import { pool } from "../db.js";

/** Advance today's daily quest progress (capped at target), stamp completion. */
export async function bumpQuest(userId: string, questId: string, inc = 1): Promise<void> {
  const t = await pool.query("select target from quests where id = $1", [questId]);
  if (!t.rowCount) return;
  const target: number = t.rows[0].target;
  await pool.query(
    `insert into user_quests(user_id, quest_id, day, progress) values ($1,$2,current_date,$3)
     on conflict (user_id, quest_id, day)
       do update set progress = least($4, user_quests.progress + $3)`,
    [userId, questId, inc, target]
  );
  await pool.query(
    `update user_quests set completed_at = now()
     where user_id = $1 and quest_id = $2 and day = current_date
       and progress >= $3 and completed_at is null`,
    [userId, questId, target]
  );
}

/** Advance badge progress and earn it when the target is reached. */
export async function bumpBadge(userId: string, badgeId: string, inc = 1): Promise<void> {
  const t = await pool.query("select target from badges where id = $1", [badgeId]);
  if (!t.rowCount) return;
  const target: number = t.rows[0].target;
  await pool.query(
    `insert into user_badges(user_id, badge_id, progress) values ($1,$2,$3)
     on conflict (user_id, badge_id) do update set progress = user_badges.progress + $3`,
    [userId, badgeId, inc]
  );
  await pool.query(
    `update user_badges set earned_at = now()
     where user_id = $1 and badge_id = $2 and progress >= $3 and earned_at is null`,
    [userId, badgeId, target]
  );
}
