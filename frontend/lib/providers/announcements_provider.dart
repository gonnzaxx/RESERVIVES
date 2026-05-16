/// Gestión de Comunicación Institucional y Anuncios.
///
/// Administra el flujo de anuncios informativos que se muestran a los usuarios
/// e incluye el registro de métricas de visualización para seguimiento estadístico.

library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/anuncio.dart';
import 'package:reservives/services/api_client.dart';

/// Proveedor de la lista de anuncios activos.
///
/// Utiliza [AsyncNotifierProvider] para manejar los estados de carga, error
/// y datos de forma nativa. Se marca como [autoDispose] para limpiar los
/// recursos cuando el usuario no está visualizando la sección de noticias.
final anunciosProvider = AsyncNotifierProvider.autoDispose<AnunciosNotifier, List<Anuncio>>(
      () => AnunciosNotifier(),
);

/// Controlador encargado de la lógica de negocio de los anuncios.
class AnunciosNotifier extends AsyncNotifier<List<Anuncio>> {
  @override
  Future<List<Anuncio>> build() async {
    final apiClient = ref.read(apiClientProvider);

    // Recupera los anuncios desde el endpoint público.
    final response = await apiClient.get('/anuncios/');
    return (response as List).map((e) => Anuncio.fromJson(e)).toList();
  }

  /// Fuerza una recarga completa de los anuncios desde el servidor.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Notifica al servidor que un usuario ha interactuado con un anuncio.
  ///
  /// Esta operación se realiza de forma silenciosa para
  /// no interrumpir la experiencia del usuario si falla la red.
  Future<void> registrarVisualizacion(String anuncioId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/anuncios/$anuncioId/view');
    } catch (e) {
      // Silenciamos el error para no interrumpir la navegación del usuario.
    }
  }
}
