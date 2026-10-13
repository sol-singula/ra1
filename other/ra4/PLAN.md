# ra4 plan: Snipe a Noob

Status: **plan, decisions made 2026-10-13, not built.** Every word a player sees is at a 3rd grade reading level. This doc is for us.
Decisions are at the bottom ([section 14](#14-decisions)).

## 1. What's out there (October 2026)

- **[UPD🔥] Sniper Arena** (9D GAME CLUB, released January 2026) is the model: first-person sniper deathmatch,
  fast respawns, rifles to unlock, skins from crates, global boards. About 9K to 10K players at once, peak about
  20K. Money: a membership (+20% credits), a squad bonus (+20%), crates, a battle pass, "case" and "secret" updates
  in the title tag.
- **SNIPER DUELS** sits just behind it at about 7K. **RIVALS** owns the shooter genre (145K to 220K) with short
  rounds, weapon skins and crates.
- **The gap:** nobody pairs a sniper arena with the "[Verb] a [Noun]" title style that owns the top of the charts,
  or with bright blocky art that reads on a phone. Sniper Arena looks realistic and grey.
- **Rules that matter here:**
  - Guns are allowed. Blocky, no blood, players "pop" into bricks: that keeps the Content Maturity label at
    **Mild** (non-realistic violence), so every age can play.
  - Crates bought with Robux, or with credits Robux can buy, need every item and its exact odds (adding to 100%)
    behind an "Odds" button. Players whose `PolicyService` restricts paid random items don't see crates and can't
    trade what came from them.
  - No paying to win kills: if a bought rifle shot better, kids would quit. Everything bought is cosmetic or speed
    of progress.

Sources: [Sniper Arena on RoWatcher](https://rowatcher.com/games/9534705677/upd-sniper-arena),
[Sniper Arena on Rotrends](https://rotrends.com/game/9534705677/UPD-Sniper-Arena),
[Shooter genre live counts](https://rowatcher.com/genres/Shooter),
[Most popular Roblox games](https://rowatcher.com/news/the-most-popular-roblox-games-right-now-ranked-by-live-players).

## 2. Title

Format: **[Verb] a [Noun]**, like ra2 and ra3.

| Pick | Why |
|---|---|
| **Snipe a Noob** (chosen) | "Noob" is the Roblox word every kid knows (the yellow default avatar). Funny, not mean, and it says the whole game in three words. |
| Snipe a Friend | Pushes friend invites, but sounds less exciting. |
| Snipe a Sniper | Clear, but a mouthful and less searchable. |

Title tags like ra2: `[🔥 NEW] Snipe a Noob`, later `[🎯 CRATES]`, `[⚡ 2X]`. Search the name on Roblox before
locking it in.

## 3. The game in one line

**"One shot, one pop. Most pops in 5 minutes wins."**

## 4. How it plays (3rd grade words)

1. **You spawn with a sniper.** There's a dot in the middle of your screen.
2. **Aim and tap.** One hit pops anyone into bricks. Every shot counts.
3. **Popped? Back in 5 seconds.** You spawn far from whoever got you, with 2 seconds of shield.
4. **The round is 5 minutes.** The top 3 stand on a podium. Then 15 seconds in the lobby, then the next round.
5. **Earn coins every pop.** Spend them in the lobby on skins, pop effects and new rifles that everyone sees.

Words on screen: Pop, Round, Coins, Level, Crate, Skin. A big kill feed on the right, your pop count big at the top.

### The shot

- **Hitscan** (no bullet travel), so it feels instant. The client sends "I shot from here, in this direction"; the
  server checks it against where players were a moment ago (lag compensation, about 200 ms back), line of sight
  and fire rate. The server decides every pop.
- **Hip fire** shows a wide crosshair that wobbles; **scoped** (right click, or the scope button on phones) zooms
  in and the dot goes steady after 0.3 s. A quick-scope is possible but harder: that's the skill ceiling.
- **Reload** after every shot (about 1.2 s, the bolt sound). No spraying.
- **Headshots** still pop in one, but pay double coins and show "🎯 HEADSHOT".
- **Phones:** a big FIRE button and a SCOPE button, light aim help when scoped (the dot slows a little over a
  target). Gamepad the same. Everyone plays in one pool.

### The lobby and the round loop

- **You join in the lobby.** It holds the leaderboards (TODAY'S TOP SNIPERS with a prize at 7pm ET, MOST POPS,
  BEST STREAK, HIGHEST LEVEL), the Shop, the Crate Machine, the Trade Plaza, a shooting range and a Duel pad.
- **The loop:** 15 s in the lobby (vote the next map on three pads) → 5 min round in the arena → 8 s podium →
  back to the lobby. Coins, crates and the shop all live in the lobby, so every player passes them every 5 minutes.
- **Join mid-round:** a big PLAY button (and a PLAY pad) drops you into the current round right away.
- **2 players is enough.** A round starts as soon as 2 players are in the server. With only 1, they shoot robot
  targets on the range and duel a practice robot while a sign says "Waiting for 1 more player...".
- **The map fits the crowd:** 2 to 8 players get a small map, 9 to 16 a medium one, 17 to 24 a big one, so a
  2-player round still finds action in seconds.

### The arena

- **24 players**, free for all.
- **4 maps to start** (each with a small, medium and large layout), bright brick style, each about 120 by 120 studs with towers, bridges and cover so you
  can't be shot from everywhere: Block Town, Candy Canyon, Space Dock (reuses ra3 parts), Castle Court (reuses ra2).
- **Spawns** pick the point farthest from enemies' sight lines. 2 s spawn shield (shown as a bubble) that breaks
  when you fire.
- **Fall off = back in 5 s,** no pop given (no free kills from the map).

## 5. Why a round is fun (and why you stay for the next)

- **Kill streaks:** 3 pops = "🔥 ON FIRE" (your name glows in the feed), 5 = "⚡ UNSTOPPABLE" (shows on the map
  for everyone, worth +1 bonus coin per pop), 10 = "👑 LEGEND" banner for the whole server.
- **Revenge:** pop the player who popped you last = "😤 REVENGE!" and bonus coins.
- **Bounty:** whoever leads the round wears a gold crown that everyone can see through walls for 2 s every 15 s.
  Pop them = **bounty bonus**. Comebacks every round.
- **Last minute:** the music speeds up and pops are worth 2x coins. The clock is always on screen.
- **Podium:** top 3 on a podium with their skin and emote for 8 seconds, then the next map loads in place
  (no teleport, no wait).
- **Rounds never wait:** join mid-round and play right away. Your pops count for that round.

## 6. Keeping them busy (the always-on task)

1. **Level bar** at the bottom: every pop and every round gives XP. Each level gives coins; some levels unlock a
   rifle or a skin. 100 levels for the first 20 hours.
2. **Daily quests** (3 a day): "Pop 15", "Get 3 headshots", "Win a round", "Pop the crown". They pay coins or
   crate keys.
3. **Playtime gifts** at 1, 3, 5, 10, 15, 20, 30, 45 and 60 minutes, and a **daily gift streak** (from ra2/ra3).
4. **New player:** the first round has 4 friendly robots (tagged "ROBOT") so you get your first pops fast, and 2x
   coins for 10 minutes.
5. **Season board** (2 weeks): pops this season. #1 gets a one-of-a-kind skin that's never sold.

## 7. Twists with friends (easy to understand)

Free for all only: no team rounds.

- **Squad bonus:** friends in the server give +10% coins each, up to +30% (ra3's team code).
- **Party spawn:** friends spawn a little closer to each other (still fair game).
- **Duel a friend:** walk on the Duel pad in the lobby with a friend for a 1v1, first to 5.
- **Shared streak:** two friends who both get a pop within 3 s get "🤝 DOUBLE TAP" and bonus coins.

## 8. Why players stay

| Roblox signal | Our feature |
|---|---|
| **Play-through rate** | Plain thumbnails: a blocky kid scoping in, a red dot on a silhouette, a big "?" or "SNIPE A NOOB". Start from ra2's mystery-silhouette formula (best CTR). |
| **First-play bounce** | Shooting within 5 seconds of joining. Robots in the first round. A pop in the first 20 seconds for almost everyone. |
| **Session length** | 5-minute rounds back to back, streaks, bounty, the level bar always moving, playtime gifts. |
| **Day 2** | Daily quests, daily gift streak, the daily TOP SNIPER board with a prize at 7pm ET (ra2/ra3 code). |
| **Co-play** | Squad bonus, party spawn, duels, double tap. |
| **Spend** | Section 9. |

## 9. What coins are for (and why players want them)

Coins only matter if spending them changes **how other players see you**. In a shooter, the moments you're seen
are: the kill feed, the podium, and the second someone gets popped by you. So:

- **Pop cam:** when you're popped, your 5 s wait shows the player who got you: their name, level, rifle skin and pop
  effect, from their side. Every death is a 5-second ad for someone else's stuff. That's why a skin is worth coins.
- **The kill feed** shows the rifle skin icon: "Ava [🌌 Galaxy] 🎯 Ben".
- **The podium** shows the top 3 with their skin, pop effect and emote for 8 s.

What coins buy (all in the lobby):

| Buy with coins | Price | Why kids want it |
|---|---|---|
| **Daily Shop:** 6 skins, 2 pop effects, 2 emotes, new every day at 7pm ET | 500 to 25,000 | Fresh every day = a reason to come back and save up |
| **Coin Crate** (odds shown) | 2,000 | A surprise, and the only free way to a Legend skin |
| **Rifles** (side-grades, all still one-shot): Bolt (default), Swift (fast bolt, less zoom), Eagle (big zoom, slow bolt), Ghost (no tracer line), Twin (two shots, then a long reload) | 5,000 to 60,000, unlocked by level | A new way to play, not a stronger one |
| **Crosshair styles and kill-feed name colours** | 1,000 to 10,000 | Small flex, cheap, a first purchase in the first session |
| **Rifle Mastery:** pop 100 / 500 / 2,000 with a rifle to unlock its gold, diamond and rainbow looks | free, needs pops | Long goal for each rifle |

How many coins: 10 a pop, 20 a headshot, +5 a pop on a streak, 50 for the crown, 2x in the last minute, 100 / 60 / 30
for the podium. A normal round pays about 150 to 300, so the first crosshair is in the first session and a Daily
Shop skin takes a day or two of play. Robux can't buy coins directly (the 2x Coins and VIP passes speed them up),
so coins always mean "I played".

## 10. Making money

Nothing bought shoots better. Everything random shows its odds. Nothing pays Robux to players.

**Tier 1: buy once**

| Pass | Robux |
|---|---|
| VIP: +20% coins, gold name in the feed, VIP podium pose | 399 |
| 2x Coins | 299 |
| Extra Loadout (switch between 2 rifles mid-round) | 199 |
| Custom Pop Effect (choose how your targets pop: confetti, candy, pixels...) | 249 |

**Tier 2: buy again and again**

| Product | Robux |
|---|---|
| Crate Keys (1 / 5 / 15) | 49 / 199 / 499 |
| Credits packs (the premium currency) | 99 to 1,999 |
| Round Callout: your name in gold when the next round starts | 99 |
| Revive Now (skip the 5 s respawn wait, once) | 9 |
| Season Pass (2 weeks): 50 tiers of skins, emotes, pop effects | 399 |

**Tier 3: skins economy**

- **Crates:** Common to Secret skins for rifles, with odds on every crate. Crate keys come from levels and quests
  too, so free players open some.
- **Trading skins** at a Trade Plaza (ra3's stalls) for credits, with our 10% credit tax. Policy-checked.
- **Rifles** are unlocked with coins by level (more zoom, faster bolt, quieter shot). They are side-grades:
  every rifle still pops in one.

Revive Now needs a careful look: 5 seconds is short, so it may not sell; we test it and drop it if it feels bad.

## 11. Rules we keep

- Odds on every crate, behind an "Odds" button, adding to 100%.
- No blood, no gore, no realistic guns: blocky, bright, players pop into bricks. Content maturity: Mild.
- Spawn shield, so nobody farms spawns.
- Anti-cheat on the server: fire rate, line of sight, aim snap checks, kill rate outliers logged to Discord.
- No rewards for watching anything. Prices shown before every purchase.

## 12. Small enough to build

Most of ra2 and ra3 comes over:

| From | Used for |
|---|---|
| ra3 services, Loader, Net, Store, Theme, HUD, panels, tests, renderer | Everything |
| ra3 Blast (hitscan, beams, popups) | The shot (plus lag compensation and scope) |
| ra3 Forge odds, roll tables | Crates and their Odds page |
| ra3 Trade Plaza, PolicyService checks | Skin trading |
| ra2/ra3 leaderboards, daily board, prize, Discord log | Daily TOP SNIPER, season board, logs |
| ra2/ra3 goals, quests, playtime gifts, daily gifts, new-player boost | As-is |
| ra3 team service, robots | Squad bonus, first-round robots |
| ra2 castle, ra3 space parts | Two of the four maps |

New:
- **First-person camera and scope:** lock to first person in a round, zoom, sway, crosshair, hit marker, kill feed.
- **Lobby:** boards, shop, crate machine, range, duel pad, map vote, PLAY pad.
- **Round manager:** 5-minute clock, scores, streaks, bounty, podium, map vote and size by player count, starts
  at 2 players.
- **Pop cam:** a 5 s camera on the shooter while you wait.
- **Spawn picker** and spawn shield.
- **Server hit check** with lag compensation (keep each player's last 1 s of positions).
- **Rifle viewmodel** and skins (box style, recoloured).

## 13. Build order

1. **The lobby, one map, the rifle, the shot, pops, respawn, the round loop (starts at 2), the podium.**
2. **Kill feed, streaks, revenge, bounty, last-minute 2x, sounds and music.**
3. **Levels, coins, the Daily Shop, rifles, crosshairs, mastery, daily quests, gifts, robots for new players.**
4. **The other 3 maps (3 sizes each), map vote, duels, pop cam.**
5. **Skins, crates with odds, shop, passes, products.**
6. **Season pass and season board, lobby leaderboards with the daily TOP SNIPER prize, Discord log.**
7. **Trade Plaza for skins.**
8. **Thumbnails, icon, publish.**

## 14. Decisions

| Question | Answer |
|---|---|
| Title | **Snipe a Noob** |
| "Past games" | Fast games: short rounds, no waiting |
| Phone aim help | Light, when scoped |
| Team (Squads) rounds | Never: free for all only |
| Trading skins | Yes, like ra3 |
| Server size | 24 |
| Lobby | Yes, with leaderboards |
| Minimum to start a round | 2 players |
| Rifles | Side-grades unlocked by level (all one-shot). Not answered yet; this is the default. |
