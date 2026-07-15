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

  @Array(32)
  external Array<Uint8> modifiedTime;

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
typedef OpenNative = Int32 Function(Pointer<Utf8> path);
typedef OpenDart   = int   Function(Pointer<Utf8> path);

typedef DiskSizeNative = Int64 Function(Int32 handle);
typedef DiskSizeDart   = int   Function(int handle);

typedef CallbackNative = Void Function(Pointer<RecoveryEventNative>);
typedef ScanNative = Int32 Function(
    Int32 handle, Pointer<Utf8> outputDir,
    Pointer<NativeFunction<CallbackNative>> callback,
    Int32 enableFat, Int32 enableCarve,
    Int32 scanMode,
    );
typedef ScanDart = int Function(
    int handle, Pointer<Utf8> outputDir,
    Pointer<NativeFunction<CallbackNative>> callback,
    int enableFat, int enableCarve,
    int scanMode,
    );

typedef VoidIntNative = Void Function(Int32);
typedef VoidIntDart   = void Function(int);

typedef SaveFileNative = Int32 Function(Int32 handle, Int64 sectorOffset, Int64 fileSize, Pointer<Utf8> outputPath);
typedef SaveFileDart   = int   Function(int handle, int sectorOffset, int fileSize, Pointer<Utf8> outputPath);

// ── Bindings class ───────────────────────────────────────────────────
class RecoveryBindings {
  late final DynamicLibrary _lib;
  late final OpenDart      open;
  late final OpenDart      unmount;
  late final DiskSizeDart  diskSize;
  late final ScanDart      scan;
  late final VoidIntDart   cancel;
  late final VoidIntDart   close;
  late final SaveFileDart  saveFile;

  RecoveryBindings() {
    final libPath = Platform.isMacOS
        ? '${Directory.current.path}/librecovery.dylib'
        : 'recovery.dll';

    _lib = DynamicLibrary.open(libPath);

    open     = _lib.lookupFunction<OpenNative,     OpenDart>    ('recovery_open');
    unmount  = _lib.lookupFunction<OpenNative,     OpenDart>    ('recovery_unmount');
    diskSize = _lib.lookupFunction<DiskSizeNative, DiskSizeDart>('recovery_disk_size');
    scan     = _lib.lookupFunction<ScanNative,     ScanDart>    ('recovery_scan');
    cancel   = _lib.lookupFunction<VoidIntNative,  VoidIntDart> ('recovery_cancel');
    close    = _lib.lookupFunction<VoidIntNative,  VoidIntDart> ('recovery_close');
    saveFile = _lib.lookupFunction<SaveFileNative, SaveFileDart>('recovery_save_file');
  }
}
