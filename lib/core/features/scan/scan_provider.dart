// lib/features/scan/scan_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../models/recovery_event.dart';
import '../../service/recovery_service.dart';

// Service singleton
final recoveryServiceProvider = Provider((ref) {
  return RecoveryService();
});

// Scan stream — active khi đang scan
final scanStreamProvider = StreamProvider.autoDispose
    .family<RecoveryEvent, ScanParams>((ref, params) {
  final service = ref.watch(recoveryServiceProvider);
  return service.startScan(
    sourcePath:  params.sourcePath,
    outputDir:   params.outputDir,
    enableFat:   params.enableFat,
    enableCarve: params.enableCarve,
    scanMode:    params.scanMode,
  );
});

// Accumulate files tìm được
final foundFilesProvider = StateNotifierProvider
    .autoDispose<FoundFilesNotifier, List<FileFoundEvent>>((ref) {
  return FoundFilesNotifier();
});

class FoundFilesNotifier extends StateNotifier<List<FileFoundEvent>> {
  FoundFilesNotifier() : super([]);
  void add(FileFoundEvent e) => state = [...state, e];
  void clear()               => state = [];
}

// Params class
class ScanParams {
  final String sourcePath, outputDir;
  final bool enableFat, enableCarve;
  final int scanMode;
  const ScanParams({
    required this.sourcePath,
    required this.outputDir,
    this.enableFat = true,
    this.enableCarve = true,
    this.scanMode = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanParams &&
          runtimeType == other.runtimeType &&
          sourcePath == other.sourcePath &&
          outputDir == other.outputDir &&
          enableFat == other.enableFat &&
          enableCarve == other.enableCarve &&
          scanMode == other.scanMode;

  @override
  int get hashCode =>
      sourcePath.hashCode ^
      outputDir.hashCode ^
      enableFat.hashCode ^
      enableCarve.hashCode ^
      scanMode.hashCode;
}