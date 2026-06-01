import { Router } from "express";

import { firebaseAuth } from "../auth/firebase_admin";
import { db } from "../db/turso_client";
import { errorResponse, successResponse } from "../utils/api_response";

type AccountDatabaseClient = Pick<typeof db, "execute">;

type AccountRouterDependencies = {
  database?: AccountDatabaseClient;
  deleteFirebaseUser?: (userId: string) => Promise<void>;
  logger?: Pick<Console, "error">;
};

export function createAccountRouter(
  dependencies: AccountRouterDependencies = {},
) {
  const router = Router();
  const database = dependencies.database ?? db;
  const deleteFirebaseUser =
    dependencies.deleteFirebaseUser ??
    ((userId: string) => firebaseAuth().deleteUser(userId));
  const logger = dependencies.logger ?? console;

  router.get("/me", async (req, res) => {
    try {
      const userId = req.user_id;
      const result = await readAccountRow(database, userId);
      const row = result.rows[0] as Record<string, unknown> | undefined;

      if (!row) {
        logger.error(
          `Authenticated account ${userId} was not present in account persistence.`,
        );
        res
          .status(503)
          .json(errorResponse("Account persistence is unavailable"));
        return;
      }

      const user = {
        id: userId,
        email: (row.email as string | null | undefined) ?? null,
        name: (row.name as string | null | undefined) ?? null,
        avatar_url: (row.avatar_url as string | null | undefined) ?? null,
        created_at: (row.created_at as string | null | undefined) ?? null,
        updated_at: (row.updated_at as string | null | undefined) ?? null,
      };

      res.json(successResponse(user));
    } catch (error) {
      logger.error(error);
      res.status(503).json(errorResponse("Account persistence is unavailable"));
    }
  });

  router.delete("/", async (req, res) => {
    try {
      const userId = req.user_id;

      await database.execute({
        sql: `DELETE FROM note_tags WHERE note_id IN (SELECT id FROM notes WHERE user_id = ?)`,
        args: [userId],
      });
      await database.execute({
        sql: `DELETE FROM notes WHERE user_id = ?`,
        args: [userId],
      });
      await database.execute({
        sql: `DELETE FROM folders WHERE user_id = ?`,
        args: [userId],
      });
      await database.execute({
        sql: `DELETE FROM tags WHERE user_id = ?`,
        args: [userId],
      });
      await database.execute({
        sql: `DELETE FROM sync_state WHERE user_id = ?`,
        args: [userId],
      });
      await database.execute({
        sql: `DELETE FROM deleted_entities WHERE user_id = ?`,
        args: [userId],
      });
      await database.execute({
        sql: `DELETE FROM users WHERE id = ?`,
        args: [userId],
      });

      await deleteFirebaseUser(userId);

      res.json(successResponse(null, "Account deleted"));
    } catch (error) {
      logger.error(error);
      res.status(500).json(errorResponse("Failed to delete account"));
    }
  });

  return router;
}

const router = createAccountRouter();

export default router;

async function readAccountRow(database: AccountDatabaseClient, userId: string) {
  try {
    return await database.execute({
      sql: `
        SELECT id, email, name, avatar_url, created_at, updated_at
        FROM users
        WHERE id = ?
        LIMIT 1
      `,
      args: [userId],
    });
  } catch (error) {
    if (!isUsersAvatarUrlColumnError(error)) {
      throw error;
    }

    return database.execute({
      sql: `
        SELECT id, email, name, NULL AS avatar_url, created_at, updated_at
        FROM users
        WHERE id = ?
        LIMIT 1
      `,
      args: [userId],
    });
  }
}

function isUsersAvatarUrlColumnError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  return (
    message.includes("table users has no column named avatar_url") ||
    message.includes("no such column: avatar_url")
  );
}
