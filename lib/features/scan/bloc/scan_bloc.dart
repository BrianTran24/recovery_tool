import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/recovery_event.dart';
import '../../../core/service/recovery_service.dart';
import 'scan_event.dart';
import 'scan_state.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final RecoveryService _recoveryService;
  StreamSubscription<RecoveryEvent>? _scanSubscription;
  final List<FileFoundEvent> _internalFiles = [];
  Timer? _flushTimer;

  ScanBloc(this._recoveryService) : super(const ScanState()) {
    on<StartScanEvent>(_onStartScan);
    on<StopScanEvent>(_onStopScan);
    on<ScanProgressUpdatedEvent>(_onProgressUpdated);
    on<FileFoundEventReceived>(_onFileFound);
    on<FsIdentifiedEventReceived>(_onFsIdentified);
    on<ScanDoneEventReceived>(_onScanDone);
    on<ScanErrorEventReceived>(_onScanError);
    on<BatchUpdateFilesEvent>(_onBatchUpdateFiles);
  }

  Future<void> _onStartScan(StartScanEvent event, Emitter<ScanState> emit) async {
    _internalFiles.clear();
    emit(const ScanState(status: ScanStatus.loading));

    await _scanSubscription?.cancel();
    _scanSubscription = _recoveryService.startScan(
      sourcePath: event.sourcePath,
      outputDir: event.outputDir,
      enableFat: event.enableFat,
      enableCarve: event.enableCarve,
      scanMode: event.scanMode,
      referenceVideo: event.referenceVideo,
    ).listen((event) {
      if (event is FsIdentifiedEvent) {
        add(FsIdentifiedEventReceived(event.filesystems));
      } else if (event is ProgressEvent) {
        add(ScanProgressUpdatedEvent(event.percent, event.speedMbps));
      } else if (event is FileFoundEvent) {
        add(FileFoundEventReceived(event));
      } else if (event is DoneEvent) {
        add(ScanDoneEventReceived(event.duration));
      } else if (event is ErrorEvent) {
        add(ScanErrorEventReceived(event.message, event.isHardwareFailure));
      }
    });
  }

  void _onStopScan(StopScanEvent event, Emitter<ScanState> emit) {
    _recoveryService.cancel();
    emit(state.copyWith(status: ScanStatus.success));
    _scanSubscription?.cancel();
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  void _onProgressUpdated(ScanProgressUpdatedEvent event, Emitter<ScanState> emit) {
    emit(state.copyWith(
      status: ScanStatus.inProgress,
      percent: event.percent,
      speed: event.speedMbps,
    ));
  }

  void _onFileFound(FileFoundEventReceived event, Emitter<ScanState> emit) {
    _internalFiles.add(event.event as FileFoundEvent);
    
    if (_flushTimer == null) {
      _flushTimer = Timer(const Duration(milliseconds: 100), () {
        _flushTimer = null;
        add(const BatchUpdateFilesEvent());
      });
    }
  }

  void _onBatchUpdateFiles(BatchUpdateFilesEvent event, Emitter<ScanState> emit) {
    emit(state.copyWith(
      foundFiles: List.from(_internalFiles),
      foundCount: _internalFiles.length,
    ));
  }

  void _onFsIdentified(FsIdentifiedEventReceived event, Emitter<ScanState> emit) {
    emit(state.copyWith(fileSystems: List.from(event.filesystems)));
  }

  void _onScanDone(ScanDoneEventReceived event, Emitter<ScanState> emit) {
    emit(state.copyWith(
      status: ScanStatus.success,
      elapsed: event.duration,
      percent: 100,
      foundFiles: List.from(_internalFiles),
      foundCount: _internalFiles.length,
    ));
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  void _onScanError(ScanErrorEventReceived event, Emitter<ScanState> emit) {
    emit(state.copyWith(
      status: ScanStatus.failure,
      errorMessage: event.message,
      isHardwareFailure: event.isHardwareFailure,
    ));
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  @override
  Future<void> close() {
    _scanSubscription?.cancel();
    _flushTimer?.cancel();
    return super.close();
  }
}
