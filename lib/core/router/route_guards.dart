import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../config/app_env.dart';
import '../constants/route_names.dart';

class RouteGuards {
  const RouteGuards._();

  static String? authRedirect(Ref ref, GoRouterState state) {
    if (!AppEnv.enableExperimentalSync) {
      return state.matchedLocation == RouteNames.auth ? RouteNames.root : null;
    }

    final session = ref.read(currentAuthSessionProvider);
    final isAuthRoute = state.matchedLocation == RouteNames.auth;

    if (session == null && !isAuthRoute) {
      return RouteNames.auth;
    }

    if (session != null && isAuthRoute) {
      return RouteNames.root;
    }

    return null;
  }
}
