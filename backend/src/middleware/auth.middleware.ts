import { NextFunction, Request, Response } from "express";

import { db } from "../db/turso_client";
import { firebaseAuth } from "../auth/firebase_admin";

export async function requireFirebaseAuth(
  req: Request,
  res: Response,
  next: NextFunction,
) {
  const token = extractBearerToken(req);
  if (!token) {
    return res.status(401).json(unauthorizedResponse());
  }

  try {
    const decoded = await firebaseAuth().verifyIdToken(token);
    const now = new Date().toISOString();

    req.user_id = decoded.uid;
    req.auth_user = {
      id: decoded.uid,
      email: decoded.email ?? null,
      name: decoded.name ?? null,
      avatarUrl: decoded.picture ?? null,
    };

    await db.execute({
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

    return next();
  } catch (error) {
    console.error("Firebase auth verification failed:", error);
    return res.status(401).json(unauthorizedResponse());
  }
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
