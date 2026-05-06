/// Providers de Lista de Espera.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/lista_espera.dart';
import 'package:reservives/services/api_client.dart';

/// Entradas activas del usuario en listas de espera.
final miListaEsperaProvider =
    FutureProvider.autoDispose<List<ListaEspera>>((ref) async {
  final api = ref.read(apiClientProvider);
  final response = await api.get('/lista-espera/');
  return (response as List)
      .map((e) => ListaEspera.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Número de personas en espera para un slot concreto.
typedef ListaEsperaCountArgs = ({
  String espacioId,
  String tramoId,
  DateTime fecha
});

final listaEsperaCountProvider =
    FutureProvider.autoDispose.family<int, ListaEsperaCountArgs>(
  (ref, args) async {
    final api = ref.read(apiClientProvider);
    final fechaStr =
        '${args.fecha.year}-${args.fecha.month.toString().padLeft(2, '0')}-${args.fecha.day.toString().padLeft(2, '0')}';
    final response = await api.get(
      '/lista-espera/espacio/${args.espacioId}/count?tramo_id=${args.tramoId}&fecha=$fechaStr',
    );
    return (response as Map<String, dynamic>)['count'] as int? ?? 0;
  },
);

/// Notifier para unirse / abandonar la lista de espera.
final listaEsperaActionProvider =
    AsyncNotifierProvider<ListaEsperaActionNotifier, ListaEspera?>(
  ListaEsperaActionNotifier.new,
);

class ListaEsperaActionNotifier extends AsyncNotifier<ListaEspera?> {
  @override
  Future<ListaEspera?> build() async => null;

  Future<bool> unirse({
    required String espacioId,
    required String tramoId,
    required DateTime fecha,
  }) async {
    state = const AsyncLoading();
    try {
      final api = ref.read(apiClientProvider);
      final fechaStr =
          '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
      final response = await api.post('/lista-espera/', body: {
        'espacio_id': espacioId,
        'tramo_id': tramoId,
        'fecha': fechaStr,
      });
      final entrada = ListaEspera.fromJson(response as Map<String, dynamic>);
      state = AsyncData(entrada);
      ref.invalidate(miListaEsperaProvider);
      ref.invalidate(listaEsperaCountProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> abandonar(String entradaId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/lista-espera/$entradaId');
      ref.invalidate(miListaEsperaProvider);
      ref.invalidate(listaEsperaCountProvider);
      return true;
    } catch (_) {
      return false;
    }
  }
}
