# ra9 · Turf Wars: Overdrive — master plan

The design brief (October 2026), kept here as the reference every phase is checked against, with the art direction
and the decisions made where the brief stops (it ends partway through §7, Construction).

## 0. Art direction (the brief's map notes, which override the biome art in §4)

The maps look like **SUPERHOT**: a plain white world, matte and geometric, with no textures to speak of, but
**detailed**: arches, columns, steps, railings, pillars, plinths, window frames and ledges, so every place reads as
a real place made of clean shapes. Light grey shadows, soft ambient light, a white sky.

* **Colour is information.** The only strong colours are the teams: **red** and **blue**. The turf on the ground,
  the players, their arrows, their structures and their banners. Everything else is white, off-white or light grey.
* **The maps must feel very different from each other** while staying plain: a different architecture, shape and
  scale on each (a courtyard of arches, a glacier of shards, overgrown terraces, a canyon of slabs), each with its own
  tint of grey or off-white and its own light, never its own texture.
* Reference: the brief's two images: a SUPERHOT courtyard (white arches and columns, a red figure, a red tracer
  line) and Mineplex Turf Wars (red and blue turf, a bow in first person, a frontline across the floor).

The biome names of §4 stay (Castle Clash, Frostbite, Jungle Rush, Dust Devil) as the four layouts, in that style.

## 1. Vision

A fast first-person team-warfare game, after Mineplex Turf Wars. Two teams push each other's territory back until
one runs out of turf. Build (prepare defences together) and Fight (bows and movement) alternate; every valid kill
pushes the frontline toward the enemy's base. Up to 40 players a server, friends kept together, maps rotating, a
reward for every qualifying win.

Player fantasy: *"I joined a huge battle, helped my team build a defence, pulled off an incredible shot, pushed the
enemy's frontline, unlocked something cool, and jumped straight into another match with my friends."*

Pillars: instant action (no lobby, no tutorial room) · massive teamwork · exceptional combat feel · visible
progression (a reward per qualifying win, a 100-win ladder) · status and identity (cosmetics, streaks, stats) ·
constant variety (maps, rotation) · **fair competition: nothing paid adds combat power**.

Audience: 13–24 (attention to 16+); accessible to younger players.

| Target | Value |
|---|---:|
| Server | 40 (20 a team) |
| Understand the objective | < 15 s |
| First meaningful action | < 10 s |
| First fight | < 90 s after joining |
| Build phase | 60 s |
| Fight phase | 120 s |
| Maps at launch | 4 polished |
| Weapons at launch | 3 |
| First unlock | the first qualifying win |
| Reward ladder | 100 wins |

## 2. Loop

**Join → Build → Fight → push the frontline → Rebuild → Fight → eliminate the enemy → reward → next map.**

* **A. Assignment:** straight into the running match; parties together, solo players balance round them. Joining
  mid-fight: a protected spawn on your side, told the phase, in at the next safe moment.
* **B. Build (60 s):** snap-to-grid modular structures (low barricade, wall, reinforced wall, short tower, bridge,
  cover, team banner) with a preview, a valid/invalid colour and a cost; a personal budget and a team cap; budgets
  refill each build phase; structures persist until destroyed or the match ends.
* **C. Fight (120 s):** a horn; building off; bows, sprint, jump, slide. Each qualifying kill moves the frontline.
  Feedback per kill: the hit, the frontline moving, your contribution. Ends at once if a team has no turf left.
* **D. Rebuild (60 s):** the frontline stays where it is.
* **E. Repeat** until a team is eliminated. No timer decides a winner; a watchdog only recovers a broken match.
* **F. Victory:** freeze, victory/defeat, final frontline, stats, the win's reward, streaks; the next map loads in
  the same server, ~8–12 s, no lobby.

## 3. Territory

Two bases joined by a battlefield split into red and blue turf. A **server-authoritative frontline value** along the
battlefield's length; each valid kill moves it a fixed distance (scaled to the map, tuned in play) toward the
victim's base. Valid kill: opposing teams, victim alive and eligible, not a duplicate, during combat. No movement
for self-kills, environment deaths or invalid events. A player standing on enemy turf during the fight is pushed
back to their own side (Turf Wars' rule: you fight across the line, you can't walk over it).

Stalemates: limited budgets, structure durability, destructible pieces, open lanes, no piece seals every route,
several approaches per map, long matches logged for balance. **No hidden comeback multipliers.**

## 4. Maps

Four polished layouts on one reusable arena system (`World/ArenaBuilder` + a data file per map), each a different
architecture and tactical feel:

| Map | Architecture (SUPERHOT white) | Play |
|---|---|---|
| Castle Clash | a courtyard of arches, columns, battlements and gate towers; off-white stone blocks | balanced lanes, moderate cover; teaches the game |
| Frostbite | a glacier: faceted shards, pale blue-white ice walls, terraces of slabs | protected routes, high firing ledges |
| Jungle Rush | stepped ruins, square pillars, overgrown blocks (geometric "leaves"), archways | more cover, narrow routes, flanks |
| Dust Devil | a canyon of tall slabs and mesas, bridges, long open floor; warm off-white | long sightlines, few but key covers |

Rotation: never the same map twice in a row; the next map is named during the results; the arena is fully reset.
Boundaries: solid walls all round, a ceiling, a kill plane below, server-checked spawns and placements.

## 5. Combat

Three bows, all free: **Standard Bow** (versatile; travel time, drop, variable draw), **Rapid Crossbow** (fast,
lower damage, a magazine and reload), **Heavy Bow** (slow draw, high impact and knockback). Later weapons are
sidegrades or cosmetics, never strictly stronger. Projectiles, damage, kills and credit are validated on the
server; clients may draw predicted arrows. Hit feedback: a sound, a hit marker, a target flinch, an elimination
indicator. No blood. Knockback: predictable, capped.

## 6. Movement

Sprint, jump, a **front flip every 4th eligible jump** (cosmetic, can be turned off), a short **slide** on a
cooldown. Later: wall jumps, air dashes, trick chains, trails. First-person camera: stable aim, adjustable
sensitivity, controller and touch aim, little shake, no third-person peeking.

## 7. Construction (the brief, then the decisions)

Placement: pick a structure → transparent preview → snaps to valid spots → server checks position, team side, phase,
cost and limits → it appears for everyone → the budget updates. Each structure: cost, durability, reach, footprint,
surface rules, team, lifetime. No full-width unbreakable walls, attack routes always open, nothing on spawns, tower
height capped, nothing outside the arena, invalid spots explained. Mobile: a large-button tray, one tap to place.

**Decisions (where the brief stops):**

* Grid: 4-stud cells; structures go only on **your own turf** (the frontline is the limit), never within the spawn
  zones, never on the map's solid geometry.
* Budget: 100 points a player each build phase; a team cap of 60 standing structures (raised with team size).
* A wall can't be placed if it would close the last open cell across a lane (the server checks a free path across
  the battlefield's width at that row).
* Structures take arrow damage (heavy bow more); destroyed pieces leave nothing.

## 8. Progression, rewards and fairness (decisions)

* A **qualifying win**: on the winning team, present for at least 2 minutes of the match and at least one build or
  fight phase, not idle. Each one advances the **100-win ladder** (arrow trails, bow skins, kill effects, banners,
  titles; every 10th is a big one), with streak badges for 3/5/10 in a row.
* Stats: wins, kills, deaths, assists, accuracy, structures built, frontline pushed, MVPs.
* MVP of a match: most frontline pushed (kills) plus a share for assists and building.
* After a win: fireworks in the winners' colour, a 30-second countdown to the next game, and the winners are asked
  "Are you liking the game?" (once a day); a YES means their next win asks for a like. Answering (YES or NO) gives
  the Thank-You Trail once; asking for a like gives nothing (no rewards for likes or favourites).
* Monetization later, cosmetic only (bow skins, trails, kill effects, VIP tag and chat colour). No combat power.

## 9. Production

Phases, each tested on the mock engine (`tools/run_tests.sh`):

* **A** scaffold, this plan, the engine skeleton, the test harness.
* **B** the match loop: teams and parties, build/fight phases, the frontline, kills, victory, rotation.
* **C** the four maps (ArenaBuilder + layouts), boundaries and spawns.
* **D** the bows (server projectiles, hits, knockback), the building system (grid, budget, durability).
* **E** the client: first person, the bow (draw, charge, predicted arrows), the build tray and preview, the HUD
  (phase, timer, frontline bar, budget, kill feed, hit markers), sprint/slide/flip, touch controls.
* **F** saves, the reward ladder, stats, the Discord log and analytics, renders, the icon and thumbnails, the
  dashboard entry, docs, publish.
