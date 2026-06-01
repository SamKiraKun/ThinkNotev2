# ThinkNote Play Release Checklist

Updated: 2026-05-24

This checklist covers the remaining release tasks that cannot be completed purely by editing repository code.

## CI And Release Artifact Gates

- Run CircleCI `build_android` with the real production signing secrets.
- Use the same scripted release command locally when you need a comparable production-candidate artifact:
  - `APP_FLAVOR=production API_URL=https://api.unicef.edu.eu.org FIREBASE_API_KEY=... FIREBASE_APP_ID=... FIREBASE_MESSAGING_SENDER_ID=... FIREBASE_PROJECT_ID=... bash scripts/android/build_release_artifacts.sh`
- Windows local equivalent: `set "APP_FLAVOR=production" && set "API_URL=https://api.unicef.edu.eu.org" && set "FIREBASE_API_KEY=..." && set "FIREBASE_APP_ID=..." && set "FIREBASE_MESSAGING_SENDER_ID=..." && set "FIREBASE_PROJECT_ID=..." && scripts\android\build_release_artifacts.cmd`
- Verify locally produced artifacts with `bash scripts/android/verify_release_artifacts.sh` or `scripts\android\verify_release_artifacts.cmd`.
- Confirm the workflow artifacts include:
  - signed `app-release.aab`
  - signed `app-release.apk`
  - `release-manifest.json`
  - `aab-signature-verification.txt`
  - `flutter-analyze-machine.txt`
  - `flutter-test-output.txt`
- Confirm the workflow gates passed before promotion approval:
  - Flutter analyze
  - Flutter tests
  - backend build/test/audit
  - repository secret scan
- Install the signed QA APK on a device or emulator with `bash scripts/android/smoke_install_release.sh` or `scripts\android\smoke_install_release.cmd` and verify:
  - sign-in works
  - initial sync works
  - permanent deletion removes the item and it stays deleted after restart
  - account deletion still succeeds

## Play Console Gates

- Host the policy from `PRIVACY_POLICY.md` at a stable HTTPS URL.
- Set the production support email in the Play listing and privacy policy.
- Complete the Data Safety form using `docs/play_store/sync_enabled_data_map.md`.
- Upload the signed AAB to Internal testing.
- Review the Play pre-launch report and resolve any crashes, ANRs, or policy warnings.
- Capture final screenshots from the signed production-candidate build.
- Approve staged rollout only after internal testing sign-off.

## Crash Reporting Decision

- Repository state: optional Sentry bootstrap is wired behind `SENTRY_DSN`.
- Public rollout requires one of these explicit outcomes:
  - provide the production `SENTRY_DSN` in release builds and update privacy/Data Safety disclosures for diagnostics collection, or
  - leave `SENTRY_DSN` unset and document an approved exception for launching without crash reporting.

## Evidence Bundle

- `DEVELOPMENT_PLAN.md`
- `PRIVACY_POLICY.md`
- `docs/play_store/sync_enabled_data_map.md`
- CircleCI `release-metadata` artifact directory
