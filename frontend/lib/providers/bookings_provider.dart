/// Proveedores de Reservas.
///
/// Gestiona el ciclo de vida de las reservas de espacios.
/// Implementa UI Optimista para garantizar una respuesta inmediata al usuario
/// y sincronización en tiempo real mediante [bookingsLiveVersionProvider].

library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/reserva.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/bookings_live_updates_provider.dart';
import 'package:reservives/providers/service_provider.dart';
import 'package:reservives/services/api_client.dart';

/// Proveedor de la lista de reservas de espacios del usuario autenticado.
final misReservasProvider =
AsyncNotifierProvider.autoDispose<MisReservasNotifier, List<Reserva>>(
      () => MisReservasNotifier(),
);

/// Controlador encargado de gestionar las reservas de espacios con soporte optimista.
class MisReservasNotifier extends AsyncNotifier<List<Reserva>> {
  @override
  Future<List<Reserva>> build() async {
    // Escucha cambios de versión del servidor para invalidar la caché local.
    ref.watch(bookingsLiveVersionProvider);
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/reservas-espacios/');
    return (response as List)
        .map((e) => Reserva.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Helper privado para obtener el estado actual de los datos sin lógica de error/carga.
  List<Reserva> _currentList() {
    return state.maybeWhen(
      data: (items) => List<Reserva>.from(items),
      orElse: () => <Reserva>[],
    );
  }

  /// Restaura la lista desde un estado previo.
  void setFromSnapshot(List<Reserva> snapshot) {
    state = AsyncData(List<Reserva>.from(snapshot));
  }

  /// Inserta una reserva en la lista local antes de que el servidor confirme.
  void insertOptimistic(Reserva reserva) {
    final current = _currentList();
    current.insert(0, reserva);
    current.sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio));
    state = AsyncData(current);
  }

  /// Reemplaza una reserva temporal (ID optimista) por la confirmada por la API.
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

  /// Cambia el estado visual de una reserva a cancelada inmediatamente.
  void markCancelledOptimistic(String reservaId) {
    final current = _currentList();

    state = AsyncData(
      current
          .map((r) => r.id == reservaId ? _copyReservaWithEstado(r, EstadoReserva.cancelada) : r)
          .toList(),
    );
  }
}

/// Proveedor que combina reservas de espacios y servicios para el Home.
/// Proporciona una lista única ordenada cronológicamente.
final activityHistoryProvider = Provider.autoDispose<AsyncValue<List<Reserva>>>((ref) {
  final reservasAsync = ref.watch(misReservasProvider);
  final serviciosAsync = ref.watch(misReservasServiciosProvider);

  // Manejo de carga: Si alguna carga, intentamos mostrar datos parciales.
  if (reservasAsync.isLoading || serviciosAsync.isLoading) {
    final reservasData = reservasAsync.asData?.value;
    final serviciosData = serviciosAsync.asData?.value;
    if (reservasData != null || serviciosData != null) {
      return AsyncData(_mergeAndSort(reservasData ?? const [], serviciosData ?? const []));
    }
    return const AsyncLoading();
  }

  final reservasData = reservasAsync.asData?.value ?? const <Reserva>[];
  final serviciosData = serviciosAsync.asData?.value ?? const <Reserva>[];

  // Si una de las dos fuentes falla, seguimos mostrando la otra en Home.
  if (reservasAsync.hasError && serviciosAsync.hasError) {
    return AsyncError(
      reservasAsync.error ?? serviciosAsync.error!,
      reservasAsync.stackTrace ?? serviciosAsync.stackTrace ?? StackTrace.current,
    );
  }

  return AsyncData(_mergeAndSort(reservasData, serviciosData));
});

/// Une dos listas de reservas y las ordena descendientemente por fecha de inicio.
List<Reserva> _mergeAndSort(List<Reserva> a, List<Reserva> b) {
  final all = [...a, ...b];
  all.sort((x, y) => y.fechaInicio.compareTo(x.fechaInicio));
  return all;
}

/// Proveedor para la acción puntual de crear una nueva reserva.
final crearReservaProvider =
AsyncNotifierProvider<CrearReservaNotifier, Reserva?>(
  CrearReservaNotifier.new,
);

/// Controlador para el flujo de creación y cancelación de reservas.
class CrearReservaNotifier extends AsyncNotifier<Reserva?> {
  @override
  Future<Reserva?> build() async => null;

  /// Ejecuta el proceso de reserva con lógica optimista y rollback automático.
  Future<bool> crearReserva(
      String espacioId,
      DateTime fecha,
      String tramoId,
      String? observaciones,
      ) async {
    final user = ref.read(authProvider).user;
    // Guardamos estado actual para posible rollback.
    final previousReservas = ref.read(misReservasProvider).maybeWhen(
      data: (items) => List<Reserva>.from(items),
      orElse: () => <Reserva>[],
    );

    // Creación de objeto optimista (temporal).
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

    // Actualizamos UI local inmediatamente.
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

      // Sincronizamos ID real del servidor.
      final reserva = Reserva.fromJson(response as Map<String, dynamic>);
      ref.read(misReservasProvider.notifier).replaceOptimistic(tempId, reserva);

      unawaited(ref.read(authProvider.notifier).refreshCurrentUser());

      state = AsyncData(reserva);
      return true;
    } catch (error, stackTrace) {
      // Rollback en caso de error de red o validación.
      ref.read(misReservasProvider.notifier).setFromSnapshot(previousReservas);
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  /// Cancela una reserva existente con UI optimista.
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

/// Helper para generar una copia inmutable de la reserva con un estado diferente.
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

/// Traduce errores técnicos a mensajes comprensibles para el usuario final.
String _toFriendlyMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'No se pudo completar la operación. Inténtalo de nuevo.';
}

