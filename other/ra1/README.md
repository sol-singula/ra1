# Mystery Morph Restaurant: playable base (Roblox)

The first playable slice of the game described in [`MYSTERY_MORPH_RESTAURANT_GDD.md`](MYSTERY_MORPH_RESTAURANT_GDD.md),
built as a [Rojo](https://rojo.space) project. You run a greybox restaurant on Restaurant Row: take orders,
cook them at real stations, serve customers, deal with the angry ones, earn Morph Bucks, level up and upgrade.
Every model is primitive parts, so it runs in a blank Baseplate with no uploaded assets.

The game itself lives in [`games/ra1 - Mystery Morph Restaurant/`](<../../games/ra1 - Mystery Morph Restaurant>). This folder only holds docs: this README, the screenshots and the GDD. Every command and path below is relative to the game folder.

## Screenshots

[`screenshots/`](screenshots/README.md) has 20 frames from a real play session. The game's own server and client
scripts ran on the mock engine while a bot cooked, served, fought and upgraded through the real prompts and UI.
The game folder's `tools/gameplay/` has the session script and the three.js renderer that drew them. The renderer and the avatar
are stand-ins for Roblox's.

## Run it in Roblox Studio

1. Install the tools. With [Rokit](https://github.com/rojo-rbx/rokit): open a terminal in the game folder
   (`games/ra1 - Mystery Morph Restaurant/`) and
   run `rokit install` (it reads `rokit.toml`). Aftman or Foreman work too, or install Rojo 7 directly.
2. Install the Rojo plugin for Studio: run `rojo plugin install`, or get "Rojo" from the Creator Store.
3. In Studio, create a new **Baseplate** place.
4. In the game folder, run `rojo serve`.
5. In Studio, open the Rojo plugin and click **Connect**. The scripts appear under ReplicatedStorage,
   ServerScriptService and StarterPlayer and stay synced while you edit files.
6. Press **Play**.

To get a single file instead: `rojo build -o MysteryMorph.rbxl`, then double-click the file to open it in Studio.
A prebuilt copy, `MysteryMorphRestaurant.rbxl`, is already in the game folder.

**Better lighting.** The game adds atmosphere, bloom, sun rays and colour correction on its own. For the best
look, also select **Lighting** in the Explorer and set **Technology** to **Future**. Scripts can't change that
property.

**Saving progress.** Profiles save to a DataStore. In an unpublished place, or with API access off, the game still
runs but shows "Studio: turn on API access…" and progress resets when you stop. To save: publish the place, then
in **Game Settings → Security** turn on **Enable Studio Access to API Services**.

## How to play

| Action | Keyboard / mouse | Gamepad | Touch |
|---|---|---|---|
| Use a station, take an order, serve | **E** at the prompt | X | tap the prompt |
| Clear an assembly board | **F** (hold) | Y | tap the prompt |
| Repair furniture | **R** (hold) | Y | tap the prompt |
| Chop / stop pouring | **Space** or the on-screen button | A | on-screen button |
| Attack (Swipe Combo) | click | R2 | 👊 button |
| Calm Down! | **Q** | L1 | 💗 button |
| Mutation ability | **G** | R1 | mutation button |

**The first time you play, a 13-step tutorial walks you through everything.** A card on the left says what to do,
and a bouncing **HERE** arrow with a glow marks the station or customer to use next. Your first customer is a
patient, scripted Grandma Golem who orders a plain Basic Burger. Finish the tutorial for a 25 MB bonus, or press
**Skip tutorial**. Players who have already served a customer never see it.

1. On your first join, pick a free mutation: **Octopus Arm** (carry 2 items, cook faster), **Crab Claw Arm**
   (hits harder) or **Wrench Claw Arm** (repairs faster).
2. A customer walks up to the counter. Press **E** on them to take the order, then they sit down. Their order is
   on the ticket rail at the top of the screen and in their speech bubble, including requests like
   "Hold the pickles". The **menu board** on the wall shows what's on today's menu.
3. Read the **recipe card** (top right). For the oldest order you still owe, it lists every part of the dish and
   where it comes from: 📦 Pantry, 🔥 Grill, 🍟 Fryer or 🔪 Cutting Board. Parts already on a board get a ✅, and
   anything the customer asked you to leave out gets a 🚫.
4. Cook it. Take ingredients from the **Pantry**. Chop vegetables at the **Cutting Board** by tapping when the
   marker is in the green. Put patties on the **Grill** and potatoes in the **Fryer**, and take them off while the
   bar is green (Perfect). Burn something for too long and the station catches fire; hold E to put it out.
5. Stack everything on an **Assembly Counter** board. When the stack matches a menu dish, the prompt says
   "Plate …". Press E to pick up the plated dish. Pour drinks at the **Drink Dispenser** and stop in the top band.
6. Walk the dish to the customer and press **E**. They pay, tip by satisfaction and leave a little reputation.
   The hint line above your hands always says what to do next.
7. Customers who wait too long get angry: they throw food (move to dodge), smash tables, and the worst start a
   fight. Calm them with **Q**, or bop them until they're dizzy and pay an apology. A knock-out never costs you
   anything. Broken tables and stools need repairs before anyone can sit there. **Beginner protection:** until
   you reach level 2, a customer who would start throwing things storms out instead.
8. Spend stat points in **Stats**, change dishes in **Menu**, and at level 5 with 1,000 MB use **Upgrade** to turn
   the Broken Burger Shack into the Tiny Mutation Diner (6 seats, 5 menu slots, new customer types).

## What's in this base

| Area | In the build |
|---|---|
| Restaurant | TIER_01 Broken Burger Shack and TIER_02 Tiny Mutation Diner, greybox, one plot per player (8 per server) |
| Stations | Pantry, Cutting Board, Grill (2 slots), Fryer, Drink Dispenser, Assembly Counter (2 boards), Trash |
| Cooking | Heat timing with Perfect window, burning and fires (§C8), chopping rhythm, pour meter, quality grades |
| Recipes | The 12 MVP recipes from §34.4, the 4 level-1 recipes on the starting menu, unlocks by level |
| Orders | Main + optional side/drink, 6 "leave it out" modifications from §6.18 |
| Customers | The 8 MVP personalities with their §9 patience, tips, anger odds and combat style; procedural greybox bodies |
| Satisfaction & pay | Exact §C11.3 satisfaction, §C11.4 pay, tips, Jackpot Tip, reputation stars, demand per hour |
| Anger | Levels 0–5 with escalation rolls, thrown food, furniture smashing, fights, storm-outs, Calm Down! |
| Combat | Swipe Combo, Calm Down!, Octo-Flurry, Claw Grab & Toss, Repair Burst; HP, KO and respawn with nothing lost |
| Progression | XP curve (§C5.1) to level 10, 2 stat points per level, all 9 stats with their effects |
| Mutations | The tutorial pick of 3 arm parts with stats, passives and abilities |
| Repairs | Five damage states, unusable broken seats, hold-to-repair for MB |
| Saving | Session-locked DataStore profiles, autosave every 120 s, save on leave and shutdown |

**Not in yet** (designed in the GDD, next on the list): employees and offline earnings, the city and its NPCs,
quests and the tutorial script, the mutation shop and the other 277 parts, decor and build mode, co-op visits,
events, monetization, sound and animation. Level 6 "restaurant-wide chaos" is also left out.

**Simplifications** you will notice, all deliberate for the base:

- The restaurant is built on the player's plot instead of an instanced interior far away (§27.4.4).
- One pantry grab is one portion: French Fries use 1 potato (canon 3), Onion Rings fold the batter in,
  Grilled Cheese is 2 grilled slices + 1 cheese, and drinks skip their chop/mix steps.
- Customers walk fixed waypoints instead of pathfinding, and a chasing customer can clip through counters.
- An ignored customer at maximum anger storms out after 30 s, and HP slowly regenerates out of combat.
- Atmosphere is a fixed per-tier value until decor exists.

## Code layout

```text
games/ra1 - Mystery Morph Restaurant/
├─ default.project.json        Rojo project (src/shared → ReplicatedStorage.Shared, src/server → ServerScriptService.Server,
│                              src/client → StarterPlayerScripts.Client)
├─ src/shared/                 code both sides use
│  ├─ Constants.lua            every tunable number, with its GDD section
│  ├─ Formulas.lua             pure canon formulas (satisfaction, pay, XP, heat timing, recipe matching…)
│  ├─ Data/                    recipes, ingredients, personalities, modifications, tiers, stats, mutations
│  ├─ Net.lua                  remote events with per-player rate limits
│  ├─ MorphBuilder.lua         greybox customer bodies and mutation parts
│  └─ Signal.lua
├─ src/server/
│  ├─ Main.server.lua          bootstrap: world, services, player join/leave, shutdown save
│  ├─ Loader.lua               dependency-ordered Init/Start lifecycle (§27.6)
│  ├─ World/                   Restaurant Row and the restaurant layout
│  └─ Services/                PlayerData, Economy, Progression, Mutation, Restaurant, Cooking, Order,
│                              CustomerAI, Combat, Repair (names from canon §C19)
├─ src/client/
│  ├─ Main.client.lua, Store.lua
│  ├─ UI/Theme.lua             §24 colours, fonts and element helpers
│  └─ Controllers/             HUD, panels, minigames, customer visuals, combat input
├─ tests/                      formula unit tests + server and client smoke tests on a mock engine
└─ tools/                      run_tests.sh and the tiny Luau runner the tests use
```

The server owns every outcome: cooking grades, satisfaction, money and damage are computed in services, and
clients only send intents ("tap", "use this prompt"). Customers follow the GDD's SPCV pattern: the server moves an
invisible proxy part and each client builds the visible body locally.

To tune the game, edit `src/shared/Constants.lua` or the tables in `src/shared/Data/`. To test with more
customers, raise `Constants.DEMAND_SCALE` (canon demand is about one customer a minute at the start).

## Tests

```bash
./tools/run_tests.sh
```

This needs Rust (`cargo`) once, to build the small Luau runner in `tools/luaurun`. It runs:

- `tests/Formulas.spec.luau`: the canon formulas against the GDD reference values.
- `tests/ServerSmoke.spec.luau`: boots the real server scripts on a mock engine (`tests/mock/Engine.luau`) and plays
  a full session. That covers joining, picking a mutation, cooking at every station, a grill fire, serving
  customers, a wrong order, a fight, ignored customers, repair, level-up, a tier upgrade, then leaving and rejoining.
  The `nodatastore` variant repeats it with DataStores unavailable.
- `tests/ClientSmoke.spec.luau`: boots the real client scripts, sends every server event, clicks through every
  panel and renders a customer.

The mock is not Roblox: it catches script errors and broken logic, not physics, rendering or replication. Always
play-test in Studio as well.

Formatting and linting: `stylua src tests` and `selene src tests`. `roblox-lite.yml` declares the Roblox globals
for Selene when the full generated Roblox standard library isn't available.
