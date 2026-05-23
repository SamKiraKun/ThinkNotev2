# ThinkNote Flutter App

This workspace contains the ThinkNote Flutter client with Riverpod state management, `go_router` navigation, secure token storage, and a production-ready auth flow built from design tokens.

## Run the app

1. Install Flutter for the stable 3.4+ SDK line.
2. Copy `.env.example` to `.env` in the project root and fill in the Firebase client values.
3. From the project root, fetch packages:

```bash
flutter pub get
```

4. Start the app:

```bash
flutter run
```

## Firebase env

The Android client reads Firebase config from the root `.env` file.

- Client config lives in `.env`
- Backend Admin config lives in `backend/.env`
- Keep both files out of git; only `.env.example` files are tracked

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
