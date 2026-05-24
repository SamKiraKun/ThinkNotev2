import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_env.dart';
import '../core/config/firebase_client_options.dart';

class AppInitializer {
  const AppInitializer();

  void validateEnvironment() {
    AppEnv.validateBase();

    if (defaultTargetPlatform == TargetPlatform.android) {
      AppEnv.validateAndroid();
    }
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
