import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/espacio.dart';
import 'package:reservives/services/api_client.dart';

/// Provider para el texto de búsqueda en instalaciones
final espaciosSearchQueryProvider = NotifierProvider.autoDispose<_EspaciosSearchQuery, String>(
  _EspaciosSearchQuery.new,
);

class _EspaciosSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;
}

/// Provider para el filtro de tipo de espacio seleccionado
final espaciosFilterTipoProvider = NotifierProvider.autoDispose<_FilterTipo, TipoEspacio?>(
  _FilterTipo.new,
);

class _FilterTipo extends Notifier<TipoEspacio?> {
  @override
  TipoEspacio? build() => null;

  void setTipo(TipoEspacio? value) => state = value;
}

/// Provider que carga la lista de espacios y aplica los filtros de búsqueda.
final espaciosProvider = FutureProvider.autoDispose<List<Espacio>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final tipo = ref.watch(espaciosFilterTipoProvider);
  final search = ref.watch(espaciosSearchQueryProvider).toLowerCase();

  Map<String, String>? queryParams;
  if (tipo != null) {
    queryParams = {'tipo': tipo.value};
  }

  final response = await apiClient.get('/espacios', queryParams: queryParams);

  var spaces = (response as List).map((e) => Espacio.fromJson(e)).toList();

  if (search.isNotEmpty) {
    spaces = spaces
        .where((e) =>
    e.nombre.toLowerCase().contains(search) ||
        (e.descripcion?.toLowerCase().contains(search) ?? false))
        .toList();
  }

  return spaces;
});

/// Provider para cargar los detalles de un espacio especifico.
final espacioDetalleProvider =
FutureProvider.family.autoDispose<Espacio, String>((ref, id) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/espacios/$id');
  return Espacio.fromJson(response);
});
