import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/anuncio.dart';
import 'package:reservives/services/api_client.dart';

final anunciosProvider = AsyncNotifierProvider.autoDispose<AnunciosNotifier, List<Anuncio>>(
      () => AnunciosNotifier(),
);

class AnunciosNotifier extends AsyncNotifier<List<Anuncio>> {
  @override
  Future<List<Anuncio>> build() async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get('/anuncios/');
    return (response as List).map((e) => Anuncio.fromJson(e)).toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => build());
  }

  /// Registra que un usuario ha visto un anuncio
  Future<void> registrarVisualizacion(String anuncioId) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/anuncios/$anuncioId/view');
    } catch (e) {
      print('Error al registrar métrica de anuncio: $e');
    }
  }
}
