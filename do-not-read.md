# ThinkNote Sync Failure Audit

Audit date: 2026-06-01
note: already implemented

Scope: Static audit of the Flutter client and TypeScript/Express backend, plus read-only runtime checks against the required production API host. No implementation code was changed.

## 1. Executive Summary

ThinkNote is configured to use the required production API origin `https://api.unicef.edu.eu.org`. The Flutter client builds sync URLs from `AppEnv.apiUri`, validates that the configured origin is exactly the canonical host, and calls `/health`, `/sync/push`, and `/sync/pull` without an `/api` or `/v1` prefix.

The production host was reachable during this audit:

- `GET https://api.unicef.edu.eu.org/health` returned HTTP 200 with `{"status":"ok","db":{"time":"2026-06-01 00:36:22"},"message":"Backend is running!"}`.
- `POST https://api.unicef.edu.eu.org/sync/push` without credentials returned HTTP 401 JSON: `{"success":false,"data":null,"error":"unauthorized","message":"Missing or invalid authentication token"}`. This confirms the deployed route exists and auth middleware is active.

The main confirmed sync blocker is not the frontend API URL. It is a frontend/backend database contract mismatch around default folders:

- The client creates notes under local system folders such as `personal`, `study`, `ideas`, `work`, and `journal`.
- The client deliberately does not push system folders to the backend.
- The client still sends the note's `folder_id`, normally `personal`, in `/sync/push`.
- The backend `notes.folder_id` column has a foreign key to `folders(id)`.
- The backend does not create or normalize default folder rows before inserting notes.
- The same `@libsql/client` database package used by the backend reported `PRAGMA foreign_keys=1` in local verification, and inserting a note with a missing folder failed with `SQLITE_CONSTRAINT_FOREIGNKEY: FOREIGN KEY constraint failed`.

Impact: a normal first note saved in the default Personal folder can make `/sync/push` fail with HTTP 500, leaving the note dirty locally. The UI then reports a sync/server/connection problem while the actual cause is a server-side persistence failure.

Severity: P0, production-blocking for normal note sync.

## 2. Confirmed API Configuration

| Source | Value / Behavior | Matches `https://api.unicef.edu.eu.org`? | Evidence |
|---|---|---:|---|
| Flutter canonical API constant | `AppEnv.canonicalApiUrl = 'https://api.unicef.edu.eu.org'` | Yes | `lib/core/config/app_env.dart`, `AppEnv.canonicalApiUrl` |
| Flutter API default | `String.fromEnvironment('API_URL', defaultValue: canonicalApiUrl)` | Yes by default | `lib/core/config/app_env.dart`, `AppEnv.apiUrl` |
| Flutter validation | Requires absolute URL, origin-only path, HTTPS, host `api.unicef.edu.eu.org` | Yes | `lib/core/config/app_env.dart`, `validateBase`, `isCanonicalApiUri` |
| App startup | Calls `AppEnv.validateBase()` and Android also calls `validateAndroid()` | Yes | `lib/bootstrap/app_initializer.dart`, `validateEnvironment` |
| Runtime URL construction | Adds a trailing slash to `AppEnv.apiUri` and resolves request paths | Yes | `lib/core/network/authenticated_api_client.dart`, `_buildUri` |
| README | Documents canonical production `API_URL=https://api.unicef.edu.eu.org` | Yes | `README.md` |
| Android release scripts | Default omitted `API_URL` to canonical and reject non-canonical production origins | Yes | `scripts/android/build_release_artifacts.sh`, `scripts/android/build_release_artifacts.ps1` |
| Root `.env` | Contains `API_URL=https://api.unicef.edu.eu.org`, but README says Flutter does not load `.env` as an asset | Informational only | `.env`, `README.md` |
| `.env.example` | Contains `API_URL=http://10.0.2.2:3000` | No, but template only | `.env.example` |

Conclusion: the production client code is designed to use `https://api.unicef.edu.eu.org`. A wrongly launched local IDE run can still omit Firebase `--dart-define` values, but the API URL itself defaults to the canonical host.

## 3. Frontend Sync Flow Analysis

### Create and edit

1. The note editor updates in-memory state on title/content/folder/tag/pin/favorite changes.
   Evidence: `lib/features/notes/presentation/controllers/note_editor_controller.dart`, `updateTitle`, `updateContent`, `setFolder`, `replaceTags`, `togglePinned`, `toggleFavorite`.

2. A 450 ms debouncer calls `_persist()`.
   Evidence: `note_editor_controller.dart`, `_debouncer = Debouncer(const Duration(milliseconds: 450))`, `_scheduleSave`, `_persist`.

3. `_persist()` calls `NotesRepository.saveNote(...)`.
   Evidence: `note_editor_controller.dart`, `_persist`.

4. New notes are assigned a UUID, a default folder when none is selected, and `syncStatus: NoteSyncStatus.pendingCreate`.
   Evidence: `lib/features/notes/data/repositories/notes_repository_impl.dart`, `saveNote`, `_fallbackFolderId`.

5. Existing notes are rewritten with `syncStatus` equal to `pendingCreate` if they have no `remoteId`, otherwise `pendingUpdate`.
   Evidence: `notes_repository_impl.dart`, `_pendingMutationStatus`.

6. After a save succeeds, the editor calls `_scheduleSync()`, which invokes `SyncController.scheduleSync()` without awaiting it.
   Evidence: `note_editor_controller.dart`, `_persist`, `_scheduleSync`.

### Delete and trash

1. Moving to trash is a soft update: `isDeleted=true`, `deletedAt=now`, `isPinned=false`, `isArchived=false`, and dirty sync status.
   Evidence: `notes_repository_impl.dart`, `moveToTrash`.

2. Permanent note deletion queues a delete operation in local `sync_queue` and removes the note from the local note list.
   Evidence: `notes_repository_impl.dart`, `deleteNote`; `lib/features/sync/data/models/sync_delete_operation.dart`, `toPayloadJson`.

3. `emptyTrash()` queues delete operations for each trashed note and removes them locally.
   Evidence: `notes_repository_impl.dart`, `emptyTrash`.

### Sync execution

1. `SyncController.scheduleSync()` delegates to `syncNow()`.
   Evidence: `lib/features/sync/presentation/controllers/sync_controller.dart`, `scheduleSync`, `syncNow`.

2. `syncNow()` deduplicates concurrent syncs via `_inFlight`.
   Evidence: `sync_controller.dart`, `_inFlight`.

3. `_runSync()` exits early if sync is disabled, if no Firebase session exists, or if the persisted retry backoff has not expired.
   Evidence: `sync_controller.dart`, `_runSync`, `_readNextRetryAt`.

4. The controller reads the local notes store, pending delete operations, dirty note versions, and last server sync timestamp.
   Evidence: `sync_controller.dart`, `_runSync`, `_pushedNoteVersions`.

5. Every sync first calls public `GET /health`.
   Evidence: `sync_controller.dart`, `apiClient.verifyBackendHealth`; `authenticated_api_client.dart`, `verifyBackendHealth`.

6. The push request is `POST /sync/push` with `notes`, `folders`, `tags`, `deleted_notes`, `deleted_folders`, and `deleted_tags`.
   Evidence: `sync_controller.dart`, `_buildPushBody`, `_noteToPushJson`, `_folderToPushJson`, `_tagToPushJson`.

7. The pull request is `GET /sync/pull`, optionally with `?since=<last_server_sync_at>`.
   Evidence: `sync_controller.dart`, `apiClient.getJson('/sync/pull', queryParameters: ...)`.

8. On success, pushed note versions are acknowledged only if they were not edited again while sync was in flight.
   Evidence: `sync_controller.dart`, `_acknowledgePushedNotes`.

9. Pull data is merged, queued delete IDs are cleared, `last_server_sync_at` is updated, and retry state is cleared.
   Evidence: `sync_controller.dart`, `_mergeStore`, `commitSyncResult`; `notes_local_datasource.dart`, `commitSyncResult`.

10. On failure, the controller classifies the error, stores retry metadata, increments failed delete retry counts, and leaves dirty notes/deletes queued.
    Evidence: `sync_controller.dart`, catch block in `_runSync`, `_classifySyncFailure`, `recordSyncFailure`.

## 4. Backend Notes API Analysis

The backend is an Express app created in `backend/src/app.ts`.

Mounted routes:

- `GET /health` is public and checks only `SELECT datetime('now')`.
- `/notes` is protected by IP rate limit, Firebase auth, user rate limit, then `notes.routes.ts`.
- `/sync` is protected by IP rate limit, Firebase auth, user rate limit, then `sync.routes.ts`.
- `/account` is protected by the same auth/rate-limit stack.

Evidence: `backend/src/app.ts`, `createApp`.

Authentication:

- Protected routes require `Authorization: Bearer <Firebase ID token>`.
- Missing or invalid tokens return HTTP 401 with `success:false`, `error:"unauthorized"`, and a message.
- The middleware inserts/updates the authenticated user row, but logs and continues if that database write fails.

Evidence: `backend/src/middleware/auth.middleware.ts`, `buildRequireFirebaseAuth`, `extractBearerToken`.

Sync routes:

- `GET /sync/pull` returns `data.server_time`, `data.notes`, `data.folders`, `data.tags`, and deleted entity arrays.
- `POST /sync/push` accepts arrays for notes, folders, tags, and deleted entities.
- Payload validation rejects malformed arrays, oversized batches, invalid field types, oversized fields, and invalid booleans.
- Push order is folders, tags, notes, deleted notes, deleted folders, deleted tags.

Evidence: `backend/src/routes/sync.routes.ts`, `/pull`, `/push`, `syncFolders`, `syncTags`, `syncNotes`; `backend/src/utils/note_validation.ts`.

Notes persistence:

- Notes are upserted into `notes(id, user_id, title, content, excerpt, category, folder_id, color_key, emoji, is_pinned, is_favorite, is_archived, is_deleted, created_at, updated_at, deleted_at)`.
- Tags are linked through `note_tags`.
- Deletes are recorded in `deleted_entities`.

Evidence: `backend/src/routes/sync.routes.ts`, `syncNotes`, `syncDeletedNotes`, `recordDeletionTombstone`.

Response format:

- Success responses are `{ success: true, data, message }`.
- Error responses are `{ success: false, data: null, message }`.
- Frontend `AuthenticatedApiClient._decodeResponse()` expects a JSON object and throws `ApiException` for HTTP 400+.

Evidence: `backend/src/utils/api_response.ts`; `lib/core/network/authenticated_api_client.dart`.

## 5. Frontend vs Backend Contract Comparison

| Area | Frontend Behavior | Backend Expectation | Match? | Evidence |
|---|---|---|---:|---|
| API origin | Uses `https://api.unicef.edu.eu.org` by default and validates only that canonical origin | Deployed API is at same host | Yes | `AppEnv`, runtime `/health` check |
| Path prefix | Calls `/health`, `/sync/push`, `/sync/pull` | Mounts `/health` and `/sync` at root | Yes | `authenticated_api_client.dart`, `backend/src/app.ts` |
| Auth header | Sends `authorization: Bearer <Firebase ID token>` and retries once after 401 with forced token refresh | Requires bearer Firebase token | Yes | `AuthenticatedApiClient._headers`, `auth.middleware.ts` |
| Health precheck | Calls public `/health` before push | Public route returns JSON `status: ok` | Yes | `verifyBackendHealth`, runtime 200 |
| Note create/update payload | Sends `id`, `title`, `content`, `folder_id`, `tags`, booleans, timestamps | `validateSyncNotePayload()` allows those fields | Mostly yes | `_noteToPushJson`, `validateSyncNotePayload` |
| Default note folder | Sends local system folder IDs such as `personal` in `folder_id` | `notes.folder_id` must reference a row in backend `folders(id)` | No | `_noteToPushJson`, `FolderModel.defaults`, `schema.sql` |
| System folders | Excludes folders where `folder.isSystem` | Backend has no built-in seed for system folder rows | No | `_buildPushBody`, `syncFolders` |
| Tags | Excludes default tags but backend can create missing tag rows from note tag labels | Backend `ensureTagExists()` creates tags by label | Yes | `_tagToPushJson`, `ensureTagExists` |
| Pull response | Expects `data.server_time`, arrays of notes/folders/tags/deletes | Backend returns those keys | Yes | `SyncPullPayload.fromJson`, `sync.routes.ts` |
| HTTP errors | Converts backend status/body into `ApiException` and classifies by status/kind | Backend returns JSON error bodies for route errors | Mostly yes | `_decodeResponse`, `errorResponse` |
| Transactionality | Assumes a push either completes or can safely retry | Backend writes folders/tags/notes/deletes in separate statements without a route-level transaction | Risk | `sync.routes.ts`, `/push` |

## 6. Authentication/User Context Analysis

Sync requires a Firebase session on both sides.

Frontend:

- `currentAuthSessionProvider` derives from Firebase `userChanges()` or `FirebaseAuth.currentUser`.
- `SyncController._runSync()` skips sync if `currentAuthSessionProvider` is null.
- `AuthenticatedApiClient._headers()` calls `currentIdToken()` and sends the bearer token.
- On HTTP 401, the client retries once with `forceRefresh: true`, then signs out if the retry is still 401.

Evidence: `lib/features/auth/auth_providers.dart`, `FirebaseAuthRepository.currentIdToken`, `AuthenticatedApiClient._sendAuthorized`.

Backend:

- `requireFirebaseAuth` extracts the bearer token and calls Firebase Admin `verifyIdToken`.
- The UID becomes `req.user_id`.
- The user row upsert is best-effort and errors are logged, not returned.

Evidence: `backend/src/middleware/auth.middleware.ts`.

No active `local-workspace@thinknote.app` or equivalent fallback identity was found in the app code. The current launch path is mandatory-authenticated, and route guards send unauthenticated users to the auth route.

Needs runtime verification:

- Whether the Firebase Admin credentials deployed at `api.unicef.edu.eu.org` match the same Firebase project used by the client build.
- Whether a real ID token from the app can call `/account/me`, `/sync/push`, and `/sync/pull`.

## 7. Queue and Retry Mechanism Analysis

The app has two queue mechanisms:

1. Creates/updates are not stored as separate queue rows. They stay in the local `notes` table with `syncStatus != synced`.
2. Permanent deletes are stored in `sync_queue` as delete operations.

Evidence: `notes_repository_impl.dart`, `saveNote`, `_pendingMutationStatus`, `deleteNote`; `app_database.dart`, local `sync_queue` schema.

Retry behavior:

- Failed syncs write `sync_failure_count` and `sync_retry_after` into local `sync_state`.
- `SyncController` skips non-forced sync while retry backoff is active.
- Backoff starts at 30 seconds and doubles up to 15 minutes.
- Periodic shell sync runs every 3 minutes, app resume triggers sync, connectivity from offline to online triggers sync, and manual buttons can call `forceFullPull: true`.

Evidence: `sync_controller.dart`, `_calculateNextRetryAt`; `main_shell_screen.dart`, `_syncRefreshInterval`, connectivity listener, app lifecycle hook.

Confirmed behavior:

- Dirty notes remain dirty after failure because acknowledgment happens only after push and pull both succeed.
- Delete operations remain queued after failure and get retry counts/last error updated.

Risk:

- There is no one-shot timer scheduled exactly for `nextRetryAt`; retry depends on user actions, app lifecycle, connectivity changes, or the 3-minute periodic timer.
- If the backend keeps returning 500 for the folder foreign-key mismatch, the queue will never drain until the contract is fixed.

## 8. Error Handling Analysis

The displayed message:

```text
ThinkNote could not reach the server. Your changes stay queued and will retry automatically.
```

comes from `SyncController._networkFailureForApiError()` when an `ApiException` has `ApiFailureKind.serverUnreachable`.

Evidence: `lib/features/sync/presentation/controllers/sync_controller.dart`, `_networkFailureForApiError`.

The title shown in sync UI surfaces comes from `describeSyncErrorType(syncState.lastErrorType)`.

Evidence: `sync_controller.dart`, `describeSyncErrorType`; `lib/shared/widgets/app_header.dart`, sync status popover; `home_screen.dart` and `profile_screen.dart`, manual sync snackbars.

Error mapping:

- DNS failure becomes `DNS issue`.
- TLS/SSL failure becomes `Connection security issue`.
- Timeout becomes `Connection timeout`.
- Connection refused/reset/closed/broken pipe becomes `Server unreachable` plus the message above.
- HTTP 401 becomes `Authentication issue`.
- HTTP 403 becomes `Permission issue`.
- HTTP 400/422 becomes `Sync data issue`.
- HTTP 429 becomes `Retry later`.
- HTTP 500+ becomes `Server issue` with the backend error message, usually `Failed to push sync changes` or `Failed to pull sync changes`.

The app does not always hide HTTP errors behind the exact connection message. It only uses the exact "could not reach" text for client-level connection failures. However, backend route handlers catch detailed database exceptions and replace them with generic JSON such as `Failed to push sync changes`, so a database foreign-key failure would likely appear to the user as a generic server issue unless debug/server logs are inspected.

## 9. Backend Database and Persistence Analysis

Backend schema:

- `users(id)` primary key.
- `folders(id)` primary key with `user_id` foreign key to `users(id)`.
- `tags(id)` primary key with `user_id` foreign key to `users(id)`.
- `notes(id)` primary key with `user_id` foreign key to `users(id)` and `folder_id` foreign key to `folders(id)`.
- `note_tags(note_id, tag_id)` with cascading foreign keys.
- `deleted_entities(user_id, entity_type, entity_id)` for tombstones.
- `sync_state(user_id, key)` exists but is not used by the current sync routes.

Evidence: `backend/src/db/schema.sql`.

Confirmed persistence failure path:

1. A new local store contains default folders from `FolderModel.defaults()`.
2. Default folders have fixed IDs including `personal`, and `isSystem: true`.
3. A new note gets fallback folder ID `personal`.
4. `/sync/push` sends dirty notes with `folder_id: note.folderId`.
5. `/sync/push` sends folders with `where((folder) => !folder.isSystem)`, excluding `personal`.
6. Backend `syncNotes()` inserts `folder_id` unchanged if that folder was not deleted.
7. Backend schema requires `notes.folder_id` to reference `folders(id)`.
8. Local verification with the same backend database package showed foreign keys enabled and insertion with a missing folder failed.

Evidence:

- `lib/features/folders/data/models/folder_model.dart`, `FolderModel.defaults`.
- `lib/features/notes/data/repositories/notes_repository_impl.dart`, `_fallbackFolderId`.
- `lib/features/sync/presentation/controllers/sync_controller.dart`, `_buildPushBody`, `_noteToPushJson`.
- `backend/src/routes/sync.routes.ts`, `syncNotes`.
- `backend/src/db/schema.sql`, `notes.folder_id` foreign key.
- Local verification: `@libsql/client` returned `PRAGMA foreign_keys=1`; inserting `folder_id='personal'` without a folder row failed with `SQLITE_CONSTRAINT_FOREIGNKEY: FOREIGN KEY constraint failed`.

Additional database risks:

- `/health` only proves the database can execute `SELECT datetime('now')`; it does not prove required tables or migrations exist.
- `/account/me` can hide missing/failed `users` persistence because the auth middleware logs user-row upsert failure and the account route can fall back to the Firebase auth profile.
- `/sync/push` is not wrapped in a transaction, so partial folder/tag writes can survive before a note write fails.
- Deleting folders can violate note folder foreign keys unless note `folder_id` is nulled or otherwise normalized before deleting the folder row.

## 10. Deployment/Environment Findings

Production host:

- `https://api.unicef.edu.eu.org/health` was reachable and returned JSON status `ok`.
- `/sync/push` exists on the deployed host and rejects unauthenticated requests with structured 401 JSON.

What this proves:

- DNS/TLS/basic routing for the required host worked from this audit environment.
- The deployed app exposes the expected root-level `/sync/push` route.
- Auth middleware is active.

What this does not prove:

- The deployed schema has all required tables.
- Authenticated sync writes can commit.
- Firebase Admin credentials on the backend match the client Firebase project.
- CORS is correct for a deployed Flutter Web origin.
- A mobile device/emulator can reach the same host on its network.

CORS:

- In production, if `CORS_ALLOWED_ORIGINS` is empty and a browser sends an `Origin`, the backend returns a 500 `CORS_ALLOWED_ORIGINS is not configured`.
- Native mobile requests usually have no browser `Origin`; production no-origin requests are allowed only when `CORS_ALLOW_NO_ORIGIN=true`.

Evidence: `backend/src/app.ts`, CORS callback and `loadConfig`; `backend/README.md`, production controls.

Android:

- Main Android manifest grants `INTERNET`.
- Release cleartext traffic is disabled and network security config uses `cleartextTrafficPermitted="false"`.
- The configured API is HTTPS, so this is compatible.

Evidence: `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/network_security_config.xml`.

## 11. Confirmed Root Causes

### P0 - Default folder IDs are sent on notes but not persisted on the backend

Severity: P0

Evidence:

- Client default folders are fixed system folders: `FolderModel.defaults()` includes IDs such as `personal`.
- New notes default to the first local folder via `_fallbackFolderId`, normally `personal`.
- Client push excludes system folders: `_buildPushBody` uses `localStore.folders.where((folder) => !folder.isSystem)`.
- Client push still sends `folder_id: note.folderId`.
- Backend `syncNotes()` inserts `folder_id` unchanged.
- Backend schema enforces `FOREIGN KEY (folder_id) REFERENCES folders(id)`.
- Local `@libsql/client` verification showed `PRAGMA foreign_keys=1` and rejected a note row whose `folder_id` did not exist.

Affected files:

- `lib/features/folders/data/models/folder_model.dart`
- `lib/features/notes/data/repositories/notes_repository_impl.dart`
- `lib/features/sync/presentation/controllers/sync_controller.dart`
- `backend/src/routes/sync.routes.ts`
- `backend/src/db/schema.sql`

Why it breaks sync:

The ordinary first-note path creates a note under the default local Personal folder but never creates the corresponding backend folder row. The backend note insert can fail with a foreign-key constraint error, returning generic HTTP 500 from `/sync/push`. The client leaves the note queued and retries indefinitely.

What must be fixed later:

Choose one authoritative contract:

- Sync system folders to the backend per user before notes are inserted.
- Or send `folder_id: null` for local-only system folders and map them client-side.
- Or seed backend system folders per user before note sync.
- Also add a backend test that posts a note with the default folder ID and proves it either succeeds or is normalized safely.

### P1 - Backend sync push is not transactional

Severity: P1

Evidence:

- `/sync/push` calls `syncFolders`, `syncTags`, `syncNotes`, `syncDeletedNotes`, `syncDeletedFolders`, and `syncDeletedTags` sequentially.
- Each helper performs independent `db.execute()` calls.
- No route-level transaction wraps the full push.

Affected files:

- `backend/src/routes/sync.routes.ts`

Why it breaks or degrades sync:

When a later step fails, earlier writes may already be committed. With the folder mismatch, folders/tags can be persisted while notes fail. Repeated retries may be idempotent in many cases, but partial server state makes debugging harder and increases conflict risk.

What must be fixed later:

Wrap sync push operations in a database transaction where supported, or make each step explicitly idempotent and add tests for partial-failure recovery.

## 12. Suspected Issues Requiring Runtime Verification

### P0/P1 - Production schema may be incomplete even though `/health` passes

Why this is suspected:

- `/health` only runs `SELECT datetime('now')`.
- Auth middleware logs and continues if inserting into `users` fails.
- `/account/me` can fall back to Firebase profile data on `"no such table: users"`.
- Sync routes do not have equivalent fallbacks and would return 500 if tables are missing.

Needs runtime verification:

- Run an authenticated production `/sync/push` with a safe test account and inspect whether any `no such table`, foreign-key, or migration errors appear in backend logs.
- Add or run a protected schema readiness endpoint/script that verifies `users`, `notes`, `folders`, `tags`, `note_tags`, and `deleted_entities`.

### P1 - Firebase project mismatch can produce persistent 401 sync failures

Why this is suspected:

- The backend validates tokens with Firebase Admin.
- The client gets tokens from Firebase SDK config supplied by `--dart-define`.
- Static analysis cannot prove deployed backend Admin credentials match the client build project.

Needs runtime verification:

- Use a real signed-in app token against `/account/me`, `/sync/push`, and `/sync/pull`.
- Confirm backend logs show the expected Firebase UID.

### P1 - CORS can block Flutter Web sync

Why this is suspected:

- Production CORS requires `CORS_ALLOWED_ORIGINS` for browser-origin requests.
- This audit did not confirm the deployed website origin or current CORS environment values.

Needs runtime verification:

- Send an OPTIONS/POST request from the actual deployed Flutter Web origin.
- Confirm `Access-Control-Allow-Origin` matches that origin.

### P2 - Payload size and batch limits can trap large queues

Why this is suspected:

- Backend JSON body limit defaults to `256kb`.
- Individual note content can be up to 100,000 characters.
- Sync push can include up to 100 notes, folders, or tags before validation rejects the batch.
- The client currently builds one push body rather than chunking dirty notes.

Needs runtime verification:

- Create a large local backlog and confirm whether the client receives 413 or 400.
- Add chunking tests after the P0 folder contract is fixed.

## 13. Recommended Fix Plan

Phase 1 - Reproduce the P0 contract failure locally

1. Use a fake authenticated request against the backend sync route with a note payload containing `folder_id: "personal"` and no folders array.
2. Confirm the backend returns 500 or a foreign-key error under the current schema.
3. Add a failing backend route test for this case.

Phase 2 - Fix the folder contract

1. Pick the product contract for system folders.
2. Prefer either server-side per-user system-folder seeding or client-side nulling of local-only system folder IDs before push.
3. Ensure pulled notes can still render in the local default folders.
4. Add tests for create, update, move to trash, permanent delete, and folder deletion paths.

Phase 3 - Improve backend sync durability

1. Wrap sync push in a transaction or implement explicit idempotent recovery tests.
2. Ensure folder deletion does not violate note `folder_id` foreign keys.
3. Return a more diagnostic server error code/message in non-production logs or structured logs while keeping user-facing responses safe.

Phase 4 - Verify production configuration

1. Run authenticated production smoke tests with a disposable Firebase user.
2. Confirm `/account/me`, `/sync/push`, `/sync/pull`, and subsequent pull from a second fresh local store work.
3. Confirm CORS from the deployed web origin if Flutter Web is shipped.

## 14. Validation Plan After Fixes

Minimum validation:

1. Create a note in the default Personal folder.
2. Confirm `/sync/push` returns 200.
3. Confirm the local note becomes `synced` and has `remoteId`.
4. Clear local data or sign in on another device.
5. Confirm `/sync/pull` returns the note and it renders under the expected folder.

Regression validation:

1. Edit the same note and confirm update sync.
2. Move the note to trash and confirm soft-delete sync.
3. Permanently delete the note and confirm delete tombstone sync.
4. Create a custom folder, move a note into it, sync, pull on a clean install.
5. Delete a custom folder and confirm notes are safely reassigned or nulled without backend FK errors.
6. Test expired-token behavior and confirm the one-time forced refresh works.
7. Test Flutter Web from the deployed origin if web is in scope.

Suggested automated tests:

- Backend route test for `/sync/push` with default folder behavior.
- Backend route test for folder deletion with existing notes.
- Flutter sync controller test asserting default-folder note payload is normalized according to the chosen contract.
- Integration smoke test using the canonical production API in a disposable environment.

## 15. Files That Will Likely Need Changes

Frontend:

- `lib/features/sync/presentation/controllers/sync_controller.dart`
- `lib/features/notes/data/repositories/notes_repository_impl.dart`
- `lib/features/folders/data/models/folder_model.dart`
- `test/unit/sync/sync_controller_test.dart`

Backend:

- `backend/src/routes/sync.routes.ts`
- `backend/src/db/schema.sql`
- `backend/src/utils/note_validation.ts` if folder normalization requires validation changes
- `backend/tests/app.test.js` or new sync route tests
- `backend/scripts/push_schema.js` or deployment scripts if schema readiness checks are added

Deployment/config:

- Backend environment variables for Firebase Admin, Turso, CORS, and no-origin behavior.
- Android release build scripts only if runtime config verification needs stronger artifact metadata.

## 16. Final Notes

The frontend is already pointed at the required API host, and the deployed host is reachable. The highest-confidence blocker is the default-folder persistence contract: notes reference local system folder IDs that the backend never stores, while the backend schema requires the folder row to exist.

The safest implementation approach is to first add a failing test that captures a default-folder note sync, then fix the contract in the smallest place that matches the product model. After that, run an authenticated production smoke test, because `/health` alone is not enough to prove sync persistence works.
