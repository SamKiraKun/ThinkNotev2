import { NextFunction, Request, Response } from "express";

import { db } from "../db/turso_client";
import { firebaseAuth } from "../auth/firebase_admin";
import { errorResponse } from "../utils/api_response";

type VerifiedAuthUser = {
  uid: string;
  email?: string | null;
  name?: string | null;
  picture?: string | null;
};

type AuthMiddlewareDependencies = {
  verifyIdToken?: (token: string) => Promise<VerifiedAuthUser>;
  database?: Pick<typeof db, "execute">;
  logger?: Pick<Console, "error">;
};

type AuthUserProfile = {
  id: string;
  email: string | null;
  name: string | null;
  avatarUrl: string | null;
};

export function buildRequireFirebaseAuth(
  dependencies: AuthMiddlewareDependencies = {},
) {
  const verifyIdToken =
      dependencies.verifyIdToken ??
      ((token: string) => firebaseAuth().verifyIdToken(token));
  const database = dependencies.database ?? db;
  const logger = dependencies.logger ?? console;

  return async function requireFirebaseAuth(
    req: Request,
    res: Response,
    next: NextFunction,
  ) {
    const token = extractBearerToken(req);
    if (!token) {
      return res.status(401).json(unauthorizedResponse());
    }

    let decoded: VerifiedAuthUser;
    try {
      decoded = await verifyIdToken(token);
    } catch (error) {
      logger.error("Firebase auth verification failed:", error);
      return res.status(401).json(unauthorizedResponse());
    }

    const now = new Date().toISOString();

    req.user_id = decoded.uid;
    req.auth_user = {
      id: decoded.uid,
      email: decoded.email ?? null,
      name: decoded.name ?? null,
      avatarUrl: decoded.picture ?? null,
    };

    try {
      await persistAuthenticatedUser(database, req.auth_user, now);
    } catch (error) {
      logger.error("Failed to sync authenticated user profile:", {
        request_id: req.request_id,
        user_id: decoded.uid,
        error,
      });
      return res
        .status(503)
        .json(errorResponse("Account persistence is unavailable"));
    }

    return next();
  };
}

export const requireFirebaseAuth = buildRequireFirebaseAuth();

async function persistAuthenticatedUser(
  database: Pick<typeof db, "execute">,
  user: AuthUserProfile,
  now: string,
) {
  try {
    await upsertAuthenticatedUser(database, user, now, user.email);
  } catch (error) {
    if (isUsersAvatarUrlColumnError(error)) {
      await upsertAuthenticatedUserLegacy(database, user, now, user.email);
      return;
    }

    if (!user.email || !isUsersEmailConstraintError(error)) {
      throw error;
    }

    try {
      await upsertAuthenticatedUser(database, user, now, null);
    } catch (retryError) {
      if (isUsersAvatarUrlColumnError(retryError)) {
        await upsertAuthenticatedUserLegacy(database, user, now, null);
        return;
      }

      throw retryError;
    }
  }
}

async function upsertAuthenticatedUser(
  database: Pick<typeof db, "execute">,
  user: AuthUserProfile,
  now: string,
  email: string | null,
) {
  await database.execute({
    sql: `
      INSERT INTO users (id, email, name, avatar_url, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        email = excluded.email,
        name = excluded.name,
        avatar_url = excluded.avatar_url,
        updated_at = excluded.updated_at
    `,
    args: [
      user.id,
      email,
      user.name,
      user.avatarUrl,
      now,
      now,
    ],
  });
}

async function upsertAuthenticatedUserLegacy(
  database: Pick<typeof db, "execute">,
  user: AuthUserProfile,
  now: string,
  email: string | null,
) {
  await database.execute({
    sql: `
      INSERT INTO users (id, email, name, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        email = excluded.email,
        name = excluded.name,
        updated_at = excluded.updated_at
    `,
    args: [user.id, email, user.name, now, now],
  });
}

function isUsersEmailConstraintError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  const code =
    typeof error === "object" && error !== null && "code" in error
      ? String((error as { code?: unknown }).code)
      : "";

  return (
    message.includes("UNIQUE constraint failed: users.email") ||
    (code === "SQLITE_CONSTRAINT_UNIQUE" && message.includes("users.email"))
  );
}

function isUsersAvatarUrlColumnError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error);
  return (
    message.includes("table users has no column named avatar_url") ||
    message.includes("no such column: avatar_url")
  );
}

function unauthorizedResponse() {
  return {
    success: false,
    data: null,
    error: "unauthorized",
    message: "Missing or invalid authentication token",
  };
}

function extractBearerToken(req: Request): string | null {
  const header = req.header("authorization");
  if (!header) {
    return null;
  }

  const [scheme, token] = header.split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token) {
    return null;
  }

  return token;
}
