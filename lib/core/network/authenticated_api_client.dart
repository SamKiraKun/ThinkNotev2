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
  String toString() =>
      'ApiException(statusCode: $statusCode, message: $message)';
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
    onUnauthorized: () async {
      await ref.read(authRepositoryProvider).signOut();
    },
  );
});

class AuthenticatedApiClient {
  AuthenticatedApiClient(
    this._httpClient,
    this._authRepository, {
    Future<void> Function()? onUnauthorized,
  }) : _onUnauthorized = onUnauthorized;

  final http.Client _httpClient;
  final AuthRepository _authRepository;
  final Future<void> Function()? _onUnauthorized;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _sendAuthorized((headers) {
      return _httpClient.get(
        _buildUri(path, queryParameters: queryParameters),
        headers: headers,
      );
    });
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _sendAuthorized((headers) {
      return _httpClient.post(
        _buildUri(path),
        headers: headers,
        body: jsonEncode(body ?? const <String, dynamic>{}),
      );
    });
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _sendAuthorized((headers) async {
      final request = http.Request('DELETE', _buildUri(path));
      request.headers.addAll(headers);
      if (body != null) {
        request.body = jsonEncode(body);
      }

      final streamed = await _httpClient.send(request);
      return http.Response.fromStream(streamed);
    });
    return _decodeResponse(response);
  }

  Future<http.Response> _sendAuthorized(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    final firstResponse = await send(await _headers());
    if (firstResponse.statusCode != 401) {
      return firstResponse;
    }

    final retryResponse = await send(await _headers(forceRefresh: true));
    if (retryResponse.statusCode == 401 && _onUnauthorized != null) {
      await _onUnauthorized();
    }

    return retryResponse;
  }

  Uri _buildUri(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    final normalizedBase = AppEnv.apiUri.toString().endsWith('/')
        ? AppEnv.apiUri
        : Uri.parse('${AppEnv.apiUri}/');
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return normalizedBase.resolve(normalizedPath).replace(
          queryParameters: queryParameters,
        );
  }

  Future<Map<String, String>> _headers({bool forceRefresh = false}) async {
    final token = await _authRepository.currentIdToken(
      forceRefresh: forceRefresh,
    );
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
