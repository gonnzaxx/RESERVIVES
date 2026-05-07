/// RESERVIVES - Constantes de la aplicación
library;

class AppConstants {
  // URL base de la API
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://tu_dominio_o_ip:1212/api',
  );

  // Nombre de la app
  static const String appName = 'AppName Example';
  static const String appTagline = 'Tagline Example';

  // Microsoft EntraID
  static const String azureClientId = 'AZURE_CLIENT_ID';
  static const String azureTenantId = 'AZURE_TENANT_ID';
  static const String azureScope = 'AZURE_SCOPE';
  static const String azureRedirectUriWeb = 'AZURE_REDIRECT_URI_WEB';
  static const String azureRedirectUriNative = 'AZURE_REDIRECT_URI_NATIVE';
  static const String azureCustomScheme = 'AZURE_CUSTOM_SCHEME';

  // Dominios del instituto
  static const List<String> allowedDomains = [
    'alumno.domain.org',
    'profesor.domain.org',
    'domain.org',
  ];

  // Paginación
  static const int defaultPageSize = 20;

  // Animaciones (duración en ms)
  static const int animationDuration = 300;
  static const int animationDurationLong = 500;

  static String get apiOrigin {
    final uri = Uri.parse(apiBaseUrl);
    return '${uri.scheme}://${uri.authority}';
  }

  static String resolveApiUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$apiOrigin$path';
    return '$apiOrigin/$path';
  }
}