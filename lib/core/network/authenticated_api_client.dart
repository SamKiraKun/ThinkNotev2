import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../features/auth/auth_providers.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../config/app_env.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final authenticatedApiClientProvider = Provider<AuthenticatedApiClient>((ref) {
  return AuthenticatedApiClient(
    ref.watch(httpClientProvider),
    ref.watch(authRepositoryProvider),
  );
});

class AuthenticatedApiClient {
  AuthenticatedApiClient(this._httpClient, this._authRepository);

  final http.Client _httpClient;
  final AuthRepository _authRepository;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _httpClient.get(
      _buildUri(path, queryParameters: queryParameters),
      headers: await _headers(),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _httpClient.post(
      _buildUri(path),
      headers: await _headers(),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request('DELETE', _buildUri(path));
    request.headers.addAll(await _headers());
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamed = await _httpClient.send(request);
    final response = await http.Response.fromStream(streamed);
    return _decodeResponse(response);
  }

  Uri _buildUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedBase = AppEnv.apiUri.toString().endsWith('/')
        ? AppEnv.apiUri
        : Uri.parse('${AppEnv.apiUri}/');
    final normalizedPath =
        path.startsWith('/') ? path.substring(1) : path;
    return normalizedBase.resolve(normalizedPath).replace(
          queryParameters: queryParameters,
        );
  }

  Future<Map<String, String>> _headers() async {
    final token = await _authRepository.currentIdToken();
    return <String, String>{
      'authorization': 'Bearer $token',
      'content-type': 'application/json',
      'accept': 'application/json',
    };
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Request failed.',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }
}
