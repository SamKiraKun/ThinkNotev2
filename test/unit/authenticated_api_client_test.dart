import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:thinknote/core/network/authenticated_api_client.dart';
import 'package:thinknote/features/auth/domain/entities/auth_session.dart';
import 'package:thinknote/features/auth/domain/repositories/auth_repository.dart';

void main() {
  test('throws a readable ApiException when the backend returns HTML', () async {
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
        await Future<void>.delayed(const Duration(seconds: 16));
        return http.Response('{}', 200);
      }),
      _FakeAuthRepository(),
    );

    await expectLater(
      () => client.getJson('/account/me'),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('took too long to respond'),
        ),
      ),
    );
  });

  test('throws a precise ApiException when the backend route is missing', () async {
    final client = AuthenticatedApiClient(
      MockClient((request) async {
        return http.Response(
          '{"success":false,"message":""}',
          404,
          headers: const {'content-type': 'application/json'},
        );
      }),
      _FakeAuthRepository(),
    );

    await expectLater(
      () => client.getJson('/account/me'),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 404)
            .having(
              (error) => error.message,
              'message',
              contains('route was not found'),
            ),
      ),
    );
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