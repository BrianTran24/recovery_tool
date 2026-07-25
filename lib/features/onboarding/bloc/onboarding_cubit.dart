import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/service/storage_service.dart';

class OnboardingCubit extends Cubit<bool?> {
  final StorageService _storageService;

  OnboardingCubit(this._storageService) : super(null) {
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    // Check .env override
    final override = dotenv.maybeGet('ALWAYS_SHOW_ONBOARDING');
    if (override != null && override != 'null' && override.isNotEmpty) {
      if (override.toLowerCase() == 'true') {
        emit(false); // Always show onboarding (onboardingComplete = false)
        return;
      } else if (override.toLowerCase() == 'false') {
        emit(true); // Always skip onboarding (onboardingComplete = true)
        return;
      }
    }

    final isComplete = await _storageService.isOnboardingComplete();
    emit(isComplete);
  }

  Future<void> completeOnboarding() async {
    await _storageService.setOnboardingComplete(true);
    emit(true);
  }
}
