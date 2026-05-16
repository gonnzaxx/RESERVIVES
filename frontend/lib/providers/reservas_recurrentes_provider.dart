/// Providers de Reservas Recurrentes.
///
/// Gestiona la creación, consulta y moderación de reservas de tipo recurrente,
/// que requieren aprobación del administrador antes de activarse.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/reserva_recurrente.dart';
import 'package:reservives/services/api_client.dart';

/// Reservas recurrentes activas del usuario autenticado.
final misReservasRecurrentesProvider =
    FutureProvider.autoDispose<List<ReservaRecurrente>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/reservas-recurrentes/');
  return (response as List)
      .map((e) => ReservaRecurrente.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Reservas recurrentes pendientes de aprobación (solo visible para administradores).
final reservasRecurrentesPendientesProvider =
    FutureProvider.autoDispose<List<ReservaRecurrente>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response =
      await api.get('/reservas-recurrentes/?estado=PENDIENTE_APROBACION');
  return (response as List)
      .map((e) => ReservaRecurrente.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Controlador para crear y cancelar reservas recurrentes propias.
final crearReservaRecurrenteProvider =
    AsyncNotifierProvider<CrearReservaRecurrenteNotifier, ReservaRecurrente?>(
  CrearReservaRecurrenteNotifier.new,
);

class CrearReservaRecurrenteNotifier
    extends AsyncNotifier<ReservaRecurrente?> {
  @override
  Future<ReservaRecurrente?> build() async => null;

  /// Envía al backend la solicitud de nueva reserva recurrente semanal.
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

  /// Cancela una reserva recurrente propia identificada por [reservaId].
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

/// Controlador exclusivo para acciones administrativas: aprobar y rechazar solicitudes.
final adminReservaRecurrenteProvider =
    AsyncNotifierProvider<AdminReservaRecurrenteNotifier, void>(
  AdminReservaRecurrenteNotifier.new,
);

class AdminReservaRecurrenteNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Aprueba la reserva recurrente e invalida la lista de pendientes.
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

  /// Rechaza la reserva recurrente, opcionalmente con un [motivo] de rechazo.
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

// Formatea un DateTime al estándar YYYY-MM-DD requerido por el backend.
String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
