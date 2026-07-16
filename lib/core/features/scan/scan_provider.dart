// lib/features/scan/scan_provider.dart
import 'dart:async';
import 'dart:collection';

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
    referenceVideo: params.referenceVideo,
  );
});

// Accumulate files tìm được
final foundFilesProvider = StateNotifierProvider
    .autoDispose<FoundFilesNotifier, List<FileFoundEvent>>((ref) {
  return FoundFilesNotifier();
});

class FoundFilesNotifier extends StateNotifier<List<FileFoundEvent>> {
  FoundFilesNotifier() : super(const []);

  // Danh sách nội bộ tăng trưởng (growable). Ta KHÔNG sao chép toàn bộ list mỗi
  // lần tìm thấy 1 file (cách cũ `state = [...state, e]` là O(n^2) → phình bộ nhớ
  // nghiêm trọng khi quét ra hàng chục nghìn file). Thay vào đó append vào list này
  // và chỉ phát một "view" mới (bọc, không copy phần tử) theo lô, tối đa ~10 lần/giây.
  final List<FileFoundEvent> _items = [];
  Timer? _flushTimer;
  bool _dirty = false;

  void add(FileFoundEvent e) {
    _items.add(e);
    _dirty = true;
    _flushTimer ??= Timer(const Duration(milliseconds: 100), _flush);
  }

  void _flush() {
    _flushTimer = null;
    if (!_dirty) return;
    _dirty = false;
    // UnmodifiableListView bọc trực tiếp _items (không copy phần tử); mỗi lần tạo
    // một view mới nên StateNotifier phát hiện thay đổi và rebuild UI.
    state = UnmodifiableListView(_items);
  }

  void clear() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _items.clear();
    _dirty = false;
    state = const [];
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    super.dispose();
  }
}

// Params class
class ScanParams {
  final String sourcePath, outputDir;
  final bool enableFat, enableCarve;
  final int scanMode;
  final String referenceVideo;
  const ScanParams({
    required this.sourcePath,
    required this.outputDir,
    this.enableFat = true,
    this.enableCarve = true,
    this.scanMode = 1,
    this.referenceVideo = '',
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
          scanMode == other.scanMode &&
          referenceVideo == other.referenceVideo;

  @override
  int get hashCode =>
      sourcePath.hashCode ^
      outputDir.hashCode ^
      enableFat.hashCode ^
      enableCarve.hashCode ^
      scanMode.hashCode ^
      referenceVideo.hashCode;
}