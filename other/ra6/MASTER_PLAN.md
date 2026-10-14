# SURVIVE THE 6-7 — Full Game Design & Production Plan

**Roblox co-op survival · PvE · Exploration · Collection · Progression · Friend competition**

The goal is to build a Roblox game that combines the replayability of co-op survival, the satisfying progression
of a collection game, and the comedy of an unforgettable monster. It should be accessible to a young player who has
never played a survival game, but deep enough that friends compete over levels, rare items, difficult achievements,
and who can survive the hardest challenges.

This plan establishes the core experience, systems, visual direction, monetization philosophy, technical
architecture, production sequence, and launch strategy.

## The game's core promise

**Survive the night. Hunt for loot. Fight the monsters. Get stronger. Beat your friends.**

- Six-player co-op as the initial target.
- A real survival challenge with a defined ending.
- An original, hilarious monster roster led by a signature creature.
- Skillful movement and active PvE combat.
- Persistent levels, collections, achievements, and unlocks.
- Beautiful, optimized environments that work on phones.
- Free private servers and light monetization at launch.

## 1. Product vision and positioning

### What the game is

*Survive the 6-7* is the working title for a cooperative, session-based survival adventure. Players enter a
dangerous forest, collect resources, discover equipment, prepare a camp, fight increasingly dangerous creatures, and
attempt to complete a finite run.

Each run tells a story. A team might discover an incredible weapon, barely survive a monster ambush, rescue a
teammate, and reach the final encounter with almost no supplies. Another team might play more carefully, explore
more of the map, and arrive fully prepared.

After a run, players keep permanent progression and return with new goals. They can compare achievements with
friends, pursue rare collections, and eventually tackle harder challenges.

### What makes it different

We should borrow genre conventions, not reproduce another game's complete identity.

| Design pillar | Our approach |
|---|---|
| Survival | A structured run with a clear objective and final encounter |
| Monsters | Funny, expressive creatures with unique combat behaviors |
| Movement | Running, jumping, dodging, traversal, and environmental skill |
| Collection | Tools, weapons, materials, discoveries, creature trophies, cosmetics |
| Progression | Permanent levels, equipment unlocks, mastery, and difficulty tiers |
| Cooperation | Revives, shared base upgrades, complementary roles, clutch rescues |
| Competition | Friend records, rare achievements, fastest clears, highest difficulty |
| Presentation | Bright, polished environments contrasted with strange nighttime danger |

**The central design rule:** collecting items must help players survive, and surviving must unlock new reasons to
collect items. Neither system should feel disconnected from the other.

### Target audience

- Roblox players who enjoy co-op survival, action, collection, and progression.
- Friends who want to play together in private servers.
- Players who enjoy funny enemies and shareable gameplay moments.
- Casual mobile players who need clear objectives and responsive controls.
- Dedicated players who want difficult challenges, rare rewards, and long-term goals.

The game should be easy to start, but not easy to master.

## 2. Title, branding, and discoverability

**Working title: Survive the 6-7**

The name incorporates the current meme direction while clearly presenting a survival challenge. It is not a final
approved title; before launch, we should validate how players interpret it and check Roblox search results and
naming conflicts.

The title alone doesn't explain every mechanic. The icon, thumbnail, and game description need to communicate the
rest immediately.

### Thumbnail concept

Art direction reference: original composition, unmistakable monster silhouette, readable danger, and a clear view of
the camp. Final creative should be custom-made and tested at small mobile thumbnail sizes.

The monster must be visually recognizable at a glance. We should not recreate the composition, logo, creature, or
branding of *99 Nights in the Forest*.

### Store presentation priorities

1. Show the monster pursuing players.
2. Show the survival objective and camp.
3. Show exciting equipment and loot.
4. Show cooperation and a dramatic final encounter.
5. Show progression through different regions.

The title attracts attention; the visual and opening gameplay must then deliver on the promise.

## 3. Core gameplay loop

The game needs two interconnected loops: what players do during a run, and what motivates them to return for
another run.

### The run loop

1. **EXPLORE** — Discover cabins, caves, resources, and loot
2. **COLLECT & CRAFT** — Gather materials, equip tools, improve loadouts
3. **PREPARE THE CAMP** — Build defenses, stock supplies, upgrade shared equipment
4. **SURVIVE THE NIGHT** — Fight monsters, dodge attacks, protect friends
5. **DEFEAT THE FINAL THREAT** — Complete the run and earn rewards
6. **UPGRADE & RETURN** — Gain permanent progression and unlock harder challenges

### The day-and-night rhythm

Day and night should change the way players behave, not merely the lighting.

**Daytime**

- Explore new locations.
- Gather wood, stone, scrap, food, and special materials.
- Search structures for tools, weapons, consumables, and clues.
- Complete optional objectives.
- Return to camp and improve the team's defenses.
- Decide whether to explore further or play safely.

**Nighttime**

- Monster behavior becomes more aggressive.
- The team must respond to different enemy types and attack patterns.
- Players protect the camp, rescue teammates, and manage resources.
- Special events can change the battlefield.
- Survivors receive rewards and a short preparation window before the next stage.

The day phase should be a meaningful opportunity, not an empty waiting period. Players should be able to make risky
choices for better loot.

### Run duration

The first target is a 20–30 minute complete run, with shorter early stages and increasingly demanding later stages.
We should test this duration rather than hard-code it as a final decision.

A rough pacing target:

| Phase | Target elapsed time | Purpose |
|---|---|---|
| Spawn and first objective | 0–2 min | Teach movement and collecting |
| First exploration | 2–5 min | Introduce loot and first threat |
| Early survival | 5–10 min | Teach camp defense and combat |
| Mid-run progression | 10–18 min | Introduce new enemy behaviors |
| Final preparation | 18–23 min | Give players meaningful choices |
| Final encounter and rewards | 23–30 min | Deliver a memorable conclusion |

These are design targets, not a requirement that every run follows an identical clock.

## 4. The first five minutes

Retention starts before deep progression matters. A new player needs to experience the core fantasy almost
immediately.

1. **0:00–0:15 — Enter the world.** Spawn beside a glowing campfire in a beautiful forest. Show the next objective
   prominently. Friends are already visible, and the player can move immediately.
2. **0:15–0:45 — Learn to move and collect.** The player runs, jumps over a fallen log, collects nearby wood, and
   sees it appear in their inventory. No lengthy tutorial or text wall.
3. **0:45–1:30 — Make something useful.** Craft a basic tool or contribute to a camp upgrade. Show a visible change
   in the world so the action feels worthwhile.
4. **1:30–2:30 — Find something exciting.** Open a loot container, discover a useful item, equip it, and learn how
   to switch equipment through the hotbar.
5. **2:30–3:30 — Meet the threat.** The signature monster appears in the distance. Players hear its sound, see its
   unusual animation, and learn that it is dangerous.
6. **3:30–5:00 — Fight, escape, and earn a reward.** The player dodges an attack, helps a teammate, or uses the
   environment to escape. A clear reward and next objective appear afterward.

By minute five, the player should know how to move, collect, equip, fight or escape, and understand what the team
is trying to accomplish.

The opening must work for someone playing alone as well as for someone joining three friends.

## 5. Movement and combat

Movement is a foundational system, not a polish task. If it feels bad, combat feels bad, exploration feels bad, and
the monsters become less frightening.

### Movement specification

- **Running and sprinting.** Responsive acceleration, deceleration, turning, and consistent speed. Sprinting should
  be powerful enough to escape danger without making stamina management tedious.
- **Jumping and traversal.** Predictable jump arcs, forgiving landings, collision-safe obstacles, and carefully
  selected vaults or climbs. Avoid making basic movement fail because a character catches on tiny scenery.
- **Dodge and evade.** A dodge, quick step, or other defensive action should let skilled players avoid clearly
  telegraphed attacks. Cooldowns and recovery prevent unlimited escape.
- **Combat responsiveness.** Fast input response, clear hit feedback, readable hitboxes, weapon switching, attack
  recovery, and consistent knockback. Avoid animations that lock the player in place for too long.

### Non-negotiable movement tests

- Movement feels responsive on mobile and PC.
- The camera does not clip through trees or walls.
- Jumping behaves consistently on slopes and uneven ground.
- Sprinting, dodging, and combat cannot be exploited to bypass all danger.
- Players can understand why an attack hit them.
- Network latency doesn't make dodges and attacks feel random.
- Movement remains smooth when several enemies and players are active.

We should tune this with repeated playtests, not rely only on values chosen in code.

### Combat design

Each weapon needs a role and trade-off.

| Weapon type | Strength | Limitation |
|---|---|---|
| Axe | Resource gathering and close combat | Short range |
| Club or hammer | Staggering certain enemies | Slower attacks |
| Spear | Safer reach | Timing and positioning matter |
| Bow | Ranged damage | Ammunition and aiming |
| Traps | Area control and defense | Requires setup |
| Support tools | Healing, rescue, utility | Limited direct damage |

Weapon rarity should not automatically make every older weapon worthless. Distinct effects, enemy matchups, and
different playstyles keep more items useful.

### Enemy behavior framework

Every enemy needs:

1. A readable silhouette and identity.
2. A detection system that makes sense to players.
3. At least one distinctive behavior.
4. An attack that can be anticipated and countered.
5. A reward or tactical reason to engage with it.
6. A sound and animation language that players recognize.

**Kermy should be a real threat, not just a mascot in the background.**

His personality can create funny moments, but the game must still respect player skill. He can fake a retreat, get
briefly distracted, take an awkward shortcut, or make a ridiculous noise before lunging. Those behaviors must be
readable and consistent enough that players can learn them.

## 6. Inventory, hotbar, and item collection

The hotbar and inventory are core features. We should design both before building large quantities of loot.

### Hotbar

Start with six slots, subject to mobile usability tests.

- Slot 1: primary tool or weapon.
- Slot 2: secondary weapon or tool.
- Slot 3: light source or utility.
- Slot 4: healing item.
- Slot 5: consumable or trap.
- Slot 6: flexible slot.

Players can change assignments. The slots are not hard-coded to specific item types.

On PC, players should be able to select slots through number keys and mouse input. On mobile, large touch targets
must make item switching reliable without blocking the view.

### Inventory GUI

The inventory should include:

- Item grid with clear icons and rarity borders.
- Stack counts for stackable materials.
- Item name, description, and stats.
- Equip, use, drop, and move actions where appropriate.
- Sorting and filtering once the collection becomes large.
- A clear explanation of what is carried versus what is permanently unlocked.
- Controller navigation support.

We should not overwhelm new players with dozens of item categories immediately. Introduce complexity as the game
grows.

### Item categories

| Category | Examples | Purpose |
|---|---|---|
| Resources | Wood, stone, scrap, fibers | Crafting and camp upgrades |
| Tools | Axes, pickaxes, repair tools | Exploration and gathering |
| Weapons | Melee, ranged, traps | Combat |
| Consumables | Food, medicine, temporary boosts | Survival |
| Equipment | Armor, backpacks, accessories | Build choices |
| Discoveries | Maps, keys, clues, artifacts | Exploration and progression |
| Trophies | Monster parts, statues, badges | Collection and achievement |
| Cosmetics | Outfits, emotes, visual effects | Personal expression |

### Item rarity

Use a small, readable rarity ladder: **Common, Uncommon, Rare, Epic, and Legendary.**

Rarity should affect excitement, not make every drop a mandatory grind. Rare items can be found in specific
locations, earned from challenging encounters, or discovered through exploration. The most important progression
milestones should remain achievable without paying.

### Inventory rules

We need to decide early how inventory works during a run:

- Which items are lost on defeat?
- Which resources can be deposited at camp?
- Can players trade items during a run?
- Can players drop equipment for teammates?
- How much can each player carry?
- What happens if a player disconnects while holding rare loot?

My starting recommendation is to make run-specific resources and most temporary equipment subject to the run's
outcome, while permanent unlocks, earned account XP, and completed collection discoveries persist. Rare permanent
discoveries should not disappear due to an ordinary defeat.

These rules need to be communicated before players risk valuable items.

## 7. Camp building and shared progression

The camp is the team's home base, visual reward, and strategic center. It should evolve visibly as the team
survives.

### Camp upgrade tree

| Tier | Name | Contents |
|---|---|---|
| 1 | The Campsite | Campfire, basic storage, crafting station |
| 2 | The Outpost | Walls, basic traps, repair station, watch platform |
| 3 | The Fort | Reinforced defenses, advanced crafting, team utility upgrades |
| 4 | The Stronghold | Advanced defensive options and late-run preparation |

Each tier should require team contributions, resource choices, and time. Players need to feel that upgrades make the
camp safer or more capable, not merely larger.

### Individual contribution

The game should recognize players who help the team:

- Resources gathered.
- Repairs completed.
- Defenses built.
- Teammates revived.
- Monsters defeated.
- Objectives completed.

Contribution rewards should recognize different playstyles. A player who supports the team should not feel inferior
to the person with the most kills.

### Shared versus individual ownership

The camp belongs to the current run, while players maintain their own permanent progression. Private servers should
use the same rules as public servers, with the same rewards and difficulty standards.

Cosmetic camp personalization can eventually give players a reason to invest in their own identity without making
shared progression unfair.

## 8. Server size, matchmaking, and run fairness

The initial target is six players per server. We should test four, six, and eight players before locking in the
final size.

Six offers a promising balance between teamwork and readability, but the actual answer depends on how crowded combat
becomes, how much loot is available, and how the game performs on phones.

### Run structure

Each run has a fixed starting roster and a clear conclusion. Players should not be able to enter the final encounter
late and receive an easy win without earning it.

Recommended rules:

- Friends can join a party before a run begins.
- The roster locks at the start of the run.
- Players who leave can be replaced in the next run, not halfway through a late-stage encounter.
- Disconnects should not automatically invalidate the team's progress.
- Difficulty should adjust for the actual number of active players, within tested limits.
- Solo players should have a viable route through the game.
- Players retain the permanent rewards they have earned under the run's save rules.

A fixed roster is fairer and easier to balance than allowing unrestricted late joining.

### Handling departures

A six-player run may become a five-player run when someone disconnects. The system should avoid abruptly spawning a
full six-player enemy load.

Instead, difficulty can account for active players at controlled stage boundaries, while already-started encounters
remain predictable. Players should have a fair chance to finish the current encounter.

### Private servers

Private servers should be free if Roblox's available configuration and operating costs allow it. They are a social
growth feature, not our primary revenue stream.

The message should be simple: **Play with your friends. Survive together.**

Private servers should support the full game, not a restricted mode with inferior rewards. We'll verify the
available Roblox private-server settings and costs during implementation.

## 9. Long-term progression and friend competition

Completing one run should feel satisfying, but the player should have another goal afterward.

I would use four permanent progression tracks.

- **Player level.** Earn XP from completed objectives, survival milestones, discoveries, and successful runs. Levels
  unlock additional options, not just larger damage numbers.
- **Equipment mastery.** Use weapon types to unlock alternate moves, cosmetic variants, and mastery rewards. Keep
  the power curve controlled so new players can still participate.
- **Bestiary and discoveries.** Record creatures encountered, attack patterns learned, rare variants found, and
  trophies collected. Players can pursue completion without requiring purchases.
- **Achievements and difficulty.** Reward difficult clears, speed records, low-damage runs, solo victories, and team
  challenges with titles and visible trophies.

### The friend leaderboard

Compete across multiple categories rather than one endless XP race.

| Category | What it measures |
|---|---|
| Highest difficulty cleared | Challenge mastery |
| Fastest successful run | Efficiency and skill |
| Most nights or stages survived | Survival achievement |
| Rarest discoveries | Exploration and collection |
| Most monsters defeated | Combat contribution |
| Most teammates rescued | Cooperation |
| Most weapon mastery | Specialization |
| Most achievements earned | Overall completion |

Leaderboards should show a player's friends first, then broader rankings. This makes competition personal and
achievable.

We should avoid rewards that make new players permanently weaker than veterans. High levels should offer new
choices, not make every encounter trivial.

## 10. Biomes, enemy roster, and bosses

The first release should focus on one excellent biome and a manageable enemy roster. Additional regions become
expansion content.

1. **Pinewood Forest** — Starting region. Teaches collecting, crafting, basic enemies, and camp defense.
2. **Crooked Swamp** — Mud, poisonous plants, hidden paths, and creatures that ambush from the water.
3. **Frostwood** — Slippery surfaces, limited visibility, and enemies that force players to manage warmth and
   movement.
4. **Hollow Village** — Abandoned structures, traps, unusual loot, and more complex enemy encounters.

### The monster roster

Kermy is the signature creature, but the world needs enough enemy variety that every encounter doesn't feel
identical.

| Enemy role | Gameplay purpose |
|---|---|
| Kermy | Signature pursuer with memorable chase behavior |
| Small nuisance | Teaches dodging and threat recognition |
| Pack hunter | Surrounds distracted players |
| Ranged pest | Forces players to move and use cover |
| Heavy brute | Rewards positioning and coordinated attacks |
| Trickster | Creates unusual, funny situations |
| Elite variant | Adds a higher-risk optional encounter |
| Boss | Tests several skills at once |

Every monster needs an explicit behavior specification, animation list, sound list, difficulty target, reward
table, and mobile-performance budget.

### Boss design

Bosses should introduce new mechanics, not just a larger health bar.

A boss might require players to bait a charge into a tree, destroy exposed weak points, rescue a trapped teammate,
or coordinate attacks during short vulnerability windows.

The final boss should be a culmination of the run's learned skills. Players need to understand what they did well
and what they need to improve when they fail.

## 11. Graphics and art direction

Our visual target is high-quality stylized 3D, optimized for mobile. We should not try to maximize polygon count or
realism. We want environments that look rich, readable, and memorable without overloading phones.

### Environment standards

- Trees need attractive silhouettes, varied foliage, and believable bark.
- The forest floor should use rocks, ferns, logs, mushrooms, and carefully placed ground detail.
- The camp should be a visual focal point with warm light and recognizable structures.
- Cabins and landmarks should be identifiable from a distance.
- Loot must stand out from background clutter.
- Important paths and objectives should remain readable at night.
- Each biome needs a distinct color palette and visual identity.

### Lighting and atmosphere

Use warm campfire lighting against cool moonlight, selective fog, shadows, and restrained particle effects. Darkness
should create tension without making the game hard to see.

Avoid relying on expensive effects everywhere. Use lighting, composition, and color contrast to achieve the
atmosphere.

### Mobile-first performance

Performance is part of the art direction.

- Use reusable environment assets and controlled material counts.
- Use level-of-detail strategies where appropriate.
- Limit transparent foliage and expensive particle effects.
- Reduce distant detail and effects on lower graphics settings.
- Pool frequently spawned objects where it helps.
- Use spatially appropriate sound and effects.
- Profile memory, frame rate, and server load throughout development.

Set explicit performance budgets for trees, enemies, effects, textures, and visible objects once the first
environment is running on representative devices.

### Animation quality

Animation should be a signature feature, especially for Kermy.

The monster needs anticipation, exaggerated movement, clean transitions, and readable recovery states. Players
should be able to recognize an attack before it lands.

The same applies to the player character: running, jumping, landing, attacking, dodging, healing, reviving, and
interacting should all feel intentional.

## 12. UI, controls, and accessibility

The UI must work on phone first without looking oversized on PC.

### Essential HUD

- **Health and survival status.** Clearly show health, important status effects, and any sprint stamina needed for
  the current design.
- **Current objective.** One primary objective at a time, with optional objectives separated visually. Players
  should never need to guess where to go.
- **Team status.** Show teammates' health and downed state, along with clear rescue indicators. Avoid filling the
  screen with unnecessary team statistics.
- **Hotbar and interaction prompts.** Keep item selection accessible during combat. Use contextual prompts for
  looting, crafting, reviving, and interacting.

### Input parity

- **Mobile:** virtual movement controls, jump, sprint, attack, dodge, interaction, and hotbar.
- **PC:** keyboard and mouse, direct item selection, responsive camera control.
- **Controller:** consistent navigation, aiming support, and button remapping where feasible.

Avoid putting essential information only in audio or color. Use icons, text, and animation to communicate important
threats and objectives.

## 13. Monetization strategy

The launch strategy is deliberately conservative. First, we prove that the game is fun and players return. Then we
expand monetization based on real player behavior.

### Launch

- Free-to-play experience.
- Free private servers, subject to Roblox's actual configuration and cost constraints.
- No paywall around the main survival loop.
- No required purchases to beat the final boss.
- Minimal store presence until retention is validated.

### After retention is established

- **Cosmetics.** Character outfits, hats, emotes, victory poses, and visual effects. Players pay to express
  themselves and show off to friends.
- **Camp customization.** Decorative structures, themed camp styles, and cosmetic collectibles. Keep competitive
  camp upgrades earnable through play.
- **Monster-themed bundles.** Kermy outfits, funny emotes, lobby poses, and collectible visual variants. The mascot
  gives us a recognizable identity.
- **Season pass.** A free reward track and optional premium track with cosmetics and achievements. Introduce this
  only when updates can support it consistently.

The game should never become frustrating on purpose to sell a solution. We should not sell mandatory power, make
survival artificially miserable, or flood players with purchase prompts.

### Monetization measurement

Track:

- Percentage of players who purchase.
- Revenue per daily active player.
- Average spending per paying player.
- Repeat purchase rate.
- Retention of paying and non-paying players.
- Refunds and purchase-related complaints.
- Whether purchases disrupt gameplay or create unfair matches.

We should decide on specific prices only after seeing how players interact with the game and what they value.

## 14. Technical architecture

The game should be built around reliable server-authoritative gameplay, modular systems, and clear separation
between the active run and permanent account progression.

### Core systems

| System | Responsibility |
|---|---|
| Run manager | Run lifecycle, stages, victory, defeat, and cleanup |
| Party and matchmaking | Group formation and server assignment |
| Player controller | Movement, input, animation, and interactions |
| Combat service | Attacks, hit validation, damage, and status effects |
| Enemy AI | Detection, navigation, attacks, and state transitions |
| Inventory service | Item ownership, stacking, equipment, and validation |
| Loot service | Spawn rules, rarity, rewards, and collection |
| Crafting service | Recipes, resource costs, and camp upgrades |
| Progression service | XP, levels, achievements, and permanent unlocks |
| Persistence service | Account data, safe saves, migrations, and recovery |
| UI layer | HUD, inventory, menus, and accessibility |
| Analytics layer | Retention, session behavior, difficulty, and purchases |

### Multiplayer authority

The server should validate important gameplay decisions: damage, inventory changes, crafting costs, loot rewards,
enemy state, and progression. The client handles responsive presentation and input, but should not be trusted to
award itself valuable items or declare a boss defeated.

This is especially important for a survival game with rare equipment and competitive achievements.

### Data persistence

Separate temporary run state from permanent player data.

- **Run data:** current health, temporary inventory, camp state, enemy states, current stage, and participating
  players.
- **Permanent data:** XP, levels, discovered items, achievements, unlocked equipment, cosmetic ownership, and
  settings.

Save at meaningful checkpoints and after important permanent rewards. Handle server shutdowns, failed saves, and
disconnects explicitly.

### Performance and exploit prevention

- Keep enemy AI efficient and avoid unnecessary pathfinding updates.
- Reuse assets and effects where practical.
- Validate all inventory and currency transactions.
- Add cooldown and range checks for combat and interactions.
- Rate-limit remote events.
- Test simultaneous loot claims and disconnect scenarios.
- Profile the full server with six active players and multiple enemies.

The goal is reliable gameplay before large-scale content production.

## 15. Development roadmap

The project should be developed in milestones. Each milestone must prove something before the team invests in more
content.

| Phase | Name | Goal | Exit condition |
|---|---|---|---|
| 1 | Prototype | **Movement and one enemy.** Build running, jumping, camera, collisions, one weapon, one funny monster, and a small test forest. | Movement feels good, and the enemy encounter is fun without needing progression systems. |
| 2 | Vertical slice | **One complete survival run.** Add gathering, crafting, a functional hotbar, inventory, camp upgrades, day/night transitions, a boss, victory and defeat. | A new player can complete the core experience and understand the next goal. |
| 3 | Multiplayer | **Six-player co-op and persistence.** Implement parties, private servers, revives, fixed run rosters, disconnect handling, server-authoritative combat, and permanent progression. | Multiplayer runs remain fair and reliable when players leave or lose connection. |
| 4 | Polish | **Mobile optimization and onboarding.** Improve animation, environment quality, audio, objective clarity, loading, and UI. Test on lower-end phones and controllers. | First-session players can learn the game without external instructions, and performance meets agreed targets. |
| 5 | Closed test | **Retention and balance testing.** Run small playtests, identify where players quit, measure completion rates, tune enemy difficulty, and improve the reward loop. | Players voluntarily replay, invite friends, and demonstrate improving retention. |
| 6 | Launch | **Public release and expansion.** Launch with the first biome, a complete run, a polished enemy roster, permanent progression, friend leaderboards, and a reliable save system. | Stable performance, healthy player feedback, and a measured plan for new content. |

## 16. Retention and success metrics

We should measure success by player behavior, not just concurrent users or total visits.

| Metric | What it tells us |
|---|---|
| First-minute engagement | Whether the game hooks new players |
| First-five-minute completion | Whether the opening is understandable and exciting |
| First-run completion rate | Whether the core experience is too difficult or too long |
| Day 1 retention | Whether players return the next day |
| Day 7 retention | Whether the game creates lasting interest |
| Average session length | Whether players stay engaged |
| Runs per session | Whether the core loop encourages another attempt |
| Party size and friend invites | Whether social play helps growth |
| Disconnect and crash rates | Whether technical issues damage retention |
| Revenue per active player | Whether monetization works without harming engagement |

We should establish baseline targets after the first closed test, then improve them through controlled changes.
Don't assume that adding more enemies, items, or purchases automatically improves retention.

### What to fix first when metrics are weak

- **Players leave in the first minute:** improve the spawn experience and objective clarity.
- **Players leave before the first night:** make exploration and early rewards more compelling.
- **Players die repeatedly without understanding why:** improve enemy tells, movement, and combat feedback.
- **Players finish once but don't replay:** deepen progression, vary encounters, and improve post-run rewards.
- **Players return but don't invite friends:** make co-op interactions and shared achievements more memorable.
- **Players enjoy the game but don't purchase:** improve cosmetic desirability and presentation rather than adding
  friction to the free experience.

## 17. Launch scope: what is in and what is out

The biggest risk is trying to build too much before the core game has been validated.

| Feature | Scope |
|---|---|
| Responsive running, jumping, and combat | Required |
| One polished forest biome | Required |
| Six-player target with solo viability | Required |
| Functional hotbar and inventory | Required |
| Gathering, crafting, and camp upgrades | Required |
| Signature monster plus supporting enemies | Required |
| Complete run with final boss | Required |
| Permanent progression and saves | Required |
| Friend leaderboards and achievements | Required |
| Free private servers | Target |
| Multiple biomes at launch | Later |
| Large paid shop and season pass | Later |
| Trading and complex player economy | Later |
| Dozens of weapons and enemy types | Later |

## 18. Final product principles

These are the rules that should guide decisions throughout development:

1. **Fun before monetization.** The core game must be enjoyable without purchases.
2. **Movement before content volume.** A small, responsive game beats a huge, clumsy one.
3. **The monster must be memorable and dangerous.** Comedy should reinforce the gameplay, not replace it.
4. **Collection must matter.** Items should create choices, discoveries, and goals.
5. **Every run needs a conclusion.** Players should know what victory means and why they failed.
6. **Permanent progression should reward commitment.** A defeat should not erase everything a player worked for.
7. **Co-op should create stories.** Revives, rescues, shared upgrades, and close victories are essential.
8. **Mobile is a first-class platform.** Performance and controls must be designed in from the beginning.
9. **Friends should have meaningful goals to compare.** Mastery, discoveries, and achievements should all count.
10. **Build only what we can validate.** Add complexity when player data and playtests demonstrate a need.

The immediate next milestone is a playable prototype: one forest clearing, responsive movement, a functional pickup
system, a hotbar, one weapon, and Kermy's first chase encounter. That prototype will tell us more about the game's
potential than building ten biomes before we know whether the first five minutes are genuinely fun.

---

*Map direction from the team (with the request to begin ra6): the map should mostly just be forest, besides the
camp and random findings.*
