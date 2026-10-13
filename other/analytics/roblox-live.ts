import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

/**
 * Read-only live view of the studio's Roblox games for the team's dashboards: other/live.html (every game, with a
 * game switcher) and other/ra2/live.html (Steal a Dragon only). This file is other/analytics/roblox-live.ts.
 *   GET ?game=ra2  with header X-View-Key (or ?key=)
 * -> { now, servers: [ { server_no, job_id, version, reported_players, last_seen, players: [ ... ] } ],
 *      today: { ... last 24 h ... }, recent: [ the last 15 sessions ],
 *      stats: { compare: { hour|day|week: { now, prev } }, hourly: [ 48 hours ], versions: [ per game version ],
 *               feedback: { all, day, liked, disliked, reasons, recent }, notify: { on_list, shown_players, ... } } }
 *   GET ?summary=1  (same key): how many are on each game, for the "N online" counts on other/live.html's switcher
 * -> { now, games: { ra2: { online, sessions_24h }, ra3: { ... }, ra4: { ... }, ra5: { ... }, ra7: { ... } } }
 *      online        distinct players with an open session refreshed in the last 2 minutes
 *      sessions_24h  sessions started in the last 24 hours
 *    Cached for 15 seconds.
 *
 * Servers come from two places, merged by job id:
 *   roblox_servers   every server that posted to the Discord game log in the last 10 minutes (any game version)
 *   roblox_sessions  open sessions (refreshed in the last 2 minutes, or older versions still on a live server)
 *
 * Metrics (for any set of sessions): players, new players, sessions, avg minutes (ended sessions), and for new
 * players' ended sessions: % who quit in under a minute, % who stayed 3+ minutes, % who finished the tutorial;
 * plus Robux purchases. Each version also gets phone frame rate (roblox_phone_fps) and the in-game "Do you like
 * the game?" answers (roblox_feedback, with the reasons picked after a thumbs down). Notification list size comes
 * from roblox_notify_summary. Stats are cached for a minute, per game.
 *
 * The view key only reads this; it can't write anything. Only its SHA-256 is kept here.
 */

const VIEW_KEY_SHA256 = "8022e9bd65e2446656d8bfdc62791367ff84846a3f8450700d286a22fb0787df";
const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "x-view-key, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", ...CORS } });
}

async function sha256(text: string) {
  const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, {
  auth: { persistSession: false },
});

const HOUR = 3600_000;
const headshotCache = new Map<number, { url: string; at: number }>();
async function headshots(ids: number[]) {
  const need = ids.filter((id) => !headshotCache.has(id) || Date.now() - headshotCache.get(id)!.at > HOUR);
  for (let i = 0; i < need.length; i += 90) {
    const chunk = need.slice(i, i + 90);
    try {
      const res = await fetch(
        `https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${chunk.join(",")}&size=150x150&format=Png&isCircular=false`,
      );
      if (res.ok) {
        const body = await res.json();
        for (const d of body.data || []) if (d.imageUrl) headshotCache.set(d.targetId, { url: d.imageUrl, at: Date.now() });
      }
    } catch (_) { /* no pictures this time */ }
  }
  const out: Record<number, string> = {};
  for (const id of ids) if (headshotCache.has(id)) out[id] = headshotCache.get(id)!.url;
  return out;
}

const nameCache = new Map<number, { name: string; display: string; at: number }>();
async function names(ids: number[]) {
  const need = ids.filter((id) => !nameCache.has(id) || Date.now() - nameCache.get(id)!.at > HOUR);
  for (let i = 0; i < need.length; i += 100) {
    try {
      const res = await fetch("https://users.roblox.com/v1/users", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userIds: need.slice(i, i + 100), excludeBannedUsers: false }),
      });
      if (res.ok) {
        const body = await res.json();
        for (const u of body.data || []) nameCache.set(u.id, { name: u.name, display: u.displayName, at: Date.now() });
      }
    } catch (_) { /* ids this time */ }
  }
}

function withName<T extends Record<string, unknown>>(s: T): T {
  const n = nameCache.get(Number(s.user_id));
  return { ...s, username: s.username || n?.name || null, display_name: s.display_name || n?.display || null };
}

// Stats -------------------------------------------------------------------------------------------------------
type Row = { user_id: number; is_new: boolean | null; duration_s: number | null; started_at: string; place_version: number | null; td: unknown; pur: unknown };
type Fb = { user_id: number; username: string | null; display_name: string | null; place_version: number | null; device: string | null; is_new: boolean | null; at: string; liked: boolean; text: string | null; minutes: number | null; bonked: number | null; robbed: number | null; reasons: string[] | null };

const pct = (n: number, d: number) => (d ? Math.round((1000 * n) / d) / 10 : null);
const avg = (xs: number[]) => (xs.length ? Math.round((10 * xs.reduce((a, b) => a + b, 0)) / xs.length) / 10 : null);
function metrics(rows: Row[]) {
  const ended = rows.filter((r) => typeof r.duration_s === "number");
  const newEnded = ended.filter((r) => r.is_new);
  return {
    sessions: rows.length,
    players: new Set(rows.map((r) => r.user_id)).size,
    new_players: new Set(rows.filter((r) => r.is_new).map((r) => r.user_id)).size,
    avg_min: ended.length ? Math.round(ended.reduce((a, r) => a + (r.duration_s as number), 0) / ended.length / 6) / 10 : null,
    quick_quit_pct: pct(newEnded.filter((r) => (r.duration_s as number) < 60).length, newEnded.length),
    stay3_pct: pct(newEnded.filter((r) => (r.duration_s as number) >= 180).length, newEnded.length),
    tutorial_pct: pct(newEnded.filter((r) => r.td != null).length, newEnded.length),
    robux: rows.reduce((a, r) => a + (Number(r.pur) || 0), 0),
  };
}
function likes(rs: Fb[]) {
  const up = rs.filter((r) => r.liked).length;
  return { answers: rs.length, likes: up, dislikes: rs.length - up, like_pct: pct(up, rs.length) };
}
function profile(rs: Fb[]) {
  return {
    n: rs.length,
    minutes: avg(rs.map((r) => Number(r.minutes) || 0)),
    bonked: avg(rs.map((r) => Number(r.bonked) || 0)),
    robbed: avg(rs.map((r) => Number(r.robbed) || 0)),
    phone_pct: pct(rs.filter((r) => r.device === "touch").length, rs.length),
    new_pct: pct(rs.filter((r) => r.is_new).length, rs.length),
  };
}

// one entry per game, so a dashboard switching between games doesn't make each one start over
const statsCache = new Map<string, { at: number; body: unknown }>();
async function stats(game: string) {
  const cached = statsCache.get(game);
  if (cached && Date.now() - cached.at < 60_000) return cached.body;
  const since = new Date(Date.now() - 14 * 24 * HOUR).toISOString();
  const rows: Row[] = [];
  for (let from = 0; from < 50000; from += 1000) {
    const { data, error } = await db.from("roblox_sessions")
      .select("user_id,is_new,duration_s,started_at,place_version,td:summary->counts->tutorial_done,pur:summary->counts->purchase")
      .eq("game", game).gte("started_at", since).order("started_at", { ascending: true }).range(from, from + 999);
    if (error || !data) break;
    rows.push(...(data as unknown as Row[]));
    if (data.length < 1000) break;
  }
  const now = Date.now();
  const within = (a: number, b: number) => rows.filter((r) => { const t = Date.parse(r.started_at); return t >= now - a && t < now - b; });
  const compare = {
    hour: { now: metrics(within(HOUR, 0)), prev: metrics(within(2 * HOUR, HOUR)) },
    day: { now: metrics(within(24 * HOUR, 0)), prev: metrics(within(48 * HOUR, 24 * HOUR)) },
    week: { now: metrics(within(7 * 24 * HOUR, 0)), prev: metrics(within(14 * 24 * HOUR, 7 * 24 * HOUR)) },
  };
  const hourly = [];
  const top = Math.floor(now / HOUR) * HOUR;
  for (let h = 47; h >= 0; h--) {
    const start = top - h * HOUR;
    const inHour = rows.filter((r) => { const t = Date.parse(r.started_at); return t >= start && t < start + HOUR; });
    hourly.push({ t: new Date(start).toISOString(), ...metrics(inHour) });
  }
  const byVersion = new Map<number, Row[]>();
  for (const r of rows) {
    const v = r.place_version ?? 0;
    if (!byVersion.has(v)) byVersion.set(v, []);
    byVersion.get(v)!.push(r);
  }
  const [fpsQ, fbQ, nsQ] = await Promise.all([
    db.from("roblox_phone_fps").select("place_version,avg_fps,under30_pct,samples").eq("game", game),
    db.from("roblox_feedback").select("user_id,username,display_name,place_version,device,is_new,at,liked,text,minutes,bonked,robbed,reasons").eq("game", game).order("at", { ascending: false }).limit(2000),
    db.from("roblox_notify_summary").select("on_list,shown_players,ever_opted,left_list,opted_24h").eq("game", game).maybeSingle(),
  ]);
  const fpsBy = new Map((fpsQ.data || []).map((f: Record<string, any>) => [f.place_version ?? 0, f]));
  const fb = (fbQ.data || []) as Fb[];
  const versions = [...byVersion.entries()].map(([v, rs]) => {
    const f = fpsBy.get(v) as Record<string, any> | undefined;
    const vfb = likes(fb.filter((r) => (r.place_version ?? 0) === v));
    return {
      version: v || null,
      first_seen: rs[0].started_at,
      last_seen: rs[rs.length - 1].started_at,
      ...metrics(rs),
      phone_fps: f?.avg_fps != null ? Number(f.avg_fps) : null,
      phone_under30_pct: f?.under30_pct != null ? Number(f.under30_pct) : null,
      like_pct: vfb.like_pct,
      answers: vfb.answers,
    };
  }).sort((a, b) => (b.version ?? 0) - (a.version ?? 0));
  const reasons: Record<string, number> = {};
  const dislikes = fb.filter((r) => !r.liked);
  for (const r of dislikes) for (const k of Array.isArray(r.reasons) ? r.reasons : []) reasons[k] = (reasons[k] || 0) + 1;
  const feedback = {
    all: likes(fb),
    day: likes(fb.filter((r) => Date.parse(r.at) >= now - 24 * HOUR)),
    liked: profile(fb.filter((r) => r.liked)),
    disliked: profile(dislikes),
    reasons,
    dislikes_with_reason: dislikes.filter((r) => Array.isArray(r.reasons) && r.reasons.length).length,
    recent: fb.slice(0, 40).map((r) => withName(r as unknown as Record<string, unknown>)),
  };
  const ns = (nsQ.data || {}) as Record<string, number>;
  const notify = {
    on_list: Number(ns.on_list) || 0,
    shown_players: Number(ns.shown_players) || 0,
    ever_opted: Number(ns.ever_opted) || 0,
    left_list: Number(ns.left_list) || 0,
    opted_24h: Number(ns.opted_24h) || 0,
    accept_pct: pct(Number(ns.ever_opted) || 0, Number(ns.shown_players) || 0),
  };
  const body = { compare, hourly, versions, since, feedback, notify };
  statsCache.delete(game); // added again at the end, so the Map stays oldest first
  statsCache.set(game, { at: Date.now(), body });
  for (const old of statsCache.keys()) if (statsCache.size > 20) statsCache.delete(old); // ?game= is free text
  return body;
}

// Summary (?summary=1) ----------------------------------------------------------------------------------------
// Two small queries per game, all at once: the user ids of open sessions refreshed in the last 2 minutes (each
// player counted once), and a head-only count of the sessions started in the last 24 hours.
const SUMMARY_GAMES = ["ra2", "ra3", "ra4", "ra5", "ra7"];
let summaryCache: { at: number; body: unknown } | null = null;
async function summary() {
  if (summaryCache && Date.now() - summaryCache.at < 15_000) return summaryCache.body;
  const now = Date.now();
  const liveSince = new Date(now - 120_000).toISOString();
  const daySince = new Date(now - 24 * HOUR).toISOString();
  let failed = false;
  const entries = await Promise.all(SUMMARY_GAMES.map(async (game) => {
    const [openQ, dayQ] = await Promise.all([
      db.from("roblox_sessions").select("user_id").eq("game", game).is("ended_at", null).gte("updated_at", liveSince).limit(1000),
      db.from("roblox_sessions").select("session_id", { count: "exact", head: true }).eq("game", game).gte("started_at", daySince),
    ]);
    if (openQ.error || dayQ.error) failed = true;
    return [game, {
      online: openQ.error ? null : new Set((openQ.data || []).map((s) => s.user_id)).size,
      sessions_24h: dayQ.error ? null : dayQ.count ?? 0,
    }] as const;
  }));
  const body = { now: new Date(now).toISOString(), games: Object.fromEntries(entries) };
  if (!failed) summaryCache = { at: Date.now(), body }; // after a failed query, the next call asks again
  return body;
}

type Server = {
  server_no: number | null;
  job_id: string;
  version: number | null;
  reported_players: number | null;
  last_seen: string | null;
  players: Record<string, unknown>[];
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: CORS });
  const url = new URL(req.url);
  const key = req.headers.get("x-view-key") || url.searchParams.get("key") || "";
  if (!key || (await sha256(key)) !== VIEW_KEY_SHA256) return json({ error: "not allowed" }, 401);
  if (url.searchParams.get("summary") === "1") return json(await summary());
  const game = (url.searchParams.get("game") || "ra2").slice(0, 40);
  const now = new Date();
  const liveSince = new Date(now.getTime() - 120_000).toISOString();
  const serverSince = new Date(now.getTime() - 600_000).toISOString();
  const openSince = new Date(now.getTime() - 6 * HOUR).toISOString();

  const cols = "session_id,user_id,username,display_name,server_no,job_id,place_version,started_at,is_new,session_no,device,country,premium,join_source,friends_in_server,live,start,updated_at";
  const [openQ, serversQ, recentQ, statsBody] = await Promise.all([
    db.from("roblox_sessions").select(cols).eq("game", game).is("ended_at", null).gte("started_at", openSince).limit(1000),
    db.from("roblox_servers").select("job_id,server_no,players,version,last_seen,started_at").eq("game", game).is("closed_at", null).gte("last_seen", serverSince).limit(200),
    db.from("roblox_sessions").select("user_id,username,display_name,server_no,job_id,started_at,ended_at,duration_s,is_new,end_reason,device,summary->last_actions,summary->earned_gained").eq("game", game).not("ended_at", "is", null).order("ended_at", { ascending: false }).limit(15),
    stats(game),
  ]);
  if (openQ.error) return json({ error: openQ.error.message }, 500);

  const aliveJobs = new Set((serversQ.data || []).map((s) => s.job_id));
  const latest = new Map<number, Record<string, unknown>>();
  for (const s of openQ.data || []) {
    const fresh = (s.updated_at as string) >= liveSince;
    const oldVersionStillOn = s.live == null && aliveJobs.has(s.job_id as string);
    if (!fresh && !oldVersionStillOn) continue;
    const id = Number(s.user_id);
    const prev = latest.get(id);
    if (!prev || (prev.started_at as string) < (s.started_at as string)) latest.set(id, s);
  }
  const live = [...latest.values()];
  const recentRows = recentQ.data || [];
  const ids = [...new Set([...live.map((s) => Number(s.user_id)), ...recentRows.map((s) => Number(s.user_id))])];
  const missing = [...live, ...recentRows].filter((s) => !s.username).map((s) => Number(s.user_id));
  const [pics] = await Promise.all([headshots(ids), names([...new Set(missing)])]);

  const byJob = new Map<string, Server>();
  const get = (job: string) => {
    if (!byJob.has(job)) byJob.set(job, { server_no: null, job_id: job, version: null, reported_players: null, last_seen: null, players: [] });
    return byJob.get(job)!;
  };
  for (const s of serversQ.data || []) {
    const srv = get(s.job_id);
    srv.server_no = s.server_no ?? srv.server_no;
    srv.version = s.version ?? srv.version;
    srv.reported_players = s.players ?? null;
    srv.last_seen = s.last_seen;
  }
  for (const raw of live) {
    const s = withName(raw) as Record<string, any>;
    const srv = get(s.job_id || "unknown");
    if (srv.server_no == null && s.server_no != null) srv.server_no = s.server_no;
    if (srv.version == null && s.place_version != null) srv.version = s.place_version;
    srv.players.push({
      user_id: s.user_id,
      username: s.username,
      display_name: s.display_name,
      headshot: pics[Number(s.user_id)] || null,
      started_at: s.started_at,
      is_new: s.is_new,
      session_no: s.session_no,
      device: s.device,
      country: s.country,
      premium: s.premium,
      join_source: s.join_source,
      friends_in_server: s.friends_in_server,
      live: s.live,
      start_coins: s.start?.coins ?? null,
      updated_at: s.updated_at,
    });
  }
  const servers = [...byJob.values()].sort((a, b) =>
    (a.server_no ?? 999) - (b.server_no ?? 999) || (b.version ?? 0) - (a.version ?? 0)
  );
  const numberOf = new Map(servers.map((s) => [s.job_id, s.server_no]));
  const day = (statsBody as { compare: { day: { now: ReturnType<typeof metrics> } } }).compare.day.now;
  const today = {
    sessions: day.sessions,
    players: day.players,
    new_players: day.new_players,
    avg_minutes: day.avg_min,
    robux_sessions: day.robux,
  };
  const recent = recentRows.map((s) => ({
    ...withName(s as Record<string, unknown>),
    server_no: s.server_no ?? numberOf.get(s.job_id as string) ?? null,
    headshot: pics[Number(s.user_id)] || null,
  }));
  return json({ now: now.toISOString(), game, servers, today, recent, stats: statsBody });
});
