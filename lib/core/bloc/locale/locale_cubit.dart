import 'dart:ui';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../service/storage_service.dart';

class LocaleCubit extends Cubit<Locale> {
  final StorageService _storageService;
  static const List<String> _supportedLanguages = ['en', 'vi'];

  LocaleCubit(this._storageService) : super(const Locale('en')) {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final savedLanguageCode = await _storageService.getLanguage();
    
    if (savedLanguageCode != null) {
      emit(Locale(savedLanguageCode));
    } else {
      // First run: detect system locale
      final systemLocale = PlatformDispatcher.instance.locale;
      final languageCode = systemLocale.languageCode.toLowerCase();
      
      if (_supportedLanguages.contains(languageCode)) {
        emit(Locale(languageCode));
      } else {
        // Fallback to English
        emit(const Locale('en'));
      }
    }
  }

  Future<void> setLocale(Locale locale) async {
    emit(locale);
    await _storageService.setLanguage(locale.languageCode);
  }
}
