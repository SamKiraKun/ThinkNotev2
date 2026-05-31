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

  static const String _defaultDevelopmentApiUrl =
      'https://api.unicef.edu.eu.org';
  static const String _retiredApiHost = 'api.unicefindia.edu.eu.org';

  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: _defaultDevelopmentApiUrl,
  );
  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
  );
  static const String firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const String firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
  );
  static const String firebaseWebAppId = String.fromEnvironment(
    'FIREBASE_WEB_APP_ID',
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
  static const String firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const String firebaseMeasurementId = String.fromEnvironment(
    'FIREBASE_MEASUREMENT_ID',
  );
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const String analyticsKey = String.fromEnvironment('ANALYTICS_KEY');
  static const bool enableAnalytics = bool.fromEnvironment(
    'ENABLE_ANALYTICS',
    defaultValue: false,
  );

  static bool get enableExperimentalSync => true;

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
  static String get resolvedFirebaseAndroidAppId =>
      _firstNonEmpty(firebaseAndroidAppId, firebaseAppId);
  static String get resolvedFirebaseIosAppId =>
      _firstNonEmpty(firebaseIosAppId, firebaseAppId);
  static String get resolvedFirebaseWebAppId =>
      _firstNonEmpty(firebaseWebAppId, firebaseAppId);
  static String? get sentryDsnOrNull => _nonEmptyOrNull(sentryDsn);
  static String? get analyticsKeyOrNull => _nonEmptyOrNull(analyticsKey);
  static String? get firebaseAuthDomainOrNull =>
      _nonEmptyOrNull(firebaseAuthDomain);
  static String? get firebaseMeasurementIdOrNull =>
      _nonEmptyOrNull(firebaseMeasurementId);

  static void validateBase() {
    final flavor = appFlavor;
    final parsedApiUri = Uri.tryParse(apiUrl);

    if (parsedApiUri == null ||
        parsedApiUri.scheme.isEmpty ||
        parsedApiUri.host.isEmpty) {
      throw StateError(
        'API_URL must be a valid absolute URL.',
      );
    }

    if (_isRetiredApiHost(parsedApiUri)) {
      throw StateError(
        'API_URL points to a retired ThinkNote backend host. Update API_URL to https://api.unicef.edu.eu.org or another active API deployment before launching the app.',
      );
    }

    if (flavor == AppFlavor.production) {
      if (parsedApiUri.scheme != 'https') {
        throw StateError('Production API_URL must use HTTPS.');
      }
    }

    _requireNonEmpty('FIREBASE_API_KEY', firebaseApiKey);
    _requireNonEmpty(
      'FIREBASE_MESSAGING_SENDER_ID',
      firebaseMessagingSenderId,
    );
    _requireNonEmpty('FIREBASE_PROJECT_ID', firebaseProjectId);
    _requireNonEmpty(
      'FIREBASE_APP_ID or a platform-specific FIREBASE_*_APP_ID',
      _firstNonEmpty(
        firebaseAndroidAppId,
        firebaseIosAppId,
        firebaseWebAppId,
        firebaseAppId,
      ),
    );

    if (flavor != AppFlavor.development) {
      _requireNonEmpty('API_URL', apiUrl);
    }

    if (flavor == AppFlavor.production && parsedApiUri.scheme != 'https') {
      throw StateError('Production API_URL must use HTTPS.');
    }
  }

  static void validateAndroid() {
    validateBase();
    _requireNonEmpty(
      'FIREBASE_ANDROID_APP_ID or FIREBASE_APP_ID',
      resolvedFirebaseAndroidAppId,
    );
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

  static String _firstNonEmpty(String first, String second,
      [String? third, String? fourth]) {
    final values = <String>[first, second];
    if (third != null) {
      values.add(third);
    }
    if (fourth != null) {
      values.add(fourth);
    }

    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return '';
  }

  static bool _isRetiredApiHost(Uri apiUri) {
    return apiUri.host.toLowerCase() == _retiredApiHost;
  }
}
