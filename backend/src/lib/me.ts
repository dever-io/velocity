import { pool } from "../db.js";
import { levelInfo } from "./points.js";

const DISTRICTS: Record<string, { ru: string; en: string; titleRu: string; titleEn: string }> = {
  khamovniki: {
    ru: "Хамовники",
    en: "Khamovniki",
    titleRu: "Хранитель Хамовников",
    titleEn: "Keeper of Khamovniki",
  },
};

export async function getMe(userId: string): Promise<any | null> {
  const u = await pool.query(
    `select id, nickname, avatar_letter, locale, role, district, points,
            streak_count, streak_best, km_total
     from users where id = $1 and deleted_at is null`,
    [userId]
  );
  if (!u.rowCount) return null;
  const user = u.rows[0];

  const stats = await pool.query(
    `select
       (select count(*)::int from edit_proposals where user_id = $1 and status = 'approved') as edits,
       (select count(*)::int from reports where user_id = $1) as reports,
       (select count(*)::int from report_votes where user_id = $1 and kind = 'confirm') as confirms`,
    [userId]
  );

  const d = DISTRICTS[user.district] ?? DISTRICTS.khamovniki;
  const level = levelInfo(user.points);

  return {
    id: user.id,
    nickname: user.nickname,
    avatarLetter: user.avatar_letter,
    locale: user.locale,
    role: user.role,
    district: user.district,
    districtName: { ru: d.ru, en: d.en },
    title: { ru: d.titleRu, en: d.titleEn },
    points: user.points,
    level,
    streak: { count: user.streak_count, best: user.streak_best },
    kmTotal: Number(user.km_total),
    stats: stats.rows[0],
  };
}

export async function getContributions(userId: string): Promise<any> {
  const history = await pool.query(
    `select delta, reason, ref_type as "refType", created_at as "createdAt"
     from points_ledger where user_id = $1 order by created_at desc limit 30`,
    [userId]
  );
  const edits = await pool.query(
    `select id, type, status, awarded, payload, created_at as "createdAt"
     from edit_proposals where user_id = $1 order by created_at desc limit 50`,
    [userId]
  );
  const reports = await pool.query(
    `select id, category, comment, status, confirmations, created_at as "createdAt"
     from reports where user_id = $1 order by created_at desc limit 50`,
    [userId]
  );
  const me = await getMe(userId);
  return {
    points: me?.points ?? 0,
    level: me?.level,
    stats: me?.stats,
    history: history.rows,
    edits: edits.rows,
    reports: reports.rows,
  };
}
