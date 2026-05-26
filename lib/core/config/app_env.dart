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

  static const String _defaultDevelopmentApiUrl = 'https://api.unicefindia.edu.eu.org';

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: _defaultDevelopmentApiUrl,
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
  static const String firebaseDatabaseUrl = String.fromEnvironment(
    'FIREBASE_DATABASE_URL',
  );
  static const String firebaseStorageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
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

  static AppFlavor get appFlavor => AppFlavor.parse(_appFlavorValue);

  static bool get isDevelopment => appFlavor == AppFlavor.development;
  static bool get isStaging => appFlavor == AppFlavor.staging;
  static bool get isProduction => appFlavor == AppFlavor.production;
  static bool get showPrototypeTools => !isProduction;

  static Uri get apiUri => Uri.parse(apiUrl);
  static String? get sentryDsnOrNull => _nonEmptyOrNull(sentryDsn);
  static String? get analyticsKeyOrNull => _nonEmptyOrNull(analyticsKey);

  static void validateBase() {
    final flavor = appFlavor;

    if (!enableExperimentalSync) {
      return;
    }

    _requireNonEmpty('FIREBASE_API_KEY', firebaseApiKey);
    _requireNonEmpty('FIREBASE_APP_ID', firebaseAppId);
    _requireNonEmpty(
      'FIREBASE_MESSAGING_SENDER_ID',
      firebaseMessagingSenderId,
    );
    _requireNonEmpty('FIREBASE_PROJECT_ID', firebaseProjectId);

    if (flavor != AppFlavor.development) {
      _requireNonEmpty('API_URL', apiUrl);
      if (apiUrl == _defaultDevelopmentApiUrl) {
        throw StateError(
          'API_URL must be set explicitly when experimental sync is enabled outside development.',
        );
      }
    }

    final parsedApiUri = Uri.tryParse(apiUrl);
    if (parsedApiUri == null ||
        parsedApiUri.scheme.isEmpty ||
        parsedApiUri.host.isEmpty) {
      throw StateError(
        'API_URL must be a valid absolute URL when experimental sync is enabled.',
      );
    }

    if (flavor == AppFlavor.production && parsedApiUri.scheme != 'https') {
      throw StateError(
        'Production API_URL must use HTTPS when experimental sync is enabled.',
      );
    }
  }

  static void validateAndroid() {
    validateBase();
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
