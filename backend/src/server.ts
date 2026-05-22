import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import dotenv from "dotenv";

import notesRoutes from "./routes/notes.routes";
import syncRoutes from "./routes/sync.routes";
import { db } from "./db/turso_client";
import { requireFirebaseAuth } from "./middleware/auth.middleware";

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(helmet());
app.use(cors({
  origin: (origin, callback) => {
    const allowedOrigins = process.env.CORS_ALLOWED_ORIGINS
      ?.split(",")
      .map((entry) => entry.trim())
      .filter(Boolean);

    if (!origin || !allowedOrigins?.length || allowedOrigins.includes(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error("Origin is not allowed by CORS"));
  },
}));
app.use(express.json());
app.use(morgan("dev"));

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

app.use("/notes", requireFirebaseAuth, notesRoutes);
app.use("/sync", requireFirebaseAuth, syncRoutes);

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
