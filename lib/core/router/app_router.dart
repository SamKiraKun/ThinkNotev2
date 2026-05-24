import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_env.dart';
import '../../features/auth/auth_providers.dart';
import 'app_routes.dart';
import 'route_guards.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  if (AppEnv.enableExperimentalSync) {
    ref.watch(authSessionChangesProvider);
  }

  return GoRouter(
    redirect: (context, state) => RouteGuards.authRedirect(ref, state),
    routes: buildAppRoutes(),
  );
});
