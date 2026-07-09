import { readdir, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import pg from "pg";
import { config } from "./config.js";

const __dirname = dirname(fileURLToPath(import.meta.url));

export const pool = new pg.Pool({ connectionString: config.databaseUrl });

export async function query<T extends pg.QueryResultRow = any>(
  text: string,
  params: any[] = []
): Promise<pg.QueryResult<T>> {
  return pool.query<T>(text, params);
}

/** Wait for Postgres to accept connections (Docker may still be starting). */
export async function waitForDb(retries = 30, delayMs = 1000): Promise<void> {
  for (let i = 0; i < retries; i++) {
    try {
      await pool.query("select 1");
      return;
    } catch (err) {
      if (i === retries - 1) throw err;
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
}

/** Run *.sql files in migrations/ once each, tracked in schema_migrations. */
export async function migrate(): Promise<void> {
  await pool.query(
    `create table if not exists schema_migrations (
       name text primary key,
       applied_at timestamptz not null default now()
     )`
  );
  const dir = join(__dirname, "..", "migrations");
  let files: string[] = [];
  try {
    files = (await readdir(dir)).filter((f) => f.endsWith(".sql")).sort();
  } catch {
    return; // no migrations dir yet
  }
  for (const file of files) {
    const done = await pool.query("select 1 from schema_migrations where name = $1", [file]);
    if (done.rowCount) continue;
    const sql = await readFile(join(dir, file), "utf8");
    const client = await pool.connect();
    try {
      await client.query("begin");
      await client.query(sql);
      await client.query("insert into schema_migrations(name) values ($1)", [file]);
      await client.query("commit");
      console.log(`[migrate] applied ${file}`);
    } catch (err) {
      await client.query("rollback");
      console.error(`[migrate] FAILED ${file}`);
      throw err;
    } finally {
      client.release();
    }
  }
}
