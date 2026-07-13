// lib/core/models/recovery_event.dart
sealed class RecoveryEvent {
  @override
  String toString() => '$runtimeType';
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
  final int fileSize;
  final int sectorOffset;
  FileFoundEvent({required this.fileType, required this.filename,
    required this.fileSize, required this.sectorOffset});

  @override
  String toString() => 'FileFoundEvent(type: $fileType, name: $filename, size: $fileSize, sector: $sectorOffset)';
}

class ErrorEvent extends RecoveryEvent {
  final int code;
  final String message;
  ErrorEvent({required this.code, required this.message});

  @override
  String toString() => 'ErrorEvent(code: $code, message: $message)';
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
