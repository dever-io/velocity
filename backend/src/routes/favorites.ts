import type { FastifyInstance } from "fastify";
import { pool } from "../db.js";

export async function favoriteRoutes(app: FastifyInstance) {
  app.get("/favorites", { preHandler: app.authenticate }, async (req) => {
    const r = await pool.query(
      `select id, type, title, payload, created_at as "createdAt"
       from favorites where user_id = $1 order by created_at desc`,
      [req.userId]
    );
    return r.rows;
  });

  app.post("/favorites", { preHandler: app.authenticate }, async (req, reply) => {
    const b = (req.body ?? {}) as any;
    if (b.type !== "place" && b.type !== "route") return reply.code(400).send({ error: "bad type" });
    const r = await pool.query(
      `insert into favorites(user_id, type, title, payload) values ($1,$2,$3,$4::jsonb)
       returning id, type, title, payload, created_at as "createdAt"`,
      [req.userId, b.type, (b.title ?? "").slice(0, 120) || "Без названия", JSON.stringify(b.payload ?? {})]
    );
    return r.rows[0];
  });

  app.delete("/favorites/:id", { preHandler: app.authenticate }, async (req) => {
    await pool.query("delete from favorites where id = $1 and user_id = $2", [(req.params as any).id, req.userId]);
    return { ok: true };
  });
}
