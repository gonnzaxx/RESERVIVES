import 'package:flutter_riverpod/flutter_riverpod.dart';

final adminCountersVersionProvider =
    NotifierProvider<AdminCountersVersionNotifier, int>(
      AdminCountersVersionNotifier.new,
    );

class AdminCountersVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

void notifyAdminCountersChanged(WidgetRef ref) {
  ref.read(adminCountersVersionProvider.notifier).bump();
}

const Set<String> _dashboardCounterEvents = {
  'reserva_created',
  'reserva_updated',
  'reserva_cancelada',
  'reserva_aprobada',
  'reserva_rechazada',
  'reserva_servicio_created',
  'reserva_servicio_cancelada',
  'reserva_servicio_aprobada',
  'reserva_servicio_rechazada',
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

bool shouldRefreshAdminDashboardCounters(String? event) {
  if (event == null) return true;
  return _dashboardCounterEvents.contains(event);
}
