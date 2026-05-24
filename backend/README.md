# ThinkNote Backend

Node.js Backend using TursoDB (libSQL).

## Setup

1. Copy `backend/.env.example` to `backend/.env`
2. Update `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` (optional for local file DB).
3. Add Firebase Admin credentials using either `FIREBASE_SERVICE_ACCOUNT_JSON`
   or `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY`.
4. Set `CORS_ALLOWED_ORIGINS` for browser clients in deployed environments.
5. Run `npm install`
6. Run `npm run db:push` to initialize the database scheme.
7. Run `npm run dev` to start the development server.

## Checks

```bash
npm run build
npm test
```

## API Endpoints

- `GET /notes`: List all notes
- `POST /notes`: Create a note
- `GET /notes/:id`: Get a note
- `PATCH /notes/:id`: Update a note
- `DELETE /notes/:id`: Soft delete a note
- `PATCH /notes/:id/pin`: Pin/unpin a note
- `PATCH /notes/:id/favorite`: Favorite/unfavorite a note
- `PATCH /notes/:id/archive`: Archive a note
- `PATCH /notes/:id/unarchive`: Unarchive a note
- `PATCH /notes/:id/restore`: Restore a trashed note
- `GET /sync/pull?since=...`: Pull authenticated user changes
- `POST /sync/push`: Push local note mutations

All `/notes` and `/sync` endpoints require `Authorization: Bearer <Firebase ID token>`.

## Production controls

- `CORS_ALLOWED_ORIGINS`: comma-separated browser origins allowed in production.
- `CORS_ALLOW_NO_ORIGIN`: set to `true` only when a deployed native client needs requests without an `Origin` header.
- `JSON_BODY_LIMIT`: maximum JSON payload size, default `256kb`.
- `IP_RATE_LIMIT_MAX`: requests per IP per window, default `300`.
- `USER_RATE_LIMIT_MAX`: authenticated requests per Firebase UID per window, default `120`.
- `RATE_LIMIT_WINDOW_MS`: rate-limit window duration, default `60000`.

The API also enforces note payload limits before database writes:
titles are limited to 200 characters, note content to 100,000 characters,
excerpts to 500 characters, and sync pushes to 100 notes per request.
