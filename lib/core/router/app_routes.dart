import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/auth_gate_screen.dart';
import '../../features/auth/presentation/screens/app_passcode_unlock_screen.dart';
import '../../features/onboarding/presentation/screens/app_launch_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_experience_screen.dart';
import '../../features/notes/presentation/screens/archived_notes_screen.dart';
import '../../features/notes/presentation/screens/note_editor_screen.dart';
import '../../features/notes/presentation/screens/trash_screen.dart';
import '../../features/profile/presentation/screens/import_export_screen.dart';
import '../../features/profile/presentation/screens/lock_notes_screen.dart';
import '../../features/profile/presentation/screens/notification_settings_screen.dart';
import '../../features/profile/presentation/screens/privacy_screen.dart';
import '../../features/profile/presentation/screens/theme_settings_screen.dart';
import '../../features/shell/presentation/screens/main_shell_screen.dart';
import '../constants/route_names.dart';

List<RouteBase> buildAppRoutes() {
  return <RouteBase>[
    GoRoute(
      path: RouteNames.launch,
      builder: (context, state) => const AppLaunchScreen(),
    ),
    GoRoute(
      path: RouteNames.onboarding,
      builder: (context, state) => const OnboardingExperienceScreen(),
    ),
    GoRoute(
      path: RouteNames.auth,
      builder: (context, state) => const AuthGateScreen(),
    ),
    GoRoute(
      path: RouteNames.unlock,
      builder: (context, state) => const AppPasscodeUnlockScreen(),
    ),
    GoRoute(
      path: RouteNames.root,
      builder: (context, state) => const MainShellScreen(),
    ),
    GoRoute(
      path: RouteNames.editor,
      builder: (context, state) {
        final extra =
            state.extra as Map<String, dynamic>? ?? const <String, dynamic>{};
        return NoteEditorScreen(
          noteId: extra['noteId'] as String?,
          initialFolderId: extra['initialFolderId'] as String?,
        );
      },
    ),
    GoRoute(
      path: RouteNames.trash,
      builder: (context, state) => const TrashScreen(),
    ),
    GoRoute(
      path: RouteNames.archive,
      builder: (context, state) => const ArchivedNotesScreen(),
    ),
    GoRoute(
      path: RouteNames.themeSettings,
      builder: (context, state) => const ThemeSettingsScreen(),
    ),
    GoRoute(
      path: RouteNames.privacy,
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      path: RouteNames.importExport,
      builder: (context, state) => const ImportExportScreen(),
    ),
    GoRoute(
      path: RouteNames.lockNotes,
      builder: (context, state) => const LockNotesScreen(),
    ),
    GoRoute(
      path: RouteNames.notificationSettings,
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
  ];
}
