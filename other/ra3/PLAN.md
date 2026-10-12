# ra3 plan: Raid a Planet

Status: **built (all 9 steps), waiting on a Roblox experience to publish to.** See [README](README.md) for how to
run and play it. Every word a player sees is at a 3rd grade reading level. This doc is for us.

## 1. What's trending (October 2026)

- **"[Verb] a [Noun]" titles still own the charts.** Steal An Egg is #1 (about 0.9 to 1.5 million players at once),
  Steal a Brainrot is top 10, and Ride A Pet and Break and Steal an Egg are in the top 30.
- **Forge games are hot right now.** "+1 Loot To Forge" (clear a dungeon, haul ore to the hub, forge better gear,
  rebirth) sits in Roblox's own top-playing list with a [BOSS] tag. "+1 ___" is the other title pattern of the moment.
- **Boss and raid games exist but none is big.** Blox Fruits has raids and bosses, but it's an old anime RPG.
  Nobody owns the words "raid" or "planet" in a title.
- **Co-op survival is big.** 99 Nights in the Forest (about 150K players) shows kids want a goal they do together.
- **Rules that changed:**
  - Random rolls bought with Robux, or with any currency Robux can buy (our Gems), must show every outcome and its
    exact odds, adding to 100%, behind a button that says "Odds" or "Info". The page was updated 2026-08-19.
  - Players who can't buy random items (some ages and countries) also can't trade what they drop. We check
    `PolicyService` and hide those for them.
  - Avatar items (clothing, UGC) sold inside a game give the game owner 40%. Other people's gamepasses give us 0.
  - A game can never send Robux to a player. So no "auction house for Robux". Trades are items and Gems only.

Sources: [Roblox charts](https://www.roblox.com/charts), [Live charts](https://livecounts.nl/roblox-charts/),
[+1 Loot To Forge guide](https://nerdschalk.com/1-loot-to-forge-progression-guide-dungeon-ores-forging-and-rebirths/),
[Paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items),
[Marketplace fees and commissions](https://create.roblox.com/docs/marketplace/marketplace-fees-and-commissions).

## 2. Title

Format: **[Verb] a [Noun]**, like ra2.

| Pick | Why |
|---|---|
| **Raid a Planet** (recommended) | The verb is the whole game. "Planet" says space in one word and lets every planet be a new level. No big game uses it. |
| Loot a Planet | "Loot" is the forge-game word right now, but it says less about teams. |
| +1 Loot in Space | Copies the "+1" trend, but that trend is younger and could die first. |

Before locking it in, search the name on Roblox and check that no big game already uses it.

## 3. The game in one line

**"Blast space bugs. Forge a bigger blaster. Every 15 minutes, the whole server fights one giant boss."**

- **Core fantasy:** get strong, then show it off.
- **Implied challenge:** the boss has billions of health. You can't do it alone.

## 4. How it plays (3rd grade words)

1. **Blast bugs.** Hold the button. Bugs drop ore and coins.
2. **Go to the Forge.** Put ore in. Wait. Get a new blaster.
3. **Your blaster has a roll.** Most are plain. Some are shiny. A few are GOD rolls.
4. **Beat the planet boss.** Open the next planet.
5. **The big raid.** Every 15 minutes a portal opens. Everyone jumps in and fights one giant boss.
6. **Top 5 damage** go on the big board in the sky. Everyone sees your blaster.
7. **Trade.** Swap blasters and pets with other players at the Trade Plaza.

Words on screen: Blast, Ore, Forge, Blaster, Boss, Raid, Gems, Trade. Icons and arrows over text.

### Blasters (the main collectible)

- **One model, many looks.** Like ra2's dragons: boxes, bright colours, glowing parts. Rarity by colour and glow:
  Common, Rare, Epic, Legend, Secret, and raid-only Ultra.
- **Every blaster has a roll:** Damage, Speed, Luck and Gem Find, each plain, shiny, or GOD. A GOD roll is 1 in
  1,000. The odds are shown on the Forge. GOD rolls are the thing people trade for.
- **Pets** are helpers that float next to you and add a little damage or luck. They come from the raid and from
  eggs. They're the second collectible, not the first.

### Planets

- 8 planets in a ring around the Hub, each with its own colour, bugs and boss: Dust, Ice, Lava, Jungle, Crystal,
  Storm, Shadow, Sun.
- Each planet is a small open map. Bugs come to you, so there's always a target.
- **Solo scaling:** bug health, boss health and ore drops scale to how many players are near. One player can beat
  every planet alone. The boss just takes longer and drops a little less.

## 5. Keeping them busy (the always-on task)

A player should never wonder what to do. One goal on screen at all times, in this order:

1. **The goal card** (reuse ra2's): "Blast 10 bugs", "Forge a blaster", "Beat the Dust boss", "Join a raid"...
   Every goal pays coins or ore. 60 goals cover the first 10 hours.
2. **The forge timer** always shows at the top: "⚒️ Rare Blaster: 4:12". When it's done it flashes. You always
   have something cooking.
3. **The raid countdown** always shows: "☄️ RAID IN 6:30". The hype builds twice every half hour.
4. **Playtime gifts** (ra2's) at 1, 3, 5, 10, 15, 20, 30, 45 and 60 minutes, with the next one shown.
5. **Daily quests** (3 a day): "Beat 2 bosses", "Forge 3 blasters", "Join 1 raid". They pay Gems. This is the
   main free Gem source.

After "100% done" (all 8 bosses, about 30 to 40 hours):
- **Rebirth:** reset planets, keep blasters and pets, get a star on your name and +25% damage for ever. Each
  rebirth adds a star. Stars show on the raid board.
- **Nightmare planets:** the same 8 with 10x health and better rolls. They unlock at rebirth 1.
- **Weekly raid board** with an Ultra blaster for #1 that no one can forge.

## 6. The raid (every 15 minutes, 30 players)

- **Servers hold 30.** Easier to fill than 50, so raids feel full more often, and it runs well on phones.
- **Countdown, portal, arena.** At 0:00 a portal opens in the sky over the Hub. Players walk in. Nobody is stuck
  outside: you can join until the boss is at 50% health.
- **The boss** has health in the billions and three phases:
  1. **Blast** (plain damage).
  2. **Shields:** four glowing plates light up on the floor. One player standing on each breaks the shield. This
     is the team moment. The game says "STAND ON A PLATE!" in big letters with arrows.
  3. **Rage:** the boss fires slow glowing balls. Dodge or you're down for 5 seconds (no death, no respawn walk).
- **Everyone gets loot.** Every player who did any damage gets ore, coins and 1 to 3 Gems. The top 5 get an extra
  roll with better odds. Nobody leaves with nothing.
- **The sky board:** the top 5 by damage, with their blaster and pet, projected over the Hub for 60 seconds. This
  is what sells the shop.
- **Bots when it's quiet.** Below 10 players, friendly robot knights fill the raid: they stand on plates and do
  modest damage. They're tagged "ROBOT", so nobody is fooled. The boss scales to real players only, so a 1-player
  raid is a 1-player boss with 3 robots helping. (Reuses ra2's raider NPC system.)

## 7. Twists with friends (easy to understand)

- **Squad bonus:** friends in the server give +10% damage each, up to +30%. (ra2's team system.)
- **Shield plates need 4 people.** Four friends can break the shield alone and get a "SQUAD BREAK" tag on the board.
- **Squad ore:** when a friend is on your planet, bosses drop double ore for both of you. "Bring a friend = 2x ore."
- **Pass the blaster:** you can lend a blaster to a friend for one raid. They use it, you get half the Gems they earn
  with it. Teaches trading without risk.
- **Boss tag team:** one planet boss (Shadow) can only be stunned when two players hit it at the same second.
  The game counts you down: "3, 2, 1, BLAST!"
- **Squad raids:** friends can open a private 4-player raid once an hour with a smaller boss and the same loot
  table. For when the big raid is 12 minutes away.

## 8. Why players stay

| Roblox signal | Our feature |
|---|---|
| **Play-through rate** (they click) | Plain thumbnails like ra2's: a blocky kid with a glowing blaster facing a giant boss, "RAID A PLANET", or a big "?". The mystery-silhouette style had the best CTR for ra2, so we start there. |
| **First-play bounce** | Blasting within 5 seconds. A tiny tutorial boss at 90 seconds drops a guaranteed Rare blaster with fireworks. The first raid countdown is already running when you land. |
| **Playtime** | A forge timer, a raid countdown and a goal card are always on screen. 2x everything for a new player's first 10 minutes. Playtime gifts. |
| **Play days** (day 2) | The anvil works while you sleep (up to 8 hours of ore and one free roll). Daily quests pay Gems. Daily gift streak. A daily TOP RAIDER board with a prize at 7pm ET, like ra2. |
| **Co-play days** | Squad bonus, squad ore, shield plates, tag-team boss, squad raids. |
| **Spend days / Robux** | Section 9. |

## 9. Making money

Three tiers. Everything random shows its odds. Nothing pays Robux to players.

**Tier 1: convenience (buy once)**

| Pass | Price (Robux) |
|---|---|
| Auto Blast: targets the nearest bug and fires by itself | 249 |
| Triple Forge: three blasters cooking at once | 449 |
| 2x Gems from raids and quests | 299 |
| VIP: +25% damage, gold name, VIP hub lounge | 449 |
| Pet Slot +1 | 199 |

**Tier 2: impatience and flex (buy again and again)**

| Product | Price (Robux) |
|---|---|
| Luck Elixir: 15 min of better rolls, sold hardest in the 2 minutes before a raid | 49 |
| Finish Forge Now: scales down as the timer runs out, from 149 to 9 | 9 to 149 |
| Raid Callout: your name in gold across every screen when the raid starts | 149 |
| Gem packs | 99 to 1,999 |
| Reroll one stat on a blaster (uses Gems) | Gems |
| Daily deal | 25 |

**Tier 3: the player economy**

- **Gems** are the premium currency. Robux buys them; raids and daily quests drop a few. Every Gem sink (rerolls,
  trade tax, pet eggs, name colours) keeps Gem demand up, and Gem demand is Robux demand.
- **Trade Plaza:** a Hub area with 12 stalls. Players list blasters and pets for other items or for Gems. We take a
  10% Gem tax on every Gem trade. Trades go through Roblox-style trade windows inside the game: both players
  confirm, 5-second cool-off, logged to Discord.
- **Booths:** a side street of 16 stands where players show their own clothing and UGC. Other players buy it
  through the game's shop prompt and we get 40%. Merchants stay online for hours, which lifts CCU and fills raids.
- **Booth rank:** a pass (199) that moves your booth to the front of the street. Pure flex, pure margin.

**What we don't do**
- Never send Robux to a player.
- Never trade for anything outside Roblox. The trade window says it, the rules page says it, and the Discord log
  catches chat about "gift cards" or "paypal".
- Never let a player who can't buy random items trade them (PolicyService check).

## 10. Rules we keep

- Odds on every chest, egg and forge, behind an "Odds" button, adding to 100%.
- No rewards for watching anything.
- Prices shown before every purchase.
- Being down in a raid never costs anything.
- Chat filter on every booth sign and trade note.

## 11. Small enough to build

Most of ra2 comes over as-is:

| From ra2 | Used for |
|---|---|
| Services, Loader, Net, Store, Theme, HUD, panels, hotbar | Everything |
| Dragon builder (200 looks) | Blaster looks and pets (recolour and reshape the same box style) |
| Leaderboards, daily board, prize | Raid board, daily TOP RAIDER |
| Daily gifts, playtime gifts, new-player boost, goals, tutorial | As-is |
| Team service | Squad bonus |
| Raider NPCs | Robot knights in quiet raids |
| Discord game log | Trades, booths, raids, errors |
| Combat (bonk) | Blast (hitscan from the blaster, same stun and knockback code for the boss's Rage balls) |
| Offline coins | The sleeping anvil |

New:
- **Bugs and bosses:** one bug model and one boss model, scaled and recoloured per planet. Bugs walk at you
  (same movement code as the raiders). Boss phases are a small state machine.
- **Forge:** a timer per slot, a roll table, an odds page.
- **Trade window:** two-sided confirm, with an inventory list.
- **Booths:** `MarketplaceService:PromptPurchase` on an asset id the player enters, checked with
  `MarketplaceService:GetProductInfo` so only clothing and UGC are allowed.
- **Raid arena:** one instanced area in the same server (30 players, no teleports), reached through the portal.

## 12. Build order

1. **Hub and Dust planet, blast, ore, forge, first boss.** The solo loop, playable end to end.
2. **Goals, forge timer, raid countdown, playtime gifts, tutorial boss.** The always-on task.
3. **The raid:** portal, arena, 3-phase boss, loot, sky board, robot knights.
4. **Planets 2 to 8, rebirth, Nightmare.**
5. **Gems, shop, daily quests.**
6. **Trade Plaza with the tax, then booths.**
7. **Pets and eggs.**
8. **Squad twists, squad raids.**
9. **Audio, thumbnails, icon, Discord log, publish.**

All nine steps are built and green (`tools/run_tests.sh`). It ships to the live place once the experience exists.

## 13. Thumbnails and icon

Plain, like ra2's, showing only what's in the game: blocky kid, blocky blaster, blocky boss. Start from the
mystery-silhouette formula (dark boss, glowing eyes, one energy burst, a big "?"), since it had the best CTR.
Then a set with the title and a set with no text. 16:9, under 0.7 MB.
