// Seeds a believable per-user gamification state on first sign-in so the heavily
// gamified UI (Home hub, Profile passport, League) looks alive in local demo.
// Idempotent: keyed on the presence of a user_season row.
import { pool } from "../db.js";

export async function ensureUserGameState(userId: string): Promise<void> {
  const existing = await pool.query("select 1 from user_season where user_id = $1", [userId]);
  if (existing.rowCount) return;

  // Veteran persona: level 7 (points 1060), 12-day streak, 184 km.
  await pool.query(
    `update users set points = 1060, streak_count = 12, streak_best = 18,
       km_total = 184, streak_last = current_date, district = 'khamovniki'
     where id = $1`,
    [userId]
  );

  // Today's daily quests: draw 0/1, confirm 3/3 (ready to claim), ride 3/5.
  await pool.query(
    `insert into user_quests(user_id, quest_id, day, progress, claimed) values
       ($1,'draw_lane',current_date,0,false),
       ($1,'confirm_reports',current_date,3,false),
       ($1,'ride_km',current_date,3,false)
     on conflict do nothing`,
    [userId]
  );

  // Badges: 5 earned, 3 in progress.
  await pool.query(
    `insert into user_badges(user_id, badge_id, progress, earned_at) values
       ($1,'trailblazer',1,now()),
       ($1,'marathon',184,now()),
       ($1,'guardian',7,now()),
       ($1,'on_a_roll',12,now()),
       ($1,'night_watch',1,now()),
       ($1,'eagle_eye',4,null),
       ($1,'cartographer',5,null),
       ($1,'signaler',6,null)
     on conflict do nothing`,
    [userId]
  );

  // Battle-pass: tier 3 / 8 of the current season.
  await pool.query(
    `insert into user_season(user_id, season_id, current_tier) values ($1,'spring26',3)
     on conflict do nothing`,
    [userId]
  );

  // A little real contribution history so counts and lists aren't empty.
  for (let i = 0; i < 5; i++) {
    await pool.query(
      `insert into edit_proposals(user_id, type, payload, status, awarded, reviewed_at, created_at)
       values ($1,'new_segment',$2::jsonb,'approved',50, now() - ($3 || ' days')::interval, now() - ($3 || ' days')::interval)`,
      [userId, JSON.stringify({ kind: "lane", surface: "asphalt", name: "Дорожка" }), String(i)]
    );
  }
  const repPoints: [string, string, number, number][] = [
    ["pothole", "Яма у съезда с моста.", 37.5945, 55.732],
    ["glass", "Мусор на велополосе.", 37.5985, 55.7275],
    ["hazard", "Открытый люк.", 37.5895, 55.7365],
    ["closure", "Временное перекрытие тротуара.", 37.6005, 55.7315],
  ];
  for (const [category, comment, lon, lat] of repPoints) {
    await pool.query(
      `insert into reports(user_id, geom, category, comment, confirmations, status)
       values ($1, ST_SetSRID(ST_MakePoint($2,$3),4326), $4, $5, 1, 'active')`,
      [userId, lon, lat, category, comment]
    );
  }
  // Confirm a few seeded reports (created by nobody) → confirms count > 0.
  const others = await pool.query(
    "select id from reports where user_id is null order by created_at limit 3"
  );
  for (const r of others.rows) {
    await pool.query(
      "insert into report_votes(report_id, user_id, kind) values ($1,$2,'confirm') on conflict do nothing",
      [r.id, userId]
    );
    await pool.query("update reports set confirmations = confirmations + 1 where id = $1", [r.id]);
  }

  // Recent points history for the "История начислений" section.
  await pool.query(
    `insert into points_ledger(user_id, delta, reason, created_at) values
       ($1, 50, 'edit_approved', now()),
       ($1, 10, 'report_validated', now() - interval '1 day'),
       ($1, 2, 'confirm', now() - interval '1 day')`,
    [userId]
  );
}
