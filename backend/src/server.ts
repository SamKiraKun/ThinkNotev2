import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import dotenv from "dotenv";

import notesRoutes from "./routes/notes.routes";
import { db } from "./db/turso_client";

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(morgan("dev"));

// In a real app, you would have auth middleware that extracts user from valid JWT/session.
// For now, attaching a mock user_id to requests for demonstration.
app.use((req, res, next) => {
  (req as any).user_id = 'mock-user-id';
  next();
});

app.use("/notes", notesRoutes);

// Health check
app.get("/health", async (req, res) => {
  try {
    const time = await db.execute("SELECT datetime('now') AS time");
    res.json({ status: "ok", db: time.rows[0], message: "Backend is running!" });
  } catch (error) {
    console.error("DB connection error:", error);
    res.status(500).json({ status: "error", message: "Database connection failed" });
  }
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
