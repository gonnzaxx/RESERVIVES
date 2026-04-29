import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/incidencia.dart';
import 'package:reservives/services/api_client.dart';

final misIncidenciasProvider =
AsyncNotifierProvider.autoDispose<MisIncidenciasNotifier, List<Incidencia>>(
      () => MisIncidenciasNotifier(),
);

class MisIncidenciasNotifier extends AsyncNotifier<List<Incidencia>> {
  @override
  Future<List<Incidencia>> build() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/incidencias/mis-incidencias');
    return (response as List)
        .map((e) => Incidencia.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  void addIncident(Incidencia incident) {
    state.whenData((list) {
      state = AsyncData([incident, ...list]);
    });
  }
}

final reportarIncidenciaProvider =
AsyncNotifierProvider<ReportarIncidenciaNotifier, void>(
      () => ReportarIncidenciaNotifier(),
);

class ReportarIncidenciaNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<bool> reportar(String descripcion, {String? imagenUrl}) async {
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
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

// Admin Providers
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
