/// Proveedores de Espacios.
///
/// Gestiona el catálogo de instalaciones del centro, los filtros de búsqueda
/// y la carga de detalles individuales.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/espacio.dart';
import 'package:reservives/services/api_client.dart';

/// Almacena el texto de búsqueda introducido por el usuario en la sección de instalaciones.
final espaciosSearchQueryProvider = NotifierProvider.autoDispose<_EspaciosSearchQuery, String>(
  _EspaciosSearchQuery.new,
);

class _EspaciosSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  // Actualiza la cadena de búsqueda.
  void setQuery(String value) => state = value;
}

/// Guarda el tipo de espacio actualmente seleccionado como filtro (null = sin filtro).
final espaciosFilterTipoProvider = NotifierProvider.autoDispose<_FilterTipo, TipoEspacio?>(
  _FilterTipo.new,
);

class _FilterTipo extends Notifier<TipoEspacio?> {
  @override
  TipoEspacio? build() => null;

  // Cambia el filtro de tipo; pasa null para mostrar todos los espacios.
  void setTipo(TipoEspacio? value) => state = value;
}

/// Obtiene la lista de espacios del backend aplicando el filtro de tipo y la búsqueda por texto.
final espaciosProvider = FutureProvider.autoDispose<List<Espacio>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final tipo = ref.watch(espaciosFilterTipoProvider);
  final search = ref.watch(espaciosSearchQueryProvider).toLowerCase();

  Map<String, String>? queryParams;
  if (tipo != null) {
    queryParams = {'tipo': tipo.value};
  }

  final response = await apiClient.get('/espacios/', queryParams: queryParams);

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

/// Carga el detalle de un espacio concreto por su [id].
final espacioDetalleProvider =
FutureProvider.family.autoDispose<Espacio, String>((ref, id) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/espacios/$id');
  return Espacio.fromJson(response);
});
