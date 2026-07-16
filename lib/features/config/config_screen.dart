import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:disks_desktop/disks_desktop.dart';
import '../../scan_screen.dart';

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
    // Mặc định folder khôi phục là E:\test theo yêu cầu
    _outputDir = r'E:\test';
    _pathController.text = _outputDir!;
    // Mặc định video tham chiếu (dùng để repair video thiếu moov).
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
        title: const Text('Cấu hình quét'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thông tin ổ đĩa
            Card(
              child: ListTile(
                leading: const Icon(Icons.storage, color: Colors.blue),
                title: Text(
                  widget.disk.raw.startsWith('/dev/')
                      ? (widget.disk.devicePath ?? 'Unknown')
                      : 'Ảnh backup: ${widget.disk.devicePath ?? 'Unknown'}',
                ),
                subtitle: Text(
                  widget.disk.raw.startsWith('/dev/')
                      ? 'Dung lượng: ${(widget.disk.size ?? 0) ~/ (1024 * 1024 * 1024)} GB'
                      : 'Làm việc trên ảnh chỉ đọc, không ghi vào thẻ gốc',
                ),
              ),
            ),
            if (!widget.disk.raw.startsWith('/dev/')) ...[
              const SizedBox(height: 12),
              const Card(
                color: Color(0xFFE8F4FF),
                child: ListTile(
                  leading: Icon(Icons.lock_outline, color: Colors.blue),
                  title: Text('Chế độ an toàn'),
                  subtitle: Text('Nguồn là file .img nên mọi thao tác sẽ chạy trên bản sao.'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            
            const Card(
              color: Color(0xFFF0F7FF),
              child: ListTile(
                leading: Icon(Icons.auto_fix_high, color: Colors.blue),
                title: Text('Chế độ khôi phục thông minh'),
                subtitle: Text('Hệ thống sẽ tự động kết hợp Quét cấu trúc (để giữ tên file) và Quét sâu (để tìm file bị mất dấu vết).'),
              ),
            ),
            
            const SizedBox(height: 24),
            Text('Trạng thái file cần tìm', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  RadioListTile<int>(
                    secondary: const Icon(Icons.delete_outline, color: Colors.red),
                    title: const Text('Chỉ file đã xóa'),
                    subtitle: const Text('Tìm kiếm những file đã bị xóa trước đó.'),
                    value: 1,
                    groupValue: _scanMode,
                    onChanged: (v) => setState(() => _scanMode = v!),
                  ),
                  const Divider(indent: 64, endIndent: 16, height: 1),
                  RadioListTile<int>(
                    secondary: const Icon(Icons.file_present, color: Colors.green),
                    title: const Text('Chỉ file hiện có'),
                    subtitle: const Text('Quét những file chưa bị xóa (file đang tồn tại).'),
                    value: 2,
                    groupValue: _scanMode,
                    onChanged: (v) => setState(() => _scanMode = v!),
                  ),
                  const Divider(indent: 64, endIndent: 16, height: 1),
                  RadioListTile<int>(
                    secondary: const Icon(Icons.all_inclusive, color: Colors.blue),
                    title: const Text('Tất cả file'),
                    subtitle: const Text('Quét cả file đã xóa và file hiện có.'),
                    value: 3,
                    groupValue: _scanMode,
                    onChanged: (v) => setState(() => _scanMode = v!),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Text('Thư mục lưu trữ', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pathController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _pickDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Duyệt'),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text('Video tham chiếu (để sửa video lỗi)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Dùng một video khỏe cùng máy quay để tự động dựng lại các video bị mất chỉ mục (moov) khi khôi phục.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _refController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _pickReferenceVideo,
                  icon: const Icon(Icons.movie_outlined),
                  label: const Text('Chọn'),
                ),
              ],
            ),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startScan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('BẮT ĐẦU QUÉT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
