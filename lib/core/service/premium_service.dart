import 'dart:io';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'storage_service.dart';

class PremiumService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService;

  PremiumService(this._storageService);

  Future<bool> checkPremiumStatus() async {
    final isPremium = await _storageService.getPremiumStatus();
    
    if (!isPremium) return false;

    final isExpired = await _storageService.isPremiumExpired();
    if (isExpired) {
      await _storageService.setPremiumStatus(false);
      return false;
    }

    return true;
  }

  Future<PremiumActivationResult> activatePremium(String licenseKey) async {
    try {
      debugPrint('Verifying license key: $licenseKey');
      
      final result = await _apiService.verifyPremiumLicense(licenseKey);
      
      if (result.isValid && !result.isExpired) {
        await _storageService.setPremiumStatus(true);
        
        if (result.userId != null) {
          await _storageService.setPremiumUserId(result.userId!);
        }
        
        if (result.expiresAt != null) {
          await _storageService.setPremiumExpiry(result.expiresAt);
        }
        
        await _storageService.setPremiumLicenseKey(licenseKey);
        
        debugPrint('Premium activated successfully');
        
        return PremiumActivationResult(
          success: true,
          message: 'Premium đã được kích hoạt thành công!',
        );
      } else if (result.isExpired) {
        return PremiumActivationResult(
          success: false,
          message: 'License key đã hết hạn.',
        );
      } else {
        return PremiumActivationResult(
          success: false,
          message: result.message ?? 'License key không hợp lệ.',
        );
      }
    } catch (e) {
      debugPrint('Premium activation error: $e');
      return PremiumActivationResult(
        success: false,
        message: 'Lỗi kích hoạt premium: ${e.toString()}',
      );
    }
  }

  Future<DecryptionProgress> unlockPremium(String outputDir) async {
    return DecryptionProgress(
      success: true,
      message: 'Tính năng mã hóa đã được gỡ bỏ.',
      totalFiles: 0,
      decryptedFiles: 0,
      failedFiles: 0,
    );
  }

  Future<DecryptionProgress> decryptAllFiles(String outputDir) async {
    return DecryptionProgress(
      success: true,
      message: 'Tính năng mã hóa đã được gỡ bỏ.',
      totalFiles: 0,
      decryptedFiles: 0,
      failedFiles: 0,
    );
  }

  Future<void> deactivatePremium() async {
    await _storageService.clearPremiumData();
    debugPrint('Premium deactivated');
  }

  Future<PremiumInfo> getPremiumInfo() async {
    final isPremium = await checkPremiumStatus();
    final userId = await _storageService.getPremiumUserId();
    final expiry = await _storageService.getPremiumExpiry();
    final licenseKey = await _storageService.getPremiumLicenseKey();

    return PremiumInfo(
      isPremium: isPremium,
      userId: userId,
      expiresAt: expiry,
      licenseKey: licenseKey,
    );
  }
}

class PremiumActivationResult {
  bool success;
  String message;

  PremiumActivationResult({
    required this.success,
    required this.message,
  });
}

class DecryptionProgress {
  bool success;
  String message;
  int totalFiles;
  int decryptedFiles;
  int failedFiles;

  DecryptionProgress({
    required this.success,
    required this.message,
    required this.totalFiles,
    required this.decryptedFiles,
    required this.failedFiles,
  });

  double get progressPercentage {
    if (totalFiles == 0) return 0;
    return (decryptedFiles / totalFiles) * 100;
  }
}

class PremiumInfo {
  final bool isPremium;
  final String? userId;
  final DateTime? expiresAt;
  final String? licenseKey;

  PremiumInfo({
    required this.isPremium,
    this.userId,
    this.expiresAt,
    this.licenseKey,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  String get statusText {
    if (!isPremium) return 'Free';
    if (isExpired) return 'Expired';
    return 'Premium';
  }
}
