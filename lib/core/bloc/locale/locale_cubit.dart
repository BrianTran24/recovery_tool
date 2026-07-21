import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../service/storage_service.dart';

class LocaleCubit extends Cubit<Locale> {
  final StorageService _storageService;

  LocaleCubit(this._storageService) : super(const Locale('vi')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final languageCode = await _storageService.getLanguage();
    if (languageCode != null) {
      emit(Locale(languageCode));
    }
  }

  Future<void> setLocale(Locale locale) async {
    emit(locale);
    await _storageService.setLanguage(locale.languageCode);
  }
}
