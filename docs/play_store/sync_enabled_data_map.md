# ThinkNote Sync-Enabled Data Map And Play Data Safety Notes

Audit date: 2026-05-24

This document is the working data inventory for the authenticated ThinkNote Android release path.

## Launch Mode

- Mode: authenticated sync-enabled v1
- Accounts: Firebase Authentication email/password
- Cloud sync: enabled through the ThinkNote backend
- Ads: none
- Analytics: none in the current production path
- Crash reporting: not yet enabled
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
- Diagnostics: not collected because crash reporting is not wired.
- Encryption in transit: yes, sync-enabled production builds require an HTTPS API URL.
- Data deletion: in-app account deletion is implemented. A hosted privacy policy and account-deletion web reference still need to be published before Play submission.

## Crash Reporting Decision

- Crash reporting is intentionally not enabled in the current authenticated sync build.
- This is a documented release exception, not an assumption that crash reporting is unnecessary.
- Before public rollout, either add Crashlytics/Sentry with updated disclosures or record explicit approval to launch without crash reporting in `docs/play_store/release_checklist.md`.

## Remaining Release Evidence

- Signed AAB built by CircleCI with the final production Firebase and API settings.
- CircleCI release metadata includes signed-artifact verification output and Flutter test logs.
- Flutter widget tests complete successfully on CI.
- Hosted privacy policy URL and support email are live.
- Play Console Data Safety answers are completed from this document.
- Play screenshots match the authenticated sync build.
- Crash reporting is either added or explicitly deferred in release notes and policy review.
