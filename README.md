# ThinkNote Flutter App

This workspace contains the ThinkNote Flutter client with Riverpod state management, `go_router` navigation, local SQLite persistence, and Android release configuration.

ThinkNote now targets a mandatory-authentication notes release. The Flutter client initializes Firebase on supported platforms, requires email/password sign-in before the user can access the app shell, keeps a per-account local cache, and syncs notes, folders, and tags through the backend API at `https://api.unicef.edu.eu.org` unless `API_URL` is overridden.

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
  --dart-define=API_URL=https://your-api.example.com \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
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
- `API_URL` (required outside development and must be HTTPS in production)
- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID` (generic fallback app id)
- `FIREBASE_ANDROID_APP_ID`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_WEB_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_DATABASE_URL`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_AUTH_DOMAIN` (web)
- `FIREBASE_MEASUREMENT_ID` (web)
- `SENTRY_DSN`
- `ANALYTICS_KEY`
- `ENABLE_ANALYTICS`

Canonical Android release build from a Bash-compatible shell:

```bash
APP_FLAVOR=production \
API_URL=https://your-api.example.com \
FIREBASE_API_KEY=... \
FIREBASE_ANDROID_APP_ID=... \
FIREBASE_MESSAGING_SENDER_ID=... \
FIREBASE_PROJECT_ID=... \
bash scripts/android/build_release_artifacts.sh
```

Canonical Android release build from Windows Command Prompt or PowerShell:

```bat
set "APP_FLAVOR=production"
set "API_URL=https://your-api.example.com"
set "FIREBASE_API_KEY=..."
set "FIREBASE_ANDROID_APP_ID=..."
set "FIREBASE_MESSAGING_SENDER_ID=..."
set "FIREBASE_PROJECT_ID=..."
scripts\android\build_release_artifacts.cmd
```

Authenticated builds must pass Firebase client settings. Production builds must use an HTTPS `API_URL`.

CircleCI is the canonical Android release builder. It signs the release,
stores the Play AAB separately from the QA APK, and archives release metadata
including lockfiles, git SHA, Flutter/Gradle versions, and R8 mapping output.

To verify and smoke-install the produced release artifacts on a connected device or emulator:

```bash
bash scripts/android/verify_release_artifacts.sh
bash scripts/android/smoke_install_release.sh
```

On Windows without Bash available:

```bat
scripts\android\verify_release_artifacts.cmd
scripts\android\smoke_install_release.cmd
```

Privacy and Play Data Safety drafts live in `PRIVACY_POLICY.md` and
`docs/play_store/sync_enabled_data_map.md`. They should be treated as the
working sync-enabled release documents until a hosted privacy policy and Play
Console submission are finalized.

## Verification

Run the analyzer and Flutter tests from the project root:

```bash
flutter analyze --no-pub
flutter test --reporter expanded
```
