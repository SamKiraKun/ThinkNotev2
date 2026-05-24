# ThinkNote Local-Only Data Map And Play Data Safety Notes

Audit date: 2026-05-24

Status: superseded for the current launch path by `docs/play_store/sync_enabled_data_map.md`. Keep this file only as a reference for a future local-only variant.

This document is the working data inventory for a ThinkNote 1.0 local-only Android release. It is not valid for a sync-enabled release.

## Launch Mode

- Mode: local-only v1
- Accounts: no account creation or sign-in
- Cloud sync: disabled in production client
- Ads: none
- Analytics: none
- Crash reporting: none
- Client Firebase SDK: none
- Backend calls from production client: none
- Clipboard backup: not exposed in production UI
- Android backup: disabled and data extraction excludes app data

## Local Data Inventory

| Data | Stored | Leaves Device | Notes |
| --- | --- | --- | --- |
| Notes and note content | App-private encrypted SQLite database | No | Local note fields are encrypted at rest, but this is not end-to-end encryption. |
| Folders and tags | App-private SQLite database | No | Used for local organization. |
| Recent searches | App-private SQLite database | No | Device-local convenience data. |
| Theme and note display preferences | App-private SQLite database / SharedPreferences | No | Device-local settings. |
| Lock/reminder prototype preferences | SharedPreferences in non-production builds only | No | Production UI hides these tools. |

## Play Data Safety Draft For Local-Only V1

These are implementation notes for completing Play Console. Final answers must be verified against the built AAB and published privacy policy.

- Data collection: no off-device collection by the production local-only app.
- Data sharing: no sharing by the production local-only app.
- User content: stored locally on device; not collected by ThinkNote servers.
- Personal info: not collected because accounts are not available.
- App activity: not collected because analytics are not wired.
- Device or other IDs: not collected by ThinkNote app code.
- Diagnostics: not collected because crash reporting is not wired.
- Encryption in transit: not applicable to local-only app behavior because app data is not transmitted.
- Data deletion: users can delete local notes in app or remove app data/uninstall. No server account deletion applies because there are no accounts.

## Required Evidence Before Upload

- `flutter analyze` passes.
- `flutter test` passes.
- Signed AAB is built by CircleCI with `ENABLE_EXPERIMENTAL_SYNC=false`.
- Release metadata includes git SHA, lockfiles, build number, Flutter/Gradle versions, and R8 mapping.
- Merged release manifest confirms no unexpected dangerous permissions.
- Play screenshots and listing do not show cloud sync, account, lock/encryption, reminders, or clipboard backup claims.
- Hosted privacy policy URL matches `PRIVACY_POLICY.md`.

## Sync-Enabled Release Delta

If sync is enabled later, this data map must be replaced before release. Required additions include:

- Firebase Auth identifiers, email, display name, and avatar if used.
- Note content and metadata transmitted to backend/Turso/libSQL.
- Firebase Admin and hosting processor disclosures.
- Account deletion in app and web URL.
- Data retention and deletion timelines.
- Backend rate limits, payload limits, audit logging, and abuse response.
- Transport encryption evidence and privacy policy updates.
