/// IES Luis Vives App - Gestión de Elementos Favoritos.
///
/// Administra la persistencia y el estado reactivo de los espacios y servicios
/// marcados como favoritos por el usuario. Permite un acceso rápido desde la
/// biblioteca personal y sincroniza los cambios con el backend.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/espacio.dart';
import 'package:reservives/models/servicio.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/services/api_client.dart';

/// Estado inmutable que contiene los identificadores de los elementos favoritos.
class FavoritosState {
  final List<String> espaciosIds;
  final List<String> serviciosIds;
  final bool isLoading;

  FavoritosState({
    this.espaciosIds = const [],
    this.serviciosIds = const [],
    this.isLoading = false,
  });

  FavoritosState copyWith({
    List<String>? espaciosIds,
    List<String>? serviciosIds,
    bool? isLoading,
  }) {
    return FavoritosState(
      espaciosIds: espaciosIds ?? this.espaciosIds,
      serviciosIds: serviciosIds ?? this.serviciosIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Controlador para la lógica de marcadores (favoritos).
class FavoritosNotifier extends Notifier<FavoritosState> {

  @override
  FavoritosState build() {
    // En modo invitado no hay sesión; omitimos la carga para evitar errores 401.
    final isGuest = ref.read(authProvider).isGuest;
    if (!isGuest) {
      Future.microtask(() => cargarFavoritos());
    }
    return FavoritosState();
  }

  /// Recupera los listados de IDs favoritos desde la API.
  Future<void> cargarFavoritos() async {
    state = state.copyWith(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final espaciosResp = await apiClient.get('/favoritos/espacios');
      final serviciosResp = await apiClient.get('/favoritos/servicios');

      final espaciosIds = (espaciosResp as List).map((i) => i['espacio_id'] as String).toList();
      final serviciosIds = (serviciosResp as List).map((i) => i['servicio_id'] as String).toList();

      state = state.copyWith(
        espaciosIds: espaciosIds,
        serviciosIds: serviciosIds,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  bool isEspacioFavorito(String id) => state.espaciosIds.contains(id);
  bool isServicioFavorito(String id) => state.serviciosIds.contains(id);

  /// Alterna el estado de favorito de un espacio.
  Future<bool> toggleEspacioFavorito(String id) async {
    final isFav = isEspacioFavorito(id);
    final apiClient = ref.read(apiClientProvider);
    try {
      if (isFav) {
        await apiClient.delete('/favoritos/espacios/$id');
        state = state.copyWith(
          espaciosIds: state.espaciosIds.where((i) => i != id).toList(),
        );
        return false;
      } else {
        await apiClient.post('/favoritos/espacios/$id');
        state = state.copyWith(
          espaciosIds: [...state.espaciosIds, id],
        );
        return true;
      }
    } catch (e) {
      return isFav;
    }
  }

  /// Alterna el estado de favorito de un servicio.
  Future<bool> toggleServicioFavorito(String id) async {
    final isFav = isServicioFavorito(id);
    final apiClient = ref.read(apiClientProvider);
    try {
      if (isFav) {
        await apiClient.delete('/favoritos/servicios/$id');
        state = state.copyWith(
          serviciosIds: state.serviciosIds.where((i) => i != id).toList(),
        );
        return false;
      } else {
        await apiClient.post('/favoritos/servicios/$id');
        state = state.copyWith(
          serviciosIds: [...state.serviciosIds, id],
        );
        return true;
      }
    } catch (e) {
      return isFav;
    }
  }
}

/// Provider global para el estado de los IDs favoritos.
final favoritosProvider = NotifierProvider<FavoritosNotifier, FavoritosState>(() {
  return FavoritosNotifier();
});

/// Provider que resuelve los objetos [Espacio] completos basándose en los IDs favoritos.
final listaFavoritosEspaciosProvider = FutureProvider.autoDispose<List<Espacio>>((ref) async {
  final favState = ref.watch(favoritosProvider);
  if (favState.espaciosIds.isEmpty) return [];
  
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/espacios/');
  final todos = (response as List).map((e) => Espacio.fromJson(e)).toList();
  return todos.where((e) => favState.espaciosIds.contains(e.id)).toList();
});

/// Provider que resuelve los objetos [ServicioInstituto] completos basándose en los IDs favoritos.
final listaFavoritosServiciosProvider = FutureProvider.autoDispose<List<ServicioInstituto>>((ref) async {
  final favState = ref.watch(favoritosProvider);
  if (favState.serviciosIds.isEmpty) return [];
  
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/servicios/');
  final todos = (response as List).map((e) => ServicioInstituto.fromJson(e)).toList();
  
  return todos.where((e) => favState.serviciosIds.contains(e.id)).toList();
});
