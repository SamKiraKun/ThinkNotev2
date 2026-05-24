enum AppFlavor {
  development,
  staging,
  production;

  static AppFlavor parse(String value) {
    return switch (value.trim().toLowerCase()) {
      'development' => AppFlavor.development,
      'staging' => AppFlavor.staging,
      'production' => AppFlavor.production,
      _ => throw StateError(
          'Unsupported APP_FLAVOR "$value". Expected development, staging, or production.',
        ),
    };
  }
}

final class AppEnv {
  AppEnv._();

  static const String _defaultDevelopmentApiUrl = 'http://10.0.2.2:3000';

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: _defaultDevelopmentApiUrl,
  );
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String analyticsKey = String.fromEnvironment('ANALYTICS_KEY');
  static const bool enableAnalytics = bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: false,
  );
  static const bool enableExperimentalSync = bool.fromEnvironment(
    'ENABLE_EXPERIMENTAL_SYNC',
    defaultValue: false,
  );

  static const String _appFlavorValue = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: 'development',
  );

  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String firebaseAppId = String.fromEnvironment(
    'FIREBASE_APP_ID',
  );
  static const String firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String _firebaseDatabaseUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
  );
  static const String _firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  static AppFlavor get appFlavor => AppFlavor.parse(_appFlavorValue);

  static bool get isDevelopment => appFlavor == AppFlavor.development;
  static bool get isStaging => appFlavor == AppFlavor.staging;
  static bool get isProduction => appFlavor == AppFlavor.production;

  static Uri get apiUri => Uri.parse(apiUrl);
  static String? get firebaseDatabaseUrl => _nonEmptyOrNull(
        _firebaseDatabaseUrl,
      );
  static String? get firebaseStorageBucket => _nonEmptyOrNull(
        _firebaseStorageBucket,
      );
  static String? get sentryDsnOrNull => _nonEmptyOrNull(sentryDsn);
  static String? get analyticsKeyOrNull => _nonEmptyOrNull(analyticsKey);

  static void validateBase() {
    final flavor = appFlavor;

    if (flavor != AppFlavor.development) {
      _requireNonEmpty('API_URL', apiUrl);
    }
  }

  static void validateAndroid() {
    validateBase();
    _requireNonEmpty('FIREBASE_API_KEY', firebaseApiKey);
    _requireNonEmpty('FIREBASE_APP_ID', firebaseAppId);
    _requireNonEmpty(
      'FIREBASE_MESSAGING_SENDER_ID',
      firebaseMessagingSenderId,
    );
    _requireNonEmpty('FIREBASE_PROJECT_ID', firebaseProjectId);
  }

  static void _requireNonEmpty(String key, String value) {
    if (value.trim().isEmpty) {
      throw StateError('Missing required --dart-define value for $key.');
    }
  }

  static String? _nonEmptyOrNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }
}
