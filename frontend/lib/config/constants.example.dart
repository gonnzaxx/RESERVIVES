/// RESERVIVES - Plantilla de Constantes.
library;

class AppConstants {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  static const String appName = 'RESERVIVES';
  static const String appTagline = 'IES Luis Vives';

  static const String azureClientId = String.fromEnvironment('AZURE_CLIENT_ID');
  static const String azureTenantId = String.fromEnvironment('AZURE_TENANT_ID');
  static const String azureRedirectUri = String.fromEnvironment('AZURE_REDIRECT_URI');

  static const List<String> allowedDomains = [
    'alumno.iesluisvives.org',
    'profesor.iesluisvives.org',
    'iesluisvives.org',
  ];

  static const int defaultPageSize = 20;
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
