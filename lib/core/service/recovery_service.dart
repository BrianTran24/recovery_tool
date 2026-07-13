// lib/core/service/recovery_service.dart
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../ffi/recovery_bindings.dart';
import '../models/recovery_event.dart';
import 'photorec_runner.dart';

const _kProgress  = 1;
const _kFileFound = 2;
const _kError     = 3;
const _kDone      = 4;

class RecoveryService {
  final RecoveryBindings _bindings = RecoveryBindings();
  int? _activeHandle;
  PhotoRecRunner? _photoRecRunner;

  Stream<RecoveryEvent> startScan({
    required String devicePath,
    required String outputDir,
    bool enableFat   = true,
    bool enableCarve = true,
  }) {
    final controller = StreamController<RecoveryEvent>(onCancel: () {
      cancel();
    });

    _startScanInternal(
      devicePath: devicePath,
      outputDir: outputDir,
      enableFat: enableFat,
      enableCarve: enableCarve,
      controller: controller,
    );

    return controller.stream;
  }

  Future<void> _startScanInternal({
    required String devicePath,
    required String outputDir,
    required bool enableFat,
    required bool enableCarve,
    required StreamController<RecoveryEvent> controller,
  }) async {
    print('DEBUG: _startScanInternal started for $devicePath');
    String targetPath = devicePath;
    String unmountPath = devicePath;

    if (Platform.isMacOS) {
      if (devicePath.contains('/dev/disk') && !devicePath.contains('/dev/rdisk')) {
        targetPath = devicePath.replaceFirst('/dev/disk', '/dev/rdisk');
      } else if (devicePath.contains('/dev/rdisk')) {
        unmountPath = devicePath.replaceFirst('/dev/rdisk', '/dev/disk');
      }
    }

    // 1. Unmount and Open Device
    if (unmountPath.startsWith('/dev/')) {
      final unmountPtr = unmountPath.toNativeUtf8();
      _bindings.unmount(unmountPtr);
      malloc.free(unmountPtr);
    }

    final targetPtr = targetPath.toNativeUtf8();
    print('DEBUG: Calling _bindings.open for $targetPath');
    int handle = _bindings.open(targetPtr);
    print('DEBUG: _bindings.open returned handle: $handle');
    malloc.free(targetPtr);

    if (handle < 0) {
      controller.add(ErrorEvent(code: handle, message: 'Lỗi mở thiết bị ($handle)'));
      controller.close();
      return;
    }
    _activeHandle = handle;
    
    // Phát sự kiện bắt đầu ngay để UI không bị stuck ở loading
    controller.add(ProgressEvent(percent: 0, scannedBytes: 0, speedMbps: 0));

    int totalFound = 0;
    int fatCount = 0;
    int carveCount = 0;
    final startTime = DateTime.now();

    // 2. Perform FAT Scan (FFI) if enabled
    if (enableFat) {
      print('DEBUG: Starting FAT scan');
      final callable = NativeCallable<Void Function(Pointer<RecoveryEventNative>)>.listener((Pointer<RecoveryEventNative> ptr) {
        final ev = ptr.ref;
        final event = _mapNativeEventStatic(ev);
        print('DEBUG: Received native event type: ${ev.eventType}');
        
        if (event is FileFoundEvent) {
          fatCount++;
          totalFound++;
        }
        
        if (!controller.isClosed && event is! DoneEvent) {
          controller.add(event);
        }
        
        malloc.free(ptr);
      });

      print('DEBUG: Before _runScanInIsolate');
      await _runScanInIsolate(
        handle: handle,
        outputDir: outputDir,
        callbackAddr: callable.nativeFunction.address,
        enableFat: true,
        enableCarve: false, // Legacy carver disabled
      );
      print('DEBUG: After _runScanInIsolate');
      
      callable.close();
    }

    // 3. Perform Deep Scan (PhotoRec) if enabled
    if (enableCarve && !controller.isClosed) {
      final binaryPath = await _deployPhotoRec();
      _photoRecRunner = PhotoRecRunner();
      
      final photoRecStream = _photoRecRunner!.events.listen((event) {
        if (event is FileFoundEvent) {
          carveCount++;
          totalFound++;
        }
        if (!controller.isClosed && event is! DoneEvent) {
          controller.add(event);
        }
      });

      await _photoRecRunner!.run(
        binaryPath: binaryPath,
        devicePath: targetPath,
        outputDir: outputDir,
      );
      
      await photoRecStream.cancel();
      _photoRecRunner = null;
    }

    // 4. Cleanup and Close
    _bindings.close(handle);
    _activeHandle = null;

    if (!controller.isClosed) {
      controller.add(DoneEvent(
        totalFound: totalFound,
        fatCount: fatCount,
        carveCount: carveCount,
        duration: DateTime.now().difference(startTime),
      ));
      controller.close();
    }
  }

  Future<String> _deployPhotoRec() async {
    final exeName = Platform.isWindows ? 'photorec_win.exe' : (Platform.isMacOS ? 'photorec_macos' : 'photorec_android');
    final directory = await getApplicationSupportDirectory();
    final path = p.join(directory.path, exeName);

    if (!File(path).existsSync()) {
      // In a real scenario, we would load from assets
      // ByteData data = await rootBundle.load('assets/bin/$exeName');
      // List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      // await File(path).writeAsBytes(bytes);
      
      // Placeholder for now
      // print('DEBUG: Binary should be deployed to $path');
      // For testing purposes on Windows, if photorec is in PATH, we can just return 'photorec'
      if (Platform.isWindows) return 'photorec'; 
    }

    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', path]);
    }

    return path;
  }

  static Future<void> _runScanInIsolate({
    required int handle,
    required String outputDir,
    required int callbackAddr,
    required bool enableFat,
    required bool enableCarve,
  }) {
    print('DEBUG: Spawning isolate for scan');
    return Isolate.run(() {
      print('DEBUG: Isolate started');
      final workerBindings = RecoveryBindings();
      final outputPtr = outputDir.toNativeUtf8();
      
      // Chuyển địa chỉ int lại thành con trỏ hàm
      final nativeCallback = Pointer<NativeFunction<Void Function(Pointer<RecoveryEventNative>)>>.fromAddress(callbackAddr);

      print('DEBUG: Calling workerBindings.scan');
      workerBindings.scan(
        handle,
        outputPtr,
        nativeCallback,
        enableFat ? 1 : 0,
        enableCarve ? 1 : 0,
      );
      print('DEBUG: workerBindings.scan finished');

      malloc.free(outputPtr);
      workerBindings.close(handle);
      print('DEBUG: Isolate finishing');
    });
  }

  static RecoveryEvent _mapNativeEventStatic(RecoveryEventNative ev) {
    switch (ev.eventType) {
      case _kProgress:
        return ProgressEvent(
          percent: ev.percent,
          scannedBytes: ev.scannedBytes,
          speedMbps: ev.speedMbps,
        );
      case _kFileFound:
        return FileFoundEvent(
          fileType: _arrayToStringStatic(ev.fileType, 16),
          filename: _arrayToStringStatic(ev.filename, 256),
          fileSize: ev.fileSize,
          sectorOffset: ev.sectorOffset,
        );
      case _kError:
        return ErrorEvent(
          code: ev.errorCode,
          message: _arrayToStringStatic(ev.errorMsg, 256),
        );
      case _kDone:
        return DoneEvent(
          totalFound: ev.totalFound,
          fatCount: ev.fatCount,
          carveCount: ev.carveCount,
          duration: Duration(milliseconds: ev.durationMs),
        );
      default:
        return ErrorEvent(code: -1, message: 'Unknown event type: ${ev.eventType}');
    }
  }

  static String _arrayToStringStatic(Array<Uint8> arr, int maxLen) {
    final bytes = <int>[];
    for (int i = 0; i < maxLen; i++) {
      final b = arr[i];
      if (b == 0) break;
      bytes.add(b);
    }
    return String.fromCharCodes(bytes);
  }

  void cancel() {
    if (_activeHandle != null) {
      _bindings.cancel(_activeHandle!);
    }
    _photoRecRunner?.stop();
  }
}
