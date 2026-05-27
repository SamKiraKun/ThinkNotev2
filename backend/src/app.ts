import { randomUUID } from "crypto";

import cors from "cors";
import dotenv from "dotenv";
import express, { RequestHandler, Router } from "express";
import helmet from "helmet";
import morgan from "morgan";

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

type DatabaseClient = Pick<typeof db, "execute">;

type Logger = Pick<Console, "error" | "log">;

type AppConfig = {
  port: string | number;
  isProduction: boolean;
  allowedOrigins: string[];
  corsAllowNoOrigin: boolean;
  rateLimitWindowMs: number;
  ipRateLimitMax: number;
  userRateLimitMax: number;
  jsonBodyLimit: string;
};

type AppOptions = {
  authMiddleware?: RequestHandler;
  notesRouter?: Router;
  syncRouter?: Router;
  accountRouter?: Router;
  dbClient?: DatabaseClient;
  logger?: Logger;
  config?: Partial<AppConfig>;
};

export function createApp(options: AppOptions = {}) {
  const config = loadConfig(options.config);
  const authMiddleware = options.authMiddleware ?? requireFirebaseAuth;
  const notesRouter = options.notesRouter ?? notesRoutes;
  const syncRouter = options.syncRouter ?? syncRoutes;
  const accountRouter = options.accountRouter ?? accountRoutes;
  const dbClient = options.dbClient ?? db;
  const logger = options.logger ?? console;

  const app = express();
  const ipRateLimit = createRateLimitMiddleware({
    keyPrefix: "ip",
    maxRequests: config.ipRateLimitMax,
    windowMs: config.rateLimitWindowMs,
    keyForRequest: (req) => req.ip ?? req.socket.remoteAddress ?? "unknown",
  });
  const userRateLimit = createRateLimitMiddleware({
    keyPrefix: "user",
    maxRequests: config.userRateLimitMax,
    windowMs: config.rateLimitWindowMs,
    keyForRequest: (req) => req.user_id,
  });

  if (config.isProduction) {
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
          callback(null, config.corsAllowNoOrigin);
          return;
        }

        if (!config.allowedOrigins.length) {
          if (config.isProduction) {
            callback(new Error("CORS_ALLOWED_ORIGINS is not configured"));
            return;
          }

          callback(null, true);
          return;
        }

        if (config.allowedOrigins.includes(origin)) {
          callback(null, true);
          return;
        }

        callback(new Error("CORS origin is not allowed"));
      },
    }),
  );
  app.use(express.json({ limit: config.jsonBodyLimit }));
  app.use(
    morgan(
      config.isProduction
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

  app.get("/health", async (req, res) => {
    try {
      const time = await dbClient.execute("SELECT datetime('now') AS time");
      res.json({
        status: "ok",
        db: time.rows[0],
        message: "Backend is running!",
      });
    } catch (error) {
      logger.error("DB connection error:", error);
      res
        .status(500)
        .json({ status: "error", message: "Database connection failed" });
    }
  });

  app.use("/notes", ipRateLimit, authMiddleware, userRateLimit, notesRouter);
  app.use("/sync", ipRateLimit, authMiddleware, userRateLimit, syncRouter);
  app.use(
    "/account",
    ipRateLimit,
    authMiddleware,
    userRateLimit,
    accountRouter,
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

      logger.error("Unhandled request error:", error);
      res.status(500).json(errorResponse("Unexpected server error"));
    },
  );

  return app;
}

export function resolveServerPort() {
  return process.env.PORT || 3000;
}

function loadConfig(overrides: Partial<AppConfig> = {}): AppConfig {
  const isProduction = overrides.isProduction ?? process.env.NODE_ENV === "production";
  return {
    port: overrides.port ?? process.env.PORT ?? 3000,
    isProduction,
    allowedOrigins:
      overrides.allowedOrigins ??
      process.env.CORS_ALLOWED_ORIGINS
        ?.split(",")
        .map((entry) => entry.trim())
        .filter(Boolean) ??
        [],
    corsAllowNoOrigin:
      overrides.corsAllowNoOrigin ??
      (process.env.CORS_ALLOW_NO_ORIGIN === "true" || !isProduction),
    rateLimitWindowMs:
      overrides.rateLimitWindowMs ??
      parsePositiveInteger(process.env.RATE_LIMIT_WINDOW_MS, 60_000),
    ipRateLimitMax:
      overrides.ipRateLimitMax ??
      parsePositiveInteger(process.env.IP_RATE_LIMIT_MAX, 300),
    userRateLimitMax:
      overrides.userRateLimitMax ??
      parsePositiveInteger(process.env.USER_RATE_LIMIT_MAX, 120),
    jsonBodyLimit: overrides.jsonBodyLimit ?? process.env.JSON_BODY_LIMIT ?? "256kb",
  };
}