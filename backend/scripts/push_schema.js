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
    
    console.log("Schema pushed successfully!");
  } catch (error) {
    console.error("Failed to push schema:", error);
  }
}

pushSchema();
