import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'dart:developer' as developer;

/// Excepción personalizada para errores devueltos por la API.
class ApiException implements Exception {
  final String message; // Mensaje para el usuario
  final int statusCode;// Código de estado HTTP (400, 404, 500, etc.)

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException: $message ($statusCode)';
}

/// Provider global para acceder a la instancia de [ApiClient] en toda la app.
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref);
});

class ApiClient {
  final Ref _ref;
  ApiClient(this._ref);
  /// Genera las cabeceras estándar e inyecta el token de autorización si existe.
  Map<String, String> _getHeaders() {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = _ref.read(authProvider.notifier).token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Procesa la respuesta del servidor, gestiona el refresco de sesión y parsea errores.
  dynamic _processResponse(http.Response response) {

    // Si el token es inválido o ha expirado, forzamos el logout.
    if (response.statusCode == 401) {
      final authState = _ref.read(authProvider);
      if (!authState.isGuest) {
        _ref.read(authProvider.notifier).logout();
      }
      throw ApiException('Sesión expirada. Por favor, vuelve a iniciar sesión.', 401);
    }
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        // Decodificación de bytes para asegurar soporte correcto de caracteres UTF-8.
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (e) {
        body = response.body;
      }
    }

    // Retornamos el cuerpo si la respuesta es del tipo 2xx.
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    // Intenta extraer el mensaje de error estructurado del backend.
    String errorMsg = 'Error en el servidor';
    if (body is Map && body.containsKey('detail')) {
      errorMsg = body['detail'].toString();

    } else if (body is String) {
      errorMsg = body;
    }
    throw ApiException(errorMsg, response.statusCode);
  }

  /// Registra el error en consola solo si no es un 401 esperado en modo invitado.
  void _logError(Object e) {
    final isGuest401 = e is ApiException &&
        e.statusCode == 401 &&
        _ref.read(authProvider).isGuest;
    if (!isGuest401) {
      developer.log('ApiClient error', error: e, name: 'services.api_client');
    }
  }

  /// Realiza una petición GET al [endpoint] indicado.
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');

      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(uri, headers: _getHeaders());
      return _processResponse(response);

    } catch (e) {
      _logError(e);
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  /// Realiza una petición POST al [endpoint] indicado, serializando el [body] a JSON.
  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {

      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final headers = _getHeaders();
      if (body == null) headers.remove('Content-Type');
      final response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
      return _processResponse(response);

    } catch (e) {
      _logError(e);
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  /// Sube un archivo al servidor utilizando un formato [MultipartRequest].
  Future<dynamic> postMultipart(String endpoint, {required String fileField, required List<int> fileBytes, required String fileName}) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);
      final headers = _getHeaders();

      headers.remove('Content-Type');
      request.headers.addAll(headers);

      // Detecta el tipo de imagen basándose en la extensión.
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'png' : (ext == 'jpg' || ext == 'jpeg' ? 'jpeg' : 'png');
      final multipartFile = http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName, contentType: MediaType('image', mimeType));

      request.files.add(multipartFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return _processResponse(response);

    } catch (e) {
      _logError(e);
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  /// Realiza una petición PUT para actualizaciones completas.
  Future<dynamic> put(String endpoint, {required Map<String, dynamic> body}) async {
    try {

      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final response = await http.put(uri, headers: _getHeaders(), body: jsonEncode(body));
      return _processResponse(response);

    } catch (e) {
      _logError(e);
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  /// Variante de PUT que acepta un [body] de tipo dinámico (listas o primitivos).
  Future<dynamic> putJson(String endpoint, {required dynamic body}) async {
    try {

      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final response = await http.put(uri, headers: _getHeaders(), body: jsonEncode(body));
      return _processResponse(response);

    } catch (e) {
      _logError(e);
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  /// Realiza una petición PATCH para actualizaciones parciales.
  Future<dynamic> patch(String endpoint, {required Map<String, dynamic> body}) async {
    try {

      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final response = await http.patch(uri, headers: _getHeaders(), body: jsonEncode(body));
      return _processResponse(response);

    } catch (e) {
      _logError(e);
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  /// Realiza una petición DELETE para eliminar recursos.
  Future<dynamic> delete(String endpoint) async {
    try {

      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final response = await http.delete(uri, headers: _getHeaders());
      return _processResponse(response);

    } catch (e) {
      _logError(e);
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }
}

