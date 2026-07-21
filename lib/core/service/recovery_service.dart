// lib/core/service/recovery_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import '../ffi/recovery_bindings.dart';
import '../models/recovery_event.dart';

const _kProgress = 1;
const _kFileFound = 2;
const _kError = 3;
const _kDone = 4;

class FileSystemInfo {
  final int offset;
  final int type;

  FileSystemInfo({required this.offset, required this.type});

  String get typeName {
    switch (type) {
      case 1: return 'FAT32';
      case 2: return 'exFAT';
      case 3: return 'NTFS';
      case 4: return 'ext4';
      default: return 'Unknown';
    }
  }
}

class RecoveryService {
  final RecoveryBindings _bindings = RecoveryBindings();
  int? _activeHandle;

  Future<List<FileSystemInfo>> identifyFileSystems(int handle) async {
    final ptr = _bindings.identifyFs(handle);
    final jsonStr = ptr.toDartString();
    debugPrint('DEBUG: Identified FS JSON: $jsonStr');
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((item) => FileSystemInfo(
        offset: item['offset'] as int,
        type: item['type'] as int,
      )).toList();
    } catch (e) {
      debugPrint('ERROR parsing FS JSON: $e');
      return [];
    }
  }

  Stream<RecoveryEvent> startScan({
    required String sourcePath,
    required String outputDir,
    bool enableFat = true,
    bool enableCarve = true,
    int scanMode = 1, // 1=Deleted, 2=Existing, 3=Both
    String referenceVideo = '',
  }) {
    final controller = StreamController<RecoveryEvent>(
      onCancel: () {
        cancel();
      },
    );

    _startScanInternal(
      sourcePath: sourcePath,
      outputDir: outputDir,
      enableFat: enableFat,
      enableCarve: enableCarve,
      scanMode: scanMode,
      referenceVideo: referenceVideo,
      controller: controller,
    );

    return controller.stream;
  }

  Future<void> _startScanInternal({
    required String sourcePath,
    required String outputDir,
    required bool enableFat,
    required bool enableCarve,
    required int scanMode,
    required String referenceVideo,
    required StreamController<RecoveryEvent> controller,
  }) async {
    debugPrint('DEBUG: _startScanInternal (FFI Native) started for $sourcePath');
    var targetPath = _normalizeNativeDevicePath(sourcePath);

    String unmountPath = sourcePath;

    if (Platform.isMacOS) {
      if (sourcePath.contains('/dev/disk') &&
          !sourcePath.contains('/dev/rdisk')) {
        targetPath = sourcePath.replaceFirst('/dev/disk', '/dev/rdisk');
      } else if (sourcePath.contains('/dev/rdisk')) {
        unmountPath = sourcePath.replaceFirst('/dev/rdisk', '/dev/disk');
      }
    }

    // 1. Unmount and Open Device
    if (unmountPath.startsWith('/dev/')) {
      final unmountPtr = unmountPath.toNativeUtf8();
      _bindings.unmount(unmountPtr);
      malloc.free(unmountPtr);
    }

    final targetPtr = targetPath.toNativeUtf8();
    debugPrint('DEBUG: Calling _bindings.open for $targetPath');
    int handle = _bindings.open(targetPtr);
    debugPrint('DEBUG: _bindings.open returned handle: $handle');
    malloc.free(targetPtr);

    if (handle < 0) {
      controller.add(
        ErrorEvent(code: handle, message: 'Lỗi mở thiết bị ($handle)'),
      );
      controller.close();
      return;
    }

    // 1.1. Hardware Health Check
    final hwInfoPtr = malloc<HardwareHealthInfoNative>();
    final hwResult = _bindings.checkHardware(handle, hwInfoPtr);
    final hwInfo = hwInfoPtr.ref;

    if (hwResult != 0) {
      final errorMsg = _arrayToStringStatic(hwInfo.errorMessage, 256);
      controller.add(
        ErrorEvent(
          code: hwResult,
          message:
              'Phát hiện lỗi phần cứng/firmware nghiêm trọng: $errorMsg. Khuyến nghị sử dụng thiết bị chuyên dụng (PC-3000 Flash) để đọc trực tiếp chip NAND.',
          isHardwareFailure: true,
        ),
      );
      _bindings.close(handle);
      malloc.free(hwInfoPtr);
      controller.close();
      return;
    }
    malloc.free(hwInfoPtr);

    _activeHandle = handle;

    // 1.2. File System Identification
    final filesystems = await identifyFileSystems(handle);
    controller.add(FsIdentifiedEvent(filesystems));

    // Đặt video tham chiếu để repair tự động các video thiếu `moov` khi carve.
    // g_sessions là global trong DLL (cùng process) nên set ở đây có hiệu lực cho
    // cả isolate worker.
    if (referenceVideo.isNotEmpty) {
      final refPtr = referenceVideo.toNativeUtf8();
      _bindings.setReferenceVideo(handle, refPtr);
      malloc.free(refPtr);
    }

    // Phát sự kiện bắt đầu ngay để UI không bị stuck ở loading
    controller.add(ProgressEvent(percent: 0, scannedBytes: 0, speedMbps: 0));

    // 2. Perform Unified Scan (FAT + Deep Scan) in Isolate via FFI
    final receivePort = ReceivePort();
    final scanCompleter = Completer<void>();
    
    final subscription = receivePort.listen((message) {
      if (message is RecoveryEvent && !controller.isClosed) {
        controller.add(message);
        if (message is DoneEvent || message is ErrorEvent) {
          if (!scanCompleter.isCompleted) {
            scanCompleter.complete();
          }
        }
      }
    });

    debugPrint('DEBUG: Spawning Isolate for FFI scan');
    await _runScanInIsolate(
      handle: handle,
      outputDir: outputDir,
      sendPort: receivePort.sendPort,
      enableFat: enableFat,
      enableCarve: enableCarve,
      scanMode: scanMode,
    );
    
    // Wait for the scan to finish or timeout
    await scanCompleter.future.timeout(const Duration(hours: 5), onTimeout: () => null);
    debugPrint('DEBUG: FFI scan finished');

    await subscription.cancel();
    receivePort.close();

    // 3. Cleanup and Close
    _bindings.close(handle);
    _activeHandle = null;

    if (!controller.isClosed) {
      controller.close();
    }
  }

  static Future<void> _runScanInIsolate({
    required int handle,
    required String outputDir,
    required SendPort sendPort,
    required bool enableFat,
    required bool enableCarve,
    required int scanMode,
  }) {
    return Isolate.run(() {
      final workerBindings = RecoveryBindings();
      final outputPtr = outputDir.toNativeUtf8();

      final callable =
          NativeCallable<Void Function(Pointer<RecoveryEventNative>)>.isolateLocal((
            Pointer<RecoveryEventNative> ptr,
          ) {
            final ev = ptr.ref;
            final event = _mapNativeEventStatic(ev);
            sendPort.send(event);
          });

      workerBindings.scan(
        handle,
        outputPtr,
        callable.nativeFunction,
        enableFat ? 1 : 0,
        enableCarve ? 1 : 0,
        scanMode,
      );

      callable.close();
      malloc.free(outputPtr);
    });
  }

  String _normalizeNativeDevicePath(String path) {
    if (!Platform.isWindows) return path;
    if (path.startsWith(r'\\?\') || path.startsWith('\\\\.\\')) {
      return path;
    }

    final hasDriveLetter =
        path.length >= 2 &&
        path.codeUnitAt(1) == ':'.codeUnitAt(0) &&
        ((path.codeUnitAt(0) >= 'A'.codeUnitAt(0) &&
                path.codeUnitAt(0) <= 'Z'.codeUnitAt(0)) ||
            (path.codeUnitAt(0) >= 'a'.codeUnitAt(0) &&
                path.codeUnitAt(0) <= 'z'.codeUnitAt(0)));

    if (hasDriveLetter) return r'\\?\' + path;
    return path;
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
          modifiedTime: _arrayToStringStatic(ev.modifiedTime, 32),
          fileSize: ev.fileSize,
          sectorOffset: ev.sectorOffset,
          folder: _arrayToStringStatic(ev.folder, 256),
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
        return ErrorEvent(
          code: -1,
          message: 'Unknown event type: ${ev.eventType}',
        );
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
  }

  void pause() {
    if (_activeHandle != null) {
      _bindings.pause(_activeHandle!);
    }
  }

  void resume() {
    if (_activeHandle != null) {
      _bindings.resume(_activeHandle!);
    }
  }

  Future<int> saveFile({
    required int handle,
    required int sectorOffset,
    required int fileSize,
    required String outputPath,
  }) async {
    final pathPtr = outputPath.toNativeUtf8();
    final result = _bindings.saveFile(handle, sectorOffset, fileSize, pathPtr);
    malloc.free(pathPtr);
    return result;
  }

  Stream<RecoveryEvent> convertE01({
    required String e01Path,
    required String outputPath,
  }) {
    final controller = StreamController<RecoveryEvent>();
    final receivePort = ReceivePort();

    final subscription = receivePort.listen((message) {
      if (message is RecoveryEvent) {
        if (!controller.isClosed) {
          controller.add(message);
        }
      }
    });

    _runConversionInIsolate(
      e01Path: e01Path,
      outputPath: outputPath,
      sendPort: receivePort.sendPort,
    ).then((_) {
      subscription.cancel();
      receivePort.close();
      if (!controller.isClosed) {
        controller.close();
      }
    }).catchError((e) {
      subscription.cancel();
      receivePort.close();
      if (!controller.isClosed) {
        controller.add(ErrorEvent(code: -1, message: e.toString()));
        controller.close();
      }
    });

    return controller.stream;
  }

  static Future<void> _runConversionInIsolate({
    required String e01Path,
    required String outputPath,
    required SendPort sendPort,
  }) {
    return Isolate.run(() {
      final workerBindings = RecoveryBindings();
      final e01Ptr = e01Path.toNativeUtf8();
      final outputPtr = outputPath.toNativeUtf8();

      final callable =
          NativeCallable<Void Function(Pointer<RecoveryEventNative>)>.isolateLocal((
            Pointer<RecoveryEventNative> ptr,
          ) {
            final ev = ptr.ref;
            final event = _mapNativeEventStatic(ev);
            sendPort.send(event);
          });

      workerBindings.convertE01(
        e01Ptr,
        outputPtr,
        callable.nativeFunction,
      );

      callable.close();
      malloc.free(e01Ptr);
      malloc.free(outputPtr);
    });
  }
}
