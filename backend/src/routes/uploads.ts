import { randomUUID } from "node:crypto";
import { createWriteStream } from "node:fs";
import { mkdir } from "node:fs/promises";
import { pipeline } from "node:stream/promises";
import { resolve, join, extname } from "node:path";
import type { FastifyInstance } from "fastify";
import { config } from "../config.js";

const ALLOWED = new Set([".jpg", ".jpeg", ".png", ".heic", ".webp"]);

// Local disk uploads. Mirrors the spec's presigned-S3 shape but stores files
// under UPLOAD_DIR and serves them from PUBLIC_BASE_URL/uploads/* (local-only).
export async function uploadRoutes(app: FastifyInstance) {
  app.post("/uploads", { preHandler: app.authenticate }, async (req, reply) => {
    if (!req.isMultipart()) return reply.code(400).send({ error: "multipart required" });
    const root = resolve(config.uploadDir);
    await mkdir(root, { recursive: true });

    const results: { key: string; url: string }[] = [];
    for await (const part of req.parts()) {
      if (part.type !== "file") continue;
      const ext = (extname(part.filename ?? "").toLowerCase() || ".jpg");
      const safeExt = ALLOWED.has(ext) ? ext : ".jpg";
      const key = `${randomUUID()}${safeExt}`;
      await pipeline(part.file, createWriteStream(join(root, key)));
      results.push({ key, url: `${config.publicBaseUrl}/uploads/${key}` });
      if (results.length >= 3) break;
    }
    if (!results.length) return reply.code(400).send({ error: "no files" });
    return { uploads: results };
  });
}
