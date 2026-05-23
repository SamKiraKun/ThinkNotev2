import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseClientOptions {
  const FirebaseClientOptions._();

  static FirebaseOptions get android {
    return FirebaseOptions(
      apiKey: _required('FIREBASE_API_KEY'),
      appId: _required('FIREBASE_APP_ID'),
      messagingSenderId: _required('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: _required('FIREBASE_PROJECT_ID'),
      databaseURL: _optional('FIREBASE_DATABASE_URL'),
      storageBucket: _optional('FIREBASE_STORAGE_BUCKET'),
    );
  }

  static String _required(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required Firebase env var: $key');
    }

    return value;
  }

  static String? _optional(String key) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      return null;
    }

    return value;
  }
}
