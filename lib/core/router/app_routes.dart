import 'package:go_router/go_router.dart';

import '../../features/notes/presentation/screens/note_editor_screen.dart';
import '../../features/notes/presentation/screens/trash_screen.dart';
import '../../features/shell/presentation/screens/main_shell_screen.dart';
import '../constants/route_names.dart';

List<RouteBase> buildAppRoutes() {
  return <RouteBase>[
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
  ];
}
