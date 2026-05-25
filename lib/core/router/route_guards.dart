import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_env.dart';
import '../constants/route_names.dart';
import '../../features/onboarding/presentation/controllers/onboarding_controller.dart';

class RouteGuards {
  const RouteGuards._();

  static String? appRedirect(Ref ref, GoRouterState state) {
    final location = state.matchedLocation;
    final isLaunchRoute = location == RouteNames.launch;
    final isOnboardingRoute = location == RouteNames.onboarding;
    final isAuthRoute = location == RouteNames.auth;
    final startupSnapshot = ref.read(appStartupSnapshotProvider);

    if (startupSnapshot.isLoading) {
      return isLaunchRoute ? null : RouteNames.launch;
    }

    if (startupSnapshot.hasError) {
      return isLaunchRoute ? null : RouteNames.launch;
    }

    final startup = startupSnapshot.requireValue;

    if (!startup.onboardingProfile.hasCompletedOnboarding) {
      return isOnboardingRoute ? null : RouteNames.onboarding;
    }

    if (AppEnv.enableExperimentalSync && startup.requiresAuthentication) {
      return isAuthRoute ? null : RouteNames.auth;
    }

    if (isLaunchRoute || isOnboardingRoute || isAuthRoute) {
      return RouteNames.root;
    }

    return null;
  }
}
