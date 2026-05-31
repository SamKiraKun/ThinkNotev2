import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_env.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/network/authenticated_api_client.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../auth/auth_providers.dart';
import '../../../notes/data/models/app_preferences_model.dart';
import '../../../notes/presentation/controllers/notes_controller.dart';
import '../../../sync/presentation/controllers/sync_controller.dart';
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

    await sharedPreferences.setBool(StorageKeys.hasCompletedOnboarding, true);
    await sharedPreferences.setString(
      StorageKeys.onboardingWorkspaceName,
      normalizedName,
    );
    await sharedPreferences.setString(
      StorageKeys.onboardingWorkspaceFocus,
      workspaceFocus.storageValue,
    );
    await sharedPreferences.setBool(
      StorageKeys.notificationsEnabled,
      wantsNotifications,
    );
    await sharedPreferences.setString(
      StorageKeys.onboardingThemePreference,
      themePreference.storageValue,
    );

    final currentPreferences =
        ref.read(notesControllerProvider).valueOrNull?.preferences ??
            const AppPreferencesModel();
    await ref.read(notesControllerProvider.notifier).updatePreferences(
          currentPreferences.copyWith(themePreference: themePreference),
        );

    state = AsyncData(
      OnboardingProfile(
        hasCompletedOnboarding: true,
        workspaceName: normalizedName,
        workspaceFocus: workspaceFocus,
        wantsNotifications: wantsNotifications,
        themePreference: themePreference,
      ),
    );
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
  final startTime = DateTime.now();

  final session = ref.watch(currentAuthSessionProvider);
  final onboardingProfile =
      await ref.watch(onboardingControllerProvider.future);

  if (session != null) {
    try {
      await ref.read(authenticatedAccountProvider.future);
      await ref.read(syncControllerProvider.notifier).syncNow(
            forceFullPull: true,
            rethrowOnError: true,
          );
      ref.invalidate(notesControllerProvider);
      await ref.read(notesControllerProvider.future);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await ref.read(authRepositoryProvider).signOut();
        return AppStartupSnapshot(
          onboardingProfile: onboardingProfile,
          requiresAuthentication: true,
        );
      }
      rethrow;
    }
  }

  final elapsed = DateTime.now().difference(startTime);
  const minDelay = Duration(seconds: 1);
  if (elapsed < minDelay) {
    await Future.delayed(minDelay - elapsed);
  }

  return AppStartupSnapshot(
    onboardingProfile: onboardingProfile,
    requiresAuthentication: session == null,
  );
});
