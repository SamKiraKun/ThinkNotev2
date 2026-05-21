import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/notes/data/models/app_preferences_model.dart';
import 'features/notes/presentation/controllers/notes_controller.dart';

class ThinkNoteApp extends ConsumerWidget {
  const ThinkNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(appRouterProvider);
    final themeMode = ref
            .watch(notesControllerProvider)
            .valueOrNull
            ?.preferences
            .themePreference
            .themeMode ??
        ThemeMode.system;

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: goRouter,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(
              maxScaleFactor: AppConstants.maxSupportedTextScale,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
