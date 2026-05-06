/// Gestión de Encuestas y Participación.
///
/// Administra el ciclo de vida de las encuestas del centro, permitiendo tanto
/// la participación de los usuarios (votos) como la administración (creación,
/// edición y borrado).

library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/encuesta.dart';
import 'package:reservives/services/api_client.dart';

/// Provider para la vista pública de encuestas activas para el usuario.
final todasEncuestasProvider =
AsyncNotifierProvider.autoDispose<TodasEncuestasNotifier, List<Encuesta>>(
      () => TodasEncuestasNotifier(),
);

/// Provider para la vista de gestión administrativa de encuestas.
final adminEncuestasProvider =
AsyncNotifierProvider.autoDispose<AdminEncuestasNotifier, List<Encuesta>>(
      () => AdminEncuestasNotifier(),
);

/// Controlador para operaciones administrativas sobre las encuestas.
class AdminEncuestasNotifier extends AsyncNotifier<List<Encuesta>> {
  @override
  Future<List<Encuesta>> build() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/encuestas/admin/list');
    return (response as List)
        .map((e) => Encuesta.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Refresca la lista de encuestas del administrador.
  Future<void> refresh() async {
    state = await AsyncValue.guard(() => build());
  }

  /// Crea una nueva encuesta y sincroniza los listados globales.
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

      // Invalidamos el provider de usuarios para que vean la nueva encuesta.
      ref.invalidate(todasEncuestasProvider);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Elimina una encuesta de forma permanente.
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

  /// Actualiza parámetros específicos de una encuesta existente.
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

/// Controlador para la interacción del usuario con las encuestas.
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

  /// Refresca la lista para obtener resultados de votaciones actualizados.
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

  /// Replica las capacidades de creación/edición para acceso rápido desde la vista general.
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
