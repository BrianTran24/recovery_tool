// lib/core/models/recovery_event.dart
sealed class RecoveryEvent {}

class ProgressEvent extends RecoveryEvent {
  final double percent;
  final int scannedBytes;
  final int speedMbps;
  ProgressEvent({required this.percent,
    required this.scannedBytes,
    required this.speedMbps});
}

class FileFoundEvent extends RecoveryEvent {
  final String fileType;   // "JPEG", "MP4"...
  final String filename;
  final int fileSize;
  final int sectorOffset;
  FileFoundEvent({required this.fileType, required this.filename,
    required this.fileSize, required this.sectorOffset});
}

class ErrorEvent extends RecoveryEvent {
  final int code;
  final String message;
  ErrorEvent({required this.code, required this.message});
}

class DoneEvent extends RecoveryEvent {
  final int totalFound;
  final int fatCount;
  final int carveCount;
  final Duration duration;
  DoneEvent({required this.totalFound, required this.fatCount,
    required this.carveCount, required this.duration});
}