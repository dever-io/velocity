import { mkdir } from "node:fs/promises";
import { resolve } from "node:path";
import Fastify from "fastify";
import cors from "@fastify/cors";
import jwt from "@fastify/jwt";
import multipart from "@fastify/multipart";
import fastifyStatic from "@fastify/static";
import { config } from "./config.js";
import { waitForDb, migrate } from "./db.js";
import { authPlugin } from "./plugins/auth.js";
import { registerRoutes } from "./routes/index.js";
import { runSeed } from "./scripts/seed.js";

async function main() {
  const app = Fastify({
    logger: { transport: { target: "pino-pretty", options: { translateTime: "HH:MM:ss", ignore: "pid,hostname" } } },
    bodyLimit: 12 * 1024 * 1024,
  });

  await app.register(cors, { origin: true });
  await app.register(jwt, { secret: config.jwtSecret });
  await app.register(multipart, { limits: { fileSize: 8 * 1024 * 1024, files: 3 } });

  const uploadRoot = resolve(config.uploadDir);
  await mkdir(uploadRoot, { recursive: true });
  await app.register(fastifyStatic, { root: uploadRoot, prefix: "/uploads/" });

  await app.register(authPlugin);

  app.get("/health", async () => ({ ok: true, service: "velo-backend", ts: Date.now() }));

  await app.register(registerRoutes);

  // Boot sequence: DB up -> migrate -> seed (idempotent) -> listen
  app.log.info("waiting for database…");
  await waitForDb();
  await migrate();
  await runSeed(app.log);

  await app.listen({ port: config.port, host: config.host });
  app.log.info(`Velocity backend on http://localhost:${config.port} (devAuth=${config.devAuth})`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
