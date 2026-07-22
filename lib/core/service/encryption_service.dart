import 'dart:io';
import 'dart:math';
import 'package:aes_encrypt_file/aes_encrypt_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class EncryptionService {
  static const String _keyStorageKey = 'aes_encryption_key';
  static const String _ivStorageKey = 'aes_encryption_iv';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool get isEncryptionEnabled {
    final enabled = dotenv.get('ENABLE_FILE_ENCRYPTION', fallback: 'true');
    return enabled.toLowerCase() == 'true';
  }

  Future<String> _getOrCreateEncryptionKey() async {
    String? key = await _secureStorage.read(key: _keyStorageKey);
    
    if (key == null) {
      key = _generateRandomKey(32);
      await _secureStorage.write(key: _keyStorageKey, value: key);
      debugPrint('Generated new encryption key');
    }
    
    return key;
  }

  Future<String> _getOrCreateIV() async {
    String? iv = await _secureStorage.read(key: _ivStorageKey);
    
    if (iv == null) {
      iv = _generateRandomKey(16);
      await _secureStorage.write(key: _ivStorageKey, value: iv);
      debugPrint('Generated new encryption IV');
    }
    
    return iv;
  }

  String _generateRandomKey(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  Future<File?> encryptFile(File sourceFile) async {
    if (!isEncryptionEnabled) {
      debugPrint('Encryption disabled in dev mode - skipping');
      return sourceFile;
    }

    try {
      final key = await _getOrCreateEncryptionKey();
      final iv = await _getOrCreateIV();
      
      final encryptedPath = '${sourceFile.path}.encrypted';
      
      debugPrint('Encrypting file: ${sourceFile.path}');
      
      final aesEncryptFile = AesEncryptFile();
      final success = await aesEncryptFile.encryptFile(
        inputPath: sourceFile.path,
        outputPath: encryptedPath,
        key: key,
        iv: iv,
      );
      
      if (!success) {
        debugPrint('Encryption failed');
        return null;
      }

      final encryptedFile = File(encryptedPath);
      
      if (await encryptedFile.exists()) {
        // Delete original file and rename encrypted file
        await sourceFile.delete();
        final finalFile = await encryptedFile.rename(sourceFile.path);
        
        debugPrint('File encrypted successfully: ${finalFile.path}');
        return finalFile;
      } else {
        debugPrint('Encrypted file not created');
        return null;
      }
    } catch (e) {
      debugPrint('Encryption error: $e');
      return null;
    }
  }

  Future<File?> decryptFile(File encryptedFile, {String? outputPath}) async {
    try {
      final key = await _getOrCreateEncryptionKey();
      final iv = await _getOrCreateIV();
      
      final decryptedPath = outputPath ?? 
        encryptedFile.path.replaceAll('.encrypted', '').replaceAll('.enc', '');
      
      debugPrint('Decrypting file: ${encryptedFile.path}');
      
      final aesEncryptFile = AesEncryptFile();
      final success = await aesEncryptFile.decryptFile(
        inputPath: encryptedFile.path,
        outputPath: decryptedPath,
        key: key,
        iv: iv,
      );
      
      if (!success) {
        debugPrint('Decryption failed');
        return null;
      }

      final decryptedFile = File(decryptedPath);
      
      if (await decryptedFile.exists()) {
        debugPrint('File decrypted successfully: ${decryptedFile.path}');
        return decryptedFile;
      } else {
        debugPrint('Decrypted file not created');
        return null;
      }
    } catch (e) {
      debugPrint('Decryption error: $e');
      return null;
    }
  }

  Future<File?> decryptToCache(File encryptedFile, {String? customCacheName}) async {
    if (!isEncryptionEnabled) {
      return encryptedFile;
    }

    try {
      final cacheDir = await getTemporaryDirectory();
      final cachePath = customCacheName ?? 
        'preview_${DateTime.now().millisecondsSinceEpoch}_${p.basename(encryptedFile.path)}';
      final cacheFile = File(p.join(cacheDir.path, cachePath));

      debugPrint('Decrypting to cache: ${cacheFile.path}');
      
      final decrypted = await decryptFile(encryptedFile, outputPath: cacheFile.path);
      
      if (decrypted != null && await decrypted.exists()) {
        debugPrint('File decrypted to cache: ${decrypted.path}');
        return decrypted;
      } else {
        debugPrint('Failed to decrypt to cache');
        return null;
      }
    } catch (e) {
      debugPrint('Decrypt to cache error: $e');
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final files = cacheDir.listSync();
      
      for (var file in files) {
        if (file is File && p.basename(file.path).startsWith('preview_')) {
          await file.delete();
          debugPrint('Deleted cache file: ${file.path}');
        }
      }
      
      debugPrint('Cache cleared');
    } catch (e) {
      debugPrint('Clear cache error: $e');
    }
  }

  Future<bool> isFileEncrypted(File file) async {
    if (!isEncryptionEnabled) {
      return false;
    }

    try {
      // Try to read first few bytes to check if it looks encrypted
      final bytes = await file.openRead(0, 100).first;
      
      // Simple heuristic: encrypted files usually don't have readable headers
      // For images, check common headers (JPEG: FF D8, PNG: 89 50 4E 47)
      if (bytes.length >= 2) {
        // Check for common image headers
        if (bytes[0] == 0xFF && bytes[1] == 0xD8) return false; // JPEG
        if (bytes.length >= 4 && 
            bytes[0] == 0x89 && 
            bytes[1] == 0x50 && 
            bytes[2] == 0x4E && 
            bytes[3] == 0x47) return false; // PNG
        if (bytes.length >= 4 && 
            bytes[0] == 0x66 && 
            bytes[1] == 0x74 && 
            bytes[2] == 0x79 && 
            bytes[3] == 0x70) return false; // MP4
      }
      
      // If no recognizable header, assume encrypted
      return true;
    } catch (e) {
      debugPrint('Check encryption error: $e');
      return false;
    }
  }

  Future<void> resetEncryptionKeys() async {
    await _secureStorage.delete(key: _keyStorageKey);
    await _secureStorage.delete(key: _ivStorageKey);
    debugPrint('Encryption keys reset');
  }

  Future<Map<String, String?>> exportKeys() async {
    final key = await _secureStorage.read(key: _keyStorageKey);
    final iv = await _secureStorage.read(key: _ivStorageKey);
    return {
      'key': key,
      'iv': iv,
    };
  }

  Future<void> importKeys({required String key, required String iv}) async {
    await _secureStorage.write(key: _keyStorageKey, value: key);
    await _secureStorage.write(key: _ivStorageKey, value: iv);
    debugPrint('Encryption keys imported');
  }
}
