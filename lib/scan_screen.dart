// lib/features/scan/scan_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'preview_screen.dart';
import 'core/features/scan/scan_provider.dart';
import '../../core/models/recovery_event.dart';

class ScanScreen extends ConsumerStatefulWidget {
  final String devicePath;
  final String outputDir;
  final bool enableFat;
  final bool enableCarve;

  const ScanScreen({
    super.key,
    required this.devicePath,
    required this.outputDir,
    this.enableFat = true,
    this.enableCarve = true,
  });

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  late final ScanParams _params;
  double _percent = 0;
  int _speed = 0;
  int _found = 0;
  bool _done = false;
  Duration _elapsed = Duration.zero;
  final List<String> _logs = [];

  int _lastLoggedMB = -1;

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
    _params = ScanParams(
      devicePath: widget.devicePath,
      outputDir: widget.outputDir,
      enableFat: widget.enableFat,
      enableCarve: widget.enableCarve,
    );
    _logs.add('Khởi tạo phiên quét cho ${widget.devicePath}');
  }

  @override
  Widget build(BuildContext context) {
    // Watch để đảm bảo provider luôn active khi widget tồn tại
    final scanAsync = ref.watch(scanStreamProvider(_params));
    
    // Lắng nghe stream — mỗi event update local state
    ref.listen(scanStreamProvider(_params), (prev, next) {
      next.when(
        data: (event) {
          switch (event) {
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
              setState(() { _done = true; _elapsed = duration; });
              _addLog('HOÀN THÀNH: Tìm thấy $totalFound file trong ${duration.inSeconds}s');

            case ErrorEvent(:final message):
              _addLog('LỖI: $message');
              // Khi bị rút đĩa (detach), ErrorEvent sẽ được gửi. 
              // Ta cho phép người dùng xem kết quả đã có.
              setState(() { _done = true; });
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        title: scanAsync.when(
          data: (_) => Text(_done ? 'Hoàn thành' : 'Đang quét...'),
          error: (e, __) => const Text('Lỗi khởi tạo'),
          loading: () => const Text('Đang khởi động...'),
        ),
        actions: [
          if (!_done)
            IconButton(
              onPressed: () {
                ref.read(recoveryServiceProvider).cancel();
                setState(() { _done = true; });
              },
              icon: const Icon(Icons.stop_circle_outlined, color: Colors.red),
            ),
        ],
      ),
      body: Column(children: [
        // ── Progress bar ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_percent.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text('$_speed MB/s',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _percent / 100,
                minHeight: 12,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(label: 'Tìm thấy', value: '$_found'),
                  _StatItem(label: 'Thời gian', value: _elapsed.inSeconds > 0 ? '${_elapsed.inMinutes}:${(_elapsed.inSeconds % 60).toString().padLeft(2, '0')}' : '--:--'),
                ],
              ),
            ],
          ),
        ),

        // Nút xem kết quả - hiện sớm nếu có file, hoặc khi đã xong
        if (files.isNotEmpty || _done)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              height: 50,
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
                icon: Icon(_done ? Icons.remove_red_eye : Icons.visibility_outlined),
                label: Text(
                  _done ? 'XEM KẾT QUẢ' : 'XEM TRỰC TIẾP ($_found file)', 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _done ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),

        const Divider(height: 1),

        // ── Tab Logs và Files ─────────────────────────────────────
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Files tìm thấy'),
                    Tab(text: 'Nhật ký'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // List Files
                      ListView.builder(
                        itemCount: files.length,
                        itemBuilder: (ctx, i) => _FileFoundTile(event: files[files.length - 1 - i]),
                      ),
                      // List Logs
                      Container(
                        color: Colors.black.withOpacity(0.05),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _logs.length,
                          itemBuilder: (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(_logs[i], style: const TextStyle(fontFamily: 'Courier', fontSize: 11)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Widgets phụ ─────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color  color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 12, color: color,
              fontWeight: FontWeight.w500)),
    );
  }
}

class _FileFoundTile extends StatelessWidget {
  final FileFoundEvent event;
  const _FileFoundTile({required this.event});

  static const _icons = {
    'JPEG': Icons.image_outlined,
    'PNG':  Icons.image_outlined,
    'CR2':  Icons.camera_outlined,
    'NEF':  Icons.camera_outlined,
    'MP4':  Icons.videocam_outlined,
    'MOV':  Icons.videocam_outlined,
    'PDF':  Icons.picture_as_pdf_outlined,
    'DOCX': Icons.description_outlined,
  };

  static const _colors = {
    'JPEG': Colors.orange,
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
    final color = _colors[event.fileType] ?? Colors.grey;
    final icon  = _icons[event.fileType]  ?? Icons.insert_drive_file_outlined;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(event.filename,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${event.fileType} · ${_formatSize(event.fileSize)} · sector ${event.sectorOffset}',
        style: const TextStyle(fontSize: 11),
      ),
      dense: true,
    );
  }
}