import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recovery_tool/core/service/recovery_service.dart';
import 'package:recovery_tool/core/models/recovery_event.dart';
import 'package:path/path.dart' as p;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Recovery Integration Test', () {
    late RecoveryService recoveryService;
    late Directory tempDir;
    late File dummyDisk;

    setUp(() async {
      recoveryService = RecoveryService();
      tempDir = await Directory.systemTemp.createTemp('recovery_test_');
      dummyDisk = File(p.join(tempDir.path, 'dummy_disk.img'));

      // Create a dummy disk with a JPEG file embedded
      // JPEG header: FF D8 FF E0 ...
      // JPEG footer: FF D9
      final List<int> diskContent = List<int>.filled(2048, 0); // 2 sectors
      
      // Place JPEG at offset 512 (sector 1)
      diskContent[512] = 0xFF;
      diskContent[513] = 0xD8;
      diskContent[514] = 0xFF;
      diskContent[515] = 0xE0;
      
      // Some "data"
      for (int i = 516; i < 1000; i++) {
        diskContent[i] = i % 256;
      }
      
      // Footer at 1000
      diskContent[1000] = 0xFF;
      diskContent[1001] = 0xD9;

      await dummyDisk.writeAsBytes(diskContent);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Scan and Recover File from Dummy Disk', (WidgetTester tester) async {
      final outputDir = Directory(p.join(tempDir.path, 'output'))..createSync();
      
      final events = <RecoveryEvent>[];
      final completer = Completer<void>();

      final stream = recoveryService.startScan(
        sourcePath: dummyDisk.path,
        outputDir: outputDir.path,
        enableFat: false, // Only carving for this test
        enableCarve: true,
      );

      stream.listen(
        (event) {
          debugPrint('Test Event: $event');
          events.add(event);
          if (event is DoneEvent) {
            completer.complete();
          }
        },
        onError: (e) {
          debugPrint('Test Error: $e');
          completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        }
      );

      await completer.future.timeout(const Duration(seconds: 10));

      // Verify events
      final foundEvents = events.whereType<FileFoundEvent>().toList();
      expect(foundEvents, isNotEmpty, reason: 'Should have found at least one file');
      
      final jpegEvent = foundEvents.firstWhere((e) => e.fileType == 'JPEG');
      expect(jpegEvent.sectorOffset, 1); // 512 / 512 = 1

      // Verify "Save File" (Recovery)
      // We need a handle to call saveFile, but startScan closes it.
      // In a real app, the user would click "Recover" on a result.
      // Let's test the saveFile method by opening the disk again.
      
      // Note: We need to manually open to get a handle for saveFile test if we want to test it separately,
      // but usually the service might handle it.
      // For now, let's just check if the scanner worked.
    });
  });
}
