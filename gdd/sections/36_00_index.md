## 36. Content Database Appendices

This section holds the implementation-oriented content databases required by brief Part 23. Every database uses
stable, unique identifiers; every cross-reference anywhere in this document resolves to a definition (checked
automatically by `gdd/tools/validate_gdd.py`; see the Completion Manifest at the top of the document). Large,
number-heavy databases are **data-backed**: their source of truth is a JSON file in `gdd/data/` and the markdown
tables are rendered from it by a script in `gdd/tools/`, so derived values (ingredient cost, profit margin,
upgrade costs, stat budgets) are computed rather than typed. The same JSON files feed the generated Luau data
modules described in §27, so the GDD and the game share one content source.

### 36.1 Database Index and Identifier Conventions

#### 36.1.1 Database index (brief Part 23 checklist)

| # | Database (Part 23) | ID pattern | Canonical location | Primary consumer (service, §27) |
|---|---|---|---|---|
| 1 | All recipes | `RCP_<CAT>_<NNN>` | §6.3–§6.17 (full specs), §36.2 (quick reference) | `RecipeService`, `OrderService`, `CookingService` |
| 2 | All ingredients | `ING_<NAME>` | §7 | `RecipeService`, `InventoryService` |
| 3 | All mutation parts | `MUT_<NNN>` | §36.3 | `MutationService`, `MorphAssemblyService` |
| 4 | All mutation synergies | `SYN_<NNN>` | §36.4 (rules in §12.10) | `MutationService` |
| 5 | All customer personalities | `PER_<NNN>` | §9 | `CustomerAIService` |
| 6 | All employee archetypes | `EMP_<NNN>` (roles `ROLE_<NAME>`) | §36.8 (roles §16, §36.1.4) | `EmployeeService`, `OfflineEarningsService` |
| 7 | All NPCs | `NPC_<NNN>` | §19 | `QuestService`, client dialogue controller |
| 8 | All quests | `QST_<TYPE>_<NNN>` | §20 | `QuestService` |
| 9 | All city buildings | `BLD_<NN>` (districts `DST_<NN>`) | §36.10 (districts §18, §36.1.3) | `CityEventService`, city controllers |
| 10 | All city events | `EVT_<NNN>` | §36.11 | `CityEventService` |
| 11 | All restaurant upgrades | `TIER_<NN>`, `UPG_<NNN>` | §36.12 | `RestaurantService`, `BuildingService` |
| 12 | All furniture | `FRN_<NNN>` | §36.13 | `BuildingService`, `RepairService` |
| 13 | All abilities | `ABL_<NNN>` (status effects `STS_<NAME>`) | §36.6, §36.7 | `CombatService` |
| 14 | All animations | `ANM_<NNN>` | §36.14 | client `Animator` controllers |
| 15 | All sounds | `SFX_<NNN>`, `MUS_<NNN>` | §36.15 | `AudioController` |
| 16 | All achievements | `ACH_<NNN>` | §36.16 | `ProgressionService` |
| 17 | All progression milestones | `MLS_<NNN>` | §36.17 | `ProgressionService`, analytics |
| + | Order modifications | `MOD_<NNN>` | §6.18 | `OrderService` |
| + | Kitchen stations | `STN_<NAME>` | §5 (specs), §36.1.5 | `CookingService` |
| + | Morph combination examples | `CMB_<NNN>` | §36.5 (rules in §12.9) | `MorphAssemblyService` presets |
| + | Skill-tree nodes | `SKL_<TREE>_<NN>` | §14 | `ProgressionService` |
| + | Offline incidents | `INC_<NNN>` | §36.9 | `OfflineEarningsService` |

#### 36.1.2 Identifier rules

| Prefix / pattern | Entity | Notes |
|---|---|---|
| `RCP_<CAT>_<NNN>` | Recipe | CAT ∈ BRG, PIZ, TAC, SAN, SOP, PST, BRK, DES, DRK, SEA, SAL, FRI, ALN, MUT, LEG |
| `ING_<NAME>` | Ingredient | Descriptive upper-snake name |
| `MOD_<NNN>` | Order modification | |
| `STN_<NAME>` | Kitchen station type | |
| `PER_<NNN>` | Customer personality | |
| `ABL_<NNN>` | Ability | 001–008 base kit, 009–060 mutation combat, 061–070 mutation utility |
| `STS_<NAME>` | Status effect | |
| `MUT_<NNN>` | Mutation part | |
| `SYN_<NNN>` / `CMB_<NNN>` | Synergy / morph combination example | |
| `SKL_<TREE>_<NN>` | Skill node | TREE ∈ CHEF, CMBT, RPR (primary), SVC, MGMT (specializations) |
| `ACH_<NNN>` / `MLS_<NNN>` | Achievement / milestone | |
| `TIER_<NN>` / `UPG_<NNN>` / `FRN_<NNN>` | Restaurant tier / upgrade / furniture item | `FRN_901`–`FRN_910` are non-purchasable trophies |
| `ROLE_<NAME>` / `EMP_<NNN>` / `INC_<NNN>` | Employee role / archetype / offline incident | |
| `DST_<NN>` / `BLD_<NN>` / `NPC_<NNN>` / `EVT_<NNN>` | District / building / named NPC / city event | |
| `QST_<TYPE>_<NNN>` | Quest | TYPE ∈ TUT, STY, DLY, WKY, CHF, CBT, RPR, EXP, EMP, RST |
| `ANM_<NNN>` / `SFX_<NNN>` / `MUS_<NNN>` | Animation / sound effect / music | `ANM_301`–`ANM_370` mirror `ABL_001`–`ABL_070` |

Rules: identifiers are upper-snake ASCII, never reused, never renumbered; retired content keeps its ID with a
`deprecated` flag in data. New content continues each sequence (the next mutation part is the first unused
`MUT_` number, and so on), as described in §33. Non-database names: services are PascalCase (`CookingService`),
remotes are `<Domain>.<Action>` (`Cooking.InteractStation`), analytics events are `mmr_<snake_case>`.

#### 36.1.3 Districts

| ID | District | Unlock | Connects to |
|---|---|---|---|
| `DST_01` | Restaurant Row | start | DST_02, DST_03, DST_08 |
| `DST_02` | Mutation Market | start | DST_01, DST_03, DST_06 |
| `DST_03` | Downtown Morph City | start (tutorial step 10) | DST_01, DST_02, DST_04, DST_05, DST_07, DST_10 |
| `DST_04` | Industrial District | L8 | DST_03, DST_09 |
| `DST_05` | Monster Mall | L6 | DST_03, DST_07 |
| `DST_06` | Mutation Research District | L15 | DST_02, DST_09 |
| `DST_07` | Entertainment District | L10 | DST_03, DST_05, DST_10 |
| `DST_08` | Residential District | L4 | DST_01, DST_09 |
| `DST_09` | Underground Mutation Sewers | L20 | DST_04, DST_06, DST_08 (hidden manholes) |
| `DST_10` | Arena District | L12 | DST_03, DST_07 |

#### 36.1.4 Employee roles

| ID | Role | Online summary | Offline contribution |
|---|---|---|---|
| `ROLE_CHEF` | Chef | cooks full recipes at assigned stations | kitchen capacity (required for offline operation) |
| `ROLE_PREP` | Prep Cook | chops and prepares components for chefs | +15 % kitchen capacity per prep cook (max +45 %) |
| `ROLE_WAITER` | Waiter | seats customers, takes orders, delivers food | service capacity (required at TIER_03+) |
| `ROLE_CASHIER` | Cashier | processes payments, boosts tips | +10 % service capacity, +1 % tip rate per 20 skill |
| `ROLE_DISH` | Dishwasher | washes plates | prevents "No Clean Plates" stalls (−20 % kitchen capacity if absent at TIER_04+) |
| `ROLE_CLEANER` | Cleaner | removes trash and spills | keeps cleanliness high |
| `ROLE_REPAIR` | Repair Technician | repairs damaged objects | auto-repairs offline damage at a discount |
| `ROLE_SECURITY` | Security Guard | intercepts angry customers | mitigates incident losses |
| `ROLE_MANAGER` | Restaurant Manager | buffs morale, coordinates | sets the offline time cap |
| `ROLE_DELIVERY` | Delivery Worker | runs delivery orders | adds a delivery revenue stream |
| `ROLE_STOCKER` | Ingredient Stocker | restocks special ingredients | 5–15 % ingredient discount, auto-buys special stock within budget |
| `ROLE_ASST_MGR` | Assistant Manager | covers manager tasks | +2 h offline cap (requires a Manager), −20 % incident losses |

#### 36.1.5 Kitchen stations (summary; full specifications in §5)

| ID | Station | Kind | Available from |
|---|---|---|---|
| `STN_PANTRY` | Ingredient Storage (Pantry Shelf) | utility | starter kit |
| `STN_FRIDGE` | Refrigerator | utility | starter kit |
| `STN_FREEZER` | Freezer | utility + FREEZE | L5, TIER_02 |
| `STN_CUT` | Cutting Board | appliance (CHOP) | starter kit |
| `STN_PREP` | Preparation Counter | utility | starter kit |
| `STN_GRILL` | Grill | appliance (GRILL) | starter kit |
| `STN_FRYER` | Fryer | appliance (FRY) | starter kit |
| `STN_OVEN` | Oven | appliance (BAKE) | L3 |
| `STN_PIZZA_OVEN` | Pizza Oven | appliance (BAKE) | L3 |
| `STN_STOVE` | Stovetop | appliance (SAUTE, small BOIL) | L2 |
| `STN_SOUP_POT` | Soup Pot | appliance (BOIL/SIMMER) | L4 |
| `STN_STEAMER` | Steamer | appliance (STEAM) | L7, TIER_02 |
| `STN_BLENDER` | Blender | appliance (BLEND) | L5 |
| `STN_MIXER` | Mixer | appliance (MIX) | L5, TIER_02 |
| `STN_DRINK` | Drink Dispenser | appliance (POUR) | starter kit |
| `STN_ICECREAM` | Ice Cream Machine | appliance (SCOOP) | L4 |
| `STN_ASSEMBLY` | Food Assembly Counter | utility (ASSEMBLE) | starter kit |
| `STN_PLATING` | Plating Station | utility (PLATE) | L5, TIER_02 |
| `STN_WINDOW` | Serving Window | utility (hand-off) | starter kit |
| `STN_DISHWASH` | Dishwashing Station | utility (WASH) | starter kit |
| `STN_TRASH` | Trash Disposal | utility | starter kit |
| `STN_DELIVERY` | Ingredient Delivery Station | utility | starter kit |
| `STN_INFUSER` | Mutagen Infuser | appliance (INFUSE) | L40, TIER_06 |
| `STN_ANTIGRAV` | Anti-Gravity Wok | appliance (FLOAT) | L30, TIER_05 |

#### 36.1.6 Shared enumerations

| Enumeration | Values |
|---|---|
| Currencies | **MB** Morph Bucks (primary) · **MS** Mutation Shards · **RT** Research Tokens — no other currencies exist; Robux buys cosmetics only (§23) |
| Anatomy slots (22) | HEAD, FACE, NOSE, MOUTH, EYES, EARS, HORNS, NECK, TORSO, ARM_L, ARM_R, HANDS, LEG_L, LEG_R, FEET, TAIL, WINGS, BACK, SKIN, FUR, SCALES, FX (`ARM`/`LEG` parts fit either side) |
| Morph UI groups | Head (HEAD, FACE, NOSE, MOUTH) · Ears (EARS, HORNS) · Eyes · Arms (ARM_L, ARM_R, HANDS) · Legs (LEG_L, LEG_R, FEET) · Tails · Extras (NECK, TORSO, WINGS, BACK, SKIN, FUR, SCALES, FX) |
| Mutation categories (16) | MAMMAL, BIRD, REPTILE, AMPHIBIAN, FISH, INSECT, ARACHNID, MARINE, DINOSAUR, MYTHOLOGICAL, ROBOT, OBJECT, FOOD, PLANT, ALIEN, ELEMENTAL |
| Rarities (7) | Common ● gray · Uncommon ▲ green · Rare ■ blue · Epic ⬟ purple · Legendary ★ orange · Mythic ⬢ magenta · Secret ? rainbow-on-black (shape + color, never color alone) |
| Mutation tags (33) | chef, fighter, repair, speed, tank, charm, luck, fire, ice, electric, water, stinky, sticky, tentacle, claw, horn, flying, light, heavy, armored, aquatic, robotic, plant, alien, cosmic, glow, grabby, multi, loud, regen, tall, gold, sweet |
| Mutation acquisition codes | STARTER, SHOP_MART, SHOP_ROTATION, LAB_FUSION, CAPSULE, QUEST, EVENT, ARENA, OFFLINE_FIND, ACHIEVEMENT, SECRET |
| Ingredient tags (35) | bread, meat, poultry, seafood, cheese, dairy, veg, fruit, grain, noodle, sauce, spice, spicy, sweet, frozen, liquid, egg, fried, crunchy, round, square, pickle, tentacle, eyeball, slime, bug, alien, mutagen, glowing, legendary, gold, plant, nut, caffeine, fizzy |
| Preparation actions | CHOP, GRILL, FRY, BAKE, SAUTE, BOIL, STEAM, FREEZE, MIX, BLEND, POUR, SCOOP, ASSEMBLE, PLATE, SERVE, CLEAN, WASH, INFUSE, FLOAT |
| Ingredient states | RAW, CHOPPED, GRILLED, FRIED, BAKED, SAUTEED, BOILED, STEAMED, FROZEN, MIXED, BLENDED, POURED, SCOOPED, INFUSED, FLOATED; failures UNDERCOOKED, BURNED, ON_FIRE, MUSHY, SPILLED |
| Quality grades | PERFECT 1.00 · GOOD 0.80 · OK 0.60 · UNDERCOOKED 0.35 · BURNED 0.15 · RUINED 0.00 |
| Customer anger levels | 0 Happy · 1 Annoyed · 2 Complaining · 3 Throwing food · 4 Destroying furniture · 5 Fighting the player · 6 Restaurant-wide chaos |
| NPC combat styles | PACIFIST, THROWER, BRAWLER, CHARGER, TANK, TRICKSTER, INSTIGATOR |
| Damage states | Pristine (100–76 %) · Scuffed (75–51 %) · Cracked (50–26 %) · Broken (25–1 %) · Destroyed (0 %, auto-rebuild ≤ 25 % of price) |
| Quest types | TUT tutorial · STY story · DLY daily · WKY weekly · CHF cooking · CBT combat · RPR repair · EXP exploration · EMP employee management · RST restaurant expansion |
| Reward vocabulary | MB, MS, RT, XP, Morph Capsules, specific `MUT_` parts, recipe unlocks, trophy decorations (`FRN_901`–`FRN_910`), skill points, stat-respec tokens, titles, emotes, cosmetic color palettes |
| Player stats (9) | COOK_SPD, COOK_QLT, STR, DEF, REPAIR, MOVE, LUCK, CHARM, EFFICIENCY (formulas and caps in §14) |

#### 36.1.7 Cross-reference integrity

The validator treats an identifier in the first cell of a table row, or at the start of a heading, as that
entity's definition; every other occurrence is a reference. A build fails if any reference is unresolved, if a
canonical master-list entry is missing or renamed, if a required count falls below the brief's minimum, or if a
required diagram is missing. Run it after every content change:

```bash
python3 gdd/tools/validate_gdd.py          # human-readable report, exit code 1 on failure
python3 gdd/tools/build_gdd.py --render    # re-render data tables, validate, assemble the GDD
```
