import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'core/models/recovery_event.dart';
import 'features/scan/bloc/scan_bloc.dart';
import 'features/scan/bloc/scan_state.dart';
import 'core/theme/app_theme.dart';

class PreviewScreen extends StatelessWidget {
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
      if (Platform.isMacOS) {
        Process.run('open', [outputDir]);
      } else if (Platform.isWindows) {
        Process.run('explorer.exe', [outputDir]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ScanBloc, ScanState>(
      builder: (context, state) {
        final files = state.foundFiles;

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
              title: const Text('Kho dữ liệu khôi phục'),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ElevatedButton.icon(
                    onPressed: _openFolder,
                    icon: const Icon(Icons.folder_open_rounded, size: 18),
                    label: const Text('Mở Thư mục'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              ],
              bottom: TabBar(
                indicatorColor: AppTheme.primaryColor,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: Colors.grey,
                tabs: [
                  Tab(text: 'Hình ảnh (${images.length})'),
                  Tab(text: 'Video (${videos.length})'),
                  Tab(text: 'Tài liệu (${others.length})'),
                ],
              ),
            ),
            body: Container(
              color: Colors.grey.shade50,
              child: TabBarView(
                children: [
                  _FileGrid(files: images, outputDir: outputDir),
                  _FileGrid(files: videos, outputDir: outputDir),
                  _FileGrid(files: others, outputDir: outputDir),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FileGrid extends StatelessWidget {
  final List<FileFoundEvent> files;
  final String outputDir;

  const _FileGrid({required this.files, required this.outputDir});

  Future<void> _openFile(String filename) async {
    final normalizedOutputDir = p.normalize(outputDir);
    final filePath = p.join(normalizedOutputDir, filename);
    final file = File(filePath);
    
    if (await file.exists()) {
      if (Platform.isWindows) {
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Chưa tìm thấy file nào ở mục này', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final type = canonicalFileType(file.fileType);
        final isImage = isImageFileType(type);
        final filePath = p.join(outputDir, file.filename);

        return _FileGridItem(
          file: file,
          isImage: isImage,
          filePath: filePath,
          onTap: () => _openFile(file.filename),
        );
      },
    );
  }
}

class _FileGridItem extends StatelessWidget {
  final FileFoundEvent file;
  final bool isImage;
  final String filePath;
  final VoidCallback onTap;

  const _FileGridItem({
    required this.file,
    required this.isImage,
    required this.filePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.grey.shade100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    isImage
                        ? Image.file(
                            File(filePath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildIconPlaceholder(),
                          )
                        : _buildIconPlaceholder(),
                    if (!isImage && (canonicalFileType(file.fileType) == 'MP4' || canonicalFileType(file.fileType) == 'MOV'))
                      const Center(
                        child: CircleAvatar(
                          backgroundColor: Colors.black26,
                          child: Icon(Icons.play_arrow_rounded, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatSize(file.fileSize),
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                      Text(
                        canonicalFileType(file.fileType),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                  if (file.folder.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.folder_rounded, size: 10, color: Colors.amber),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            file.folder,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9, color: Colors.amber),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPlaceholder() {
    IconData icon;
    Color color;
    switch (canonicalFileType(file.fileType)) {
      case 'MP4':
      case 'MOV':
        icon = Icons.videocam_rounded;
        color = Colors.red;
        break;
      case 'PDF':
        icon = Icons.picture_as_pdf_rounded;
        color = Colors.orange;
        break;
      case 'JPEG':
      case 'PNG':
      case 'JPG':
        icon = Icons.image_rounded;
        color = Colors.blue;
        break;
      default:
        icon = Icons.insert_drive_file_rounded;
        color = Colors.grey;
    }
    return Icon(icon, size: 32, color: color.withValues(alpha: 0.5));
  }

  String _formatSize(int bytes) {
    if (bytes > 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    if (bytes > 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }
}
