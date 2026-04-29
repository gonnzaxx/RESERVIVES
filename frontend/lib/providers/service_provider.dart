/// RESERVIVES - Proveedores de Servicios del Instituto.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/models/servicio.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/bookings_live_updates_provider.dart';
import 'package:reservives/services/api_client.dart';

final serviciosInstitutoProvider = FutureProvider.autoDispose<List<ServicioInstituto>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/servicios/');
  return (response as List).map((e) => ServicioInstituto.fromJson(e)).toList();
});

final serviciosSearchQueryProvider =
NotifierProvider.autoDispose<_ServiciosSearchQuery, String>(
  _ServiciosSearchQuery.new,
);

class _ServiciosSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

final serviciosFiltradosProvider =
Provider.autoDispose<AsyncValue<List<ServicioInstituto>>>((ref) {
  final serviciosAsync = ref.watch(serviciosInstitutoProvider);
  final query = ref.watch(serviciosSearchQueryProvider).trim().toLowerCase();

  return serviciosAsync.whenData((items) {
    if (query.isEmpty) return items;
    return items
        .where((s) =>
    s.nombre.toLowerCase().contains(query) ||
        (s.descripcion?.toLowerCase().contains(query) ?? false) ||
        (s.ubicacion?.toLowerCase().contains(query) ?? false))
        .toList();
  });
});

final servicioDetalleProvider =
FutureProvider.family.autoDispose<ServicioInstituto, String>(
      (ref, servicioId) async {
    final inList = await ref.watch(serviciosInstitutoProvider.future);
    for (final servicio in inList) {
      if (servicio.id == servicioId) return servicio;
    }

    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/servicios/$servicioId');
    return ServicioInstituto.fromJson(response as Map<String, dynamic>);
  },
);

final misReservasServiciosProvider =
AsyncNotifierProvider.autoDispose<MisReservasServiciosNotifier, List<Reserva>>(
      () => MisReservasServiciosNotifier(),
);

class MisReservasServiciosNotifier extends AsyncNotifier<List<Reserva>> {
  @override
  Future<List<Reserva>> build() async {
    ref.watch(reservasPollTickProvider);
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/servicios/reservas');
    return (response as List)
        .map((e) => Reserva.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<Reserva> _currentList() {
    return state.maybeWhen(
      data: (items) => List<Reserva>.from(items),
      orElse: () => <Reserva>[],
    );
  }

  void setFromSnapshot(List<Reserva> snapshot) {
    state = AsyncData(List<Reserva>.from(snapshot));
  }

  void insertOptimistic(Reserva reserva) {
    final current = _currentList();
    current.insert(0, reserva);
    current.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
    state = AsyncData(current);
  }

  void replaceOptimistic(String id, Reserva real) {
    final current = _currentList();
    final index = current.indexWhere((r) => r.id == id);
    if (index == -1) {
      current.insert(0, real);
    } else {
      current[index] = real;
    }
    current.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
    state = AsyncData(current);
  }

  void markCancelledOptimistic(String reservaId) {
    final current = _currentList();

    state = AsyncData(
      current
          .map((r) => r.id == reservaId ? _copyReservaWithEstado(r, EstadoReserva.cancelada) : r)
          .toList(),
    );
  }
}

final reservarServicioProvider =
AsyncNotifierProvider<ReservarServicioNotifier, Reserva?>(
  ReservarServicioNotifier.new,
);

class ReservarServicioNotifier extends AsyncNotifier<Reserva?> {
  @override
  Future<Reserva?> build() async => null;

  Future<bool> reservar(
      String servicioId,
      DateTime fecha,
      String tramoId,
      String? observaciones,
      ) async {
    final user = ref.read(authProvider).user;
    final previous = ref.read(misReservasServiciosProvider).maybeWhen(
      data: (items) => List<Reserva>.from(items),
      orElse: () => <Reserva>[],
    );

    final tempId = 'optimistic-servicio-${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = Reserva(
      id: tempId,
      usuarioId: user?.id ?? '',
      espacioId: servicioId,
      fechaInicio: fecha, // Provisional hasta que llegue la real
      fechaFin: fecha.add(const Duration(hours: 1)),
      observaciones: observaciones,
      estado: EstadoReserva.pendiente,
      tokensConsumidos: 0,
      nombreUsuario: user == null ? null : '${user.nombre} ${user.apellidos}',
      nombreEspacio: null,
      tipoEspacio: 'SERVICIO',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(misReservasServiciosProvider.notifier).insertOptimistic(optimistic);
    state = AsyncData(optimistic);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/servicios/reservar', body: {
        'servicio_id': servicioId,
        'fecha': DateFormat('yyyy-MM-dd').format(fecha),
        'tramo_id': tramoId,
        if (observaciones != null) 'observaciones': observaciones,
      });

      final reserva = Reserva.fromJson(response as Map<String, dynamic>);
      ref.read(misReservasServiciosProvider.notifier).replaceOptimistic(tempId, reserva);

      unawaited(ref.read(authProvider.notifier).refreshCurrentUser());

      state = AsyncData(reserva);
      return true;
    } catch (error, stackTrace) {
      ref.read(misReservasServiciosProvider.notifier).setFromSnapshot(previous);
      state = AsyncError(Exception(_toFriendlyMessage(error)), stackTrace);
      return false;
    }
  }

  Future<bool> cancelarReservaServicio(String reservaId) async {
    final previous = ref.read(misReservasServiciosProvider).maybeWhen(
      data: (items) => List<Reserva>.from(items),
      orElse: () => <Reserva>[],
    );

    ref.read(misReservasServiciosProvider.notifier).markCancelledOptimistic(reservaId);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/servicios/reservas/$reservaId/cancelar');
      final updated = Reserva.fromJson(response as Map<String, dynamic>);

      ref.read(misReservasServiciosProvider.notifier).replaceOptimistic(reservaId, updated);

      unawaited(ref.read(authProvider.notifier).refreshCurrentUser());

      state = AsyncData(updated);
      return true;
    } catch (error, stackTrace) {
      ref.read(misReservasServiciosProvider.notifier).setFromSnapshot(previous);
      state = AsyncError(Exception(_toFriendlyMessage(error)), stackTrace);
      return false;
    }
  }
}

Reserva _copyReservaWithEstado(Reserva reserva, EstadoReserva nuevoEstado) {
  return Reserva(
    id: reserva.id,
    usuarioId: reserva.usuarioId,
    espacioId: reserva.espacioId,
    fechaInicio: reserva.fechaInicio,
    fechaFin: reserva.fechaFin,
    observaciones: reserva.observaciones,
    estado: nuevoEstado,
    tokensConsumidos: reserva.tokensConsumidos,
    nombreUsuario: reserva.nombreUsuario,
    nombreEspacio: reserva.nombreEspacio,
    tipoEspacio: reserva.tipoEspacio,
    createdAt: reserva.createdAt,
    updatedAt: DateTime.now(),
  );
}

String _toFriendlyMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'No se pudo completar la operación. Inténtalo de nuevo.';
}
