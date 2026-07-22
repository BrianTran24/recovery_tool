import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/core/service/api_service.dart';

void main() {
  late ApiService apiService;

  setUp(() {
    apiService = ApiService();
  });

  group('ApiService Tests (Mock Backend Required)', () {
    test('verifyPremiumLicense with valid key should return success', () async {
      // This test requires mock backend running on localhost:3000
      // Run: dart run test_backend/mock_server.dart

      final result = await apiService.verifyPremiumLicense('PREMIUM-2024-VALID-KEY');

      expect(result.isValid, true);
      expect(result.userId, isNotNull);
      expect(result.expiresAt, isNotNull);
      expect(result.isExpired, false);
    }, skip: 'Requires mock backend running');

    test('verifyPremiumLicense with expired key should return expired', () async {
      final result = await apiService.verifyPremiumLicense('PREMIUM-2024-EXPIRED');

      expect(result.isValid, true);
      expect(result.isExpired, true);
    }, skip: 'Requires mock backend running');

    test('verifyPremiumLicense with invalid key should return failure', () async {
      final result = await apiService.verifyPremiumLicense('INVALID-KEY');

      expect(result.isValid, false);
      expect(result.message, isNotNull);
    }, skip: 'Requires mock backend running');

    test('verifyPremiumLicense with empty key should return failure', () async {
      final result = await apiService.verifyPremiumLicense('');

      expect(result.isValid, false);
    });

    test('checkSubscription with valid userId should return active', () async {
      final result = await apiService.checkSubscription('user_123456');

      expect(result.isActive, true);
      expect(result.planType, isNotNull);
      expect(result.expiresAt, isNotNull);
    }, skip: 'Requires mock backend running');

    test('checkSubscription with expired userId should return inactive', () async {
      final result = await apiService.checkSubscription('user_789012');

      expect(result.isActive, false);
      expect(result.isExpired, true);
    }, skip: 'Requires mock backend running');

    test('checkSubscription with unknown userId should return inactive', () async {
      final result = await apiService.checkSubscription('unknown_user');

      expect(result.isActive, false);
    }, skip: 'Requires mock backend running');

    test('validateToken with valid token should return true', () async {
      final result = await apiService.validateToken('valid-token-12345');

      expect(result, true);
    }, skip: 'Requires mock backend running');

    test('validateToken with short token should return false', () async {
      final result = await apiService.validateToken('short');

      expect(result, false);
    }, skip: 'Requires mock backend running');
  });

  group('ApiService Error Handling', () {
    test('should handle network timeout gracefully', () async {
      // This will timeout since no backend is running
      final result = await apiService.verifyPremiumLicense('ANY-KEY')
          .timeout(const Duration(seconds: 5), onTimeout: () {
        return PremiumVerificationResult(
          isValid: false,
          message: 'Timeout',
        );
      });

      expect(result, isA<PremiumVerificationResult>());
    });

    test('should handle invalid response gracefully', () async {
      // Test with backend down
      final result = await apiService.verifyPremiumLicense('TEST-KEY');
      
      // Should return error result, not throw exception
      expect(result, isA<PremiumVerificationResult>());
      expect(result.isValid, false);
    });
  });
}
