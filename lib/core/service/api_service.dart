import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get _baseUrl => dotenv.get('API_BASE_URL', fallback: 'http://localhost:3000');
  static int get _timeout => int.parse(dotenv.get('API_TIMEOUT', fallback: '30'));

  Future<PremiumVerificationResult> verifyPremiumLicense(String licenseKey) async {
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
          message: 'Không thể xác thực license. Vui lòng thử lại sau.',
        );
      }
    } on TimeoutException {
      debugPrint('API Timeout');
      return PremiumVerificationResult(
        isValid: false,
        message: 'Kết nối timeout. Vui lòng kiểm tra internet.',
      );
    } catch (e) {
      debugPrint('API Exception: $e');
      return PremiumVerificationResult(
        isValid: false,
        message: 'Lỗi kết nối: ${e.toString()}',
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
