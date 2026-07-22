import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import 'features/scan/bloc/scan_bloc.dart';
import 'features/scan/bloc/scan_event.dart';
import 'features/scan/bloc/scan_state.dart';
import 'features/scan/widgets/semi_circle_progress.dart';
import 'features/scan/file_detail_view.dart';
import 'core/models/recovery_event.dart';
import 'package:recovery_tool/core/service/recovery_service.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:recovery_tool/l10n/app_localizations.dart';

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
  String _searchQuery = '';
  String _selectedCategory = 'All';
  
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
    
    // Configure Flutter image cache for better performance
    PaintingBinding.instance.imageCache.maximumSize = 100;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50 MB
    
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

        // 1. Apply Search and Category Filter first
        final filteredBySearchAndCategory = files.where((f) {
          final matchesSearch = f.filename.toLowerCase().contains(_searchQuery.toLowerCase());
          
          bool matchesCategory = true;
          if (_selectedCategory == 'Images') {
            matchesCategory = isImageFileType(f.fileType);
          } else if (_selectedCategory == 'Videos') {
            matchesCategory = isVideoFileType(f.fileType);
          } else if (_selectedCategory == 'Documents') {
            final type = canonicalFileType(f.fileType);
            matchesCategory = type == 'PDF' || type == 'DOCX';
          }
          
          return matchesSearch && matchesCategory;
        }).toList();

        // 2. Group filtered files by folder for the sidebar count
        final Map<String, List<FileFoundEvent>> folderGroups = {};
        for (var f in filteredBySearchAndCategory) {
          final folder = f.folder.isEmpty ? 'Root' : f.folder;
          folderGroups.putIfAbsent(folder, () => []).add(f);
        }
        final folders = folderGroups.keys.toList()..sort();
        
        if (_selectedFolder == null && folders.isNotEmpty) {
          _selectedFolder = folders.first;
        } else if (_selectedFolder != null && !folders.contains(_selectedFolder)) {
          // If the selected folder is no longer in the filtered list, we don't necessarily reset it, 
          // because the user might have filtered away all files in that folder.
          // But for the grid, we need to decide what to show.
        }

        // 3. Final display list (either from folder or the whole filtered list if no folder selected)
        List<FileFoundEvent> displayedFiles;
        if (_selectedFolder != null && folderGroups.containsKey(_selectedFolder)) {
          displayedFiles = folderGroups[_selectedFolder]!;
        } else {
          displayedFiles = filteredBySearchAndCategory;
        }
        
        // 4. Reverse list once for display (newest first)
        final reversedFiles = displayedFiles.reversed.toList();

        return Column(
          children: [
            _buildProgressHeader(context, l10n, state, done),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          l10n.scanTabFiles,
                          style: const TextStyle(
                            color: AppTheme.cyberCyan,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (state.fileSystems.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: _buildFsInfo(context, state.fileSystems),
                            ),
                          ),
                        ],
                      ],
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSidebarSection(Icons.folder_rounded, l10n.scanTabFiles),
                              Expanded(
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
                                            key: ValueKey(folder),
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
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              // Top Filter Bar
                              _buildTopFilterBar(context),
                              const Divider(height: 1, color: Colors.white10),
                              Expanded(
                                child: reversedFiles.isEmpty
                                    ? _buildEmptyState(Icons.find_in_page_rounded, l10n.scanSearchingFiles)
                                    : GridView.builder(
                                        padding: const EdgeInsets.all(16),
                                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 180,
                                          mainAxisExtent: 160,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                        itemCount: reversedFiles.length,
                                        itemBuilder: (context, index) {
                                          final file = reversedFiles[index];
                                          return _FileGridItem(
                                            key: ValueKey('${file.sectorOffset}_${file.filename}'),
                                            allFiles: reversedFiles,
                                            index: index,
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
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressHeader(BuildContext context, AppLocalizations l10n, ScanState state, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatCard(l10n.scanElapsed, _formatDuration(_elapsed), Icons.timer_rounded, Colors.blue),
                if (!done) ...[
                  const SizedBox(height: 12),
                  _buildStatCard(l10n.scanRemaining, _etr, Icons.hourglass_empty_rounded, Colors.green),
                ],
              ],
            ),
          ),
          const SizedBox(width: 48),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SemiCircleProgressIndicator(
                progress: state.percent / 100,
                label: done ? l10n.scanResults : l10n.scanProcessing,
                speed: done ? null : state.speed,
                size: 240,
              ),
              if (!done) ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.status == ScanStatus.paused) ...[
                      FilledButton.icon(
                        onPressed: () => context.read<ScanBloc>().add(ResumeScanEvent()),
                        icon: const Icon(Icons.play_circle_rounded, size: 24),
                        label: Text(l10n.scanResume, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.cyberCyan.withValues(alpha: 0.2),
                          foregroundColor: AppTheme.cyberCyan,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.read<ScanBloc>().add(CancelScanEvent()),
                        icon: const Icon(Icons.cancel_rounded, size: 24),
                        label: Text(l10n.scanCancel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white10),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ] else
                      FilledButton.icon(
                        onPressed: () => context.read<ScanBloc>().add(PauseScanEvent()),
                        icon: const Icon(Icons.pause_circle_rounded, size: 24),
                        label: Text(l10n.scanPause, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.orange.withValues(alpha: 0.2),
                          foregroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: () => launchUrl(Uri.directory(widget.outputDir)),
                      icon: const Icon(Icons.folder_open_rounded, size: 20),
                      label: Text(l10n.openFolder, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.cyberCyan.withValues(alpha: 0.2),
                        foregroundColor: AppTheme.cyberCyan,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: widget.onDone,
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      label: Text(l10n.scanNew, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
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
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: fileSystems.map((fs) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.cyberCyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storage_rounded, size: 12, color: AppTheme.cyberCyan),
            const SizedBox(width: 4),
            Text(
              '${fs.typeName} (@${fs.offset})',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.cyberCyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildTopFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white.withValues(alpha: 0.02),
      child: Row(
        children: [
          // Search Box
          SizedBox(
            width: 250,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search files...',
                hintStyle: const TextStyle(color: Colors.white24),
                prefixIcon: const Icon(Icons.search, size: 16, color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Category Chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', Icons.all_inclusive_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('Images', Icons.image_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('Videos', Icons.videocam_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('Documents', Icons.description_rounded),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedCategory == label;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.cyberCyan.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.cyberCyan.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? AppTheme.cyberCyan : Colors.white54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppTheme.cyberCyan : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarSection(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white24),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
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

class _FileGridItem extends StatefulWidget {
  final List<FileFoundEvent> allFiles;
  final int index;
  final String outputDir;
  
  const _FileGridItem({
    super.key,
    required this.allFiles,
    required this.index,
    required this.outputDir,
  });

  @override
  State<_FileGridItem> createState() => _FileGridItemState();
}

class _FileGridItemState extends State<_FileGridItem> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    final event = widget.allFiles[widget.index];
    final normalizedType = canonicalFileType(event.fileType);
    final color = _colors[normalizedType] ?? Colors.blueGrey;
    final icon  = _icons[normalizedType]  ?? Icons.insert_drive_file_rounded;
    final isImage = isImageFileType(normalizedType);
    final filePath = p.join(widget.outputDir, event.folder, event.filename);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FileDetailView(
                allFiles: widget.allFiles,
                initialIndex: widget.index,
                outputDir: widget.outputDir,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        hoverColor: Colors.white.withValues(alpha: 0.05),
        splashColor: AppTheme.cyberCyan.withValues(alpha: 0.1),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
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
        ),
      ),
    );
  }
}
