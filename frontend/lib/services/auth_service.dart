/// RESERVIVES - Authentication Service

library;

import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:reservives/models/usuario.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'package:reservives/services/api_client.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

class AuthService {
  final Ref _ref;
  AuthService(this._ref);

  Future<String?> loginWithMicrosoft() async {
    try {
      final authUrl = Uri.parse(
        'https://login.microsoftonline.com/${AppConstants.azureTenantId}/oauth2/v2.0/authorize'
            '?client_id=${AppConstants.azureClientId}'
            '&response_type=id_token token'
            '&scope=${Uri.encodeComponent('openid profile email User.Read')}'
            '&response_mode=fragment'
            '&nonce=123456',
      );

      // Abrir URL de login de Microsoft
      if (await canLaunchUrl(authUrl)) {
        await launchUrl(
          authUrl,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
      } else {
        return 'No se pudo abrir el navegador para iniciar sesión';
      }
      return null;
    } catch (e) {
      if (e is ApiException) {
        return e.message;
      }
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
