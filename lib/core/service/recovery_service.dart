// lib/core/service/recovery_service.dart
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'package:ffi/ffi.dart';
import '../ffi/recovery_bindings.dart';
import '../models/recovery_event.dart';

const _kProgress  = 1;
const _kFileFound = 2;
const _kError     = 3;
const _kDone      = 4;

class RecoveryService {
  final RecoveryBindings _bindings = RecoveryBindings();
  int? _activeHandle;

  Stream<RecoveryEvent> startScan({
    required String devicePath,
    required String outputDir,
    bool enableFat   = true,
    bool enableCarve = true,
  }) {
    String targetPath = devicePath;
    String unmountPath = devicePath;

    if (Platform.isMacOS) {
      if (devicePath.contains('/dev/disk') && !devicePath.contains('/dev/rdisk')) {
        targetPath = devicePath.replaceFirst('/dev/disk', '/dev/rdisk');
      } else if (devicePath.contains('/dev/rdisk')) {
        unmountPath = devicePath.replaceFirst('/dev/rdisk', '/dev/disk');
      }
    }

    final controller = StreamController<RecoveryEvent>(onCancel: () {
      cancel();
    });

    // 1. Tạo NativeCallable ở Main Isolate để nhận callback (Event loop ở đây luôn rảnh)
    final callable = NativeCallable<Void Function(Pointer<RecoveryEventNative>)>.listener((Pointer<RecoveryEventNative> ptr) {
      final ev = ptr.ref;
      final event = _mapNativeEventStatic(ev);
      if (!controller.isClosed) controller.add(event);
      
      // GIẢI PHÓNG vùng nhớ Heap mà C đã malloc
      malloc.free(ptr);
      
      if (event is DoneEvent || event is ErrorEvent) {
        if (!controller.isClosed) controller.close();
      }
    });

    // 2. Mở thiết bị
    // Chỉ unmount nếu là thiết bị vật lý (/dev/disk...)
    if (unmountPath.startsWith('/dev/')) {
      final unmountPtr = unmountPath.toNativeUtf8();
      _bindings.unmount(unmountPtr);
      malloc.free(unmountPtr);
    }

    final targetPtr = targetPath.toNativeUtf8();
    int handle = _bindings.open(targetPtr);
    malloc.free(targetPtr);

    if (handle == -2 && targetPath != devicePath) {
      final originalPtr = devicePath.toNativeUtf8();
      handle = _bindings.open(originalPtr);
      malloc.free(originalPtr);
    }

    if (handle < 0) {
      controller.add(ErrorEvent(code: handle, message: 'Lỗi mở thiết bị ($handle)'));
      controller.close();
      callable.close();
      return controller.stream;
    }
    _activeHandle = handle;

    // Lấy địa chỉ hàm callback để truyền vào Isolate
    final callbackAddr = callable.nativeFunction.address;

    // 3. Chạy Isolate quét (Isolate này sẽ bị block bởi hàm scan của C)
    _runScanInIsolate(
      handle: handle,
      outputDir: outputDir,
      callbackAddr: callbackAddr,
      enableFat: enableFat,
      enableCarve: enableCarve,
    ).then((_) {
      _activeHandle = null;
      callable.close();
    });

    return controller.stream;
  }

  static Future<void> _runScanInIsolate({
    required int handle,
    required String outputDir,
    required int callbackAddr,
    required bool enableFat,
    required bool enableCarve,
  }) {
    return Isolate.run(() {
      final workerBindings = RecoveryBindings();
      final outputPtr = outputDir.toNativeUtf8();
      
      // Chuyển địa chỉ int lại thành con trỏ hàm
      final nativeCallback = Pointer<NativeFunction<Void Function(Pointer<RecoveryEventNative>)>>.fromAddress(callbackAddr);

      workerBindings.scan(
        handle,
        outputPtr,
        nativeCallback,
        enableFat ? 1 : 0,
        enableCarve ? 1 : 0,
      );

      malloc.free(outputPtr);
      workerBindings.close(handle);
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
  }
}
