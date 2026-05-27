# ThinkNote Sync-Enabled Data Map And Play Data Safety Notes

Audit date: 2026-05-24

This document is the working data inventory for the authenticated ThinkNote Android release path.

## Launch Mode

- Mode: authenticated sync-enabled v1
- Accounts: Firebase Authentication email/password
- Cloud sync: enabled through the ThinkNote backend
- Ads: none
- Analytics: none in the current production path
- Crash reporting: supported when `SENTRY_DSN` is configured for the build
- Android backup: disabled and data extraction excludes app data

## Data Inventory

| Data | Stored | Leaves Device | Notes |
| --- | --- | --- | --- |
| Firebase user ID and email | Firebase Auth and ThinkNote backend user record | Yes | Required for sign-in and account scoping. |
| Optional display name and avatar | Firebase Auth / backend user record | Yes | Only if supplied by Firebase. |
| Notes and note content | App-private encrypted SQLite cache and backend database | Yes | Local note fields are encrypted at rest and synced over HTTPS for signed-in users. |
| Folders and tags | App-private SQLite cache and backend database | Yes | Synced with note organization state. |
| Recent searches | App-private SQLite cache | No | Stays local for speed. |
| Theme and note display preferences | App-private SQLite cache / SharedPreferences | No | Device-local preferences in this release. |

## Play Data Safety Working Notes

- Data collection: yes, for account identity and synced note content.
- Data sharing: none beyond required service providers for authentication and backend hosting.
- User content: collected and transmitted for sync.
- Personal info: email address and Firebase account identifier are processed for authentication.
- App activity: not collected because analytics are not wired.
- Device or other IDs: Firebase account identifiers are processed for sign-in.
- Diagnostics: collected only in builds that configure `SENTRY_DSN` for Sentry crash reporting.
- Encryption in transit: yes, sync-enabled production builds require an HTTPS API URL.
- Data deletion: in-app account deletion is implemented. A hosted privacy policy and account-deletion web reference still need to be published before Play submission.

## Crash Reporting Decision

- The app now supports Sentry crash reporting through the `SENTRY_DSN` runtime define.
- Public rollout with crash reporting enabled still requires updated Play Data Safety and privacy disclosures that mention diagnostics collection.
- If `SENTRY_DSN` is omitted, diagnostics remain disabled and the release must carry an explicit approved exception in `docs/play_store/release_checklist.md`.

## Remaining Release Evidence

- Signed AAB built by CircleCI with the final production Firebase and API settings.
- CircleCI release metadata includes signed-artifact verification output and Flutter test logs.
- Flutter widget tests complete successfully on CI.
- Hosted privacy policy URL and support email are live.
- Play Console Data Safety answers are completed from this document.
- Play screenshots match the authenticated sync build.
- Crash reporting is either enabled with a real `SENTRY_DSN` and updated disclosures, or explicitly deferred in release notes and policy review.
