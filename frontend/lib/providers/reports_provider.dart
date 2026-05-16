/// Gestión de Incidencias y Reportes.
///
/// Administra el ciclo de vida de los reportes de mantenimiento o problemas
/// en el centro. Permite a los usuarios reportar averías y consultar su estado,
/// y a los administradores gestionar y resolver dichas incidencias.

library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/incidencia.dart';
import 'package:reservives/services/api_client.dart';

final incidenciaByIdProvider = FutureProvider.autoDispose.family<Incidencia, String>((ref, id) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/incidencias/mis-incidencias');
  final list = (response as List).map((e) => Incidencia.fromJson(e as Map<String, dynamic>)).toList();
  return list.firstWhere((i) => i.id == id);
});

final misIncidenciasProvider =
AsyncNotifierProvider.autoDispose<MisIncidenciasNotifier, List<Incidencia>>(
      () => MisIncidenciasNotifier(),
);

/// Provider para el listado histórico de incidencias del usuario actual.
class MisIncidenciasNotifier extends AsyncNotifier<List<Incidencia>> {
  @override
  Future<List<Incidencia>> build() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/incidencias/mis-incidencias');
    return (response as List)
        .map((e) => Incidencia.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Refresca la lista de incidencias personales.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  /// Añade una nueva incidencia localmente para evitar esperas de red.
  void addIncident(Incidencia incident) {
    state.whenData((list) {
      state = AsyncData([incident, ...list]);
    });
  }
}

/// Provider encargado del proceso de envío de nuevos reportes.
final reportarIncidenciaProvider =
AsyncNotifierProvider<ReportarIncidenciaNotifier, void>(
      () => ReportarIncidenciaNotifier(),
);

/// Envía un reporte de incidencia al servidor.
///
/// Tras el éxito, actualiza automáticamente el listado de [misIncidenciasProvider].
class ReportarIncidenciaNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Incidencia?> reportar(String descripcion, {String? imagenUrl}) async {
    state = const AsyncLoading();
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post('/incidencias/', body: {
        'descripcion': descripcion,
        'imagen_url': imagenUrl,
      });

      final nueva = Incidencia.fromJson(response as Map<String, dynamic>);
      ref.read(misIncidenciasProvider.notifier).addIncident(nueva);
      state = const AsyncData(null);
      return nueva;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

/// Provider para que el personal de mantenimiento gestione todas las incidencias.
final todasIncidenciasProvider =
AsyncNotifierProvider.autoDispose<TodasIncidenciasNotifier, List<Incidencia>>(
      () => TodasIncidenciasNotifier(),
);

class TodasIncidenciasNotifier extends AsyncNotifier<List<Incidencia>> {
  @override
  Future<List<Incidencia>> build() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/incidencias/admin');
    return (response as List)
        .map((e) => Incidencia.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cambia el estado de una incidencia a 'RESUELTA' e incluye un comentario.
  ///
  /// Realiza una actualización optimista del estado local para reflejar el cambio
  /// inmediatamente en el panel administrativo.
  Future<bool> resolver(String id, String? comentario) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.patch('/incidencias/admin/$id/estado', body: {
        'estado': 'RESUELTA',
        if (comentario != null) 'comentario_admin': comentario,
      });

      state.whenData((list) {
        state = AsyncValue.data(
            list.map((inc) => inc.id == id
                ? inc.copyWith(estado: EstadoIncidencia.resuelta, comentarioAdmin: comentario)
                : inc).toList()
        );
      });
      return true;
    } catch (e) {
      return false;
    }
  }
}
