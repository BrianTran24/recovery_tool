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
    devicePath:  params.devicePath,
    outputDir:   params.outputDir,
    enableFat:   params.enableFat,
    enableCarve: params.enableCarve,
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
  final String devicePath, outputDir;
  final bool enableFat, enableCarve;
  const ScanParams({
    required this.devicePath,
    required this.outputDir,
    this.enableFat = true,
    this.enableCarve = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanParams &&
          runtimeType == other.runtimeType &&
          devicePath == other.devicePath &&
          outputDir == other.outputDir &&
          enableFat == other.enableFat &&
          enableCarve == other.enableCarve;

  @override
  int get hashCode =>
      devicePath.hashCode ^
      outputDir.hashCode ^
      enableFat.hashCode ^
      enableCarve.hashCode;
}