import type { FastifyInstance } from "fastify";
import { authRoutes } from "./auth.js";
import { meRoutes } from "./me.js";
import { mapRoutes } from "./map.js";
import { reportRoutes } from "./reports.js";
import { editRoutes } from "./edits.js";
import { favoriteRoutes } from "./favorites.js";
import { routeRoutes } from "./route.js";
import { gamificationRoutes } from "./gamification.js";
import { uploadRoutes } from "./uploads.js";

export async function registerRoutes(app: FastifyInstance) {
  await app.register(authRoutes);
  await app.register(meRoutes);
  await app.register(mapRoutes);
  await app.register(reportRoutes);
  await app.register(editRoutes);
  await app.register(favoriteRoutes);
  await app.register(routeRoutes);
  await app.register(gamificationRoutes);
  await app.register(uploadRoutes);
}
