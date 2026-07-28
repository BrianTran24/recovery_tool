import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/core/service/premium_service.dart';
import 'package:recovery_tool/core/service/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PremiumService premiumService;
  late StorageService storageService;
  late Directory testDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = StorageService();
    premiumService = PremiumService(storageService);
    testDir = Directory.systemTemp.createTempSync('premium_test_');
  });

  tearDown(() {
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('PremiumService Tests', () {
    test('checkPremiumStatus should return false by default', () async {
      final isPremium = await premiumService.checkPremiumStatus();
      expect(isPremium, false);
    });

    test('checkPremiumStatus should return true after activation', () async {
      // Manually set premium status
      await storageService.setPremiumStatus(true);
      await storageService.setPremiumExpiry(DateTime.now().add(const Duration(days: 365)));

      final isPremium = await premiumService.checkPremiumStatus();
      expect(isPremium, true);
    });

    test('checkPremiumStatus should return false if expired', () async {
      await storageService.setPremiumStatus(true);
      await storageService.setPremiumExpiry(DateTime.now().subtract(const Duration(days: 1)));

      final isPremium = await premiumService.checkPremiumStatus();
      expect(isPremium, false);
    });

    test('activatePremium with valid key should succeed', () async {
      // This test requires mock backend running
      final result = await premiumService.activatePremium('PREMIUM-2024-VALID-KEY');

      expect(result, isA<PremiumActivationResult>());
      // Result depends on backend availability
    }, skip: 'Requires mock backend running');

    test('activatePremium with invalid key should fail', () async {
      final result = await premiumService.activatePremium('INVALID-KEY');

      expect(result, isA<PremiumActivationResult>());
      expect(result.success, false);
    }, skip: 'Requires mock backend running');

    test('activatePremium with expired key should fail', () async {
      final result = await premiumService.activatePremium('PREMIUM-2024-EXPIRED');

      expect(result, isA<PremiumActivationResult>());
      expect(result.success, false);
      expect(result.message, contains('hết hạn'));
    }, skip: 'Requires mock backend running');

    test('getPremiumInfo should return correct info', () async {
      await storageService.setPremiumStatus(true);
      await storageService.setPremiumUserId('test_user_123');
      await storageService.setPremiumLicenseKey('TEST-KEY');
      
      final expiryDate = DateTime.now().add(const Duration(days: 365));
      await storageService.setPremiumExpiry(expiryDate);

      final info = await premiumService.getPremiumInfo();

      expect(info.isPremium, true);
      expect(info.userId, 'test_user_123');
      expect(info.licenseKey, 'TEST-KEY');
      expect(info.expiresAt, isNotNull);
      expect(info.isExpired, false);
      expect(info.statusText, 'Premium');
    });

    test('getPremiumInfo should show expired status', () async {
      await storageService.setPremiumStatus(true);
      await storageService.setPremiumExpiry(DateTime.now().subtract(const Duration(days: 1)));

      final info = await premiumService.getPremiumInfo();

      expect(info.isPremium, true);
      expect(info.isExpired, true);
      expect(info.statusText, 'Expired');
    });

    test('deactivatePremium should clear all premium data', () async {
      // Set premium data
      await storageService.setPremiumStatus(true);
      await storageService.setPremiumUserId('test_user');
      await storageService.setPremiumLicenseKey('TEST-KEY');

      // Deactivate
      await premiumService.deactivatePremium();

      // Verify cleared
      final isPremium = await storageService.getPremiumStatus();
      final userId = await storageService.getPremiumUserId();
      final licenseKey = await storageService.getPremiumLicenseKey();

      expect(isPremium, false);
      expect(userId, isNull);
      expect(licenseKey, isNull);
    });
  });

  group('PremiumInfo Tests', () {
    test('PremiumInfo should detect expired status', () {
      final expiredInfo = PremiumInfo(
        isPremium: true,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(expiredInfo.isExpired, true);
      expect(expiredInfo.statusText, 'Expired');
    });

    test('PremiumInfo without expiry should not be expired', () {
      final info = PremiumInfo(
        isPremium: true,
        expiresAt: null,
      );

      expect(info.isExpired, false);
      expect(info.statusText, 'Premium');
    });

    test('PremiumInfo for free user should show Free status', () {
      final info = PremiumInfo(
        isPremium: false,
      );

      expect(info.statusText, 'Free');
    });
  });
}
