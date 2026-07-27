import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/core/models/license_models.dart';
import 'package:recovery_tool/core/service/api_service.dart';

void main() {
  late ApiService apiService;

  setUp(() {
    apiService = ApiService();
  });

  group('ApiService License Tests', () {
    test('ActivateLicenseResponse should parse correctly', () {
      final json = {
        "valid": true,
        "message": "Kích hoạt bản quyền thành công",
        "data": {
          "code": "RECOV-H87X-K92P-M4LW-Q91Z",
          "type": "1m",
          "status": "active",
          "hwid": "CPU-INTEL-12900K-MAIN-ASUS-Z690",
          "activated_at": "2026-07-27T12:00:00Z",
          "expires_at": "2026-08-26T12:00:00Z"
        }
      };

      final response = ActivateLicenseResponse.fromJson(json);

      expect(response.valid, true);
      expect(response.message, "Kích hoạt bản quyền thành công");
      expect(response.data?.code, "RECOV-H87X-K92P-M4LW-Q91Z");
      expect(response.data?.type, "1m");
      expect(response.data?.status, "active");
      expect(response.data?.hwid, "CPU-INTEL-12900K-MAIN-ASUS-Z690");
      expect(response.data?.expiresAt, DateTime.parse("2026-08-26T12:00:00Z"));
    });

    test('ActivateLicenseResponse error should parse correctly', () {
      final json = {
        "valid": false,
        "error": "license code đã được kích hoạt cho máy tính khác"
      };

      final response = ActivateLicenseResponse.fromJson(json);

      expect(response.valid, false);
      expect(response.error, "license code đã được kích hoạt cho máy tính khác");
      expect(response.data, isNull);
    });

    test('VerifyLicenseResponse should parse correctly', () {
      final json = {
        "valid": true,
        "message": "Bản quyền hợp lệ",
        "data": {
          "code": "RECOV-H87X-K92P-M4LW-Q91Z",
          "type": "1m",
          "status": "active",
          "hwid": "CPU-INTEL-12900K-MAIN-ASUS-Z690",
          "expires_at": "2026-08-26T12:00:00Z"
        }
      };

      final response = VerifyLicenseResponse.fromJson(json);

      expect(response.valid, true);
      expect(response.message, "Bản quyền hợp lệ");
      expect(response.data?.code, "RECOV-H87X-K92P-M4LW-Q91Z");
      expect(response.data?.expiresAt, DateTime.parse("2026-08-26T12:00:00Z"));
    });

    test('VerifyLicenseResponse expired should parse correctly', () {
      final json = {
        "valid": false,
        "error": "license code đã hết hạn"
      };

      final response = VerifyLicenseResponse.fromJson(json);

      expect(response.valid, false);
      expect(response.error, "license code đã hết hạn");
    });
  });
}
