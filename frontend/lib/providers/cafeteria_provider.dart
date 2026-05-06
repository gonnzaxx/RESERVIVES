/// Proveedores del Servicio de Cafetería.
///
/// Gestiona el acceso al catálogo de productos, categorías y destacados de
/// la cafetería del centro.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/cafeteria.dart';
import 'package:reservives/services/api_client.dart';

/// Provider encargado de obtener la estructura completa del menú.
///
/// Recupera una lista de [CategoriaCafeteria], donde cada categoría contiene
/// su propia lista de productos anidados. Se utiliza [autoDispose] para
/// liberar la memoria cuando el usuario navega fuera de la sección de cafetería
final menuCafeteriaProvider = FutureProvider.autoDispose<List<CategoriaCafeteria>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/cafeteria/categorias');
  return (response as List).map((e) => CategoriaCafeteria.fromJson(e)).toList();
});

/// Provider que carga los productos destacados.
final productosDestacadosProvider = FutureProvider.autoDispose<List<ProductoCafeteria>>((ref) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/cafeteria/productos/destacados');
  return (response as List).map((e) => ProductoCafeteria.fromJson(e)).toList();
});
