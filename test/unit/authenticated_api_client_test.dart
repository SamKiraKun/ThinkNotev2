import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thinknote/core/network/authenticated_api_client.dart';
import 'package:thinknote/features/auth/domain/entities/auth_session.dart';
import 'package:thinknote/features/auth/domain/repositories/auth_repository.dart';

void main() {
  test('throws a readable ApiException when the backend returns HTML',
      () async {
    final client = AuthenticatedApiClient(
      MockClient((request) async {
        expect(request.headers['accept'], 'application/json');
        expect(request.headers['authorization'], 'Bearer test-token');

        return http.Response(
          '<!DOCTYPE html><html><body>This service has been suspended.</body></html>',
          503,
          headers: const {'content-type': 'text/html; charset=utf-8'},
        );
      }),
      _FakeAuthRepository(),
    );

    await expectLater(
      () => client.getJson('/account/me'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 503)
            .having((error) => error.kind, 'kind', ApiFailureKind.server)
            .having(
              (error) => error.message,
              'message',
              contains('backend is unavailable'),
            ),
      ),
    );
  });

  test('throws a precise ApiException when the backend times out', () async {
    final client = AuthenticatedApiClient(
      MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return http.Response('{}', 200);
      }),
      _FakeAuthRepository(),
      requestTimeout: const Duration(milliseconds: 10),
    );

    await expectLater(
      () => client.getJson('/account/me'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.kind, 'kind', ApiFailureKind.timeout)
            .having(
              (error) => error.message,
              'message',
              contains('took too long to respond'),
            ),
      ),
    );
  });

  test('throws a precise ApiException when the backend route is missing',
      () async {
    final client = AuthenticatedApiClient(
      MockClient((request) async {
        return http.Response(
          '{"success":false,"message":""}',
          404,
          headers: const {
            'content-type': 'application/json',
            'x-request-id': 'req-missing-route',
          },
        );
      }),
      _FakeAuthRepository(),
    );

    await expectLater(
      () => client.getJson('/account/me'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having((error) => error.kind, 'kind', ApiFailureKind.notFound)
            .having((error) => error.endpoint, 'endpoint', '/account/me')
            .having(
              (error) => error.requestId,
              'requestId',
              'req-missing-route',
            )
            .having(
              (error) => error.message,
              'message',
              contains('route was not found'),
            ),
      ),
    );
  });

  test('verifies the authenticated sync readiness endpoint before sync',
      () async {
    final client = AuthenticatedApiClient(
      MockClient((request) async {
        expect(request.url.path, '/sync/readiness');
        expect(request.headers['accept'], 'application/json');
        expect(request.headers['authorization'], 'Bearer test-token');

        return http.Response(
          '{"success":true,"data":{"status":"ready","server_time":"2026-06-01T00:00:00.000Z"}}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
      _FakeAuthRepository(),
    );

    await client.verifySyncReadiness();
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Stream<AuthSession?> authStateChanges() => const Stream<AuthSession?>.empty();

  @override
  AuthSession? currentSession() => null;

  @override
  Future<String> currentIdToken({bool forceRefresh = false}) async {
    return 'test-token';
  }

  @override
  Future<AuthSession> reloadSession() {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
    throw UnimplementedError();
  }

  @override
  Future<void> sendEmailVerification() {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}
