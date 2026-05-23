import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/firebase_client_options.dart';

class AppInitializer {
  const AppInitializer();

  Future<void> initializeEnvironment() {
    return dotenv.load(fileName: '.env');
  }

  Future<void> initializeFirebase() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await Firebase.initializeApp(
      options: FirebaseClientOptions.android,
    );
  }

  Future<SharedPreferences> initializePreferences() {
    return SharedPreferences.getInstance();
  }
}
