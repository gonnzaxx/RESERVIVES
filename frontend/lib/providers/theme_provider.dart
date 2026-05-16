/// Gestión de Apariencia y Temas.
///
/// Controla el modo visual de la aplicación (Claro/Oscuro/Sistema).
/// La preferencia del usuario se persiste en SharedPreferences y tiene
/// prioridad sobre el tema por defecto configurado por el administrador.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePrefKey = 'user_theme_mode';

/// Provider de inyección para el tema inicial cargado antes del arranque.
/// null significa que el usuario no ha establecido preferencia propia.
final initialThemeModeProvider = Provider<ThemeMode?>((ref) => null);

/// Notifier del tema activo. null = sin preferencia del usuario.
class ThemeNotifier extends Notifier<ThemeMode?> {
  @override
  ThemeMode? build() {
    return ref.read(initialThemeModeProvider);
  }

  /// Alterna entre claro y oscuro (para el toggle rápido del perfil).
  Future<void> toggleTheme() async {
    final current = state ?? ThemeMode.light;
    await setThemeMode(current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Establece y persiste el modo de tema elegido por el usuario.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, _modeToString(mode));
  }

  /// Elimina la preferencia del usuario y vuelve al tema del administrador.
  Future<void> clearThemeMode() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themePrefKey);
  }
}

/// Provider global que expone el tema elegido por el usuario (null = sin override).
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode?>(
  ThemeNotifier.new,
);

String _modeToString(ThemeMode mode) {
  switch (mode) {
    case ThemeMode.dark:
      return 'dark';
    case ThemeMode.system:
      return 'system';
    case ThemeMode.light:
      return 'light';
  }
}

ThemeMode? _modeFromString(String? value) {
  switch (value) {
    case 'dark':
      return ThemeMode.dark;
    case 'system':
      return ThemeMode.system;
    case 'light':
      return ThemeMode.light;
    default:
      return null;
  }
}

/// Carga la preferencia de tema del usuario desde SharedPreferences.
/// Devuelve null si el usuario no ha establecido ninguna preferencia.
Future<ThemeMode?> loadInitialTheme() async {
  final prefs = await SharedPreferences.getInstance();
  return _modeFromString(prefs.getString(_themePrefKey));
}
