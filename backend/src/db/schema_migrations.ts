import fs from "fs";
import path from "path";

import { db } from "./turso_client";

type SchemaDatabaseClient = Pick<typeof db, "execute">;
type Logger = Pick<Console, "log">;
type TableColumn = {
  name: string;
  notnull: number;
};

export async function ensureDatabaseSchema(
  database: SchemaDatabaseClient = db,
  logger: Logger = console,
) {
  const statements = readSchemaStatements();

  for (const statement of statements) {
    await database.execute(statement);
  }
  await relaxLegacyUsersTable(database);

  logger.log(
    `Database schema ready with ${statements.length} idempotent statements.`,
  );
}

function readSchemaStatements() {
  const schemaPath = path.resolve(__dirname, "../../src/db/schema.sql");
  const schema = fs.readFileSync(schemaPath, "utf8");

  return schema
    .split(";")
    .map((statement) => statement.trim())
    .filter(Boolean);
}

async function relaxLegacyUsersTable(database: SchemaDatabaseClient) {
  const columns = await tableColumns(database, "users");
  if (columns.length === 0) {
    return;
  }

  const columnByName = new Map(columns.map((column) => [column.name, column]));
  const emailColumn = columnByName.get("email");
  const passwordHashColumn = columnByName.get("password_hash");
  const needsRebuild =
    emailColumn?.notnull === 1 ||
    passwordHashColumn?.notnull === 1 ||
    (await hasUniqueEmailIndex(database));

  if (!needsRebuild) {
    return;
  }

  const now = new Date().toISOString();
  const args: string[] = [];
  const timestampExpression = (name: string) => {
    args.push(now);
    return columnByName.has(name) ? `COALESCE(${name}, ?)` : "?";
  };
  const nullableExpression = (name: string) =>
    columnByName.has(name) ? name : "NULL";

  await database.execute("PRAGMA foreign_keys = OFF");
  try {
    await database.execute("DROP TABLE IF EXISTS users_new");
    await database.execute(`
      CREATE TABLE users_new (
        id TEXT PRIMARY KEY,
        email TEXT,
        password_hash TEXT,
        name TEXT,
        avatar_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    `);
    await database.execute({
      sql: `
        INSERT INTO users_new (
          id, email, password_hash, name, avatar_url, created_at, updated_at
        )
        SELECT
          id,
          ${nullableExpression("email")},
          ${nullableExpression("password_hash")},
          ${nullableExpression("name")},
          ${nullableExpression("avatar_url")},
          ${timestampExpression("created_at")},
          ${timestampExpression("updated_at")}
        FROM users
      `,
      args,
    });
    await database.execute("DROP TABLE users");
    await database.execute("ALTER TABLE users_new RENAME TO users");
  } finally {
    await database.execute("PRAGMA foreign_keys = ON");
  }
}

async function tableColumns(
  database: SchemaDatabaseClient,
  tableName: string,
): Promise<TableColumn[]> {
  const result = await database.execute(`PRAGMA table_info(${tableName})`);
  return result.rows.map((row) => ({
    name: String(row.name),
    notnull: Number(row.notnull),
  }));
}

async function hasUniqueEmailIndex(database: SchemaDatabaseClient) {
  const indexes = await database.execute("PRAGMA index_list(users)");

  for (const index of indexes.rows) {
    if (Number(index.unique) !== 1) {
      continue;
    }

    const indexName = String(index.name);
    const indexColumns = await database.execute(
      `PRAGMA index_info(${indexName})`,
    );
    const columnNames = indexColumns.rows.map((row) => String(row.name));
    if (columnNames.length === 1 && columnNames[0] === "email") {
      return true;
    }
  }

  return false;
}
