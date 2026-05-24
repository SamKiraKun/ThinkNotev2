# ThinkNote Flutter App

This workspace contains the ThinkNote Flutter client with Riverpod state management, `go_router` navigation, local SQLite persistence, and Android release configuration.

ThinkNote 1.0 now targets an authenticated offline-first notes release. The Flutter client initializes Firebase, supports email/password sign-in, keeps a per-account local SQLite cache with encrypted local note fields, and syncs notes, folders, and tags through the backend when `ENABLE_EXPERIMENTAL_SYNC=true`.

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
  --dart-define=ENABLE_EXPERIMENTAL_SYNC=true \
  --dart-define=API_URL=https://your-api.example.com \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```

## Runtime configuration

The Flutter client is configured entirely through compile-time `--dart-define` values.

- CI injects values from CircleCI project or context environment variables.
- Local development can pass values manually through `flutter run` or `flutter build`.
- The app does not bundle, read, or require a root `.env` file.
- Backend Admin config remains separate in `backend/.env`.

Supported client defines:

- `APP_FLAVOR`
- `API_URL` (required when authenticated sync is enabled)
- `FIREBASE_API_KEY` (required when authenticated sync is enabled)
- `FIREBASE_APP_ID` (required when authenticated sync is enabled)
- `FIREBASE_MESSAGING_SENDER_ID` (required when authenticated sync is enabled)
- `FIREBASE_PROJECT_ID` (required when authenticated sync is enabled)
- `FIREBASE_DATABASE_URL`
- `FIREBASE_STORAGE_BUCKET`
- `SENTRY_DSN`
- `ANALYTICS_KEY`
- `ENABLE_ANALYTICS`
- `ENABLE_EXPERIMENTAL_SYNC`

Example Android release build:

```bash
flutter build appbundle --release \
  --dart-define=APP_FLAVOR=production \
  --dart-define=ENABLE_EXPERIMENTAL_SYNC=true \
  --dart-define=API_URL=https://your-api.example.com \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=...
```

Sync-enabled builds must also pass Firebase client settings. Production sync builds must use an HTTPS `API_URL`.

CircleCI is the canonical Android release builder. It signs the release,
stores the Play AAB separately from the QA APK, and archives release metadata
including lockfiles, git SHA, Flutter/Gradle versions, and R8 mapping output.

Privacy and Play Data Safety drafts live in `PRIVACY_POLICY.md` and
`docs/play_store/sync_enabled_data_map.md`. They should be treated as the
working sync-enabled release documents until a hosted privacy policy and Play
Console submission are finalized.

## Verification

Run the analyzer and Flutter tests from the project root:

```bash
flutter analyze
flutter test
```
