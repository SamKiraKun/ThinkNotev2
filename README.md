# ThinkNote Flutter App

This workspace contains the ThinkNote Flutter client with Riverpod state management, `go_router` navigation, secure token storage, and a production-ready auth flow built from design tokens.

## Run the app

1. Install Flutter for the stable 3.4+ SDK line.
2. From the project root, fetch packages:

```bash
flutter pub get
```

3. Start the app with your API base URL:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## Auth endpoint configuration

The auth client reads its base URL from `API_BASE_URL`.

- Sign in: `POST /auth/sign-in`
- Google: `POST /auth/social/google`
- Apple: `POST /auth/social/apple`
- Microsoft: `POST /auth/social/microsoft`
- Forgot password: `POST /auth/forgot-password`
- Current user: `GET /auth/me`

Social auth is intentionally gated behind:

```bash
--dart-define=ENABLE_SOCIAL_AUTH=true
```

If that flag is not enabled, the UI stays real but the repository returns a controlled "coming soon" error instead of faking success.

## Social credentials

Do not place OAuth secrets, backend tokens, or service credentials in Dart source.

- Put mobile or web client IDs in the platform-specific configuration expected by each provider.
- Keep provider secrets on the backend only.
- Wire provider callback handling to the backend endpoints above before enabling `ENABLE_SOCIAL_AUTH=true`.

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
