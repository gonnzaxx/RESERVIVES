import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/espacio.dart';
import 'package:reservives/models/servicio.dart';
import 'package:reservives/services/api_client.dart';

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

class FavoritosNotifier extends Notifier<FavoritosState> {

  @override
  FavoritosState build() {
    Future.microtask(() => cargarFavoritos());
    return FavoritosState();
  }

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

final favoritosProvider = NotifierProvider<FavoritosNotifier, FavoritosState>(() {
  return FavoritosNotifier();
});

final listaFavoritosEspaciosProvider = FutureProvider.autoDispose<List<Espacio>>((ref) async {
  final favState = ref.watch(favoritosProvider);
  if (favState.espaciosIds.isEmpty) return [];
  
  final apiClient = ref.read(apiClientProvider);
  final List<Espacio> favoritos = [];

  final response = await apiClient.get('/espacios');
  final todos = (response as List).map((e) => Espacio.fromJson(e)).toList();
  
  return todos.where((e) => favState.espaciosIds.contains(e.id)).toList();
});

final listaFavoritosServiciosProvider = FutureProvider.autoDispose<List<ServicioInstituto>>((ref) async {
  final favState = ref.watch(favoritosProvider);
  if (favState.serviciosIds.isEmpty) return [];
  
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/servicios');
  final todos = (response as List).map((e) => ServicioInstituto.fromJson(e)).toList();
  
  return todos.where((e) => favState.serviciosIds.contains(e.id)).toList();
});
