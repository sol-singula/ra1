# FARM TO FLEET — the game plan (clean rebuild)

This is a from-scratch design. Nothing below assumes the current code; the only things kept are the
Roblox place (same universe and place IDs, so the game's URL and stats carry on), the Rojo project
shape, and the mock-engine test harness and renderer in `tools/`. All of `src/` and `tests/` is
rewritten.

## 1. The pitch

**A farm tycoon where the crops grow themselves, the customers are the only bottleneck, and every
upgrade is a pad on the ground in front of you.**

You start with six tiles of wheat, a tiny barn and a stand on the road. Crops pop up on their own;
you walk over them to pick them; they go in the barn; customers walk up to the stand and buy them.
Within two minutes the barn is full and the sign says "CUSTOMERS CAN'T KEEP UP": the first shop
upgrade pad is right there and costs what you just made. From then on it's the classic tycoon
rhythm, tuned so that the field always slightly out-produces the shop and the shop upgrade is
always the thing you want next. At the end of the plot you move to a bigger farm (rebirth) with
a permanent multiplier and a new look.

Three rules that every system obeys:

1. **One bottleneck.** Production is free and automatic. Selling is the limit. The only warning in
   the game is "barn full".
2. **No menus to progress.** Every purchase is a pad on the ground, laid out in buy order, the next
   affordable one glowing. Menus exist only for the shop (Robux), settings and the leaderboard.
3. **Always something to buy in under a minute.** The pad ladder is priced so a new pad is
   affordable every 20 to 60 seconds for the first hour, then every few minutes.

## 2. The loop, in detail

### Grow
- A **tile** grows one crop at a time. Growth time is per crop kind (wheat 8 s ... golden apple 60 s).
- The field grows **random crops** out of the kinds unlocked so far, weighted toward the newer ones,
  so the field looks varied and the better crops matter without any choosing.
- A ripe crop sits on the tile with a bob and a sparkle. There is no rot, no watering, no tending.

### Pick
- Walk over a ripe tile and it's picked (touch, no click). Crops go into **your basket** (a number
  over your head), and the basket empties into the **barn** when you walk past it, or automatically
  after 3 s if you own the Wheelbarrow pad.
- The **Tractor** pads automate picking: a tractor drives the rows and picks everything. Tractor 1
  comes early (pad 9) so the player is freed from picking within the first ten minutes, which is
  when the game becomes the shop game.

### Sell
- The **barn** has a cap. Crops in it are what's for sale.
- **Customers** walk up from the road at `rate` a minute, each buys up to `basket` crops (the dearest
  first) and pays the crop's value. Sales are the game's cash.
- A full barn stops the field (crops stay ripe on the tiles, nothing is lost) and the HUD shows the
  one warning: **BARN FULL — customers can't keep up. Upgrade the shop!** with an arrow to the pad.
- **Vehicles** are the second sell channel (the "fleet"): a van takes 40 crops out of the barn,
  drives off, comes back in 20 s and pays 2.5x. They're big pads mid-game and they make the fleet
  side of the name real.

### Buy
- Pads in a fixed ladder (section 4). Buying a pad places the building and grows the number it
  owns. Pads are grouped by area so you can read the farm: field in the middle, shop on the road,
  pens on the left, garage on the right.

### Rebirth
- The last pad of the plot is **MOVE TO A BIGGER FARM**. It resets cash and pads, keeps rebirths,
  gives +50% to all earnings per rebirth, a bigger plot skin (fence colour, barn colour, a trophy
  by the gate) and unlocks one crop kind per rebirth beyond the base eight.

## 3. Economy and numbers

Starting state: 6 tiles, barn cap 60, 10 customers a minute, basket 1, wheat only, $0.

| Crop | Unlocks at | Grow (s) | Value |
|---|---|---|---|
| Wheat | start | 8 | $1 |
| Carrot | level 2 | 10 | $2 |
| Tomato | level 4 | 12 | $4 |
| Corn | level 6 | 15 | $7 |
| Pumpkin | level 9 | 20 | $12 |
| Strawberry | level 12 | 25 | $20 |
| Melon | level 16 | 35 | $35 |
| Golden Apple | level 20 | 60 | $80 |
| (rebirth crops: Dragonfruit, Truffle, Starfruit...) | 1 per rebirth | | |

Level = farm XP from sales (1 XP per crop sold). Levels are the only gate besides cash and they're
spaced so the first hour reaches level 10 or so.

Production vs. selling, first ten minutes (the designed tension):

| Minute | Tiles | Crops/min | Customers/min x basket | Who's behind |
|---|---|---|---|---|
| 0 | 6 | 45 | 10 x 1 | shop (barn full at ~1:30) |
| 2 | 6 | 45 | 16 x 1 (Sign) | shop |
| 4 | 10 | 70 | 24 x 1 (Bell) | shop |
| 6 | 10 | 70 | 24 x 2 (Helper) | field |
| 8 | 16 | 110 | 48 (Parking + Helper) | shop |

The ladder keeps alternating. Shop pads are always the cheapest pad on offer when the barn is at
90%, so the fix to the warning is always affordable.

Multipliers (all stack, all shown on the HUD as one "x" number):
- Animals: Chickens +25% crop value, Pigs +25% growth speed, Sheep +50% barn cap, Cows +25%
  customers, Goats +1 basket. Each pen has 3 levels.
- Rebirth: +50% earnings per rebirth.
- Passes: 2x Customers, Auto-Pick (wheelbarrow + tractor behaviour from minute one), VIP (2x XP,
  gold name, VIP fence).
- Gems: Rush (2x customers for 10 min), Instant Grow (every tile ripe now), Skip (buy the next pad
  for gems).

## 4. The pad ladder

Stage 1 — THE SHACK (first 15 minutes): 14 pads, $15 to $900.
1. Sign (+6 customers) 2. Field row 2 (+4 tiles) 3. Bell (+8 customers) 4. Wheelbarrow (auto-empty
basket) 5. Chicken Coop 6. Shop Helper (basket 2) 7. Field row 3 (+6 tiles) 8. Bigger Barn (cap
150) 9. Tractor 10. Parking (+12 customers) 11. Pig Pen 12. Field row 4 13. Awning (+10 customers)
14. BUILD THE FARMHOUSE (stage gate, $900).

Stage 2 — THE FARM (15 to 60 minutes): 16 pads, $1.2k to $40k.
Second Counter (basket 3), Sheep Pen, Big Barn (cap 400), Tractor 2, Field rows 5 and 6, Adverts
(+20 customers), Cow Barn, Garage + Van, Chicken Coop 2, Billboard (+30), Pig Pen 2, Tractor 3,
Van 2, Drive-Thru (basket 4), BUILD THE RANCH (gate).

Stage 3 — THE RANCH (1 to 4 hours): 16 pads, $50k to $2M.
Greenhouse (rows 7 and 8, grow 1.5x), Truck (120 crops, 3x), Sheep Pen 2, Cow Barn 2, Goat Pen,
Radio Ad (+50 customers), Supermarket Deal (basket 6), Tractor 4, Truck 2, Silo (cap 2000), all pens
level 3, TV Ad (+100 customers), Semi (400 crops, 4x), Helipad (cosmetic flex), MOVE TO A BIGGER
FARM (rebirth, $2M).

Every pad: name, one-line effect, price, a 3D stand-in of the building (ghost), and a glowing ring
when affordable. Pads are 10 to 20 studs from the previous one, never behind a fence.

## 5. What's on screen

- **HUD (top left):** cash, cash a minute (the real one, from the last minute), level bar.
- **Shop line (top centre):** `🏪 24 customers/min · basket 2 · barn 112/150`. Turns red with the
  BARN FULL warning. Nothing else ever warns.
- **Guide (bottom centre):** one line and an arrow in the world: "Walk over the wheat", "Walk to the
  barn", "Buy the Sign". Fifteen steps for the first ten minutes, then it only speaks for stage gates,
  the first van and the rebirth.
- **Right rail:** Shop (Robux), Rebirth, Leaderboard, Settings. Four buttons.
- **Pads:** price and name on a billboard, green when affordable, grey when not, a lock with the
  level when level-gated.
- **World feedback:** a cash pop on every sale, a shopper figure walking in and out, the tractor
  driving, vans leaving and returning, confetti on a pad buy, a bigger burst on a stage gate.

## 6. The world

- 6 plots per server round a central road loop. Each plot: 120 x 90 studs, road side at the front
  with the stand, field in the centre, pens left, garage right, farmhouse back.
- Toon look: flat bright colours, chunky parts, a soft sky, a single warm sun, long shadows. All
  buildings are built from parts in code (no asset uploads needed), each with a two-tone roof and
  a sign. Crops are simple shapes with one accent colour, big enough to read from the default camera.
- The hub in the centre: leaderboard boards (cash earned, rebirths), a trophy for the top farm, a
  spawn by the road. No gameplay in the hub.

## 7. Monetization and retention

- Passes: 2x Customers (the obvious one, 399 R$), Auto-Pick (199), VIP (499), Fleet Pack (van skins,
  149). Dev products: gem packs. Gems are also earned: 1 per level, 3 per daily login streak day,
  5 per rebirth.
- Offline earnings: the farm keeps selling for up to 2 hours while away at 50% rate, paid on return
  with a card ("While you were away: +$3,450"). The fleet pass doubles the window.
- Daily login streak with gems. No daily quests, no contracts, no orders.
- Leaderboards: all-time cash, rebirths. A "FARM OF THE DAY" trophy at the hub for the top earner.

## 8. Technical plan

Kept: Rojo project, `tools/` (luaurun, mock engine, screenshot renderer, test runner), lint config,
the publish script. Rewritten from a blank `src/`:

Server services (Loader with Init/Start/OnPlayerReady as now, but new code):
`PlayerData` (profile, save, offline time) · `Plot` (claim, layout, pads) · `Field` (tiles, growth,
random crop choice, picking) · `Barn` (cap, stock) · `Shop` (customers, basket, sales) · `Fleet`
(vehicle trips) · `Pads` (the ladder, buy, build) · `Animals` (pens, multipliers) · `Economy` (cash,
XP, level, multipliers) · `Rebirth` · `Monetize` (passes, products, gems) · `Guide` (step state) ·
`Leaderboard` · `Analytics`.

Client controllers: `Hud` · `Pads` (billboards, glow, ghosts) · `Guide` (line + arrow) ·
`Field` (crop visuals, pick effects) · `Shoppers` · `Vehicles` · `Effects` (cash pops, confetti) ·
`ShopUI` · `Rebirth` · `Leaderboard` · `Away` card.

Data modules (shared, pure, tested): `Crops`, `Pads`, `Animals`, `Passes`, `Guide`, `Balance` (every
number from section 3 in one file).

Tests (mock engine): `Boot`, `Field`, `Shop`, `Pads`, `Animals`, `Fleet`, `Rebirth`, `Guide`,
`Comeback` (offline), `Monetize`. Each is a scripted play-through of its slice: the first ten
minutes test plays the real pad ladder with the real prices and checks a pad is affordable every
minute.

## 9. Build order (each step ships: tests green, built, published)

1. **Core loop.** Plot, field, pick, barn, customers, HUD, the first 14 pads, guide steps 1 to 15.
   Playable and fun on its own. This is the biggest step.
2. **Stage 2 and the fleet.** Animals with multipliers, shop tiers, garage and vans, stage gates.
3. **Stage 3 and rebirth.** Trucks, semi, greenhouse, rebirth with skins, rebirth crops.
4. **Money and retention.** Passes, gems, offline earnings, daily streak, leaderboards, hub.
5. **Look and feel pass.** Lighting, sky, toon materials, sounds, every effect, screenshots for the
   store page, new description and icon brief.
6. **Tuning.** Play the mock run end to end, time to each pad, fix any gap over 90 s in the first
   hour.
