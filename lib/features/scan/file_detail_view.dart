import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:recovery_tool/core/models/recovery_event.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:recovery_tool/l10n/app_localizations.dart';

class FileDetailView extends StatelessWidget {
  final FileFoundEvent event;
  final String outputDir;

  const FileDetailView({
    super.key,
    required this.event,
    required this.outputDir,
  });

  String _formatSize(int bytes) {
    if (bytes > 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
    if (bytes > 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '$bytes B';
  }

  String _getStatusText(BuildContext context, int status) {
    final l10n = AppLocalizations.of(context)!;
    switch (status) {
      case 1:
        return l10n.fileDetailHealthy;
      case 2:
        return l10n.fileDetailOrphaned;
      case 3:
        return l10n.fileDetailCarved;
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final normalizedType = canonicalFileType(event.fileType);
    final isImage = isImageFileType(normalizedType);
    final filePath = p.join(outputDir, event.folder, event.filename);
    
    return Scaffold(
      backgroundColor: AppTheme.cyberDeepNavy,
      appBar: AppBar(
        title: Text(l10n.fileDetailTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Side: Large Preview
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: isImage
                    ? Image.file(
                        File(filePath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => _buildNoPreview(normalizedType),
                      )
                    : _buildNoPreview(normalizedType),
              ),
            ),
          ),

          // Right Side: Properties & Actions
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.cyberGlass,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.fileDetailProperties,
                    style: const TextStyle(
                      color: AppTheme.cyberCyan,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildPropertyItem(l10n.fileDetailName, event.filename),
                        _buildPropertyItem(l10n.fileDetailType, normalizedType),
                        _buildPropertyItem(l10n.fileDetailSize, _formatSize(event.fileSize)),
                        _buildPropertyItem(l10n.fileDetailLocation, event.folder.isEmpty ? '/' : event.folder),
                        _buildPropertyItem(l10n.fileDetailOffset, '#${event.sectorOffset}'),
                        _buildPropertyItem(l10n.fileDetailModified, event.modifiedTime),
                        _buildStatusItem(context, l10n.fileDetailStatus, event.status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => launchUrl(Uri.file(filePath)),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(l10n.fileDetailOpenFile),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.cyberCyan.withValues(alpha: 0.2),
                            foregroundColor: AppTheme.cyberCyan,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(Uri.directory(p.dirname(filePath))),
                          icon: const Icon(Icons.folder_open_rounded),
                          label: Text(l10n.fileDetailShowInFolder),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: const BorderSide(color: Colors.white10),
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(BuildContext context, String label, int status) {
    final color = _getStatusColor(status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Text(
              _getStatusText(context, status),
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoPreview(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getIconForType(type),
            size: 80,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          const SizedBox(height: 16),
          Text(
            'Preview not available for $type',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'JPEG':
      case 'PNG':
        return Icons.image_rounded;
      case 'CR2':
      case 'NEF':
        return Icons.camera_rounded;
      case 'MP4':
      case 'MOV':
        return Icons.videocam_rounded;
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      case 'DOCX':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
