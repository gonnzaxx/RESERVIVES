import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

const _languagePrefKey = 'language_code';

// Se sobreescribe desde `main.dart` con el idioma inicial
final initialLocaleProvider = Provider<Locale>((ref) => const Locale('es'));

// Idioma actual de la app.
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  () => LocaleNotifier(),
);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    return ref.read(initialLocaleProvider);
  }

  Future<void> setLocale(Locale locale) async {
    if (!AppLocalizationsDelegateSupported.isSupported(locale)) return;
    if (state == locale) return;

    state = locale;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, locale.languageCode);

    Intl.defaultLocale = locale.languageCode;
    await initializeDateFormatting(locale.languageCode, null);
  }
}

/// Carga idioma inicial
Future<Locale> loadInitialLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_languagePrefKey);
  if (saved != null && AppLocalizationsDelegateSupported.isSupportedCode(saved)) {
    return Locale(saved);
  }

  final systemLocale = PlatformDispatcher.instance.locale;
  final code = systemLocale.languageCode;

  if (AppLocalizationsDelegateSupported.isSupportedCode(code)) {
    return Locale(code);
  }
  
  // Fallback
  return const Locale('es');
}

class AppLocalizationsDelegateSupported {
  static bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
  }

  static bool isSupportedCode(String code) {
    return AppLocalizations.supportedLocales.any((l) => l.languageCode == code);
  }
}

