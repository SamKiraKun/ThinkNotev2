import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_names.dart';
import '../../features/onboarding/presentation/controllers/onboarding_controller.dart';
import '../../features/auth/presentation/screens/app_passcode_unlock_screen.dart';

class RouteGuards {
  const RouteGuards._();

  static String? appRedirect(Ref ref, GoRouterState state) {
    final location = state.matchedLocation;
    final isLaunchRoute = location == RouteNames.launch;
    final isOnboardingRoute = location == RouteNames.onboarding;
    final isAuthRoute = location == RouteNames.auth;
    final isUnlockRoute = location == RouteNames.unlock;
    final startupSnapshot = ref.read(appStartupSnapshotProvider);

    if (startupSnapshot.isLoading) {
      if (isLaunchRoute || isOnboardingRoute || isAuthRoute) {
        return null;
      }
      return RouteNames.launch;
    }

    if (startupSnapshot.hasError) {
      if (isLaunchRoute || isOnboardingRoute || isAuthRoute) {
        return null;
      }
      return RouteNames.launch;
    }

    final startup = startupSnapshot.requireValue;

    if (!startup.onboardingProfile.hasCompletedOnboarding) {
      return isOnboardingRoute ? null : RouteNames.onboarding;
    }

    if (startup.requiresAuthentication) {
      return isAuthRoute ? null : RouteNames.auth;
    }

    // Enforce passcode lock gate if configured and session is locked
    final isUnlocked = ref.read(appUnlockedProvider);
    if (!isUnlocked) {
      return isUnlockRoute ? null : RouteNames.unlock;
    }

    if (isLaunchRoute || isOnboardingRoute || isAuthRoute || isUnlockRoute) {
      return RouteNames.root;
    }

    return null;
  }
}
