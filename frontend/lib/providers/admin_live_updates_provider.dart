/// IES Luis Vives App - Sistema de Invalidación y Sincronización de Contadores.
///
/// Este archivo gestiona el control de versiones local para los contadores del
/// dashboard administrativo. Permite invalidar datos cacheados cuando ocurren
/// eventos específicos en el sistema (notificaciones push, sockets, etc.).

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Proveedor global de la versión de los contadores.
final adminCountersVersionProvider =
    NotifierProvider<AdminCountersVersionNotifier, int>(
      AdminCountersVersionNotifier.new,
    );

/// Notifier que refresca los datos administrativos.
/// Incrementa un entero cada vez que se detecta un cambio en el servidor.
class AdminCountersVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  /// Incrementa la versión para forzar la actualización de los providers que la observan.
  void bump() => state = state + 1;
}

/// Función para notificar cambios desde cualquier parte de la UI.
void notifyAdminCountersChanged(WidgetRef ref) {
  ref.read(adminCountersVersionProvider.notifier).bump();
}

const Set<String> _dashboardCounterEvents = {
  // Eventos de Reservas de Espacios
  'reserva_created',
  'reserva_updated',
  'reserva_cancelada',
  'reserva_aprobada',
  'reserva_rechazada',

  // Eventos de Reservas de Servicios
  'reserva_servicio_created',
  'reserva_servicio_cancelada',
  'reserva_servicio_aprobada',
  'reserva_servicio_rechazada',

  // Eventos de Entidades Maestras
  'usuario_created',
  'usuario_updated',
  'usuario_deleted',
  'espacio_created',
  'espacio_updated',
  'espacio_deleted',
  'anuncio_created',
  'anuncio_updated',
  'anuncio_deleted',
};

/// Evalúa si un evento recibido (ej: vía Push Notification) requiere
/// disparar una recarga de los contadores del dashboard.
///
/// Retorna `true` si el evento está en la lista de interés o si el evento es nulo.
bool shouldRefreshAdminDashboardCounters(String? event) {
  if (event == null) return true;
  return _dashboardCounterEvents.contains(event);
}
