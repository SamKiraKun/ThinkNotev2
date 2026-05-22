import { randomUUID } from "crypto";
import { Request, Response, Router } from "express";

import { db } from "../db/turso_client";
import { errorResponse, noteFromRow, successResponse } from "../utils/api_response";

const router = Router();

router.get("/", async (req, res) => {
  try {
    const userId = req.user_id;
    const includeArchived = req.query.include_archived === "true";
    const includeDeleted = req.query.include_deleted === "true";

    const result = await db.execute({
      sql: `
        SELECT * FROM notes
        WHERE user_id = ?
          AND (? = 1 OR is_deleted = 0)
          AND (? = 1 OR is_archived = 0)
        ORDER BY is_pinned DESC, updated_at DESC
      `,
      args: [userId, includeDeleted ? 1 : 0, includeArchived ? 1 : 0],
    });

    res.json(
      successResponse(
        result.rows.map((row) => noteFromRow(row as Record<string, unknown>)),
      ),
    );
  } catch (error) {
    console.error(error);
    res.status(500).json(errorResponse("Failed to fetch notes"));
  }
});

router.get("/:id", async (req, res) => {
  try {
    const result = await db.execute({
      sql: "SELECT * FROM notes WHERE id = ? AND user_id = ?",
      args: [req.params.id, req.user_id],
    });

    if (result.rows.length === 0) {
      return res.status(404).json(errorResponse("Note not found"));
    }

    return res.json(
      successResponse(noteFromRow(result.rows[0] as Record<string, unknown>)),
    );
  } catch (error) {
    console.error(error);
    return res.status(500).json(errorResponse("Failed to fetch note"));
  }
});

router.post("/", async (req, res) => {
  try {
    const { title, content, excerpt, category, folder_id, color_key, emoji } =
      req.body ?? {};
    const normalizedTitle = typeof title === "string" ? title.trim() : "";
    const normalizedContent = typeof content === "string" ? content : "";

    if (!normalizedTitle && !normalizedContent.trim()) {
      return res
        .status(400)
        .json(errorResponse("Title or content is required"));
    }

    const id = randomUUID();
    const now = new Date().toISOString();

    await db.execute({
      sql: `
        INSERT INTO notes (
          id, user_id, title, content, excerpt, category, folder_id, color_key,
          emoji, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      args: [
        id,
        req.user_id,
        normalizedTitle,
        normalizedContent,
        excerpt ?? normalizedContent.slice(0, 160),
        category ?? "Personal",
        folder_id ?? null,
        color_key ?? "personal",
        emoji ?? "",
        now,
        now,
      ],
    });

    const created = await db.execute({
      sql: "SELECT * FROM notes WHERE id = ? AND user_id = ?",
      args: [id, req.user_id],
    });

    return res.status(201).json(
      successResponse(noteFromRow(created.rows[0] as Record<string, unknown>)),
    );
  } catch (error) {
    console.error(error);
    return res.status(500).json(errorResponse("Failed to create note"));
  }
});

router.patch("/:id", async (req, res) => {
  try {
    const existing = await db.execute({
      sql: "SELECT * FROM notes WHERE id = ? AND user_id = ?",
      args: [req.params.id, req.user_id],
    });
    if (existing.rows.length === 0) {
      return res.status(404).json(errorResponse("Note not found"));
    }

    const current = existing.rows[0] as Record<string, unknown>;
    const {
      title,
      content,
      excerpt,
      category,
      folder_id,
      color_key,
      emoji,
      is_pinned,
      is_favorite,
      is_archived,
      is_deleted,
      deleted_at,
    } = req.body ?? {};
    const now = new Date().toISOString();

    await db.execute({
      sql: `
        UPDATE notes SET
          title = ?, content = ?, excerpt = ?, category = ?, folder_id = ?,
          color_key = ?, emoji = ?, is_pinned = ?, is_favorite = ?,
          is_archived = ?, is_deleted = ?, deleted_at = ?, updated_at = ?
        WHERE id = ? AND user_id = ?
      `,
      args: [
        title !== undefined ? title : current.title,
        content !== undefined ? content : current.content,
        excerpt !== undefined ? excerpt : current.excerpt,
        category !== undefined ? category : current.category,
        folder_id !== undefined ? folder_id : current.folder_id,
        color_key !== undefined ? color_key : current.color_key,
        emoji !== undefined ? emoji : current.emoji,
        is_pinned !== undefined ? (is_pinned ? 1 : 0) : current.is_pinned,
        is_favorite !== undefined
          ? (is_favorite ? 1 : 0)
          : current.is_favorite,
        is_archived !== undefined
          ? (is_archived ? 1 : 0)
          : current.is_archived,
        is_deleted !== undefined ? (is_deleted ? 1 : 0) : current.is_deleted,
        deleted_at !== undefined ? deleted_at : current.deleted_at,
        now,
        req.params.id,
        req.user_id,
      ],
    });

    const updated = await db.execute({
      sql: "SELECT * FROM notes WHERE id = ? AND user_id = ?",
      args: [req.params.id, req.user_id],
    });

    return res.json(
      successResponse(noteFromRow(updated.rows[0] as Record<string, unknown>)),
    );
  } catch (error) {
    console.error(error);
    return res.status(500).json(errorResponse("Failed to update note"));
  }
});

router.delete("/:id", async (req, res) => {
  try {
    const now = new Date().toISOString();
    await db.execute({
      sql: `
        UPDATE notes
        SET is_deleted = 1, is_archived = 0, is_pinned = 0,
            deleted_at = ?, updated_at = ?
        WHERE id = ? AND user_id = ?
      `,
      args: [now, now, req.params.id, req.user_id],
    });

    return res.json(successResponse(null, "Note moved to Trash"));
  } catch (error) {
    console.error(error);
    return res.status(500).json(errorResponse("Failed to delete note"));
  }
});

router.patch("/:id/restore", async (req, res) => {
  return updateBooleanState(req, res, {
    is_deleted: 0,
    deleted_at: null,
  });
});

router.patch("/:id/archive", async (req, res) => {
  return updateBooleanState(req, res, {
    is_archived: 1,
    is_deleted: 0,
    is_pinned: 0,
    deleted_at: null,
  });
});

router.patch("/:id/unarchive", async (req, res) => {
  return updateBooleanState(req, res, {
    is_archived: 0,
  });
});

router.patch("/:id/pin", async (req, res) => {
  return updateBooleanState(req, res, {
    is_pinned: req.body?.is_pinned ? 1 : 0,
  });
});

router.patch("/:id/favorite", async (req, res) => {
  return updateBooleanState(req, res, {
    is_favorite: req.body?.is_favorite ? 1 : 0,
  });
});

async function updateBooleanState(
  req: Request,
  res: Response,
  fields: Record<string, string | number | null>,
) {
  try {
    const now = new Date().toISOString();
    const noteId = String(req.params.id);
    const assignments = [
      ...Object.keys(fields).map((key) => `${key} = ?`),
      "updated_at = ?",
    ].join(", ");
    const args: Array<string | number | null> = [
      ...Object.values(fields),
      now,
      noteId,
      req.user_id,
    ];

    await db.execute({
      sql: `UPDATE notes SET ${assignments} WHERE id = ? AND user_id = ?`,
      args,
    });

    const updated = await db.execute({
      sql: "SELECT * FROM notes WHERE id = ? AND user_id = ?",
      args: [noteId, req.user_id],
    });

    if (updated.rows.length === 0) {
      return res.status(404).json(errorResponse("Note not found"));
    }

    return res.json(
      successResponse(noteFromRow(updated.rows[0] as Record<string, unknown>)),
    );
  } catch (error) {
    console.error(error);
    return res.status(500).json(errorResponse("Failed to update note state"));
  }
}

export default router;
