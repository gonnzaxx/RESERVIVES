import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:reservives/config/constants.dart';
import 'package:reservives/providers/auth_provider.dart';
import 'dart:developer' as developer;

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => 'ApiException: $message ($statusCode)';
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref);
});

class ApiClient {
  final Ref _ref;
  ApiClient(this._ref);

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

  dynamic _processResponse(http.Response response) {
    if (response.statusCode == 401) {
      _ref.read(authProvider.notifier).logout();
      throw ApiException('SesiÃ³n expirada. Por favor, vuelve a iniciar sesiÃ³n.', 401);
    }
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (e) {
        body = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String errorMsg = 'Error en el servidor';
    if (body is Map && body.containsKey('detail')) {
      errorMsg = body['detail'].toString();
    } else if (body is String) {
      errorMsg = body;
    }
    throw ApiException(errorMsg, response.statusCode);
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      var uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final response = await http.get(uri, headers: _getHeaders());
      return _processResponse(response);
    } catch (e) {
      developer.log('ApiClient error', error: e, name: 'services.api_client');
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final headers = _getHeaders();
      if (body == null) headers.remove('Content-Type');
      final response = await http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
      return _processResponse(response);
    } catch (e) {
      developer.log('ApiClient error', error: e, name: 'services.api_client');
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  Future<dynamic> postMultipart(String endpoint, {required String fileField, required List<int> fileBytes, required String fileName}) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);
      final headers = _getHeaders();
      headers.remove('Content-Type');
      request.headers.addAll(headers);
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'png' : (ext == 'jpg' || ext == 'jpeg' ? 'jpeg' : 'png');
      final multipartFile = http.MultipartFile.fromBytes(fileField, fileBytes, filename: fileName, contentType: MediaType('image', mimeType));
      request.files.add(multipartFile);
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _processResponse(response);
    } catch (e) {
      developer.log('ApiClient error', error: e, name: 'services.api_client');
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  Future<dynamic> put(String endpoint, {required Map<String, dynamic> body}) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final response = await http.put(uri, headers: _getHeaders(), body: jsonEncode(body));
      return _processResponse(response);
    } catch (e) {
      developer.log('ApiClient error', error: e, name: 'services.api_client');
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  Future<dynamic> putJson(String endpoint, {required dynamic body}) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final response = await http.put(uri, headers: _getHeaders(), body: jsonEncode(body));
      return _processResponse(response);
    } catch (e) {
      developer.log('ApiClient error', error: e, name: 'services.api_client');
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  Future<dynamic> patch(String endpoint, {required Map<String, dynamic> body}) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final response = await http.patch(uri, headers: _getHeaders(), body: jsonEncode(body));
      return _processResponse(response);
    } catch (e) {
      developer.log('ApiClient error', error: e, name: 'services.api_client');
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }

  Future<dynamic> delete(String endpoint) async {
    try {
      final uri = Uri.parse('${AppConstants.apiBaseUrl}$endpoint');
      final response = await http.delete(uri, headers: _getHeaders());
      return _processResponse(response);
    } catch (e) {
      developer.log('ApiClient error', error: e, name: 'services.api_client');
      if (e is ApiException) rethrow;
      throw ApiException('Error al conectar con el servidor', 503);
    }
  }
}

