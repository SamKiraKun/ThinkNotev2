# ThinkNote Privacy Policy

Effective date: 2026-05-26

ThinkNote is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our mobile application.

## Summary

ThinkNote is an offline-first notes application. It lets users create an account with Firebase Authentication, stores note data locally on the device for fast access, and syncs note data, folders, and tags to the ThinkNote backend when sync is enabled for the signed-in account.

## Data Stored On Your Device

ThinkNote stores notes, folders, tags, recent searches, and app preferences in the app's private local storage on your device.

ThinkNote encrypts note content and related local note fields before they are stored in the on-device database using a device-protected application secret. This is not the same as end-to-end encryption. Anyone with access to your unlocked device, a compromised device, or app-private storage through advanced tooling may still be able to access local data while the app is in use. Android cloud backup and device-transfer backup are disabled for ThinkNote app data. Use your device lock and operating-system security features to protect your notes.

## Data Collected And Processed

ThinkNote processes the following data for signed-in accounts:

- Firebase Authentication account identifiers such as user ID and email address.
- Optional profile display name and profile photo if provided by Firebase.
- Note content and metadata, including folders, tags, archive state, pin/favorite state, and delete/restore state.
- Technical request metadata needed to secure and operate the backend, such as authentication tokens, timestamps, and rate-limiting information.

ThinkNote does not include ads in this release. Analytics and crash reporting are not enabled in the current production path.

## Accounts And Cloud Sync

ThinkNote uses Firebase Authentication for sign-in. The app currently supports email and password authentication.

When sync is enabled, note data is sent over HTTPS to the ThinkNote backend, which verifies Firebase ID tokens and stores synced note data in the configured ThinkNote database.

ThinkNote keeps a device-local cache for the signed-in account so notes remain available offline and can sync when a connection returns.

## Imports, Exports, And Clipboard

Safer backup and restore flows using local file storage and clipboard import/export are supported only for local backup purposes and do not transmit data to our servers unless cloud sync is explicitly enabled.

## Deleting Data

Users can delete their ThinkNote account from the in-app Settings screen (under Profile). Account deletion permanently removes the ThinkNote backend account record and synced note data associated with that account.

Deleting the app from the device removes app-local data from that installation. Local cached data for a deleted account is cleared during the in-app delete-account flow.

## Third-Party Services

ThinkNote relies on the following service providers to run:

- **Firebase Authentication (Google LLC)**: For secure account sign-in.
- **Google Cloud Platform**: Hosting the backend database and API services.

All transmission of data to third-party services is secured using TLS encryption (HTTPS).

## Contact

If you have any questions or requests regarding this Privacy Policy or your data, please contact us at:

- **Email**: support@thinkmart.in
- **Website**: https://thinknote.app
