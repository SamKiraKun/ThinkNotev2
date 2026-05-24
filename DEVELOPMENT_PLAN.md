# ThinkNote Development Plan

## Implementation Status Update - 2026-05-24

### Completed in code

- Firebase client bootstrap restored behind compile-time sync defines.
- Firebase Authentication email/password sign-in and auth-gated routing added to the Flutter app.
- Per-account local SQLite cache selection added so authenticated users do not share one device database file.
- Local note fields are encrypted at rest before being written to the device database.
- Token-authenticated sync controller added to the Flutter client.
- Automatic sync bootstrap now runs on app launch for returning sessions, on sign-in, when the app resumes, and on a periodic in-app refresh cadence.
- Connectivity-restored sync now runs while the app is foregrounded.
- Permanent note deletion, folder deletion, and tag deletion now persist durable delete operations locally and sync backend tombstones so deleted data cannot be resurrected by another device.
- Sync retry backoff is now persisted in local sync state so repeated failures do not hammer the backend and retries survive app restarts.
- Backend `/sync` now accepts folders, tags, and note tag membership in addition to notes.
- Backend `/sync` now accepts delete markers, returns deletion tombstones on pull, and rejects stale upserts for deleted entities.
- Backend `/account` deletion route added and wired to in-app account deletion.
- Backend request logging now emits request IDs and authenticated user context.
- CircleCI now captures Flutter test logs, verifies the signed AAB structure/signature, and writes release metadata without CircleCI-unsafe heredocs.
- Privacy and release documentation pivoted from local-only drafts to sync-enabled drafts.

### Still required before Play release

- A green CircleCI run with the real production signing and runtime secrets.
- Device smoke install from the signed release artifact.
- Hosted privacy policy URL and production support email.
- Play Data Safety submission using the sync-enabled data map.
- Final Play screenshots and listing assets captured from the signed build.
- Internal testing upload, pre-launch report review, and rollout approval.
- Crash reporting must either be added before public rollout or remain an explicit documented release sign-off exception.

## Recommended Online Stack

### Final recommendation

- Auth: Firebase Authentication
- Online data store: Turso (libSQL)
- API/backend: existing Node.js + Express backend in `backend/`
- Local offline database: Drift for Flutter
- File storage later: Firebase Storage
- Push notifications later: Firebase Cloud Messaging

### Why this stack

This is the best fit for the current repository.

- The backend already uses Turso in `backend/src/db/turso_client.ts`.
- The schema in `backend/src/db/schema.sql` is relational, which fits Turso much better than moving everything to a document database.
- Firebase Auth is fast to ship on Flutter and easy to combine with a custom backend.
- Turso has a usable free tier for MVP-scale notes data.
- The app can stay offline-first while syncing through a lightweight backend.

### What to avoid for now

- Do not move to Firestore unless you are willing to redesign the backend and data model.
- Do not keep `SharedPreferences` as the long-term notes database.
- Do not build shared collaborative workspaces in v1.

## Product Direction

### V1 scope

V1 should be a personal offline-first notes app with:

- Firebase login
- Sync across devices for the same user
- Notes, folders, tags, pin, favorite, trash, archive
- Search from local data
- Theme settings
- Import/export

### V2 scope

After V1 is stable:

- Attachments
- Reminders and notifications
- Note locking
- Better import/export
- Shared workspaces or collaboration

## Architecture Plan

### Client

- Flutter app remains the main client.
- Replace notes storage from `SharedPreferences` with Drift.
- Keep local-first writes.
- Sync through backend APIs after local persistence succeeds.

### Auth

- Use Firebase Auth on the client.
- Send Firebase ID token to the backend.
- Backend verifies token using Firebase Admin SDK.
- Use Firebase UID as the canonical `users.id`.

### Backend

- Keep Express backend.
- Remove mock auth from `backend/src/server.ts`.
- Add auth middleware.
- Add user bootstrap/upsert on first authenticated request.
- Expand notes endpoints into a real sync API.

### Data model

For V1 keep personal workspaces only.

- One user owns many notes
- One user owns many folders
- One user owns many tags

Do not add shared workspace complexity yet.

## Phase-by-Phase Roadmap

## Phase 0: Foundations

### Goal

Freeze the direction before more feature work.

### Tasks

- Confirm V1 is single-user sync, not team collaboration.
- Confirm Firebase Auth providers for launch:
  - Email/password
  - Google
- Keep Apple sign-in optional unless iOS launch requires it immediately.
- Keep Turso as the cloud notes database.
- Keep the backend as the only data access layer.

### Deliverables

- Final architecture decision documented
- Firebase project created
- Turso database created
- Environment variable list prepared for app and backend

## Phase 1: Authentication

### Goal

Ship real account login and session persistence.

### Tasks

- Add `firebase_core` and `firebase_auth` to Flutter.
- Configure Android app for Firebase.
- Configure iOS app for Firebase.
- Build auth flow screens and routing:
  - Splash/auth gate
  - Sign in
  - Sign up
  - Sign out
  - Session restore
- Add provider/repository layer for auth state.
- Store only what is necessary locally.
- Remove local-only product copy where it is no longer correct.

### Backend tasks

- Add Firebase Admin SDK.
- Verify Firebase ID tokens.
- Replace mock user injection in `backend/src/server.ts`.
- Upsert the user row in Turso on first verified request.

### Acceptance criteria

- User can sign up
- User can sign in
- User remains signed in after app restart
- User can sign out
- Backend rejects unauthenticated requests
- Backend scopes all notes data by authenticated user

## Phase 2: Local Data Layer Upgrade

### Goal

Replace the current local notes blob with a real local database.

### Current problem

The current notes store is persisted as one JSON blob in `SharedPreferences`.
That is not strong enough for:

- sync queues
- migrations
- conflict handling
- large data sets
- attachments metadata

### Tasks

- Add Drift to Flutter.
- Create local tables for:
  - notes
  - folders
  - tags
  - note_tags
  - sync_queue
  - sync_state
- Add fields for sync lifecycle:
  - `remote_id`
  - `updated_at`
  - `deleted_at`
  - `is_deleted`
  - `sync_status`
  - `last_synced_at`
- Write one-time migration from `SharedPreferences` store into Drift.
- Switch repository reads/writes to Drift.

### Acceptance criteria

- Existing local users keep their notes after upgrade
- App works offline with no data loss
- Large note collections remain responsive

## Phase 3: Sync Engine

### Goal

Make the app offline-first with reliable cloud sync.

### Sync strategy

Use local-first writes.

1. User edits note
2. Save immediately to Drift
3. Enqueue mutation for sync
4. Background sync pushes queued changes
5. Pull server changes and merge locally

### Backend tasks

- Add sync endpoints such as:
  - `GET /sync/pull?since=...`
  - `POST /sync/push`
- Support notes, folders, tags, and trash/archive state.
- Return server timestamps and revision metadata.
- Enforce per-user ownership.

### Client tasks

- Create sync service and queue processor.
- Run sync:
  - on app launch [done]
  - on sign-in [done]
  - on app resume/background restore [done]
  - after connectivity is restored [done]
  - periodically while app is open [done]
- Track sync failures and retries. [done: durable retry backoff state now persists locally]
- Expose sync state in UI later if needed.

### Conflict strategy for V1

- Use last-write-wins by `updated_at`
- If a conflict is risky, preserve a backup copy instead of silently dropping content

### Acceptance criteria

- Note created on device A appears on device B
- Edits sync both ways
- Delete, restore, archive, pin, favorite all sync correctly
- Offline edits sync correctly when connectivity returns

### Current gap after this pass

- The remaining blockers are operational release tasks, not the core sync contract.

## Phase 4: Core Notes Feature Completion

### Goal

Finish the note management features already implied by the repo.

### Tasks

- Implement archive feature end to end
- Build archived notes screen
- Ensure trash and archive are separate states with clear rules
- Add note detail polish where needed
- Make tags and folders fully editable
- Ensure note state transitions are consistent:
  - active
  - pinned
  - favorite
  - archived
  - trashed

### Acceptance criteria

- Archived notes screen exists and works
- Notes can move between active, archive, and trash cleanly
- All state changes sync to cloud and persist locally

## Phase 5: Routing and Guards

### Goal

Make navigation production-ready.

### Current gap

The router is minimal and `route_guards.dart` is empty.

### Tasks

- Add auth-aware route guards
- Add separate routes for:
  - login
  - signup
  - auth gate
  - archive
  - import/export
  - lock notes
  - notifications settings
  - theme settings
- Block authenticated-only screens when logged out
- Redirect correctly after sign-in/sign-out

### Acceptance criteria

- App always lands on the correct screen based on auth state
- Protected routes cannot be opened without authentication
- Navigation works from cold start and background restore

## Phase 6: Settings and Utility Screens

### Goal

Implement the currently empty settings-related screens.

### Screens to build

- `theme_settings_screen.dart`
- `import_export_screen.dart`
- `lock_notes_screen.dart`
- `notification_settings_screen.dart`

### Implementation order

#### 1. Theme settings

- Move current modal-based theme controls into a full screen if desired
- Keep preferences stored locally
- Sync only if you want cross-device settings later

#### 2. Import/export

- Start with JSON export
- Then add JSON import with validation
- Optionally add Markdown export later

#### 3. Lock notes

- Add app lock or protected-note access
- Use local biometrics/passcode first
- Do not delay V1 sync for encryption design

#### 4. Notification settings

- Local reminder notifications first
- Cloud push notifications later

### Acceptance criteria

- All currently empty settings screens have real UI and logic
- Each screen is reachable through routing

## Phase 7: Search and UX Refinement

### Goal

Keep the app fast and polished as data becomes cloud-backed.

### Tasks

- Keep search local against Drift
- Do not query the server for every search keystroke
- Improve empty states and error states
- Add better sync status feedback:
  - synced
  - syncing
  - offline changes pending
  - failed sync
- Add note action menus where callbacks are currently empty

### Acceptance criteria

- Search remains instant with large local data sets
- Users can tell whether data is synced or pending

## Phase 8: Attachments

### Goal

Add images and file attachments after note sync is stable.

### Tasks

- Use Firebase Storage for file blobs
- Keep only metadata in Turso
- Add local attachment cache
- Compress images before upload
- Add cleanup rules for deleted notes and files

### Acceptance criteria

- Users can attach images/files to notes
- Metadata sync is reliable
- Deleting a note cleans up attachment references

## Phase 9: Notifications

### Goal

Add reminders first, push later.

### Tasks

- Add local scheduled reminders for notes
- Add per-note reminder metadata
- Sync reminder metadata to the backend
- Add FCM only after the local reminder flow is stable

### Acceptance criteria

- Reminder can be created, edited, deleted
- Reminder survives app restarts
- Reminder metadata syncs across devices

## Phase 10: QA, Security, and Release Hardening

### Goal

Prepare the app for real users.

### Tasks

- Add unit tests for:
  - auth repositories
  - token verification paths
  - sync merge logic
  - conflict handling
  - archive/trash transitions
- Add widget tests for:
  - auth gate
  - editor flows
  - sync state UI
- Add backend tests for auth middleware and note ownership
- Add logging/crash reporting
- Review data validation and auth checks
- Finalize Android/iOS release settings

### Acceptance criteria

- Core flows are covered by automated tests
- Unauthorized data access is blocked
- Release builds are stable

## Suggested Execution Order

Build in this order:

1. Firebase Auth
2. Backend Firebase token verification
3. Drift local database
4. Migration from `SharedPreferences`
5. Sync engine
6. Archive feature
7. Route guards and auth routes
8. Theme/import-export/lock/reminder screens
9. Attachments
10. Notifications and release hardening

## Recommended Free Services Summary

### Use now

- Firebase Auth: free and easiest for mobile auth
- Turso: free relational online notes store for MVP
- Firebase Storage: only when attachments are added

### Best stack for this repo

- Firebase Auth + Turso + existing Express backend

## Environment and Secrets Checklist

### Flutter app

- Firebase Android config
- Firebase iOS config
- API base URL

### Backend

- `TURSO_DATABASE_URL`
- `TURSO_AUTH_TOKEN`
- Firebase Admin credentials
- CORS allowed origins

## Definition of Done for V1

ThinkNote V1 is done when:

- users can sign in with Firebase
- notes sync across devices
- the app remains fully usable offline
- archive and trash both work correctly
- settings screens are implemented
- route guards are in place
- local data is stored in Drift
- cloud data is stored in Turso
- backend enforces authenticated user ownership
- release builds pass CI and manual QA


Recommended stack for v1:

Auth: firebase_auth
Online data: Turso / libSQL
API layer: keep the current Node/Express backend in server.ts
Local offline cache: replace the current SharedPreferences blob in notes_local_datasource.dart with Drift
File attachments later: Firebase Storage
Notifications later: local notifications first, FCM after sync is stable
Why this is the right choice

Turso matches your current SQL schema for notes, folders, tags, trash, and archive better than a document rewrite.
Firebase Auth is easy on the client, and the backend can verify Firebase ID tokens and use the Firebase UID as the app user ID.
Free-tier MVP is realistic.
You avoid splitting auth and data in a way that fights your current repo.
Detailed Development Plan

Decide the v1 workspace model before writing more backend code. If “online workspace” means one person syncing across multiple devices, keep the current user_id structure in schema.sql. If you already know shared workspaces are coming soon, change the schema now to workspace_id plus workspace_members, because retrofitting that later will be painful. My recommendation is: v1 should be personal sync only.

Finish auth first. Create the Firebase project, enable Email/Password and Google sign-in first, and wire firebase_core plus firebase_auth into the Flutter app. Build sign-in, sign-up, session restore, and logout. Once auth exists, remove the “local only / no signup / no cloud” wording from profile_screen.dart and related screens. Done means a user can sign in, reopen the app, stay signed in, and sign out cleanly.

Replace the mock backend identity with real Firebase verification. Right now the backend injects mock-user-id in server.ts. Replace that with Firebase Admin token verification middleware. Use the Firebase UID as users.id. Since Firebase owns credentials, stop relying on password_hash in the current schema. On first authenticated request, upsert the user row. Done means unauthenticated requests fail and authenticated users only read/write their own data.

Rebuild local storage for real offline sync. Your current notes store is a single JSON blob in SharedPreferences in notes_local_datasource.dart. That is fine for local MVP, but not strong enough for sync, migrations, conflict handling, or large note sets. Move to Drift. Create local tables for notes, folders, tags, deleted records, and a sync queue. Add a one-time migration that imports the old SharedPreferences data into Drift on upgrade. Done means the app works fully offline with a large note library and no data loss.

Build the sync model before adding more features. Do local-first writes: save locally immediately, then enqueue a sync task. Add authenticated sync endpoints such as pull changes since timestamp and push local mutations, or a simple CRUD layer plus delta fetch if you want to start smaller. Keep updated_at, deleted_at, and is_deleted, and add a revision or server-version field. For conflict handling, use last-write-wins for v1, but if two devices changed the same note, preserve the losing version as a conflict copy instead of silently discarding it. Done means two devices converge correctly after reconnecting.

Finish the core note-state features next. Trash exists, but archived_notes_screen.dart is empty, so archive is not complete. Implement archive/unarchive actions, archived list UI, and synced archive state. Make pin, favorite, trash, restore, and archive all flow through the same local-plus-cloud sync rules. Done means every note state change is visible and consistent across devices.

Finish the incomplete profile/settings screens in a strict order. theme_settings_screen.dart, lock_notes_screen.dart, import_export_screen.dart, and notification_settings_screen.dart are empty. Build theme settings first because the logic mostly exists already in modals. Build import/export second with JSON export first and import later. Build note locking third as a local device feature with biometrics or passcode, not encrypted cloud sync. Build notification settings fourth with local reminders first.

Add route guards and real routing coverage. route_guards.dart is empty, and the router in app_routes.dart only exposes root, editor, and trash. Add auth-aware redirects, onboarding/login routes, archive route, and routes for the settings screens you actually implement. Done means the app no longer depends on hidden or dead screens and the navigation model matches the product.

Clean up UI copy once cloud sync is real. Several current screens still tell the user the app is offline-only, especially profile_screen.dart. Change the messaging to “offline-first with cloud sync” instead of “local only.” Keep offline messaging, but make it accurate: the app should work offline and sync when online.

Keep search local even after adding cloud sync. Do not query the cloud on every keystroke. Once notes are synced to Drift locally, search locally for instant results. Keep recent searches device-local unless you have a strong reason to sync them. Done means search stays fast and cheap even with a large library.

Add attachments only after sync is stable. Use Firebase Storage for files and Turso for file metadata. Do not store blobs in Turso. Use per-user storage paths based on Firebase UID. Compress images client-side. Done means notes can attach images/files without destabilizing the sync model.

Harden release quality after the main flows work. Add tests for Firebase token verification, migration from SharedPreferences to Drift, sync conflict resolution, archive/trash behavior, and route guards. Then wire Crashlytics and expand CI so auth, tests, and builds all run reliably. Done means a new user can sign in, create notes, edit on one device, install on another device, and see consistent data.

Suggested build order

Firebase Auth
Backend token verification
Drift local database migration
Turso sync endpoints
Archive feature
Route guards and auth routing
Theme/import-export/lock/reminders
Attachments
QA and release hardening
