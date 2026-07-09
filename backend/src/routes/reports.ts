import type { FastifyInstance } from "fastify";
import { pool } from "../db.js";
import { config } from "../config.js";
import { awardPoints } from "../lib/points.js";
import { bumpQuest, bumpBadge } from "../lib/gamify.js";

const CATEGORIES = new Set(["pothole", "glass", "closure", "hazard", "other"]);

export async function reportRoutes(app: FastifyInstance) {
  // REP-1: create a problem report.
  app.post("/reports", { preHandler: app.authenticate }, async (req, reply) => {
    const b = (req.body ?? {}) as any;
    if (!CATEGORIES.has(b.category)) return reply.code(400).send({ error: "bad category" });
    const lng = Number(b.lng);
    const lat = Number(b.lat);
    if (Number.isNaN(lng) || Number.isNaN(lat)) return reply.code(400).send({ error: "bad coords" });
    const photoKeys: string[] = Array.isArray(b.photoKeys) ? b.photoKeys.slice(0, 3) : [];

    const ins = await pool.query(
      `insert into reports(user_id, geom, category, comment, photo_keys, status)
       values ($1, ST_SetSRID(ST_MakePoint($2,$3),4326), $4, $5, $6, 'active') returning id`,
      [req.userId, lng, lat, b.category, (b.comment ?? "").slice(0, 500) || null, photoKeys]
    );
    const id = ins.rows[0].id;
    await bumpBadge(req.userId, "signaler", 1);
    const hour = new Date().getHours();
    if (hour >= 22 || hour < 5) await bumpBadge(req.userId, "night_watch", 1);

    // Spec: +10 after validation. DEV_AUTO_MODERATE validates immediately.
    let reward = null;
    if (config.devAutoModerate) {
      reward = await awardPoints(pool, req.userId, 10, "report_validated", "report", id);
    }
    return { id, status: "active", reward };
  });

  // REP-2: confirm / mark-gone. One vote per user; +2 XP once per confirmed report.
  app.post("/reports/:id/vote", { preHandler: app.authenticate }, async (req, reply) => {
    const { id } = req.params as any;
    const kind = (req.body as any)?.kind;
    if (kind !== "confirm" && kind !== "gone") return reply.code(400).send({ error: "bad kind" });

    const exists = await pool.query("select 1 from reports where id = $1", [id]);
    if (!exists.rowCount) return reply.code(404).send({ error: "not found" });

    const vote = await pool.query(
      `insert into report_votes(report_id, user_id, kind) values ($1,$2,$3)
       on conflict (report_id, user_id) do nothing returning report_id`,
      [id, req.userId, kind]
    );
    const isNewVote = (vote.rowCount ?? 0) > 0;

    let reward = null;
    let confirmations = 0;
    if (kind === "confirm") {
      if (isNewVote) {
        const upd = await pool.query(
          `update reports set confirmations = confirmations + 1,
             expires_at = now() + interval '14 days' where id = $1 returning confirmations`,
          [id]
        );
        confirmations = upd.rows[0].confirmations;
        await bumpQuest(req.userId, "confirm_reports", 1);
        await bumpBadge(req.userId, "eagle_eye", 1);
        reward = await awardPoints(pool, req.userId, 2, "confirm", "report", id);
      } else {
        confirmations = (await pool.query("select confirmations from reports where id=$1", [id])).rows[0].confirmations;
      }
    } else {
      // "gone" — a majority can retire it; keep simple: mark resolved after this vote.
      await pool.query("update reports set status = 'resolved', resolved_at = now() where id = $1", [id]);
    }
    return { ok: true, confirmations, reward };
  });
}
