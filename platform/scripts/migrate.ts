// Applies pending SQL migrations in order. Usage: DATABASE_URL=... npm run migrate
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { closeDb, db } from "../src/db.js";

export async function migrate(log = true) {
  const dir = join(import.meta.dirname, "..", "migrations");
  await db().query("CREATE TABLE IF NOT EXISTS schema_migrations (name text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())");
  const { rows } = await db().query<{ name: string }>("SELECT name FROM schema_migrations");
  const done = new Set(rows.map((r) => r.name));
  for (const file of readdirSync(dir).filter((f) => f.endsWith(".sql")).sort()) {
    if (done.has(file)) continue;
    const client = await db().connect();
    try {
      await client.query("BEGIN");
      await client.query(readFileSync(join(dir, file), "utf8").replace(/CREATE TABLE schema_migrations[\s\S]*?\);/, ""));
      await client.query("INSERT INTO schema_migrations (name) VALUES ($1)", [file]);
      await client.query("COMMIT");
      if (log) console.log(`applied ${file}`);
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  migrate().then(closeDb).catch(async (error) => {
    console.error(error);
    await closeDb();
    process.exit(1);
  });
}
