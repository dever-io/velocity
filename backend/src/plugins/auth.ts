import fp from "fastify-plugin";
import type { FastifyReply, FastifyRequest } from "fastify";

export interface JwtPayload {
  sub: string;
  role?: "user" | "moderator";
}

declare module "fastify" {
  interface FastifyInstance {
    authenticate: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
    requireModerator: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
  interface FastifyRequest {
    userId: string;
    role: string;
  }
}

export const authPlugin = fp(async (app) => {
  app.decorateRequest("userId", "");
  app.decorateRequest("role", "user");

  app.decorate("authenticate", async (req: FastifyRequest, reply: FastifyReply) => {
    try {
      const payload = await req.jwtVerify<JwtPayload>();
      req.userId = payload.sub;
      req.role = payload.role ?? "user";
    } catch {
      return reply.code(401).send({ error: "unauthorized" });
    }
  });

  app.decorate("requireModerator", async (req: FastifyRequest, reply: FastifyReply) => {
    try {
      const payload = await req.jwtVerify<JwtPayload>();
      req.userId = payload.sub;
      req.role = payload.role ?? "user";
      if (req.role !== "moderator") return reply.code(403).send({ error: "forbidden" });
    } catch {
      return reply.code(401).send({ error: "unauthorized" });
    }
  });
});
