const assert = require("node:assert/strict");
const test = require("node:test");

const request = require("supertest");

const { createApp } = require("../dist/app");

const silentLogger = {
  error() {},
  log() {},
};

function allowAuthenticatedRequest(req, _res, next) {
  req.user_id = "test-user";
  req.auth_user = {
    id: "test-user",
    email: "test@example.com",
    name: "Test User",
    avatarUrl: null,
  };
  next();
}

test("POST /notes rejects requests without a bearer token", async () => {
  const app = createApp({
    logger: silentLogger,
    config: {
      isProduction: false,
      corsAllowNoOrigin: true,
    },
  });

  const response = await request(app).post("/notes").send({});

  assert.equal(response.status, 401);
  assert.equal(response.body.message, "Missing bearer token");
});

test("POST /notes enforces the per-user rate limit", async () => {
  const app = createApp({
    authMiddleware: allowAuthenticatedRequest,
    logger: silentLogger,
    config: {
      isProduction: false,
      corsAllowNoOrigin: true,
      ipRateLimitMax: 100,
      userRateLimitMax: 2,
      rateLimitWindowMs: 60_000,
    },
  });

  await request(app).post("/notes").send({}).expect(400);
  await request(app).post("/notes").send({}).expect(400);
  const response = await request(app).post("/notes").send({});

  assert.equal(response.status, 429);
  assert.match(response.body.message, /Too many requests/i);
  assert.equal(response.headers["retry-after"], "60");
});

test("POST /notes rejects a request body that exceeds the configured size", async () => {
  const app = createApp({
    authMiddleware: allowAuthenticatedRequest,
    logger: silentLogger,
    config: {
      isProduction: false,
      corsAllowNoOrigin: true,
      jsonBodyLimit: "120b",
    },
  });

  const response = await request(app)
    .post("/notes")
    .send({
      title: "Oversized",
      content: "x".repeat(400),
    });

  assert.equal(response.status, 413);
  assert.equal(response.body.message, "Request body is too large");
});

test("POST /notes blocks a disallowed browser origin", async () => {
  const app = createApp({
    authMiddleware: allowAuthenticatedRequest,
    logger: silentLogger,
    config: {
      isProduction: true,
      corsAllowNoOrigin: false,
      allowedOrigins: ["https://allowed.example.com"],
    },
  });

  const response = await request(app)
    .post("/notes")
    .set("Origin", "https://evil.example.com")
    .send({});

  assert.equal(response.status, 403);
  assert.equal(response.body.message, "Origin is not allowed by CORS");
});