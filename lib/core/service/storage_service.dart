import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _languageKey = 'preferred_language';
  static const String _onboardingCompleteKey = 'onboarding_complete';
  static const String _premiumStatusKey = 'premium_status';
  static const String _premiumUserIdKey = 'premium_user_id';
  static const String _premiumExpiryKey = 'premium_expiry';
  static const String _premiumLicenseKey = 'premium_license_key';
  static const String _premiumOutputDirKey = 'premium_output_dir';
  static const String _encryptedFilesListKey = 'encrypted_files_list';

  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  Future<void> setOnboardingComplete(bool complete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, complete);
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  // Premium related methods
  Future<void> setPremiumStatus(bool isPremium) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_premiumStatusKey, isPremium);
  }

  Future<bool> getPremiumStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_premiumStatusKey) ?? false;
  }

  Future<void> setPremiumUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_premiumUserIdKey, userId);
  }

  Future<String?> getPremiumUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_premiumUserIdKey);
  }

  Future<void> setPremiumExpiry(DateTime? expiryDate) async {
    final prefs = await SharedPreferences.getInstance();
    if (expiryDate != null) {
      await prefs.setString(_premiumExpiryKey, expiryDate.toIso8601String());
    } else {
      await prefs.remove(_premiumExpiryKey);
    }
  }

  Future<DateTime?> getPremiumExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString(_premiumExpiryKey);
    if (expiryStr != null) {
      return DateTime.parse(expiryStr);
    }
    return null;
  }

  Future<void> setPremiumLicenseKey(String licenseKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_premiumLicenseKey, licenseKey);
  }

  Future<String?> getPremiumLicenseKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_premiumLicenseKey);
  }

  Future<void> setPremiumOutputDir(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_premiumOutputDirKey, path);
  }

  Future<String?> getPremiumOutputDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_premiumOutputDirKey);
  }

  Future<void> clearPremiumData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_premiumStatusKey);
    await prefs.remove(_premiumUserIdKey);
    await prefs.remove(_premiumExpiryKey);
    await prefs.remove(_premiumLicenseKey);
    await prefs.remove(_premiumOutputDirKey);
  }

  // Encrypted files tracking
  Future<void> addEncryptedFile(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final files = prefs.getStringList(_encryptedFilesListKey) ?? [];
    if (!files.contains(filePath)) {
      files.add(filePath);
      await prefs.setStringList(_encryptedFilesListKey, files);
    }
  }

  Future<void> removeEncryptedFile(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    final files = prefs.getStringList(_encryptedFilesListKey) ?? [];
    files.remove(filePath);
    await prefs.setStringList(_encryptedFilesListKey, files);
  }

  Future<List<String>> getEncryptedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_encryptedFilesListKey) ?? [];
  }

  Future<void> clearEncryptedFilesList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_encryptedFilesListKey);
  }

  Future<bool> isPremiumExpired() async {
    final expiry = await getPremiumExpiry();
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  Future<void> clearCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final entities = tempDir.listSync();
        for (var entity in entities) {
          // Safety check: only delete directories and files, avoid system files if any
          if (entity is Directory || entity is File) {
            await entity.delete(recursive: true);
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}
