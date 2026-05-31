import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  static const Duration _requestTimeout = Duration(seconds: 15);

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
    final uri = _buildUri(path, queryParameters: queryParameters);
    final response = await _sendAuthorized('GET', uri, (headers) {
      return _httpClient.get(
        uri,
        headers: headers,
      );
    });
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildUri(path);
    final response = await _sendAuthorized('POST', uri, (headers) {
      return _httpClient.post(
        uri,
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
    final uri = _buildUri(path);
    final response = await _sendAuthorized('DELETE', uri, (headers) async {
      final request = http.Request('DELETE', uri);
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
    String method,
    Uri uri,
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    try {
      _debugLogRequest(method, uri);
      final firstResponse = await _sendWithTimeout(send, await _headers());
      _debugLogResponse(method, uri, firstResponse);
      if (firstResponse.statusCode != 401) {
        return firstResponse;
      }

      _debugLogRetry(method, uri);
      final retryResponse = await _sendWithTimeout(
        send,
        await _headers(forceRefresh: true),
      );
      _debugLogResponse(method, uri, retryResponse, retried: true);
      if (retryResponse.statusCode == 401 && _onUnauthorized != null) {
        await _onUnauthorized();
      }

      return retryResponse;
    } on TimeoutException catch (error, stackTrace) {
      _debugLogFailure(method, uri, error, stackTrace);
      throw const ApiException(
        'The ThinkNote backend took too long to respond. Check your connection and try again.',
      );
    } on http.ClientException catch (error, stackTrace) {
      _debugLogFailure(method, uri, error, stackTrace);
      throw ApiException(_describeClientException(error));
    }
  }

  Future<http.Response> _sendWithTimeout(
    Future<http.Response> Function(Map<String, String> headers) send,
    Map<String, String> headers,
  ) {
    return send(headers).timeout(_requestTimeout);
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
          _fallbackHttpErrorMessage(response.statusCode),
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
      final message = decoded['message']?.toString().trim();
      throw ApiException(
        message != null && message.isNotEmpty
            ? message
            : _fallbackHttpErrorMessage(response.statusCode),
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

  String _fallbackHttpErrorMessage(int statusCode) {
    return switch (statusCode) {
      400 => 'The request sent to the ThinkNote backend was invalid.',
      401 => 'Your session could not be verified. Sign in again.',
      403 => 'You do not have permission to perform that action.',
      404 => 'The configured ThinkNote API route was not found. Verify that API_URL points to the active backend deployment.',
      408 => 'The ThinkNote backend took too long to respond. Check your connection and try again.',
      409 => 'The request could not be completed because of a conflict on the backend.',
      422 => 'The server rejected the request data. Review the provided information and try again.',
      429 => 'Too many requests were sent to the ThinkNote backend. Try again in a moment.',
      _ when statusCode >= 500 => 'The ThinkNote backend is temporarily unavailable. Please try again in a few minutes.',
      _ => 'Request failed.',
    };
  }

  String _describeClientException(http.ClientException error) {
    final message = error.message.toLowerCase();
    if (message.contains('certificate') || message.contains('handshake')) {
      return 'A secure connection to the ThinkNote backend could not be established. Check the backend certificate configuration and try again.';
    }

    if (message.contains('failed host lookup') ||
        message.contains('network is unreachable') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('connection closed')) {
      return 'Unable to reach the ThinkNote backend. Check your internet connection and verify that API_URL points to the active server.';
    }

    return 'A network error prevented ThinkNote from reaching the backend. Please try again.';
  }

  void _debugLogRequest(String method, Uri uri) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[ThinkNote API] $method $uri');
  }

  void _debugLogRetry(String method, Uri uri) {
    if (!kDebugMode) {
      return;
    }

    debugPrint('[ThinkNote API] retrying $method $uri after 401');
  }

  void _debugLogResponse(
    String method,
    Uri uri,
    http.Response response, {
    bool retried = false,
  }) {
    if (!kDebugMode) {
      return;
    }

    final contentType = response.headers['content-type'] ?? 'unknown';
    final requestLabel = retried ? '$method $uri (retry)' : '$method $uri';
    final htmlPreview = _debugHtmlPreview(response);
    if (htmlPreview == null) {
      debugPrint(
        '[ThinkNote API] $requestLabel -> ${response.statusCode} ($contentType)',
      );
      return;
    }

    debugPrint(
      '[ThinkNote API] $requestLabel -> ${response.statusCode} ($contentType) html=$htmlPreview',
    );
  }

  void _debugLogFailure(
    String method,
    Uri uri,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!kDebugMode) {
      return;
    }

    debugPrint(
      '[ThinkNote API] $method $uri failed with ${error.runtimeType}: $error',
    );
  }

  String? _debugHtmlPreview(http.Response response) {
    final trimmedBody = response.body.trim();
    if (trimmedBody.isEmpty || !_looksLikeHtmlResponse(response, trimmedBody)) {
      return null;
    }

    final normalized = trimmedBody.replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.length <= 120) {
      return normalized;
    }

    return '${normalized.substring(0, 120)}...';
  }
}
