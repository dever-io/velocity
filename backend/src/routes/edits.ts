import type { FastifyInstance } from "fastify";
import { pool } from "../db.js";
import { config } from "../config.js";
import { awardPoints, type AwardResult } from "../lib/points.js";
import { bumpQuest, bumpBadge } from "../lib/gamify.js";

const TYPES = new Set(["new_segment", "modify_segment", "new_poi", "modify_poi"]);

/** Materialize an approved proposal into infra_segments/pois and award XP. */
async function approveProposal(id: string): Promise<AwardResult | null> {
  const res = await pool.query("select * from edit_proposals where id = $1", [id]);
  if (!res.rowCount) return null;
  const p = res.rows[0];
  if (p.status !== "pending") return null;
  const payload = p.payload ?? {};

  if (p.type === "new_segment") {
    await pool.query(
      `insert into infra_segments(geom, kind, surface, name, source, created_by)
       select geom, $2, $3, $4, 'community', $5 from edit_proposals where id = $1`,
      [id, payload.kind ?? "other", payload.surface ?? "unknown", payload.name ?? null, p.user_id]
    );
  } else if (p.type === "new_poi") {
    await pool.query(
      `insert into pois(geom, kind, name, details, source, created_by)
       select geom, $2, $3, $4::jsonb, 'community', $5 from edit_proposals where id = $1`,
      [id, payload.kind ?? "workshop", payload.name ?? "Точка", JSON.stringify(payload.details ?? {}), p.user_id]
    );
  } else if (p.type === "modify_segment" && payload.targetId) {
    if (payload.removed) {
      await pool.query("update infra_segments set status = 'removed', updated_at = now() where id = $1", [payload.targetId]);
    } else {
      await pool.query(
        `update infra_segments set kind = coalesce($2, kind), surface = coalesce($3, surface),
           source = 'community', updated_at = now() where id = $1`,
        [payload.targetId, payload.kind ?? null, payload.surface ?? null]
      );
    }
  }

  const isPoi = p.type.includes("poi");
  const award = isPoi ? 20 : 50;
  await pool.query(
    "update edit_proposals set status = 'approved', awarded = $2, reviewed_at = now() where id = $1",
    [id, award]
  );
  const reward = await awardPoints(pool, p.user_id, award, isPoi ? "poi_approved" : "edit_approved", "edit", id);
  if (p.type === "new_segment") {
    await bumpQuest(p.user_id, "draw_lane", 1);
    await bumpBadge(p.user_id, "trailblazer", 1);
    await bumpBadge(p.user_id, "cartographer", 1);
  }
  return reward;
}

export async function editRoutes(app: FastifyInstance) {
  // EDIT-1/2: submit a community edit proposal.
  app.post("/edits", { preHandler: app.authenticate }, async (req, reply) => {
    const b = (req.body ?? {}) as any;
    if (!TYPES.has(b.type)) return reply.code(400).send({ error: "bad type" });
    const payload = JSON.stringify(b.payload ?? {});
    const photoKeys: string[] = Array.isArray(b.photoKeys) ? b.photoKeys.slice(0, 3) : [];

    let id: string;
    if (b.geometry) {
      const ins = await pool.query(
        `insert into edit_proposals(user_id, type, geom, payload, photo_keys, status)
         values ($1, $2, ST_SetSRID(ST_GeomFromGeoJSON($3),4326), $4::jsonb, $5, 'pending') returning id`,
        [req.userId, b.type, JSON.stringify(b.geometry), payload, photoKeys]
      );
      id = ins.rows[0].id;
    } else {
      const ins = await pool.query(
        `insert into edit_proposals(user_id, type, payload, photo_keys, status)
         values ($1, $2, $3::jsonb, $4, 'pending') returning id`,
        [req.userId, b.type, payload, photoKeys]
      );
      id = ins.rows[0].id;
    }

    // Spec: points only after moderation. DEV_AUTO_MODERATE simulates the moderator.
    let reward: AwardResult | null = null;
    let status = "pending";
    if (config.devAutoModerate) {
      reward = await approveProposal(id);
      status = "approved";
    }
    return { id, status, reward };
  });

  app.get("/edits/:id", { preHandler: app.authenticate }, async (req, reply) => {
    const { id } = req.params as any;
    const r = await pool.query(
      `select id, type, status, awarded, reject_reason as "rejectReason",
              created_at as "createdAt", reviewed_at as "reviewedAt"
       from edit_proposals where id = $1 and user_id = $2`,
      [id, req.userId]
    );
    if (!r.rowCount) return reply.code(404).send({ error: "not found" });
    return r.rows[0];
  });

  // ── Moderation (EDIT-4) — moderator role. Also used by a Telegram bot / admin. ──
  app.get("/moderation/edits", { preHandler: app.requireModerator }, async (req) => {
    const status = (req.query as any)?.status ?? "pending";
    const r = await pool.query(
      `select e.id, e.type, e.status, e.payload, e.photo_keys as "photoKeys",
              ST_AsGeoJSON(e.geom) as geojson, u.nickname, e.created_at as "createdAt"
       from edit_proposals e join users u on u.id = e.user_id
       where e.status = $1 order by e.created_at asc limit 100`,
      [status]
    );
    return r.rows.map((row) => ({ ...row, geometry: row.geojson ? JSON.parse(row.geojson) : null, geojson: undefined }));
  });

  app.post("/moderation/edits/:id/approve", { preHandler: app.requireModerator }, async (req, reply) => {
    const reward = await approveProposal((req.params as any).id);
    if (!reward) return reply.code(409).send({ error: "not pending or not found" });
    return { ok: true, reward };
  });

  app.post("/moderation/edits/:id/reject", { preHandler: app.requireModerator }, async (req) => {
    const { id } = req.params as any;
    const reason = (req.body as any)?.reason ?? null;
    await pool.query(
      "update edit_proposals set status = 'rejected', reject_reason = $2, reviewed_at = now() where id = $1 and status = 'pending'",
      [id, reason]
    );
    return { ok: true };
  });
}
