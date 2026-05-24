import express from "express";
import { randomUUID } from "crypto";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import dotenv from "dotenv";

import accountRoutes from "./routes/account.routes";
import notesRoutes from "./routes/notes.routes";
import syncRoutes from "./routes/sync.routes";
import { db } from "./db/turso_client";
import { requireFirebaseAuth } from "./middleware/auth.middleware";
import {
  createRateLimitMiddleware,
  parsePositiveInteger,
} from "./middleware/rate_limit.middleware";
import { errorResponse } from "./utils/api_response";

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const isProduction = process.env.NODE_ENV === "production";
const allowedOrigins = process.env.CORS_ALLOWED_ORIGINS
  ?.split(",")
  .map((entry) => entry.trim())
  .filter(Boolean) ?? [];
const corsAllowNoOrigin =
  process.env.CORS_ALLOW_NO_ORIGIN === "true" || !isProduction;
const rateLimitWindowMs = parsePositiveInteger(
  process.env.RATE_LIMIT_WINDOW_MS,
  60_000,
);
const ipRateLimit = createRateLimitMiddleware({
  keyPrefix: "ip",
  maxRequests: parsePositiveInteger(process.env.IP_RATE_LIMIT_MAX, 300),
  windowMs: rateLimitWindowMs,
  keyForRequest: (req) => req.ip ?? req.socket.remoteAddress ?? "unknown",
});
const userRateLimit = createRateLimitMiddleware({
  keyPrefix: "user",
  maxRequests: parsePositiveInteger(process.env.USER_RATE_LIMIT_MAX, 120),
  windowMs: rateLimitWindowMs,
  keyForRequest: (req) => req.user_id,
});

if (isProduction) {
  app.set("trust proxy", 1);
}

app.use((req, res, next) => {
  const requestIdHeader = req.header("x-request-id")?.trim();
  req.request_id = requestIdHeader || randomUUID();
  res.setHeader("x-request-id", req.request_id);
  next();
});

morgan.token(
  "request-id",
  (req) => (req as express.Request).request_id || "unknown",
);
morgan.token(
  "user-id",
  (req) => (req as express.Request).user_id || "anonymous",
);

app.use(helmet());
app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin) {
        callback(null, corsAllowNoOrigin);
        return;
      }

      if (!allowedOrigins.length) {
        if (isProduction) {
          callback(new Error("CORS_ALLOWED_ORIGINS is not configured"));
          return;
        }

        callback(null, true);
        return;
      }

      if (allowedOrigins.includes(origin)) {
        callback(null, true);
        return;
      }

      callback(new Error("CORS origin is not allowed"));
    },
  }),
);
app.use(express.json({ limit: process.env.JSON_BODY_LIMIT ?? "256kb" }));
app.use(
  morgan(
    isProduction
      ? ':request-id :remote-addr :method :url :status :res[content-length] - :response-time ms user=:user-id'
      : ':method :url :status :response-time ms req=:request-id user=:user-id',
  ),
);

app.use(
  (
    error: unknown,
    req: express.Request,
    res: express.Response,
    next: express.NextFunction,
  ) => {
    const requestError = error as { message?: string; type?: string };

    if (requestError.message === "CORS origin is not allowed") {
      res.status(403).json(errorResponse("Origin is not allowed by CORS"));
      return;
    }

    if (requestError.message === "CORS_ALLOWED_ORIGINS is not configured") {
      res
        .status(500)
        .json(errorResponse("CORS_ALLOWED_ORIGINS is not configured"));
      return;
    }

    if (requestError.type === "entity.too.large") {
      res.status(413).json(errorResponse("Request body is too large"));
      return;
    }

    if (error instanceof SyntaxError) {
      res.status(400).json(errorResponse("Invalid JSON request body"));
      return;
    }

    next(error);
  },
);

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

app.use("/notes", ipRateLimit, requireFirebaseAuth, userRateLimit, notesRoutes);
app.use("/sync", ipRateLimit, requireFirebaseAuth, userRateLimit, syncRoutes);
app.use(
  "/account",
  ipRateLimit,
  requireFirebaseAuth,
  userRateLimit,
  accountRoutes,
);

app.use(
  (
    error: unknown,
    req: express.Request,
    res: express.Response,
    next: express.NextFunction,
  ) => {
    if (res.headersSent) {
      next(error);
      return;
    }

    console.error("Unhandled request error:", error);
    res.status(500).json(errorResponse("Unexpected server error"));
  },
);

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
