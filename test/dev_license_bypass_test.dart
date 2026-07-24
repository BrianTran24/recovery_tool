import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/core/service/premium_service.dart';
import 'package:recovery_tool/core/service/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PremiumService premiumService;
  late StorageService storageService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storageService = StorageService();
    premiumService = PremiumService(storageService);
    
    // Load environment variables for test
    dotenv.testLoad(fileInput: 'DEV_LICENSE_KEY=TEST-BYPASS-KEY');
  });

  group('Development License Bypass Tests', () {
    test('activatePremium should succeed when licenseKey matches DEV_LICENSE_KEY', () async {
      final result = await premiumService.activatePremium('TEST-BYPASS-KEY');

      expect(result.success, true);
      expect(result.message, 'premiumActivated');
      
      final isPremium = await storageService.getPremiumStatus();
      expect(isPremium, true);
      
      final userId = await storageService.getPremiumUserId();
      expect(userId, 'DEV_USER');
    });

    test('activatePremium should NOT bypass when licenseKey does NOT match DEV_LICENSE_KEY', () async {
      // This will try to call the API, which should fail in test environment (no internet/mock)
      final result = await premiumService.activatePremium('WRONG-KEY');

      expect(result.success, false);
      // It should NOT be activated via bypass
      final isPremium = await storageService.getPremiumStatus();
      expect(isPremium, false);
    });
    
    test('activatePremium should NOT bypass when DEV_LICENSE_KEY is empty', () async {
      dotenv.testLoad(fileInput: 'DEV_LICENSE_KEY=');
      
      final result = await premiumService.activatePremium('ANY-KEY');
      expect(result.success, false);
      
      final isPremium = await storageService.getPremiumStatus();
      expect(isPremium, false);
    });
  });
}
