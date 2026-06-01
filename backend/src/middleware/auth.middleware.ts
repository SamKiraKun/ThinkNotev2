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
          req.auth_user.id,
          req.auth_user.email,
          req.auth_user.name,
          req.auth_user.avatarUrl,
          now,
          now,
        ],
      });
    } catch (error) {
      logger.error("Failed to sync authenticated user profile:", error);
      return res
        .status(503)
        .json(errorResponse("Account persistence is unavailable"));
    }

    return next();
  };
}

export const requireFirebaseAuth = buildRequireFirebaseAuth();

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
