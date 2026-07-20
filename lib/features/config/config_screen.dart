import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:disks_desktop/disks_desktop.dart';
import '../../scan_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

class ConfigScreen extends StatefulWidget {
  final Disk disk;
  const ConfigScreen({super.key, required this.disk});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  int _scanMode = 1; // 1=Deleted, 2=Existing, 3=Both
  String? _outputDir;
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _refController = TextEditingController();
  String _referenceVideo = r'assets\GX011168.MP4';

  @override
  void initState() {
    super.initState();
    _outputDir = r'E:\test';
    _pathController.text = _outputDir!;
    _refController.text = _referenceVideo;
  }

  Future<void> _pickDirectory() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _outputDir = result;
        _pathController.text = result;
      });
    }
  }

  Future<void> _pickReferenceVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp4', 'mov', 'MP4', 'MOV'],
    );
    final picked = result?.files.single.path;
    if (picked != null) {
      setState(() {
        _referenceVideo = picked;
        _refController.text = picked;
      });
    }
  }

  void _startScan() {
    if (_outputDir == null || _outputDir!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn thư mục lưu file')),
      );
      return;
    }

    final path = (widget.disk.raw.startsWith('/dev/'))
        ? widget.disk.raw
        : widget.disk.devicePath;

    if (path == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanScreen(
          sourcePath: path,
          outputDir: _outputDir!,
          enableFat: true,
          enableCarve: true,
          scanMode: _scanMode,
          referenceVideo: _referenceVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấu hình Quét'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Disk Info Card
            _buildSectionHeader('Thiết bị nguồn'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.storage_rounded, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.disk.raw.startsWith('/dev/')
                                ? (widget.disk.devicePath ?? 'Unknown Device')
                                : 'Ảnh backup: ${widget.disk.devicePath ?? 'Unknown'}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.disk.raw.startsWith('/dev/')
                                ? 'Dung lượng: ${(widget.disk.size ?? 0) ~/ (1024 * 1024 * 1024)} GB'
                                : 'Chế độ chỉ đọc - An toàn tuyệt đối',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // GC/Trim Warning
            if (widget.disk.raw.startsWith('/dev/')) ...[
              const SizedBox(height: 16),
              _buildGCTrimWarning(),
            ],
            
            const SizedBox(height: 32),
            _buildSectionHeader('Chế độ khôi phục'),
            _buildScanModeSelector(),
            
            const SizedBox(height: 32),
            _buildSectionHeader('Cấu hình lưu trữ'),
            _buildPathSelector(
              label: 'Thư mục đầu ra',
              controller: _pathController,
              onTap: _pickDirectory,
              icon: Icons.folder_open_rounded,
            ),
            
            const SizedBox(height: 24),
            _buildSectionHeader('Video tham chiếu (Tùy chọn)'),
            _buildPathSelector(
              label: 'Chọn video khỏe cùng loại để sửa lỗi moov',
              controller: _refController,
              onTap: _pickReferenceVideo,
              icon: Icons.movie_filter_rounded,
              isSmall: true,
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startScan,
                child: const Text('BẮT ĐẦU QUÉT NGAY'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildGCTrimWarning() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gcTrimWarningTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.amber.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.gcTrimWarningDesc,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanModeSelector() {
    return Card(
      child: Column(
        children: [
          _buildScanModeItem(
            value: 1,
            icon: Icons.delete_sweep_rounded,
            title: 'Chỉ file đã xóa',
            subtitle: 'Tìm kiếm các tệp tin đã bị xóa khỏi hệ thống.',
            color: Colors.red.shade400,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _buildScanModeItem(
            value: 2,
            icon: Icons.file_present_rounded,
            title: 'Chỉ file hiện có',
            subtitle: 'Quét và liệt kê các tệp tin đang tồn tại.',
            color: Colors.green.shade400,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _buildScanModeItem(
            value: 3,
            icon: Icons.all_inclusive_rounded,
            title: 'Tất cả file',
            subtitle: 'Kết hợp quét cả file hiện có và file đã xóa.',
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildScanModeItem({
    required int value,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return InkWell(
      onTap: () => setState(() => _scanMode = value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: RadioListTile<int>(
          value: value,
          groupValue: _scanMode,
          onChanged: (v) => setState(() => _scanMode = v!),
          activeColor: AppTheme.primaryColor,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          controlAffinity: ListTileControlAffinity.trailing,
        ),
      ),
    );
  }

  Widget _buildPathSelector({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    required IconData icon,
    bool isSmall = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSmall)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                readOnly: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: label,
                  prefixIcon: Icon(icon, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: Colors.grey.shade200),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Icon(Icons.edit_note_rounded),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
