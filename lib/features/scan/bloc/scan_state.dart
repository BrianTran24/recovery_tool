import 'package:equatable/equatable.dart';
import '../../../core/models/recovery_event.dart';
import '../../../core/service/recovery_service.dart';

enum ScanStatus { initial, loading, inProgress, success, failure }

class ScanState extends Equatable {
  final ScanStatus status;
  final double percent;
  final int speed;
  final int foundCount;
  final List<FileFoundEvent> foundFiles;
  final List<FileSystemInfo> fileSystems;
  final String? errorMessage;
  final bool isHardwareFailure;
  final Duration elapsed;

  const ScanState({
    this.status = ScanStatus.initial,
    this.percent = 0.0,
    this.speed = 0,
    this.foundCount = 0,
    this.foundFiles = const [],
    this.fileSystems = const [],
    this.errorMessage,
    this.isHardwareFailure = false,
    this.elapsed = Duration.zero,
  });

  ScanState copyWith({
    ScanStatus? status,
    double? percent,
    int? speed,
    int? foundCount,
    List<FileFoundEvent>? foundFiles,
    List<FileSystemInfo>? fileSystems,
    String? errorMessage,
    bool? isHardwareFailure,
    Duration? elapsed,
  }) {
    return ScanState(
      status: status ?? this.status,
      percent: percent ?? this.percent,
      speed: speed ?? this.speed,
      foundCount: foundCount ?? this.foundCount,
      foundFiles: foundFiles ?? this.foundFiles,
      fileSystems: fileSystems ?? this.fileSystems,
      errorMessage: errorMessage ?? this.errorMessage,
      isHardwareFailure: isHardwareFailure ?? this.isHardwareFailure,
      elapsed: elapsed ?? this.elapsed,
    );
  }

  @override
  List<Object?> get props => [
    status,
    percent,
    speed,
    foundCount,
    foundFiles,
    fileSystems,
    errorMessage,
    isHardwareFailure,
    elapsed,
  ];
}
