// lib/core/ffi/recovery_bindings.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

@Packed(1)
final class HardwareHealthInfoNative extends Struct {
  @Int32()
  external int status;

  @Int64()
  external int capacity;

  @Array(64)
  external Array<Uint8> controllerId;

  @Array(32)
  external Array<Uint8> firmwareVersion;

  @Array(256)
  external Array<Uint8> errorMessage;
}

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
  @Int32()  external int status;
  @Int32()  external int errorCode;

  @Array(256)
  external Array<Uint8> errorMsg;

  @Int32()  external int totalFound;
  @Int32()  external int fatCount;
  @Int32()  external int carveCount;
  @Int64()  external int durationMs;

  @Array(256)
  external Array<Uint8> folder;
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

typedef SetRefNative = Int32 Function(Int32 handle, Pointer<Utf8> referencePath);
typedef SetRefDart   = int   Function(int handle, Pointer<Utf8> referencePath);

typedef RepairNative = Int32 Function(Pointer<Utf8> brokenPath, Pointer<Utf8> referencePath, Pointer<Utf8> outputPath);
typedef RepairDart   = int   Function(Pointer<Utf8> brokenPath, Pointer<Utf8> referencePath, Pointer<Utf8> outputPath);

typedef CheckHardwareNative = Int32 Function(Int32 handle, Pointer<HardwareHealthInfoNative> outInfo);
typedef CheckHardwareDart   = int Function(int handle, Pointer<HardwareHealthInfoNative> outInfo);

typedef IdentifyFsNative = Pointer<Utf8> Function(Int32 handle);
typedef IdentifyFsDart   = Pointer<Utf8> Function(int handle);

typedef ConvertE01Native = Int32 Function(
    Pointer<Utf8> e01Path,
    Pointer<Utf8> outputPath,
    Pointer<NativeFunction<CallbackNative>> callback);
typedef ConvertE01Dart = int Function(
    Pointer<Utf8> e01Path,
    Pointer<Utf8> outputPath,
    Pointer<NativeFunction<CallbackNative>> callback);

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
  late final SetRefDart    setReferenceVideo;
  late final RepairDart    repairVideo;
  late final CheckHardwareDart checkHardware;
  late final IdentifyFsDart identifyFs;
  late final ConvertE01Dart convertE01;

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
    setReferenceVideo = _lib.lookupFunction<SetRefNative, SetRefDart>('recovery_set_reference_video');
    repairVideo       = _lib.lookupFunction<RepairNative, RepairDart>('recovery_repair_video');
    checkHardware     = _lib.lookupFunction<CheckHardwareNative, CheckHardwareDart>('recovery_check_hardware');
    identifyFs        = _lib.lookupFunction<IdentifyFsNative, IdentifyFsDart>('recovery_identify_fs');
    convertE01        = _lib.lookupFunction<ConvertE01Native, ConvertE01Dart>('recovery_convert_e01');
  }
}
