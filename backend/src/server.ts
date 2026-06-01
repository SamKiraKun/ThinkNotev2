import { createApp, resolveServerPort } from "./app";
import { ensureDatabaseSchema } from "./db/schema_migrations";

async function main() {
  await ensureDatabaseSchema();

  const app = createApp();
  const port = resolveServerPort();

  app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
  });
}

void main().catch((error) => {
  console.error("Failed to start ThinkNote backend:", error);
  process.exit(1);
});
