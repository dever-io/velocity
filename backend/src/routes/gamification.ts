import type { FastifyInstance } from "fastify";
import { pool } from "../db.js";
import { awardPoints } from "../lib/points.js";
import { bumpQuest, bumpBadge } from "../lib/gamify.js";

interface Entry {
  name: string;
  avatarLetter: string;
  avatarColor: string;
  xp: number;
  isMe: boolean;
  rank?: number;
}

/** Bots for a board + the requesting user's live entry, ranked by XP desc. */
async function rankedBoard(board: string, userId: string): Promise<Entry[]> {
  const bots = await pool.query(
    "select name, avatar_letter, avatar_color, xp from leaderboard_entries where board = $1",
    [board]
  );
  const me = await pool.query("select nickname, avatar_letter, points from users where id = $1", [userId]);
  const entries: Entry[] = bots.rows.map((r) => ({
    name: r.name,
    avatarLetter: r.avatar_letter,
    avatarColor: r.avatar_color,
    xp: r.xp,
    isMe: false,
  }));
  if (me.rowCount) {
    entries.push({
      name: me.rows[0].nickname,
      avatarLetter: me.rows[0].avatar_letter,
      avatarColor: "avatar",
      xp: me.rows[0].points,
      isMe: true,
    });
  }
  entries.sort((a, b) => b.xp - a.xp);
  entries.forEach((e, i) => (e.rank = i + 1));
  return entries;
}

export async function gamificationRoutes(app: FastifyInstance) {
  // Daily quests with the user's progress today.
  app.get("/quests", { preHandler: app.authenticate }, async (req) => {
    const r = await pool.query(
      `select q.id, q.title_ru, q.title_en, q.target, q.reward_xp as "rewardXp",
              q.icon, q.color, q.sort,
              coalesce(uq.progress,0) as progress, coalesce(uq.claimed,false) as claimed
       from quests q
       left join user_quests uq on uq.quest_id = q.id and uq.user_id = $1 and uq.day = current_date
       order by q.sort`,
      [req.userId]
    );
    return r.rows.map((q) => ({
      id: q.id,
      title: { ru: q.title_ru, en: q.title_en },
      target: q.target,
      rewardXp: q.rewardXp,
      icon: q.icon,
      color: q.color,
      progress: q.progress,
      claimed: q.claimed,
      completed: q.progress >= q.target,
    }));
  });

  // Claim a completed, unclaimed quest → award XP.
  app.post("/quests/:id/claim", { preHandler: app.authenticate }, async (req, reply) => {
    const { id } = req.params as any;
    const q = await pool.query(
      `select q.target, q.reward_xp, coalesce(uq.progress,0) as progress, coalesce(uq.claimed,false) as claimed
       from quests q
       left join user_quests uq on uq.quest_id = q.id and uq.user_id = $1 and uq.day = current_date
       where q.id = $2`,
      [req.userId, id]
    );
    if (!q.rowCount) return reply.code(404).send({ error: "no quest" });
    const row = q.rows[0];
    if (row.progress < row.target) return reply.code(409).send({ error: "not completed" });
    if (row.claimed) return reply.code(409).send({ error: "already claimed" });
    await pool.query(
      `insert into user_quests(user_id, quest_id, day, progress, claimed)
       values ($1,$2,current_date,$3,true)
       on conflict (user_id, quest_id, day) do update set claimed = true`,
      [req.userId, id, row.target]
    );
    const reward = await awardPoints(pool, req.userId, row.reward_xp, "quest", "quest", null);
    return { ok: true, reward };
  });

  // Badges with progress + earned state.
  app.get("/badges", { preHandler: app.authenticate }, async (req) => {
    const r = await pool.query(
      `select b.id, b.title_ru, b.title_en, b.desc_ru, b.desc_en, b.icon, b.color, b.target, b.sort,
              coalesce(ub.progress,0) as progress, ub.earned_at as "earnedAt"
       from badges b
       left join user_badges ub on ub.badge_id = b.id and ub.user_id = $1
       order by b.sort`,
      [req.userId]
    );
    const badges = r.rows.map((b) => ({
      id: b.id,
      title: { ru: b.title_ru, en: b.title_en },
      desc: { ru: b.desc_ru, en: b.desc_en },
      icon: b.icon,
      color: b.color,
      target: b.target,
      progress: Math.min(b.progress, b.target),
      earned: b.earnedAt != null,
    }));
    return { earned: badges.filter((b) => b.earned).length, total: badges.length, badges };
  });

  app.get("/leaderboard", { preHandler: app.authenticate }, async (req) => {
    const board = (req.query as any)?.board === "league" ? "league" : "district";
    return { board, entries: await rankedBoard(board, req.userId) };
  });

  app.get("/league", { preHandler: app.authenticate }, async (req) => {
    const entries = await rankedBoard("league", req.userId);
    const leagues = await pool.query("select id, title_ru, title_en, color, sort from leagues order by sort");
    const currentLeagueId = "gold";
    const season = await pool.query("select (ends_on - current_date) as days_left from seasons limit 1");
    return {
      currentLeagueId,
      ladder: leagues.rows.map((l) => ({
        id: l.id,
        title: { ru: l.title_ru, en: l.title_en },
        color: l.color,
        current: l.id === currentLeagueId,
      })),
      entries,
      promotion: 5,
      demotion: 4,
      daysLeft: season.rows[0]?.days_left ?? 0,
    };
  });

  app.get("/season", { preHandler: app.authenticate }, async (req) => {
    const s = await pool.query(
      `select id, title_ru, title_en, tiers, (ends_on - current_date) as days_left from seasons limit 1`
    );
    if (!s.rowCount) return { season: null };
    const season = s.rows[0];
    const tiers = await pool.query(
      "select tier, reward_icon, reward_ru, reward_en from season_tiers where season_id = $1 order by tier",
      [season.id]
    );
    const us = await pool.query(
      "select current_tier from user_season where user_id = $1 and season_id = $2",
      [req.userId, season.id]
    );
    const currentTier = us.rows[0]?.current_tier ?? 0;
    return {
      id: season.id,
      title: { ru: season.title_ru, en: season.title_en },
      tiers: season.tiers,
      currentTier,
      daysLeft: season.days_left,
      rewards: tiers.rows.map((t) => ({
        tier: t.tier,
        icon: t.reward_icon,
        reward: { ru: t.reward_ru, en: t.reward_en },
        state: t.tier < currentTier ? "done" : t.tier === currentTier ? "current" : "locked",
      })),
    };
  });

  // Minimal analytics + ride-import hook (HLT → ride_km quest + km stat).
  app.post("/events", { preHandler: app.authenticate }, async (req) => {
    const b = (req.body ?? {}) as any;
    const name = String(b.name ?? "event").slice(0, 60);
    await pool.query("insert into events(user_id, name, props) values ($1,$2,$3::jsonb)", [
      req.userId,
      name,
      JSON.stringify(b.props ?? {}),
    ]);
    let reward = null;
    if (name === "ride_imported" && typeof b.props?.km === "number") {
      const km = Math.max(0, Math.min(500, Math.round(b.props.km)));
      await pool.query("update users set km_total = km_total + $2 where id = $1", [req.userId, km]);
      await bumpQuest(req.userId, "ride_km", km);
      await bumpBadge(req.userId, "marathon", km);
    }
    return { ok: true, reward };
  });
}
