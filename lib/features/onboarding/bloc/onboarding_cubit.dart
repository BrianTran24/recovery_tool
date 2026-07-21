import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/service/storage_service.dart';

class OnboardingCubit extends Cubit<bool?> {
  final StorageService _storageService;

  OnboardingCubit(this._storageService) : super(null) {
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    final isComplete = await _storageService.isOnboardingComplete();
    emit(isComplete);
  }

  Future<void> completeOnboarding() async {
    await _storageService.setOnboardingComplete(true);
    emit(true);
  }
}
