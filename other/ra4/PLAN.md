# ra4 plan: Snipe a Noob (working title)

Status: **first draft, not built.** Every word a player sees is at a 3rd grade reading level. This doc is for us.
Open decisions are at the bottom ([section 13](#13-decisions-for-you)).

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
| **Snipe a Noob** (recommended) | "Noob" is the Roblox word every kid knows (the yellow default avatar). Funny, not mean, and it says the whole game in three words. |
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
4. **The round is 5 minutes.** The top 3 stand on a podium. Then a new round on a new map.
5. **Earn coins every pop.** Buy new rifles and skins. Level up.

Words on screen: Pop, Round, Coins, Level, Crate, Skin. A big kill feed on the right, your pop count big at the top.

### The shot

- **Hitscan** (no bullet travel), so it feels instant. The client sends "I shot from here, in this direction"; the
  server checks it against where players were a moment ago (lag compensation, about 200 ms back), line of sight
  and fire rate. The server decides every pop.
- **Hip fire** shows a wide crosshair that wobbles; **scoped** (right click, or the scope button on phones) zooms
  in and the dot goes steady after 0.3 s. A quick-scope is possible but harder: that's the skill ceiling.
- **Reload** after every shot (about 1.2 s, the bolt sound). No spraying.
- **Headshots** still pop in one, but pay double coins and show "🎯 HEADSHOT".
- **Phones:** a big FIRE button and a SCOPE button, light aim help when scoped (sticks a little on a target).
  Gamepad the same. Phone players only fight phone players? No: one pool, aim help evens it out.

### The arena

- **20 players**, free for all.
- **4 small maps to start**, bright brick style, each about 120 by 120 studs with towers, bridges and cover so you
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

- **Squad bonus:** friends in the server give +10% coins each, up to +30% (ra3's team code).
- **Party spawn:** friends spawn near each other and never count each other as targets in a "Squads" round
  (every 4th round is Squads: teams of up to 4, team with most pops wins).
- **Duel a friend:** walk on the Duel pad in the lobby with a friend for a 1v1, first to 5.
- **Shared streak:** two friends who both get a pop within 3 s get "🤝 DOUBLE TAP" and bonus coins.

## 8. Why players stay

| Roblox signal | Our feature |
|---|---|
| **Play-through rate** | Plain thumbnails: a blocky kid scoping in, a red dot on a silhouette, a big "?" or "SNIPE A NOOB". Start from ra2's mystery-silhouette formula (best CTR). |
| **First-play bounce** | Shooting within 5 seconds of joining. Robots in the first round. A pop in the first 20 seconds for almost everyone. |
| **Session length** | 5-minute rounds back to back, streaks, bounty, the level bar always moving, playtime gifts. |
| **Day 2** | Daily quests, daily gift streak, the daily TOP SNIPER board with a prize at 7pm ET (ra2/ra3 code). |
| **Co-play** | Squad bonus, Squads rounds, duels, double tap. |
| **Spend** | Section 9. |

## 9. Making money

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

## 10. Rules we keep

- Odds on every crate, behind an "Odds" button, adding to 100%.
- No blood, no gore, no realistic guns: blocky, bright, players pop into bricks. Content maturity: Mild.
- Spawn shield, so nobody farms spawns.
- Anti-cheat on the server: fire rate, line of sight, aim snap checks, kill rate outliers logged to Discord.
- No rewards for watching anything. Prices shown before every purchase.

## 11. Small enough to build

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
- **Round manager:** 5-minute clock, scores, streaks, bounty, podium, map rotation, Squads every 4th round.
- **Spawn picker** and spawn shield.
- **Server hit check** with lag compensation (keep each player's last 1 s of positions).
- **Rifle viewmodel** and skins (box style, recoloured).

## 12. Build order

1. **One map, the rifle, the shot, pops, respawn, the round clock, the podium.** Playable end to end.
2. **Kill feed, streaks, revenge, bounty, last-minute 2x, sounds and music.**
3. **Levels, coins, rifles to unlock, daily quests, playtime and daily gifts, robots for new players.**
4. **The other 3 maps and map rotation, Squads rounds, duels.**
5. **Skins, crates with odds, shop, passes, products.**
6. **Season pass and season board, daily TOP SNIPER, Discord log.**
7. **Trade Plaza for skins.**
8. **Thumbnails, icon, publish.**

## 13. Decisions for you

My pick is first in each line. Say "go" to take them all.

1. **Title:** Snipe a Noob / Snipe a Friend / Snipe a Sniper / your own.
2. **"Past games":** I read this as "fast games" (short rounds, no waiting). If you meant a match history screen,
   I'll add one.
3. **Phones:** light aim help when scoped / none.
4. **Squads rounds:** every 4th round / never (pure free for all).
5. **Trading skins:** yes, like ra3 / no, keep it simple.
6. **Server size:** 20 / 16 (smaller maps feel busier) / 24.
7. **Rifles:** side-grades unlocked by level (all one-shot) / one rifle, skins only.
