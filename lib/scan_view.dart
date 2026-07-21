import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'features/scan/bloc/scan_bloc.dart';
import 'features/scan/bloc/scan_event.dart';
import 'features/scan/bloc/scan_state.dart';
import 'core/models/recovery_event.dart';
import 'core/service/recovery_service.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

class ScanView extends StatefulWidget {
  final String sourcePath;
  final String outputDir;
  final bool enableFat;
  final bool enableCarve;
  final int scanMode;
  final String referenceVideo;
  final VoidCallback? onDone;
  final VoidCallback? onCancel;

  const ScanView({
    super.key,
    required this.sourcePath,
    required this.outputDir,
    this.enableFat = true,
    this.enableCarve = true,
    this.scanMode = 1,
    this.referenceVideo = '',
    this.onDone,
    this.onCancel,
  });

  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> with SingleTickerProviderStateMixin {
  String? _selectedFolder;
  
  // Timing logic
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  String _etr = '--:--';

  void _startTimer(Duration initialOffset) {
    _timer?.cancel();
    _stopwatch.reset();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _elapsed = initialOffset + _stopwatch.elapsed;
      });
    });
  }

  void _stopTimer() {
    _stopwatch.stop();
    _timer?.cancel();
  }

  void _calculateETR(double percent) {
    if (percent <= 0 || percent >= 100) {
      _etr = '--:--';
      return;
    }
    
    final totalEstMs = (_elapsed.inMilliseconds / percent) * 100;
    final remainingMs = totalEstMs - _elapsed.inMilliseconds;
    if (remainingMs > 0) {
      final d = Duration(milliseconds: remainingMs.toInt());
      _etr = _formatDuration(d);
    } else {
      _etr = '--:--';
    }
  }

  @override
  void initState() {
    super.initState();
    final scanBloc = context.read<ScanBloc>();
    final state = scanBloc.state;

    if (state.status == ScanStatus.initial || state.status == ScanStatus.failure) {
      scanBloc.add(StartScanEvent(
        sourcePath: widget.sourcePath,
        outputDir: widget.outputDir,
        enableFat: widget.enableFat,
        enableCarve: widget.enableCarve,
        scanMode: widget.scanMode,
        referenceVideo: widget.referenceVideo,
      ));
      _startTimer(Duration.zero);
    } else if (state.status == ScanStatus.inProgress || state.status == ScanStatus.loading) {
      _elapsed = state.elapsed;
      _startTimer(state.elapsed);
    } else if (state.status == ScanStatus.success) {
      _elapsed = state.elapsed;
      _etr = '00:00';
      // No timer needed for finished scan
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<ScanBloc, ScanState>(
      listener: (context, state) {
        if (state.status == ScanStatus.success) {
          _stopTimer();
          _elapsed = state.elapsed;
          _etr = '00:00';
        } else if (state.status == ScanStatus.failure) {
          _stopTimer();
          if (state.errorMessage != null) {
            _showErrorDialog(context, state.errorMessage!, state.isHardwareFailure);
          }
        } else if (state.status == ScanStatus.paused) {
          _stopTimer();
        } else if (state.status == ScanStatus.inProgress && _timer == null) {
          _startTimer(state.elapsed);
        } else if (state.status == ScanStatus.initial) {
          widget.onCancel?.call();
        }
        _calculateETR(state.percent);
      },
      builder: (context, state) {
        final files = state.foundFiles;
        final done = state.status == ScanStatus.success || state.status == ScanStatus.failure;
        final paused = state.status == ScanStatus.paused;

        // Group files by folder
        final Map<String, List<FileFoundEvent>> folderGroups = {};
        for (var f in files) {
          final folder = f.folder.isEmpty ? 'Root' : f.folder;
          folderGroups.putIfAbsent(folder, () => []).add(f);
        }
        final folders = folderGroups.keys.toList()..sort();
        
        if (_selectedFolder == null && folders.isNotEmpty) {
          _selectedFolder = folders.first;
        } else if (_selectedFolder != null && !folders.contains(_selectedFolder)) {
          _selectedFolder = folders.isNotEmpty ? folders.first : null;
        }

        final displayedFiles = _selectedFolder != null ? folderGroups[_selectedFolder] ?? [] : [];

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    done ? l10n.scanResults : l10n.scanProcessing,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  if (!done)
                    Row(
                      children: [
                        if (paused) ...[
                          TextButton.icon(
                            onPressed: () {
                              context.read<ScanBloc>().add(ResumeScanEvent());
                            },
                            icon: const Icon(Icons.play_circle_rounded, color: AppTheme.cyberCyan),
                            label: Text(l10n.scanResume, style: const TextStyle(color: AppTheme.cyberCyan)),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () {
                              context.read<ScanBloc>().add(CancelScanEvent());
                            },
                            icon: const Icon(Icons.cancel_rounded, color: Colors.white54),
                            label: Text(l10n.scanCancel, style: const TextStyle(color: Colors.white54)),
                          ),
                        ] else
                          TextButton.icon(
                            onPressed: () {
                              context.read<ScanBloc>().add(PauseScanEvent());
                            },
                            icon: const Icon(Icons.pause_circle_rounded, color: Colors.orange),
                            label: Text(l10n.scanPause, style: const TextStyle(color: Colors.orange)),
                          ),
                      ],
                    ),
                ],
              ),
            ),

            if (state.fileSystems.isNotEmpty) _buildFsInfo(context, state.fileSystems),

            _buildProgressHeader(context, l10n, state, done),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      l10n.scanTabFiles,
                      style: const TextStyle(
                        color: AppTheme.cyberCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white10),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 180,
                          decoration: const BoxDecoration(
                            border: Border(right: BorderSide(color: Colors.white10)),
                          ),
                          child: folders.isEmpty
                              ? Center(
                                  child: Text(
                                    l10n.scanSearchingFiles,
                                    style: const TextStyle(color: Colors.white24, fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: folders.length,
                                  itemBuilder: (context, index) {
                                    final folder = folders[index];
                                    final isSelected = _selectedFolder == folder;
                                    final count = folderGroups[folder]?.length ?? 0;
                                    return ListTile(
                                      dense: true,
                                      selected: isSelected,
                                      selectedTileColor: AppTheme.cyberCyan.withValues(alpha: 0.1),
                                      leading: Icon(
                                        folder == 'Root' ? Icons.folder_special_rounded : Icons.folder_rounded,
                                        size: 18,
                                        color: isSelected ? AppTheme.cyberCyan : Colors.white54,
                                      ),
                                      title: Text(
                                        folder,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isSelected ? AppTheme.cyberCyan : Colors.white70,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSelected ? AppTheme.cyberCyan : Colors.white24,
                                        ),
                                      ),
                                      onTap: () => setState(() => _selectedFolder = folder),
                                    );
                                  },
                                ),
                        ),
                        Expanded(
                          child: displayedFiles.isEmpty
                              ? _buildEmptyState(Icons.find_in_page_rounded, l10n.scanSearchingFiles)
                              : GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 180,
                                    mainAxisExtent: 160,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: displayedFiles.length,
                                  itemBuilder: (context, index) {
                                    return _FileGridItem(
                                      event: displayedFiles[displayedFiles.length - 1 - index],
                                      outputDir: widget.outputDir,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressHeader(BuildContext context, AppLocalizations l10n, ScanState state, bool done) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${state.percent.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.cyberCyan,
                    ),
                  ),
                  Text(l10n.scanProgress, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${state.speed} MB/s',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(l10n.scanSpeed, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: state.percent / 100,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyberCyan),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatCard(l10n.scanFound, '${state.foundCount}', Icons.insert_drive_file_rounded, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(l10n.scanElapsed, _formatDuration(_elapsed), Icons.timer_rounded, Colors.blue)),
              const SizedBox(width: 16),
              if (!done)
                Expanded(child: _buildStatCard(l10n.scanRemaining, _etr, Icons.hourglass_empty_rounded, Colors.green)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildFsInfo(BuildContext context, List<FileSystemInfo> fileSystems) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: AppTheme.cyberCyan.withValues(alpha: 0.05),
      child: Wrap(
        spacing: 12,
        children: fileSystems.map((fs) => Chip(
          avatar: const Icon(Icons.storage_rounded, size: 16, color: AppTheme.cyberDeepNavy),
          label: Text(
            '${fs.typeName} (@${fs.offset})',
            style: const TextStyle(fontSize: 12, color: AppTheme.cyberDeepNavy, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.cyberCyan,
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide.none,
        )).toList(),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    if (hours > 0) {
      return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
    }
    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
  }

  void _showErrorDialog(BuildContext context, String message, bool isHardware) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cyberDeepNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            Icon(
              isHardware ? Icons.memory_rounded : Icons.error_outline_rounded,
              color: Colors.red,
            ),
            const SizedBox(width: 12),
            Text(isHardware ? l10n.scanHardwareError : l10n.scanSystemError, style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.scanUnderstand, style: const TextStyle(color: AppTheme.cyberCyan)),
          ),
        ],
      ),
    );
  }
}

class _FileGridItem extends StatelessWidget {
  final FileFoundEvent event;
  final String outputDir;
  
  const _FileGridItem({
    required this.event,
    required this.outputDir,
  });

  static const _icons = {
    'JPEG': Icons.image_rounded,
    'JPG':  Icons.image_rounded,
    'PNG':  Icons.image_rounded,
    'CR2':  Icons.camera_rounded,
    'NEF':  Icons.camera_rounded,
    'MP4':  Icons.videocam_rounded,
    'MOV':  Icons.videocam_rounded,
    'PDF':  Icons.picture_as_pdf_rounded,
    'DOCX': Icons.description_rounded,
  };

  static const _colors = {
    'JPEG': Colors.orange,
    'JPG':  Colors.orange,
    'PNG':  Colors.blue,
    'CR2':  Colors.purple,
    'NEF':  Colors.purple,
    'MP4':  Colors.red,
    'MOV':  Colors.red,
    'PDF':  Colors.deepOrange,
    'DOCX': Colors.indigo,
  };

  String _formatSize(int bytes) {
    if (bytes > 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    if (bytes > 1024)        return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '$bytes B';
  }

  @override
  Widget build(BuildContext context) {
    final normalizedType = canonicalFileType(event.fileType);
    final color = _colors[normalizedType] ?? Colors.blueGrey;
    final icon  = _icons[normalizedType]  ?? Icons.insert_drive_file_rounded;
    final isImage = isImageFileType(normalizedType);
    final filePath = p.join(outputDir, event.filename);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Preview Area
          Expanded(
            child: Container(
              color: Colors.white.withValues(alpha: 0.02),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isImage)
                    Image.file(
                      File(filePath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(icon, color: color.withValues(alpha: 0.2), size: 32),
                      ),
                    )
                  else
                    Center(
                      child: Icon(icon, color: color.withValues(alpha: 0.2), size: 32),
                    ),
                  
                  // Sector Offset Overlay
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${event.sectorOffset}',
                        style: const TextStyle(fontSize: 8, color: Colors.white70, fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Info Area
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event.filename,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        normalizedType,
                        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      _formatSize(event.fileSize),
                      style: const TextStyle(fontSize: 9, color: Colors.white38),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
