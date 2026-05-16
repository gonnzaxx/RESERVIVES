/// Providers de Lista de Espera.
///
/// Gestiona la inscripción del usuario en listas de espera para slots
/// ya ocupados, consulta el número de personas en cola y permite abandonar la posición.
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

/// Argumentos necesarios para consultar el contador de un slot concreto.
typedef ListaEsperaCountArgs = ({
  String espacioId,
  String tramoId,
  DateTime fecha
});

/// Número de personas en espera para un espacio, tramo y fecha determinados.
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

/// Controlador para las acciones de unirse y abandonar la lista de espera.
final listaEsperaActionProvider =
    AsyncNotifierProvider<ListaEsperaActionNotifier, ListaEspera?>(
  ListaEsperaActionNotifier.new,
);

class ListaEsperaActionNotifier extends AsyncNotifier<ListaEspera?> {
  @override
  Future<ListaEspera?> build() async => null;

  /// Añade al usuario a la lista de espera del [espacioId] para el [tramoId] y [fecha] indicados.
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

  /// Elimina al usuario de la lista de espera identificada por [entradaId].
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
