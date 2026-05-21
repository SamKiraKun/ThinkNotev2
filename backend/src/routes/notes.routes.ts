import { Router } from "express";
import { db } from "../db/turso_client";
import { v4 as uuidv4 } from "uuid";

const router = Router();

// Helper to format responses
const successResponse = (data: any, message: string | null = null) => ({
  success: true,
  data,
  message
});

const errorResponse = (message: string) => ({
  success: false,
  data: null,
  message
});

// GET /notes
router.get("/", async (req, res) => {
  try {
    const userId = (req as any).user_id; // from mock middleware
    const result = await db.execute({
      sql: "SELECT * FROM notes WHERE user_id = ? AND is_deleted = 0 ORDER BY is_pinned DESC, updated_at DESC",
      args: [userId]
    });
    
    // Map SQLite results (0/1) back to booleans for the frontend
    const notes = result.rows.map(r => ({
      ...r,
      is_pinned: r.is_pinned === 1,
      is_favorite: r.is_favorite === 1,
      is_archived: r.is_archived === 1,
      is_deleted: r.is_deleted === 1
    }));
    
    res.json(successResponse(notes));
  } catch (error) {
    console.error(error);
    res.status(500).json(errorResponse("Failed to fetch notes"));
  }
});

// GET /notes/:id
router.get("/:id", async (req, res) => {
  try {
    const userId = (req as any).user_id;
    const { id } = req.params;
    const result = await db.execute({
      sql: "SELECT * FROM notes WHERE id = ? AND user_id = ? AND is_deleted = 0",
      args: [id, userId]
    });
    
    if (result.rows.length === 0) {
      return res.status(404).json(errorResponse("Note not found"));
    }
    
    const r = result.rows[0];
    const note = {
      ...r,
      is_pinned: r.is_pinned === 1,
      is_favorite: r.is_favorite === 1,
      is_archived: r.is_archived === 1,
      is_deleted: r.is_deleted === 1
    };
    
    res.json(successResponse(note));
  } catch (error) {
    console.error(error);
    res.status(500).json(errorResponse("Failed to fetch note"));
  }
});

// POST /notes
router.post("/", async (req, res) => {
  try {
    const userId = (req as any).user_id;
    const { title, content, excerpt, category, color_key, emoji } = req.body;
    
    if (!title) {
        return res.status(400).json(errorResponse("Title is required"));
    }
    
    const id = uuidv4();
    const now = new Date().toISOString();
    
    await db.execute({
      sql: `INSERT INTO notes (
        id, user_id, title, content, excerpt, category, color_key, emoji, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      args: [
        id, userId, title,
        content || "",
        excerpt || "",
        category || "Personal",
        color_key || "personal",
        emoji || "💜",
        now, now
      ]
    });
    
    const created = await db.execute({ sql: "SELECT * FROM notes WHERE id = ?", args: [id] });
    
    const r = created.rows[0];
    res.status(201).json(successResponse({
      ...r,
      is_pinned: r.is_pinned === 1,
      is_favorite: r.is_favorite === 1,
      is_archived: r.is_archived === 1,
      is_deleted: r.is_deleted === 1
    }));
  } catch (error) {
    console.error(error);
    res.status(500).json(errorResponse("Failed to create note"));
  }
});

// PATCH /notes/:id
router.patch("/:id", async (req, res) => {
  try {
    const userId = (req as any).user_id;
    const { id } = req.params;
    
    const existing = await db.execute({ sql: "SELECT * FROM notes WHERE id = ? AND user_id = ? AND is_deleted = 0", args: [id, userId] });
    if (existing.rows.length === 0) {
      return res.status(404).json(errorResponse("Note not found"));
    }
    
    const { title, content, excerpt, category, color_key, emoji, is_pinned, is_favorite, is_archived } = req.body;
    const now = new Date().toISOString();
    
    const current = existing.rows[0] as any;
    
    await db.execute({
      sql: `UPDATE notes SET 
        title = ?, content = ?, excerpt = ?, category = ?, color_key = ?, emoji = ?, 
        is_pinned = ?, is_favorite = ?, is_archived = ?, updated_at = ?
        WHERE id = ? AND user_id = ?`,
      args: [
        title !== undefined ? title : current.title,
        content !== undefined ? content : current.content,
        excerpt !== undefined ? excerpt : current.excerpt,
        category !== undefined ? category : current.category,
        color_key !== undefined ? color_key : current.color_key,
        emoji !== undefined ? emoji : current.emoji,
        is_pinned !== undefined ? (is_pinned ? 1 : 0) : current.is_pinned,
        is_favorite !== undefined ? (is_favorite ? 1 : 0) : current.is_favorite,
        is_archived !== undefined ? (is_archived ? 1 : 0) : current.is_archived,
        now,
        id, userId
      ]
    });
    
    const updatedResult = await db.execute({ sql: "SELECT * FROM notes WHERE id = ?", args: [id] });
    const r = updatedResult.rows[0];
    res.json(successResponse({
        ...r,
        is_pinned: r.is_pinned === 1,
        is_favorite: r.is_favorite === 1,
        is_archived: r.is_archived === 1,
        is_deleted: r.is_deleted === 1
      }));
  } catch (error) {
    console.error(error);
    res.status(500).json(errorResponse("Failed to update note"));
  }
});

// DELETE /notes/:id (soft delete)
router.delete("/:id", async (req, res) => {
  try {
    const userId = (req as any).user_id;
    const { id } = req.params;
    const now = new Date().toISOString();
    
    await db.execute({
      sql: "UPDATE notes SET is_deleted = 1, deleted_at = ? WHERE id = ? AND user_id = ?",
      args: [now, id, userId]
    });
    
    res.json(successResponse(null, "Note deleted successfully"));
  } catch (error) {
    console.error(error);
    res.status(500).json(errorResponse("Failed to delete note"));
  }
});

// PATCH /notes/:id/pin
router.patch("/:id/pin", async (req, res) => {
    try {
        const userId = (req as any).user_id;
        const { id } = req.params;
        const { is_pinned } = req.body;
        const now = new Date().toISOString();

        await db.execute({
            sql: "UPDATE notes SET is_pinned = ?, updated_at = ? WHERE id = ? AND user_id = ?",
            args: [is_pinned ? 1 : 0, now, id, userId]
        });

        const updatedResult = await db.execute({ sql: "SELECT * FROM notes WHERE id = ?", args: [id] });
        const r = updatedResult.rows[0];
        res.json(successResponse({
            ...r,
            is_pinned: r.is_pinned === 1,
            is_favorite: r.is_favorite === 1,
            is_archived: r.is_archived === 1,
            is_deleted: r.is_deleted === 1
        }));
    } catch (error) {
        console.error(error);
        res.status(500).json(errorResponse("Failed to update pin state"));
    }
});

export default router;
