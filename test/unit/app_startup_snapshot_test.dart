import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thinknote/core/network/authenticated_api_client.dart';
import 'package:thinknote/features/auth/auth_providers.dart';
import 'package:thinknote/features/auth/domain/entities/auth_session.dart';
import 'package:thinknote/features/auth/domain/repositories/auth_repository.dart';
import 'package:thinknote/features/notes/data/models/app_preferences_model.dart';
import 'package:thinknote/features/onboarding/data/models/onboarding_profile.dart';
import 'package:thinknote/features/onboarding/presentation/controllers/onboarding_controller.dart';

void main() {
  test('unauthenticated startup snapshot resolves without an artificial delay',
      () async {
    final container = ProviderContainer(
      overrides: [
        onboardingControllerProvider.overrideWith(
          () => _TestOnboardingController(_completedProfile),
        ),
        currentAuthSessionProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final stopwatch = Stopwatch()..start();
    final snapshot = await container.read(appStartupSnapshotProvider.future);
    stopwatch.stop();

    expect(snapshot.onboardingProfile.hasCompletedOnboarding, isTrue);
    expect(snapshot.requiresAuthentication, isTrue);
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 300)));
  });

  test('unauthorized backend bootstrap signs out and falls back to auth',
      () async {
    final authRepository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [
        onboardingControllerProvider.overrideWith(
          () => _TestOnboardingController(_completedProfile),
        ),
        currentAuthSessionProvider.overrideWithValue(
          const AuthSession(uid: 'user-1', email: 'sam@example.com'),
        ),
        authRepositoryProvider.overrideWithValue(authRepository),
        authenticatedAccountProvider.overrideWith(
          (ref) async => throw const ApiException(
            'Missing or invalid authentication token',
            statusCode: 401,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(appStartupSnapshotProvider.future);

    expect(snapshot.requiresAuthentication, isTrue);
    expect(authRepository.signOutCalls, 1);
    expect(
      container.read(authStartupNoticeProvider),
      contains('verified'),
    );
  });

  test('non-auth backend bootstrap failures keep the signed-in app usable',
      () async {
    final authRepository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [
        onboardingControllerProvider.overrideWith(
          () => _TestOnboardingController(_completedProfile),
        ),
        currentAuthSessionProvider.overrideWithValue(
          const AuthSession(uid: 'user-1', email: 'sam@example.com'),
        ),
        authRepositoryProvider.overrideWithValue(authRepository),
        authenticatedAccountProvider.overrideWith(
          (ref) async => throw const ApiException(
            'Service unavailable',
            statusCode: 503,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(appStartupSnapshotProvider.future);

    expect(snapshot.requiresAuthentication, isFalse);
    expect(authRepository.signOutCalls, 0);
    expect(
      container.read(authStartupNoticeProvider),
      contains('working locally'),
    );
  });

  test(
      'account persistence bootstrap failures keep the signed-in app usable with a precise notice',
      () async {
    final authRepository = _FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [
        onboardingControllerProvider.overrideWith(
          () => _TestOnboardingController(_completedProfile),
        ),
        currentAuthSessionProvider.overrideWithValue(
          const AuthSession(uid: 'user-1', email: 'sam@example.com'),
        ),
        authRepositoryProvider.overrideWithValue(authRepository),
        authenticatedAccountProvider.overrideWith(
          (ref) async => throw const ApiException(
            'Account persistence is unavailable',
            statusCode: 503,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(appStartupSnapshotProvider.future);

    expect(snapshot.requiresAuthentication, isFalse);
    expect(authRepository.signOutCalls, 0);
    expect(
      container.read(authStartupNoticeProvider),
      contains('restore your account profile'),
    );
  });
}

final OnboardingProfile _completedProfile = const OnboardingProfile(
  hasCompletedOnboarding: true,
  workspaceName: 'Studio HQ',
  workspaceFocus: WorkspaceFocus.planning,
  wantsNotifications: false,
  themePreference: AppThemePreference.system,
);

class _TestOnboardingController extends OnboardingController {
  _TestOnboardingController(this.profile);

  final OnboardingProfile profile;

  @override
  Future<OnboardingProfile> build() async => profile;
}

class _FakeAuthRepository implements AuthRepository {
  int signOutCalls = 0;

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
  Future<void> sendEmailVerification() {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) {
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
  Future<void> signOut() async {
    signOutCalls += 1;
  }
}
