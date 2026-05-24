import 'package:firebase_core/firebase_core.dart';

import 'app_env.dart';

class FirebaseClientOptions {
  const FirebaseClientOptions._();

  static FirebaseOptions get android {
    return FirebaseOptions(
      apiKey: AppEnv.firebaseApiKey,
      appId: AppEnv.firebaseAppId,
      messagingSenderId: AppEnv.firebaseMessagingSenderId,
      projectId: AppEnv.firebaseProjectId,
      databaseURL: AppEnv.firebaseDatabaseUrl,
      storageBucket: AppEnv.firebaseStorageBucket,
    );
  }
}
