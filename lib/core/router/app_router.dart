import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/route_names.dart';
import '../../features/onboarding/presentation/controllers/onboarding_controller.dart';
import '../../features/auth/presentation/screens/app_passcode_unlock_screen.dart';
import 'app_routes.dart';
import 'route_guards.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(appStartupSnapshotProvider);
  ref.watch(appUnlockedProvider);

  return GoRouter(
    initialLocation: RouteNames.launch,
    redirect: (context, state) => RouteGuards.appRedirect(ref, state),
    routes: buildAppRoutes(),
  );
});
