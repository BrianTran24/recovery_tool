// lib/core/ffi/recovery_bindings.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// ── Struct mapping C RecoveryEvent ──────────────────────────────────
@Packed(1)
final class RecoveryEventNative extends Struct {
  @Int32()  external int eventType;
  @Double() external double percent;
  @Int64()  external int scannedBytes;
  @Int32()  external int speedMbps;

  @Array(16)
  external Array<Uint8> fileType;

  @Array(256)
  external Array<Uint8> filename;

  @Int64()  external int fileSize;
  @Int64()  external int sectorOffset;
  @Int32()  external int errorCode;

  @Array(256)
  external Array<Uint8> errorMsg;

  @Int32()  external int totalFound;
  @Int32()  external int fatCount;
  @Int32()  external int carveCount;
  @Int64()  external int durationMs;
}

// ── Native function typedefs ─────────────────────────────────────────
typedef _OpenNative = Int32 Function(Pointer<Utf8> path);
typedef _OpenDart   = int   Function(Pointer<Utf8> path);

typedef _DiskSizeNative = Int64 Function(Int32 handle);
typedef _DiskSizeDart   = int   Function(int handle);

typedef _CallbackNative = Void Function(Pointer<RecoveryEventNative>);
typedef _ScanNative = Int32 Function(
    Int32 handle, Pointer<Utf8> outputDir,
    Pointer<NativeFunction<_CallbackNative>> callback,
    Int32 enableFat, Int32 enableCarve,
    );
typedef _ScanDart = int Function(
    int handle, Pointer<Utf8> outputDir,
    Pointer<NativeFunction<_CallbackNative>> callback,
    int enableFat, int enableCarve,
    );

typedef _VoidIntNative = Void Function(Int32);
typedef _VoidIntDart   = void Function(int);

// ── Bindings class ───────────────────────────────────────────────────
class RecoveryBindings {
  late final DynamicLibrary _lib;
  late final _OpenDart      open;
  late final _OpenDart      unmount;
  late final _DiskSizeDart  diskSize;
  late final _ScanDart      scan;
  late final _VoidIntDart   cancel;
  late final _VoidIntDart   close;

  RecoveryBindings() {
    final libPath = Platform.isMacOS
        ? '${Directory.current.path}/librecovery.dylib'
        : 'recovery.dll';

    _lib = DynamicLibrary.open(libPath);

    open     = _lib.lookupFunction<_OpenNative,     _OpenDart>    ('recovery_open');
    unmount  = _lib.lookupFunction<_OpenNative,     _OpenDart>    ('recovery_unmount');
    diskSize = _lib.lookupFunction<_DiskSizeNative, _DiskSizeDart>('recovery_disk_size');
    scan     = _lib.lookupFunction<_ScanNative,     _ScanDart>    ('recovery_scan');
    cancel   = _lib.lookupFunction<_VoidIntNative,  _VoidIntDart> ('recovery_cancel');
    close    = _lib.lookupFunction<_VoidIntNative,  _VoidIntDart> ('recovery_close');
  }
}
