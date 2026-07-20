import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recovery_tool/core/service/storage_service.dart';

final storageServiceProvider = Provider((ref) => StorageService());

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier(ref.read(storageServiceProvider));
});

class LocaleNotifier extends StateNotifier<Locale> {
  final StorageService _storageService;

  LocaleNotifier(this._storageService) : super(const Locale('vi')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final languageCode = await _storageService.getLanguage();
    if (languageCode != null) {
      state = Locale(languageCode);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await _storageService.setLanguage(locale.languageCode);
  }
}
