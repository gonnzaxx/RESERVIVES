/// Gestión de Tramos Horarios (Backoffice).
///
/// Este archivo administra los intervalos de tiempo permitidos para las reservas
/// en el centro (ej: "09:00 - 10:00"). Permite definir la disponibilidad base
/// que luego será utilizada por los usuarios al agendar espacios o servicios.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/models/tramo_horario.dart';
import 'package:reservives/services/api_client.dart';

/// Estado inmutable para la gestión de tramos horarios en el panel administrativo.
class AdminTramosState {
  final bool isLoading;
  final List<TramoHorario> tramos;
  final String? error;

  const AdminTramosState({
    required this.isLoading,
    required this.tramos,
    this.error,
  });

  AdminTramosState copyWith({
    bool? isLoading,
    List<TramoHorario>? tramos,
    String? error,
  }) =>
      AdminTramosState(
        isLoading: isLoading ?? this.isLoading,
        tramos: tramos ?? this.tramos,
        error: error,
      );
}

/// Notifier encargado de realizar las operaciones CRUD sobre los tramos horarios.
class AdminTramosNotifier extends Notifier<AdminTramosState> {
  @override
  AdminTramosState build() {
    Future.microtask(loadTramos);
    return const AdminTramosState(isLoading: true, tramos: []);
  }

  /// Recupera la lista completa de tramos configurados en el sistema.
  Future<void> loadTramos() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get('/admin/configuracion/tramos');
      final list = (res as List)
          .map((e) => TramoHorario.fromJson(e as Map<String, dynamic>))
          .toList();
      state = state.copyWith(isLoading: false, tramos: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Registra un nuevo tramo horario en la base de datos.
  Future<bool> crearTramo(Map<String, dynamic> body) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/admin/configuracion/tramos', body: body);
      await loadTramos();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Actualiza parcialmente la información de un tramo existente.
  Future<bool> editarTramo(String id, Map<String, dynamic> body) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/admin/configuracion/tramos/$id', body: body);
      await loadTramos();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Cambia el estado de un tramo a 'inactivo', impidiendo nuevas reservas.
  Future<bool> desactivarTramo(String id) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/admin/configuracion/tramos/$id', body: {'activo': false});
      await loadTramos();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Elimina un tramo horario del sistema.
  Future<bool> eliminarTramo(String id) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.delete('/admin/configuracion/tramos/$id');
      await loadTramos();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}

final adminTramosProvider =
NotifierProvider.autoDispose<AdminTramosNotifier, AdminTramosState>(
  AdminTramosNotifier.new,
);