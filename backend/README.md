# ThinkNote Backend

Node.js Backend using TursoDB (libSQL).

## Setup

1. Copy `.env.example` to `.env`
2. Update `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` (optional for local file DB).
3. The example file already includes the Firebase project ID, database URL, and storage bucket for the current Android client config.
4. Add Firebase Admin credentials using either `FIREBASE_SERVICE_ACCOUNT_JSON`
   or `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, and `FIREBASE_PRIVATE_KEY`.
5. Run `npm install`
6. Run `npm run db:push` to initialize the database scheme.
7. Run `npm run dev` to start the development server.

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
