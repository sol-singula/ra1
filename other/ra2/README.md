# Steal a Dragon (ra2): playable game (Roblox)

Grab a dragon. Run home. Lock your door. Steal from everyone else.

The game lives in [`games/ra2 - Steal a Dragon/`](<../../games/ra2 - Steal a Dragon>). This folder holds the docs:
this README, the [publish checklist](PUBLISH.md), the [plan](PLAN.md), the [screenshots](screenshots/README.md) and the [thumbnails](thumbnails/README.md). Every command and path below is
relative to the game folder.

Everything is built from plain parts, so it runs in a blank Baseplate with no uploaded assets. The map: a cobblestone lobby with a golden dragon statue and the three leaderboards in a row, the Dragon Road (a royal carpet with lanterns and banners) running from the open Dragon Gate next to the lobby to a dark exit tunnel under a snowy mountain, 8 castles with towers and flags, forests, rocks, flowers, a ring of snowy mountains, clouds, and three dragons circling in the sky.

**Spawning:** new players spawn in the lobby looking straight down the Dragon Road, with the free dragon right in front of them. Once the tutorial is done, players spawn (and respawn) inside their own base, facing the road.

**Brick look:** like most top Roblox games, the world is shiny plastic bricks with Roblox's classic studs on top
(built in, no uploads). To switch back to smooth stone, wood and grass, set `BRICK_STYLE = false` in
`src/shared/Constants.lua`.

## Run it in Roblox Studio

1. Open the prebuilt file `StealADragon.rbxl` in the game folder. Or, to keep it synced while you edit:
   open a terminal in the game folder, run `rokit install` once, then `rojo serve`. In Studio, open a new
   Baseplate, then click **Connect** in the Rojo plugin.
2. **Game Settings → Places:** set **Max Players** to **8**. There are 8 bases.
3. **Game Settings → Security:** turn on **Enable Studio Access to API Services**. Without it the game still
   runs, but progress doesn't save, and the leaderboards only show the players in the server.
4. The place uses **Future** lighting (set by the project file). If you synced into an older Baseplate, select
   **Lighting** in the Explorer and set **Technology** to **Future**.
5. Press **Play**. To test stealing, use **Test → Clients and Servers** with 2 or 3 players.

### Test on a phone

In Studio, use the **Device** emulator (the phone icon at the top of the game view) and pick a phone in
landscape. On a real phone, publish the place and open it in the Roblox app. The game turns the screen to
landscape on its own.

## How to play

| Action | Phone / tablet | Keyboard / mouse | Gamepad |
|---|---|---|---|
| Grab, buy, steal, sell, hatch | tap the prompt | **E** (sell **F**, grow **G**) | X |
| Bonk | tap with the bat in your hand (hotbar slot 1) | click with the bat, or **Q** | R2 |
| Hotbar: bat, Speed Potion, Dragon Wings | tap a slot | **1**, **2**, **3** | LB / RB |
| Close a panel | ✕, or tap outside it | ✕ or Backspace | B |
| Lock your door | step on the red pad (stepping on again resets the timer), or the **LOCK** button | same, or **L** | Y |
| Collect coins | step on the gold pad | same | same |

1. **First time:** an 8-step tutorial with a bouncing **HERE** arrow. You grab a free dragon, run it home,
   collect coins, lock your door, steal Frosty from the Practice Base, and buy a dragon on the road. At the end
   you get an egg that **hatches tomorrow**.
2. **Dragons** walk down the Dragon Road. Tap **Buy** and carry the dragon home. Carrying slows you down, and
   rarer and bigger dragons slow you more. Reach your base and the dragon jumps into a free nest.
3. **Nests** make coins every second. Step on the gold pad to collect them. Buy more nests at your base: every
   locked nest has a **Buy nest** prompt for the next one.
4. **Lock** your door for 60 seconds by stepping on the red pad; step on it again any time to reset the timer to
   full. While it's locked, nobody can get in, except your friends.
5. **Steal:** walk into an open base and hold **Steal** on a dragon. Run home. The owner gets an alert. If they
   **bonk** you, you drop the dragon, and anyone can grab it for 8 seconds before it flies home.
6. **Level up:** dragons level up by themselves over real time, even while you're offline (fast at first, then
   slower: level 8 after 10 minutes, 18 after an hour, 50 after 8 hours, up to level 100). Each level adds 15% to
   its coins. Tap **Level Up** on your dragon to buy a level with coins (each one costs a bit more), or step on
   the **LEVEL ALL** plate at the back of your base to spend your coins on the cheapest level-ups across all your
   nests (with no coins it offers **+5 Levels for ALL** for Robux). Dragons grow
   in size at levels 8, 18 and 49 (Kid, Big, Giant) and stay Giant after that. A high-level dragon is a big prize
   for thieves.
7. **Your base** has 24 nests (4 to start, buy up to 20 with coins, +4 with the Extra Nests pass). Just inside the
   gate: the gold **coin pad**, the blue **Auto Collect** plate (step on it to buy the pass), the red **lock pad**
   and the orange **+5 MIN** plate (step on it to buy 5 more minutes of lock).
8. **Skins:** the Shop's **Skins** tab repaints the wings and belly of all your dragons. Midnight, Candy and Ocean
   cost coins; Lava, Royal Gold and Neon cost Robux.
9. **Your castle grows** with your dragon power (the coins per second of your nest dragons, before passes): a
   plain low wall at the start, then tall walls and back towers (25/s), gate towers, buttresses and ivy (250/s),
   a keep and corner turrets (2,500/s), and gold trim with a golden dragon over the gate (25,000/s).
10. **Hotbar:** slot 1 is the bonk bat (a big hammer with Mega Bonk). Slot 2 is the **Speed Potion**: 50% faster
    for 30 seconds; you start with 3, and 5 more cost Robux. Slot 3 is **Dragon Wings** (a pass): click to jump
    high, then glide where you steer. Wings can't lift a carried dragon.
11. **Secret:** walk to the very end of the exit tunnel. There's a door. 🪩

The lobby is the courtyard of a castle: walls with towers, a keep, and a fountain with the golden dragon statue.
The FREE dragon waits on the south side, near the spawn. The camera can't zoom out past 45 studs.

**Rarities:** Common, Rare, Epic, Legend and Secret. **Specials:** Fire and Ice ×2, Gold ×3, Rainbow ×5.

## What keeps players coming back

| Roblox signal | In the game |
|---|---|
| First minute | You hold a dragon within seconds, with an arrow showing every step |
| Playtime | Coins tick up, a new dragon every 2.5 s, a **Legend dragon every 5 minutes** with a countdown, goals with rewards |
| Day 2 return | The egg hatches tomorrow (then a new one starts), dragons level up overnight, coins earned while away (up to 8 hours), daily gift streak (day 2 = a Rare dragon, day 7 = a Legend) |
| Playing with friends | Friends in the server are a team: +10% coins each (up to +30%), they can enter your locked base, and a **TEAM STEAL** bonus when a friend is nearby |
| Inviting friends | **FRIENDS** button opens Roblox's invite. A brand-new friend who joins from your invite gives you a free Coral dragon and them 200 coins. Check Roblox's current rules on invite rewards before going live (switch: `INVITE_REWARDS` in `Constants.lua`). |
| Leaderboards | Three boards in the lobby: **TOP COINS** (lifetime coins), **TOP THIEVES** (steals) and **BEST DRAGONS** (best coins per second). Global, merged with the live players in the server. |

## Making money

Every paid item is a **fixed thing, never a random roll**, so Roblox's paid-random-item rules (odds disclosure
and bans for some countries and ages) don't apply. Offline bases can't be robbed.

**Game passes:** 2x Coins (129), VIP (449), Fast Feet (199), Extra Nests (249), Auto Collect (149), Long Lock (199),
Mega Bonk (149), Dragon Wings (299).

**Developer products:** Server Luck (99, rarer dragons for everyone in the server for 15 minutes, with your name
on it), Lock Now (19), 5-Minute Lock (35, also the **+5 MIN** plate in your base), +5 Levels for ALL (99, also
the **LEVEL ALL** plate when you have no coins), 5 Speed Potions (29, also the empty potion in the hotbar), Coin
Bag (49), Coin Chest (299), Daily Deal (25) and the Robux skins. These are bought from the world: +10 Levels (39,
tap **+10 Levels** on your dragon), Hatch Now (49, tap the egg), Buy Now (199, **Buy with Robux** on Epic and
better road dragons) and Double It (25, on the welcome-back screen).

### Hooking up the real items

Step-by-step, with every item's name, price and description, in the [publish checklist](PUBLISH.md#2-set-up-the-paid-items).
In short: create each item on the Creator Dashboard (**Monetization → Passes** and **Developer Products**), then
paste each ID into `src/shared/Data/Shop.lua` in place of `id = 0`.

While an ID is 0, buying it in Studio gives it for free so you can test, and in a live game the button says
"Coming soon". Product receipts are granted once and saved right away.

## Code layout

```text
games/ra2 - Steal a Dragon/
├─ default.project.json        Rojo project
├─ StealADragon.rbxl           prebuilt place
├─ src/shared/                 Constants (every number), Formulas (game math), Format, Net, Signal,
│                              Data/ (Dragons, Shop, Goals)
├─ src/server/
│  ├─ Main.server.lua, Loader.lua
│  ├─ World/                   WorldBuilder (castle-courtyard lobby, road, 8 castle bases that grow in 5
│  │                           levels, Practice Base), Disco (the secret room), Scenery (trees, rocks,
│  │                           mountains, lanterns, towers, clouds), DragonBuilder (dragon models)
│  └─ Services/                PlayerData (saving), Economy (coins, passes, leaderstats), Team (friends),
│                              Base (locks, banks, pads), Dragon (nests, carry, steal, drop, place),
│                              Road (spawns, Legend event, luck, free and practice stands), Combat (bonk, speed),
│                              Tool (hotbar: bat, potions, wings; camera zoom cap),
│                              Reward (daily, egg, goals, offline, invites), Shop (purchases), Leaderboard,
│                              Tutorial
├─ src/client/                 Theme (phone scaling), Store, Controllers/ (Hud, Panels, Tutorial, Prompts, Fx,
│                              Guide (the glowing path), Tool (wing jump and glide), Disco (party lights))
├─ tests/                      formula unit tests, server and client smoke tests on a mock engine
└─ tools/                      run_tests.sh, the Luau test runner, gameplay/ (screenshot session + renderer)
```

**Look of the screens:** chunky glossy buttons with thick dark outlines, white text with a black outline, pill-shaped
bars, red "!" badges, panels with a coloured header and a round close button that pop in, and buttons that
squish when tapped (all in `src/client/UI/Theme.lua`). The screens follow Roblox's UI, accessibility and
adaptive-design guidance: Reduced Motion, Text Size and Background Transparency settings, key hints for
keyboard and gamepad, gamepad navigation and more. See [UI_GUIDELINES.md](UI_GUIDELINES.md).

**Phones first:** every screen is laid out for a 1000 × 560 canvas and scaled to the real screen, about 0.7 on a
phone. Buttons stay about 48 points or bigger. The menu buttons sit above the thumbstick, LOCK sits left of the
jump button, and Roblox's own hotbar holds the bat, potions and wings. Each player only sees the prompts that make sense for them, and the server checks everything
again.

## Tests

```bash
./tools/run_tests.sh
```

This needs Rust (`cargo`) once, to build the small Luau runner. It runs:

- **Formula unit tests:** 119 checks.
- **Client smoke test:** a phone-sized screen, every event, button and panel, including the Skins tab; 90 checks.
- **Server smoke test:** 3 players through the tutorial, buying, stealing, bonking, grabbing, locks, selling,
  nests, speed, passes and receipts, daily gift, egg, goals, friends and invites, leaderboards, offline coins
  and leaving mid-steal, returning players spawning in their own base, levels, the base plates, skins and the exit tunnel; 121 checks,
  plus a run with DataStores turned off.

The mock engine is not Roblox: it catches script errors and broken logic, not physics or rendering. Always
play-test in Studio too.

Screenshots: `luaurun tools/gameplay/session.luau <jsonDir>`, then
`node tools/gameplay/render.js <jsonDir> <pngDir> --modules <node_modules with puppeteer, three@0.149.0, @fontsource/fredoka, @fontsource/luckiest-guy>`.
