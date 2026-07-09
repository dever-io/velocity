-- Velocity gamification schema (VeloQuest direction). Content tables carry ru/en
-- copy so the API is self-contained; user_* tables carry per-user progress.

-- ── Quests (daily) ────────────────────────────────────────────────────────────
create table quests (
  id        text primary key,                 -- draw_lane | confirm_reports | ride_km
  title_ru  text not null,
  title_en  text not null,
  target    integer not null,
  reward_xp integer not null,
  icon      text not null,                     -- SF Symbol name
  color     text not null,                     -- token key: tint|green|red|orange|purple
  sort      integer not null default 0
);

create table user_quests (
  user_id      uuid not null references users(id),
  quest_id     text not null references quests(id),
  day          date not null,
  progress     integer not null default 0,
  claimed      boolean not null default false,
  completed_at timestamptz,
  primary key (user_id, quest_id, day)
);

-- ── Badges ────────────────────────────────────────────────────────────────────
create table badges (
  id       text primary key,
  title_ru text not null,
  title_en text not null,
  desc_ru  text not null,
  desc_en  text not null,
  icon     text not null,
  color    text not null,
  target   integer not null default 1,
  sort     integer not null default 0
);

create table user_badges (
  user_id   uuid not null references users(id),
  badge_id  text not null references badges(id),
  progress  integer not null default 0,
  earned_at timestamptz,
  primary key (user_id, badge_id)
);

-- ── Leagues (Duolingo-style tiers) ────────────────────────────────────────────
create table leagues (
  id       text primary key,                   -- bronze|silver|gold|platinum|diamond
  title_ru text not null,
  title_en text not null,
  color    text not null,
  sort     integer not null
);

-- Leaderboard entries. board = 'district' (home peek) | 'league' (League screen).
-- user_ref links a real user (their live XP overrides `xp` at query time); bots
-- have user_ref = null.
create table leaderboard_entries (
  id           uuid primary key default gen_random_uuid(),
  board        text not null,
  league_id    text references leagues(id),
  user_ref     uuid references users(id),
  name         text not null,
  avatar_letter text not null default 'V',
  avatar_color text not null default 'tint',
  xp           integer not null default 0
);
create index leaderboard_board on leaderboard_entries (board, xp desc);

-- ── Season / battle pass ──────────────────────────────────────────────────────
create table seasons (
  id       text primary key,
  title_ru text not null,
  title_en text not null,
  ends_on  date not null,
  tiers    integer not null default 8
);

create table season_tiers (
  season_id     text not null references seasons(id),
  tier          integer not null,
  reward_icon   text not null,
  reward_ru     text not null,
  reward_en     text not null,
  primary key (season_id, tier)
);

create table user_season (
  user_id      uuid not null references users(id),
  season_id    text not null references seasons(id),
  current_tier integer not null default 0,
  primary key (user_id, season_id)
);
