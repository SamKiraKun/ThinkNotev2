import { Router } from "express";

import { firebaseAuth } from "../auth/firebase_admin";
import { db } from "../db/turso_client";
import { errorResponse, successResponse } from "../utils/api_response";

const router = Router();

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
