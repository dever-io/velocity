// Seeds content (quests, badges, leagues, season, Moscow infra/POI/reports,
// leaderboard bots). Per-table idempotent (skips a table that already has rows).
// Per-user gamification state is seeded on sign-in (see lib/persona.ts).
import type { FastifyBaseLogger } from "fastify";
import { pool, waitForDb, migrate } from "../db.js";

type Log = Pick<FastifyBaseLogger, "info"> | Console;

async function isEmpty(table: string): Promise<boolean> {
  const { rows } = await pool.query(`select count(*)::int as c from ${table}`);
  return rows[0].c === 0;
}

function lineWKT(coords: [number, number][]): string {
  return "LINESTRING(" + coords.map(([lon, lat]) => `${lon} ${lat}`).join(",") + ")";
}

// ── Content data ────────────────────────────────────────────────────────────
const QUESTS = [
  ["draw_lane", "Нанести 1 дорожку", "Draw 1 bike lane", 1, 50, "pencil.and.outline", "green", 0],
  ["confirm_reports", "Подтвердить 3 репорта", "Confirm 3 reports", 3, 6, "checkmark.seal.fill", "tint", 1],
  ["ride_km", "Проехать 5 км", "Ride 5 km", 5, 15, "bicycle", "orange", 2],
] as const;

const BADGES = [
  ["trailblazer", "Первопроходец", "Trailblazer", "Добавьте первую дорожку", "Add your first bike lane", "flag.fill", "green", 1, 0],
  ["eagle_eye", "Глаз-алмаз", "Eagle eye", "Подтвердите 10 сообщений", "Confirm 10 reports", "eye.fill", "tint", 10, 1],
  ["marathon", "Марафонец", "Marathon", "Проедьте 100 км", "Ride 100 km", "figure.outdoor.cycle", "orange", 100, 2],
  ["night_watch", "Ночной дозор", "Night watch", "Сообщите о проблеме ночью", "Report a problem at night", "moon.stars.fill", "purple", 1, 3],
  ["cartographer", "Картограф", "Cartographer", "Добавьте 10 дорожек", "Add 10 bike lanes", "map.fill", "teal", 10, 4],
  ["guardian", "Хранитель", "Guardian", "Достигните 5 уровня", "Reach level 5", "shield.lefthalf.filled", "purple", 5, 5],
  ["on_a_roll", "На волне", "On a roll", "Серия 7 дней", "Keep a 7-day streak", "flame.fill", "orange", 7, 6],
  ["signaler", "Сигнальщик", "Signaler", "Отправьте 20 сообщений", "Submit 20 reports", "exclamationmark.bubble.fill", "red", 20, 7],
] as const;

const LEAGUES = [
  ["bronze", "Бронзовая лига", "Bronze league", "bronze", 0],
  ["silver", "Серебряная лига", "Silver league", "silver", 1],
  ["gold", "Золотая лига", "Gold league", "gold", 2],
  ["platinum", "Платиновая лига", "Platinum league", "platinum", 3],
  ["diamond", "Алмазная лига", "Diamond league", "diamond", 4],
] as const;

const SEASON_TIERS = [
  [1, "star.fill", "50 XP", "50 XP"],
  [2, "bicycle", "Значок", "Badge"],
  [3, "shield.fill", "Аватар", "Avatar"],
  [4, "gift.fill", "Стикеры", "Stickers"],
  [5, "trophy.fill", "Тема оформления", "App theme"],
  [6, "sparkles", "Титул", "Title"],
  [7, "medal.fill", "Рамка аватара", "Avatar frame"],
  [8, "crown.fill", "Трофей сезона", "Season trophy"],
] as const;

// [kind, surface, name, source, coords]
const SEGMENTS: [string, string, string, string, [number, number][]][] = [
  ["prot", "asphalt", "Фрунзенская набережная", "osm", [[37.5905, 55.7305], [37.5975, 55.7278], [37.6035, 55.7262]]],
  ["lane", "asphalt", "ул. Льва Толстого", "community", [[37.5875, 55.7355], [37.5905, 55.7340]]],
  ["shared", "asphalt", "Комсомольский проспект", "osm", [[37.586, 55.729], [37.5895, 55.725], [37.593, 55.7215]]],
  ["prot", "asphalt", "Парк Горького — набережная", "osm", [[37.601, 55.73], [37.603, 55.7315], [37.605, 55.733]]],
  ["mtb", "ground", "Воробьёвы горы — тропа", "osm", [[37.556, 55.71], [37.56, 55.7115], [37.565, 55.712]]],
  ["other", "gravel", "Нескучный сад", "osm", [[37.596, 55.722], [37.599, 55.72], [37.6015, 55.7185]]],
  ["lane", "asphalt", "Зубовский бульвар", "osm", [[37.5905, 55.736], [37.595, 55.7365]]],
  ["prot", "asphalt", "Хамовнический вал", "community", [[37.573, 55.727], [37.578, 55.7255]]],
  ["shared", "asphalt", "Пречистенка", "osm", [[37.596, 55.742], [37.599, 55.7405], [37.601, 55.7395]]],
];

// [kind, name, address, lon, lat]
const POIS: [string, string, string, number, number][] = [
  ["workshop", "Веломастерская «Спица»", "ул. Тимура Фрунзе, 11", 37.592, 55.7345],
  ["parking", "Велопарковка у Парка Горького", "Крымский Вал", 37.6015, 55.7305],
  ["rental", "Велопрокат Gorky", "Парк Горького", 37.603, 55.7298],
  ["fountain", "Питьевой фонтанчик", "Нескучный сад", 37.5975, 55.721],
  ["workshop", "СервисБайк", "Зубовский бул., 4", 37.5885, 55.7365],
  ["parking", "Парковка «Фрунзенская»", "Фрунзенская наб.", 37.596, 55.7285],
  ["fountain", "Фонтанчик на Пушкинской наб.", "Пушкинская наб.", 37.604, 55.728],
  ["rental", "Прокат «Лужники»", "Лужники", 37.556, 55.718],
];

// [category, comment, lon, lat, confirmations]
const REPORTS: [string, string, number, number, number][] = [
  ["pothole", "Большая яма ближе к бордюру, легко влететь колесом.", 37.593, 55.733, 3],
  ["glass", "Битое стекло на дорожке.", 37.5975, 55.7278, 1],
  ["closure", "Перекрытие из-за стройки.", 37.5895, 55.725, 5],
  ["hazard", "Скользко после дождя, крутой спуск.", 37.6015, 55.7185, 2],
];

// [board, league, name, letter, color, xp]
const LEADERBOARD: [string, string | null, string, string, string, number][] = [
  ["league", "gold", "Игорь К.", "И", "tint", 1240],
  ["league", "gold", "Мария П.", "М", "purple", 1180],
  ["league", "gold", "Лена С.", "Л", "green", 1120],
  ["league", "gold", "Дмитрий В.", "Д", "orange", 1080],
  ["league", "gold", "Олег Р.", "О", "teal", 1040],
  ["league", "gold", "Артём Н.", "А", "red", 980],
  ["league", "gold", "Соня М.", "С", "tint", 920],
  ["league", "gold", "Павел Т.", "П", "green", 860],
  ["district", null, "Игорь К.", "И", "tint", 1240],
  ["district", null, "Мария П.", "М", "purple", 1180],
  ["district", null, "Лена С.", "Л", "green", 1020],
  ["district", null, "Дмитрий В.", "Д", "orange", 980],
];

export async function runSeed(log: Log = console): Promise<void> {
  if (await isEmpty("quests")) {
    for (const q of QUESTS)
      await pool.query(
        "insert into quests(id,title_ru,title_en,target,reward_xp,icon,color,sort) values ($1,$2,$3,$4,$5,$6,$7,$8)",
        [...q]
      );
    log.info("[seed] quests");
  }

  if (await isEmpty("badges")) {
    for (const b of BADGES)
      await pool.query(
        "insert into badges(id,title_ru,title_en,desc_ru,desc_en,icon,color,target,sort) values ($1,$2,$3,$4,$5,$6,$7,$8,$9)",
        [...b]
      );
    log.info("[seed] badges");
  }

  if (await isEmpty("leagues")) {
    for (const l of LEAGUES)
      await pool.query(
        "insert into leagues(id,title_ru,title_en,color,sort) values ($1,$2,$3,$4,$5)",
        [...l]
      );
    log.info("[seed] leagues");
  }

  if (await isEmpty("seasons")) {
    await pool.query(
      "insert into seasons(id,title_ru,title_en,ends_on,tiers) values ($1,$2,$3, (now() + interval '12 days')::date, $4)",
      ["spring26", "Сезон 3 · Весна", "Season 3 · Spring", 8]
    );
    for (const [tier, icon, ru, en] of SEASON_TIERS)
      await pool.query(
        "insert into season_tiers(season_id,tier,reward_icon,reward_ru,reward_en) values ('spring26',$1,$2,$3,$4)",
        [tier, icon, ru, en]
      );
    log.info("[seed] season + tiers");
  }

  if (await isEmpty("infra_segments")) {
    for (const [kind, surface, name, source, coords] of SEGMENTS)
      await pool.query(
        `insert into infra_segments(geom,kind,surface,name,source,status)
         values (ST_GeomFromText($1,4326),$2,$3,$4,$5,'active')`,
        [lineWKT(coords), kind, surface, name, source]
      );
    log.info(`[seed] ${SEGMENTS.length} infra segments`);
  }

  if (await isEmpty("pois")) {
    for (const [kind, name, address, lon, lat] of POIS)
      await pool.query(
        `insert into pois(geom,kind,name,details,source,status)
         values (ST_SetSRID(ST_MakePoint($1,$2),4326),$3,$4,$5::jsonb,'osm','active')`,
        [lon, lat, kind, name, JSON.stringify({ address })]
      );
    log.info(`[seed] ${POIS.length} POIs`);
  }

  if (await isEmpty("reports")) {
    for (const [category, comment, lon, lat, conf] of REPORTS)
      await pool.query(
        `insert into reports(geom,category,comment,confirmations,status)
         values (ST_SetSRID(ST_MakePoint($1,$2),4326),$3,$4,$5,'active')`,
        [lon, lat, category, comment, conf]
      );
    log.info(`[seed] ${REPORTS.length} reports`);
  }

  if (await isEmpty("leaderboard_entries")) {
    for (const [board, league, name, letter, color, xp] of LEADERBOARD)
      await pool.query(
        "insert into leaderboard_entries(board,league_id,name,avatar_letter,avatar_color,xp) values ($1,$2,$3,$4,$5,$6)",
        [board, league, name, letter, color, xp]
      );
    log.info("[seed] leaderboard bots");
  }
}

// CLI: `npm run seed` — wait for DB, migrate, seed, exit.
const isMain = process.argv[1] && import.meta.url === `file://${process.argv[1]}`;
if (isMain) {
  (async () => {
    await waitForDb();
    await migrate();
    await runSeed(console);
    console.log("[seed] done");
    await pool.end();
    process.exit(0);
  })().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
