import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_env.dart';

class FirebaseClientOptions {
  const FirebaseClientOptions._();

  static FirebaseOptions get current {
    if (kIsWeb) {
      return web;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => ios,
      TargetPlatform.android => android,
      _ => android,
    };
  }

  static FirebaseOptions get android {
    return _buildOptions(appId: AppEnv.resolvedFirebaseAndroidAppId);
  }

  static FirebaseOptions get ios {
    return _buildOptions(appId: AppEnv.resolvedFirebaseIosAppId);
  }

  static FirebaseOptions get web {
    return _buildOptions(
      appId: AppEnv.resolvedFirebaseWebAppId,
      authDomain: AppEnv.firebaseAuthDomainOrNull,
      measurementId: AppEnv.firebaseMeasurementIdOrNull,
    );
  }

  static FirebaseOptions _buildOptions({
    required String appId,
    String? authDomain,
    String? measurementId,
  }) {
    return FirebaseOptions(
      apiKey: AppEnv.firebaseApiKey,
      appId: appId,
      messagingSenderId: AppEnv.firebaseMessagingSenderId,
      projectId: AppEnv.firebaseProjectId,
      databaseURL: AppEnv.firebaseDatabaseUrl.isEmpty
          ? null
          : AppEnv.firebaseDatabaseUrl,
      storageBucket: AppEnv.firebaseStorageBucket.isEmpty
          ? null
          : AppEnv.firebaseStorageBucket,
      authDomain: authDomain,
      measurementId: measurementId,
    );
  }
}
