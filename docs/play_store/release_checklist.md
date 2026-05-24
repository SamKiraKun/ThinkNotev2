# ThinkNote Play Release Checklist

Updated: 2026-05-24

This checklist covers the remaining release tasks that cannot be completed purely by editing repository code.

## CI And Release Artifact Gates

- Run CircleCI `build_android` with the real production signing secrets.
- Confirm the workflow artifacts include:
  - signed `app-release.aab`
  - signed `app-release.apk`
  - `release-manifest.json`
  - `aab-signature-verification.txt`
  - `flutter-test-output.txt`
- Install the signed QA APK on a device or emulator and verify:
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

- Current repository decision: crash reporting is still deferred.
- Public rollout requires one of these explicit outcomes:
  - add Sentry or Crashlytics and update privacy/Data Safety disclosures, or
  - document an approved exception for launching without crash reporting.

## Evidence Bundle

- `DEVELOPMENT_PLAN.md`
- `PRIVACY_POLICY.md`
- `docs/play_store/sync_enabled_data_map.md`
- CircleCI `release-metadata` artifact directory