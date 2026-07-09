# Velocity — Roadmap

Gap analysis vs [spec.ru.md](spec.ru.md). Legend: `✅` done · `🟡` partial · `⬜` todo.
The base app is a working MVP prototype; the items below are what's left to make it a
real product **по спеке**.

## 1 · MVP completion — code, locally testable (start here)
- ✅ **Real device geolocation** (MAP-6): `CLLocationManager`, live "me" dot, auto-center on first fix, recenter. _(compass heading captured, not yet drawn)_
- ✅ **Draw the built route on the map** (RTE-1/3): polyline mini-map + fit camera.
- ✅ **EDIT-2 UI** — correct a segment (type/surface / "removed") from the segment card → `modify_segment`.
- ✅ **Profile edit** — nickname / avatar via `PATCH /me` (ACC-3).
- ✅ **REP-3** — report expiry job (5-min interval) + `expires_at` filter in `/map/reports`.
- ✅ **PTS-3** — daily XP cap (500) in `awardPoints` (verified: grants clamp to 0 past the cap).
- ⬜ **A→B by tap/search in Route; open saved route from favorites** (RTE-1/5).
- ⬜ **EDIT-1** — drag/delete draw points; photo + comment in the draw flow.
- ⬜ Privacy hint on report ("не создавай отчёт у дома", §12); finish analytics events (§11); POI clustering (MAP-4).
- ⬜ **Accessibility** — Dynamic Type + VoiceOver labels (§11).

## 2 · Data — fixes the "empty map"
- ⬜ **OSM ETL** — Moscow extract → osmium filter cycling tags → PostGIS (§7). _(now: ~9 hand-seeded segments)_
- ⬜ **Real routing** — OpenRouteService / GraphHopper key + provider choice (§7, §15.5). _(now: synthetic straight routes)_
- ⬜ **Real geocoder** — Photon proxy (§7). _(now: search over seed)_

## 3 · Deploy / infra
> **Server 111.88.225.21 is a live RU box that already runs a CRM.** Deploy isolated
> (Docker, dedicated ports, own network) — never touch the CRM. Confirm plan before running anything there.
- ⬜ Deploy backend (Docker) behind the RU server as a reverse-proxied service; proxy app requests through it (helps 152-ФЗ localization).
- ⬜ PostgreSQL/PostGIS + daily backups; photos → S3/Tigris; EXIF strip; presigned upload.
- ⬜ Point the app at the RU endpoint (replace `APIBaseURL`).
- ⬜ Health checks, logs, autodeploy from git; OpenAPI schema; Sentry (opt).

## 4 · Auth / Apple (needs paid Apple Developer, $99/yr)
- ⬜ Real **Sign in with Apple** + **Google OAuth** (ACC-2). _(now: dev stub + guest button)_
- ⬜ Re-enable **HealthKit** entitlement on device; real `WorkoutRoute` track, HR / max speed / ascent (HLT).
- ⬜ TestFlight beta.

## 5 · Moderation
- ⬜ **Telegram moderation bot** (EDIT-4) or minimal web admin. _(now: dev auto-approve)_

## 6 · Legal (§12)
- ⬜ 152-ФЗ review; RU data hosting via the proxy / DB in RF.

## 7 · Open decisions (§15)
- ⬜ Final **name** (placeholder "Velocity") · rewards beyond points · routing provider · OSM contribution.

## Phase 2 (deferred by spec)
Android · push · Strava · offline maps · partner rewards · turn-by-turn · self-hosted routing · OSM export · monetization.

---

## Done ✅ (reference)
**iOS:** onboarding · sign-in (stub + guest) · Home/Quest Hub · Map (MapLibre, real OpenFreeMap basemap + offline fallback, infra/MTB/POI/report layers, cards, layer toggles, search, fog-of-war, district conquest) · Route (profiles, stats, infra %, elevation chart, save) · Report (categories, photos) · Draw → Level-up celebration · Add POI · Profile (game passport, season/battle-pass, stats, streak, badges + detail) · League (promotion/demotion) · Rides UI (HealthKit) · Settings/About/Rules/Privacy · RU/EN instant toggle · light/dark · reward loop (confetti/+XP/toast) · custom app icon.
**Backend:** dev auth + JWT · `/me` + contributions + delete · map GeoJSON (bbox) · reports + votes · edits + moderation endpoints (dev auto-approve) · route (offline fallback) · geocode (fallback) · favorites · gamification (quests/claim, badges, leaderboard, league, season) · uploads (local disk).
**Ahead of plan:** full gamification (spec PTS-4 = phase 2) and guest login already built.
**Ops:** pushed to github.com/dever-io/velocity, MIT license, runs on a physical iPhone.
