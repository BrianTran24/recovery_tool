import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recovery_tool/core/service/storage_service.dart';

final storageServiceProvider = Provider((ref) => StorageService());

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

class LocaleNotifier extends Notifier<Locale> {
  late StorageService _storageService;

  @override
  Locale build() {
    _storageService = ref.read(storageServiceProvider);
    _loadLocale();
    return const Locale('vi');
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
