import 'dart:io';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:recovery_tool/core/service/recovery_service.dart';
import 'package:recovery_tool/core/models/recovery_event.dart';
import 'package:path/path.dart' as p;

void main() {
  group('E01 Conversion Unit Test', () {
    late RecoveryService recoveryService;
    late Directory tempDir;
    final e01Path = '/Users/hieutran/AndroidStudioProjects/recovery_sd/assets/test/eo1/nps-2009-canon2-gen1.E01';

    setUp(() async {
      recoveryService = RecoveryService();
      tempDir = await Directory.systemTemp.createTemp('e01_conv_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Convert E01 to RAW', () async {
      final outputPath = p.join(tempDir.path, 'output.raw');
      final completer = Completer<void>();
      final events = <RecoveryEvent>[];

      final stream = recoveryService.convertE01(
        e01Path: e01Path,
        outputPath: outputPath,
      );

      stream.listen(
        (event) {
          events.add(event);
          if (event is DoneEvent) {
            completer.complete();
          }
        },
        onError: (e) {
          completer.completeError(e);
        },
      );

      await completer.future.timeout(const Duration(minutes: 5));

      // Verify that we got progress events and a done event
      expect(events.whereType<ProgressEvent>(), isNotEmpty);
      expect(events.whereType<DoneEvent>(), isNotEmpty);

      // Verify the output file exists
      final outputFile = File(outputPath);
      expect(outputFile.existsSync(), isTrue);
      expect(outputFile.lengthSync(), greaterThan(0));
      
      print('E01 Conversion Successful. Output size: ${outputFile.lengthSync()} bytes');
    });
  });
}
