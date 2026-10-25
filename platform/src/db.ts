import pg from "pg";
import { config } from "./config.js";

// Return int8 (bigint) columns as JS numbers: sync versions stay far below 2^53.
pg.types.setTypeParser(20, (value) => Number(value));

let pool: pg.Pool | undefined;

/** Shared pool. Neon's pooled endpoint handles serverless fan-out; keep a small local pool. */
export function db(): pg.Pool {
  pool ??= new pg.Pool({
    connectionString: config.databaseUrl,
    max: 5,
    idleTimeoutMillis: 10_000,
    ssl: /localhost|127\.0\.0\.1/.test(config.databaseUrl) ? undefined : { rejectUnauthorized: true },
  });
  return pool;
}

export type Tx = pg.PoolClient;

/** Runs `fn` in a transaction; rolls back on any error. */
export async function tx<T>(fn: (client: Tx) => Promise<T>): Promise<T> {
  const client = await db().connect();
  try {
    await client.query("BEGIN");
    const result = await fn(client);
    await client.query("COMMIT");
    return result;
  } catch (error) {
    await client.query("ROLLBACK").catch(() => {});
    throw error;
  } finally {
    client.release();
  }
}

export async function closeDb() {
  await pool?.end();
  pool = undefined;
}
