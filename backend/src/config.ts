// Loads .env (Node >=20.12 has process.loadEnvFile) and exposes typed config.
try {
  // @ts-ignore - available in Node 20.12+/24
  process.loadEnvFile?.();
} catch {
  // .env optional; fall back to real environment
}

function env(key: string, fallback = ""): string {
  const v = process.env[key];
  return v === undefined || v === "" ? fallback : v;
}

function bool(key: string, fallback = false): boolean {
  const v = process.env[key];
  if (v === undefined || v === "") return fallback;
  return v === "1" || v.toLowerCase() === "true";
}

export const config = {
  port: parseInt(env("PORT", "8787"), 10),
  host: env("HOST", "0.0.0.0"),
  databaseUrl: env("DATABASE_URL", "postgres://velo:velo@localhost:5544/velo"),
  jwtSecret: env("JWT_SECRET", "dev-only-secret-change-in-prod"),
  jwtTtl: env("JWT_TTL", "7d"),
  devAuth: bool("DEV_AUTH", true),
  devAutoModerate: bool("DEV_AUTO_MODERATE", true),
  orsApiKey: env("ORS_API_KEY"),
  orsBaseUrl: env("ORS_BASE_URL", "https://api.openrouteservice.org"),
  photonUrl: env("PHOTON_URL"),
  uploadDir: env("UPLOAD_DIR", "./uploads"),
  publicBaseUrl: env("PUBLIC_BASE_URL", "http://localhost:8787"),
  appleBundleId: env("APPLE_BUNDLE_ID", "com.velocity.app"),
  googleClientId: env("GOOGLE_CLIENT_ID"),
};

export type Config = typeof config;
