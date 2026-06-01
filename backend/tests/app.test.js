const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");

const { createClient } = require("@libsql/client");
const { Router } = require("express");
const request = require("supertest");

const { createApp } = require("../dist/app");
const { createSyncRouter } = require("../dist/routes/sync.routes");
const { createAccountRouter } = require("../dist/routes/account.routes");
const {
  buildRequireFirebaseAuth,
} = require("../dist/middleware/auth.middleware");

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

const syncTestTimestamp = "2026-06-01T00:00:00.000Z";

async function createSyncTestHarness() {
  const dbPath = path.join(
    os.tmpdir(),
    `thinknote-sync-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}.db`,
  );
  const db = createClient({
    url: `file:${dbPath.replace(/\\/g, "/")}`,
  });
  const schema = fs.readFileSync(
    path.join(__dirname, "../src/db/schema.sql"),
    "utf8",
  );

  await db.execute("PRAGMA foreign_keys = ON");
  await db.executeMultiple(schema);
  await db.execute({
    sql: `
      INSERT INTO users (id, email, name, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?)
    `,
    args: [
      "test-user",
      "test@example.com",
      "Test User",
      syncTestTimestamp,
      syncTestTimestamp,
    ],
  });

  const app = createApp({
    authMiddleware: allowAuthenticatedRequest,
    logger: silentLogger,
    syncRouter: createSyncRouter(db),
    config: {
      isProduction: false,
      corsAllowNoOrigin: true,
    },
  });

  return {
    app,
    db,
    async cleanup() {
      db.close();
      try {
        fs.rmSync(dbPath, { force: true });
      } catch {}
      try {
        fs.rmSync(`${dbPath}-shm`, { force: true });
      } catch {}
      try {
        fs.rmSync(`${dbPath}-wal`, { force: true });
      } catch {}
    },
  };
}

function createFailingSyncDatabase(baseDb) {
  return {
    execute(statement, args) {
      return args === undefined
        ? baseDb.execute(statement)
        : baseDb.execute(statement, args);
    },
    async transaction(mode) {
      const transaction = await baseDb.transaction(mode);

      return {
        get closed() {
          return transaction.closed;
        },
        close() {
          transaction.close();
        },
        commit() {
          return transaction.commit();
        },
        rollback() {
          return transaction.rollback();
        },
        execute(statement, args) {
          const sql = typeof statement === "string" ? statement : statement.sql;
          if (sql.includes("INSERT INTO notes")) {
            throw new Error("forced notes failure");
          }

          return args === undefined
            ? transaction.execute(statement)
            : transaction.execute(statement, args);
        },
      };
    },
  };
}

test("GET /health returns public backend health status", async () => {
  const app = createApp({
    logger: silentLogger,
    dbClient: {
      async execute() {
        return { rows: [{ time: "2026-05-31 20:15:55" }] };
      },
    },
    config: {
      isProduction: false,
      corsAllowNoOrigin: true,
    },
  });

  const response = await request(app).get("/health");

  assert.equal(response.status, 200);
  assert.equal(response.body.status, "ok");
  assert.equal(response.body.message, "Backend is running!");
});

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
  assert.equal(response.body.error, "unauthorized");
  assert.equal(
    response.body.message,
    "Missing or invalid authentication token",
  );
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

test("GET /account/me returns the authenticated account", async () => {
  const accountRouter = createAccountRouter({
    database: {
      async execute() {
        return {
          rows: [
            {
              id: "test-user",
              email: "test@example.com",
              name: "Test User",
              avatar_url: null,
              created_at: syncTestTimestamp,
              updated_at: syncTestTimestamp,
            },
          ],
        };
      },
    },
    logger: silentLogger,
  });
  const app = createApp({
    authMiddleware: allowAuthenticatedRequest,
    accountRouter,
    logger: silentLogger,
    config: {
      isProduction: false,
      corsAllowNoOrigin: true,
    },
  });

  const response = await request(app).get("/account/me");

  assert.equal(response.status, 200);
  assert.equal(response.body.success, true);
  assert.equal(response.body.data.id, "test-user");
  assert.equal(response.body.data.email, "test@example.com");
});

test("GET /account/me fails when syncing the authenticated user record fails", async () => {
  const authMiddleware = buildRequireFirebaseAuth({
    verifyIdToken: async () => ({
      uid: "synced-user",
      email: "sync@example.com",
      name: "Sync User",
      picture: null,
    }),
    database: {
      async execute() {
        throw new Error("database unavailable during user sync");
      },
    },
    logger: silentLogger,
  });

  const app = createApp({
    authMiddleware,
    logger: silentLogger,
    config: {
      isProduction: false,
      corsAllowNoOrigin: true,
    },
  });

  const response = await request(app)
    .get("/account/me")
    .set("Authorization", "Bearer valid-token");

  assert.equal(response.status, 503);
  assert.equal(response.body.success, false);
  assert.equal(response.body.message, "Account persistence is unavailable");
});

test("authenticated profile persistence retries without email when a stale email row conflicts", async () => {
  const profileWrites = [];
  const authMiddleware = buildRequireFirebaseAuth({
    verifyIdToken: async () => ({
      uid: "recreated-user",
      email: "reused@example.com",
      name: "Recreated User",
      picture: null,
    }),
    database: {
      async execute(statement) {
        profileWrites.push(statement.args);
        if (statement.args[1] === "reused@example.com") {
          const error = new Error("UNIQUE constraint failed: users.email");
          error.code = "SQLITE_CONSTRAINT_UNIQUE";
          throw error;
        }

        return { rows: [] };
      },
    },
    logger: silentLogger,
  });
  const accountRouter = Router();
  accountRouter.get("/me", (req, res) => {
    res.json({
      success: true,
      data: {
        id: req.user_id,
        email: req.auth_user.email,
      },
      message: null,
    });
  });
  const app = createApp({
    authMiddleware,
    accountRouter,
    logger: silentLogger,
    config: {
      isProduction: false,
      corsAllowNoOrigin: true,
    },
  });

  const response = await request(app)
    .get("/account/me")
    .set("Authorization", "Bearer valid-token");

  assert.equal(response.status, 200);
  assert.equal(response.body.data.id, "recreated-user");
  assert.equal(profileWrites.length, 2);
  assert.equal(profileWrites[0][1], "reused@example.com");
  assert.equal(profileWrites[1][1], null);
});

test("users schema treats email as non-unique profile metadata", async () => {
  const dbPath = path.join(
    os.tmpdir(),
    `thinknote-users-${process.pid}-${Date.now()}-${Math.random().toString(16).slice(2)}.db`,
  );
  const db = createClient({
    url: `file:${dbPath.replace(/\\/g, "/")}`,
  });
  const schema = fs.readFileSync(
    path.join(__dirname, "../src/db/schema.sql"),
    "utf8",
  );

  try {
    await db.executeMultiple(schema);
    await db.execute({
      sql: `
        INSERT INTO users (id, email, name, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?), (?, ?, ?, ?, ?)
      `,
      args: [
        "old-user",
        "shared@example.com",
        "Old User",
        syncTestTimestamp,
        syncTestTimestamp,
        "new-user",
        "shared@example.com",
        "New User",
        syncTestTimestamp,
        syncTestTimestamp,
      ],
    });

    const result = await db.execute({
      sql: `SELECT COUNT(*) AS count FROM users WHERE email = ?`,
      args: ["shared@example.com"],
    });

    assert.equal(Number(result.rows[0].count), 2);
  } finally {
    db.close();
    try {
      fs.rmSync(dbPath, { force: true });
    } catch {}
    try {
      fs.rmSync(`${dbPath}-shm`, { force: true });
    } catch {}
    try {
      fs.rmSync(`${dbPath}-wal`, { force: true });
    } catch {}
  }
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

test("POST /sync/push normalizes local-only default folder ids to null", async () => {
  const harness = await createSyncTestHarness();

  try {
    const response = await request(harness.app)
      .post("/sync/push")
      .send({
        notes: [
          {
            id: "note-default-folder",
            title: "Title",
            content: "Content",
            folder_id: "personal",
            created_at: syncTestTimestamp,
            updated_at: syncTestTimestamp,
          },
        ],
      });

    assert.equal(response.status, 200);
    assert.equal(response.body.success, true);

    const notesResult = await harness.db.execute({
      sql: `SELECT folder_id FROM notes WHERE id = ? AND user_id = ?`,
      args: ["note-default-folder", "test-user"],
    });
    const foldersResult = await harness.db.execute({
      sql: `SELECT COUNT(*) AS count FROM folders WHERE user_id = ?`,
      args: ["test-user"],
    });

    assert.equal(notesResult.rows.length, 1);
    assert.equal(notesResult.rows[0].folder_id, null);
    assert.equal(Number(foldersResult.rows[0].count), 0);
  } finally {
    await harness.cleanup();
  }
});

test("GET /sync/readiness verifies schema and authenticated write readiness", async () => {
  const harness = await createSyncTestHarness();

  try {
    const response = await request(harness.app).get("/sync/readiness");

    assert.equal(response.status, 200);
    assert.equal(response.body.success, true);
    assert.equal(response.body.data.status, "ready");
    assert.deepEqual(response.body.data.tables, [
      "users",
      "folders",
      "tags",
      "notes",
      "note_tags",
      "deleted_entities",
      "sync_state",
    ]);

    const stateResult = await harness.db.execute({
      sql: `SELECT value FROM sync_state WHERE user_id = ? AND key = ?`,
      args: ["test-user", "__readiness_probe"],
    });
    assert.equal(stateResult.rows.length, 1);
  } finally {
    await harness.cleanup();
  }
});

test("POST /sync/push clears note folder references before deleting folders", async () => {
  const harness = await createSyncTestHarness();
  const deletedAt = "2026-06-01T01:00:00.000Z";

  try {
    await harness.db.execute({
      sql: `
        INSERT INTO folders (id, user_id, name, emoji, color_key, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `,
      args: [
        "custom-folder",
        "test-user",
        "Custom",
        "📁",
        "work",
        syncTestTimestamp,
        syncTestTimestamp,
      ],
    });
    await harness.db.execute({
      sql: `
        INSERT INTO notes (
          id, user_id, title, content, excerpt, category, folder_id, color_key,
          emoji, is_pinned, is_favorite, is_archived, is_deleted, created_at,
          updated_at, deleted_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
      args: [
        "note-in-folder",
        "test-user",
        "Title",
        "Content",
        "Content",
        "Personal",
        "custom-folder",
        "personal",
        "",
        0,
        0,
        0,
        0,
        syncTestTimestamp,
        syncTestTimestamp,
        null,
      ],
    });

    const response = await request(harness.app)
      .post("/sync/push")
      .send({
        deleted_folders: [
          {
            id: "custom-folder",
            deleted_at: deletedAt,
          },
        ],
      });

    assert.equal(response.status, 200);
    assert.equal(response.body.success, true);
    const syncedAt = response.body.data.server_time;

    const noteResult = await harness.db.execute({
      sql: `SELECT folder_id, updated_at FROM notes WHERE id = ? AND user_id = ?`,
      args: ["note-in-folder", "test-user"],
    });
    const folderResult = await harness.db.execute({
      sql: `SELECT COUNT(*) AS count FROM folders WHERE id = ? AND user_id = ?`,
      args: ["custom-folder", "test-user"],
    });

    assert.equal(noteResult.rows.length, 1);
    assert.equal(noteResult.rows[0].folder_id, null);
    assert.equal(String(noteResult.rows[0].updated_at), syncedAt);
    assert.equal(Number(folderResult.rows[0].count), 0);
  } finally {
    await harness.cleanup();
  }
});

test("POST /sync/push rolls back earlier writes when a later sync step fails", async () => {
  const harness = await createSyncTestHarness();
  const app = createApp({
    authMiddleware: allowAuthenticatedRequest,
    logger: silentLogger,
    syncRouter: createSyncRouter(createFailingSyncDatabase(harness.db)),
    config: {
      isProduction: false,
      corsAllowNoOrigin: true,
    },
  });

  try {
    const response = await request(app)
      .post("/sync/push")
      .send({
        folders: [
          {
            id: "folder-before-failure",
            name: "Before failure",
            color_key: "work",
            emoji: "📁",
            created_at: syncTestTimestamp,
            updated_at: syncTestTimestamp,
          },
        ],
        notes: [
          {
            id: "note-after-folder",
            title: "Title",
            content: "Content",
            folder_id: "folder-before-failure",
            created_at: syncTestTimestamp,
            updated_at: syncTestTimestamp,
          },
        ],
      });

    assert.equal(response.status, 500);
    assert.equal(response.body.message, "Failed to push sync changes");

    const folderResult = await harness.db.execute({
      sql: `SELECT COUNT(*) AS count FROM folders WHERE id = ? AND user_id = ?`,
      args: ["folder-before-failure", "test-user"],
    });
    const noteResult = await harness.db.execute({
      sql: `SELECT COUNT(*) AS count FROM notes WHERE id = ? AND user_id = ?`,
      args: ["note-after-folder", "test-user"],
    });

    assert.equal(Number(folderResult.rows[0].count), 0);
    assert.equal(Number(noteResult.rows[0].count), 0);
  } finally {
    await harness.cleanup();
  }
});
