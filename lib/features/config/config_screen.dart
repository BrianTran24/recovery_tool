import 'dart:io';
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
  bool _enableFat = true;
  bool _enableCarve = true;
  String? _outputDir;
  final TextEditingController _pathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Mặc định folder khôi phục trong Home
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      _outputDir = '$home/RecoveredFiles';
      _pathController.text = _outputDir!;
    }
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

    if (!_enableFat && !_enableCarve) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn ít nhất một phương thức quét (Quét nhanh hoặc Quét sâu)'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanScreen(
          devicePath: path,
          outputDir: _outputDir!,
          enableFat: _enableFat,
          enableCarve: _enableCarve,
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
                title: Text(widget.disk.devicePath ?? 'Unknown'),
                subtitle: Text('Dung lượng: ${(widget.disk.size ?? 0) ~/ (1024 * 1024 * 1024)} GB'),
              ),
            ),
            const SizedBox(height: 24),
            
            Text('Tùy chọn quét', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.flash_on, color: Colors.orange),
                    title: const Text('Quét nhanh (File System)'),
                    subtitle: const Text('Loại 1: Tìm file dựa trên bảng mục lục. Nhanh, giữ nguyên tên file và thư mục.'),
                    value: _enableFat,
                    onChanged: (v) => setState(() => _enableFat = v),
                  ),
                  const Divider(indent: 64, endIndent: 16, height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.search, color: Colors.deepPurple),
                    title: const Text('Quét sâu (Signature Carving)'),
                    subtitle: const Text('Loại 2: Quét từng sector để tìm dữ liệu thô. Dành cho thẻ bị format, mất tên file.'),
                    value: _enableCarve,
                    onChanged: (v) => setState(() => _enableCarve = v),
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
