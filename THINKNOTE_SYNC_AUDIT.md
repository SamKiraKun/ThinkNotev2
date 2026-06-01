# ThinkNote Sync Failure Audit

## 1. Executive Summary

This audit did **not** find a static frontend/backend contract mismatch in the current codebase. The Flutter client is hard-wired to the canonical backend origin `https://api.unicef.edu.eu.org`, validates that origin at bootstrap, sends the expected `/sync/push` and `/sync/pull` payload shapes, and the backend code exposes those exact routes.

On **June 1, 2026**, manual runtime probes from this workspace reached the deployed backend successfully:

- `GET https://api.unicef.edu.eu.org/health` returned `200 OK` with JSON at approximately **08:21 UTC**.
- `GET https://api.unicef.edu.eu.org/sync/pull` without a bearer token returned the expected `401 Unauthorized` JSON at approximately **08:23 UTC**.

That matters because the user-reported message:

```text
ThinkNote could not reach the server.
Your changes stay queued and will retry automatically.
```

is only emitted by the Flutter client when it classifies the failure as a **low-level transport failure** (`connection refused`, `connection reset`, `connection closed`, `broken pipe`) before it receives any HTTP response at all. In the current codebase, that message is **not** used for `401`, `403`, `404`, `500`, validation errors, or JSON contract errors.

The current evidence therefore points away from a dead API host or a broken route path and toward one of these runtime problems:

1. A client-context transport failure between the failing app instance and `https://api.unicef.edu.eu.org`.
2. A deployment-side auth/schema/readiness problem that is **masked** by shallow health checks and permissive `/account/me` fallback behavior.
3. A browser-only CORS problem on the actual deployed web origin.

Severity remains **P0** because online sync is a release-blocking feature, but the most likely failure is now runtime/deployment-specific rather than a straightforward source-code endpoint mismatch.

## 2. Confirmed API Configuration

### Canonical frontend API origin

The Flutter app's runtime API origin is defined in `lib/core/config/app_env.dart:21-28`:

- `canonicalApiUrl = 'https://api.unicef.edu.eu.org'`
- `apiUrl` defaults to that same canonical origin.

Bootstrap validation in `lib/core/config/app_env.dart:97-133` enforces:

- the URL must be absolute,
- the URL must not contain a route path,
- the host must be exactly `api.unicef.edu.eu.org`,
- the scheme must be `https`.

Because `lib/bootstrap/app_bootstrap.dart:50-78` calls `AppInitializer.validateEnvironment()`, and `lib/bootstrap/app_initializer.dart:11-17` calls `AppEnv.validateBase()`, a build pointed at `localhost`, `10.0.2.2`, or any non-canonical host should fail during app startup rather than silently queue sync traffic.

### Frontend documentation and local shell files

- `README.md:5`, `README.md:22`, `README.md:41`, and `README.md:81` all document `https://api.unicef.edu.eu.org` as the required production API origin.
- Root `.env:3-4` also currently points to `APP_FLAVOR=development` and `API_URL=https://api.unicef.edu.eu.org`.

### Release scripts

Both Android release builders default to and enforce the canonical backend origin:

- `scripts/android/build_release_artifacts.sh:24-25`, `:42-47`, `:67-74`
- `scripts/android/build_release_artifacts.ps1:32-37`, `:60-64`, `:90-102`

These scripts reject non-canonical production `API_URL` values.

### Stale config artifact

Root `.env.example:3-4` still advertises:

- `APP_FLAVOR=development`
- `API_URL=http://10.0.2.2:3000`

and `.env.example:14` still claims `ENABLE_EXPERIMENTAL_SYNC=false`.

This does **not** match the current runtime code:

- `AppEnv.enableExperimentalSync` is hard-coded to `true` in `lib/core/config/app_env.dart:69`.
- `AppEnv.validateBase()` rejects non-canonical API origins in `lib/core/config/app_env.dart:128-133`.

### Backend runtime probe

Manual runtime evidence on **June 1, 2026**:

- `GET /health` on `https://api.unicef.edu.eu.org` returned `200 OK` JSON.
- `GET /sync/pull` without a token returned the expected `401 Unauthorized` JSON.

### Conclusion

The current repo does **not** appear to be using a stale or malformed production API base URL. The canonical host is configured consistently in code and release scripts, and the live deployed host responded correctly during this audit.

## 3. Frontend Sync Flow Analysis

### Startup and auth gate

The app is mandatory-authentication in current code:

- `lib/features/onboarding/presentation/controllers/onboarding_controller.dart:123-159`
- `lib/core/router/route_guards.dart:45-63`
- `lib/features/auth/presentation/screens/auth_gate_screen.dart:123-135`

For signed-in sessions, startup also calls `/account/me` through `authenticatedAccountProvider`:

- `lib/features/auth/auth_providers.dart:29-45`

### Local note write path

Creating or editing a note goes through:

1. `NoteEditorController._persist()` in `lib/features/notes/presentation/controllers/note_editor_controller.dart:256-313`
2. `NotesRepositoryImpl.saveNote()` in `lib/features/notes/data/repositories/notes_repository_impl.dart:36-93`
3. `NotesLocalDataSource.writeStore()` in `lib/features/notes/data/datasources/notes_local_datasource.dart:114-120`

Local note mutations are stored first, then marked for sync using note-level `syncStatus`:

- new notes become `pendingCreate` at `notes_repository_impl.dart:50-61`
- edited notes become `pendingCreate` or `pendingUpdate` through `_pendingMutationStatus()` at `notes_repository_impl.dart:477-481`

### Delete path

Hard deletions are stored in a local delete queue:

- note delete: `notes_repository_impl.dart:161-179`
- trash empty: `notes_repository_impl.dart:182-203`
- folder delete queueing: `notes_repository_impl.dart:281-316`
- tag delete queueing: `notes_repository_impl.dart:347-375`

Delete operations persist into `sync_queue` through:

- `NotesLocalDataSource.upsertDeleteOperation()` at `notes_local_datasource.dart:148-152`
- SQL write at `notes_local_datasource.dart:433-455`

### What triggers sync

The UI schedules sync after all note/folder/tag mutations:

- `lib/features/notes/presentation/controllers/notes_controller.dart:41-180`
- `lib/features/notes/presentation/controllers/note_editor_controller.dart:305-306`, `:321-323`

The shell also triggers sync on:

- session bootstrap,
- app resume,
- connectivity restored,
- a 3-minute timer.

Evidence:

- `lib/features/shell/presentation/screens/main_shell_screen.dart:33-54`
- `:76-113`
- `:172-228`

### Actual sync request path

The sync controller performs this exact flow:

1. Abort if sync disabled or session missing.
2. Check retry backoff.
3. Read local store and pending deletes.
4. Call `GET /health`.
5. Call `POST /sync/push`.
6. Call `GET /sync/pull`.
7. Merge server data into local store.
8. Clear queue items and update sync metadata.

Evidence:

- `lib/features/sync/presentation/controllers/sync_controller.dart:143-289`

Specific routes:

- `verifyBackendHealth()` -> `/health` in `lib/core/network/authenticated_api_client.dart:105-115`
- push -> `/sync/push` in `sync_controller.dart:200-203`
- pull -> `/sync/pull` in `sync_controller.dart:207-214`

### Outbound payloads

Push payload construction lives in:

- `lib/features/sync/presentation/controllers/sync_controller.dart:610-649`

Note payload fields:

- `id`, `title`, `content`, `folder_id`, `tags`,
- `is_pinned`, `is_favorite`, `is_archived`, `is_deleted`,
- `created_at`, `updated_at`, `deleted_at`

from `sync_controller.dart:678-697`.

Folder payload fields:

- `id`, `name`, `color_key`, `emoji`, `created_at`, `updated_at`

from `sync_controller.dart:700-709`.

Tag payload fields:

- `id`, `label`, `emoji`, `created_at`, `updated_at`

from `sync_controller.dart:711-718`.

Delete payload fields:

- `id`, `deleted_at`

from `lib/features/sync/data/models/sync_delete_operation.dart` via `toPayloadJson()`.

## 4. Backend Notes API Analysis

### Route mounting

The backend mounts the relevant routers in `backend/src/app.ts:178-186`:

- `/notes`
- `/sync`
- `/account`

All three are protected by:

- IP rate limit
- Firebase auth middleware
- per-user rate limit

### Health route

The public health route lives at `backend/src/app.ts:162-176`.

It only executes:

- `SELECT datetime('now') AS time`

This proves DB connectivity only. It does **not** validate:

- `users`, `notes`, `folders`, `tags`, `deleted_entities`, or `sync_state` tables
- Firebase Admin credentials
- sync write readiness

### Auth middleware

Authenticated sync uses Firebase bearer tokens:

- token extraction: `backend/src/middleware/auth.middleware.ts:96-108`
- missing/invalid token -> `401`: `auth.middleware.ts:34-45`, `:87-94`

The middleware also tries to upsert the authenticated user into `users`:

- `auth.middleware.ts:57-79`

Important behavior:

- if that DB write fails, it logs the failure and still continues to the route handler.

### `/account/me`

The account route in `backend/src/routes/account.routes.ts:9-50` tries to read from `users`, but if the read fails with messages such as:

- `no such table: users`
- `fetch failed`
- `connection`
- `timeout`

it logs the error and falls back to `req.auth_user` instead:

- `account.routes.ts:14-31`
- `account.routes.ts:96-104`

This means `/account/me` can return `200 OK` even when persistent user-table access is broken.

### `/sync/pull`

The sync pull route lives at `backend/src/routes/sync.routes.ts:34-110`.

It returns:

- `server_time`
- `notes`
- `folders`
- `tags`
- `deleted_notes`
- `deleted_folders`
- `deleted_tags`

Payload serialization uses:

- `backend/src/utils/api_response.ts:13-55`

### `/sync/push`

The push route lives at `backend/src/routes/sync.routes.ts:112-291`.

It validates:

- body is a JSON object,
- arrays are arrays,
- payload counts do not exceed sync limits,
- each note/folder/tag/delete record matches validation rules.

Validation is defined in:

- `backend/src/utils/note_validation.ts:120-329`

Writes happen inside a single write transaction:

- `backend/src/routes/sync.routes.ts:296-316`

That transaction covers:

- folders,
- tags,
- notes,
- deleted notes,
- deleted folders,
- deleted tags.

### Backend test evidence

`backend/package.json:11-14` defines:

- `test:validation`
- `test:routes`
- combined `test`

Running `npm test` in `backend/` during this audit passed all 10 backend tests, including:

- health route,
- auth rejection,
- rate limiting,
- CORS rejection,
- `/sync/push` transaction rollback,
- folder-delete normalization logic.

Evidence is also present in `backend/tests/app.test.js:129-461`.

## 5. Frontend vs Backend Contract Comparison

| Area | Frontend Behavior | Backend Expectation | Match? | Evidence |
|---|---|---|---|---|
| Base API origin | Uses canonical `https://api.unicef.edu.eu.org` and validates it at bootstrap | Deployed host responds at that origin | Yes | `lib/core/config/app_env.dart:21-28`, `:97-133`; manual health probe on 2026-06-01 |
| Health route | Calls `GET /health` before every sync | Public `GET /health` exists and returns JSON | Yes, but shallow | `authenticated_api_client.dart:105-115`; `backend/src/app.ts:162-176` |
| Sync auth | Sends `Authorization: Bearer <Firebase ID token>` | Requires bearer token on `/sync/*` | Yes | `authenticated_api_client.dart:233-241`; `auth.middleware.ts:34-45`, `:96-108` |
| Push route | Calls `POST /sync/push` with `notes`, `folders`, `tags`, and delete arrays | Accepts exactly those arrays | Yes | `sync_controller.dart:200-203`, `:610-649`; `sync.routes.ts:122-155` |
| Pull route | Calls `GET /sync/pull?since=...` | Supports optional `since` query param | Yes | `sync_controller.dart:207-214`; `sync.routes.ts:34-42` |
| Note fields | Sends `id`, `title`, `content`, `folder_id`, `tags`, booleans, timestamps | Validates those fields as optional sync note payload fields | Yes | `sync_controller.dart:678-697`; `note_validation.ts:46-50`, `:120-167`, `:332-453` |
| Folder fields | Sends `id`, `name`, `color_key`, `emoji`, timestamps | Expects same fields | Yes | `sync_controller.dart:700-709`; `note_validation.ts:52-60`, `:169-238` |
| Tag fields | Sends `id`, `label`, `emoji`, timestamps | Expects same fields | Yes | `sync_controller.dart:711-718`; `note_validation.ts:61-67`, `:240-298` |
| Delete fields | Sends `id`, `deleted_at` | Expects same fields | Yes | `sync_delete_operation.dart`; `note_validation.ts:69-72`, `:300-329` |
| Pull response fields | Expects `server_time`, note/folder/tag arrays, deleted arrays | Returns exactly those keys | Yes | `SyncPullPayload.fromJson` at `sync_controller.dart:543-607`; `sync.routes.ts:84-105` |
| HTTP status handling | Treats 4xx/5xx as API failures, not transport failures | Returns structured JSON errors | Yes | `authenticated_api_client.dart:244-352`; `api_response.ts:1-11` |
| User-observed error text | `"ThinkNote could not reach the server..."` | Only reachable from transport-failure classification, not normal JSON error responses | Partial mismatch with current live host health | `sync_controller.dart:434-462`; live `/health` and `/sync/pull` probes on 2026-06-01 |

## 6. Authentication/User Context Analysis

### What auth the client uses

The Flutter app gets the current Firebase user and requests ID tokens from:

- `lib/features/auth/data/repositories/firebase_auth_repository.dart:22-34`

The auth header is attached in:

- `lib/core/network/authenticated_api_client.dart:233-241`

### What happens when auth is missing or invalid

- missing Firebase user on client -> `StateError` before request (`firebase_auth_repository.dart:23-31`)
- `401` from backend -> client retries once with a refreshed token, then signs out if still unauthorized (`authenticated_api_client.dart:155-173`)
- sync controller maps auth failures to:
  - `SyncErrorType.authentication`
  - user-facing text: `Your session expired. Sign in again to resume sync...`

Evidence:

- `sync_controller.dart:396-416`

### Important auth-side blind spot

The backend auth middleware logs but **does not fail** if the `users` upsert fails:

- `backend/src/middleware/auth.middleware.ts:57-79`

Then `/account/me` may still return `200 OK` using `req.auth_user` fallback:

- `backend/src/routes/account.routes.ts:14-45`, `:96-104`

This creates a false-positive "auth is fine" signal for the client even when persistent backend user storage is broken.

### Current conclusion

There is no static evidence that the frontend is omitting the bearer token. Auth is wired correctly in code. The remaining unresolved auth questions are runtime-only:

- whether the deployed backend has working Firebase Admin credentials,
- whether the failing client receives a valid Firebase ID token,
- whether the deployed DB schema supports authenticated writes.

## 7. Queue and Retry Mechanism Analysis

### Where queued work lives

Notes are queued implicitly by local `syncStatus` values:

- `pendingCreate`
- `pendingUpdate`

Delete operations are queued explicitly in SQLite `sync_queue`:

- schema: `lib/core/database/app_database.dart:272-281`
- read: `notes_local_datasource.dart:154-166`
- clear: `notes_local_datasource.dart:168-176`, `:457-470`
- failure count update: `notes_local_datasource.dart:178-189`, `:472-494`

### Retry scheduling

Backoff is exponential:

- starts at 30 seconds,
- doubles,
- caps at 15 minutes.

Evidence:

- `lib/features/sync/presentation/controllers/sync_controller.dart:671-675`

Sync metadata persists in `sync_state`:

- `last_server_sync_at`
- `sync_retry_after`
- `sync_failure_count`

Evidence:

- `sync_controller.dart:721-723`
- `notes_local_datasource.dart:122-146`, `:191-225`

### Does the queue retry?

Yes, based on current source:

- after note/folder/tag mutations,
- after connectivity returns,
- after app resume,
- on the periodic timer,
- on manual sync.

There is no static evidence that queued notes are dropped prematurely. Unsynced notes remain eligible for future pushes because `_pushedNoteVersions()` includes every note whose `syncStatus != synced`:

- `sync_controller.dart:507-511`

### Queue risk not directly causing the current failure

The queueing model appears functionally sound in source. The failure is more likely happening before or during remote I/O rather than in local queue persistence.

## 8. Error Handling Analysis

### Exact source of the reported message

The exact text:

```text
ThinkNote could not reach the server. Your changes stay queued and will retry automatically.
```

comes from:

- `lib/features/sync/presentation/controllers/sync_controller.dart:456-460`

That branch is only used when `AuthenticatedApiClient` classified the failure as `ApiFailureKind.serverUnreachable`.

### How the client classifies failures

Relevant mappings:

- DNS -> `authenticated_api_client.dart:367-374`
- TLS/SSL -> `:357-365`
- connection refused/reset/closed/broken pipe -> `:376-384`
- generic no-internet -> `:386-397`
- HTTP 401/403/404/409/429/500 -> `:320-352`

The sync UI label comes from:

- `describeSyncErrorType()` in `sync_controller.dart:377-393`

### What the quoted message rules out

If the quoted message is from the current code path, it rules out all of these as the **direct** failure source for that sync attempt:

- backend `401 Unauthorized`
- backend `403`
- backend `404`
- backend `409`
- backend `429`
- backend `500`
- backend validation JSON errors
- malformed JSON response

Those would all surface different `ApiException` types and different user-visible messages.

### Confirmed diagnostic weakness

The app does not currently surface:

- the failing endpoint,
- the HTTP status code when available,
- the backend `x-request-id`,
- whether the failure happened on `/health`, `/sync/push`, or `/sync/pull`.

That makes operational debugging much harder than it needs to be.

## 9. Backend Database and Persistence Analysis

### Schema

The backend schema includes:

- `users`
- `folders`
- `tags`
- `notes`
- `note_tags`
- `deleted_entities`
- `sync_state`

Evidence:

- `backend/src/db/schema.sql:1-86`

### Sync writes

Writes are transactional in `/sync/push`:

- `backend/src/routes/sync.routes.ts:268-280`
- transaction helper at `:296-316`

Existing tests confirm rollback behavior:

- `backend/tests/app.test.js:406-460`

### Important persistence blind spots

1. `/health` does not validate schema existence.
2. auth middleware ignores failures to upsert into `users`.
3. `/account/me` can still succeed when `users` reads fail.

That combination allows:

- backend health to appear normal,
- authenticated startup to appear normal,
- sync writes to fail only later, deeper in `/sync/push`.

### What is not confirmed

This audit did **not** prove that the deployed production database is missing tables or failing writes. It only confirmed that the current codebase would allow that failure mode to slip past `/health` and `/account/me`.

## 10. Deployment/Environment Findings

### Live backend status on June 1, 2026

Confirmed live behavior:

- `/health` reachable and healthy at about **08:21 UTC**
- `/sync/pull` mounted and enforcing auth at about **08:23 UTC**

This disproves:

- dead domain,
- missing HTTPS,
- missing `/sync` route prefix,
- obvious "website instead of API" misrouting.

### Production env requirements

Backend docs require:

- `TURSO_DATABASE_URL`
- `TURSO_AUTH_TOKEN`
- Firebase Admin credentials
- `CORS_ALLOWED_ORIGINS` for browser deployments

Evidence:

- `backend/README.md:63-69`
- `backend/src/auth/firebase_admin.ts:19-37`
- `backend/src/db/turso_client.ts:6-12`
- `backend/src/app.ts:212-237`

### Browser-origin risk

For production browser traffic, the backend will reject disallowed origins:

- `backend/src/app.ts:92-116`
- error response at `backend/src/app.ts:136-145`

Tests confirm this behavior:

- `backend/tests/app.test.js:266-284`

This means a Flutter web deployment can fail even while native mobile sync works, if the real frontend origin is missing from `CORS_ALLOWED_ORIGINS`.

### Deployment observability gap

The repo contains backend code and docs but no checked-in Render-style deployment manifest proving:

- schema push execution,
- exact production env vars,
- exact allowed origins,
- Firebase Admin credential source.

That keeps deployment parity in the "needs runtime verification" bucket.

## 11. Confirmed Root Causes

The audit did **not** confirm a single static code mismatch like "wrong route" or "wrong base URL." The confirmed causes and blockers are:

### 11.1 P0 - The failing client experienced a transport-level failure before any HTTP response

- Severity: `P0`
- Evidence:
  - the user-reported text exactly matches `lib/features/sync/presentation/controllers/sync_controller.dart:456-460`
  - that branch is only used after `ApiFailureKind.serverUnreachable`
  - the current live backend host was reachable on June 1, 2026 via `/health`
- Affected files:
  - `lib/features/sync/presentation/controllers/sync_controller.dart`
  - `lib/core/network/authenticated_api_client.dart`
- Why it breaks sync:
  - sync stops before `/sync/push` or `/sync/pull` can complete, so dirty notes remain queued locally
- What must be fixed later:
  - capture the raw device/runtime error for the failing client context
  - surface endpoint and request diagnostics in the app
  - verify whether the failing context is Android, iOS, or web

### 11.2 P1 - Backend readiness checks are shallow enough to allow a broken sync backend to appear healthy

- Severity: `P1`
- Evidence:
  - `/health` only runs `SELECT datetime('now')` in `backend/src/app.ts:162-176`
  - auth middleware suppresses `users` upsert failures in `backend/src/middleware/auth.middleware.ts:57-79`
  - `/account/me` falls back to `req.auth_user` on DB read failures in `backend/src/routes/account.routes.ts:14-31`, `:96-104`
  - backend tests during this audit still returned `200` for `/account/me` even when a profile-cache/database read failed
- Affected files:
  - `backend/src/app.ts`
  - `backend/src/middleware/auth.middleware.ts`
  - `backend/src/routes/account.routes.ts`
- Why it breaks sync:
  - the app can pass startup checks and believe the backend is available even when sync persistence is not actually ready
- What must be fixed later:
  - add a sync-readiness health check
  - stop swallowing user-table failures silently
  - make `/account/me` distinguish degraded DB state from a healthy account response

### 11.3 P2 - Configuration sources are internally inconsistent and can mislead operators or ad hoc builds

- Severity: `P2`
- Evidence:
  - `.env.example:4` still points to `http://10.0.2.2:3000`
  - `.env.example:14` still says `ENABLE_EXPERIMENTAL_SYNC=false`
  - runtime code hard-enables sync in `lib/core/config/app_env.dart:69`
  - runtime bootstrap rejects non-canonical API origins in `lib/core/config/app_env.dart:128-133`
- Affected files:
  - `.env.example`
  - `lib/core/config/app_env.dart`
  - `scripts/android/build_release_artifacts.sh`
  - `scripts/android/build_release_artifacts.ps1`
- Why it breaks sync:
  - it creates conflicting operator expectations about whether sync is toggleable and which API host is valid
- What must be fixed later:
  - align the example env file, docs, and runtime behavior
  - either honor `ENABLE_EXPERIMENTAL_SYNC` everywhere or remove it from docs/scripts

## 12. Suspected Issues Requiring Runtime Verification

These remain unresolved without a real authenticated client session or production deployment access:

1. Whether the deployed backend has valid Firebase Admin credentials and accepts real client ID tokens.
2. Whether the deployed database has the full sync schema applied (`users`, `notes`, `folders`, `tags`, `deleted_entities`, `sync_state`), not just a reachable SQL connection.
3. Whether the failing client was a Flutter web build blocked by `CORS_ALLOWED_ORIGINS`.
4. Whether the failing device/browser had a local firewall, VPN, DNS, captive portal, or network policy causing connection resets or refused connections.
5. Whether the failure was transient and happened during a short backend networking incident that had recovered by June 1, 2026.
6. Whether the exact user-visible text came from the current build or from an older build with slightly different sync labeling.

## 13. Recommended Fix Plan

### Phase 1 - Capture the real failing runtime evidence

1. Reproduce the failure on the exact device/build where sync currently fails.
2. Log and surface:
   - failing endpoint (`/health`, `/sync/push`, `/sync/pull`)
   - raw exception type/message
   - HTTP status code when present
   - backend `x-request-id` header
3. Record the exact build flavor, platform, and `API_URL` value in diagnostic output.

### Phase 2 - Harden backend readiness signals

1. Replace the shallow health probe with a sync-readiness check that verifies:
   - database connectivity
   - required tables exist
   - authenticated write path is operational
2. Stop silently swallowing `users` upsert failures in auth middleware.
3. Make `/account/me` return a degraded or failing status when account persistence is broken instead of always falling back to `req.auth_user`.

### Phase 3 - Verify production deployment

1. Confirm production `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN`.
2. Confirm production Firebase Admin credentials.
3. Confirm `db:push` or equivalent schema migration was actually run.
4. Confirm `CORS_ALLOWED_ORIGINS` includes the real web app origin if Flutter web is in scope.

### Phase 4 - Clean up configuration drift

1. Update root `.env.example` to match the current canonical API and sync posture.
2. Remove or correctly wire `ENABLE_EXPERIMENTAL_SYNC`.
3. Keep README, scripts, and example env files consistent.

### Phase 5 - Improve client-side diagnostics and resilience

1. Preserve the offline queue behavior.
2. Distinguish transport, auth, CORS, validation, and backend-write failures in the UI.
3. Consider a temporary developer diagnostics screen that shows last sync request metadata.

## 14. Validation Plan After Fixes

1. Sign in with a real Firebase account and verify `/account/me` succeeds without fallback behavior.
2. Create a note and confirm:
   - it is stored locally,
   - `/sync/push` returns `200`,
   - `/sync/pull` returns the note,
   - the note becomes `synced`.
3. Edit the same note and confirm remote update propagation.
4. Delete the note and confirm the delete tombstone clears the local queue.
5. Disable network, create/edit/delete notes, then reconnect and confirm the queue drains automatically.
6. Run the same validation on:
   - Android
   - one browser build, if web is supported
7. Force `401`, `403`, `404`, and `500` cases and confirm the UI shows the correct failure type instead of a generic transport message.
8. For web, verify CORS on the real deployed frontend origin.

## 15. Files That Will Likely Need Changes

- `lib/features/sync/presentation/controllers/sync_controller.dart`
- `lib/core/network/authenticated_api_client.dart`
- `lib/core/config/app_env.dart`
- `.env.example`
- `backend/src/app.ts`
- `backend/src/middleware/auth.middleware.ts`
- `backend/src/routes/account.routes.ts`
- `backend/src/routes/sync.routes.ts`
- `backend/src/db/schema.sql`
- `backend/README.md`
- `scripts/android/build_release_artifacts.sh`
- `scripts/android/build_release_artifacts.ps1`

## 16. Final Notes

The current codebase already answers several high-value questions:

- the app is **not** pointed at a stale or malformed production API origin by default,
- the sync route paths and payload shapes line up,
- the live production host is currently reachable,
- queued local changes are not obviously being dropped before sync.

What is still missing is decisive runtime evidence from an authenticated failing client. The safest next implementation step is **not** to rewrite the sync contract. It is to harden readiness checks and expose enough request-level diagnostics to prove whether the remaining blocker is:

- device/browser transport,
- Firebase auth verification,
- missing production schema,
- or browser-origin policy.

## 17. Implementation Progress - June 1, 2026

Started implementation from this audit and completed the first code-backed
hardening pass:

- Client sync preflight now uses authenticated `GET /sync/readiness` instead
  of the shallow public `/health` endpoint.
- `ApiException` now carries request method, endpoint, HTTP status,
  backend `x-request-id`, and raw transport error details when available.
- Manual sync failure messages now include a diagnostics line with the captured
  request metadata while preserving local queue retry behavior.
- Backend auth now fails closed with `503` when authenticated user persistence
  cannot be written.
- `/account/me` now returns a failing/degraded account persistence response
  instead of falling back to Firebase profile data when the account table cannot
  be read.
- Backend exposes authenticated `GET /sync/readiness`, verifying required sync
  tables, the authenticated user row, and a benign `sync_state` write.
- Root `.env.example`, release scripts, and Play release checklist no longer
  advertise `ENABLE_EXPERIMENTAL_SYNC` as a release toggle.

Verification completed:

- `npm.cmd test` in `backend/` passed all 11 backend tests.
- `dart --disable-analytics analyze` passed with no issues.
- `git diff --check` passed without whitespace errors.

Still requiring runtime verification:

- Reproduce sync on the failing real device/build and capture the new
  diagnostics line.
- Confirm production deployment has Firebase Admin credentials, full Turso
  schema, and correct `CORS_ALLOWED_ORIGINS` for any Flutter web origin.
- Flutter wrapper-based tests could not be run in this session because
  `flutter.bat` hung even on `--version`; the direct Dart analyzer path worked.
