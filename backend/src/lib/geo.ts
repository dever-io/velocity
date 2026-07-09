// Helpers for building GeoJSON responses and parsing bbox params.

export interface Bbox {
  minLon: number;
  minLat: number;
  maxLon: number;
  maxLat: number;
}

/** Parse "minLon,minLat,maxLon,maxLat". Falls back to a Moscow-wide box. */
export function parseBbox(raw: unknown): Bbox {
  const fallback: Bbox = { minLon: 37.2, minLat: 55.5, maxLon: 37.95, maxLat: 55.95 };
  if (typeof raw !== "string") return fallback;
  const parts = raw.split(",").map((p) => parseFloat(p.trim()));
  if (parts.length !== 4 || parts.some((n) => Number.isNaN(n))) return fallback;
  const [minLon, minLat, maxLon, maxLat] = parts;
  return { minLon, minLat, maxLon, maxLat };
}

export interface Feature {
  type: "Feature";
  id?: string;
  geometry: any;
  properties: Record<string, any>;
}

export interface FeatureCollection {
  type: "FeatureCollection";
  features: Feature[];
}

/** rows must each have a `geojson` text column (from ST_AsGeoJSON). */
export function featureCollection<T extends { id?: string; geojson: string }>(
  rows: T[],
  props: (row: T) => Record<string, any>
): FeatureCollection {
  return {
    type: "FeatureCollection",
    features: rows.map((r) => ({
      type: "Feature",
      id: r.id,
      geometry: JSON.parse(r.geojson),
      properties: props(r),
    })),
  };
}
