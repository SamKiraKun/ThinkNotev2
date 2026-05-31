import 'package:flutter/material.dart';
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
        if (breadcrumb != null) {
          breadcrumb.data = null;
        }
        return breadcrumb;
      };
      options.beforeSend = (event, hint) {
        event.user = null;
        event.request = null;
        return event;
      };
    },
    appRunner: _runThinkNoteApp,
  );
}

Future<void> _runThinkNoteApp() async {
  try {
    const initializer = AppInitializer();
    initializer.validateEnvironment();

    if (AppEnv.usesRetiredApiHost) {
      debugPrint(
        '[ThinkNote bootstrap] API_URL uses retired host ${AppEnv.apiUrl}; routing requests to ${AppEnv.apiUri}.',
      );
    }

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
  } catch (error, stackTrace) {
    debugPrint(
      '[ThinkNote bootstrap] startup failed with ${error.runtimeType}: $error',
    );
    debugPrintStack(stackTrace: stackTrace);

    runApp(
      _BootstrapFailureApp(
        message: _describeBootstrapFailure(error),
      ),
    );
  }
}

String _describeBootstrapFailure(Object error) {
  if (error is StateError) {
    return error.message?.toString() ?? error.toString();
  }

  return error.toString().replaceFirst('Exception: ', '');
}

class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 32,
                          color: Color(0xFFFFB4AB),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'ThinkNote could not finish startup.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Color(0xFFD0D7DE),
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Restart the app after updating the backend or runtime configuration.',
                          style: TextStyle(
                            color: Color(0xFF8B949E),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
