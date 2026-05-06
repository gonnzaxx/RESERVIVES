/// Centro de Mensajería y Notificaciones.
///
/// Gestiona el buzón de entrada del usuario, el conteo de mensajes no leídos
/// y la sincronización periódica con el servidor. Implementa un sistema de
/// refresco automático ("polling") y borrado optimista para una UI fluida.

library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/notificacion.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/services/api_client.dart';

/// Proveedor de "latidos" (ticks) para el refresco automático.
///
/// Genera un evento cada 8 segundos que activa la recarga de otros proveedores
/// que lo observen. Se destruye automáticamente si no hay widgets escuchando.
final notificationsRefreshTickProvider = StreamProvider.autoDispose<int>((
    ref,
    ) async* {
  var tick = 0;
  yield tick;
  while (true) {
    await Future<void>.delayed(const Duration(seconds: 8));
    tick++;
    yield tick;
  }
});

/// Contador de notificaciones no leídas sincronizado con el servidor.
///
/// Observa [notificationsRefreshTickProvider] para actualizarse periódicamente.
/// En modo invitado devuelve 0 directamente sin llamar al backend.
final unreadNotificationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(notificationsRefreshTickProvider);
  if (ref.read(authProvider).isGuest) return 0;
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/notificaciones/count');
  return (response['no_leidas'] as num).toInt();
});

/// Proveedor principal del buzón de entrada (inbox).
final notificationsInboxProvider =
AsyncNotifierProvider<NotificationsInboxNotifier, List<Notificacion>>(() {
  return NotificationsInboxNotifier();
});

/// Controlador para la gestión del historial de notificaciones.
class NotificationsInboxNotifier extends AsyncNotifier<List<Notificacion>> {

  @override
  Future<List<Notificacion>> build() async {
    // En modo invitado no hay sesión; devolvemos lista vacía sin llamar al backend.
    if (ref.read(authProvider).isGuest) return [];
    return _fetchNotifications();
  }

  /// Recupera el listado completo de notificaciones desde el backend.
  Future<List<Notificacion>> _fetchNotifications() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/notificaciones/');
    return (response as List<dynamic>)
        .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Recarga manualmente el listado de notificaciones.
  Future<void> loadUnread() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchNotifications());
  }

  /// Marca todas las notificaciones pendientes como leídas ("consume").
  /// Invalida el contador de no leídas para forzar su actualización inmediata.
  Future<void> consumeUnread() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/notificaciones/consumir');

      // Invalidamos el contador para que la burbuja roja desaparezca de la UI.
      ref.invalidate(unreadNotificationsCountProvider);

      return (response as List<dynamic>)
          .map((e) => Notificacion.fromJson(e as Map<String, dynamic>))
          .toList();
    });
  }

  /// Elimina una notificación específica con lógica de UI Optimista.
  Future<void> deleteNotification(String id) async {
    final oldState = state.value ?? [];
    state = AsyncData(oldState.where((n) => n.id != id).toList());

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete('/notificaciones/$id');
      ref.invalidate(unreadNotificationsCountProvider);
    } catch (e) {
      state = AsyncData(oldState);
    }
  }
}
