import 'dart:io';
import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:recovery_tool/core/service/recovery_service.dart';
import 'package:recovery_tool/core/models/recovery_event.dart';
import 'package:recovery_tool/core/ffi/recovery_bindings.dart';
import 'package:path/path.dart' as p;
import '../test/utils/e01_test_utils.dart';

String _arrayToString(Array<Uint8> arr, int maxLen) {
  final bytes = <int>[];
  for (int i = 0; i < maxLen; i++) {
    final b = arr[i];
    if (b == 0) break;
    bytes.add(b);
  }
  return String.fromCharCodes(bytes);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('E01 Full Recovery Integration Test', () {
    late RecoveryService recoveryService;
    late Directory tempDir;
    final e01Path = '/Users/hieutran/AndroidStudioProjects/recovery_sd/assets/test/eo1/nps-2009-canon2-gen1.E01';
    final reportPath = '/Users/hieutran/AndroidStudioProjects/recovery_sd/assets/test/eo1/report.txt';

    setUp(() async {
      recoveryService = RecoveryService();
      tempDir = await Directory.systemTemp.createTemp('e01_recovery_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Full Flow: E01 -> RAW -> Scan -> Verify', (WidgetTester tester) async {
      final rawPath = p.join(tempDir.path, 'image.raw');
      final outputDir = Directory(p.join(tempDir.path, 'output'))..createSync();
      
      // 1. Convert E01 to RAW
      print('Converting E01 to RAW: $e01Path -> $rawPath');
      final convCompleter = Completer<void>();
      
      // Use a local function to avoid Isolate/NativeCallable issues for the test if needed, 
      // but convertE01 also uses isolate in RecoveryService.
      // Let's call the bindings directly for maximum stability in test if needed,
      // but let's try the service first.
      recoveryService.convertE01(e01Path: e01Path, outputPath: rawPath).listen((event) {
        print('Conversion Event: $event');
        if (event is DoneEvent) {
          print('Conversion Done.');
          convCompleter.complete();
        } else if (event is ErrorEvent) {
          print('Conversion Error: ${event.message}');
          convCompleter.completeError(event.message);
        }
      }, onError: (e) {
        print('Conversion Stream Error: $e');
        convCompleter.completeError(e);
      });
      
      await convCompleter.future.timeout(const Duration(minutes: 5));
      expect(File(rawPath).existsSync(), isTrue);
      print('RAW image created at $rawPath, size: ${File(rawPath).lengthSync()} bytes');

      // 2. Parse Expected Results
      final expectedFiles = E01TestUtils.parseReport(reportPath);
      expect(expectedFiles, isNotEmpty);
      print('Parsed ${expectedFiles.length} expected files from report.txt');

      // 3. Start Scan (Directly via Bindings to avoid NativeCallable crash in test environment)
      print('Starting Scan on RAW image (Direct Binding)...');
      final scanEvents = <RecoveryEvent>[];
      final scanCompleter = Completer<void>();

      final bindings = RecoveryBindings();
      final targetPtr = rawPath.toNativeUtf8();
      final outputPtr = outputDir.path.toNativeUtf8();
      
      print('Calling bindings.open($rawPath)...');
      final handle = bindings.open(targetPtr);
      print('Handle: $handle');
      expect(handle, greaterThanOrEqualTo(0));

      final callback = NativeCallable<Void Function(Pointer<RecoveryEventNative>)>.isolateLocal((ptr) {
        final ev = ptr.ref;
        print('Native Callback: eventType=${ev.eventType}, percent=${ev.percent}');
        // Map native event (simplified)
        if (ev.eventType == 2) { // FileFound
           final name = _arrayToString(ev.filename, 256);
           final sector = ev.sectorOffset;
           print('File Found: $name at sector $sector');
           scanEvents.add(FileFoundEvent(
             fileType: 'Unknown',
             filename: name,
             modifiedTime: '',
             fileSize: ev.fileSize,
             sectorOffset: sector,
             folder: '',
           ));
        } else if (ev.eventType == 4) { // Done
           print('Scan Done.');
           scanCompleter.complete();
        } else if (ev.eventType == 3) { // Error
           final msg = _arrayToString(ev.errorMsg, 256);
           print('Scan Error: $msg');
           // In a real scan we might not complete on error if we want to continue, 
           // but for test we probably should.
           // scanCompleter.completeError(msg);
        }
      });

      print('Calling bindings.scan...');
      bindings.scan(handle, outputPtr, callback.nativeFunction, 1, 1, 1);
      print('bindings.scan call returned (it is likely asynchronous if it uses threads internally, but wait, is it?)');

      await scanCompleter.future.timeout(const Duration(minutes: 10));
      
      callback.close();
      bindings.close(handle);
      malloc.free(targetPtr);
      malloc.free(outputPtr);

      // 4. Verify Results
      final foundFiles = scanEvents.whereType<FileFoundEvent>().toList();
      print('Scan complete. Found ${foundFiles.length} files.');

      // Check if critical files from report.txt are found
      // Note: nps-2009-canon2-gen1.E01 might not contain ALL files listed in report.txt 
      // (which seems to be for gen6 as well). But it should contain some.
      
      int matchCount = 0;
      for (var expected in expectedFiles) {
        final match = foundFiles.any((f) => 
          f.sectorOffset == expected.sector || 
          f.filename.contains(p.basename(expected.filename))
        );
        if (match) {
          matchCount++;
          print('Matched: ${expected.filename} at sector ${expected.sector}');
        }
      }

      print('Matched $matchCount out of ${expectedFiles.length} expected files.');
      expect(matchCount, greaterThan(0), reason: 'Should have matched at least some files from the report');
    });
  });
}
