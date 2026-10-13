# Steal a Dragon: analytics

Every play session and everything players do in it is stored in Supabase (the solbuild.net project), so we can
see **why people leave** and **what keeps the ones who stay**. Code: `src/server/Services/AnalyticsService.lua`
(server) and `src/client/Controllers/AnalyticsController.lua` (device, taps, frame rate, focus). The game posts a
batch every 10 seconds to the `roblox-analytics` edge function, using the same `discord_log` secret as the
Discord game log. Rows are tagged `game = 'ra2'`.

## Tables

**`roblox_sessions`**: one row per session.

| Column | What it is |
|---|---|
| `is_new`, `session_no`, `days_since_last` | first time ever? how many sessions so far? days since the last one |
| `country`, `locale`, `device`, `screen`, `premium`, `account_age_days` | who and on what |
| `join_source` | `direct`, `followed_friend`, `invite_link`, `launch:...` (ads and links), `teleport:...` |
| `friends_in_server`, `server_players` | playing with friends? how full the server was |
| `duration_s`, `end_reason` | how long they stayed; `left`, `left_loading` (gone before the save loaded), `shutdown` |
| `start` | progress when they joined: coins, income, dragons, castle, speed, weapon, passes, tutorial... |
| `summary` | when they left: the same progress, plus coins gained, bought, stole, bonks, collected, every action counted, button taps, the last 12 actions, idle or not, where they were, robbed in the last minute, left right after a purchase prompt |

**`roblox_events`**: one row per thing that happened. `t` is seconds since the session started.

| `kind` | When |
|---|---|
| `join`, `loaded`, `ui_ready`, `left_while_loading` | loading (with seconds) |
| `tutorial_step` (`step`, `text`), `tutorial_done`, `tutorial_skipped` | the tutorial |
| `buy_dragon` (`id`, `rarity`, `price`, `coins_left`), `placed_bought`, `placed_stolen`, `placed_returned` | dragons |
| `steal_start`, `being_robbed`, `got_robbed`, `bonk_hit`, `got_bonked`, `npc_raided`, `npc_escaped` | stealing and fighting |
| `lock`, `plate`, `castle_up`, `weapon_up`, `fever`, `egg_hatched`, `playtime_gift`, `daily_prize` | progress |
| `prompt` (`name`, `action`, `object`, `zone`) | every proximity prompt used (buy, steal, sell, level up...) |
| `req_*` (`req_lock`, `req_bonk`, `req_purchase`, `req_buyspeed`, `req_claimdaily`...) | every request the client sends |
| `purchase_prompt`, `purchase_result` (`bought` true or false), `purchase` | Robux: shown, bought or closed |
| `buy_now_offer`, `grow_offer`, `hatch_now_offer`, `potions_offer` | Robux offers shown in the world |
| `snapshot` | every minute: coins, income, dragons, castle, zone, idle, carrying, ping, tutorial step |
| `went_idle`, `came_back_from_idle` | no moving and no input for 45 seconds |
| `ui` (`taps`), `perf` (`fps`, `mem_mb`), `focus` (`on`), `client_info` | from the device |
| `leave` | the end (`reason`, `last` actions, `zone`, `idle`) |

## Reports (views)

| View | Answers |
|---|---|
| `roblox_retention` | per first-play day: new players, how many came back the next day (D1) and within a week (D7) |
| `roblox_tutorial_funnel` | how many first sessions reached each tutorial goal |
| `roblox_last_actions` | the last thing players did before leaving, counted, new vs returning |
| `roblox_first_session_drivers` | for each thing a player can do in their first session: % of those players who came back vs overall |
| `roblox_session_lengths` | session length buckets, new vs returning |
| `roblox_ui_taps` | which buttons get tapped, new vs returning |

## Questions to ask

```sql
-- Where do new players quit? Minute-by-minute survival of first sessions.
select (duration_s / 60) as minute, count(*) from roblox_sessions
where game = 'ra2' and session_no = 1 group by 1 order by 1;

-- What were people doing in the 60 seconds before they left?
select e.kind, count(*) from roblox_events e join roblox_sessions s using (session_id)
where s.game = 'ra2' and s.ended_at is not null and e.t > s.duration_s - 60
  and e.kind not in ('snapshot', 'ui', 'perf') group by 1 order by 2 desc;

-- Did getting robbed early drive new players away?
select (summary->'counts'->>'got_robbed') is not null as was_robbed, count(*), avg(duration_s)
from roblox_sessions where game = 'ra2' and session_no = 1 group by 1;

-- Does playing with friends keep people longer?
select friends_in_server > 0 as with_friends, count(*), avg(duration_s) from roblox_sessions
where game = 'ra2' group by 1;

-- Phones vs computers.
select device, count(*), avg(duration_s) from roblox_sessions where game = 'ra2' group by 1;
```
