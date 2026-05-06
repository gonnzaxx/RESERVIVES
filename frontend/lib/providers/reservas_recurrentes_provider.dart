/// Providers de Reservas Recurrentes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/reserva_recurrente.dart';
import 'package:reservives/services/api_client.dart';

/// Lista de reservas recurrentes propias del usuario.
final misReservasRecurrentesProvider =
    FutureProvider.autoDispose<List<ReservaRecurrente>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/reservas-recurrentes/');
  return (response as List)
      .map((e) => ReservaRecurrente.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Lista de reservas recurrentes pendientes de aprobación (solo admin).
final reservasRecurrentesPendientesProvider =
    FutureProvider.autoDispose<List<ReservaRecurrente>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response =
      await api.get('/reservas-recurrentes/?estado=PENDIENTE_APROBACION');
  return (response as List)
      .map((e) => ReservaRecurrente.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Notifier para crear una nueva reserva recurrente.
final crearReservaRecurrenteProvider =
    AsyncNotifierProvider<CrearReservaRecurrenteNotifier, ReservaRecurrente?>(
  CrearReservaRecurrenteNotifier.new,
);

class CrearReservaRecurrenteNotifier
    extends AsyncNotifier<ReservaRecurrente?> {
  @override
  Future<ReservaRecurrente?> build() async => null;

  Future<bool> crear({
    required String espacioId,
    required String tramoId,
    required String duracionPlan,
    required DateTime fechaInicio,
    String? observaciones,
  }) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post('/reservas-recurrentes/', body: {
        'espacio_id': espacioId,
        'tramo_id': tramoId,
        'tipo_recurrencia': TipoRecurrencia.semanal.value,
        'fecha_inicio': _formatDate(fechaInicio),
        'duracion_plan': duracionPlan,
        if (observaciones != null && observaciones.isNotEmpty)
          'observaciones': observaciones,
      });
      final reserva =
          ReservaRecurrente.fromJson(response as Map<String, dynamic>);
      state = AsyncData(reserva);
      ref.invalidate(misReservasRecurrentesProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> cancelar(String reservaId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/reservas-recurrentes/$reservaId/cancelar');
      ref.invalidate(misReservasRecurrentesProvider);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Notifier para acciones de admin (aprobar / rechazar).
final adminReservaRecurrenteProvider =
    AsyncNotifierProvider<AdminReservaRecurrenteNotifier, void>(
  AdminReservaRecurrenteNotifier.new,
);

class AdminReservaRecurrenteNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> aprobar(String reservaId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/reservas-recurrentes/$reservaId/aprobar');
      ref.invalidate(reservasRecurrentesPendientesProvider);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rechazar(String reservaId, {String? motivo}) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/reservas-recurrentes/$reservaId/rechazar',
        body: {if (motivo != null) 'motivo_rechazo': motivo},
      );
      ref.invalidate(reservasRecurrentesPendientesProvider);
      return true;
    } catch (_) {
      return false;
    }
  }
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
