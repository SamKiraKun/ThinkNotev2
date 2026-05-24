import { randomUUID } from "crypto";
import { Request, Response, Router } from "express";

import { db } from "../db/turso_client";
import {
  errorResponse,
  noteFromRow,
  successResponse,
} from "../utils/api_response";
import {
  validateCreateNotePayload,
  validatePatchNotePayload,
} from "../utils/note_validation";

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

    const noteIds = result.rows.map((row) => String(row.id));
    const tagsByNoteId = await loadNoteTagsByNoteIds(userId, noteIds);

    res.json(
      successResponse(
        result.rows.map((row) =>
          noteFromRow(
            row as Record<string, unknown>,
            tagsByNoteId[String(row.id)] ?? [],
          ),
        ),
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

    const tagsByNoteId = await loadNoteTagsByNoteIds(req.user_id, [
      String(req.params.id),
    ]);

    return res.json(
      successResponse(
        noteFromRow(
          result.rows[0] as Record<string, unknown>,
          tagsByNoteId[String(req.params.id)] ?? [],
        ),
      ),
    );
  } catch (error) {
    console.error(error);
    return res.status(500).json(errorResponse("Failed to fetch note"));
  }
});

router.post("/", async (req, res) => {
  try {
    const validatedPayload = validateCreateNotePayload(req.body ?? {});
    if (!validatedPayload.ok) {
      return res.status(400).json(errorResponse(validatedPayload.message));
    }

    const {
      title,
      content,
      excerpt,
      category,
      tags,
      folder_id,
      color_key,
      emoji,
    } = validatedPayload.value;
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
        title,
        content,
        excerpt ?? content.slice(0, 160),
        category ?? "Personal",
        folder_id ?? null,
        color_key ?? "personal",
        emoji ?? "",
        now,
        now,
      ],
    });

    if (tags && tags.length > 0) {
      await replaceNoteTags(id, req.user_id, tags, now);
    }

    const created = await db.execute({
      sql: "SELECT * FROM notes WHERE id = ? AND user_id = ?",
      args: [id, req.user_id],
    });

    return res.status(201).json(
      successResponse(
        noteFromRow(created.rows[0] as Record<string, unknown>, tags ?? []),
      ),
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

    const validatedPayload = validatePatchNotePayload(req.body ?? {});
    if (!validatedPayload.ok) {
      return res.status(400).json(errorResponse(validatedPayload.message));
    }
    if (Object.keys(validatedPayload.value).length === 0) {
      return res
        .status(400)
        .json(errorResponse("At least one note field is required"));
    }

    const current = existing.rows[0] as Record<string, unknown>;
    const {
      title,
      content,
      excerpt,
      category,
      tags,
      folder_id,
      color_key,
      emoji,
      is_pinned,
      is_favorite,
      is_archived,
      is_deleted,
      deleted_at,
    } = validatedPayload.value;
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
        title !== undefined ? title : rowString(current.title),
        content !== undefined ? content : rowString(current.content),
        excerpt !== undefined ? excerpt : rowString(current.excerpt),
        category !== undefined ? category : rowString(current.category),
        folder_id !== undefined
          ? folder_id
          : rowNullableString(current.folder_id),
        color_key !== undefined ? color_key : rowString(current.color_key),
        emoji !== undefined ? emoji : rowString(current.emoji),
        is_pinned !== undefined
          ? (is_pinned ? 1 : 0)
          : rowInteger(current.is_pinned),
        is_favorite !== undefined
          ? (is_favorite ? 1 : 0)
          : rowInteger(current.is_favorite),
        is_archived !== undefined
          ? (is_archived ? 1 : 0)
          : rowInteger(current.is_archived),
        is_deleted !== undefined
          ? (is_deleted ? 1 : 0)
          : rowInteger(current.is_deleted),
        deleted_at !== undefined
          ? deleted_at
          : rowNullableString(current.deleted_at),
        now,
        req.params.id,
        req.user_id,
      ],
    });

    if (tags !== undefined) {
      await replaceNoteTags(req.params.id, req.user_id, tags, now);
    }

    const updated = await db.execute({
      sql: "SELECT * FROM notes WHERE id = ? AND user_id = ?",
      args: [req.params.id, req.user_id],
    });

    const resolvedTags =
      tags ??
      (await loadNoteTagsByNoteIds(req.user_id, [String(req.params.id)]))[
        String(req.params.id)
      ] ??
      [];

    return res.json(
      successResponse(
        noteFromRow(updated.rows[0] as Record<string, unknown>, resolvedTags),
      ),
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
  const validatedPayload = validatePatchNotePayload(req.body ?? {});
  if (!validatedPayload.ok) {
    return res.status(400).json(errorResponse(validatedPayload.message));
  }

  if (validatedPayload.value.is_pinned === undefined) {
    return res.status(400).json(errorResponse("is_pinned must be provided"));
  }

  return updateBooleanState(req, res, {
    is_pinned: validatedPayload.value.is_pinned ? 1 : 0,
  });
});

router.patch("/:id/favorite", async (req, res) => {
  const validatedPayload = validatePatchNotePayload(req.body ?? {});
  if (!validatedPayload.ok) {
    return res.status(400).json(errorResponse(validatedPayload.message));
  }

  if (validatedPayload.value.is_favorite === undefined) {
    return res.status(400).json(errorResponse("is_favorite must be provided"));
  }

  return updateBooleanState(req, res, {
    is_favorite: validatedPayload.value.is_favorite ? 1 : 0,
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

    const tagsByNoteId = await loadNoteTagsByNoteIds(req.user_id, [noteId]);
    return res.json(
      successResponse(
        noteFromRow(
          updated.rows[0] as Record<string, unknown>,
          tagsByNoteId[noteId] ?? [],
        ),
      ),
    );
  } catch (error) {
    console.error(error);
    return res.status(500).json(errorResponse("Failed to update note state"));
  }
}

async function loadNoteTagsByNoteIds(userId: string, noteIds: string[]) {
  if (noteIds.length === 0) {
    return {} as Record<string, string[]>;
  }

  const placeholders = noteIds.map(() => "?").join(", ");
  const result = await db.execute({
    sql: `
      SELECT nt.note_id, t.name
      FROM note_tags nt
      INNER JOIN tags t ON t.id = nt.tag_id
      WHERE t.user_id = ?
        AND nt.note_id IN (${placeholders})
      ORDER BY t.created_at ASC
    `,
    args: [userId, ...noteIds],
  });

  const tagsByNoteId: Record<string, string[]> = {};
  for (const row of result.rows) {
    const noteId = String(row.note_id);
    const tags = tagsByNoteId[noteId] ?? [];
    tags.push(String(row.name));
    tagsByNoteId[noteId] = tags;
  }

  return tagsByNoteId;
}

async function replaceNoteTags(
  noteId: string,
  userId: string,
  tags: string[],
  now: string,
) {
  await db.execute({
    sql: `DELETE FROM note_tags WHERE note_id = ?`,
    args: [noteId],
  });

  for (const label of tags) {
    const normalizedLabel = label.trim();
    if (!normalizedLabel) {
      continue;
    }

    const tagId = await ensureTagExists(userId, normalizedLabel, now);
    await db.execute({
      sql: `
        INSERT OR REPLACE INTO note_tags (note_id, tag_id)
        VALUES (?, ?)
      `,
      args: [noteId, tagId],
    });
  }
}

async function ensureTagExists(userId: string, label: string, now: string) {
  const existing = await db.execute({
    sql: `
      SELECT id FROM tags
      WHERE user_id = ? AND lower(name) = lower(?)
      LIMIT 1
    `,
    args: [userId, label],
  });

  if (existing.rows[0]?.id) {
    return String(existing.rows[0].id);
  }

  const tagId = randomUUID();
  await db.execute({
    sql: `
      INSERT INTO tags (id, user_id, name, emoji, color_key, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `,
    args: [tagId, userId, label, "#", "personal", now, now],
  });
  return tagId;
}

function rowString(value: unknown) {
  return typeof value === "string" ? value : "";
}

function rowNullableString(value: unknown) {
  return typeof value === "string" ? value : null;
}

function rowInteger(value: unknown) {
  return typeof value === "number" ? value : 0;
}

export default router;
