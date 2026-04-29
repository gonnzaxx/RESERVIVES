import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/encuesta.dart';
import 'package:reservives/services/api_client.dart';

final todasEncuestasProvider =
AsyncNotifierProvider.autoDispose<TodasEncuestasNotifier, List<Encuesta>>(
      () => TodasEncuestasNotifier(),
);

final adminEncuestasProvider =
AsyncNotifierProvider.autoDispose<AdminEncuestasNotifier, List<Encuesta>>(
      () => AdminEncuestasNotifier(),
);

class AdminEncuestasNotifier extends AsyncNotifier<List<Encuesta>> {
  @override
  Future<List<Encuesta>> build() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/encuestas/admin/list');
    return (response as List)
        .map((e) => Encuesta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => build());
  }

  Future<bool> crearEncuesta({
    required String titulo,
    String? descripcion,
    required List<String> opciones,
    DateTime? fechaFin,
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/encuestas/', body: {
        'titulo': titulo,
        'descripcion': descripcion,
        'opciones': opciones.asMap().entries.map((e) => {'texto': e.value, 'orden': e.key}).toList(),
        'fecha_fin': (fechaFin ?? DateTime.now().add(const Duration(days: 7))).toUtc().toIso8601String(),
        'activa': true,
      });
      await refresh();
      // También invalidamos el de usuarios finales
      ref.invalidate(todasEncuestasProvider);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> eliminarEncuesta(String id) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete('/encuestas/$id');
      await refresh();
      ref.invalidate(todasEncuestasProvider);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> actualizarEncuesta({
    required String id,
    String? titulo,
    String? descripcion,
    DateTime? fechaFin,
    bool? activa,
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.patch('/encuestas/$id', body: {
        if (titulo != null) 'titulo': titulo,
        if (descripcion != null) 'descripcion': descripcion,
        if (fechaFin != null) 'fecha_fin': fechaFin.toUtc().toIso8601String(),
        if (activa != null) 'activa': activa,
      });
      await refresh();
      ref.invalidate(todasEncuestasProvider);
      return true;
    } catch (e) {
      return false;
    }
  }
}

class TodasEncuestasNotifier extends AsyncNotifier<List<Encuesta>> {
  @override
  Future<List<Encuesta>> build() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/encuestas/');
    return (response as List)
        .map((e) => Encuesta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => build());
  }

  Future<bool> votar(String encuestaId, String opcionId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/encuestas/$encuestaId/votar', body: {
        'opcion_id': opcionId,
      });

      // Refrescar para ver resultados actualizados
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> crearEncuesta({
    required String titulo,
    String? descripcion,
    required List<String> opciones,
    DateTime? fechaFin,
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/encuestas/', body: {
        'titulo': titulo,
        'descripcion': descripcion,
        'opciones': opciones.asMap().entries.map((e) => {'texto': e.value, 'orden': e.key}).toList(),
        'fecha_fin': (fechaFin ?? DateTime.now().add(const Duration(days: 7))).toUtc().toIso8601String(),
        'activa': true,
      });
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> eliminarEncuesta(String id) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.delete('/encuestas/$id');
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> actualizarEncuesta({
    required String id,
    String? titulo,
    String? descripcion,
    DateTime? fechaFin,
    bool? activa,
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.patch('/encuestas/$id', body: {
        if (titulo != null) 'titulo': titulo,
        if (descripcion != null) 'descripcion': descripcion,
        if (fechaFin != null) 'fecha_fin': fechaFin.toUtc().toIso8601String(),
        if (activa != null) 'activa': activa,
      });
      await refresh();
      return true;
    } catch (e) {
      return false;
    }
  }
}
