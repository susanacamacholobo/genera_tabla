import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_configuration.dart';
import '../errors/app_exception.dart';
import 'api_response.dart';

class ApiClient {
  ApiClient({
    required this.configuration,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
  }) : _httpClient = httpClient ?? http.Client();

  final AppConfiguration configuration;
  final Duration timeout;
  final http.Client _httpClient;

  Future<ApiResponse> get(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) => _send(
    method: 'GET',
    path: path,
    queryParameters: queryParameters,
    headers: headers,
  );

  Future<ApiResponse> post(
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) => _send(
    method: 'POST',
    path: path,
    body: body,
    queryParameters: queryParameters,
    headers: headers,
  );

  Future<ApiResponse> put(
    String path, {
    Object? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) => _send(
    method: 'PUT',
    path: path,
    body: body,
    queryParameters: queryParameters,
    headers: headers,
  );

  Future<ApiResponse> delete(
    String path, {
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) => _send(
    method: 'DELETE',
    path: path,
    queryParameters: queryParameters,
    headers: headers,
  );

  Future<ApiResponse> _send({
    required String method,
    required String path,
    Object? body,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final request = http.Request(
      method,
      configuration.endpoint(path, queryParameters: queryParameters),
    );
    request.headers.addAll({'accept': 'application/json', ...?headers});
    if (body != null) {
      request.headers.putIfAbsent(
        'content-type',
        () => 'application/json; charset=utf-8',
      );
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await _httpClient.send(request).timeout(timeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(timeout);
      Object? decoded;
      try {
        decoded = _decodeBody(response);
      } on ResponseDecodingException {
        if (response.statusCode >= 200 && response.statusCode < 300) rethrow;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          statusCode: response.statusCode,
          userMessage: _errorMessage(decoded, response.statusCode),
        );
      }
      return ApiResponse(
        statusCode: response.statusCode,
        headers: Map.unmodifiable(response.headers),
        data: decoded,
      );
    } on AppException {
      rethrow;
    } on TimeoutException {
      throw const NetworkException('El servidor tardó demasiado en responder.');
    } on http.ClientException {
      throw const NetworkException(
        'No se pudo conectar con el servidor. Verifica la red local y API_BASE_URL.',
      );
    }
  }

  Object? _decodeBody(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;

    try {
      final body = utf8.decode(response.bodyBytes);
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (!contentType.contains('json')) return body;
      return jsonDecode(body);
    } on FormatException {
      throw const ResponseDecodingException(
        'El servidor devolvió una respuesta JSON inválida.',
      );
    }
  }

  String _errorMessage(Object? body, int statusCode) {
    if (body is Map<String, dynamic>) {
      for (final key in const ['message', 'detail', 'error']) {
        final value = body[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
    }
    return 'El servidor respondió con el estado $statusCode.';
  }

  void close() => _httpClient.close();
}
