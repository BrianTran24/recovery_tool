// lib/core/models/recovery_event.dart
import '../service/recovery_service.dart';

sealed class RecoveryEvent {
  @override
  String toString() => '$runtimeType';
}

class FsIdentifiedEvent extends RecoveryEvent {
  final List<FileSystemInfo> filesystems;
  FsIdentifiedEvent(this.filesystems);

  @override
  String toString() => 'FsIdentifiedEvent(count: ${filesystems.length})';
}

class ProgressEvent extends RecoveryEvent {
  final double percent;
  final int scannedBytes;
  final int speedMbps;
  ProgressEvent({required this.percent,
    required this.scannedBytes,
    required this.speedMbps});

  @override
  String toString() => 'ProgressEvent(percent: ${percent.toStringAsFixed(1)}%, scanned: $scannedBytes, speed: $speedMbps Mbps)';
}

class FileFoundEvent extends RecoveryEvent {
  final String fileType;   // "JPEG", "MP4"...
  final String filename;
  final String modifiedTime;
  final int fileSize;
  final int sectorOffset;
  final String folder;     // rel_path thư mục (vd "DCIM"), rỗng nếu ở gốc
  final int status;        // 1=Healthy, 2=Orphaned, 3=Carved

  FileFoundEvent({
    required this.fileType,
    required this.filename,
    required this.modifiedTime,
    required this.fileSize,
    required this.sectorOffset,
    this.folder = '',
    this.status = 1,
  });

  @override
  String toString() => 'FileFoundEvent(type: $fileType, name: $filename, folder: $folder, status: $status, modified: $modifiedTime, size: $fileSize, sector: $sectorOffset)';
}

class ErrorEvent extends RecoveryEvent {
  final int code;
  final String message;
  final bool isHardwareFailure;

  ErrorEvent({
    required this.code,
    required this.message,
    this.isHardwareFailure = false,
  });

  @override
  String toString() => 'ErrorEvent(code: $code, message: $message, hw: $isHardwareFailure)';
}

class DoneEvent extends RecoveryEvent {
  final int totalFound;
  final int fatCount;
  final int carveCount;
  final Duration duration;
  DoneEvent({required this.totalFound, required this.fatCount,
    required this.carveCount, required this.duration});

  @override
  String toString() => 'DoneEvent(found: $totalFound (FAT: $fatCount, Carve: $carveCount), duration: ${duration.inSeconds}s)';
}

String canonicalFileType(String type) {
  switch (type.trim().toUpperCase()) {
    case 'JPG':
    case 'JPE':
      return 'JPEG';
    case 'JPEG':
      return 'JPEG';
    case 'PNG':
      return 'PNG';
    case 'CR2':
      return 'CR2';
    case 'NEF':
      return 'NEF';
    case 'MP4':
      return 'MP4';
    case 'MOV':
      return 'MOV';
    case 'PDF':
      return 'PDF';
    case 'DOCX':
      return 'DOCX';
    default:
      return type.trim().toUpperCase();
  }
}

bool isImageFileType(String type) {
  final normalized = canonicalFileType(type);
  return normalized == 'JPEG' ||
      normalized == 'PNG' ||
      normalized == 'CR2' ||
      normalized == 'NEF';
}

bool isVideoFileType(String type) {
  final normalized = canonicalFileType(type);
  return normalized == 'MP4' || normalized == 'MOV';
}
