import { randomUUID } from "crypto";
import { Router } from "express";

import { db } from "../db/turso_client";
import {
  deletedEntityFromRow,
  errorResponse,
  folderFromRow,
  noteFromRow,
  successResponse,
  tagFromRow,
} from "../utils/api_response";
import {
  notePayloadLimits,
  validateSyncDeletePayload,
  validateSyncFolderPayload,
  validateSyncNotePayload,
  validateSyncTagPayload,
} from "../utils/note_validation";
import type {
  ValidatedSyncDeletePayload,
  ValidatedSyncFolderPayload,
  ValidatedSyncNotePayload,
  ValidatedSyncTagPayload,
} from "../utils/note_validation";

type SyncDatabaseClient = Pick<typeof db, "execute" | "transaction">;
type SyncSqlExecutor = Pick<SyncDatabaseClient, "execute">;
type SyncTransaction = Awaited<ReturnType<SyncDatabaseClient["transaction"]>>;

const requiredSyncTables = [
  "users",
  "folders",
  "tags",
  "notes",
  "note_tags",
  "deleted_entities",
  "sync_state",
];

export function createSyncRouter(database: SyncDatabaseClient = db) {
  const router = Router();

  router.get("/readiness", async (req, res) => {
    try {
      const now = new Date().toISOString();
      await assertRequiredSyncTables(database);

      const userResult = await database.execute({
        sql: `SELECT id FROM users WHERE id = ? LIMIT 1`,
        args: [req.user_id],
      });
      if (userResult.rows.length !== 1) {
        throw new Error("Authenticated user is missing from users table");
      }

      await database.execute({
        sql: `
          INSERT INTO sync_state (user_id, key, value, updated_at)
          VALUES (?, ?, ?, ?)
          ON CONFLICT(user_id, key) DO UPDATE SET
            value = excluded.value,
            updated_at = excluded.updated_at
        `,
        args: [req.user_id, "__readiness_probe", now, now],
      });

      res.json(
        successResponse({
          status: "ready",
          server_time: now,
          tables: requiredSyncTables,
        }),
      );
    } catch (error) {
      console.error(error);
      res.status(503).json(errorResponse("Sync backend is not ready"));
    }
  });

  router.get("/pull", async (req, res) => {
    try {
      const userId = req.user_id;
      const since = typeof req.query.since === "string" ? req.query.since : null;
      const noteArgs = since ? [userId, since] : [userId];
      const noteSinceFilter = since ? "AND updated_at > ?" : "";
      const deletedArgs = since ? [userId, since] : [userId];
      const deletedSinceFilter = since ? "AND deleted_at > ?" : "";

      const [notesResult, foldersResult, tagsResult, deletedResult] = await Promise.all([
        database.execute({
          sql: `
            SELECT * FROM notes
            WHERE user_id = ? ${noteSinceFilter}
            ORDER BY updated_at ASC
          `,
          args: noteArgs,
        }),
        database.execute({
          sql: `
            SELECT * FROM folders
            WHERE user_id = ?
            ORDER BY created_at ASC
          `,
          args: [userId],
        }),
        database.execute({
          sql: `
            SELECT * FROM tags
            WHERE user_id = ?
            ORDER BY created_at ASC
          `,
          args: [userId],
        }),
        database.execute({
          sql: `
            SELECT * FROM deleted_entities
            WHERE user_id = ? ${deletedSinceFilter}
            ORDER BY deleted_at ASC
          `,
          args: deletedArgs,
        }),
      ]);

      const noteIds = notesResult.rows.map((row) => String(row.id));
      const noteTags = await loadNoteTagsByNoteId(database, userId, noteIds);
      const deletedEntities = deletedResult.rows.map((row) =>
        deletedEntityFromRow(row as Record<string, unknown>),
      );

      res.json(
        successResponse({
          server_time: new Date().toISOString(),
          notes: notesResult.rows.map((row) =>
            noteFromRow(
              row as Record<string, unknown>,
              noteTags[String(row.id)] ?? [],
            ),
          ),
          folders: foldersResult.rows.map((row) =>
            folderFromRow(row as Record<string, unknown>),
          ),
          tags: tagsResult.rows.map((row) =>
            tagFromRow(row as Record<string, unknown>),
          ),
          deleted_notes: deletedEntities.filter((item) => item.entity_type === "note"),
          deleted_folders: deletedEntities.filter(
            (item) => item.entity_type === "folder",
          ),
          deleted_tags: deletedEntities.filter((item) => item.entity_type === "tag"),
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
      const body = req.body ?? {};
      if (body === null || typeof body !== "object" || Array.isArray(body)) {
        return res
          .status(400)
          .json(errorResponse("Request body must be a JSON object"));
      }

      const rawNotes = (body as Record<string, unknown>).notes;
      const rawFolders = (body as Record<string, unknown>).folders;
      const rawTags = (body as Record<string, unknown>).tags;
      const rawDeletedNotes = (body as Record<string, unknown>).deleted_notes;
      const rawDeletedFolders = (body as Record<string, unknown>).deleted_folders;
      const rawDeletedTags = (body as Record<string, unknown>).deleted_tags;

      if (rawNotes !== undefined && !Array.isArray(rawNotes)) {
        return res.status(400).json(errorResponse("notes must be an array"));
      }
      if (rawFolders !== undefined && !Array.isArray(rawFolders)) {
        return res.status(400).json(errorResponse("folders must be an array"));
      }
      if (rawTags !== undefined && !Array.isArray(rawTags)) {
        return res.status(400).json(errorResponse("tags must be an array"));
      }
      if (rawDeletedNotes !== undefined && !Array.isArray(rawDeletedNotes)) {
        return res.status(400).json(errorResponse("deleted_notes must be an array"));
      }
      if (rawDeletedFolders !== undefined && !Array.isArray(rawDeletedFolders)) {
        return res.status(400).json(errorResponse("deleted_folders must be an array"));
      }
      if (rawDeletedTags !== undefined && !Array.isArray(rawDeletedTags)) {
        return res.status(400).json(errorResponse("deleted_tags must be an array"));
      }

      const notes = Array.isArray(rawNotes) ? rawNotes : [];
      const folders = Array.isArray(rawFolders) ? rawFolders : [];
      const tags = Array.isArray(rawTags) ? rawTags : [];
      const deletedNotes = Array.isArray(rawDeletedNotes) ? rawDeletedNotes : [];
      const deletedFolders = Array.isArray(rawDeletedFolders)
        ? rawDeletedFolders
        : [];
      const deletedTags = Array.isArray(rawDeletedTags) ? rawDeletedTags : [];

      if (notes.length > notePayloadLimits.syncNotesPerPush) {
        return res.status(400).json(
          errorResponse(
            `notes must contain ${notePayloadLimits.syncNotesPerPush} items or fewer`,
          ),
        );
      }
      if (folders.length > notePayloadLimits.syncFoldersPerPush) {
        return res.status(400).json(
          errorResponse(
            `folders must contain ${notePayloadLimits.syncFoldersPerPush} items or fewer`,
          ),
        );
      }
      if (tags.length > notePayloadLimits.syncTagsPerPush) {
        return res.status(400).json(
          errorResponse(
            `tags must contain ${notePayloadLimits.syncTagsPerPush} items or fewer`,
          ),
        );
      }
      if (deletedNotes.length > notePayloadLimits.syncDeletesPerPush) {
        return res.status(400).json(
          errorResponse(
            `deleted_notes must contain ${notePayloadLimits.syncDeletesPerPush} items or fewer`,
          ),
        );
      }
      if (deletedFolders.length > notePayloadLimits.syncDeletesPerPush) {
        return res.status(400).json(
          errorResponse(
            `deleted_folders must contain ${notePayloadLimits.syncDeletesPerPush} items or fewer`,
          ),
        );
      }
      if (deletedTags.length > notePayloadLimits.syncDeletesPerPush) {
        return res.status(400).json(
          errorResponse(
            `deleted_tags must contain ${notePayloadLimits.syncDeletesPerPush} items or fewer`,
          ),
        );
      }

      const validatedNotes: ValidatedSyncNotePayload[] = [];
      for (let index = 0; index < notes.length; index += 1) {
        const validated = validateSyncNotePayload(notes[index]);
        if (!validated.ok) {
          return res
            .status(400)
            .json(errorResponse(`notes[${index}]: ${validated.message}`));
        }
        validatedNotes.push(validated.value);
      }

      const validatedFolders: ValidatedSyncFolderPayload[] = [];
      for (let index = 0; index < folders.length; index += 1) {
        const validated = validateSyncFolderPayload(folders[index]);
        if (!validated.ok) {
          return res
            .status(400)
            .json(errorResponse(`folders[${index}]: ${validated.message}`));
        }
        validatedFolders.push(validated.value);
      }

      const validatedTags: ValidatedSyncTagPayload[] = [];
      for (let index = 0; index < tags.length; index += 1) {
        const validated = validateSyncTagPayload(tags[index]);
        if (!validated.ok) {
          return res
            .status(400)
            .json(errorResponse(`tags[${index}]: ${validated.message}`));
        }
        validatedTags.push(validated.value);
      }

      const validatedDeletedNotes: ValidatedSyncDeletePayload[] = [];
      for (let index = 0; index < deletedNotes.length; index += 1) {
        const validated = validateSyncDeletePayload(deletedNotes[index]);
        if (!validated.ok) {
          return res.status(400).json(
            errorResponse(`deleted_notes[${index}]: ${validated.message}`),
          );
        }
        validatedDeletedNotes.push(validated.value);
      }

      const validatedDeletedFolders: ValidatedSyncDeletePayload[] = [];
      for (let index = 0; index < deletedFolders.length; index += 1) {
        const validated = validateSyncDeletePayload(deletedFolders[index]);
        if (!validated.ok) {
          return res.status(400).json(
            errorResponse(`deleted_folders[${index}]: ${validated.message}`),
          );
        }
        validatedDeletedFolders.push(validated.value);
      }

      const validatedDeletedTags: ValidatedSyncDeletePayload[] = [];
      for (let index = 0; index < deletedTags.length; index += 1) {
        const validated = validateSyncDeletePayload(deletedTags[index]);
        if (!validated.ok) {
          return res.status(400).json(
            errorResponse(`deleted_tags[${index}]: ${validated.message}`),
          );
        }
        validatedDeletedTags.push(validated.value);
      }

      const now = new Date().toISOString();

      await withWriteTransaction(database, async (transaction) => {
        await syncFolders(transaction, userId, validatedFolders, now);
        await syncTags(transaction, userId, validatedTags, now);
        await syncNotes(transaction, userId, validatedNotes, now);
        await syncDeletedNotes(transaction, userId, validatedDeletedNotes, now);
        await syncDeletedFolders(
          transaction,
          userId,
          validatedDeletedFolders,
          now,
        );
        await syncDeletedTags(transaction, userId, validatedDeletedTags, now);
      });

      res.json(
        successResponse({
          server_time: now,
        }),
      );
    } catch (error) {
      console.error(error);
      res.status(500).json(errorResponse("Failed to push sync changes"));
    }
  });

  return router;
}

async function withWriteTransaction<T>(
  database: SyncDatabaseClient,
  operation: (transaction: SyncTransaction) => Promise<T>,
) {
  const transaction = await database.transaction("write");

  try {
    const result = await operation(transaction);
    await transaction.commit();
    return result;
  } catch (error) {
    if (!transaction.closed) {
      await transaction.rollback().catch((rollbackError) => {
        console.error("Failed to roll back sync transaction", rollbackError);
      });
    }
    throw error;
  } finally {
    transaction.close();
  }
}

async function assertRequiredSyncTables(database: SyncSqlExecutor) {
  const result = await database.execute({
    sql: `
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name IN (${requiredSyncTables.map(() => "?").join(", ")})
    `,
    args: requiredSyncTables,
  });
  const presentTables = new Set(result.rows.map((row) => String(row.name)));
  const missingTables = requiredSyncTables.filter(
    (tableName) => !presentTables.has(tableName),
  );

  if (missingTables.length > 0) {
    throw new Error(
      `Sync schema is missing required tables: ${missingTables.join(", ")}`,
    );
  }
}

async function syncFolders(
  database: SyncSqlExecutor,
  userId: string,
  folders: ValidatedSyncFolderPayload[],
  now: string,
) {
  for (const folder of folders) {
    if (await hasDeletionTombstone(database, userId, "folder", folder.id)) {
      continue;
    }

    const createdAt = folder.created_at ?? now;
    const updatedAt = folder.updated_at ?? createdAt;

    await database.execute({
      sql: `
        INSERT INTO folders (
          id, user_id, name, emoji, color_key, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          emoji = excluded.emoji,
          color_key = excluded.color_key,
          updated_at = excluded.updated_at
        WHERE folders.user_id = excluded.user_id
          AND folders.updated_at <= excluded.updated_at
      `,
      args: [
        folder.id,
        userId,
        folder.name,
        folder.emoji ?? "",
        folder.color_key ?? "personal",
        createdAt,
        updatedAt,
      ],
    });
  }
}

async function syncTags(
  database: SyncSqlExecutor,
  userId: string,
  tags: ValidatedSyncTagPayload[],
  now: string,
) {
  for (const tag of tags) {
    if (await hasDeletionTombstone(database, userId, "tag", tag.id)) {
      continue;
    }

    const createdAt = tag.created_at ?? now;
    const updatedAt = tag.updated_at ?? createdAt;

    await database.execute({
      sql: `
        INSERT INTO tags (
          id, user_id, name, emoji, color_key, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          emoji = excluded.emoji,
          updated_at = excluded.updated_at
        WHERE tags.user_id = excluded.user_id
          AND tags.updated_at <= excluded.updated_at
      `,
      args: [
        tag.id,
        userId,
        tag.label,
        tag.emoji ?? "",
        "personal",
        createdAt,
        updatedAt,
      ],
    });
  }
}

async function syncNotes(
  database: SyncSqlExecutor,
  userId: string,
  notes: ValidatedSyncNotePayload[],
  now: string,
) {
  const deletedFolderIds = await loadDeletedEntityIds(database, userId, "folder");
  const availableFolderIds = await loadFolderIds(database, userId);
  const deletedTagLabels = await loadDeletedTagLabels(database, userId);

  for (const note of notes) {
    const id = note.id ?? randomUUID();
    if (await hasDeletionTombstone(database, userId, "note", id)) {
      continue;
    }

    const updatedAt = note.updated_at ?? now;
    const createdAt = note.created_at ?? updatedAt;
    const title = note.title ?? "";
    const content = note.content ?? "";
    const normalizedFolderId =
      note.folder_id == null || note.folder_id === ""
        ? null
        : deletedFolderIds.has(note.folder_id) ||
            !availableFolderIds.has(note.folder_id)
          ? null
          : note.folder_id;
    const noteTags = (note.tags ?? []).filter(
      (label) => !deletedTagLabels.has(label.trim().toLowerCase()),
    );

    if (!title && !content.trim()) {
      continue;
    }

    await database.execute({
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
          AND notes.updated_at <= excluded.updated_at
      `,
      args: [
        id,
        userId,
        title,
        content,
        note.excerpt ?? content.slice(0, 160),
        note.category ?? "Personal",
        normalizedFolderId,
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

    await database.execute({
      sql: `DELETE FROM note_tags WHERE note_id = ?`,
      args: [id],
    });

    for (const label of noteTags) {
      const tagId = await ensureTagExists(database, userId, label, now);
      await database.execute({
        sql: `
          INSERT OR REPLACE INTO note_tags (note_id, tag_id)
          VALUES (?, ?)
        `,
        args: [id, tagId],
      });
    }
  }
}

async function syncDeletedNotes(
  database: SyncSqlExecutor,
  userId: string,
  notes: ValidatedSyncDeletePayload[],
  now: string,
) {
  for (const note of notes) {
    const deletedAt = note.deleted_at ?? now;
    await recordDeletionTombstone(database, userId, "note", note.id, deletedAt);
    await database.execute({
      sql: `DELETE FROM note_tags WHERE note_id = ?`,
      args: [note.id],
    });
    await database.execute({
      sql: `DELETE FROM notes WHERE id = ? AND user_id = ?`,
      args: [note.id, userId],
    });
  }
}

async function syncDeletedFolders(
  database: SyncSqlExecutor,
  userId: string,
  folders: ValidatedSyncDeletePayload[],
  now: string,
) {
  for (const folder of folders) {
    const deletedAt = folder.deleted_at ?? now;
    await recordDeletionTombstone(database, userId, "folder", folder.id, deletedAt);
    await database.execute({
      sql: `
        UPDATE notes
        SET folder_id = NULL,
            updated_at = ?
        WHERE folder_id = ? AND user_id = ?
      `,
      args: [now, folder.id, userId],
    });
    await database.execute({
      sql: `DELETE FROM folders WHERE id = ? AND user_id = ?`,
      args: [folder.id, userId],
    });
  }
}

async function syncDeletedTags(
  database: SyncSqlExecutor,
  userId: string,
  tags: ValidatedSyncDeletePayload[],
  now: string,
) {
  for (const tag of tags) {
    const deletedAt = tag.deleted_at ?? now;
    const existing = await database.execute({
      sql: `SELECT name FROM tags WHERE id = ? AND user_id = ? LIMIT 1`,
      args: [tag.id, userId],
    });
    const existingLabel = existing.rows[0]?.name
      ? String(existing.rows[0].name)
      : null;

    await recordDeletionTombstone(
      database,
      userId,
      "tag",
      tag.id,
      deletedAt,
      existingLabel == null ? undefined : { label: existingLabel },
    );
    await database.execute({
      sql: `DELETE FROM note_tags WHERE tag_id = ?`,
      args: [tag.id],
    });
    await database.execute({
      sql: `DELETE FROM tags WHERE id = ? AND user_id = ?`,
      args: [tag.id, userId],
    });
  }
}

async function hasDeletionTombstone(
  database: SyncSqlExecutor,
  userId: string,
  entityType: string,
  entityId: string,
) {
  const result = await database.execute({
    sql: `
      SELECT 1
      FROM deleted_entities
      WHERE user_id = ? AND entity_type = ? AND entity_id = ?
      LIMIT 1
    `,
    args: [userId, entityType, entityId],
  });

  return result.rows.length > 0;
}

async function loadDeletedEntityIds(
  database: SyncSqlExecutor,
  userId: string,
  entityType: string,
) {
  const result = await database.execute({
    sql: `
      SELECT entity_id
      FROM deleted_entities
      WHERE user_id = ? AND entity_type = ?
    `,
    args: [userId, entityType],
  });

  return new Set(result.rows.map((row) => String(row.entity_id)));
}

async function loadFolderIds(database: SyncSqlExecutor, userId: string) {
  const result = await database.execute({
    sql: `
      SELECT id
      FROM folders
      WHERE user_id = ?
    `,
    args: [userId],
  });

  return new Set(result.rows.map((row) => String(row.id)));
}

async function loadDeletedTagLabels(database: SyncSqlExecutor, userId: string) {
  const result = await database.execute({
    sql: `
      SELECT payload_json
      FROM deleted_entities
      WHERE user_id = ? AND entity_type = 'tag'
    `,
    args: [userId],
  });

  const labels = new Set<string>();
  for (const row of result.rows) {
    const rawPayload = row.payload_json;
    if (typeof rawPayload !== "string" || !rawPayload) {
      continue;
    }

    try {
      const payload = JSON.parse(rawPayload) as { label?: string };
      const label = payload.label?.trim().toLowerCase();
      if (label) {
        labels.add(label);
      }
    } catch {
      continue;
    }
  }

  return labels;
}

async function recordDeletionTombstone(
  database: SyncSqlExecutor,
  userId: string,
  entityType: string,
  entityId: string,
  deletedAt: string,
  payload: Record<string, unknown> = {},
) {
  await database.execute({
    sql: `
      INSERT INTO deleted_entities (
        user_id, entity_type, entity_id, deleted_at, payload_json
      ) VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(user_id, entity_type, entity_id) DO UPDATE SET
        deleted_at = excluded.deleted_at,
        payload_json = excluded.payload_json
      WHERE deleted_entities.deleted_at <= excluded.deleted_at
    `,
    args: [userId, entityType, entityId, deletedAt, JSON.stringify(payload)],
  });
}

async function ensureTagExists(
  database: SyncSqlExecutor,
  userId: string,
  label: string,
  now: string,
) {
  const existing = await database.execute({
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
  await database.execute({
    sql: `
      INSERT INTO tags (id, user_id, name, emoji, color_key, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `,
    args: [tagId, userId, label, "#", "personal", now, now],
  });
  return tagId;
}

async function loadNoteTagsByNoteId(
  database: SyncSqlExecutor,
  userId: string,
  noteIds: string[],
) {
  if (noteIds.length === 0) {
    return {} as Record<string, string[]>;
  }

  const placeholders = noteIds.map(() => "?").join(", ");
  const result = await database.execute({
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
    const label = String(row.name);
    const values = tagsByNoteId[noteId] ?? [];
    values.push(label);
    tagsByNoteId[noteId] = values;
  }

  return tagsByNoteId;
}

const router = createSyncRouter();

export default router;
