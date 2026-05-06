/// Gestión de Configuración Global del Sistema.
///
/// Este archivo maneja el estado de los ajustes globales de la aplicación
/// Utiliza un modelo de clave-valor

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/services/api_client.dart';

/// Estado inmutable para la pantalla de configuración administrativa.
class AdminSettingsState {
  final bool isLoading; // Indica si hay una operación de red en curso (carga o guardado).
  final Map<String, String> data; // Diccionario de configuraciones recuperadas del servidor.
  final String? error;

  AdminSettingsState({required this.isLoading, required this.data, this.error});

  AdminSettingsState copyWith({
    bool? isLoading,
    Map<String, String>? data,
    String? error,
  }) {
    return AdminSettingsState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      error: error,
    );
  }
}

/// Notifier encargado de orquestar la lectura y escritura de ajustes globales.
class AdminSettingsNotifier extends Notifier<AdminSettingsState> {
  @override
  AdminSettingsState build() {
    Future.microtask(loadSettings);
    return AdminSettingsState(isLoading: true, data: {});
  }

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(apiClientProvider);
      final responseBody = await client.get('/admin/configuracion');

      final decoded = responseBody as Map<String, dynamic>;

      // Normalizamos todos los valores a String para facilitar su manejo en formularios.
      final map = decoded.map((key, value) => MapEntry(key, value.toString()));

      state = state.copyWith(isLoading: false, data: map);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Envía un lote de cambios al servidor.
  ///
  /// Recibe un [Map] con las claves modificadas y retorna `true` si la
  /// operación fue exitosa tras recargar los datos actualizados.
  Future<bool> updateSettings(Map<String, String> newSettings) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final client = ref.read(apiClientProvider);

      final configsList = newSettings.entries
          .map((e) => {'clave': e.key, 'valor': e.value})
          .toList();

      await client.put('/admin/configuracion', body: {'configs': configsList});

      await loadSettings();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

/// Proveedor para la configuración administrativa.
/// Se libera de memoria cuando el administrador sale de la sección de ajustes.
final adminSettingsProvider =
NotifierProvider.autoDispose<AdminSettingsNotifier, AdminSettingsState>(
  AdminSettingsNotifier.new,
);