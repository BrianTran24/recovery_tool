import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/service/premium_service.dart';
import '../../core/service/storage_service.dart';
import '../../core/theme/app_theme.dart';

class PremiumUnlockScreen extends StatefulWidget {
  final String outputDir;

  const PremiumUnlockScreen({
    super.key,
    required this.outputDir,
  });

  @override
  State<PremiumUnlockScreen> createState() => _PremiumUnlockScreenState();
}

class _PremiumUnlockScreenState extends State<PremiumUnlockScreen> {
  final TextEditingController _licenseController = TextEditingController();
  final PremiumService _premiumService = PremiumService(StorageService());
  
  bool _isLoading = false;
  bool _isDecrypting = false;
  DecryptionProgress? _decryptionProgress;
  String? _errorMessage;

  @override
  void dispose() {
    _licenseController.dispose();
    super.dispose();
  }

  Future<void> _activateLicense() async {
    final licenseKey = _licenseController.text.trim();
    
    if (licenseKey.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập license key');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _premiumService.activatePremium(licenseKey);
      
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result.success) {
          // Show success and ask to decrypt
          _showDecryptDialog();
        } else {
          setState(() => _errorMessage = result.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Lỗi: ${e.toString()}';
        });
      }
    }
  }

  void _showDecryptDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Premium đã kích hoạt!'),
        content: const Text('Bạn có muốn giải mã toàn bộ file ngay bây giờ không?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // Return to preview
            },
            child: const Text('Để sau'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startDecryption();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Giải mã ngay'),
          ),
        ],
      ),
    );
  }

  Future<void> _startDecryption() async {
    setState(() {
      _isDecrypting = true;
      _errorMessage = null;
    });

    try {
      final progress = await _premiumService.decryptAllFiles(widget.outputDir);
      
      if (mounted) {
        setState(() {
          _isDecrypting = false;
          _decryptionProgress = progress;
        });
        
        if (progress.success) {
          _showSuccessDialog();
        } else {
          setState(() => _errorMessage = progress.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDecrypting = false;
          _errorMessage = 'Lỗi giải mã: ${e.toString()}';
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Thành công!'),
          ],
        ),
        content: Text(
          'Đã giải mã thành công ${_decryptionProgress?.decryptedFiles}/${_decryptionProgress?.totalFiles} file!\n\n'
          'Bạn có thể truy cập file trực tiếp từ thư mục output.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true); // Return to preview
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kích hoạt Premium'),
        backgroundColor: AppTheme.cyberDeepNavy,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.cyberDeepNavy,
              AppTheme.cyberDeepNavy,
            ],
          ),
        ),
        child: _isDecrypting ? _buildDecryptionProgress() : _buildActivationForm(),
      ),
    );
  }

  Widget _buildActivationForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.workspace_premium_rounded,
                  size: 80,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Nâng cấp lên Premium',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Mở khóa toàn bộ file đã khôi phục và truy cập trực tiếp từ thư mục',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildFeatureItem(Icons.lock_open_rounded, 'Giải mã toàn bộ file'),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.folder_open_rounded, 'Truy cập trực tiếp từ thư mục'),
                const SizedBox(height: 12),
                _buildFeatureItem(Icons.verified_user_rounded, 'Không có watermark'),
                const SizedBox(height: 32),
                TextField(
                  controller: _licenseController,
                  decoration: InputDecoration(
                    labelText: 'License Key',
                    hintText: 'Nhập license key của bạn',
                    prefixIcon: const Icon(Icons.key_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: _errorMessage,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9-]')),
                  ],
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _activateLicense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Kích hoạt Premium',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    // TODO: Open purchase page
                  },
                  child: const Text('Mua license key'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildDecryptionProgress() {
    final progress = _decryptionProgress;
    
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 6,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(height: 32),
              const Text(
                'Đang giải mã file...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (progress != null) ...[
                Text(
                  '${progress.decryptedFiles}/${progress.totalFiles} file',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress.progressPercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 8),
                Text(
                  '${progress.progressPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ] else
                Text(
                  'Đang chuẩn bị...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                'Vui lòng không đóng ứng dụng',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
