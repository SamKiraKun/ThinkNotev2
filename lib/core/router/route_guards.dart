import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final isAuthenticatedProvider = Provider<bool>((ref) {
  // Firebase Auth is not wired until the project supplies platform config.
  // Keep local-first routes available while exposing a single guard seam.
  return true;
});

class RouteGuards {
  const RouteGuards._();

  static String? authRedirect(Ref ref, GoRouterState state) {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (isAuthenticated) {
      return null;
    }

    return null;
  }
}
