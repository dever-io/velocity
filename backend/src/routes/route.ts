import type { FastifyInstance } from "fastify";
import { pool } from "../db.js";
import { config } from "../config.js";

function haversine(a: [number, number], b: [number, number]): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b[1] - a[1]);
  const dLon = toRad(b[0] - a[0]);
  const lat1 = toRad(a[1]);
  const lat2 = toRad(b[1]);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

// Deterministic local route: a gently bowed polyline with a synthetic elevation
// profile — used when no ORS key is configured (keeps local dev fully offline).
function localRoute(from: [number, number], to: [number, number], profile: string) {
  const N = 26;
  const dx = to[0] - from[0];
  const dy = to[1] - from[1];
  const len = Math.hypot(dx, dy) || 1;
  const nx = -dy / len; // unit normal
  const ny = dx / len;
  const bow = 0.0011;

  const coords: [number, number][] = [];
  const elevation: { d: number; ele: number }[] = [];
  let dist = 0;
  let ascent = 0;
  let prevEle = 0;
  for (let i = 0; i <= N; i++) {
    const t = i / N;
    const wobble = Math.sin(t * Math.PI) * bow + Math.sin(t * Math.PI * 5) * bow * 0.15;
    const lon = from[0] + dx * t + nx * wobble;
    const lat = from[1] + dy * t + ny * wobble;
    const p: [number, number] = [lon, lat];
    if (i > 0) dist += haversine(coords[i - 1], p);
    coords.push(p);
    const ele = 138 + 14 * Math.sin(t * Math.PI * 3) + 9 * Math.sin(t * Math.PI * 7 + 1);
    if (i > 0 && ele > prevEle) ascent += ele - prevEle;
    prevEle = ele;
    elevation.push({ d: Math.round(dist), ele: Math.round(ele) });
  }
  const speed = profile === "mtb" ? 3.3 : 4.8; // m/s
  const infraPct = 40 + Math.round(35 * Math.abs(Math.sin((from[0] + to[1]) * 7)));
  return {
    profile,
    geometry: { type: "LineString", coordinates: coords },
    distance: Math.round(dist),
    duration: Math.round(dist / speed),
    ascent: Math.round(ascent),
    infraPct,
    elevation,
    source: "local" as const,
  };
}

async function orsRoute(from: [number, number], to: [number, number], profile: string) {
  const orsProfile = profile === "mtb" ? "cycling-mountain" : "cycling-regular";
  const res = await fetch(`${config.orsBaseUrl}/v2/directions/${orsProfile}/geojson`, {
    method: "POST",
    headers: { Authorization: config.orsApiKey, "Content-Type": "application/json" },
    body: JSON.stringify({ coordinates: [from, to], elevation: true }),
  });
  if (!res.ok) throw new Error(`ORS ${res.status}`);
  const gj: any = await res.json();
  const feat = gj.features[0];
  const coords: number[][] = feat.geometry.coordinates;
  const summary = feat.properties.summary ?? {};
  let dist = 0;
  const elevation: { d: number; ele: number }[] = [];
  for (let i = 0; i < coords.length; i++) {
    if (i > 0) dist += haversine([coords[i - 1][0], coords[i - 1][1]], [coords[i][0], coords[i][1]]);
    if (i % 8 === 0) elevation.push({ d: Math.round(dist), ele: Math.round(coords[i][2] ?? 0) });
  }
  return {
    profile,
    geometry: { type: "LineString", coordinates: coords.map((c) => [c[0], c[1]]) },
    distance: Math.round(summary.distance ?? dist),
    duration: Math.round(summary.duration ?? 0),
    ascent: Math.round(feat.properties.ascent ?? 0),
    infraPct: 40 + Math.round(35 * Math.abs(Math.sin((from[0] + to[1]) * 7))),
    elevation,
    source: "ors" as const,
  };
}

const STATIC_PLACES: { name: string; lng: number; lat: number }[] = [
  { name: "Парк Горького", lng: 37.6035, lat: 55.7295 },
  { name: "Воробьёвы горы", lng: 37.556, lat: 55.71 },
  { name: "Лужники", lng: 37.554, lat: 55.7157 },
  { name: "Красная площадь", lng: 37.6208, lat: 55.7539 },
  { name: "ВДНХ", lng: 37.632, lat: 55.8263 },
  { name: "Сокольники", lng: 37.677, lat: 55.794 },
  { name: "Фрунзенская набережная", lng: 37.595, lat: 55.729 },
];

export async function routeRoutes(app: FastifyInstance) {
  // RTE-1/2/3: build an A→B route.
  app.post("/route", { preHandler: app.authenticate }, async (req, reply) => {
    const b = (req.body ?? {}) as any;
    const from = b.from,
      to = b.to;
    if (!from || !to || typeof from.lng !== "number" || typeof to.lng !== "number") {
      return reply.code(400).send({ error: "from/to required" });
    }
    const profile = b.profile === "mtb" ? "mtb" : "city";
    const fromC: [number, number] = [from.lng, from.lat];
    const toC: [number, number] = [to.lng, to.lat];
    if (config.orsApiKey) {
      try {
        return await orsRoute(fromC, toC, profile);
      } catch (err) {
        req.log.warn({ err }, "ORS failed, using local route");
      }
    }
    return localRoute(fromC, toC, profile);
  });

  // MAP-7: geocode. Photon proxy if configured, else local search.
  app.get("/geocode", { preHandler: app.authenticate }, async (req) => {
    const q = String((req.query as any)?.q ?? "").trim();
    if (!q) return { results: [] };

    if (config.photonUrl) {
      try {
        const res = await fetch(`${config.photonUrl}/api?q=${encodeURIComponent(q)}&limit=8&lang=ru`);
        if (res.ok) {
          const gj: any = await res.json();
          return {
            results: (gj.features ?? []).map((f: any) => ({
              name: f.properties.name ?? f.properties.street ?? q,
              subtitle: [f.properties.city, f.properties.state].filter(Boolean).join(", "),
              lng: f.geometry.coordinates[0],
              lat: f.geometry.coordinates[1],
            })),
          };
        }
      } catch (err) {
        req.log.warn({ err }, "Photon failed, using local geocode");
      }
    }

    const like = `%${q.toLowerCase()}%`;
    const pois = await pool.query(
      `select name, ST_X(geom) as lng, ST_Y(geom) as lat, details->>'address' as address
       from pois where status='active' and lower(name) like $1 limit 6`,
      [like]
    );
    const local = STATIC_PLACES.filter((p) => p.name.toLowerCase().includes(q.toLowerCase())).map((p) => ({
      name: p.name,
      subtitle: "Москва",
      lng: p.lng,
      lat: p.lat,
    }));
    const fromPois = pois.rows.map((r) => ({
      name: r.name,
      subtitle: r.address ?? "Москва",
      lng: Number(r.lng),
      lat: Number(r.lat),
    }));
    return { results: [...local, ...fromPois].slice(0, 8) };
  });
}
