import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/responsive_centered_shell.dart';
import '../../../../core/constants/route_names.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../folders/presentation/screens/folders_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../search/presentation/screens/search_screen.dart';
import '../controllers/shell_controller.dart';
import '../widgets/main_bottom_nav.dart';

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(shellTabProvider);
    final palette = context.palette;

    return ResponsiveCenteredShell(
      usePresentationFrame: true,
      child: Scaffold(
        backgroundColor: palette.pageBackground,
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(
                index: activeTab.index,
                children: const [
                  HomeScreen(),
                  SearchScreen(),
                  FoldersScreen(),
                  ProfileScreen(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MainBottomNav(
                activeTab: activeTab,
                onTabSelected: (tab) =>
                    ref.read(shellTabProvider.notifier).state = tab,
                onCreateTap: () {
                  context.push(RouteNames.editor);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
