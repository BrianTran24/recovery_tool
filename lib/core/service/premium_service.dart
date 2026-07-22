import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'api_service.dart';
import 'storage_service.dart';
import 'encryption_service.dart';

class PremiumService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService;
  final EncryptionService _encryptionService = EncryptionService();

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
    final isPremium = await checkPremiumStatus();
    
    if (!isPremium) {
      return DecryptionProgress(
        success: false,
        message: 'Bạn chưa có premium. Vui lòng kích hoạt premium trước.',
        totalFiles: 0,
        decryptedFiles: 0,
        failedFiles: 0,
      );
    }

    return await decryptAllFiles(outputDir);
  }

  Future<DecryptionProgress> decryptAllFiles(String outputDir) async {
    final progress = DecryptionProgress(
      success: false,
      message: '',
      totalFiles: 0,
      decryptedFiles: 0,
      failedFiles: 0,
    );

    try {
      final outputDirectory = Directory(outputDir);
      
      if (!await outputDirectory.exists()) {
        progress.success = false;
        progress.message = 'Thư mục output không tồn tại';
        return progress;
      }

      // Get all files recursively
      final allFiles = outputDirectory.listSync(recursive: true).whereType<File>().toList();
      progress.totalFiles = allFiles.length;

      debugPrint('Starting bulk decryption: ${progress.totalFiles} files');

      // Check available disk space (need at least 2x of total file size)
      final totalSize = allFiles.fold<int>(0, (sum, file) => sum + file.lengthSync());
      final freeSpace = await _getAvailableDiskSpace(outputDir);
      
      if (freeSpace < totalSize * 2) {
        progress.success = false;
        progress.message = 'Không đủ dung lượng ổ đĩa. Cần thêm ${_formatBytes(totalSize * 2 - freeSpace)}';
        return progress;
      }

      // Decrypt each file
      for (var i = 0; i < allFiles.length; i++) {
        final file = allFiles[i];
        
        // Check if file is encrypted
        final isEncrypted = await _encryptionService.isFileEncrypted(file);
        
        if (!isEncrypted) {
          debugPrint('File is not encrypted, skipping: ${file.path}');
          progress.decryptedFiles++;
          continue;
        }

        debugPrint('Decrypting file ${i + 1}/${progress.totalFiles}: ${file.path}');

        try {
          // Decrypt to a temporary location first
          final tempPath = '${file.path}.temp';
          final decryptedFile = await _encryptionService.decryptFile(file, outputPath: tempPath);
          
          if (decryptedFile != null && await decryptedFile.exists()) {
            // Delete the encrypted original
            await file.delete();
            
            // Rename decrypted file to original name
            await decryptedFile.rename(file.path);
            
            progress.decryptedFiles++;
            
            // Remove from encrypted files list
            await _storageService.removeEncryptedFile(file.path);
            
            debugPrint('Successfully decrypted: ${file.path}');
          } else {
            progress.failedFiles++;
            debugPrint('Failed to decrypt: ${file.path}');
          }
        } catch (e) {
          progress.failedFiles++;
          debugPrint('Error decrypting ${file.path}: $e');
        }
      }

      progress.success = progress.failedFiles == 0;
      progress.message = progress.success
          ? 'Đã giải mã thành công ${progress.decryptedFiles}/${progress.totalFiles} file!'
          : 'Giải mã hoàn tất với ${progress.failedFiles} lỗi';

      debugPrint('Bulk decryption completed: ${progress.decryptedFiles} success, ${progress.failedFiles} failed');
      
      return progress;
    } catch (e) {
      debugPrint('Bulk decryption error: $e');
      progress.success = false;
      progress.message = 'Lỗi khi giải mã: ${e.toString()}';
      return progress;
    }
  }

  Future<int> _getAvailableDiskSpace(String path) async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('wmic', ['logicaldisk', 'get', 'freespace']);
        // This is a simplified check, in production you'd parse the actual drive
        return 1024 * 1024 * 1024 * 100; // Assume 100GB available
      } else if (Platform.isMacOS || Platform.isLinux) {
        final result = await Process.run('df', ['-k', path]);
        // Parse output to get available space
        return 1024 * 1024 * 1024 * 100; // Assume 100GB available
      }
      return 1024 * 1024 * 1024 * 100; // Default: Assume 100GB available
    } catch (e) {
      debugPrint('Error checking disk space: $e');
      return 1024 * 1024 * 1024 * 100; // Default: Assume 100GB available
    }
  }

  String _formatBytes(int bytes) {
    if (bytes > 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    } else if (bytes > 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    } else if (bytes > 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '$bytes B';
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
