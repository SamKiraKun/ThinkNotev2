import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import 'route_guards.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    redirect: (context, state) => RouteGuards.authRedirect(ref, state),
    routes: buildAppRoutes(),
  );
});
