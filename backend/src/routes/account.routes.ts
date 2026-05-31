import { Router } from "express";

import { firebaseAuth } from "../auth/firebase_admin";
import { db } from "../db/turso_client";
import { errorResponse, successResponse } from "../utils/api_response";

const router = Router();

router.get("/me", async (req, res) => {
  try {
    const userId = req.user_id;
    let row: Record<string, unknown> | undefined;

    try {
      const result = await db.execute({
        sql: `
          SELECT id, email, name, avatar_url, created_at, updated_at
          FROM users
          WHERE id = ?
          LIMIT 1
        `,
        args: [userId],
      });
      row = result.rows[0] as Record<string, unknown> | undefined;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      if (!message.toLowerCase().includes("no such table: users")) {
        throw error;
      }
    }

    const user = {
      id: userId,
      email: (row?.email as string | null | undefined) ?? req.auth_user?.email ?? null,
      name: (row?.name as string | null | undefined) ?? req.auth_user?.name ?? null,
      avatar_url:
        (row?.avatar_url as string | null | undefined) ??
        req.auth_user?.avatarUrl ??
        null,
      created_at: (row?.created_at as string | null | undefined) ?? null,
      updated_at: (row?.updated_at as string | null | undefined) ?? null,
    };

    res.json(successResponse(user));
  } catch (error) {
    console.error(error);
    res.status(500).json(errorResponse("Failed to load account profile"));
  }
});

router.delete("/", async (req, res) => {
  try {
    const userId = req.user_id;

    await db.execute({
      sql: `DELETE FROM note_tags WHERE note_id IN (SELECT id FROM notes WHERE user_id = ?)`,
      args: [userId],
    });
    await db.execute({
      sql: `DELETE FROM notes WHERE user_id = ?`,
      args: [userId],
    });
    await db.execute({
      sql: `DELETE FROM folders WHERE user_id = ?`,
      args: [userId],
    });
    await db.execute({
      sql: `DELETE FROM tags WHERE user_id = ?`,
      args: [userId],
    });
    await db.execute({
      sql: `DELETE FROM sync_state WHERE user_id = ?`,
      args: [userId],
    });
    await db.execute({
      sql: `DELETE FROM deleted_entities WHERE user_id = ?`,
      args: [userId],
    });
    await db.execute({
      sql: `DELETE FROM users WHERE id = ?`,
      args: [userId],
    });

    await firebaseAuth().deleteUser(userId);

    res.json(successResponse(null, "Account deleted"));
  } catch (error) {
    console.error(error);
    res.status(500).json(errorResponse("Failed to delete account"));
  }
});

export default router;
