import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:recovery_tool/core/models/recovery_event.dart';
import 'package:recovery_tool/features/premium/premium_unlock_screen.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:recovery_tool/l10n/app_localizations.dart';

class FileDetailView extends StatefulWidget {
  final List<FileFoundEvent> allFiles;
  final int initialIndex;
  final String outputDir;
  final bool isPremium;

  const FileDetailView({
    super.key,
    required this.allFiles,
    required this.initialIndex,
    required this.outputDir,
    this.isPremium = false,
  });

  @override
  State<FileDetailView> createState() => _FileDetailViewState();
}

class _FileDetailViewState extends State<FileDetailView> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.allFiles.length - 1) {
      setState(() {
        _currentIndex++;
      });
    }
  }

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
    final event = widget.allFiles[_currentIndex];
    final normalizedType = canonicalFileType(event.fileType);
    final isImage = isImageFileType(normalizedType);
    final isVideo = isVideoFileType(normalizedType);
    final filePath = p.join(widget.outputDir, event.folder, event.filename);
    
    return Scaffold(
      backgroundColor: AppTheme.cyberDeepNavy,
      appBar: AppBar(
        title: Text(l10n.fileDetailTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Center(
              child: Text(
                '${_currentIndex + 1} / ${widget.allFiles.length}',
                style: const TextStyle(color: Colors.white38, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Side: Large Preview with Navigation
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
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
                            key: ValueKey(filePath),
                            errorBuilder: (context, error, stackTrace) => _buildNoPreview(normalizedType),
                          )
                        : (isVideo 
                            ? VideoPreview(videoPath: filePath, key: ValueKey(filePath))
                            : _buildNoPreview(normalizedType)),
                  ),
                ),
                
                // Navigation Overlay
                if (_currentIndex > 0)
                  Positioned(
                    left: 40,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _buildNavButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onPressed: _goToPrevious,
                        tooltip: l10n.fileDetailPrevious,
                      ),
                    ),
                  ),
                if (_currentIndex < widget.allFiles.length - 1)
                  Positioned(
                    right: 40,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: _buildNavButton(
                        icon: Icons.arrow_forward_ios_rounded,
                        onPressed: _goToNext,
                        tooltip: l10n.fileDetailNext,
                      ),
                    ),
                  ),
              ],
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
                    child: SingleChildScrollView(
                      key: ValueKey('info_$_currentIndex'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Filename & Status
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  event.filename,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildStatusBadge(context, event.status),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Quick Info Grid
                          Wrap(
                            spacing: 32,
                            runSpacing: 24,
                            children: [
                              _buildGridItem(Icons.category_outlined, l10n.fileDetailType, normalizedType),
                              _buildGridItem(Icons.data_usage_outlined, l10n.fileDetailSize, _formatSize(event.fileSize)),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Location (Full Width)
                          _buildGridItem(
                            Icons.folder_open_outlined,
                            l10n.fileDetailLocation,
                            event.folder.isEmpty ? '/' : event.folder,
                            isFullWidth: true,
                          ),
                          const SizedBox(height: 24),

                          const Divider(color: Colors.white10),
                          const SizedBox(height: 24),

                          // Technical Details
                          Row(
                            children: [
                              Expanded(child: _buildGridItem(Icons.speed_outlined, l10n.fileDetailOffset, '#${event.sectorOffset}')),
                              Expanded(child: _buildGridItem(Icons.access_time_outlined, l10n.fileDetailModified, event.modifiedTime)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (widget.isPremium)
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
                        const SizedBox(width: 12),
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
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _showPaywall(context, l10n),
                        icon: const Icon(Icons.workspace_premium_rounded),
                        label: Text(l10n.saveToDiskPremium),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaywall(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cyberDeepNavy,
        title: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Text(l10n.premiumFeature, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(l10n.upgradeRequiredDesc, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.skip, style: const TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PremiumUnlockScreen(outputDir: widget.outputDir),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
            child: Text(l10n.startRecovery),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(icon, color: Colors.white, size: 28),
          onPressed: onPressed,
          style: IconButton.styleFrom(
            hoverColor: AppTheme.cyberCyan.withValues(alpha: 0.2),
            padding: const EdgeInsets.all(12),
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(IconData icon, String label, String value, {bool isFullWidth = false}) {
    return SizedBox(
      width: isFullWidth ? double.infinity : 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, int status) {
    final color = _getStatusColor(status);
    return Container(
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

class VideoPreview extends StatefulWidget {
  final String videoPath;

  const VideoPreview({super.key, required this.videoPath});

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  late final player = Player();
  late final controller = VideoController(player);
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await player.open(Media(widget.videoPath), play: false);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error initializing video player: $e');
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
            SizedBox(height: 16),
            Text('Không thể xem video này', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Video(
            controller: controller,
            controls: MaterialVideoControls,
          ),
          StreamBuilder<bool>(
            stream: player.stream.playing,
            builder: (context, snapshot) {
              final isPlaying = snapshot.data ?? false;
              if (isPlaying) return const SizedBox.shrink();
              
              return GestureDetector(
                onTap: () => player.play(),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
