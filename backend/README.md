# ThinkNote Backend

Node.js Backend using TursoDB (libSQL).

## Setup

1. Copy `.env.example` to `.env`
2. Update `TURSO_DATABASE_URL` and `TURSO_AUTH_TOKEN` (optional for local file DB).
3. Run `npm install`
4. Run `npm run db:push` to initialize the database scheme.
5. Run `npm run dev` to start the development server.

## API Endpoints

- `GET /notes`: List all notes
- `POST /notes`: Create a note
- `GET /notes/:id`: Get a note
- `PATCH /notes/:id`: Update a note
- `DELETE /notes/:id`: Soft delete a note
- `PATCH /notes/:id/pin`: Pin/unpin a note
