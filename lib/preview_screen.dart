import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'core/models/recovery_event.dart';
import 'core/features/scan/scan_provider.dart';

class PreviewScreen extends ConsumerWidget {
  final String outputDir;

  const PreviewScreen({
    super.key,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final files = ref.watch(foundFilesProvider);

    final images = files.where((e) => isImageFileType(e.fileType)).toList();
    final videos = files.where((e) {
      final type = canonicalFileType(e.fileType);
      return type == 'MP4' || type == 'MOV';
    }).toList();
    final others = files.where((e) {
      final type = canonicalFileType(e.fileType);
      return !isImageFileType(type) && type != 'MP4' && type != 'MOV';
    }).toList();

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
            _FileGrid(files: images, outputDir: outputDir),
            _FileGrid(files: videos, outputDir: outputDir),
            _FileGrid(files: others, outputDir: outputDir),
          ],
        ),
      ),
    );
  }
}

class _FileGrid extends StatelessWidget {
  final List<FileFoundEvent> files;
  final String outputDir;

  const _FileGrid({required this.files, required this.outputDir});

  Future<void> _openFile(String filename) async {
    // Chuẩn hóa path để tránh lỗi mix slashes
    final normalizedOutputDir = p.normalize(outputDir);
    final filePath = p.join(normalizedOutputDir, filename);
    final file = File(filePath);
    
    if (await file.exists()) {
      if (Platform.isWindows) {
        // Sử dụng start để mở bằng app mặc định trên Windows
        // Bọc đường dẫn trong ngoặc kép để xử lý khoảng trắng
        Process.run('cmd', ['/c', 'start', '', filePath]);
      } else if (Platform.isMacOS) {
        Process.run('open', [filePath]);
      } else if (Platform.isLinux) {
        Process.run('xdg-open', [filePath]);
      } else {
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      }
    }
  }

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
        childAspectRatio: 0.8,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final type = canonicalFileType(file.fileType);
        final isImage = isImageFileType(type);
        final filePath = p.join(outputDir, file.filename);

        return InkWell(
          onTap: () => _openFile(file.filename),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: Colors.grey[200],
                    child: isImage
                        ? Image.file(
                            File(filePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(_getIcon(file.fileType), size: 40, color: Colors.grey),
                          )
                        : Icon(_getIcon(file.fileType), size: 40, color: Colors.grey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatSize(file.fileSize),
                        style: const TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                      if (file.modifiedTime.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          file.modifiedTime,
                          style: const TextStyle(fontSize: 8, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatSize(int bytes) {
    if (bytes > 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    if (bytes > 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  IconData _getIcon(String type) {
    switch (canonicalFileType(type)) {
      case 'JPEG':
      case 'PNG':
        return Icons.image;
      case 'MP4':
      case 'MOV':
        return Icons.videocam;
      case 'PDF':
        return Icons.picture_as_pdf;
      default:
        return Icons.insert_drive_file;
    }
  }
}
