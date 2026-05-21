const fs = require('fs');
const path = require('path');
const { createClient } = require('@libsql/client');
require('dotenv').config();

async function pushSchema() {
  const url = process.env.TURSO_DATABASE_URL || "file:local.db";
  const authToken = process.env.TURSO_AUTH_TOKEN;

  const db = createClient({ url, authToken });

  try {
    console.log(`Connecting to database at ${url}...`);
    const schemaPath = path.join(__dirname, '../src/db/schema.sql');
    const schema = fs.readFileSync(schemaPath, 'utf8');

    // Split schema into individual statements
    const statements = schema
      .split(';')
      .map(s => s.trim())
      .filter(s => s.length > 0);

    for (const statement of statements) {
      console.log(`Executing: ${statement.substring(0, 50)}...`);
      await db.execute(statement);
    }
    
    // Seed a mock user
    const mockUserId = 'mock-user-id';
    const now = new Date().toISOString();
    await db.execute({
        sql: `INSERT OR IGNORE INTO users (id, email, password_hash, name, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?)`,
        args: [mockUserId, 'mock@example.com', 'hash', 'Riya', now, now]
    });
    
    console.log("Schema pushed & seeded mock user successfully!");
  } catch (error) {
    console.error("Failed to push schema:", error);
  }
}

pushSchema();
