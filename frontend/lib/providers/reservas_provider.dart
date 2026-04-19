/// RESERVIVES - Proveedores de Reservas.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/servicio_provider.dart';
import 'package:reservives/services/api_client.dart';

final misReservasProvider =
AsyncNotifierProvider.autoDispose<MisReservasNotifier, List<Reserva>>(
      () => MisReservasNotifier(),
);

class MisReservasNotifier extends AsyncNotifier<List<Reserva>> {
  @override
  Future<List<Reserva>> build() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/reservas-espacios/');
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

  void replaceOptimistic(String tempId, Reserva real) {
    final current = _currentList();
    final index = current.indexWhere((r) => r.id == tempId);
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

final activityHistoryProvider = Provider.autoDispose<AsyncValue<List<Reserva>>>((ref) {
  final reservasAsync = ref.watch(misReservasProvider);
  final serviciosAsync = ref.watch(misReservasServiciosProvider);

  return reservasAsync.when(
    data: (reservas) {
      return serviciosAsync.when(
        data: (servicios) => AsyncData(_mergeAndSort(reservas, servicios)),
        loading: () => const AsyncLoading(),
        error: (error, stackTrace) => AsyncError(error, stackTrace),
      );
    },
    loading: () => const AsyncLoading(),
    error: (error, stackTrace) => AsyncError(error, stackTrace),
  );
});

List<Reserva> _mergeAndSort(List<Reserva> a, List<Reserva> b) {
  final all = [...a, ...b];
  all.sort((x, y) => y.fechaInicio.compareTo(x.fechaInicio));
  return all;
}

final crearReservaProvider =
AsyncNotifierProvider<CrearReservaNotifier, Reserva?>(
  CrearReservaNotifier.new,
);

class CrearReservaNotifier extends AsyncNotifier<Reserva?> {
  @override
  Future<Reserva?> build() async => null;

  Future<bool> crearReserva(
      String espacioId,
      DateTime fecha,
      String tramoId,
      String? observaciones,
      ) async {
    final user = ref.read(authProvider).user;
    final previousReservas = ref.read(misReservasProvider).maybeWhen(
      data: (items) => List<Reserva>.from(items),
      orElse: () => <Reserva>[],
    );

    final tempId = 'optimistic-reserva-${DateTime.now().microsecondsSinceEpoch}';
    final fechaOptimista = DateTime(fecha.year, fecha.month, fecha.day);
    final optimistic = Reserva(
      id: tempId,
      usuarioId: user?.id ?? '',
      espacioId: espacioId,
      fechaInicio: fechaOptimista,
      fechaFin: fechaOptimista.add(const Duration(hours: 1)),
      observaciones: observaciones,
      estado: EstadoReserva.pendiente,
      tokensConsumidos: 0,
      tramoId: tramoId,
      nombreUsuario: user == null ? null : '${user.nombre} ${user.apellidos}',
      nombreEspacio: null,
      tipoEspacio: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(misReservasProvider.notifier).insertOptimistic(optimistic);
    state = AsyncData(optimistic);

    try {
      final apiClient = ref.read(apiClientProvider);
      // Formatear fecha como YYYY-MM-DD
      final fechaStr = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
      final response = await apiClient.post('/reservas-espacios/', body: {
        'espacio_id': espacioId,
        'fecha': fechaStr,
        'tramo_id': tramoId,
        if (observaciones != null) 'observaciones': observaciones,
      });

      final reserva = Reserva.fromJson(response as Map<String, dynamic>);
      ref.read(misReservasProvider.notifier).replaceOptimistic(tempId, reserva);

      unawaited(ref.read(authProvider.notifier).refreshCurrentUser());

      state = AsyncData(reserva);
      return true;
    } catch (error, stackTrace) {
      ref.read(misReservasProvider.notifier).setFromSnapshot(previousReservas);
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> cancelarReserva(String reservaId) async {
    final previousReservas = ref.read(misReservasProvider).maybeWhen(
      data: (items) => List<Reserva>.from(items),
      orElse: () => <Reserva>[],
    );

    ref.read(misReservasProvider.notifier).markCancelledOptimistic(reservaId);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/reservas-espacios/$reservaId/cancelar');
      final updated = Reserva.fromJson(response as Map<String, dynamic>);
      ref.read(misReservasProvider.notifier).replaceOptimistic(reservaId, updated);

      unawaited(ref.read(authProvider.notifier).refreshCurrentUser());

      state = AsyncData(updated);
      return true;
    } catch (error, stackTrace) {
      ref.read(misReservasProvider.notifier).setFromSnapshot(previousReservas);
      state = AsyncError(error, stackTrace);
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
    tramoId: reserva.tramoId,
    tramo: reserva.tramo,
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

