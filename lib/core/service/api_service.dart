import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/license_models.dart';
import 'security_service.dart';

class ApiService {
  static String get _baseUrl => dotenv.get('API_BASE_URL', fallback: 'http://localhost:3000');
  static int get _timeout => int.parse(dotenv.get('API_TIMEOUT', fallback: '30'));

  final SecurityService _securityService = SecurityService();

  Future<PremiumVerificationResult> verifyPremiumLicense(String licenseKey) async {
    // Note: This method is being replaced by verifyLicense but kept for backward compatibility if needed
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/verify-license'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'license_key': licenseKey}),
      ).timeout(Duration(seconds: _timeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PremiumVerificationResult(
          isValid: data['valid'] ?? false,
          userId: data['user_id'],
          expiresAt: data['expires_at'] != null 
            ? DateTime.parse(data['expires_at'])
            : null,
          message: data['message'],
        );
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        return PremiumVerificationResult(
          isValid: false,
          message: 'errorVerifyLicense',
        );
      }
    } on TimeoutException {
      debugPrint('API Timeout');
      return PremiumVerificationResult(
        isValid: false,
        message: 'errorTimeout',
      );
    } catch (e) {
      debugPrint('API Exception: $e');
      return PremiumVerificationResult(
        isValid: false,
        message: 'errorConnection:${e.toString()}',
      );
    }
  }

  Future<ActivateLicenseResponse> activateLicense(ActivateLicenseRequest request) async {
    try {
      // 1. Encrypt Request
      final encryptedReq = await _securityService.encryptRequest(request.toJson());

      // 2. Send Encrypted Envelope
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/license/activate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(encryptedReq.toJson()),
      ).timeout(Duration(seconds: _timeout));

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        return ActivateLicenseResponse(
          valid: false,
          error: errorData['error'] ?? 'Server error: ${response.statusCode}',
        );
      }

      // 3. Decrypt Response
      final encryptedRes = EncryptedResponse.fromJson(jsonDecode(response.body));
      final decryptedData = await _securityService.decryptResponse(encryptedRes);
      
      return ActivateLicenseResponse.fromJson(decryptedData);
    } on SecurityException catch (e) {
      debugPrint('SECURITY ALERT: $e');
      return ActivateLicenseResponse(
        valid: false,
        error: 'SECURITY_ALERT: ${e.message}',
      );
    } catch (e) {
      debugPrint('Activate License API Exception: $e');
      return ActivateLicenseResponse(
        valid: false,
        error: 'errorConnection:${e.toString()}',
      );
    }
  }

  Future<VerifyLicenseResponse> verifyLicense(VerifyLicenseRequest request) async {
    try {
      // 1. Encrypt Request
      final encryptedReq = await _securityService.encryptRequest(request.toJson());

      // 2. Send Encrypted Envelope
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/license/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(encryptedReq.toJson()),
      ).timeout(Duration(seconds: _timeout));

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        return VerifyLicenseResponse(
          valid: false,
          error: errorData['error'] ?? 'Server error: ${response.statusCode}',
        );
      }

      // 3. Decrypt Response
      final encryptedRes = EncryptedResponse.fromJson(jsonDecode(response.body));
      final decryptedData = await _securityService.decryptResponse(encryptedRes);
      
      return VerifyLicenseResponse.fromJson(decryptedData);
    } on SecurityException catch (e) {
      debugPrint('SECURITY ALERT: $e');
      return VerifyLicenseResponse(
        valid: false,
        error: 'SECURITY_ALERT: ${e.message}',
      );
    } catch (e) {
      debugPrint('Verify License API Exception: $e');
      return VerifyLicenseResponse(
        valid: false,
        error: 'errorConnection:${e.toString()}',
      );
    }
  }

  Future<SubscriptionStatus> checkSubscription(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/subscription/$userId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: _timeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return SubscriptionStatus(
          isActive: data['is_active'] ?? false,
          planType: data['plan_type'],
          expiresAt: data['expires_at'] != null 
            ? DateTime.parse(data['expires_at'])
            : null,
          autoRenew: data['auto_renew'] ?? false,
        );
      } else {
        debugPrint('API Error: ${response.statusCode} - ${response.body}');
        return SubscriptionStatus(isActive: false);
      }
    } on TimeoutException {
      debugPrint('API Timeout');
      return SubscriptionStatus(isActive: false);
    } catch (e) {
      debugPrint('API Exception: $e');
      return SubscriptionStatus(isActive: false);
    }
  }

  Future<bool> validateToken(String token) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/validate-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: _timeout));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Token validation error: $e');
      return false;
    }
  }
}

class PremiumVerificationResult {
  final bool isValid;
  final String? userId;
  final DateTime? expiresAt;
  final String? message;

  PremiumVerificationResult({
    required this.isValid,
    this.userId,
    this.expiresAt,
    this.message,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

class SubscriptionStatus {
  final bool isActive;
  final String? planType;
  final DateTime? expiresAt;
  final bool autoRenew;

  SubscriptionStatus({
    required this.isActive,
    this.planType,
    this.expiresAt,
    this.autoRenew = false,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}
