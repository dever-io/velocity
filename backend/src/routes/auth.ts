import type { FastifyInstance } from "fastify";
import { createRemoteJWKSet, jwtVerify } from "jose";
import { pool } from "../db.js";
import { config } from "../config.js";
import { ensureUserGameState } from "../lib/persona.js";
import { getMe } from "../lib/me.js";

async function upsertUser(
  provider: string,
  sub: string,
  name: string,
  letter: string,
  locale: string
): Promise<{ id: string; created: boolean }> {
  const existing = await pool.query(
    "select id from users where provider = $1 and provider_sub = $2 and deleted_at is null",
    [provider, sub]
  );
  if (existing.rowCount) return { id: existing.rows[0].id, created: false };
  const ins = await pool.query(
    "insert into users(provider, provider_sub, nickname, avatar_letter, locale) values ($1,$2,$3,$4,$5) returning id",
    [provider, sub, name, letter, locale]
  );
  return { id: ins.rows[0].id, created: true };
}

async function roleOf(id: string): Promise<"user" | "moderator"> {
  const r = await pool.query("select role from users where id = $1", [id]);
  return r.rows[0]?.role ?? "user";
}

export async function authRoutes(app: FastifyInstance) {
  const sign = (id: string, role: string) =>
    app.jwt.sign({ sub: id, role }, { expiresIn: config.jwtTtl });

  // Local stand-in for Apple/Google sign-in (spec: real providers wired later).
  app.post("/auth/dev", async (req, reply) => {
    if (!config.devAuth) return reply.code(403).send({ error: "dev auth disabled" });
    const b = (req.body ?? {}) as any;
    const sub: string = b.sub || "dev-anya";
    const name: string = b.name || "Аня В.";
    const letter: string = (b.letter || name.trim()[0] || "V").toUpperCase();
    const locale: string = b.locale === "en" ? "en" : "ru";
    const { id, created } = await upsertUser("dev", sub, name, letter, locale);
    if (created) await ensureUserGameState(id);
    return { token: sign(id, await roleOf(id)), user: await getMe(id) };
  });

  // Apple / Google verification (structure). Verifies the provider identity token
  // against the provider JWKS, then issues our own JWT. Not exercised in local dev.
  const appleJwks = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
  const googleJwks = createRemoteJWKSet(new URL("https://www.googleapis.com/oauth2/v3/certs"));

  app.post("/auth/apple", async (req, reply) => {
    const { identityToken, name } = (req.body ?? {}) as any;
    if (!identityToken) return reply.code(400).send({ error: "identityToken required" });
    try {
      const { payload } = await jwtVerify(identityToken, appleJwks, {
        issuer: "https://appleid.apple.com",
        audience: config.appleBundleId,
      });
      const { id, created } = await upsertUser("apple", String(payload.sub), name || "Райдер", "A", "ru");
      if (created) await ensureUserGameState(id);
      return { token: sign(id, await roleOf(id)), user: await getMe(id) };
    } catch {
      return reply.code(401).send({ error: "invalid apple token" });
    }
  });

  app.post("/auth/google", async (req, reply) => {
    const { idToken, name } = (req.body ?? {}) as any;
    if (!idToken) return reply.code(400).send({ error: "idToken required" });
    try {
      const { payload } = await jwtVerify(idToken, googleJwks, {
        issuer: ["https://accounts.google.com", "accounts.google.com"],
        audience: config.googleClientId || undefined,
      });
      const name2 = name || (payload.name as string) || "Райдер";
      const { id, created } = await upsertUser("google", String(payload.sub), name2, "G", "ru");
      if (created) await ensureUserGameState(id);
      return { token: sign(id, await roleOf(id)), user: await getMe(id) };
    } catch {
      return reply.code(401).send({ error: "invalid google token" });
    }
  });

  app.post("/auth/refresh", { preHandler: app.authenticate }, async (req) => ({
    token: sign(req.userId, req.role),
  }));
}
