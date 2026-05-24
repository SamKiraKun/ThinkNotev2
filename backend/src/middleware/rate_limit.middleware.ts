import { NextFunction, Request, Response } from "express";

import { errorResponse } from "../utils/api_response";

type RateLimitOptions = {
  keyPrefix: string;
  maxRequests: number;
  windowMs: number;
  keyForRequest: (req: Request) => string;
};

type RateLimitEntry = {
  count: number;
  resetAt: number;
};

export function createRateLimitMiddleware(options: RateLimitOptions) {
  const entries = new Map<string, RateLimitEntry>();

  return (req: Request, res: Response, next: NextFunction) => {
    const now = Date.now();
    const rawKey = options.keyForRequest(req).trim() || "unknown";
    const key = `${options.keyPrefix}:${rawKey}`;
    const existing = entries.get(key);

    if (!existing || existing.resetAt <= now) {
      entries.set(key, {
        count: 1,
        resetAt: now + options.windowMs,
      });
      pruneExpiredEntries(entries, now);
      next();
      return;
    }

    if (existing.count >= options.maxRequests) {
      const retryAfterSeconds = Math.ceil((existing.resetAt - now) / 1000);
      res.setHeader("Retry-After", retryAfterSeconds.toString());
      res
        .status(429)
        .json(errorResponse("Too many requests. Please retry later."));
      return;
    }

    existing.count += 1;
    next();
  };
}

export function parsePositiveInteger(
  rawValue: string | undefined,
  fallback: number,
) {
  const parsed = Number.parseInt(rawValue ?? "", 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return fallback;
  }
  return parsed;
}

function pruneExpiredEntries(
  entries: Map<string, RateLimitEntry>,
  now: number,
) {
  if (entries.size < 1000) {
    return;
  }

  for (const [key, entry] of entries.entries()) {
    if (entry.resetAt <= now) {
      entries.delete(key);
    }
  }
}
