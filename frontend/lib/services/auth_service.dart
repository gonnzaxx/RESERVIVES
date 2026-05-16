/// Servicio de Autenticación.
///
/// Actúa como orquestador entre el [authProvider] y el [apiClientProvider],
/// centralizando el login con Microsoft y la limpieza de estado al cerrar sesión.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reservives/providers/announcements_provider.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/providers/bookings_provider.dart';
import 'package:reservives/providers/cafeteria_provider.dart';
import 'package:reservives/providers/chat_provider.dart';
import 'package:reservives/providers/favourites_provider.dart';
import 'package:reservives/providers/notifications_provider.dart';
import 'package:reservives/providers/polls_provider.dart';
import 'package:reservives/providers/service_provider.dart';
import 'package:reservives/providers/spaces_provider.dart';
import 'package:reservives/providers/time_slots_provider.dart';

/// Provider global para [AuthService].
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

/// Clase encargada de manejar acciones de autenticación y sincronización de datos de usuario.
class AuthService {
  final Ref _ref;

  AuthService(this._ref);

  /// Inicia el flujo de autenticación con Microsoft Azure AD.
  Future<String?> loginWithMicrosoft() async {
    try {
      await _ref.read(authProvider.notifier).login();
      final error = _ref.read(authProvider).error;
      return error;
    } catch (e) {
      return 'Error de autenticación: $e';
    }
  }

  /// Cierra la sesión actual y limpia todos los datos en caché de la aplicación.
  Future<void> logoutMicrosoft() async {
    await _ref.read(authProvider.notifier).logout();

    _ref.invalidate(anunciosProvider);
    _ref.invalidate(unreadNotificationsCountProvider);
    _ref.invalidate(menuCafeteriaProvider);
    _ref.invalidate(productosDestacadosProvider);
    _ref.invalidate(todasEncuestasProvider);
    _ref.invalidate(adminEncuestasProvider);
    _ref.invalidate(espaciosProvider);
    _ref.invalidate(serviciosInstitutoProvider);
    _ref.invalidate(favoritosProvider);
    _ref.invalidate(misReservasProvider);
    _ref.invalidate(misReservasServiciosProvider);
    _ref.invalidate(tramosProvider);
    _ref.invalidate(aiChatProvider);
  }
}
