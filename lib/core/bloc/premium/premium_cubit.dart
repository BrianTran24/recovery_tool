import 'package:flutter_bloc/flutter_bloc.dart';
import '../../service/premium_service.dart';
import '../../service/storage_service.dart';

class PremiumState {
  final bool isPremium;
  final String? outputDir;

  PremiumState({
    required this.isPremium,
    this.outputDir,
  });

  PremiumState copyWith({
    bool? isPremium,
    String? outputDir,
  }) {
    return PremiumState(
      isPremium: isPremium ?? this.isPremium,
      outputDir: outputDir ?? this.outputDir,
    );
  }
}

class PremiumCubit extends Cubit<PremiumState> {
  final PremiumService _premiumService;
  final StorageService _storageService;

  PremiumCubit(this._premiumService, this._storageService)
      : super(PremiumState(isPremium: false)) {
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    final isPremium = await _premiumService.checkPremiumStatus();
    final outputDir = await _storageService.getPremiumOutputDir();
    emit(PremiumState(
      isPremium: isPremium,
      outputDir: outputDir,
    ));
  }

  Future<void> updateOutputDir(String path) async {
    await _storageService.setPremiumOutputDir(path);
    emit(state.copyWith(outputDir: path));
  }

  void setPremiumStatus(bool isPremium) {
    emit(state.copyWith(isPremium: isPremium));
  }
}
