import 'package:equatable/equatable.dart';

abstract class ScanEvent extends Equatable {
  const ScanEvent();

  @override
  List<Object?> get props => [];
}

class StartScanEvent extends ScanEvent {
  final String sourcePath;
  final String outputDir;
  final bool enableFat;
  final bool enableCarve;
  final int scanMode;
  final String referenceVideo;

  const StartScanEvent({
    required this.sourcePath,
    required this.outputDir,
    this.enableFat = true,
    this.enableCarve = true,
    this.scanMode = 1,
    this.referenceVideo = '',
  });

  @override
  List<Object?> get props => [sourcePath, outputDir, enableFat, enableCarve, scanMode, referenceVideo];
}

class StopScanEvent extends ScanEvent {}

class ScanProgressUpdatedEvent extends ScanEvent {
  final double percent;
  final int speedMbps;

  const ScanProgressUpdatedEvent(this.percent, this.speedMbps);

  @override
  List<Object?> get props => [percent, speedMbps];
}

class FileFoundEventReceived extends ScanEvent {
  final dynamic event; 

  const FileFoundEventReceived(this.event);

  @override
  List<Object?> get props => [event];
}

class FsIdentifiedEventReceived extends ScanEvent {
  final List<dynamic> filesystems;

  const FsIdentifiedEventReceived(this.filesystems);

  @override
  List<Object?> get props => [filesystems];
}

class ScanDoneEventReceived extends ScanEvent {
  final Duration duration;
  const ScanDoneEventReceived(this.duration);

  @override
  List<Object?> get props => [duration];
}

class ScanErrorEventReceived extends ScanEvent {
  final String message;
  final bool isHardwareFailure;

  const ScanErrorEventReceived(this.message, this.isHardwareFailure);

  @override
  List<Object?> get props => [message, isHardwareFailure];
}

class BatchUpdateFilesEvent extends ScanEvent {
  const BatchUpdateFilesEvent();
}
