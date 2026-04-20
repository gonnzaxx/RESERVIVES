/// RESERVIVES - Authentication Service

library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:oauth2_client/oauth2_helper.dart';

import 'package:reservives/config/constants.dart';
import 'package:reservives/models/usuario.dart';
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
      await _ref.read(authProvider.notifier).login();
      final error = _ref.read(authProvider).error;
      return error;
    } catch (e) {
      return 'Error de autenticación: $e';
    }
  }

  Future<void> logoutMicrosoft() async {
    await _ref.read(authProvider.notifier).logout();
  }

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
    } catch (_) {
      return false;
    }
  }
}