/// Núcleo de Identidad y Ciclo de Vida de Sesión.
///
/// Gestiona el flujo de autenticación mediante Microsoft Entra ID (Azure),
/// el modo invitado y la sincronización de tokens con el backend. Implementa
/// persistencia local con validación de caducidad y estados reactivos.

library;


import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/models/usuario.dart';
import 'package:reservives/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Representación inmutable del estado de identidad del usuario.
class AuthState {
  final Usuario? user;
  final String? token;
  final bool isGuest;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.token,
    this.isGuest = false,
    this.isLoading = false,
    this.error,
  });

  /// Determina si existe una sesión activa, ya sea identificada o anónima.
  bool get isAuthenticated => token != null || isGuest;

  AuthState copyWith({
    Usuario? user,
    String? token,
    bool? isGuest,
    bool? isLoading,
    String? error,
    bool clearToken = false,
    bool clearUser = false,
    bool clearGuest = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearToken ? null : (token ?? this.token),
      isGuest: clearGuest ? false : (isGuest ?? this.isGuest),
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

/// Provider central para gestionar la autenticación y el ciclo de vida de la sesión.
///
/// Utiliza `Notifier` para exponer el estado inmutable [AuthState] y reaccionar
/// a los cambios. Implementa el flujo de OAuth2 con Microsoft Entra ID y mantiene
/// sincronizada la sesión del frontend con el backend, además de la persistencia local.
class AuthProvider extends Notifier<AuthState> {
  static const _tokenKey = 'auth_token';
  static const _guestKey = 'auth_guest_mode';
  static const _loginTimestampKey = 'auth_login_ts';
  static const _sessionDurationMinutes = 60;
  bool _sessionRestored = false;

  @override
  AuthState build() {
    if (!_sessionRestored) {
      _sessionRestored = true;
      Future.microtask(_restorePersistedSession);
      return AuthState(isLoading: true);
    }
    return state;
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

      state = state.copyWith(clearToken: true);

      final apiClient = ref.read(apiClientProvider);
      final loginResponse = await apiClient.post('/auth/login', body: {
        'microsoft_token': microsoftToken,
      });

      final backendToken = loginResponse['access_token'] as String;
      final userData = Usuario.fromJson(loginResponse['user'] as Map<String, dynamic>);

      state = state.copyWith(
        token: backendToken,
        user: userData,
        isGuest: false,
        isLoading: false,
      );
      await _persistSession(backendToken);

      if (kDebugMode) print('Login correctly synchronized with Backend');
    } catch (e) {
      if (kDebugMode) print('Login failed: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresca los datos del usuario actual desde la API (/auth/me)
  Future<void> refreshCurrentUser() async {
    if (state.isGuest) return;
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
    state = state.copyWith(token: token, isGuest: false);
    await _persistSession(token);
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
        isGuest: false,
        isLoading: false,
      );
      await _persistSession(backendToken);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Inicia sesión temporal como invitado.
  ///
  /// Borra cualquier token o usuario previo e indica a la aplicación que
  /// debe funcionar en modo restringido (Guest Mode).
  Future<void> loginAsGuest() async {
    state = state.copyWith(isLoading: true, error: null, clearToken: true, clearUser: true);
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.post('/auth/guest');
      state = state.copyWith(isGuest: true, isLoading: false);
      await _persistGuestSession();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Cierra la sesión activa del usuario.
  ///
  /// Elimina los datos locales (excepto configuraciones persistentes como el idioma
  /// o el flag de onboarding), limpia la memoria caché de imágenes y resetea el estado
  /// a su valor por defecto (sin autenticar).
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString('language_code');
      final hasSeenOnboarding = prefs.getBool('has_seen_onboarding');
      final tutorialSeenByUser = <String, bool>{};
      for (final key in prefs.getKeys()) {
        if (!key.startsWith('has_seen_app_tutorial')) continue;
        final value = prefs.getBool(key);
        if (value != null) {
          tutorialSeenByUser[key] = value;
        }
      }

      await prefs.clear();

      if (savedLanguageCode != null) {
        await prefs.setString('language_code', savedLanguageCode);
      }
      if (hasSeenOnboarding != null) {
        await prefs.setBool('has_seen_onboarding', hasSeenOnboarding);
      }
      for (final entry in tutorialSeenByUser.entries) {
        await prefs.setBool(entry.key, entry.value);
      }
      await _clearPersistedSession();
    } catch (_) {}

    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    state = AuthState();
  }

  Future<void> _persistSession(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setBool(_guestKey, false);
    await prefs.setString(
      _loginTimestampKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> _persistGuestSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.setBool(_guestKey, true);
    await prefs.setString(
      _loginTimestampKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> _clearPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_guestKey);
    await prefs.remove(_loginTimestampKey);
  }

  /// Restaura la sesión desde el almacenamiento local si existe y es válida.
  ///
  /// Comprueba si hay un token o una sesión de invitado guardada, evalúa su
  /// fecha de expiración y, si sigue siendo válida, recupera los datos del usuario.
  Future<void> _restorePersistedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final isGuest = prefs.getBool(_guestKey) ?? false;
      final loginTsRaw = prefs.getString(_loginTimestampKey);

      if ((token == null && !isGuest) || loginTsRaw == null) {
        state = AuthState();
        return;
      }

      final loginTs = DateTime.tryParse(loginTsRaw)?.toUtc();
      if (loginTs == null) {
        await _clearPersistedSession();
        state = AuthState();
        return;
      }

      final expiresAt = loginTs.add(
        const Duration(minutes: _sessionDurationMinutes),
      );
      if (DateTime.now().toUtc().isAfter(expiresAt)) {
        await _clearPersistedSession();
        state = AuthState();
        return;
      }

      if (isGuest) {
        state = state.copyWith(isGuest: true, isLoading: false, error: null);
        return;
      }

      state = state.copyWith(token: token, isLoading: true, error: null, isGuest: false);
      await refreshCurrentUser();

      if (state.user == null) {
        await _clearPersistedSession();
        state = AuthState();
        return;
      }

      state = state.copyWith(isLoading: false);
    } catch (_) {
      state = AuthState();
    }
  }
}

final authProvider = NotifierProvider<AuthProvider, AuthState>(() {
  return AuthProvider();
});
