/// Gestión de Preferencias de Notificaciones.
///
/// Administra la configuración de alertas del usuario (Push, Email, etc.).
/// Permite que el usuario decida qué tipo de comunicaciones desea recibir
/// y sincroniza estos ajustes con el servidor de mensajería.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/notification_preferences.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/services/api_client.dart';

/// Proveedor del estado de configuración de notificaciones.
///
/// Expone un [AsyncValue] que contiene las preferencias actuales. No utiliza
/// autoDispose para mantener la configuración en memoria durante toda la sesión
/// y evitar parpadeos en la interfaz de ajustes.
final notificationPreferencesProvider = AsyncNotifierProvider<
    NotificationPreferencesNotifier, NotificationPreferences>(() {
  return NotificationPreferencesNotifier();
});

/// Controlador encargado de la persistencia de los ajustes de notificación.
class NotificationPreferencesNotifier
    extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    // En modo invitado no hay sesión; devolvemos valores por defecto sin llamar al backend.
    if (ref.read(authProvider).isGuest) return NotificationPreferences.defaults();
    return _fetch();
  }

  /// Recupera las preferencias actuales del perfil del usuario.
  Future<NotificationPreferences> _fetch() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/notificaciones/preferencias');
    return NotificationPreferences.fromJson(response as Map<String, dynamic>);
  }

  /// Actualiza los ajustes de notificación en el servidor.
  ///
  /// Utiliza una actualización local inmediata (Optimistic UI) estableciendo el
  /// estado con los datos recibidos antes de completar la petición de red,
  /// asegurando una respuesta instantánea en los interruptores (switches) de la UI.
  Future<void> savePreferences(NotificationPreferences preferences) async {
    state = AsyncData(preferences);
    state = await AsyncValue.guard(() async {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/notificaciones/preferencias',
        body: preferences.toJson(),
      );
      return NotificationPreferences.fromJson(response as Map<String, dynamic>);
    });
  }
}
