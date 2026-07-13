import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../models/recovery_event.dart';

class PhotoRecRunner {
  Process? _process;
  final StreamController<RecoveryEvent> _controller = StreamController<RecoveryEvent>.broadcast();

  Stream<RecoveryEvent> get events => _controller.stream;

  Future<void> run({
    required String binaryPath,
    required String devicePath,
    required String outputDir,
    bool wholespace = true,
  }) async {
    try {
      final args = [
        '/d', outputDir,
        '/cmd', devicePath,
        'partition_none',
        wholespace ? 'wholespace' : 'freespace',
        'search',
      ];

      _process = await Process.start(binaryPath, args);

      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_parseStdout);

      _startLogMonitor(outputDir);

      final exitCode = await _process!.exitCode;
      if (exitCode != 0) {
        _controller.add(ErrorEvent(code: exitCode, message: 'PhotoRec exited with code $exitCode'));
      }
    } catch (e) {
      _controller.add(ErrorEvent(code: -1, message: 'Failed to start PhotoRec: $e'));
    }
  }

  void _parseStdout(String line) {
    final event = parseProgress(line);
    if (event != null) _controller.add(event);
  }

  static ProgressEvent? parseProgress(String line) {
    // Example: "Pass 0 - Reading sector 1234/5678, 22%"
    final progressMatch = RegExp(r'(\d+)%').firstMatch(line);
    if (progressMatch != null) {
      final percent = double.tryParse(progressMatch.group(1)!) ?? 0;
      return ProgressEvent(
        percent: percent,
        scannedBytes: 0,
        speedMbps: 0,
      );
    }
    return null;
  }

  void _startLogMonitor(String outputDir) {
    final logFile = File(p.join(outputDir, 'photorec.log'));
    int lastPosition = 0;

    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_process == null) {
        timer.cancel();
        return;
      }

      if (logFile.existsSync()) {
        final length = logFile.lengthSync();
        if (length > lastPosition) {
          final stream = logFile.openRead(lastPosition, length);
          stream.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
            if (line.startsWith('File found:')) {
              _parseLogLine(line);
            }
          });
          lastPosition = length;
        }
      }
    });
  }

  void _parseLogLine(String line) {
    final event = parseLogEntry(line);
    if (event != null) _controller.add(event);
  }

  static FileFoundEvent? parseLogEntry(String line) {
    // File found: f0000000.jpg at 1024
    final match = RegExp(r'File found: (.*) at (\d+)').firstMatch(line);
    if (match != null) {
      final filename = match.group(1)!;
      final sector = int.tryParse(match.group(2)!) ?? 0;
      final type = filename.split('.').last.toUpperCase();

      return FileFoundEvent(
        fileType: type,
        filename: filename,
        fileSize: 0,
        sectorOffset: sector,
      );
    }
    return null;
  }

  void stop() {
    _process?.kill();
    _process = null;
  }
}
