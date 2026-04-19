library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:reservives/models/usuario.dart';
import 'package:reservives/services/api_client.dart';
import 'package:reservives/services/push_notifications_service.dart';


class AuthState {
  final bool isLoading;
  final Usuario? user;
  final String? error;

  const AuthState({
    this.isLoading = true,
    this.user,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    bool? isLoading,
    Object? user = _authSentinel,
    Object? error = _authSentinel,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: identical(user, _authSentinel) ? this.user : user as Usuario?,
      error: identical(error, _authSentinel) ? this.error : error as String?,
    );
  }
}

const Object _authSentinel = Object();

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});

class AuthNotifier extends Notifier<AuthState> {

  SharedPreferences? _prefs;
  String? _token;

  String? get token => _token;

  @override
  AuthState build() {
    _init();
    return const AuthState();
  }

  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _token = _prefs?.getString('auth_token');
      final userDataStr = _prefs?.getString('user_data');

      if (_token != null && userDataStr != null) {
        final userData = jsonDecode(userDataStr) as Map<String, dynamic>;
        state = state.copyWith(
          isLoading: false,
          user: Usuario.fromJson(userData),
          error: null,
        );
        unawaited(ref.read(pushNotificationsServiceProvider).syncTokenWithBackend());
      } else {
        // Si durante la inicializacion ya hubo login manual (p.ej. bypass),
        // no sobrescribimos ese estado.
        if (state.user == null) {
          state = state.copyWith(
            isLoading: false,
            user: null,
            error: null,
          );
        } else {
          state = state.copyWith(isLoading: false, error: null);
        }
      }
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        user: null,
        error: 'Error cargando sesión local',
      );
    }
  }

  Future<void> loginWithMicrosoft(String microsoftToken) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/auth/login',
        body: {'microsoft_token': microsoftToken},
      );
      await _handleLoginSuccess(response as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        user: null,
        error: e is ApiException ? e.message : e.toString(),
      );
    }
  }

  Future<void> loginDevBypass({String? email}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post(
        '/auth/login-dev',
        body: email == null || email.isEmpty ? {} : {'email': email},
      );
      await _handleLoginSuccess(response as Map<String, dynamic>);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        user: null,
        error: e is ApiException ? e.message : e.toString(),
      );
    }
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> response) async {
    _token = response['access_token'] as String?;
    final userMap = response['user'] as Map<String, dynamic>;
    final user = Usuario.fromJson(userMap);

    await _prefs?.setString('auth_token', _token ?? '');
    await _prefs?.setString('user_data', jsonEncode(userMap));

    state = state.copyWith(
      isLoading: false,
      user: user,
      error: null,
    );
    unawaited(ref.read(pushNotificationsServiceProvider).syncTokenWithBackend());
  }

  Future<void> logout() async {
    _token = null;
    await _prefs?.remove('auth_token');
    await _prefs?.remove('user_data');

    state = state.copyWith(
      isLoading: false,
      user: null,
      error: null,
    );
  }

  Future<void> updateUserData(Usuario newUser) async {
    if (state.user != null && state.user!.id == newUser.id) {
      await _prefs?.setString('user_data', jsonEncode(newUser.toJson()));
      state = state.copyWith(user: newUser, error: null);
    }
  }

  Future<void> refreshCurrentUser() async {
    final currentUser = state.user;
    if (currentUser == null) return;

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/usuarios/${currentUser.id}');
      await updateUserData(Usuario.fromJson(response as Map<String, dynamic>));
    } catch (_) {
    }
  }
}
