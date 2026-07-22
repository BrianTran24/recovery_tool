import 'dart:io';
import 'dart:async';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:recovery_tool/core/ffi/recovery_bindings.dart';
import 'utils/e01_test_utils.dart';

// Helper to convert C string (uint8 array) to Dart string
String _arrayToString(Array<Uint8> arr, int maxLen) {
  final bytes = <int>[];
  for (int i = 0; i < maxLen; i++) {
    final b = arr[i];
    if (b == 0) break;
    bytes.add(b);
  }
  return String.fromCharCodes(bytes);
}

class FileFoundInfo {
  final String filename;
  final String folder;
  final int size;
  final int sector;

  FileFoundInfo({
    required this.filename,
    required this.folder,
    required this.size,
    required this.sector,
  });
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart test/verify_recovery.dart <e01_path> <report_txt_path>');
    print('Example: dart test/verify_recovery.dart assets/test/eo1/nps-2009-canon2-gen6.E01 assets/test/eo1/report.txt');
    exit(1);
  }

  final e01Path = p.absolute(args[0]);
  final reportPath = p.absolute(args[1]);
  final tempDir = Directory.systemTemp.createTempSync('recovery_verify_');
  final rawPath = p.join(tempDir.path, 'image.raw');
  final outputDir = Directory(p.join(tempDir.path, 'output'))..createSync();

  print('=========================================');
  print('   RECOVERY VERIFICATION SCRIPT          ');
  print('=========================================');
  print('Input E01: $e01Path');
  print('Report:    $reportPath');
  print('Output:    ${outputDir.path}');
  print('-----------------------------------------');

  // 1. Parse Report
  final expectedFiles = E01TestUtils.parseReport(reportPath);
  final e01Basename = p.basename(e01Path).replaceAll('.E01', '');
  
  // Try to match based on the gen number or full name
  final relevantExpected = expectedFiles.where((f) {
    final src = f.sourceImage.toLowerCase();
    final target = e01Basename.toLowerCase();
    return src.contains(target) || target.contains(src.replaceAll('.raw', ''));
  }).toList();

  print('Parsed ${expectedFiles.length} total entries from report.');
  print('Found ${relevantExpected.length} entries relevant to this image.');

  final targetExpected = relevantExpected.isEmpty ? expectedFiles : relevantExpected;

  // 2. Initialize Bindings
  final bindings = RecoveryBindings();

  // 3. Convert E01 to RAW
  print('\n[Phase 1] Converting E01 to RAW...');
  final convCompleter = Completer<void>();
  final convCallback = NativeCallable<Void Function(Pointer<RecoveryEventNative>)>.isolateLocal((Pointer<RecoveryEventNative> ptr) {
    final ev = ptr.ref;
    if (ev.eventType == 4) { // Done
      convCompleter.complete();
    } else if (ev.eventType == 3) { // Error
      final msg = _arrayToString(ev.errorMsg, 256);
      print('\nConversion Error: $msg');
      convCompleter.completeError(msg);
    } else {
      stdout.write('\rProgress: ${ev.percent.toStringAsFixed(1)}%');
    }
  });

  final e01PathPtr = e01Path.toNativeUtf8();
  final rawPathPtr = rawPath.toNativeUtf8();
  
  bindings.convertE01(e01PathPtr, rawPathPtr, convCallback.nativeFunction);
  await convCompleter.future;
  convCallback.close();
  print('\nConversion complete: $rawPath');

  // 4. Scan RAW
  print('\n[Phase 2] Scanning RAW image...');
  final foundFiles = <FileFoundInfo>[];
  final scanCompleter = Completer<void>();

  final scanCallback = NativeCallable<Void Function(Pointer<RecoveryEventNative>)>.isolateLocal((Pointer<RecoveryEventNative> ptr) {
    final ev = ptr.ref;
    if (ev.eventType == 2) { // FileFound
      final name = _arrayToString(ev.filename, 256);
      final folder = _arrayToString(ev.folder, 256);
      foundFiles.add(FileFoundInfo(
        filename: name,
        folder: folder,
        size: ev.fileSize,
        sector: ev.sectorOffset,
      ));
    } else if (ev.eventType == 4) { // Done
      scanCompleter.complete();
    } else if (ev.eventType == 3) { // Error
       final msg = _arrayToString(ev.errorMsg, 256);
       print('\nNative Scan Error: $msg');
    } else {
      stdout.write('\rScanning: ${ev.percent.toStringAsFixed(1)}% (Found: ${foundFiles.length})');
    }
  });

  final handle = bindings.open(rawPathPtr);
  if (handle < 0) {
    print('Error: Could not open RAW image for scanning.');
    exit(1);
  }

  final outputPtr = outputDir.absolute.path.toNativeUtf8();
  // enableFat=1, enableCarve=1, scanMode=1 (Full)
  bindings.scan(handle, outputPtr, scanCallback.nativeFunction, 1, 1, 1);

  await scanCompleter.future;
  scanCallback.close();
  bindings.close(handle);
  print('\nScan complete. Detected ${foundFiles.length} files.');

  // 5. Verify Results
  print('\n[Phase 3] Verification vs Report...');
  print('--------------------------------------------------------------------------');
  print('${'Filename'.padRight(40)} | ${'Sector'.padRight(10)} | ${'SHA-1 Status'}');
  print('--------------------------------------------------------------------------');

  int matches = 0;
  int shaMatches = 0;

  for (var expected in targetExpected) {
    final matchingFound = foundFiles.where((f) => 
      f.sector == expected.firstSector || 
      p.basename(f.filename) == p.basename(expected.filename)
    ).toList();

    String shaStatus = 'MISSING';
    int foundSector = -1;

    if (matchingFound.isNotEmpty) {
      matches++;
      final found = matchingFound.first;
      foundSector = found.sector;
      
      final recoveredFilePath = p.join(outputDir.path, found.folder, found.filename);
      final recoveredFile = File(recoveredFilePath);
      if (recoveredFile.existsSync()) {
        final actualSha1 = E01TestUtils.calculateSha1(recoveredFile);
        if (actualSha1.toLowerCase() == expected.sha1.toLowerCase()) {
          shaMatches++;
          shaStatus = 'MATCH ✅';
        } else {
          shaStatus = 'MISMATCH ❌';
        }
      } else {
        shaStatus = 'NOT SAVED ⚠️';
      }
    }

    final displayName = expected.filename.length > 37 
        ? '...${expected.filename.substring(expected.filename.length - 37)}'
        : expected.filename;
        
    print('${displayName.padRight(40)} | ${expected.firstSector.toString().padRight(10)} | $shaStatus');
    if (shaStatus == 'MISMATCH ❌') {
      print('      Expected: ${expected.sha1}');
      print('      Found:    ${E01TestUtils.calculateSha1(File(p.join(outputDir.path, matchingFound.first.folder, matchingFound.first.filename)))}');
    }
  }

  print('--------------------------------------------------------------------------');
  print('\nFINAL SUMMARY:');
  print('Total Expected:   ${targetExpected.length}');
  print('Detected:         $matches');
  print('SHA-1 Verified:   $shaMatches');

  final bool success = (shaMatches == targetExpected.length && targetExpected.isNotEmpty);
  if (success) {
    print('\nVERIFICATION RESULT: PASSED 🎉');
  } else {
    print('\nVERIFICATION RESULT: FAILED ❌');
  }

  // Cleanup
  malloc.free(e01PathPtr);
  malloc.free(rawPathPtr);
  malloc.free(outputPtr);
  
  await Future.delayed(Duration(seconds: 1));
  try {
    tempDir.deleteSync(recursive: true);
  } catch (e) {
    // Ignore cleanup errors
  }
  
  if (!success) exit(1);
}
