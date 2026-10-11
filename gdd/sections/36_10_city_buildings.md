### 36.10 City Buildings Database

> **Owner:** A12 City. All 22 canon buildings (§C16.2). Districts, travel, secrets and the event system are
> specified in §18; events in §36.11. Prices follow §C4 (mutations §C4.5–§C4.6, hiring §C4.8, station
> upgrades §C4.9, recipe learning 5 × price §C10, taxi §C16.1). Activity MB rewards use the **ERM** unit of
> §18.8.4 (`MB = round(ERM × NetMBPerHour[tier] / 60)`). Acceptance criteria: `AC-18-30` … `AC-18-49`.

#### 36.10.1 Summary

| ID | Name | District | Unlock | Main NPC | Primary services | Currency used |
|---|---|---|---|---|---|---|
| `BLD_01` | Mutation Mart | DST_02 | start | `NPC_004` Mutty McMutface | Common/Uncommon catalog, daily Rare shelf, try-on mirrors, tutorial starter part | MB; MS (Rare) |
| `BLD_02` | Body Mods | DST_02 | start | `NPC_005` Glamtrax | recolor parts, palettes, morph naming, pose studio | MB (palettes); Robux cosmetics only via §23 |
| `BLD_03` | Restaurant Supplies | DST_01 | start | `NPC_006` Bolt Butterworth | stations & fixtures, station upgrades Lv2–Lv5, special-ingredient crates | MB |
| `BLD_04` | Recruitment Office | DST_03 | tutorial step 10 | `NPC_007` Ms. Hirewell | candidate board, interviews, hiring, employee training | MB |
| `BLD_05` | Training Gym | DST_10 | L12 | `NPC_008` Coach Crunch | combat drills, ability test-drive, stat & skill respec | MB (paid stat respec); free otherwise |
| `BLD_06` | Cooking Academy | DST_03 | tutorial step 10 | `NPC_009` Professor Saucington | learn recipes (5 × price), technique classes, practice kitchens, Alien Cuisine course | MB |
| `BLD_07` | Repair Workshop | DST_04 | L8 | `NPC_010` Wrenchy | repair drills, remote repair order, repair-tech training | MB |
| `BLD_08` | Morph Arena | DST_10 | L12 | `NPC_011` Rex Rumbleton | PvP opt-in lobby, matchmaking, spectating, PvE bots, seasons (§21) | free |
| `BLD_09` | City Hall | DST_03 | tutorial step 10 | `NPC_002` Mayor Moosington | expansion permits, rename, event calendar, records, roof access | MB (rename only) |
| `BLD_10` | Job Board | DST_01 | start | `NPC_012` Pinboard Pete | daily/weekly/challenge quests, event bounties | free |
| `BLD_11` | Mutation Laboratory | DST_06 | L15 | `NPC_013` Dr. Splice | fusion, category research, upgrade chamber, dupe reactor | MS, RT, MB |
| `BLD_12` | Monster Mall | DST_05 | L6 | `NPC_014` Mallory Megamall | decor furniture, emotes, palettes, restaurant themes, arcade | MB; Robux cosmetics only via §23 |
| `BLD_13` | Mystery Market | DST_09 | L20 (L15 during `EVT_024`) | `NPC_015` The Hooded Hagfish | weekly Legendary, daily Epic/Rare, MS corner | MB, MS, RT |
| `BLD_14` | Food Critic Headquarters | DST_07 | L10 | `NPC_016` Madame Fourchette | critique challenges, Gazette features, weekly theme | free (rewards MB/MS/RT) |
| `BLD_15` | Delivery Depot | DST_04 | L8 | `NPC_017` Dispatch Dot | delivery missions, rentals | free (earns MB) |
| `BLD_16` | Morph Museum | DST_06 | L15 | `NPC_018` Curator Fossilbottom | collection wings, lore, collection rewards, Vault of Secrets | free (rewards) |
| `BLD_17` | Restaurant Row Plots | DST_01 | start | `NPC_001` Nana Gristle | 8 player restaurant plots, façades, doors, status signs | — |
| `BLD_18` | Central Morph Metro Station | DST_03 | tutorial step 10 | `NPC_019` Conductor Choo | Metro hub, station discovery, Metro Card | free (10 MB snacks) |
| `BLD_19` | Morph Park & Fountain | DST_08 | L4 | `NPC_025` Old Man Pigeon | social hub, daily rumor, seasonal sculpture/planting areas | free |
| `BLD_20` | Weird Produce Stand | DST_02 | start | `NPC_023` Farmer Fungus | special produce crates, daily "Ugly Produce" deal | MB |
| `BLD_21` | Sewer King's Throne Room | DST_09 | L20 (Event Access L8 during `EVT_007`) | `NPC_020` King Ratbeard | boss arena for `EVT_007`, royal errands | free |
| `BLD_22` | Showcase Stage | DST_07 | L10 | `NPC_024` DJ Morphenstein | morph shows, voting, `EVT_005` finals venue (with `NPC_029`) | free |

#### 36.10.2 Common building pattern (applies to every row unless the row overrides it)

- **Model:** `Workspace.City.Districts.<DST>.Buildings.<BLD>` with `Facade` (`ModelStreamingMode.Atomic`,
  `LevelOfDetail.StreamingMesh`), `Interior` (Atomic, built inside the façade footprint, no teleport), `Door`
  (open doorway, 12 studs tall) and an `InteriorTrigger` that sets the sound zone (§18.9.5).
- **Interaction:** service points are server-created `ProximityPrompt`s (`MaxActivationDistance` 10, `HoldDuration`
  0, keyboard E / gamepad X / tap). Opening a screen requires being within 12 studs; the screen auto-closes beyond
  20 studs. Full-screen screens cannot open while In Combat and auto-close if combat starts (§C22 E2).
- **Transactions:** remote `Shop.Purchase(shopId, itemKey, qty, requestGuid)`; the server re-reads the current
  catalog/rotation, validates level, tier, slots, ownership limits and balance, then debits through
  `EconomyService` and grants through the owning service in one transaction keyed by `requestGuid` (a retry with
  the same GUID returns the first result). Prices shown to the client are display-only.
- **Robux:** only §23 cosmetics, always labelled with the Robux icon and never mixed into MB grids.
- **Accessibility:** every rarity/status uses the §C13.3 color + shape pair; all screens support touch,
  gamepad and keyboard focus order.
- **Analytics:** `mmr_building_enter` (bld), `mmr_shop_purchase` (bld, item, currency, amount).

#### BLD_01 — Mutation Mart

- **Location:** DST_02, north end of the bazaar facing Mutation Mile; 48 × 40 footprint, 36 studs tall.
- **Exterior:** a giant teal vending machine; the "window" shows today's two Rare parts on rotating mannequins;
  a spinning Morph Capsule on the roof; neon "MUTATION MART — Parts for Every Body!".
- **Interior layout:** three aisles by UI group (Head/Ears/Eyes · Arms/Legs/Tails · Extras); 4 Try-On Mirror
  pods; the glass Rare Rotation case; the Starter Pedestal (tutorial); checkout counter.
- **NPCs:** `NPC_004` Mutty McMutface (his vending-machine torso dispenses purchases in capsules); two stock-clerk
  gremlins restocking shelves badly; a "mannequin" that is actually a shy citizen and waves.
- **Interactions:** aisle shelves open the shop pre-filtered; Try-On applies any stocked part to a client-side
  copy of your morph for 30 s with an ability demo on a dummy; Wishlist bell (notify when a wishlisted Rare+
  appears here or at `BLD_13`).
- **Services:** permanent catalog of every Common and Uncommon part whose acquisition includes `SHOP_MART` (§36.3);
  **Rare Rotation Shelf** — 2 Rare parts, global, refreshed 00:00 UTC daily (deterministic like §18.8.2, no
  repeat within 14 days); duplicates may be bought as upgrade copies (§C4.6).
- **Currency costs:** Common 150–400 MB; Uncommon 800–2,000 MB; Rare 4,000–10,000 MB + 20 MS — the exact
  per-part price is the §36.3 catalog value. Parts above the player's equip level can be bought only after a
  "You can equip this at Lv 12" confirm.
- **Unlock:** start.
- **Quests:** `QST_TUT_010` Your First Mutation (free choice of `MUT_145` Octopus Arm, `MUT_144` Crab Claw Arm or
  `MUT_153` Wrench Claw Arm at the Starter Pedestal, then equip); daily/weekly "buy or equip" quests (§20).
- **UI screens:** `MutationShopScreen` (grid by UI group, rarity shape badges, stat-diff preview vs. equipped),
  `TryOnMirrorOverlay`, `PurchaseConfirmModal`, `StarterChoiceScreen`.
- **Roblox implementation:** catalog data in `ReplicatedStorage.Shared.Config.MutationCatalog`; Try-On uses the
  client `MorphAssemblyService` builder on a local clone (no server state, removed on exit); purchase via
  `Shop.Purchase` → `MutationService.Grant`; Rare shelf computed by the shared rotation module, re-checked at
  purchase ("Mutty restocked! Prices updated.").

#### BLD_02 — Body Mods

- **Location:** DST_02, beside the Mart on Mutation Mile.
- **Exterior:** a giant pink salon chair with a flamingo-neck hair-dryer crane; neon "BODY MODS — Look Weird,
  Feel Weird".
- **Interior layout:** 4 makeover chairs, the Palette Wall, a typewriter Naming Booth, a Mirror Maze (preview
  saved loadouts), Glamtrax's mini runway with photo lights.
- **NPCs:** `NPC_005` Glamtrax; an assistant whose robot arm holds 40 combs at once.
- **Interactions:** sit in a chair to recolor any owned part per slot; walk the mini runway for a pose photo;
  Mirror Maze shows your 3 loadouts side by side.
- **Services:** per-part recolor from owned palettes (free, unlimited); palette shop; morph naming (free;
  filtered); loadout cosmetic preview; extra cosmetic loadout slots are a §23 Robux cosmetic.
- **Currency costs:** Basic palettes 1,500 MB; Neon palettes 6,000 MB; Prestige palettes 20,000 MB (L30)
  [TUNABLE]. Recolor and naming free. No stat effects are sold here.
- **Unlock:** start (prompted after `QST_TUT_010`).
- **Quests:** style dailies ("recolor 2 parts"), Showcase prep quests (§20).
- **UI screens:** `BodyModsScreen` (part list → palette swatches with names, never a free color wheel),
  `PaletteShopScreen`, `NamingModal`.
- **Roblox implementation:** colors stored as `{slot, paletteId, swatchIndex}`; the server validates palette
  ownership (never a raw client `Color3`); applied to `MeshPart.Color` with `SurfaceAppearance.AlphaMode =
  Overlay` on tintable parts; names filtered with `TextService:FilterStringAsync` and shown via
  `GetNonChatStringForBroadcastAsync`.

#### BLD_03 — Restaurant Supplies

- **Location:** DST_01, corner of Gravy Lane and Grand Gravy Boulevard (≤ 300 studs from every plot).
- **Exterior:** corrugated warehouse with a spatula-shaped crane, rolling shutters, neon "RESTAURANT SUPPLIES — If
  It Cooks, We Got It (Probably)".
- **Interior layout:** Appliance Showroom (working demo stations), Utility aisle, Upgrade Bench, Special
  Ingredients cold room, loading dock that "ships" to the player's `STN_DELIVERY`.
- **NPCs:** `NPC_006` Bolt Butterworth (beaver with forklift legs, drives the aisles); two forklift helpers.
- **Interactions:** try any station in the showroom (grill a demo patty — no rewards); browse by kitchen
  zone; Upgrade Bench shows station levels side by side.
- **Services:** buy kitchen stations and utility fixtures per the §C7.1 availability schedule (level + tier
  gates, appliance-slot check against §C6); station upgrades Lv2–Lv5 (§C4.9); special-ingredient crates (§7
  stocked ingredients); re-orders of previously bought items and crates may also be placed from the player's
  `STN_DELIVERY` with a +10 % delivery fee [TUNABLE].
- **Currency costs:** station base prices per §15/§36.13; upgrades ×1.5 / ×4 / ×10 / ×25 of base (Lv2–Lv5,
  requiring TIER_02 / TIER_04 / TIER_06 / TIER_08); crates per §7.
- **Unlock:** start.
- **Quests:** `QST_TUT_011` Fancy Upgrades (first restaurant upgrade); restaurant-expansion challenges; "stock up"
  dailies (§20).
- **UI screens:** `SuppliesCatalogScreen` (tabs Appliances / Utility / Upgrades / Crates; slot meter "4/6
  appliance slots"), `StationUpgradeScreen`, `CrateOrderScreen`.
- **Roblox implementation:** purchases go to `InventoryService` for placement in build mode (§15); upgrades
  target owned station instance IDs through `CookingService`/`BuildingService`; showroom stations run
  `CookingService` in Practice mode (no economy writes).

#### BLD_04 — Recruitment Office

- **Location:** DST_03, north side of Gravy Plaza.
- **Exterior:** an office tower with a banner "NOW HIRING: WEIRDOS" and a revolving door that spins too fast
  (gently flings players 4 studs — harmless).
- **Interior layout:** lobby with take-a-number machine; Candidate Lounge where the 6 current candidates sit as
  visuals; Interview Booth; Ms. Hirewell's desk; Training Room.
- **NPCs:** `NPC_007` Ms. Hirewell (her filing-cabinet torso slides open to show résumés); the 6 candidates
  (generated, unnamed outside the roster).
- **Interactions:** talk to a candidate in the lounge to open their card; "Ask a question" flavor lines reveal
  a trait hint; sign the contract at the desk.
- **Services:** 6-candidate board refreshed free every 4 h; interviews; hiring; employee training sessions
  (§16 defines generation, traits, odds, training).
- **Currency costs:** hire per §C4.8 bands (Common 200–600 … Legendary 180,000–450,000 MB); manual board refresh
  50 MB × tier, max 5/day [TUNABLE]; training per §16.
- **Unlock:** tutorial step 10 (DST_03).
- **Quests:** `QST_TUT_012` Hire Help (Ollie `EMP_001`'s paperwork is filed here; script in §32);
  employee-management challenges (§20).
- **UI screens:** `RecruitBoardScreen`, `CandidateDetailPanel` (stats, wage, traits, potential),
  `HireConfirmModal` (shows employee cap vs. §C6), `TrainingScreen`.
- **Roblox implementation:** candidates generated server-side from `seed = hash(UserId, boardEpoch)` and stored
  in the profile so the board survives rejoin; lounge visuals are client-built from the candidates' part lists;
  `Recruit.Hire(candidateIndex, requestGuid)` validates cap and balance in `EmployeeService`.

#### BLD_05 — Training Gym

- **Location:** DST_10, beside the Arena on Rumble Road.
- **Exterior:** a building flexing two tower-arms; neon "TRAINING GYM — No Pain, Just Gains (and Feathers)".
- **Interior layout:** Dummy Gauntlet ring, Dodge Dojo (swinging rolling pins), Block Party lane (tomato
  cannons), Ability Range (8 dummies), the "Re-Spec-Tacular" machine, the Very Old Punching Bag behind the
  lockers (`CSEC_15`).
- **NPCs:** `NPC_008` Coach Crunch on a whistle tower; sparring partners (unnamed).
- **Interactions:** drills with Bronze/Silver/Gold targets; Ability Test-Drive (equip any canon combat ability
  `ABL_009`–`ABL_060` on a gym-only temporary rig for 60 s against dummies); sparring.
- **Services:** drills (first medal of each tier pays once: Bronze 0.05, Silver 0.10, Gold 0.15 × XPRate + 10/20/30
  MS; repeat runs give 0.01 × XPRate, capped at 0.2 × XPRate per day); stat respec; skill-tree respec.
- **Currency costs:** drills free; stat respec free once per 24 h, otherwise 500 MB × level (§C5) or one stat
  respec token; skill-tree respec free once per 7 days (§C18). Both respecs are also reachable from the §14 menu.
- **Unlock:** L12.
- **Quests:** combat challenges and gym dailies (§20).
- **UI screens:** `GymDrillSelectScreen`, `DrillHUD` (timer, medal targets), `RespecScreen`,
  `AbilityTestDriveOverlay`.
- **Roblox implementation:** drill pods are separate Atomic models; dummies are server proxies with infinite
  Huff Points; scores derive from `CombatService` hit events (server-side); test-drive abilities are flagged
  `gymOnly` and stripped on leaving the pod trigger.

#### BLD_06 — Cooking Academy

- **Location:** DST_03, east side of Gravy Plaza.
- **Exterior:** a school with a chef-hat dome and a whisk bell tower; neon "COOKING ACADEMY — Est. Whenever".
- **Interior layout:** Lecture Hall (chalkboard recipe catalog), 4 Practice Kitchens (full station set), Library
  of Recipes, Dean's Office, the Wall of Noodles (hint for `CSEC_04`), the Hall of Burnt Things (a museum of
  famous kitchen failures).
- **NPCs:** `NPC_009` Professor Saucington (eight arms, eight pointers); teaching-assistant students.
- **Interactions:** inspect any recipe; cook it free in a Practice Kitchen before learning it (no payout); take
  technique classes (chop rhythm, grill window, fryer timing).
- **Services:** learn recipes once learnable (unlock level reached; ALN needs the Alien Cuisine course, MUT needs an
  owned `STN_INFUSER`, LEG needs its Legendary Recipe quest — §C10); technique classes (first Gold per technique
  0.1 × XPRate; repeats capped at 0.15 × XPRate per day); the Alien Cuisine course (story chapter 5, free).
- **Currency costs:** learning = 5 × the recipe's base price (§6), e.g. a 16 MB dish costs 80 MB, a 109 MB dish
  545 MB.
- **Unlock:** tutorial step 10; recipes learnable from L2.
- **Quests:** cooking challenges; story chapter 5 course (with Zorp `NPC_027`).
- **UI screens:** `RecipeCatalogScreen` (filters: category, level, stations owned ✓/✗, margin),
  `LearnConfirmModal`, `PracticeKitchenHUD`, `TechniqueClassHUD`.
- **Roblox implementation:** Practice Kitchens reuse `CookingService` state machines in Practice mode with no
  economy or reputation writes; `Academy.LearnRecipe(recipeId, requestGuid)` validates gates in `RecipeService`.

#### BLD_07 — Repair Workshop

- **Location:** DST_04, at the end of Smokestack Avenue.
- **Exterior:** a garage welded from old fridges and ovens, a spinning giant wrench sign, harmless spark
  particles; neon "REPAIR WORKSHOP — We Fix What Your Customers Broke".
- **Interior layout:** Repair Range (a conveyor that brings tables, chairs and grills in random damage states),
  Tool Wall, Wrenchy's Bench, Demolition Pit (break props with a mallet, then fix them), technician training bay.
- **NPCs:** `NPC_010` Wrenchy (spider legs let him fix the ceiling); two apprentice robots.
- **Interactions:** timed repair drills using the §15 repair minigames; Demolition Pit for practice.
- **Services:** repair drills (first medal per tier as `BLD_05`, repeat cap 0.2 × XPRate/day); **Remote Repair
  Order** — Wrenchy's crew fixes every Cracked/Broken item in your restaurant within 60 s for the normal §15
  repair cost +20 % [TUNABLE]; rebuild of Destroyed items at the canon ≤ 25 % of item price (§C6); Repair
  Technician training (§16).
- **Currency costs:** drills free; remote repair = §15 cost × 1.2; rebuild ≤ 25 % of item price.
- **Unlock:** L8.
- **Quests:** repair challenges (§20); `EVT_010` support.
- **UI screens:** `RepairDrillScreen`, `RemoteRepairQuoteModal` (itemised list, total, ETA).
- **Roblox implementation:** `Repair.OrderRemote(requestGuid)` calls `RepairService.QueueRemoteRepair(owner)`;
  refused while any customer in that restaurant is at anger ≥ 3 (avoids §C22 E3 conflicts); the conveyor range
  uses ≤ 6 anchored props cycling damage states (no physics).

#### BLD_08 — Morph Arena

- **Location:** DST_10, the colosseum at the end of Rumble Road.
- **Exterior:** stacked giant food tins with banners and Rex Rumbleton's jumbotron; neon "MORPH ARENA — Fight
  Fair, Fall Funny".
- **Interior layout (lobby only):** entrance hall with the Opt-In Desk, queue pads (1v1, 2v2, free-for-all),
  spectator stands over the main pit, Season Board, Trophy Case (shows `FRN_904`), portal to "Bash the Bots" PvE.
- **NPCs:** `NPC_011` Rex Rumbleton (announcer, microphone hand); a turtle ticket-taker who stamps your hand.
- **Interactions:** opt in to PvP at the desk (explicit consent dialog, revocable any time); step on a queue
  pad; spectate live matches; enter PvE bot waves without opting in.
- **Services:** matchmaking, ranked seasons, spectating, PvE bots, `EVT_025` host. Match rules, balance and
  rewards are specified in §21; seasons pay RT per §C4.1.
- **Currency costs:** free entry; no wagers, no entry fees.
- **Unlock:** L12.
- **Quests:** combat challenges; arena season goals (§21).
- **UI screens:** `ArenaLobbyScreen` (mode select, PvP consent, queue timer), `SpectateHUD`,
  `SeasonRewardsScreen`.
- **Roblox implementation:** the lobby is in-city; matches run in an arena-pits region or in reserved servers
  (`TeleportService:ReserveServer`) as decided in §21 — that is the only city building that may teleport.
  Players who are not opted in can never be targeted by players (collision group + `CombatService` check).

#### BLD_09 — City Hall

- **Location:** DST_03, south side of Gravy Plaza; roof at 96 studs.
- **Exterior:** a domed hall with a moose-antler crown, a clock tower that runs backwards, the "TOO MANY MENUS"
  box on the roof (`CSEC_05`), a window-washer lift in Sauce Drip Alley.
- **Interior layout:** lobby with a 3-second fake queue gag ("Now serving: 7… 8… 4,000… you!"), Permits Desk,
  Records Room, Mayor's Office (`CSEC_12` duck), Complaints Department (a box that says "Thank you!" and
  shreds), Health Inspector's office, Event Calendar desk. Anchor Andy's MCN booth stands on the plaza outside.
- **NPCs:** `NPC_002` Mayor Moosington; `NPC_022` Inspector Grimewell (office hours between patrols); `NPC_026`
  Sergeant Rhonda on the front steps; clerks (unnamed).
- **Interactions:** collect permits; rename the restaurant; read the next-24-h event schedule; ride the
  window-washer lift (20 s) to the roof.
- **Services:** **City Hall Expansion Permits** — required before upgrading to TIER_04 and every tier above;
  each is a short restaurant-expansion quest (fill in Form 27-Moose, get a stamp from 3 departments, have the
  Mayor sign with his hoof) with **no extra MB** (the permit is included in the §C6 tier price); restaurant
  rename; City Records (personal stats); Event Calendar; roof access.
- **Currency costs:** permits 0 MB; first rename free, then 1,000 MB × tier [TUNABLE].
- **Unlock:** tutorial step 10.
- **Quests:** permit quests (restaurant-expansion type, one per tier from TIER_04); story chapters with the
  Mayor (§20).
- **UI screens:** `PermitScreen` (checklist: level, tier MB, quest steps), `RenameModal`,
  `EventCalendarScreen`, `RecordsScreen`.
- **Roblox implementation:** permits stored as `permits[TIER_xx] = true`; `BuildingService` refuses TIER_04+
  upgrades without the permit; names filtered via `TextService`.

#### BLD_10 — Job Board

- **Location:** DST_01, centre of Gravy Lane between plots 4 and 5.
- **Exterior:** a two-storey corkboard kiosk wrapped in flapping flyers and pigeons; neon "JOB BOARD — Help
  Wanted. Help Needed. HELP."
- **Interior layout:** open-air kiosk with four boards: Daily, Weekly, Challenges, Event Bounties.
- **NPCs:** `NPC_012` Pinboard Pete (corkboard torso; flyers pinned to himself).
- **Interactions:** tap a flyer to read and accept; turn in completed quests; read event bounties during Live
  events; `CPIX_01` hides on the back of the board.
- **Services:** quest acceptance and turn-in for daily, weekly and all challenge types; event bounty board
  (mirrors the current event objectives). Quest rows, rerolls and rewards are defined in §20.
- **Currency costs:** free (reroll rules per §20).
- **Unlock:** start.
- **Quests:** daily, weekly, cooking/combat/repair/exploration/employee/expansion challenges (§20).
- **UI screens:** `JobBoardScreen` (tabs), `QuestDetailPanel`.
- **Roblox implementation:** flyers are a `SurfaceGui` rendered per client from that player's quest set;
  `QuestService` owns all state.

#### BLD_11 — Mutation Laboratory

- **Location:** DST_06, under the Noodle Helix.
- **Exterior:** a glass dome of bubbling tubes; neon "MUTATION LABORATORY — Science! (Results May Vary.
  Actually They Don't, We Checked.)".
- **Interior layout:** Fusion Reactor (3 input pods + 1 output pod), 16 Research Terminals (one per category),
  Upgrade Chamber, Dupe Reactor, specimen tubes, Dr. Splice's office, a safety shower that sprays confetti.
- **NPCs:** `NPC_013` Dr. Splice (axolotl head, robot arm); lab robots.
- **Interactions:** load parts into pods, pick a target, pull the big lever; read category research trees.
- **Services and rules:**

| Service | Inputs | Output / effect | Cost |
|---|---|---|---|
| Fusion → Uncommon | 3 Common parts of one category | 1 chosen Uncommon of that category | 15 MS |
| Fusion → Rare | 3 Uncommon parts of one category | 1 chosen Rare of that category | 60 MS |
| Fusion → Epic | 3 Rare parts of one category (Research ≥ R2) | 1 chosen Epic of that category | 200 MS |
| Fusion → Legendary | 3 Epic parts of one category (Research ≥ R3) | 1 chosen Legendary of that category | 400 MS + 15 RT |
| Fusion → Mythic | 3 Legendary parts of the same category (Research R4) | 1 chosen Mythic of that category | 600 MS + 40 RT (canon §C4.5) |
| Category research | — | R1 free (Uncommon/Rare targets) · R2 5 RT (Epic) · R3 15 RT (Legendary) · R4 30 RT (Mythic), per category | RT as listed |
| Upgrade Chamber | 1 owned part + 1 duplicate copy (or DupeSubstituteMS) | +1 level | exactly §C4.6 (same as the §13 menu) |
| Dupe Reactor | spare duplicates | MS per §C4.6 conversion column | — |

  Fusion is **deterministic** — the player chooses the target from parts of that category and rarity whose
  acquisition includes `LAB_FUSION` (§36.3); no random outcomes. Inputs must be unequipped and in no saved
  loadout; Secret parts can be neither input nor output; inputs above Lv1 refund 50 % of the MS spent upgrading
  them; the output starts at Lv1 and keeps its normal equip level (Mythic L60).
- **Currency costs:** as in the table; upgrades per §C4.6.
- **Unlock:** L15.
- **Quests:** story (Dr. Splice chapters), weekly research quests that pay RT (§20).
- **UI screens:** `LabFusionScreen` (3 input slots, target picker, cost breakdown, "No randomness — you pick!"),
  `ResearchTreeScreen` (16 × 4 grid), `UpgradeChamberScreen`, `DupeReactorScreen`.
- **Roblox implementation:** `Lab.Fuse(inputIds[3], targetMutId, requestGuid)` → `MutationService` validates
  ownership, category, rarity, equip/loadout state, research level and balances, then consumes inputs, charges
  and grants the output inside one session-locked profile update; the 6 s reactor cutscene is client-side and
  starts only after the server confirms.

#### BLD_12 — Monster Mall

- **Location:** DST_05; 200 × 160 studs, 4 floors plus parking.
- **Exterior:** a stack of monster-sized shopping bags crowned by a peacock-tail fan sign; neon "MONSTER MALL —
  Shop Till You Drop (Your Tail)".
- **Interior layout:** atrium with sideways escalators; F1 Décor-asaurus (decorations and decorative furniture);
  F2 Emote Emporium + Palette Palace + massage chairs; F3 Theme Park-ing (restaurant themes); F4 arcade and a food
  court of plastic display food ("look, don't eat"); hidden Floor ½ (`CSEC_13`).
- **NPCs:** `NPC_014` Mallory Megamall (escalator legs); store clerks; mall-walking Grandma Golems.
- **Interactions:** preview any decor item placed into a hologram of your own dining room; try emotes in a
  mirror booth; arcade machines (score-attack mini-games: daily first play 0.03 × XPRate; best score titles).
- **Services:** decor and decorative furniture (non-functional items of §36.13), earnable emotes, palettes,
  restaurant themes; §23 Robux cosmetic packs in a clearly separate Theme Park-ing showcase.
- **Currency costs:** decor per §36.13; emotes 2,000–15,000 MB [TUNABLE]; palettes as `BLD_02`; MB themes per §15.
- **Unlock:** L6.
- **Quests:** decorating challenges (restaurant-expansion type), window-shopping dailies (§20).
- **UI screens:** `MallDirectoryScreen`, `DecorCatalogScreen` (with dining-room hologram preview),
  `EmoteShopScreen`, `ThemePreviewScreen`.
- **Roblox implementation:** each floor is its own Atomic interior model; Robux purchases use
  `MarketplaceService:PromptProductPurchase` / `PromptGamePassPurchase` handled by §23's `ProcessReceipt`;
  the hologram preview is client-only.

#### BLD_13 — Mystery Market

- **Location:** DST_09, a cavern junction 80 studs from Drain Station, lit by glowing mushrooms.
- **Exterior:** a ramshackle bazaar on a rusty barge in a lime-soda canal; a neon sign whose words shuffle
  each visit ("MYSTERY MARKET" / "MARKET? MYSTERY." / "MYSTERIOUS MARKET").
- **Interior layout:** the Hagfish's counter, the Legendary Vault (pedestal under a sheet), Epic Shelf, Rare
  Shelf, MS Corner, the Night Clock (moon dial mirroring the surface night cycle) and the Fog Bell (`CSEC_07`).
- **NPCs:** `NPC_015` The Hooded Hagfish; a parrotfish assistant who repeats prices.
- **Interactions:** reveal the Vault (sheet-pull animation), browse shelves, ask "What's next week?" (the
  Hagfish whispers next week's Legendary from Thursday 00:00 UTC).
- **Rotation rules:**

| Slot | Count | Refresh | Price (exact value from §36.3, inside the band) | Limit |
|---|---|---|---|---|
| Legendary Vault | 1 | weekly, Monday 00:00 UTC | 150,000–400,000 MB + 250 MS + 10 RT | 1 per player per week |
| Epic Shelf | 2 | daily 00:00 UTC | 25,000–60,000 MB + 80 MS | 1 of each per player per day |
| Rare Shelf | 3 | daily 00:00 UTC | 4,000–10,000 MB + 20 MS | 2 of each per player per day |
| MS Corner — crates | 4 special-ingredient crates (§7) | daily | 20–120 MS per crate [TUNABLE] | 5 of each per day |
| MS Corner — palettes | 2 cosmetic palettes | weekly | 150–400 MS [TUNABLE] | 1 each |
| Midnight Sale extras (`EVT_024` only) | +1 Legendary (last week's), +1 Epic | during the event | same as above | same as above |

  Stock is **global** (same on every server for every player) and **deterministic**: a seeded shuffle cycles
  through every part whose acquisition includes `SHOP_ROTATION` (§36.3); each Legendary appears exactly once
  per cycle (cycle length = number of eligible Legendaries, in weeks); Epic/Rare parts never repeat within 14
  days. Mutation prices are never discounted (the §C4.5 bands are protected; `EVT_024` adds stock, not sales).
- **Currency costs:** as in the table.
- **Unlock:** L20; during `EVT_024`, L15+ players get Event Access through the Market Chute.
- **Quests:** story (King Ratbeard chapters), exploration challenges (§20); `CSEC_07`.
- **UI screens:** `MysteryMarketScreen` (vault reveal, refresh countdowns, "next week" whisper),
  `PurchaseConfirmModal` with an MB/MS/RT breakdown.
- **Roblox implementation:** `MarketRotation.Get(dayIndex, weekIndex, salt)` in `ReplicatedStorage.Shared`
  drives the display; the server recomputes at purchase; if the day rolled over while the screen was open the
  purchase fails with "The Hagfish swapped the stock!" and the screen refreshes. Weekly limits are stored as
  `market.week = w, market.bought = {...}`.

#### BLD_14 — Food Critic Headquarters

- **Location:** DST_07, top of the Neon Strip.
- **Exterior:** an art-deco tower shaped like a giant fork stuck in a cake; a star-rating ticker; neon "FOOD
  CRITIC HQ — We Taste So You Don't Have To".
- **Interior layout:** Tasting Hall (judging table, Fourchette's giraffe neck reaches across it), 4 Test Kitchen
  pods, the Gazette Press, the Wall of Stars (server and global weekly top restaurants).
- **NPCs:** `NPC_016` Madame Fourchette; junior critics with tiny notebooks.
- **Interactions:** start a challenge at the judging table; read your printed review (a newspaper prop you can
  hold).
- **Rating challenges** (3 rewarded attempts per day [TUNABLE]):

| Challenge | Format | Scoring |
|---|---|---|
| Tasting Flight | cook 3 dishes from your own menu in a Test Kitchen within 6 min | each dish 1–5 Forks |
| Theme Night | weekly theme (e.g., "Only Round Food", "Spicy but Polite", "Breakfast at Night"); 3 dishes matching the theme's ingredient tags | each dish 1–5 Forks; off-theme dish = 1 Fork |
| Secret Shopper | within the next 30 min a critic customer (`PER_004` or `PER_025`) visits your restaurant unannounced | the visit's satisfaction S → Forks |

  **Forks:** DishScore = 0.4·Q + 0.3·C + 0.3·A (§C8, §C11.3); ≥ 0.95 → 5, ≥ 0.85 → 4, ≥ 0.70 → 3, ≥ 0.55 → 2,
  else 1. Secret Shopper: S ≥ 95 → 5, ≥ 85 → 4, ≥ 70 → 3, ≥ 50 → 2, else 1 (×3 to compare with flights).
  **Rewards per challenge (total Forks of 15):** ≥ 9 → 6 ERM + 15 MS; ≥ 12 → 10 ERM + 30 MS + 0.1 × XPRate;
  15 → additionally 1 RT and a **Gazette Feature** (`EventMult ×1.10` restaurant demand for 60 min). First time
  scoring 15 in all three challenge types → `FRN_903` Critic's Five-Star Plaque.
- **Currency costs:** free.
- **Unlock:** L10.
- **Quests:** story chapters with Fourchette, cooking challenges (§20); host of `EVT_008`.
- **UI screens:** `CriticChallengeScreen`, `ForkResultScreen` (forks drop one by one), `GazetteViewer`.
- **Roblox implementation:** Test Kitchens use `CookingService` Practice mode with authoritative scoring;
  Secret Shopper asks `CustomerAIService` for a flagged critic spawn inside the window; rewards keyed
  `critic:<day>:<attempt>`.

#### BLD_15 — Delivery Depot

- **Location:** DST_04, beside the forklift yard.
- **Exterior:** a hangar with a giant snail-shell roof and parcel chutes spitting boxes onto conveyors; neon
  "DELIVERY DEPOT — Fast-ish!".
- **Interior layout:** dispatch desk, mission board, parcel conveyors, Rental Rack (rocket boots, roller skates),
  a wall map of the 24 Residential addresses plus every building door.
- **NPCs:** `NPC_017` Dispatch Dot (a snail who is somehow the fastest thing in the city); sorting robots.
- **Interactions:** take a mission at the board; rent boots (cosmetic + mission-only speed); deliver to a glowing
  door; ring the bell.
- **Delivery missions:**

| Mission | Rules | Time limit | Reward |
|---|---|---|---|
| Parcel Run | carry 1 parcel from the Depot to an address | `distance / 14 + 30` s | 2 ERM + 0.02 × XPRate |
| Hot Meal | cook a requested dish from your own menu, deliver within 4 min of pickup | 240 s | 3 ERM + dish price × 1.5 (quality scales the tip like §C11.4) |
| Fragile Jelly | carry a wobbling jelly; jumping, sprinting or getting hit adds wobble; ≥ 100 wobble = splat (fail, no cost) | `distance / 12 + 40` s | 4 ERM + 0.03 × XPRate |
| Multi-Drop | 3 parcels to 3 addresses (carry capacity §C3 decides how many trips) | `total / 14 + 60` s | 7 ERM + 0.05 × XPRate |
| Rush Hour | only during `EVT_023`: any mission type, rewards ×2 | as type | ×2 |

  The first 20 missions per UTC day pay full rewards, then 25 % [TUNABLE]. Rocket-boot rental: free, +25 % move
  speed only while a mission is active. Owners with `ROLE_DELIVERY` staff gain the passive delivery revenue of
  §16/§17; the Depot shows that stream's daily total.
- **Currency costs:** free.
- **Unlock:** L8.
- **Quests:** delivery dailies; employee-management challenges for delivery staff (§20).
- **UI screens:** `DeliveryBoardScreen`, `MissionHUD` (arrow, timer, wobble meter).
- **Roblox implementation:** addresses are `CollectionService`-tagged door parts (`DeliveryAddress`); arrival is
  accepted only within 10 studs of the target and after an elapsed time ≥ `distance / (maxPlayerSpeed × 1.2)`
  (speed-hack guard); parcels are carried items (§C3), never physics parts.

#### BLD_16 — Morph Museum

- **Location:** DST_06, across the lawn from the Lab.
- **Exterior:** a classical museum with columns of giant fish bones and a T-Rex skeleton wearing a toaster for a
  head; neon "MORPH MUSEUM — History Is Weird".
- **Interior layout:** Grand Hall (T-Rex, `CSEC_16`; the **Empty Exhibit**, `CSEC_02`), 16 Category Wings (one per
  §C13.2 category; one exhibit per mutation family, lit when you own a part of it), the **Vault of Secrets** (7
  "?" pedestals for Secret mutations), lore placards, a Gift Shop of Gifts You Already Have (joke, sells nothing).
- **NPCs:** `NPC_018` Curator Fossilbottom (his grandfather-clock torso chimes when you claim a reward); docent
  robots.
- **Interactions:** walk the wings; read placards (first read of each family's placard: 0.005 × XPRate, cap 0.1
  × XPRate/day); claim collection tiers at the curator.
- **Collection rewards** (claimed manually, once each; Secret parts are excluded from category counts and
  shown only in the Vault):

| Tier | Requirement | Reward |
|---|---|---|
| Wing Bronze | own 25 % of that category's non-Secret parts | 30 MS + 0.05 × XPRate |
| Wing Silver | own 50 % | 1 Morph Capsule + palette "<Category> Classic" |
| Wing Gold | own 100 % | 5 RT + title "Curator of <Category>" |
| Collection 50 | 50 distinct non-Secret parts | 50 MS |
| Collection 100 | 100 distinct | 1 Morph Capsule |
| Collection 150 | 150 distinct | `FRN_909` Museum Replica Fossil |
| Collection 200 | 200 distinct | 10 RT |
| Collection Complete | all 273 non-Secret parts | title "Walking Encyclopedia" + palette "Museum Marble" |
| Vault Complete | all 7 Secret parts | title "Keeper of Secrets" |

- **Currency costs:** free.
- **Unlock:** L15.
- **Quests:** exploration challenges, the museum collection quest line (§20).
- **UI screens:** `MuseumMapScreen`, `WingDetailScreen`, `ClaimRewardModal`.
- **Roblox implementation:** each wing is its own Atomic model; exhibits show 3D part models only within
  40 studs (billboard silhouettes beyond) to respect the triangle budget; lit/unlit state is computed client-side
  from the replicated owned-ID set; claims via `Museum.ClaimTier(tierKey)` validated by `MutationService` counts.

#### BLD_17 — Restaurant Row Plots (player restaurants)

- **Location:** DST_01, 8 plots (80 × 100 studs) in two facing rows of 4 along Gravy Lane.
- **Exterior:** each plot carries its owner's façade, which visibly upgrades with tier (10 façade sets, §15/§25):
  from a leaning shack with a hand-painted sign (TIER_01) to a glowing palace with a rotating neon dish (TIER_10).
  Plot sign: owner display name, restaurant name, ★ rating and status (OPEN / OPEN — Staff on duty / Out to
  Lunch / Event Break / Closed).
- **Interior layout:** instanced in the far-off Interiors region (§C3, §15); the façade door is the portal.
- **NPCs:** `NPC_001` Nana Gristle (cranky hologram menu board inside each player's restaurant: tutorial mentor
  and relay of Anchor Andy's alerts); customers queue outside (§8).
- **Interactions:** enter your own door; enter a friend's door per §21 permissions; read a plot sign; knock on an
  empty plot ("For Rent… to weirdos").
- **Services:** plot assignment, façade display, visiting (same server) and status signage.
- **Currency costs:** none here (tier upgrades are §15; permits `BLD_09`).
- **Unlock:** start.
- **Quests:** `QST_TUT_001` Welcome to the Shack through `QST_TUT_009` are played here (§32).
- **UI screens:** `PlotSignInspect` (owner, rating, Visit button), `VisitRequestPrompt` (§21).
- **Roblox implementation:** `RestaurantService` assigns the lowest free plot on join (or a plot next to a joined
  friend when free); a leaving player's plot is released after 60 s (façade fades to the For Rent sign); façades
  are Atomic + `StreamingMesh`; the door calls the same pre-stream + `PivotTo` pipeline as §18.4.

#### BLD_18 — Central Morph Metro Station

- **Location:** DST_03, west side of Gravy Plaza (first building on Grand Gravy Boulevard).
- **Exterior:** a glass dome shaped like a centipede's head with a 100-handed clock; neon "MORPH METRO — Mostly
  On Time".
- **Interior layout:** concourse with the wall Metro Map (discovered stations lit), free turnstiles, 3 platforms,
  Conductor Choo's cab, Lost Property (a joke counter that returns a sock you never lost), snack machines.
- **NPCs:** `NPC_019` Conductor Choo (centipede body, train-engine head; waves 40 hands at once).
- **Interactions:** discover the hub; open the Metro Map; get your Metro Card stamped at each station.
- **Services:** Metro travel hub (§18.4), Metro Card (10 stamps → title "Commuter" + palette "Line Colors").
- **Currency costs:** travel free; Metro Snacks 10 MB (cosmetic held item, 60 s).
- **Unlock:** tutorial step 10.
- **Quests:** exploration challenges (discover stations) (§20).
- **UI screens:** `MetroMapScreen`, ride transition overlay.
- **Roblox implementation:** discovery is a server-side concourse trigger; rides use the §18.4 pipeline.

#### BLD_19 — Morph Park & Fountain

- **Location:** DST_08, centre of the district; 160 × 160 studs.
- **Exterior:** lawns, picnic tables, a bandstand, a giant tree with a swing, and a fountain topped by a
  three-headed pigeon statue; string lights at night.
- **Interior layout:** open air: Emote Circle, sitting spots, Snowmorph sculpture lawn (`EVT_030`), 12 planter beds
  (`EVT_031`), fountain basin (`CPIX_08`).
- **NPCs:** `NPC_025` Old Man Pigeon on his bench (daily rumor, gossip, `CSEC_11`); joggers and picnicking
  citizens.
- **Interactions:** sit, emote together (5+ players emoting in the circle trigger a confetti burst), wade in the
  fountain, ask Old Man Pigeon for the day's rumor.
- **Services:** social hub; daily rumor (always about an undiscovered secret); seasonal event areas.
- **Currency costs:** free.
- **Unlock:** L4.
- **Quests:** social and exploration dailies, e.g. "emote with 3 players" (§20).
- **UI screens:** `RumorDialog` (dialogue panel).
- **Roblox implementation:** no physics props; seats are `Seat` instances; the fountain is anchored geometry plus
  `ParticleEmitter`s that scale with the device bucket.

#### BLD_20 — Weird Produce Stand

- **Location:** DST_02, at the foot of the Bazaar Steps.
- **Exterior:** a farm stand built into a giant mushroom with a cow-spotted awning, crates of glowing veg and a
  scale that weighs customers and comments; neon "WEIRD PRODUCE — Freshly Mutated".
- **Interior layout:** open stall with produce crates, the "Ugly Produce" bargain bin, a seed rack (seasonal).
- **NPCs:** `NPC_023` Farmer Fungus (mushroom cap, cow body; moos when pleased).
- **Interactions:** buy crates; weigh yourself (mutation-count joke readout).
- **Services:** special-ingredient crates of plant/veg/fruit/mutagen stock (§7 stocked ingredients, e.g.
  `ING_MUTAGEN_GOO`, `ING_LAVA_PEPPER` where §7 marks them stocked); daily "Ugly Produce" deal on 2 crate types
  (−20 % [TUNABLE]); seasonal crates during `EVT_031`.
- **Currency costs:** crate prices per §7; MB only.
- **Unlock:** start (crates appear when any known recipe needs them).
- **Quests:** sourcing dailies; story errands where King Ratbeard "borrows" Fungus' crates (§20).
- **UI screens:** `ProduceStandScreen`.
- **Roblox implementation:** crates credit `InventoryService` stock directly; stall crates are client decor.

#### BLD_21 — Sewer King's Throne Room

- **Location:** DST_09, behind a giant drain-mouth decorated with bottle caps.
- **Exterior:** green neon "THRONE ROOM — Knock First. Or Don't. We're Rats."
- **Interior layout (boss arena):** a 120-stud-diameter cheese-wheel platform floating in fizzy lime soda;
  4 pipe outlets (minion spawns); a ring of crate stacks (cover); the throne built from "borrowed" kitchen
  appliances; spectator ledges for under-level players.
- **NPCs:** `NPC_020` King Ratbeard (giant rat head, crown, crab claws); rat courtiers.
- **Interactions:** outside events: audience with the King (dialogue), Royal Errand quest, throne photo spot.
  During `EVT_007`: the boss fight.
- **`EVT_007` arena rules:** Event Access via the Event Chute for L8+ during the event; boss Huff Points
  `HP = 5,000 × participants^0.9 × clamp(0.6 + 0.02 × avgLevel, 0.8, 2.6)` [TUNABLE]; three stages at 100–66 %
  (Cheese Wheel Roll: telegraphed rim rolls, jump or dodge), 66–33 % (Crab Claw Clamp: claws pin a player for
  2 s unless teammates Wallop the claw), 33–0 % (Royal Tantrum: 8 rat minions + crown boomerangs). At 0 Huff
  Points Ratbeard is Dizzy (`STS_DIZZY`), apologises, and throws a cheese party. Player KO = Seeing Stars, respawn
  at the arena edge after 4 s (no losses, §C12.1).
- **Currency costs:** free.
- **Unlock:** L20 (Event Access L8 during `EVT_007`).
- **Quests:** story chapters (King Ratbeard), Royal Errands (exploration type, §20).
- **UI screens:** `BossHUD` (boss bar with stage pips, participant list), `ThroneDialog`.
- **Roblox implementation:** arena `ModelStreamingMode.PersistentPerPlayer` with `AddPersistentPlayer` for each
  participant while the event runs; the boss is an SPCV proxy with a server hitbox; minions ≤ 24 proxies;
  projectiles are scripted arcs (§C3).

#### BLD_22 — Showcase Stage

- **Location:** DST_07, south end of the Neon Strip; the Grand Tournament Kitchen is attached backstage.
- **Exterior:** an open-air amphitheatre with a boombox-shaped stage and bat-ear speaker towers; neon "SHOWCASE
  STAGE — Strut Your Stuff".
- **Interior layout:** 40-stud runway, backstage dressing rooms (quick loadout swaps), bleachers for 8 players
  plus NPC crowd, voting podium, DJ booth; the Grand Tournament Kitchen (8 competition stations) for `EVT_005`.
- **NPCs:** `NPC_024` DJ Morphenstein (host); `NPC_029` Chef Supreme Omnivora (tournament host, backstage).
- **Interactions:** queue for a show; walk the runway (pose prompts every 4 s); vote 1–5 with emoji.
- **Morph shows:** auto-scheduled every 15 min, or on demand when ≥ 3 players queue; 2–6 contestants; one
  theme per show from: Most Tentacles · Tallest Morph · Best Color Coordination · Cutest Spooky · Most Legs ·
  Breakfast Energy (FOOD parts) · Robot Chic · Ocean Vibes · Pure Chaos (5+ categories) · Tiny but Mighty ·
  Shiniest (glow tag) · Animal Kingdom (MAMMAL only). Score = 60 % audience votes (no self-votes; party and
  friend votes weigh 0.5) + 40 % theme match computed from the contestant's equipped parts' categories, slots
  and §C13.5 tags. Rewards: every contestant 0.03 × XPRate + 5 MS; winner 20 MS + 2 ERM; first win title
  "Showstopper"; 10 wins emote "Runway Spin"; 5 rewarded shows per day [TUNABLE].
- **Currency costs:** free.
- **Unlock:** L10.
- **Quests:** social dailies; story finale venue (§20).
- **UI screens:** `ShowQueueScreen`, `RunwayHUD`, `VotingPanel`, `ShowResultsCard`.
- **Roblox implementation:** show state is server-side; `Stage.Vote(showId, contestantUserId, value)` limited to
  one vote per contestant per voter; contestants are their live characters (no copies); theme-match scoring is
  a pure shared module so the UI can explain the score.

#### 36.10.3 Acceptance Criteria

- **AC-18-30:** All 22 buildings `BLD_01`–`BLD_22` exist in their canon districts with a working door, interior
  trigger and every service listed in their row.
- **AC-18-31:** No mutation sale price falls outside the §C4.5 band for its rarity, including during `EVT_024`.
- **AC-18-32:** Mystery Market stock is identical on two servers for the same UTC day, the Legendary changes
  exactly at Monday 00:00 UTC, and every eligible Legendary appears once before any repeats.
- **AC-18-33:** A fusion request with a mismatched category, rarity, equipped input or missing research level is
  rejected with no state change; a valid one consumes exactly 3 inputs, charges exactly the table cost and grants
  exactly the chosen output, even when the request is retried with the same GUID.
- **AC-18-34:** Recipe learning charges exactly 5 × the recipe price and is refused before the unlock level or
  without the ALN course / `STN_INFUSER` / Legendary quest gates.
- **AC-18-35:** Station upgrades charge ×1.5 / ×4 / ×10 / ×25 of base price and are refused below
  TIER_02 / TIER_04 / TIER_06 / TIER_08 respectively.
- **AC-18-36:** Tier upgrades to TIER_04+ are refused without the matching City Hall permit, and permits never
  charge MB.
- **AC-18-37:** Hiring charges a value inside the §C4.8 band of the candidate's rarity and is refused at the
  employee cap.
- **AC-18-38:** Critic Forks follow the DishScore thresholds in 100 % of a 200-dish automated test, and `FRN_903`
  is granted only once.
- **AC-18-39:** Delivery arrivals faster than `distance / (maxSpeed × 1.2)` are rejected and logged.
- **AC-18-40:** Museum tiers are claimable exactly once each, and Secret parts never count toward wing tiers.
- **AC-18-41:** During `EVT_007` the Throne Room stays streamed for every participant for the full fight
  (no stream-out events logged), and the boss HP matches the formula for 1, 4 and 8 participants.
- **AC-18-42:** Showcase votes cannot target the voter, are limited to one per contestant, and friend votes weigh
  exactly 0.5.
- **AC-18-43:** Every shop screen closes automatically when the player moves > 20 studs away or enters combat, and
  no purchase can complete after the close.
