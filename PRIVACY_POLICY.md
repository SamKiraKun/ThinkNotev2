# ThinkNote Privacy Policy Draft

Effective date: 2026-05-24

This draft matches the current ThinkNote Android build path with Firebase Authentication and backend sync enabled. Replace placeholder support and hosting details before publishing it or using it in Play Console.

## Summary

ThinkNote is an offline-first notes app. It lets users create an account with Firebase Authentication, stores note data locally on the device for fast access, and syncs note data, folders, and tags to the ThinkNote backend for the signed-in account.

## Data Stored On Your Device

ThinkNote stores notes, folders, tags, recent searches, and app preferences in the app's private local storage on your device.

ThinkNote encrypts note content and related local note fields before they are stored in the on-device database by using a device-protected application secret. This is not the same as end-to-end encryption. Anyone with access to your unlocked device, a compromised device, or app-private storage through advanced tooling may still be able to access local data while the app is in use. Android cloud backup and device-transfer backup are disabled for ThinkNote app data. Use your device lock and operating-system security features to protect your notes.

## Data Collected And Processed

ThinkNote processes the following data for signed-in accounts:

- Firebase Authentication account identifiers such as user ID and email address.
- Optional profile display name and profile photo if provided by Firebase.
- Note content and metadata, including folders, tags, archive state, pin/favorite state, and delete/restore state.
- Technical request metadata needed to secure and operate the backend, such as authentication tokens, timestamps, and rate-limiting information.

ThinkNote does not include ads in this release. Analytics and crash reporting are not enabled in the current production path unless they are added and disclosed separately.

## Accounts And Cloud Sync

ThinkNote uses Firebase Authentication for sign-in. The app currently supports email and password authentication.

When sync is enabled, note data is sent over HTTPS to the ThinkNote backend, which verifies Firebase ID tokens and stores synced note data in the configured ThinkNote database.

ThinkNote keeps a device-local cache for the signed-in account so notes remain available offline and can sync when a connection returns.

## Imports, Exports, And Clipboard

Clipboard-based full-note import/export tools are not exposed in the production release path. Safer backup and restore flows should be documented here before they ship publicly.

## Deleting Data

Users can delete their ThinkNote account from the in-app Settings screen. Account deletion removes the ThinkNote backend account record and synced note data associated with that account.

Deleting the app from the device removes app-local data from that installation. Local cached data for a deleted account is cleared during the in-app delete-account flow.

## Third-Party Services

ThinkNote currently depends on:

- Firebase Authentication for account sign-in.
- Firebase Admin SDK on the backend to verify user identity.
- The configured ThinkNote backend database provider for synced note storage.

Before release, replace this section with the final processor and hosting names used in production.

## Contact

Before Play submission, replace this placeholder with the production support email and hosted privacy policy URL.
