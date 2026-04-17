/// RESERVIVES - Constantes de la aplicación.
///
/// URLs de la API, valores por defecto y configuraciones
library;

class AppConstants {
  // URL base de la API
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  // Nombre de la app
  static const String appName = 'RESERVIVES';
  static const String appTagline = 'IES Luis Vives';

  // Microsoft EntraID 
  static const String azureClientId = String.fromEnvironment(
    'AZURE_CLIENT_ID',
    defaultValue: '', // ID de cliente
  );
  static const String azureTenantId = String.fromEnvironment(
    'AZURE_TENANT_ID',
    defaultValue: '', // ID de inquilino
  );
  static const String azureRedirectUri = String.fromEnvironment(
    'AZURE_REDIRECT_URI',
    defaultValue: '', // URI de redirección
  );

  // Dominios del instituto
  static const List<String> allowedDomains = [
    'alumno.iesluisvives.org',
    'profesor.iesluisvives.org',
    'iesluisvives.org',
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