# Velocity backend (local-only)

Fastify + PostgreSQL/PostGIS API for the Velocity (VeloQuest) cycling-map app.
**Local development only — nothing here is meant to be deployed.**

## Run

```bash
npm install
npm run db:up        # start Postgres+PostGIS in Docker (host port 5544)
npm run dev          # migrate + seed + serve on http://localhost:8787
```

`npm run db:reset` wipes the volume and recreates the DB. `npm run seed` runs
migrations + content seed standalone.

## What it serves

- **Auth** — `POST /auth/dev` (local stand-in for Apple/Google that issues our JWT),
  plus `/auth/apple`, `/auth/google` (real JWKS verification, unused locally),
  `/auth/refresh`.
- **Account** — `GET/PATCH/DELETE /me`, `GET /me/contributions`.
- **Map (GeoJSON)** — `GET /map/segments|pois|reports?bbox=minLon,minLat,maxLon,maxLat[&kinds=]`.
- **Community** — `POST /reports`, `POST /reports/:id/vote`, `POST /edits`,
  `GET /edits/:id`, moderator `/moderation/edits*`.
- **Routing/search** — `POST /route` (ORS proxy w/ offline local fallback),
  `GET /geocode` (Photon proxy w/ local fallback over seeded places).
- **Gamification** — `GET /quests`, `POST /quests/:id/claim`, `GET /badges`,
  `GET /leaderboard?board=`, `GET /league`, `GET /season`, `POST /events`.
- **Uploads** — `POST /uploads` (multipart → local disk, served at `/uploads/*`).

## Config (`.env`)

`DEV_AUTH=true` enables `/auth/dev`. `DEV_AUTO_MODERATE=true` approves community
edits instantly so the reward/level-up loop is demoable (spec keeps points
post-moderation; this simulates the moderator). Leave `ORS_API_KEY`/`PHOTON_URL`
blank to use the built-in offline fallbacks. Data source: OpenStreetMap-style
seed for Moscow (Khamovniki) — see `src/scripts/seed.ts`.
