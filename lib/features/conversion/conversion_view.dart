import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recovery_tool/core/theme/app_theme.dart';
import 'package:disks_desktop/disks_desktop.dart';
import 'package:path/path.dart' as p;
import 'package:recovery_tool/core/service/recovery_service.dart';
import 'package:recovery_tool/core/models/recovery_event.dart';

class ConversionView extends StatefulWidget {
  final String e01Path;
  final Function(Disk disk) onConversionDone;

  const ConversionView({
    super.key,
    required this.e01Path,
    required this.onConversionDone,
  });

  @override
  State<ConversionView> createState() => _ConversionViewState();
}

class _ConversionViewState extends State<ConversionView> {
  double _progress = 0;
  String _status = 'Đang khởi tạo...';
  bool _isConverting = true;
  String? _outputPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startConversion();
    });
  }

  Future<void> _startConversion() async {
    final service = context.read<RecoveryService>();
    final directory = p.dirname(widget.e01Path);
    final filename = p.basenameWithoutExtension(widget.e01Path);
    _outputPath = p.join(directory, '$filename.dd');

    setState(() {
      _status = 'Đang giải mã file E01...';
    });

    final stream = service.convertE01(
      e01Path: widget.e01Path,
      outputPath: _outputPath!,
    );

    await for (final event in stream) {
      if (!mounted) return;

      if (event is ProgressEvent) {
        setState(() {
          _progress = event.percent / 100;
          _status = 'Đang chuyển đổi: ${event.percent.toStringAsFixed(1)}%';
        });
      } else if (event is ErrorEvent) {
        setState(() {
          _isConverting = false;
          _status = 'Lỗi: ${event.message}';
        });
        return;
      } else if (event is DoneEvent) {
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _progress = 1.0;
      _isConverting = false;
      _status = 'Chuyển đổi hoàn tất!';
    });

    // Chờ 1 giây rồi tự động chuyển sang callback
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    final file = File(_outputPath!);
    if (!await file.exists()) {
      setState(() {
        _status = 'Lỗi: Không tìm thấy file đích sau khi chuyển đổi.';
      });
      return;
    }

    final size = await file.length();
    final disk = Disk(
      blockSize: 512,
      busType: 'IMAGE',
      description: 'Converted Raw Image',
      device: _outputPath!,
      devicePath: _outputPath!,
      readOnly: true,
      removable: false,
      system: false,
      logicalBlockSize: 512,
      mountpoints: const [],
      raw: _outputPath!,
      size: size,
    );

    widget.onConversionDone(disk);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppTheme.cyberGlass,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.cyberCyan.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sync_rounded, color: AppTheme.cyberCyan, size: 64),
            const SizedBox(height: 32),
            const Text(
              'CHUYỂN ĐỔI ĐỊNH DẠNG E01',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _status,
              style: TextStyle(
                color: AppTheme.cyberCyan.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 48),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 12,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.cyberCyan),
              ),
            ),
            const SizedBox(height: 32),
            if (!_isConverting)
              const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 48),
          ],
        ),
      ),
    );
  }
}
