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
  DateTime? _startTime;
  DateTime? _lastProgressEmitTime;

  ScanBloc(this._recoveryService) : super(const ScanState()) {
    on<StartScanEvent>(_onStartScan);
    on<StopScanEvent>(_onStopScan);
    on<PauseScanEvent>(_onPauseScan);
    on<ResumeScanEvent>(_onResumeScan);
    on<CancelScanEvent>(_onCancelScan);
    on<ScanProgressUpdatedEvent>(_onProgressUpdated);
    on<FileFoundEventReceived>(_onFileFound);
    on<FsIdentifiedEventReceived>(_onFsIdentified);
    on<ScanDoneEventReceived>(_onScanDone);
    on<ScanErrorEventReceived>(_onScanError);
    on<BatchUpdateFilesEvent>(_onBatchUpdateFiles);
  }

  Future<void> _onStartScan(StartScanEvent event, Emitter<ScanState> emit) async {
    if (state.status == ScanStatus.inProgress || state.status == ScanStatus.loading) {
      return;
    }

    _internalFiles.clear();
    _startTime = DateTime.now();
    _lastProgressEmitTime = null;
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
        add(ScanProgressUpdatedEvent(
          event.percent, 
          event.speedMbps, 
          statusMessage: event.statusMessage,
        ));
      } else if (event is FileFoundEvent) {
        add(FileFoundEventReceived(event));
      } else if (event is DoneEvent) {
        add(ScanDoneEventReceived(event.duration));
      } else if (event is ErrorEvent) {
        add(ScanErrorEventReceived(event.message, event.isHardwareFailure));
      }
    }, onDone: () {
      // Fallback: if stream closes but we didn't get DoneEvent
      if (state.status == ScanStatus.inProgress || state.status == ScanStatus.loading) {
        add(ScanDoneEventReceived(state.elapsed));
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

  void _onPauseScan(PauseScanEvent event, Emitter<ScanState> emit) {
    if (state.status == ScanStatus.inProgress) {
      _recoveryService.pause();
      emit(state.copyWith(status: ScanStatus.paused));
    }
  }

  void _onResumeScan(ResumeScanEvent event, Emitter<ScanState> emit) {
    if (state.status == ScanStatus.paused) {
      _recoveryService.resume();
      emit(state.copyWith(status: ScanStatus.inProgress));
    }
  }

  void _onCancelScan(CancelScanEvent event, Emitter<ScanState> emit) {
    _recoveryService.cancel();
    _scanSubscription?.cancel();
    _flushTimer?.cancel();
    _flushTimer = null;
    _internalFiles.clear();
    emit(const ScanState(status: ScanStatus.initial));
  }

  void _onProgressUpdated(ScanProgressUpdatedEvent event, Emitter<ScanState> emit) {
    final now = DateTime.now();
    // Throttle progress updates to at most once per second to make them readable
    if (_lastProgressEmitTime != null &&
        now.difference(_lastProgressEmitTime!) < const Duration(seconds: 1)) {
      return;
    }
    _lastProgressEmitTime = now;

    final elapsed = _startTime != null ? now.difference(_startTime!) : Duration.zero;
    
    // If paused, don't update UI with progress but keep internal state updated if needed.
    // However, the copyWith will update status to inProgress if we are not careful.
    if (state.status == ScanStatus.paused) {
      emit(state.copyWith(
        percent: event.percent,
        speed: event.speedMbps,
        elapsed: elapsed,
      ));
      return;
    }

    emit(state.copyWith(
      status: ScanStatus.inProgress,
      percent: event.percent,
      speed: event.speedMbps,
      statusMessage: event.statusMessage,
      elapsed: elapsed,
    ));
  }

  void _onFileFound(FileFoundEventReceived event, Emitter<ScanState> emit) {
    _internalFiles.add(event.event as FileFoundEvent);

    _flushTimer ??= Timer(const Duration(seconds: 1), () {
        _flushTimer = null;
        add(const BatchUpdateFilesEvent());
      });
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
