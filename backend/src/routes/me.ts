import type { FastifyInstance } from "fastify";
import { pool } from "../db.js";
import { getMe, getContributions } from "../lib/me.js";

export async function meRoutes(app: FastifyInstance) {
  app.get("/me", { preHandler: app.authenticate }, async (req, reply) => {
    const me = await getMe(req.userId);
    if (!me) return reply.code(404).send({ error: "not found" });
    return me;
  });

  app.patch("/me", { preHandler: app.authenticate }, async (req) => {
    const b = (req.body ?? {}) as any;
    const fields: string[] = [];
    const vals: any[] = [];
    let i = 1;
    if (typeof b.nickname === "string" && b.nickname.trim()) {
      fields.push(`nickname = $${i++}`);
      vals.push(b.nickname.trim().slice(0, 40));
    }
    if (b.locale === "ru" || b.locale === "en") {
      fields.push(`locale = $${i++}`);
      vals.push(b.locale);
    }
    if (typeof b.avatarLetter === "string" && b.avatarLetter.length) {
      fields.push(`avatar_letter = $${i++}`);
      vals.push(b.avatarLetter.slice(0, 1).toUpperCase());
    }
    if (fields.length) {
      vals.push(req.userId);
      await pool.query(`update users set ${fields.join(", ")} where id = $${i}`, vals);
    }
    return getMe(req.userId);
  });

  // ACC-5: in-app delete with cascade anonymization (reports stay, unlinked).
  app.delete("/me", { preHandler: app.authenticate }, async (req) => {
    await pool.query("update reports set user_id = null where user_id = $1", [req.userId]);
    await pool.query(
      `update users set deleted_at = now(), nickname = 'Удалённый пользователь',
         avatar_letter = '•', provider_sub = provider_sub || ':deleted:' || id::text
       where id = $1`,
      [req.userId]
    );
    return { ok: true };
  });

  app.get("/me/contributions", { preHandler: app.authenticate }, async (req) =>
    getContributions(req.userId)
  );
}
