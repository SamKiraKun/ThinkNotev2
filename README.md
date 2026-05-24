# ThinkNote Flutter App

This workspace contains the ThinkNote Flutter client with Riverpod state management, `go_router` navigation, secure token storage, and a production-ready auth flow built from design tokens.

## Run the app

1. Install Flutter for the stable 3.4+ SDK line.
2. Export the runtime values you want to use for the current shell session. The Flutter app reads compile-time values from `--dart-define`; it does not load a `.env` asset file.
3. From the project root, fetch packages:

```bash
flutter pub get
```

4. Start the app:

```bash
flutter run \
  --dart-define=APP_FLAVOR=development \
  --dart-define=API_URL=http://10.0.2.2:3000 \
  --dart-define=FIREBASE_API_KEY=your-firebase-api-key \
  --dart-define=FIREBASE_APP_ID=your-firebase-app-id \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-messaging-sender-id \
  --dart-define=FIREBASE_PROJECT_ID=your-firebase-project-id \
  --dart-define=FIREBASE_DATABASE_URL=your-database-url \
  --dart-define=FIREBASE_STORAGE_BUCKET=your-storage-bucket
```

## Runtime configuration

The Flutter client is configured entirely through compile-time `--dart-define` values.

- CI injects values from CircleCI project or context environment variables.
- Local development can pass values manually through `flutter run` or `flutter build`.
- The app does not bundle, read, or require a root `.env` file.
- Backend Admin config remains separate in `backend/.env`.

Supported client defines:

- `APP_FLAVOR`
- `API_URL`
- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_DATABASE_URL`
- `FIREBASE_STORAGE_BUCKET`
- `SENTRY_DSN`
- `ANALYTICS_KEY`
- `ENABLE_ANALYTICS`
- `ENABLE_EXPERIMENTAL_SYNC`

Example Android release build:

```bash
flutter build appbundle --release \
  --dart-define=APP_FLAVOR=staging \
  --dart-define=API_URL=https://staging-api.example.com \
  --dart-define=FIREBASE_API_KEY=your-firebase-api-key \
  --dart-define=FIREBASE_APP_ID=your-firebase-app-id \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-messaging-sender-id \
  --dart-define=FIREBASE_PROJECT_ID=your-firebase-project-id
```

## Illustration assets

The sign-in and create-account screens look for these optional assets:

- `assets/images/auth/sign_in_mountain.png`
- `assets/images/auth/create_account_mountain.png`

If either asset is missing, the app falls back to the built-in `MountainIllustrationPainter`, so the auth flow still renders correctly. Replace those files when you have final illustration exports.

## Verification

Run the analyzer and the auth-focused tests from the project root:

```bash
flutter analyze
flutter test test/widget/sign_in_screen_test.dart test/widget/sign_in_form_card_test.dart test/widget/social_auth_row_test.dart test/widget/app_gradient_button_test.dart test/unit/sign_in_controller_test.dart test/unit/validators_test.dart
```
