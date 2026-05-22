import { randomUUID } from "crypto";
import { Router } from "express";

import { db } from "../db/turso_client";
import { errorResponse, noteFromRow, successResponse } from "../utils/api_response";

const router = Router();

type SyncNotePayload = {
  id?: string;
  title?: string;
  content?: string;
  excerpt?: string;
  folder_id?: string | null;
  category?: string;
  color_key?: string;
  emoji?: string;
  is_pinned?: boolean;
  is_favorite?: boolean;
  is_archived?: boolean;
  is_deleted?: boolean;
  created_at?: string;
  updated_at?: string;
  deleted_at?: string | null;
};

router.get("/pull", async (req, res) => {
  try {
    const userId = req.user_id;
    const since = typeof req.query.since === "string" ? req.query.since : null;
    const sinceFilter = since ? "AND updated_at > ?" : "";
    const args = since ? [userId, since] : [userId];

    const [notes, folders, tags] = await Promise.all([
      db.execute({
        sql: `
          SELECT * FROM notes
          WHERE user_id = ? ${sinceFilter}
          ORDER BY updated_at ASC
        `,
        args,
      }),
      db.execute({
        sql: `
          SELECT * FROM folders
          WHERE user_id = ? ${sinceFilter}
          ORDER BY updated_at ASC
        `,
        args,
      }),
      db.execute({
        sql: `
          SELECT * FROM tags
          WHERE user_id = ? ${sinceFilter}
          ORDER BY updated_at ASC
        `,
        args,
      }),
    ]);

    res.json(
      successResponse({
        server_time: new Date().toISOString(),
        notes: notes.rows.map((row) => noteFromRow(row as Record<string, unknown>)),
        folders: folders.rows,
        tags: tags.rows,
      }),
    );
  } catch (error) {
    console.error(error);
    res.status(500).json(errorResponse("Failed to pull sync changes"));
  }
});

router.post("/push", async (req, res) => {
  try {
    const userId = req.user_id;
    const notes = Array.isArray(req.body?.notes)
      ? (req.body.notes as SyncNotePayload[])
      : [];
    const now = new Date().toISOString();
    const pushedNotes = [];

    for (const note of notes) {
      const id = note.id ?? randomUUID();
      const updatedAt = note.updated_at ?? now;
      const createdAt = note.created_at ?? updatedAt;
      const title = note.title?.trim() ?? "";
      const content = note.content ?? "";

      if (!title && !content.trim()) {
        continue;
      }

      await db.execute({
        sql: `
          INSERT INTO notes (
            id, user_id, title, content, excerpt, category, folder_id, color_key,
            emoji, is_pinned, is_favorite, is_archived, is_deleted, created_at,
            updated_at, deleted_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            content = excluded.content,
            excerpt = excluded.excerpt,
            category = excluded.category,
            folder_id = excluded.folder_id,
            color_key = excluded.color_key,
            emoji = excluded.emoji,
            is_pinned = excluded.is_pinned,
            is_favorite = excluded.is_favorite,
            is_archived = excluded.is_archived,
            is_deleted = excluded.is_deleted,
            updated_at = excluded.updated_at,
            deleted_at = excluded.deleted_at
          WHERE notes.user_id = excluded.user_id
        `,
        args: [
          id,
          userId,
          title,
          content,
          note.excerpt ?? content.slice(0, 160),
          note.category ?? "Personal",
          note.folder_id ?? null,
          note.color_key ?? "personal",
          note.emoji ?? "",
          note.is_pinned ? 1 : 0,
          note.is_favorite ? 1 : 0,
          note.is_archived ? 1 : 0,
          note.is_deleted ? 1 : 0,
          createdAt,
          updatedAt,
          note.deleted_at ?? null,
        ],
      });

      const updated = await db.execute({
        sql: "SELECT * FROM notes WHERE id = ? AND user_id = ?",
        args: [id, userId],
      });
      if (updated.rows[0]) {
        pushedNotes.push(noteFromRow(updated.rows[0] as Record<string, unknown>));
      }
    }

    res.json(
      successResponse({
        server_time: now,
        notes: pushedNotes,
      }),
    );
  } catch (error) {
    console.error(error);
    res.status(500).json(errorResponse("Failed to push sync changes"));
  }
});

export default router;
