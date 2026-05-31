import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/network/authenticated_api_client.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../auth/auth_providers.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../data/models/onboarding_profile.dart';

final onboardingControllerProvider =
    AsyncNotifierProvider<OnboardingController, OnboardingProfile>(
  OnboardingController.new,
);

class OnboardingController extends AsyncNotifier<OnboardingProfile> {
  @override
  Future<OnboardingProfile> build() async {
    final sharedPreferences = ref.read(sharedPreferencesProvider);
    return OnboardingProfile(
      hasCompletedOnboarding:
          sharedPreferences.getBool(StorageKeys.hasCompletedOnboarding) ??
              false,
      workspaceName:
          sharedPreferences.getString(StorageKeys.onboardingWorkspaceName) ??
              '',
      workspaceFocus: WorkspaceFocusX.fromStorage(
        sharedPreferences.getString(StorageKeys.onboardingWorkspaceFocus),
      ),
      wantsNotifications:
          sharedPreferences.getBool(StorageKeys.notificationsEnabled) ?? false,
      themePreference: AppThemePreferenceX.fromStorage(
        sharedPreferences.getString(StorageKeys.onboardingThemePreference),
      ),
    );
  }

  Future<void> completeOnboarding({
    required String workspaceName,
    required WorkspaceFocus workspaceFocus,
    required bool wantsNotifications,
    required AppThemePreference themePreference,
  }) async {
    final normalizedName = workspaceName.trim();
    final sharedPreferences = ref.read(sharedPreferencesProvider);

    state = AsyncData(
      OnboardingProfile(
        hasCompletedOnboarding: true,
        workspaceName: normalizedName,
        workspaceFocus: workspaceFocus,
        wantsNotifications: wantsNotifications,
        themePreference: themePreference,
      ),
    );

    unawaited(
      _persistOnboardingSelection(
        sharedPreferences: sharedPreferences,
        workspaceName: normalizedName,
        workspaceFocus: workspaceFocus,
        wantsNotifications: wantsNotifications,
        themePreference: themePreference,
      ),
    );
  }

  Future<void> _persistOnboardingSelection({
    required dynamic sharedPreferences,
    required String workspaceName,
    required WorkspaceFocus workspaceFocus,
    required bool wantsNotifications,
    required AppThemePreference themePreference,
  }) async {
    try {
      await Future.wait<void>([
        sharedPreferences.setBool(StorageKeys.hasCompletedOnboarding, true),
        sharedPreferences.setString(
          StorageKeys.onboardingWorkspaceName,
          workspaceName,
        ),
        sharedPreferences.setString(
          StorageKeys.onboardingWorkspaceFocus,
          workspaceFocus.storageValue,
        ),
        sharedPreferences.setBool(
          StorageKeys.notificationsEnabled,
          wantsNotifications,
        ),
        sharedPreferences.setString(
          StorageKeys.onboardingThemePreference,
          themePreference.storageValue,
        ),
      ]);
    } catch (error, stackTrace) {
      Zone.current.handleUncaughtError(error, stackTrace);
    }
  }
}

class AppStartupSnapshot {
  const AppStartupSnapshot({
    required this.onboardingProfile,
    required this.requiresAuthentication,
  });

  final OnboardingProfile onboardingProfile;
  final bool requiresAuthentication;

  String get nextRoute {
    if (!onboardingProfile.hasCompletedOnboarding) {
      return RouteNames.onboarding;
    }
    return RouteNames.root;
  }

  bool get syncEnabled => AppEnv.enableExperimentalSync;
}

final appStartupSnapshotProvider =
    FutureProvider<AppStartupSnapshot>((ref) async {
  final session = ref.watch(currentAuthSessionProvider);
  final onboardingProfile =
      await ref.watch(onboardingControllerProvider.future);
  final startupNotice = ref.read(authStartupNoticeProvider.notifier);

  if (session != null) {
    try {
      await ref.read(authenticatedAccountProvider.future);
      startupNotice.state = null;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        startupNotice.state = 'Your session could not be verified. Sign in again.';
        await ref.read(authRepositoryProvider).signOut();
        return AppStartupSnapshot(
          onboardingProfile: onboardingProfile,
          requiresAuthentication: true,
        );
      }

      startupNotice.state = _describeStartupFailure(error);
      await ref.read(authRepositoryProvider).signOut();
      return AppStartupSnapshot(
        onboardingProfile: onboardingProfile,
        requiresAuthentication: true,
      );
    }
  }

  return AppStartupSnapshot(
    onboardingProfile: onboardingProfile,
    requiresAuthentication: session == null,
  );
});

String _describeStartupFailure(ApiException error) {
  if (error.statusCode == 401) {
    return 'Your session could not be verified. Sign in again.';
  }

  final message = error.message.trim();
  if (message.isNotEmpty) {
    return message;
  }

  if (error.statusCode != null && error.statusCode! >= 500) {
    return 'The ThinkNote backend is temporarily unavailable. Please try again in a few minutes.';
  }

  return 'The request to the ThinkNote backend could not be completed.';
}
