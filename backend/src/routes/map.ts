import type { FastifyInstance } from "fastify";
import { pool } from "../db.js";
import { parseBbox, featureCollection } from "../lib/geo.js";

function kindsFilter(raw: unknown): string[] | null {
  if (typeof raw !== "string" || !raw.trim()) return null;
  return raw.split(",").map((s) => s.trim()).filter(Boolean);
}

export async function mapRoutes(app: FastifyInstance) {
  // Cycling infrastructure segments as GeoJSON (MAP-2, MAP-3).
  app.get("/map/segments", async (req) => {
    const q = req.query as any;
    const b = parseBbox(q.bbox);
    const kinds = kindsFilter(q.kinds);
    const params: any[] = [b.minLon, b.minLat, b.maxLon, b.maxLat];
    let sql = `select id, ST_AsGeoJSON(geom) as geojson, kind, surface, smoothness,
                 mtb_scale as "mtbScale", name, source, updated_at as "updatedAt"
               from infra_segments
               where status = 'active' and geom && ST_MakeEnvelope($1,$2,$3,$4,4326)`;
    if (kinds) {
      params.push(kinds);
      sql += ` and kind = any($5)`;
    }
    const { rows } = await pool.query(sql, params);
    return featureCollection(rows, (r) => ({
      kind: r.kind,
      surface: r.surface,
      smoothness: r.smoothness,
      mtbScale: r.mtbScale,
      name: r.name,
      source: r.source,
      updatedAt: r.updatedAt,
    }));
  });

  // POIs as GeoJSON (MAP-4).
  app.get("/map/pois", async (req) => {
    const q = req.query as any;
    const b = parseBbox(q.bbox);
    const kinds = kindsFilter(q.kinds);
    const params: any[] = [b.minLon, b.minLat, b.maxLon, b.maxLat];
    let sql = `select id, ST_AsGeoJSON(geom) as geojson, kind, name, details, source
               from pois
               where status = 'active' and geom && ST_MakeEnvelope($1,$2,$3,$4,4326)`;
    if (kinds) {
      params.push(kinds);
      sql += ` and kind = any($5)`;
    }
    const { rows } = await pool.query(sql, params);
    return featureCollection(rows, (r) => ({
      kind: r.kind,
      name: r.name,
      details: r.details,
      source: r.source,
    }));
  });

  // Active reports as GeoJSON (MAP-5).
  app.get("/map/reports", async (req) => {
    const q = req.query as any;
    const b = parseBbox(q.bbox);
    const { rows } = await pool.query(
      `select r.id, ST_AsGeoJSON(r.geom) as geojson, r.category, r.comment,
              r.confirmations, r.status, r.photo_keys as "photoKeys",
              r.created_at as "createdAt", r.expires_at as "expiresAt", u.nickname as reporter
       from reports r left join users u on u.id = r.user_id
       where r.status = 'active' and r.geom && ST_MakeEnvelope($1,$2,$3,$4,4326)`,
      [b.minLon, b.minLat, b.maxLon, b.maxLat]
    );
    return featureCollection(rows, (r) => ({
      category: r.category,
      comment: r.comment,
      confirmations: r.confirmations,
      status: r.status,
      photoKeys: r.photoKeys,
      createdAt: r.createdAt,
      expiresAt: r.expiresAt,
      reporter: r.reporter,
    }));
  });
}
