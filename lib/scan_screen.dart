// lib/features/scan/scan_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'preview_screen.dart';
import 'core/features/scan/scan_provider.dart';
import 'core/models/recovery_event.dart';
import 'core/service/recovery_service.dart';
import 'core/theme/app_theme.dart';

class ScanScreen extends ConsumerStatefulWidget {
  final String sourcePath;
  final String outputDir;
  final bool enableFat;
  final bool enableCarve;
  final int scanMode;
  final String referenceVideo;

  const ScanScreen({
    super.key,
    required this.sourcePath,
    required this.outputDir,
    this.enableFat = true,
    this.enableCarve = true,
    this.scanMode = 1,
    this.referenceVideo = '',
  });

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with SingleTickerProviderStateMixin {
  late final ScanParams _params;
  double _percent = 0;
  int _speed = 0;
  int _found = 0;
  bool _done = false;
  List<FileSystemInfo> _fileSystems = [];
  Duration _elapsed = Duration.zero;
  final List<String> _logs = [];
  int _lastLoggedMB = -1;

  late TabController _tabController;

  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      _logs.insert(0, '[${DateTime.now().toString().split(' ').last.substring(0, 8)}] $msg');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _params = ScanParams(
      sourcePath: widget.sourcePath,
      outputDir: widget.outputDir,
      enableFat: widget.enableFat,
      enableCarve: widget.enableCarve,
      scanMode: widget.scanMode,
      referenceVideo: widget.referenceVideo,
    );
    _logs.add('Khởi tạo phiên quét cho ${widget.sourcePath}');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch để đảm bảo provider luôn active khi widget tồn tại
    ref.watch(scanStreamProvider(_params));
    
    ref.listen(scanStreamProvider(_params), (prev, next) {
      next.when(
        data: (event) {
          switch (event) {
            case FsIdentifiedEvent(:final filesystems):
              setState(() {
                _fileSystems = filesystems;
              });
              for (var fs in filesystems) {
                _addLog('NHẬN DIỆN: Hệ thống tập tin ${fs.typeName} tại sector ${fs.offset}');
              }
              if (filesystems.isEmpty) {
                _addLog('NHẬN DIỆN: Không tìm thấy hệ thống tập tin hợp lệ. Chuyển sang quét thô (Signature Carving).');
              }

            case ProgressEvent(:final percent, :final scannedBytes, :final speedMbps):
              setState(() { 
                _percent = percent; 
                _speed = speedMbps; 
              });
              
              final currentMB = scannedBytes ~/ (10 * 1024 * 1024);
              if (currentMB > _lastLoggedMB) {
                 _addLog('Đang quét Sector: ${scannedBytes ~/ 512} (${percent.toStringAsFixed(1)}%)');
                 _lastLoggedMB = currentMB;
              }

            case FileFoundEvent(:final filename, :final fileType):
              ref.read(foundFilesProvider.notifier).add(event);
              setState(() { _found++; });
              _addLog('TÌM THẤY: $filename ($fileType)');

            case DoneEvent(:final duration, :final totalFound):
               setState(() { _done = true; _elapsed = duration; _percent = 100; });
              _addLog('HOÀN THÀNH: Tìm thấy $totalFound file trong ${duration.inSeconds}s');

            case ErrorEvent(:final message, :final isHardwareFailure):
              _addLog('LỖI: $message');
              setState(() {
                _done = true;
              });
              _showErrorDialog(context, message, isHardwareFailure);
          }
        },
        error: (err, stack) {
          _addLog('LỖI STREAM: $err');
        },
        loading: () {},
      );
    });

    final files = ref.watch(foundFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_done ? 'Kết quả Quét' : 'Đang xử lý dữ liệu...'),
        actions: [
          if (!_done)
            TextButton.icon(
              onPressed: () {
                ref.read(recoveryServiceProvider).cancel();
                setState(() { _done = true; });
              },
              icon: const Icon(Icons.stop_circle_rounded, color: Colors.red),
              label: const Text('Dừng', style: TextStyle(color: Colors.red)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── File System Info ─────────────────────────────────────
          if (_fileSystems.isNotEmpty) _buildFsInfo(context),

          // ── Progress & Stats Header ──────────────────────────────
          _buildProgressHeader(context),

          // ── View Results Button ──────────────────────────────────
          if (files.isNotEmpty || _done)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PreviewScreen(
                          outputDir: widget.outputDir,
                        ),
                      ),
                    );
                  },
                  icon: Icon(_done ? Icons.check_circle_rounded : Icons.visibility_rounded),
                  label: Text(_done ? 'XEM TOÀN BỘ KẾT QUẢ' : 'XEM TRỰC TIẾP ($_found file)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _done ? Colors.green.shade600 : AppTheme.primaryColor,
                  ),
                ),
              ),
            ),

          // ── Tab Section ──────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Tệp tin tìm thấy'),
                    Tab(text: 'Nhật ký hệ thống'),
                  ],
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: AppTheme.primaryColor,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // List Files
                      files.isEmpty 
                        ? _buildEmptyState(Icons.find_in_page_rounded, 'Đang tìm kiếm tệp tin...')
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: files.length,
                            separatorBuilder: (context, index) => Divider(height: 1, indent: 72, color: Colors.grey.shade100),
                            itemBuilder: (ctx, i) => _FileFoundTile(event: files[files.length - 1 - i]),
                          ),
                      // List Logs
                      Container(
                        color: Colors.grey.shade50,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _logs.length,
                          itemBuilder: (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              _logs[i], 
                              style: TextStyle(
                                fontFamily: 'monospace', 
                                fontSize: 11, 
                                color: _logs[i].contains('LỖI') ? Colors.red : Colors.blueGrey.shade700,
                              ),
                            ),
                          ),
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
    );
  }

  Widget _buildProgressHeader(BuildContext context) {
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
                    '${_percent.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Text('Tiến độ quét', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$_speed MB/s',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text('Tốc độ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _percent / 100,
              minHeight: 10,
              backgroundColor: Colors.blue.shade50,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _buildStatCard('TÌM THẤY', '$_found', Icons.insert_drive_file_rounded, Colors.orange)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('THỜI GIAN', _formatDuration(_elapsed), Icons.timer_rounded, Colors.blue)),
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
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildFsInfo(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      child: Wrap(
        spacing: 12,
        children: _fileSystems.map((fs) => Chip(
          avatar: const Icon(Icons.storage_rounded, size: 16, color: Colors.white),
          label: Text(
            '${fs.typeName} (@${fs.offset})',
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryColor,
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )).toList(),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}";
  }

  void _showErrorDialog(BuildContext context, String message, bool isHardware) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isHardware ? Icons.memory_rounded : Icons.error_outline_rounded,
              color: Colors.red,
            ),
            const SizedBox(width: 12),
            Text(isHardware ? 'Lỗi Phần Cứng' : 'Lỗi Hệ Thống'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ĐÃ HIỂU'),
          ),
        ],
      ),
    );
  }
}

class _FileFoundTile extends StatelessWidget {
  final FileFoundEvent event;
  const _FileFoundTile({required this.event});

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

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(
        event.filename,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Wrap(
          spacing: 8,
          children: [
            _buildBadge(normalizedType, color),
            _buildBadge(_formatSize(event.fileSize), Colors.grey.shade600),
            if (event.folder.isNotEmpty)
              _buildBadge(event.folder, Colors.amber.shade800, isFolder: true),
          ],
        ),
      ),
      trailing: Text(
        '#${event.sectorOffset}',
        style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontFamily: 'monospace'),
      ),
      dense: false,
    );
  }

  Widget _buildBadge(String text, Color color, {bool isFolder = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFolder) ...[
            Icon(Icons.folder_rounded, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
