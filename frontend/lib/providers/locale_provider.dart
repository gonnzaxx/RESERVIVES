/// Gestión de Internacionalización y Localización (i18n).
///
/// Este módulo centraliza la lógica de cambio de idioma de la aplicación.
/// Maneja la persistencia de la preferencia del usuario, la sincronización
/// con la librería `intl` para formatos de fecha/moneda y la detección
/// automática del idioma del sistema.

library;

import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../i10n/app_localizations.dart';

/// Clave para el almacenamiento persistente del código de idioma.
const _languagePrefKey = 'language_code';

/// Proveedor del idioma inicial detectado durante el arranque.
/// Se inyecta en el `ProviderScope` desde el `main.dart`.
final initialLocaleProvider = Provider<Locale>((ref) => const Locale('es'));

// Idioma actual de la app.
final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  () => LocaleNotifier(),
);

/// Notifier que expone y gestiona el idioma activo de la interfaz.
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    return ref.read(initialLocaleProvider);
  }

  /// Cambia el idioma de la aplicación y actualiza las configuraciones globales.
  Future<void> setLocale(Locale locale) async {
    // Validar si el idioma es compatible antes de aplicar cambios.
    if (!AppLocalizationsDelegateSupported.isSupported(locale)) return;
    if (state == locale) return;

    state = locale;

    // Persistir la elección del usuario.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePrefKey, locale.languageCode);

    // Sincronizar la librería de internacionalización estándar de Dart.
    Intl.defaultLocale = locale.languageCode;
    await initializeDateFormatting(locale.languageCode, null);
  }
}

/// Lógica de pre-carga para determinar qué idioma usar al abrir la app.
///
/// Prioridad:
/// 1. Idioma guardado previamente por el usuario.
/// 2. Idioma del sistema operativo (si está soportado).
/// 3. Español ('es') como fallback.
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

/// Helper para validar la compatibilidad de locales con los recursos de la app.
class AppLocalizationsDelegateSupported {
  /// Verifica si un objeto [Locale] tiene traducciones disponibles.
  static bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
  }

  /// Verifica si un código de cadena (ej: 'en') está soportado.
  static bool isSupportedCode(String code) {
    return AppLocalizations.supportedLocales.any((l) => l.languageCode == code);
  }
}

