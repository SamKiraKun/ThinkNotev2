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
    final rawBody = response.body.trim();
    if (rawBody.isEmpty) {
      if (response.statusCode >= 400) {
        throw ApiException(
          'Request failed.',
          statusCode: response.statusCode,
        );
      }
      return const <String, dynamic>{};
    }

    if (_looksLikeHtmlResponse(response, rawBody)) {
      throw ApiException(
        _unexpectedHtmlMessage(response, rawBody),
        statusCode: response.statusCode,
      );
    }

    final decoded = _decodeJsonMap(response, rawBody);

    if (response.statusCode >= 400) {
      throw ApiException(
        decoded['message']?.toString() ?? 'Request failed.',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response, String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw ApiException(
        'Unexpected API response format.',
        statusCode: response.statusCode,
      );
    } on FormatException {
      throw ApiException(
        'Unexpected response from the ThinkNote API. Confirm that API_URL points to the backend API and that the service is returning JSON.',
        statusCode: response.statusCode,
      );
    }
  }

  bool _looksLikeHtmlResponse(http.Response response, String rawBody) {
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    return contentType.contains('text/html') || rawBody.startsWith('<!DOCTYPE html') || rawBody.startsWith('<html');
  }

  String _unexpectedHtmlMessage(http.Response response, String rawBody) {
    if (response.statusCode == 503 || rawBody.toLowerCase().contains('service suspended')) {
      return 'The ThinkNote backend is unavailable right now. The configured API returned an HTML service-suspended page instead of JSON. Verify that the backend deployment is active and that API_URL points to the API service.';
    }

    return 'The configured API returned HTML instead of JSON. Verify that API_URL points to the ThinkNote backend API, not a website or error page.';
  }
}
