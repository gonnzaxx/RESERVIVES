/// Gestión de Apariencia y Temas.
///
/// Controla el modo visual de la aplicación (Claro/Oscuro). Permite la
/// alternancia dinámica de estilos en toda la interfaz de usuario.

library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier encargado de gestionar el estado del tema actual.
class ThemeNotifier extends Notifier<ThemeMode> {

  @override
  ThemeMode build() {
    // Por defecto, la aplicación inicia en modo claro.
    return ThemeMode.light;
  }

  /// Establece un modo específico.
  void toggleTheme() {
    state = (state == ThemeMode.light) ? ThemeMode.dark : ThemeMode.light;
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}

/// Provider global que expone el modo de tema activo para MaterialApp.
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
