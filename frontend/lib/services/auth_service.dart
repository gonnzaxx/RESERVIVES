/// RESERVIVES - Authentication Service
///
/// Usa flutter_appauth (AppAuth SDK) para autenticación OAuth2 nativa
/// con PKCE — funciona en Android e iOS sin depender de dart:html.

library;

import 'dart:typed_data';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reservives/models/usuario.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/services/api_client.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

class AuthService {
  final Ref _ref;
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  AuthService(this._ref);

  Future<String?> loginWithMicrosoft() async {
    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppConstants.azureClientId,
          AppConstants.azureRedirectUri,
          issuer:
          'https://login.microsoftonline.com/${AppConstants.azureTenantId}/v2.0',
          scopes: ['openid', 'profile', 'email', 'offline_access', 'User.Read'],
        ),
      );

      if (result == null || result.accessToken == null) {
        return 'No se pudo obtener el token de acceso de Microsoft.';
      }

      // Enviar el access token al backend para crear sesión en RESERVIVES
      await _ref.read(authProvider.notifier).loginWithMicrosoft(result.accessToken!);
      return null;
    } on FlutterAppAuthUserCancelledException {
      // El usuario cerró el navegador — no es un error
      return null;
    } on FlutterAppAuthPlatformException catch (e) {
      return 'Error de autenticación: ${e.message}';
    } catch (e) {
      return 'Error de conexión con Microsoft EntraID: $e';
    }
  }

  Future<void> logoutMicrosoft() async {
    await _ref.read(authProvider.notifier).logout();
  }

  /// Sube el avatar al backend y actualiza el usuario local
  Future<bool> uploadAvatar(Uint8List bytes, String fileName) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.postMultipart(
        '/usuarios/me/avatar',
        fileField: 'file',
        fileBytes: bytes,
        fileName: fileName,
      );

      final updatedUser = Usuario.fromJson(response);
      await _ref.read(authProvider.notifier).updateUserData(updatedUser);
      return true;
    } catch (e) {
      return false;
    }
  }
}
