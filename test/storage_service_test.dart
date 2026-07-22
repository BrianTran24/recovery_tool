import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/core/service/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storageService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storageService = StorageService();
  });

  group('StorageService Premium Tests', () {
    test('getPremiumStatus should return false by default', () async {
      final isPremium = await storageService.getPremiumStatus();
      expect(isPremium, false);
    });

    test('setPremiumStatus should store and retrieve correctly', () async {
      await storageService.setPremiumStatus(true);
      final isPremium = await storageService.getPremiumStatus();
      expect(isPremium, true);
    });

    test('setPremiumUserId should store and retrieve correctly', () async {
      await storageService.setPremiumUserId('user_123');
      final userId = await storageService.getPremiumUserId();
      expect(userId, 'user_123');
    });

    test('getPremiumUserId should return null by default', () async {
      final userId = await storageService.getPremiumUserId();
      expect(userId, isNull);
    });

    test('setPremiumExpiry should store and retrieve correctly', () async {
      final expiryDate = DateTime(2027, 12, 31);
      await storageService.setPremiumExpiry(expiryDate);
      
      final retrieved = await storageService.getPremiumExpiry();
      expect(retrieved, isNotNull);
      expect(retrieved!.year, 2027);
      expect(retrieved.month, 12);
      expect(retrieved.day, 31);
    });

    test('setPremiumExpiry with null should clear expiry', () async {
      await storageService.setPremiumExpiry(DateTime.now());
      await storageService.setPremiumExpiry(null);
      
      final retrieved = await storageService.getPremiumExpiry();
      expect(retrieved, isNull);
    });

    test('setPremiumLicenseKey should store and retrieve correctly', () async {
      await storageService.setPremiumLicenseKey('TEST-LICENSE-KEY');
      final key = await storageService.getPremiumLicenseKey();
      expect(key, 'TEST-LICENSE-KEY');
    });

    test('clearPremiumData should remove all premium data', () async {
      // Set all premium data
      await storageService.setPremiumStatus(true);
      await storageService.setPremiumUserId('user_123');
      await storageService.setPremiumExpiry(DateTime.now());
      await storageService.setPremiumLicenseKey('TEST-KEY');

      // Clear
      await storageService.clearPremiumData();

      // Verify all cleared
      final isPremium = await storageService.getPremiumStatus();
      final userId = await storageService.getPremiumUserId();
      final expiry = await storageService.getPremiumExpiry();
      final key = await storageService.getPremiumLicenseKey();

      expect(isPremium, false);
      expect(userId, isNull);
      expect(expiry, isNull);
      expect(key, isNull);
    });

    test('isPremiumExpired should return false with no expiry', () async {
      final isExpired = await storageService.isPremiumExpired();
      expect(isExpired, false);
    });

    test('isPremiumExpired should return true for past date', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 1));
      await storageService.setPremiumExpiry(pastDate);

      final isExpired = await storageService.isPremiumExpired();
      expect(isExpired, true);
    });

    test('isPremiumExpired should return false for future date', () async {
      final futureDate = DateTime.now().add(const Duration(days: 365));
      await storageService.setPremiumExpiry(futureDate);

      final isExpired = await storageService.isPremiumExpired();
      expect(isExpired, false);
    });
  });

  group('StorageService Encrypted Files Tests', () {
    test('getEncryptedFiles should return empty list by default', () async {
      final files = await storageService.getEncryptedFiles();
      expect(files, isEmpty);
    });

    test('addEncryptedFile should add file to list', () async {
      await storageService.addEncryptedFile('/path/to/file1.jpg');
      final files = await storageService.getEncryptedFiles();
      
      expect(files, contains('/path/to/file1.jpg'));
      expect(files.length, 1);
    });

    test('addEncryptedFile should not add duplicates', () async {
      await storageService.addEncryptedFile('/path/to/file1.jpg');
      await storageService.addEncryptedFile('/path/to/file1.jpg');
      
      final files = await storageService.getEncryptedFiles();
      expect(files.length, 1);
    });

    test('removeEncryptedFile should remove file from list', () async {
      await storageService.addEncryptedFile('/path/to/file1.jpg');
      await storageService.addEncryptedFile('/path/to/file2.jpg');
      await storageService.removeEncryptedFile('/path/to/file1.jpg');

      final files = await storageService.getEncryptedFiles();
      expect(files, isNot(contains('/path/to/file1.jpg')));
      expect(files, contains('/path/to/file2.jpg'));
      expect(files.length, 1);
    });

    test('clearEncryptedFilesList should remove all files', () async {
      await storageService.addEncryptedFile('/path/to/file1.jpg');
      await storageService.addEncryptedFile('/path/to/file2.jpg');
      await storageService.clearEncryptedFilesList();

      final files = await storageService.getEncryptedFiles();
      expect(files, isEmpty);
    });
  });

  group('StorageService Language Tests', () {
    test('getLanguage should return null by default', () async {
      final language = await storageService.getLanguage();
      expect(language, isNull);
    });

    test('setLanguage should store and retrieve correctly', () async {
      await storageService.setLanguage('vi');
      final language = await storageService.getLanguage();
      expect(language, 'vi');
    });
  });

  group('StorageService Onboarding Tests', () {
    test('isOnboardingComplete should return false by default', () async {
      final isComplete = await storageService.isOnboardingComplete();
      expect(isComplete, false);
    });

    test('setOnboardingComplete should store and retrieve correctly', () async {
      await storageService.setOnboardingComplete(true);
      final isComplete = await storageService.isOnboardingComplete();
      expect(isComplete, true);
    });
  });
}
