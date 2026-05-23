import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppInitializer {
  const AppInitializer();

  Future<void> initializeFirebase() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    }
  }

  Future<SharedPreferences> initializePreferences() {
    return SharedPreferences.getInstance();
  }
}
