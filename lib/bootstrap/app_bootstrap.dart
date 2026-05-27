import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../app.dart';
import '../core/config/app_env.dart';
import '../core/storage/local_storage.dart';
import 'app_initializer.dart';

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sentryDsn = AppEnv.sentryDsnOrNull;
  if (sentryDsn == null) {
    await _runThinkNoteApp();
    return;
  }

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.environment = AppEnv.appFlavor.name;
      options.sendDefaultPii = false;
      options.beforeBreadcrumb = (breadcrumb, hint) {
        return breadcrumb?.copyWith(data: null);
      };
      options.beforeSend = (event, hint) {
        return event.copyWith(
          user: null,
          request: null,
        );
      };
    },
    appRunner: _runThinkNoteApp,
  );
}

Future<void> _runThinkNoteApp() async {
  const initializer = AppInitializer();
  initializer.validateEnvironment();
  await initializer.initializeFirebase();
  final prefs = await initializer.initializePreferences();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ThinkNoteApp(),
    ),
  );
}
