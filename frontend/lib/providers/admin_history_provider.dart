/// IES Luis Vives App - Gestión de Estado del Historial de Administración.
///
/// Proporciona la lógica para filtrar y recuperar el historial global de reservas
/// del centro. Utiliza Riverpod para la reactividad, permitiendo que la lista
/// se actualice automáticamente cuando cambian los filtros.

library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/admin_history_item.dart';
import 'package:reservives/services/api_client.dart';

/// Notifier encargado de gestionar el estado de los filtros aplicados al historial.
class AdminHistoryFiltersNotifier extends Notifier<AdminHistoryFilters> {
  @override
  AdminHistoryFilters build() => const AdminHistoryFilters();

  /// Actualiza los filtros actuales y dispara la invalidación de proveedores dependientes.
  void setFilters(AdminHistoryFilters next) {
    state = next;
  }

  /// Restablece todos los filtros a su estado inicial (vacío).
  void clear() {
    state = const AdminHistoryFilters();
  }
}

/// Proveedor global para el estado de los filtros.
final adminHistoryFiltersProvider =
NotifierProvider<AdminHistoryFiltersNotifier, AdminHistoryFilters>(
  AdminHistoryFiltersNotifier.new,
);

/// Proveedor de datos que recupera el historial de la API basándose en los filtros.
///
/// Se marca como [autoDispose] para liberar memoria cuando la pantalla de historial
/// no esté en uso. Observa [adminHistoryFiltersProvider] para re-ejecutar la
/// petición cada vez que un filtro cambie.
final adminHistoryProvider =
FutureProvider.autoDispose<List<AdminHistoryItem>>((ref) async {
  final api = ref.read(apiClientProvider);
  final filters = ref.watch(adminHistoryFiltersProvider);

  // Construcción dinámica de los parámetros de consulta (Query Params)
  final query = <String, String>{};

  if (filters.day != null) {
    final d = filters.day!;
    query['day'] =
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  if (filters.month != null) query['month'] = filters.month.toString();
  if (filters.year != null) query['year'] = filters.year.toString();
  if (filters.tipo != null && filters.tipo!.isNotEmpty) {
    query['tipo_reserva'] = filters.tipo!;
  }

  if (filters.estado != null && filters.estado!.isNotEmpty) {
    query['estado'] = filters.estado!;
  }

  if (filters.usuarioQ != null && filters.usuarioQ!.trim().isNotEmpty) {
    query['usuario_q'] = filters.usuarioQ!.trim();
  }

  // Petición al endpoint administrativo de reservas
  final response = await api.get('/admin/bookings', queryParams: query);

  return (response as List)
      .map((e) => AdminHistoryItem.fromJson(e as Map<String, dynamic>))
      .toList();
});