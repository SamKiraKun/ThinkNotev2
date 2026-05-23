import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/storage/local_storage.dart';
import 'app_initializer.dart';

Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  const initializer = AppInitializer();
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
