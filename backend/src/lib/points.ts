import { config } from "../config.js";

// XP → level curve. req(L) = XP to go from level L to L+1 = 100 + (L-1)*20.
// total(L) = XP needed to *reach* level L = 10(L-1)^2 + 90(L-1).
//   total(7) = 900, total(8) = 1120  → matches the design mock (level 7, "60 XP to lvl 8").

export interface LevelInfo {
  level: number;
  xp: number;
  into: number;   // XP earned inside the current level
  need: number;   // XP span of the current level
  toNext: number; // XP remaining to next level
  progress: number; // 0..1
}

function totalForLevel(level: number): number {
  const m = level - 1;
  return 10 * m * m + 90 * m;
}

export function levelInfo(xp: number): LevelInfo {
  const safeXp = Math.max(0, Math.floor(xp));
  const m = Math.floor((-90 + Math.sqrt(8100 + 40 * safeXp)) / 20);
  const level = Math.max(1, m + 1);
  const base = totalForLevel(level);
  const need = totalForLevel(level + 1) - base;
  const into = safeXp - base;
  return {
    level,
    xp: safeXp,
    into,
    need,
    toNext: Math.max(0, need - into),
    progress: need > 0 ? Math.min(1, into / need) : 0,
  };
}

export interface AwardResult {
  points: number;
  prevLevel: number;
  level: number;
  leveledUp: boolean;
  delta: number;
}

interface Queryable {
  query: (text: string, params?: any[]) => Promise<{ rows: any[] }>;
}

/** Insert a ledger row, bump users.points, and report any level change.
 *  PTS-3: positive grants are clamped so a user can't earn more than the daily cap. */
export async function awardPoints(
  db: Queryable,
  userId: string,
  delta: number,
  reason: string,
  refType: string | null = null,
  refId: string | null = null
): Promise<AwardResult> {
  const before = await db.query("select points from users where id = $1", [userId]);
  const prevXp: number = before.rows[0]?.points ?? 0;
  const prevLevel = levelInfo(prevXp).level;

  let grant = delta;
  if (delta > 0) {
    const usedRes = await db.query(
      `select coalesce(sum(delta),0)::int as used from points_ledger
       where user_id = $1 and delta > 0 and created_at::date = current_date`,
      [userId]
    );
    const used: number = usedRes.rows[0].used;
    const remaining = Math.max(0, config.dailyXpCap - used);
    grant = Math.min(delta, remaining);
  }
  if (grant === 0) {
    return { points: prevXp, prevLevel, level: prevLevel, leveledUp: false, delta: 0 };
  }

  await db.query(
    "insert into points_ledger(user_id, delta, reason, ref_type, ref_id) values ($1,$2,$3,$4,$5)",
    [userId, grant, reason, refType, refId]
  );
  const upd = await db.query(
    "update users set points = points + $2 where id = $1 returning points",
    [userId, grant]
  );
  const newXp: number = upd.rows[0].points;
  const level = levelInfo(newXp).level;
  return { points: newXp, prevLevel, level, leveledUp: level > prevLevel, delta: grant };
}
