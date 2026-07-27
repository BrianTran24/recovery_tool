import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/license_models.dart';
import '../utils/device_info_utils.dart';
import 'api_service.dart';
import 'storage_service.dart';

class PremiumService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService;

  PremiumService(this._storageService);

  Future<bool> checkPremiumStatus() async {
    final isPremium = await _storageService.getPremiumStatus();
    
    if (!isPremium) return false;

    final licenseKey = await _storageService.getPremiumLicenseKey();
    if (licenseKey != null && licenseKey.isNotEmpty) {
      // Periodic online verification or verification on startup
      final hwid = await DeviceInfoUtils.getHWID();
      final result = await _apiService.verifyLicense(VerifyLicenseRequest(
        code: licenseKey,
        hwid: hwid,
      ));

      if (!result.valid) {
        debugPrint('License verification failed: ${result.error}');
        await _storageService.setPremiumStatus(false);
        return false;
      }

      if (result.data != null) {
        await _storageService.setPremiumExpiry(result.data!.expiresAt);
      }
    }

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
      
      // Check for development bypass key
      final devKey = dotenv.maybeGet('DEV_LICENSE_KEY');
      if (devKey != null && devKey.isNotEmpty && licenseKey == devKey) {
        debugPrint('✅ Development license bypass detected');
        await _storageService.setPremiumStatus(true);
        await _storageService.setPremiumUserId('DEV_USER');
        await _storageService.setPremiumExpiry(DateTime.now().add(const Duration(days: 365)));
        await _storageService.setPremiumLicenseKey(licenseKey);
        
        return PremiumActivationResult(
          success: true,
          message: 'premiumActivated',
        );
      }
      
      final hwid = await DeviceInfoUtils.getHWID();
      final deviceName = DeviceInfoUtils.getDeviceName();

      final result = await _apiService.activateLicense(ActivateLicenseRequest(
        code: licenseKey,
        hwid: hwid,
        deviceName: deviceName,
      ));
      
      if (result.valid && result.data != null) {
        await _storageService.setPremiumStatus(true);
        await _storageService.setPremiumLicenseKey(licenseKey);
        await _storageService.setPremiumExpiry(result.data!.expiresAt);
        await _storageService.setPremiumUserId(result.data!.code); // Using code as user ID if not provided
        
        debugPrint('Premium activated successfully');
        
        return PremiumActivationResult(
          success: true,
          message: result.message ?? 'premiumActivated',
        );
      } else {
        return PremiumActivationResult(
          success: false,
          message: result.error ?? 'licenseInvalid',
        );
      }
    } catch (e) {
      debugPrint('Premium activation error: $e');
      return PremiumActivationResult(
        success: false,
        message: 'errorActivatePremium:${e.toString()}',
      );
    }
  }

  Future<DecryptionProgress> unlockPremium(String outputDir) async {
    return DecryptionProgress(
      success: true,
      message: 'featureRemoved',
      totalFiles: 0,
      decryptedFiles: 0,
      failedFiles: 0,
    );
  }

  Future<DecryptionProgress> decryptAllFiles(String outputDir) async {
    return DecryptionProgress(
      success: true,
      message: 'featureRemoved',
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
