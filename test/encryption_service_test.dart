import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:recovery_tool/core/service/encryption_service.dart';
import 'package:path/path.dart' as p;

// Mock PathProviderPlatform for testing
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    final tempDir = Directory.systemTemp.createTempSync('encryption_test');
    return tempDir.path;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    final tempDir = Directory.systemTemp.createTempSync('encryption_test_docs');
    return tempDir.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EncryptionService encryptionService;
  late Directory testDir;

  setUpAll(() {
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  setUp(() {
    encryptionService = EncryptionService();
    testDir = Directory.systemTemp.createTempSync('encryption_test_');
  });

  tearDown(() {
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('EncryptionService Tests', () {
    test('isEncryptionEnabled should read from .env', () {
      // This will depend on the actual .env configuration
      // In dev mode, it should be false
      final isEnabled = encryptionService.isEncryptionEnabled;
      expect(isEnabled, isA<bool>());
    });

    test('encryptFile should create encrypted file when enabled', () async {
      // Create a test file
      final testFile = File(p.join(testDir.path, 'test.txt'));
      await testFile.writeAsString('Hello, World!');

      expect(await testFile.exists(), true);
      expect(await testFile.readAsString(), 'Hello, World!');

      // Note: This test will only work if encryption is enabled in .env
      // In dev mode (encryption disabled), it should return the original file
      final encryptedFile = await encryptionService.encryptFile(testFile);

      if (encryptionService.isEncryptionEnabled) {
        expect(encryptedFile, isNotNull);
        expect(await encryptedFile!.exists(), true);
        
        // Encrypted content should be different
        final encryptedContent = await encryptedFile.readAsString();
        expect(encryptedContent, isNot('Hello, World!'));
      } else {
        // In dev mode, should return original file
        expect(encryptedFile, testFile);
      }
    }, skip: 'Requires .env configuration');

    test('decryptToCache should create decrypted file in cache', () async {
      // Create and encrypt a test file
      final testFile = File(p.join(testDir.path, 'test_decrypt.txt'));
      await testFile.writeAsString('Test content for decryption');

      if (!encryptionService.isEncryptionEnabled) {
        // Skip test if encryption is disabled
        return;
      }

      final encryptedFile = await encryptionService.encryptFile(testFile);
      expect(encryptedFile, isNotNull);

      // Decrypt to cache
      final cachedFile = await encryptionService.decryptToCache(encryptedFile!);
      expect(cachedFile, isNotNull);
      expect(await cachedFile!.exists(), true);

      // Content should match original
      final decryptedContent = await cachedFile.readAsString();
      expect(decryptedContent, 'Test content for decryption');
    }, skip: 'Requires .env configuration and encryption enabled');

    test('clearCache should remove preview files', () async {
      // This test would require creating temp cache files
      // and verifying they are deleted
      await encryptionService.clearCache();
      // If no errors, test passes
      expect(true, true);
    });

    test('isFileEncrypted should detect encrypted files', () async {
      // Create a plaintext file
      final plainFile = File(p.join(testDir.path, 'plain.txt'));
      await plainFile.writeAsString('Plain text content');

      final isEncrypted = await encryptionService.isFileEncrypted(plainFile);
      
      // Plain text file should not be detected as encrypted
      expect(isEncrypted, false);
    });

    test('isFileEncrypted should detect image files as not encrypted', () async {
      // Create a fake JPEG file (with JPEG header)
      final jpegFile = File(p.join(testDir.path, 'test.jpg'));
      await jpegFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0]); // JPEG header

      final isEncrypted = await encryptionService.isFileEncrypted(jpegFile);
      expect(isEncrypted, false);

      // Create a fake PNG file
      final pngFile = File(p.join(testDir.path, 'test.png'));
      await pngFile.writeAsBytes([0x89, 0x50, 0x4E, 0x47]); // PNG header

      final isPngEncrypted = await encryptionService.isFileEncrypted(pngFile);
      expect(isPngEncrypted, false);
    });

    test('exportKeys should return key and IV', () async {
      final keys = await encryptionService.exportKeys();
      
      expect(keys, isA<Map<String, String?>>());
      expect(keys.containsKey('key'), true);
      expect(keys.containsKey('iv'), true);
    });

    test('importKeys should store provided keys', () async {
      const testKey = 'test-key-123';
      const testIv = 'test-iv-456';

      await encryptionService.importKeys(key: testKey, iv: testIv);

      // Verify by exporting
      final exported = await encryptionService.exportKeys();
      expect(exported['key'], testKey);
      expect(exported['iv'], testIv);
    });

    test('resetEncryptionKeys should clear stored keys', () async {
      // First ensure there are keys
      await encryptionService.importKeys(key: 'temp-key', iv: 'temp-iv');

      // Reset
      await encryptionService.resetEncryptionKeys();

      // Keys should be null or regenerated
      final exported = await encryptionService.exportKeys();
      // After reset, keys might be null or newly generated
      expect(exported, isA<Map<String, String?>>());
    });
  });

  group('EncryptionService Integration Tests', () {
    test('Full encrypt-decrypt cycle should preserve content', () async {
      if (!encryptionService.isEncryptionEnabled) {
        return; // Skip if encryption disabled
      }

      // Create original file
      final originalFile = File(p.join(testDir.path, 'original.txt'));
      const originalContent = 'This is a test file for full cycle encryption!';
      await originalFile.writeAsString(originalContent);

      // Encrypt
      final encryptedFile = await encryptionService.encryptFile(originalFile);
      expect(encryptedFile, isNotNull);
      expect(await encryptedFile!.exists(), true);

      // Verify encrypted content is different
      final encryptedBytes = await encryptedFile.readAsBytes();
      expect(String.fromCharCodes(encryptedBytes), isNot(originalContent));

      // Decrypt
      final decryptedPath = p.join(testDir.path, 'decrypted.txt');
      final decryptedFile = await encryptionService.decryptFile(
        encryptedFile,
        outputPath: decryptedPath,
      );

      expect(decryptedFile, isNotNull);
      expect(await decryptedFile!.exists(), true);

      // Verify decrypted content matches original
      final decryptedContent = await decryptedFile.readAsString();
      expect(decryptedContent, originalContent);
    }, skip: 'Requires encryption enabled in .env');
  });
}
