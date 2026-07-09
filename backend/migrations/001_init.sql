-- Velocity core schema (spec §9). PostGIS geometry in EPSG:4326 (lon/lat).
create extension if not exists postgis;

-- ── Users ──────────────────────────────────────────────────────────────────
create table users (
  id            uuid primary key default gen_random_uuid(),
  provider      text not null,                 -- apple | google | dev
  provider_sub  text not null,                 -- identifier from provider
  nickname      text not null,
  avatar_letter text not null default 'V',     -- gradient-avatar initial
  locale        text not null default 'ru',
  role          text not null default 'user',  -- user | moderator
  points        integer not null default 0,    -- total XP
  streak_count  integer not null default 0,
  streak_best   integer not null default 0,
  streak_last   date,
  district      text not null default 'khamovniki',
  km_total      numeric not null default 0,
  created_at    timestamptz not null default now(),
  deleted_at    timestamptz,
  unique (provider, provider_sub)
);

-- ── Cycling infrastructure segments ──────────────────────────────────────────
create table infra_segments (
  id          uuid primary key default gen_random_uuid(),
  geom        geometry(LineString, 4326) not null,
  kind        text not null,                   -- prot | lane | shared | mtb | other
  surface     text not null default 'unknown', -- asphalt | ground | gravel | unknown
  smoothness  text,
  mtb_scale   text,
  name        text,
  source      text not null default 'osm',     -- osm | community
  osm_way_id  bigint,
  status      text not null default 'active',  -- active | removed
  created_by  uuid references users(id),
  updated_at  timestamptz not null default now()
);
create index infra_segments_gix on infra_segments using gist (geom);
create index infra_segments_kind on infra_segments (kind) where status = 'active';

-- ── Points of interest ───────────────────────────────────────────────────────
create table pois (
  id          uuid primary key default gen_random_uuid(),
  geom        geometry(Point, 4326) not null,
  kind        text not null,                   -- workshop | parking | rental | fountain
  name        text not null,
  details     jsonb not null default '{}',     -- { address, hours, phone, ... }
  source      text not null default 'osm',
  status      text not null default 'active',
  created_by  uuid references users(id),
  updated_at  timestamptz not null default now()
);
create index pois_gix on pois using gist (geom);

-- ── Community edit proposals (the core loop) ─────────────────────────────────
create table edit_proposals (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references users(id),
  type           text not null,                -- new_segment | modify_segment | new_poi | modify_poi
  geom           geometry(Geometry, 4326),
  payload        jsonb not null default '{}',  -- { kind, surface, name, comment, targetId, ... }
  photo_keys     text[] not null default '{}',
  status         text not null default 'pending', -- pending | approved | rejected
  reject_reason  text,
  awarded        integer not null default 0,
  created_at     timestamptz not null default now(),
  reviewed_at    timestamptz
);
create index edit_proposals_user on edit_proposals (user_id, created_at desc);

-- ── Problem reports ──────────────────────────────────────────────────────────
create table reports (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid references users(id),
  geom          geometry(Point, 4326) not null,
  category      text not null,                 -- pothole | glass | closure | hazard | other
  comment       text,
  photo_keys    text[] not null default '{}',
  status        text not null default 'active',-- active | expired | resolved
  confirmations integer not null default 0,
  expires_at    timestamptz not null default now() + interval '14 days',
  created_at    timestamptz not null default now(),
  resolved_at   timestamptz
);
create index reports_gix on reports using gist (geom);
create index reports_status on reports (status);

create table report_votes (
  report_id  uuid not null references reports(id) on delete cascade,
  user_id    uuid not null references users(id),
  kind       text not null,                    -- confirm | gone
  created_at timestamptz not null default now(),
  primary key (report_id, user_id)
);

-- ── Favorites (places & routes) ──────────────────────────────────────────────
create table favorites (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id),
  type       text not null,                    -- place | route
  title      text not null,
  payload    jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index favorites_user on favorites (user_id, created_at desc);

-- ── Points ledger (history of XP grants) ─────────────────────────────────────
create table points_ledger (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references users(id),
  delta      integer not null,
  reason     text not null,                    -- edit_approved | poi_approved | report_validated | confirm | quest
  ref_type   text,
  ref_id     uuid,
  created_at timestamptz not null default now()
);
create index points_ledger_user on points_ledger (user_id, created_at desc);

-- ── Minimal product analytics ────────────────────────────────────────────────
create table events (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references users(id),
  name       text not null,
  props      jsonb not null default '{}',
  created_at timestamptz not null default now()
);
