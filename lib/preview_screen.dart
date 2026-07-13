import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/models/recovery_event.dart';

class PreviewScreen extends StatelessWidget {
  final List<FileFoundEvent> files;
  final String outputDir;

  const PreviewScreen({
    super.key,
    required this.files,
    required this.outputDir,
  });

  Future<void> _openFolder() async {
    final uri = Uri.directory(outputDir);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback cho macOS/Windows nếu URI directory không chạy
      if (Platform.isMacOS) {
        Process.run('open', [outputDir]);
      } else if (Platform.isWindows) {
        Process.run('explorer.exe', [outputDir]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = files.where((e) => ['JPEG', 'PNG', 'CR2', 'NEF'].contains(e.fileType)).toList();
    final videos = files.where((e) => ['MP4', 'MOV'].contains(e.fileType)).toList();
    final others = files.where((e) => !['JPEG', 'PNG', 'CR2', 'NEF', 'MP4', 'MOV'].contains(e.fileType)).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kết quả khôi phục'),
          actions: [
            TextButton.icon(
              onPressed: _openFolder,
              icon: const Icon(Icons.folder_open, color: Colors.white),
              label: const Text('Mở thư mục', style: TextStyle(color: Colors.white)),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Hình ảnh', icon: Icon(Icons.image)),
              Tab(text: 'Video', icon: Icon(Icons.videocam)),
              Tab(text: 'Khác', icon: Icon(Icons.insert_drive_file)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FileGrid(files: images),
            _FileGrid(files: videos),
            _FileGrid(files: others),
          ],
        ),
      ),
    );
  }
}

class _FileGrid extends StatelessWidget {
  final List<FileFoundEvent> files;
  const _FileGrid({required this.files});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(child: Text('Không tìm thấy file nào'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: Colors.grey[200],
                  child: Icon(_getIcon(file.fileType), size: 40, color: Colors.grey),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  file.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'JPEG':
      case 'PNG':
        return Icons.image;
      case 'MP4':
      case 'MOV':
        return Icons.videocam;
      default:
        return Icons.insert_drive_file;
    }
  }
}
