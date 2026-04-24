import 'dart:convert';
import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/models/usuario.dart';
import 'package:reservives/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado de la autenticación
class AuthState {
  final Usuario? user;
  final String? token;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => token != null;

  AuthState copyWith({
    Usuario? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Configuración de Azure Entra ID
String get _clientId => AppConstants.azureClientId;
String get _tenantId => AppConstants.azureTenantId;
String get _redirectUri => kIsWeb
    ? AppConstants.azureRedirectUriWeb
    : AppConstants.azureRedirectUriNative;
String get _customUriScheme => kIsWeb
    ? ''
    : AppConstants.azureCustomScheme;

List<String> get _scopes => [
  'openid',
  'profile',
  'email',
  'User.Read',
  'offline_access',
];

class AuthProvider extends Notifier<AuthState> {
  @override
  AuthState build() {
    return AuthState();
  }

  String? get token => state.token;

  OAuth2Client _createClient() {
    return OAuth2Client(
      authorizeUrl: 'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/authorize',
      tokenUrl: 'https://login.microsoftonline.com/$_tenantId/oauth2/v2.0/token',
      redirectUri: _redirectUri,
      customUriScheme: _customUriScheme,
    );
  }

  /// Inicia el flujo completo de login
  Future<void> login() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final client = _createClient();

      final tokenResponse = await client.getTokenWithAuthCodeFlow(
        clientId: _clientId,
        scopes: _scopes,
      );

      final microsoftToken = tokenResponse.accessToken;
      if (microsoftToken == null) {
        state = state.copyWith(isLoading: false, error: 'No se obtuvo token de Microsoft');
        return;
      }

      state = state.copyWith(token: null);

      final apiClient = ref.read(apiClientProvider);
      final loginResponse = await apiClient.post('/auth/login', body: {
        'microsoft_token': microsoftToken,
      });

      final backendToken = loginResponse['access_token'] as String;
      final userData = Usuario.fromJson(loginResponse['user'] as Map<String, dynamic>);

      state = state.copyWith(
        token: backendToken,
        user: userData,
        isLoading: false,
      );

      if (kDebugMode) print('Login correctly synchronized with Backend');
    } catch (e) {
      if (kDebugMode) print('Login failed: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresca los datos del usuario actual desde la API (/auth/me)
  Future<void> refreshCurrentUser() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/auth/me');
      final user = Usuario.fromJson(response as Map<String, dynamic>);
      state = state.copyWith(user: user);
    } catch (e) {
      if (kDebugMode) print('Failed to refresh user: $e');
    }
  }

  Future<void> loginWithMicrosoft(String token) async {
    state = state.copyWith(token: token);
    await refreshCurrentUser();
  }

  Future<void> updateUserData(Usuario user) async {
    state = state.copyWith(user: user);
  }

  Future<void> loginDevBypass() async {
    state = state.copyWith(isLoading: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      final loginResponse = await apiClient.post('/auth/login-dev', body: {
        'email': 'dev@alumno.iesluisvives.org',
      });

      final backendToken = loginResponse['access_token'] as String;
      final userData = Usuario.fromJson(loginResponse['user'] as Map<String, dynamic>);

      state = state.copyWith(
        token: backendToken,
        user: userData,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString('language_code');
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding');

      await prefs.clear();

      if (savedLanguageCode != null) {
        await prefs.setString('language_code', savedLanguageCode);
      }
      if (hasSeenOnboarding != null) {
        await prefs.setBool('has_seen_onboarding', hasSeenOnboarding);
      }
    } catch (_) {}

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    state = AuthState();
  }
}

final authProvider = NotifierProvider<AuthProvider, AuthState>(() {
  return AuthProvider();
});
