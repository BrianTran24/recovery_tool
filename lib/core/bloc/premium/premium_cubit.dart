import 'package:flutter_bloc/flutter_bloc.dart';
import '../../service/premium_service.dart';

class PremiumCubit extends Cubit<bool> {
  final PremiumService _premiumService;

  PremiumCubit(this._premiumService) : super(false) {
    checkStatus();
  }

  Future<void> checkStatus() async {
    final isPremium = await _premiumService.checkPremiumStatus();
    emit(isPremium);
  }

  void setPremiumStatus(bool isPremium) {
    emit(isPremium);
  }
}
