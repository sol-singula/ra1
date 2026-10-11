### 36.5 Morph Combination Examples

> Contributor: A8. These rows are *examples* of the modular system in §12.9. The game never stores combinations;
> it derives them from equipped parts. Parts are canon `MUT_` IDs (details in §36.3), synergies are §36.4 IDs.

**How to read a row.**

- **Parts** lists every non-default part by anatomy slot. `ARM: X ×2` / `LEG: X ×2` puts the same part on both
  sides (a canon matched pair); `ARM_L`/`ARM_R`/`LEG_L` name a single side. Every unlisted `TORSO`, `ARM_*` or `LEG_*`
  holds the Plain Human default (`MUT_117`, `MUT_139`, `MUT_179`), which is neutral for naming and synergies.
- **Display name / Name type.** *generated* names come from the Name-o-Matic (lead family from the head plus the
  most visually dominant other family; Loud Prefix families go first). *signature* names come from the §12.9
  signature table. The **Morphdex key** (`Lead-Dominant`) is always generated and is what the Morphdex collects;
  it matches the hyphenated customer cards on the mockup.
- **Synergies triggered.** Every §36.4 synergy the parts qualify for. Plain IDs are active; IDs in parentheses are
  suppressed by the §12.10.3 rules (a stronger synergy of the same stacking group, or the 5-active limit with no
  pins). "—" means none.
- **Seen as:** customer, NPC, employee, player preset or player-only (Secret parts never appear on customers).

Every row is re-derived by `python3 gdd/tools/check_synergies.py`, which checks that the parts exist and are
slot-legal, that the key and display name match the algorithm (and that a combo matching a signature rule is
marked as one), and that the synergy list, including the active/suppressed split, is exactly what the parts trigger.

#### 36.5.1 Brief & Mockup Combinations

The brief's eight examples (Part 7.5) and the ten example customers on the mockup sheet. Display names come straight out of the §12.9 Name-o-Matic, so no row is hand-named.

| ID | Display name | Parts (slot: canon part; unlisted torso/arms/legs = Plain Human) | Name type (Morphdex key) | Role / vibe | Synergies triggered (active; (suppressed)) | Seen as |
|---|---|---|---|---|---|---|
| `CMB_001` | Scorpion Bear | HEAD: `MUT_001`; EARS: `MUT_086`; TAIL: `MUT_216` | generated (key `Bear-Scorpion`) | Brawny tail-swiper who growls at slow service; one of the mockup's example customers | — | customer (mockup card "Bear-Scorpion"; brief example) |
| `CMB_002` | Shark Spider | HEAD: `MUT_011`; MOUTH: `MUT_062`; LEG: `MUT_185` ×2 | generated (key `Shark-Spider`) | Skitters to the table on eight legs and chomps the menu | SYN_055 | customer (mockup card "Shark-Spider"; brief example) |
| `CMB_003` | Giraffe Squid | HEAD: `MUT_015`; NECK: `MUT_110`; ARM: `MUT_146` ×2 | generated (key `Giraffe-Squid`) | Reads the menu from the ceiling and grabs cutlery with tentacles; the silhouette Madame Fourchette (`NPC_016`) made famous | SYN_123 | customer (mockup card "Giraffe-Squid"; brief example) |
| `CMB_004` | TV Moth | HEAD: `MUT_021`; FACE: `MUT_045`; WINGS: `MUT_233` | generated (key `TV-Moth`) | Flutters at the neon sign and broadcasts its own order on its face | SYN_082, SYN_124 | customer (mockup card "TV-Moth"; brief example) — fits `PER_011` |
| `CMB_005` | Frog Robot | HEAD: `MUT_005`; TORSO: `MUT_123` | generated (key `Frog-Robot`) | Beeps, croaks, beeps again | — | customer (mockup card "Frog-Robot"; brief example) |
| `CMB_006` | Cat Fish | HEAD: `MUT_002`; EYES: `MUT_072`; TORSO: `MUT_119`; TAIL: `MUT_211` | generated (key `Cat-Fish`) | Orders fish, is fish, refuses to discuss it | SYN_052 | customer (mockup card "Cat-Fish"; brief example) |
| `CMB_007` | Axolotl Cow | HEAD: `MUT_014`; TORSO: `MUT_120` | generated (key `Axolotl-Cow`) | Gentle, moist, insists the milkshake is "personal" | — | customer (mockup card "Axolotl-Cow"; brief example) |
| `CMB_008` | Muscle Pigeon | HEAD: `MUT_004`; TORSO: `MUT_124`; ARM: `MUT_160` ×2 | generated (key `Pigeon-Muscle`) | Flexes at the pickles, coos at the bill | SYN_034 | customer (mockup card "Pigeon-Muscle"; brief example) — `PER_010` signature look |
| `CMB_009` | Snake Rabbit | HEAD: `MUT_020`; EARS: `MUT_085`; FEET: `MUT_202` | generated (key `Snake-Rabbit`) | Hisses politely, hops impatiently | — | customer (mockup card "Snake-Rabbit") |
| `CMB_010` | Deer Plant | HEAD: `MUT_013`; HORNS: `MUT_107`; ARM: `MUT_158` ×2 | generated (key `Deer-Plant`) | Photosynthesizes in the window seat; orders only salads | — | customer (mockup card "Deer-Plant") |
| `CMB_011` | Muscle Pigeon | HEAD: `MUT_004`; TORSO: `MUT_124` | generated (key `Pigeon-Muscle`) | Park-bench gossip with forearms of legend | — | NPC (`NPC_025` Old Man Pigeon) |

#### 36.5.2 Named NPC Looks

Fixed looks from §19 that are built entirely from canon parts. NPC-only props (monocle, crown, lab coat) are decoration and do not count.

| ID | Display name | Parts (slot: canon part; unlisted torso/arms/legs = Plain Human) | Name type (Morphdex key) | Role / vibe | Synergies triggered (active; (suppressed)) | Seen as |
|---|---|---|---|---|---|---|
| `CMB_012` | Kitchen Kaiju | HEAD: `MUT_031`; ARM: `MUT_165` ×2 | signature (key `Dragon-Kraken`) | The legendary chef; every player who copies her look earns the title | SYN_127 | NPC (`NPC_029` Chef Supreme Omnivora) |
| `CMB_013` | Le Fancy Fin | HEAD: `MUT_011`; TAIL: `MUT_219` | signature (key `Shark-Peacock`) | Snooty rival restaurateur; fans out his tail at every insult | — | NPC (`NPC_003` Baron Von Bistro, monocle is an NPC prop) |
| `CMB_014` | Pigeon Gorilla | HEAD: `MUT_004`; ARM: `MUT_148` ×2 | generated (key `Pigeon-Gorilla`) | Yells "FEEL THE BURN… OF THE GRILL!" | SYN_077 | NPC (`NPC_008` Coach Crunch) |
| `CMB_015` | Robot Spider | HEAD: `MUT_022`; LEG: `MUT_185` ×2 | generated (key `Robot-Spider`) | Climbs the walls to reach broken things first | SYN_083 | NPC (`NPC_010` Wrenchy) |
| `CMB_016` | Axolotl Robot | HEAD: `MUT_014`; ARM_R: `MUT_147` | generated (key `Axolotl-Robot`) | Lab scientist; robot arm for the dangerous stirring | — | NPC (`NPC_013` Dr. Splice, lab coat is an NPC prop) |
| `CMB_017` | Sewer Royalty | HEAD: `MUT_006`; ARM: `MUT_144` ×2 | signature (key `Rat-Crab`) | Borrows ingredients, never returns them | SYN_037 | NPC (`NPC_020` King Ratbeard, crown is an NPC prop) |

#### 36.5.3 Employee Looks

Representative employee bodies, including the brief's employee examples (§11.2 of the brief) and `EMP_001`. Archetype stats and traits are defined in §36.8; synergies never change employee numbers (§12.10.6).

| ID | Display name | Parts (slot: canon part; unlisted torso/arms/legs = Plain Human) | Name type (Morphdex key) | Role / vibe | Synergies triggered (active; (suppressed)) | Seen as |
|---|---|---|---|---|---|---|
| `CMB_018` | Octopus Chef | HEAD: `MUT_029`; HORNS: `MUT_102`; ARM: `MUT_145` ×2 | generated (key `Octopus-Chef`) | Eight arms, one brain cell, five pickles too many | SYN_001, SYN_031, (SYN_005) | employee (`EMP_001` Ollie the Octopus Intern, `ROLE_CHEF`) |
| `CMB_019` | Cat Cheetah | HEAD: `MUT_002`; LEG: `MUT_186` ×2; FEET: `MUT_204` | generated (key `Cat-Cheetah`) | Delivers soup before you finish ordering it | SYN_096, SYN_102 | employee (brief's Cheetah Waiter, `ROLE_WAITER`) |
| `CMB_020` | Bear Rhino | HEAD: `MUT_001`; HORNS: `MUT_099`; TORSO: `MUT_118`; ARM: `MUT_140` ×2; LEG: `MUT_182` ×2 | generated (key `Bear-Rhino`) | Stands at the door looking unbudgeable | SYN_002, SYN_056, SYN_060, SYN_061, (SYN_033) | employee (brief's Rhino Security Guard, `ROLE_SECURITY`) |
| `CMB_021` | Spider Robot | HEAD: `MUT_028`; TORSO: `MUT_123`; ARM_L: `MUT_150`; ARM_R: `MUT_153`; LEG: `MUT_185` ×2 | generated (key `Spider-Robot`) | Climbs, welds and tidies with eight legs and a wrench | SYN_003, SYN_083, SYN_086, SYN_091 | employee (brief's Spider Repair Technician, `ROLE_REPAIR`) |
| `CMB_022` | Beep Boop Supreme | HEAD: `MUT_022`; FACE: `MUT_044`; EARS: `MUT_092`; TORSO: `MUT_123`; ARM: `MUT_147` ×2; LEG: `MUT_187` ×2 | signature (key `Robot`) | Counts change to the third decimal, then apologizes | SYN_027, SYN_084, SYN_088, SYN_130 | employee (brief's Robot Cashier, `ROLE_CASHIER`) — fits `PER_015` too |
| `CMB_023` | Hydrant Turtle | HEAD: `MUT_019`; NOSE: `MUT_056`; TORSO: `MUT_122` | generated (key `Hydrant-Turtle`) | Slow, cheap, permanently damp; the canon has no sloth part, so this is the stand-in for the brief's Sloth Dishwasher | SYN_023 | employee (`ROLE_DISH`) |
| `CMB_024` | Dragon Chef | HEAD: `MUT_031`; HORNS: `MUT_102`; SKIN: `MUT_254` | generated (key `Dragon-Chef`) | Excellent at grilling, occasionally grills the order ticket | SYN_004, (SYN_006) | employee (brief's Dragon Chef, `ROLE_CHEF`) |
| `CMB_025` | Chicken Bee | HEAD: `MUT_008`; TORSO: `MUT_126`; ARM: `MUT_167` ×2; WINGS: `MUT_236` | generated (key `Chicken-Bee`) | Buzzes between cutting boards | SYN_021 | employee (`ROLE_PREP`) |
| `CMB_026` | Sir Hoots-a-Lot | HEAD: `MUT_016`; FACE: `MUT_047`; EYES: `MUT_074` | signature (key `Owl-Mustache`) | Reviews the books at midnight, hoots at waste | — | employee (`ROLE_MANAGER`) |
| `CMB_027` | Dog Penguin | HEAD: `MUT_003`; TORSO: `MUT_125`; FEET: `MUT_207` | generated (key `Dog-Penguin`) | Glides between tables on ice skates | — | employee (`ROLE_WAITER`) |
| `CMB_028` | Pigeon Ostrich | HEAD: `MUT_004`; LEG: `MUT_188` ×2; FEET: `MUT_204`; WINGS: `MUT_235` | generated (key `Pigeon-Ostrich`) | Never takes the stairs, never drops a box | SYN_096 | employee (`ROLE_DELIVERY`) |
| `CMB_029` | Rat Spider | HEAD: `MUT_006`; MOUTH: `MUT_066`; ARM: `MUT_150` ×2 | generated (key `Rat-Spider`) | Inhales crumbs, webs up spills | SYN_083, SYN_090 | employee (`ROLE_CLEANER`) |
| `CMB_030` | Crocodile Crab | HEAD: `MUT_023`; TORSO: `MUT_127`; ARM: `MUT_152` ×2; BACK: `MUT_246` | generated (key `Crocodile-Crab`) | Pinches troublemakers (gently) out the door | SYN_037, SYN_038 | employee (`ROLE_SECURITY`) |
| `CMB_031` | Robot Extinguisher | HEAD: `MUT_022`; TORSO: `MUT_123`; ARM: `MUT_153` ×2; HANDS: `MUT_174`; BACK: `MUT_250` | generated (key `Robot-Extinguisher`) | Fixes the fryer, then foams it just in case | SYN_037, SYN_084, SYN_086, SYN_088 | employee (`ROLE_REPAIR`) |
| `CMB_032` | Rat Monkey | HEAD: `MUT_006`; NOSE: `MUT_049`; TAIL: `MUT_217`; BACK: `MUT_249` | generated (key `Rat-Monkey`) | Carries three crates and a grudge | — | employee (`ROLE_STOCKER`) |
| `CMB_033` | Fly Robot | HEAD: `MUT_027`; FACE: `MUT_044`; EYES: `MUT_073` | generated (key `Fly-Robot`) | Sees every mistake from every angle | — | employee (`ROLE_ASST_MGR`) |

#### 36.5.4 Player Presets & Loadout Builds

Starter morph, the three tutorial picks, and representative Chef / Fighter / Repair loadouts across the level curve (§13 loadouts).

| ID | Display name | Parts (slot: canon part; unlisted torso/arms/legs = Plain Human) | Name type (Morphdex key) | Role / vibe | Synergies triggered (active; (suppressed)) | Seen as |
|---|---|---|---|---|---|---|
| `CMB_034` | Just a Cat | HEAD: `MUT_002` | generated (key `Cat`) | The day-one look: one random Common head on Plain Human parts | — | player preset (default starter morph) |
| `CMB_035` | Dog Octopus | HEAD: `MUT_003`; ARM_L: `MUT_145` | generated (key `Dog-Octopus`) | First mutation, Chef pick (`QST_TUT_010`) | — | player preset (tutorial Chef choice) |
| `CMB_036` | Bear Crab | HEAD: `MUT_001`; ARM_L: `MUT_144` | generated (key `Bear-Crab`) | First mutation, Fighter pick (`QST_TUT_010`) | — | player preset (tutorial Fighter choice) |
| `CMB_037` | Rat Robot | HEAD: `MUT_006`; ARM_L: `MUT_153` | generated (key `Rat-Robot`) | First mutation, Repair pick (`QST_TUT_010`) | — | player preset (tutorial Repair choice) |
| `CMB_038` | Chicken Octopus | HEAD: `MUT_008`; HORNS: `MUT_102`; TORSO: `MUT_121`; ARM: `MUT_145` ×2; HANDS: `MUT_171` | generated (key `Chicken-Octopus`) | Early Chef Loadout (~L12): two-station multitasker | SYN_001, SYN_010, (SYN_005) | player preset (Chef Loadout, early) |
| `CMB_039` | Dragon Octopus | HEAD: `MUT_031`; MOUTH: `MUT_069`; HORNS: `MUT_102`; TORSO: `MUT_131`; ARM: `MUT_145` ×2; HANDS: `MUT_176`; BACK: `MUT_249`; SKIN: `MUT_254` | generated (key `Dragon-Octopus`) | Mid-game Chef Loadout (~L35): exactly five active synergies | SYN_001, SYN_004, SYN_009, SYN_011, SYN_049, (SYN_005), (SYN_006), (SYN_008), (SYN_010) | player preset (Chef Loadout, mid) |
| `CMB_040` | His Royal Snackness | HEAD: `MUT_039`; FACE: `MUT_047`; NOSE: `MUT_058`; MOUTH: `MUT_069`; HORNS: `MUT_102`; TORSO: `MUT_136`; ARM: `MUT_168` ×2; HANDS: `MUT_178`; TAIL: `MUT_217`; BACK: `MUT_249`; SKIN: `MUT_258` | signature (key `Burger-Cosmic`) | End-game Chef Loadout; more synergies than slots, so pins matter | SYN_011, SYN_015, SYN_017, SYN_029, SYN_030, (SYN_010), (SYN_016), (SYN_028), (SYN_107), (SYN_127), (SYN_128) | player preset (Chef Loadout, end-game) |
| `CMB_041` | Scorpion Bear | HEAD: `MUT_001`; HORNS: `MUT_099`; TORSO: `MUT_118`; ARM: `MUT_140` ×2; LEG: `MUT_184` ×2; TAIL: `MUT_216` | generated (key `Bear-Scorpion`) | Fighter Loadout (~L15): knockback brawler | SYN_002, SYN_054, SYN_060, SYN_062, (SYN_033), (SYN_061) | player preset (Fighter Loadout, early) |
| `CMB_042` | Dragon T-Rex | HEAD: `MUT_032`; MOUTH: `MUT_067`; EYES: `MUT_076`; HORNS: `MUT_108`; TORSO: `MUT_124`; ARM_L: `MUT_163`; ARM_R: `MUT_164`; LEG: `MUT_194` ×2; TAIL: `MUT_227`; WINGS: `MUT_240` | generated (key `T-Rex-Dragon`) | Fighter Loadout (~L45): all offense, zero armor | SYN_046, SYN_060, SYN_062, SYN_067, SYN_127, (SYN_061) | player preset (Fighter Loadout, late) |
| `CMB_043` | Crocodile Umbrella | HEAD: `MUT_023`; NECK: `MUT_109`; TORSO: `MUT_135`; ARM: `MUT_157` ×2; HANDS: `MUT_169`; LEG: `MUT_189` ×2; FEET: `MUT_205`; BACK: `MUT_246`; SCALES: `MUT_269` | generated (key `Crocodile-Umbrella`) | Tank build that blocks thrown food with umbrellas | SYN_034, SYN_057, SYN_058, (SYN_056) | player preset (Fighter Loadout, tank variant) |
| `CMB_044` | Robot Spider | HEAD: `MUT_022`; NOSE: `MUT_054`; MOUTH: `MUT_060`; TORSO: `MUT_123`; ARM_L: `MUT_150`; ARM_R: `MUT_153`; HANDS: `MUT_174`; LEG: `MUT_185` ×2; TAIL: `MUT_218`; BACK: `MUT_250` | generated (key `Robot-Spider`) | Repair Loadout (~L25): scuttles from scuff to scuff | SYN_003, SYN_083, SYN_085, SYN_087, SYN_088, (SYN_086), (SYN_091) | player preset (Repair Loadout) |
| `CMB_045` | Wolf Kangaroo | HEAD: `MUT_012`; EARS: `MUT_090`; TORSO: `MUT_119`; ARM: `MUT_149` ×2; LEG: `MUT_186` ×2; FEET: `MUT_204`; TAIL: `MUT_226` | generated (key `Wolf-Kangaroo`) | Speed build for delivery runs | SYN_051, SYN_054, SYN_096, SYN_097 | player preset (earnable loadout slot 4) |
| `CMB_046` | Shark Mantis | HEAD: `MUT_011`; MOUTH: `MUT_062`; ARM: `MUT_151` ×2; LEG: `MUT_194` ×2 | generated (key `Shark-Mantis`) | Arena glass cannon | SYN_055, SYN_060, SYN_061 | player preset (Arena loadout) |
| `CMB_047` | Deer Utensil | HEAD: `MUT_013`; FACE: `MUT_047`; MOUTH: `MUT_063`; EARS: `MUT_085`; HORNS: `MUT_102`; ARM: `MUT_156` ×2 | generated (key `Deer-Utensil`) | Front-of-house charmer who also flips burgers | SYN_010, SYN_016, SYN_115 | player preset (service build) |
| `CMB_048` | Hydrant Robot | HEAD: `MUT_019`; NOSE: `MUT_053`; TORSO: `MUT_123`; ARM: `MUT_153` ×2; BACK: `MUT_250` | generated (key `Hydrant-Robot`) | Fire-safety specialist for the Hot Sauce Heatwave (`EVT_019`) | SYN_037, SYN_084, SYN_089, (SYN_023) | player preset (Repair Loadout variant) |
| `CMB_049` | Pizza Dog | HEAD: `MUT_003`; FACE: `MUT_042`; NOSE: `MUT_052`; EYES: `MUT_071`; EARS: `MUT_087`; TORSO: `MUT_136`; HANDS: `MUT_178`; TAIL: `MUT_212`; WINGS: `MUT_235`; SKIN: `MUT_255` | generated (key `Dog-Pizza`) | Jackpot hunter: every lucky part at once | SYN_108, SYN_110, (SYN_107) | player preset (luck build) |
| `CMB_050` | Pigeon Chicken | HEAD: `MUT_004`; TORSO: `MUT_121`; LEG: `MUT_180` ×2; WINGS: `MUT_235` | generated (key `Pigeon-Chicken`) | Glides plates over the counter | SYN_024, SYN_098 | player preset (waiter build) |
| `CMB_051` | Just a Bear | HEAD: `MUT_001`; EARS: `MUT_086`; TORSO: `MUT_118`; ARM: `MUT_140` ×2; HANDS: `MUT_169`; LEG: `MUT_182` ×2; FUR: `MUT_259` | generated (key `Bear`) | Committed to the bear bit | SYN_056, SYN_061, SYN_130 | player preset (Purebred showcase) |
| `CMB_052` | Octopus Fish | HEAD: `MUT_029`; TORSO: `MUT_119`; ARM: `MUT_145` ×2; FEET: `MUT_201` | generated (key `Octopus-Fish`) | Sushi specialist | SYN_001, SYN_025, SYN_031, (SYN_005) | player preset (Chef Loadout, seafood menu) |
| `CMB_053` | Pumpkin Tree | HEAD: `MUT_018`; LEG: `MUT_193` ×2; FEET: `MUT_209`; FUR: `MUT_263` | generated (key `Pumpkin-Tree`) | Stands in the sun between rushes to heal | SYN_081, SYN_118, (SYN_080) | player preset (Repair Loadout, outdoor) |

#### 36.5.5 Customers, Events & Show-Offs

Procedurally assembled customers (§12.9.5 recipe), event guests and secret-part show-offs. "Fits `PER_…`" means the body suits that personality; personalities define behavior, not bodies (except signature looks set in §9).

| ID | Display name | Parts (slot: canon part; unlisted torso/arms/legs = Plain Human) | Name type (Morphdex key) | Role / vibe | Synergies triggered (active; (suppressed)) | Seen as |
|---|---|---|---|---|---|---|
| `CMB_054` | Ghost Toaster | HEAD: `MUT_010`; BACK: `MUT_252` | generated (key `Toaster-Ghost`) | Pops out toast when spooked; often haunts booth 3 | — | customer — fits `PER_028` |
| `CMB_055` | Pumpkin Bat | HEAD: `MUT_018`; EARS: `MUT_089`; WINGS: `MUT_234` | generated (key `Pumpkin-Bat`) | Seasonal regular during Haunted Kitchen Night (`EVT_029`) | — | customer (event) |
| `CMB_056` | Muscle Broccoli | HEAD: `MUT_030`; ARM: `MUT_160` ×2 | generated (key `Broccoli-Muscle`) | Leg day was skipped for arm day was skipped for salad | — | customer |
| `CMB_057` | Lava Golem | HEAD: `MUT_034`; TORSO: `MUT_135` | generated (key `Lava-Golem`) | Warms the booth to medium-rare | — | customer |
| `CMB_058` | Alien Cow | HEAD: `MUT_033`; TORSO: `MUT_120` | generated (key `Alien-Cow`) | Takes photos of the napkins | — | customer — fits `PER_029` |
| `CMB_059` | Fly Chicken | HEAD: `MUT_027`; LEG: `MUT_180` ×2; WINGS: `MUT_231` | generated (key `Fly-Chicken`) | Buzzes, clucks, demands extra crumbs | SYN_024 | customer |
| `CMB_060` | Lizard Turtle | HEAD: `MUT_017`; NECK: `MUT_109`; TORSO: `MUT_122`; BACK: `MUT_244` | generated (key `Lizard-Turtle`) | Arrived yesterday for tomorrow's lunch | — | customer — fits `PER_024` |
| `CMB_061` | Accidental Platypus | HEAD: `MUT_006`; MOUTH: `MUT_059`; TAIL: `MUT_218` | signature (key `Rat-Beaver`) | Picky about everything, especially classification | — | customer — fits `PER_014` |
| `CMB_062` | Turtducken | HEAD: `MUT_008`; MOUTH: `MUT_059`; TORSO: `MUT_122` | signature (key `Chicken-Turtle`) | Three animals in a trench coat of shell | — | customer |
| `CMB_063` | Kitchen Chimera | HEAD: `MUT_002`; HORNS: `MUT_097`; TAIL: `MUT_222` | signature (key `Cat-Snake`) | Purrs, bleats and rattles, in that order | — | customer |
| `CMB_064` | Discount Griffin | HEAD: `MUT_002`; HANDS: `MUT_172`; WINGS: `MUT_235` | signature (key `Cat-Pigeon`) | Swoops onto the counter for leftovers | — | customer |
| `CMB_065` | Mer-Waiter | HEAD: `MUT_003`; TAIL: `MUT_225` | signature (key `Dog-Mermaid`) | Flops to the table, tips in sea shells (converted to MB) | — | customer |
| `CMB_066` | Ceiling Inspector | HEAD: `MUT_015`; NECK: `MUT_114`; ARM: `MUT_143` ×2 | signature (key `Giraffe-Noodle`) | Has to duck through the doorway, still bonks the sign | SYN_020, SYN_123 | customer |
| `CMB_067` | Dragon Lizard | HEAD: `MUT_017`; TAIL: `MUT_227`; SKIN: `MUT_254` | generated (key `Lizard-Dragon`) | Orders everything extra spicy | — | customer — fits `PER_022` |
| `CMB_068` | Fish Yeti | HEAD: `MUT_009`; FUR: `MUT_262` | generated (key `Fish-Yeti`) | Wants the soup frozen, the ice cream hot | — | customer — fits `PER_023` |
| `CMB_069` | Muscle Dog | HEAD: `MUT_003`; MOUTH: `MUT_064`; TORSO: `MUT_124` | generated (key `Dog-Muscle`) | Retired from the ring, not from flexing | — | customer — fits `PER_030` |
| `CMB_070` | Pumpkin Golem | HEAD: `MUT_018`; TORSO: `MUT_135`; FUR: `MUT_260` | generated (key `Pumpkin-Golem`) | Knits a sweater for the table | — | customer — fits `PER_013` |
| `CMB_071` | Microwave Robot | HEAD: `MUT_036`; TORSO: `MUT_123` | generated (key `Microwave-Robot`) | Audits the receipt while reheating it | — | customer |
| `CMB_072` | Just a Mantis | HEAD: `MUT_026`; ARM: `MUT_151` ×2 | generated (key `Mantis`) | Orders in mime; you must guess "pizza" | — | customer — fits `PER_019` |
| `CMB_073` | Pigeon Crab | HEAD: `MUT_004`; ARM: `MUT_144` ×2; TAIL: `MUT_221` | generated (key `Pigeon-Crab`) | Says "arr", means "one large fries" | SYN_037 | customer — fits `PER_017` |
| `CMB_074` | Pigeon Jellyfish | HEAD: `MUT_004`; TORSO: `MUT_130` | generated (key `Pigeon-Jellyfish`) | Half of a very glowy couple | — | customer — fits `PER_027` |
| `CMB_075` | Rat Fox | HEAD: `MUT_006`; LEG: `MUT_180` ×2; TAIL: `MUT_226` | generated (key `Rat-Fox`) | Eats in 4.2 seconds, posts the time | — | customer — fits `PER_026` |
| `CMB_076` | Cat Peacock | HEAD: `MUT_002`; TAIL: `MUT_219`; SCALES: `MUT_270` | generated (key `Cat-Peacock`) | Rates your plating on a glittery scale | — | customer — fits `PER_009` |
| `CMB_077` | Bear T-Rex | HEAD: `MUT_001`; TORSO: `MUT_135`; ARM: `MUT_161` ×2 | generated (key `Bear-T-Rex`) | Enormous, adorable, cannot reach the table | — | customer — fits `PER_020` |
| `CMB_078` | Pizza Bear | HEAD: `MUT_001`; NOSE: `MUT_051`; TORSO: `MUT_136` | generated (key `Bear-Pizza`) | It's their birthday (it is always their birthday) | — | customer — fits `PER_031` |
| `CMB_079` | Rat Cactus | HEAD: `MUT_006`; NOSE: `MUT_057`; TORSO: `MUT_132` | generated (key `Rat-Cactus`) | Asks if the cactus is gluten-free | — | customer — fits `PER_021` |
| `CMB_080` | Demon Deer | HEAD: `MUT_013`; HORNS: `MUT_108` | generated (key `Deer-Demon`) | Says "please" with terrifying sincerity | — | customer — fits `PER_003` |
| `CMB_081` | T-Rex Megaphone | HEAD: `MUT_032`; MOUTH: `MUT_068` | generated (key `T-Rex-Megaphone`) | WOULD LIKE TO SPEAK TO THE MANAGER | — | customer — fits `PER_001` |
| `CMB_082` | Mustache Owl | HEAD: `MUT_016`; FACE: `MUT_047`; EYES: `MUT_079` | generated (key `Owl-Mustache`) | Takes notes on a tiny notepad, judges the font | — | customer — fits `PER_004` |
| `CMB_083` | Frog Fox | HEAD: `MUT_005`; EARS: `MUT_090` | generated (key `Frog-Fox`) | Taps foot at 4 taps per second | — | customer — fits `PER_005` |
| `CMB_084` | Rat Bat | HEAD: `MUT_006`; EARS: `MUT_089`; WINGS: `MUT_234` | generated (key `Rat-Bat`) | Unscrews salt shakers "for science" | — | customer — fits `PER_007` |
| `CMB_085` | Golden Cat | HEAD: `MUT_002`; HANDS: `MUT_178`; SKIN: `MUT_258` | generated (key `Cat-Golden`) | Tips in gold leaf (converted to MB) | SYN_017 | customer — fits `PER_008` |
| `CMB_086` | Axolotl Frog | HEAD: `MUT_014`; LEG: `MUT_181` ×2 | generated (key `Axolotl-Frog`) | Flinches at the bell, apologizes to it | SYN_105 | customer — fits `PER_012` |
| `CMB_087` | Giraffe Sheep | HEAD: `MUT_015`; FUR: `MUT_260` | generated (key `Giraffe-Sheep`) | Gasps at every special | — | customer — fits `PER_018` |
| `CMB_088` | Owl Raccoon | HEAD: `MUT_016`; FACE: `MUT_042` | generated (key `Owl-Raccoon`) | Definitely not an inspector (is an inspector) | — | customer — fits `PER_025` |
| `CMB_089` | Bear Spider | HEAD: `MUT_001`; LEG: `MUT_185` ×2 | generated (key `Bear-Spider`) | Orders the entire left side of the menu | — | customer — fits `PER_002` |
| `CMB_090` | Just an Alien | HEAD: `MUT_033`; ARM_R: `MUT_166`; FEET: `MUT_210` | generated (key `Alien`) | Tourist who floats an inch above the chair | SYN_126, SYN_127 | customer — fits `PER_029`; seen during `EVT_018` |
| `CMB_091` | Hammerhead Robot | HEAD: `MUT_025`; WINGS: `MUT_239` | generated (key `Hammerhead-Robot`) | Hovers over the queue like a traffic report | — | customer |
| `CMB_092` | Kraken Pizza | HEAD: `MUT_038`; TORSO: `MUT_136` | generated (key `Kraken-Pizza`) | Delivers its own order by mistake | — | customer |
| `CMB_093` | Phoenix Pigeon | HEAD: `MUT_004`; WINGS: `MUT_242` | generated (key `Pigeon-Phoenix`) | The fanciest pigeon in the park | — | customer |
| `CMB_094` | Crocodile Skater | HEAD: `MUT_023`; FEET: `MUT_204` | generated (key `Crocodile-Skater`) | Rolls in, rolls out, leaves skid marks of sauce | — | customer |
| `CMB_095` | Goat Pogo | HEAD: `MUT_007`; LEG: `MUT_191` ×2 | generated (key `Goat-Pogo`) | Boings through the queue | SYN_100 | customer |
| `CMB_096` | Pigeon Flamingo | HEAD: `MUT_004`; NECK: `MUT_111` | generated (key `Pigeon-Flamingo`) | Balances on one leg while ordering | — | customer |
| `CMB_097` | Microwave Octopus | HEAD: `MUT_036`; ARM: `MUT_145` ×2 | generated (key `Microwave-Octopus`) | Cooks its own leftovers at the table | SYN_001, (SYN_005) | customer |
| `CMB_098` | Shark Bee | HEAD: `MUT_011`; TORSO: `MUT_126`; WINGS: `MUT_236` | generated (key `Shark-Bee`) | Buzzing menace, sweet tooth | SYN_021 | customer |
| `CMB_099` | Octopus Cow | HEAD: `MUT_029`; TORSO: `MUT_120` | generated (key `Octopus-Cow`) | Eight-way milkshake | — | customer |
| `CMB_100` | Glitchy Cat | HEAD: `MUT_040`; TAIL: `MUT_211`; FX: `MUT_276` | generated (key `Glitchy-Cat`) | Flickers between frames; nobody remembers it walking in | SYN_131 | player (Secret parts never appear on customers) |
| `CMB_101` | Cat Unicorn | HEAD: `MUT_002`; HORNS: `MUT_101`; FX: `MUT_272` | generated (key `Cat-Unicorn`) | Sparkles constantly, purrs majestically | — | customer |
| `CMB_102` | Owl Penguin | HEAD: `MUT_016`; TORSO: `MUT_125`; FUR: `MUT_262` | generated (key `Owl-Penguin`) | Orders hot cocoa in a blizzard | — | customer |
| `CMB_103` | Cat Eel | HEAD: `MUT_002`; ARM: `MUT_159` ×2; SKIN: `MUT_253` | generated (key `Cat-Eel`) | Static on every handshake | SYN_043 | customer |
| `CMB_104` | Stormy Frog | HEAD: `MUT_005`; EYES: `MUT_081`; TAIL: `MUT_230`; FUR: `MUT_264` | generated (key `Frog-Stormy`) | Brings its own weather to brunch | SYN_042, SYN_045, SYN_050 | customer |
| `CMB_105` | Frosty Rat | HEAD: `MUT_006`; ARM_L: `MUT_162`; HANDS: `MUT_176` | generated (key `Rat-Frosty`) | Freezes the cheese, then complains it's cold | SYN_008 | customer |
| `CMB_106` | Blazing Chicken | HEAD: `MUT_008`; SKIN: `MUT_254` | generated (key `Chicken-Blazing`) | Clucks at the grill like a coworker | — | customer |
| `CMB_107` | Holo Snake | HEAD: `MUT_020`; SCALES: `MUT_270` | generated (key `Snake-Holo`) | Reflects the disco lights | — | customer |
| `CMB_108` | Slimy Frog | HEAD: `MUT_005`; TORSO: `MUT_134` | generated (key `Frog-Slimy`) | Leaves a jelly trail to the restroom | SYN_106 | customer |
| `CMB_109` | Ghost Dog | HEAD: `MUT_003`; BACK: `MUT_252` | generated (key `Dog-Ghost`) | Wags a sheet; asks for "boo-berry" pie | — | customer |
| `CMB_110` | Giraffe Accordion | HEAD: `MUT_015`; NECK: `MUT_112` | generated (key `Giraffe-Accordion`) | Wheezes a polka every time it nods | SYN_123 | player (Secret neck) |
| `CMB_111` | Chicken Noodle | HEAD: `MUT_008`; NECK: `MUT_116` | generated (key `Chicken-Noodle`) | Comforting, oddly soup-shaped | — | player (Secret neck) |
| `CMB_112` | Paper Pigeon | HEAD: `MUT_004`; WINGS: `MUT_237` | generated (key `Pigeon-Paper`) | Folded from a menu, tips in origami | — | player (Secret wings) |
| `CMB_113` | Hydrant Fridge | HEAD: `MUT_019`; TORSO: `MUT_131` | generated (key `Hydrant-Fridge`) | Ice and water on tap | — | customer |
| `CMB_114` | Frog Mushroom | HEAD: `MUT_005`; BACK: `MUT_248` | generated (key `Frog-Mushroom`) | Smells faintly of forest | — | customer |
| `CMB_115` | Ninetail Maître d' | HEAD: `MUT_002`; EARS: `MUT_090`; TAIL: `MUT_229` | signature (key `Cat-Ninetail`) | Seats you with nine-tailed elegance | — | customer (rare, `TIER_07`+) |
| `CMB_116` | Shark Robot | HEAD: `MUT_011`; BACK: `MUT_245` | generated (key `Shark-Robot`) | Shark with a jetpack, which explains a lot | — | customer |
| `CMB_117` | Octopus Unicycle | HEAD: `MUT_029`; LEG_L: `MUT_192` | generated (key `Octopus-Unicycle`) | One wheel, seven questions | — | customer |
| `CMB_118` | Literally a Hot Dog | HEAD: `MUT_003`; SKIN: `MUT_254` | signature (key `Dog-Blazing`) | The pun walks among us | — | customer |
| `CMB_119` | Fly Sea-Slug | HEAD: `MUT_027`; EYES: `MUT_075` | generated (key `Fly-Sea-Slug`) | Waves its eye-stalks at the dessert case | — | customer |
| `CMB_120` | Golden Chicken | HEAD: `MUT_008`; SKIN: `MUT_258` | generated (key `Chicken-Golden`) | Lays golden tips (converted to MB) | — | customer |
| `CMB_121` | Just a Burger | HEAD: `MUT_039` | generated (key `Burger`) | A burger ordering a burger | — | player (Mythic head; Mythic parts appear on customers only at `TIER_07`+) |
| `CMB_122` | The Full Kraken | HEAD: `MUT_038`; TORSO: `MUT_137`; ARM: `MUT_165` ×2 | signature (key `Kraken`) | Takes up three booths, tips in pearls | SYN_031, SYN_072, SYN_128, (SYN_127) | customer (`EVT_022` Lost Pet Kraken guest star) |
| `CMB_123` | Just a Phoenix | HEAD: `MUT_037`; LEG: `MUT_200` ×2; WINGS: `MUT_242` | generated (key `Phoenix`) | Bursts into (cartoon) flames when happy | SYN_053, SYN_079, SYN_080, SYN_128, (SYN_127) | player (Legendary/Mythic showcase) |
| `CMB_124` | Absolute Mystery | HEAD: `MUT_021`; EYES: `MUT_076`; EARS: `MUT_085`; TORSO: `MUT_119`; ARM_L: `MUT_145`; ARM_R: `MUT_162`; LEG_L: `MUT_180`; FEET: `MUT_210`; TAIL: `MUT_215`; WINGS: `MUT_232` | signature (key `TV-Butterfly`) | Ten categories, one confused chair | SYN_129 | customer — fits `PER_032` |
| `CMB_125` | Walking Salad Bar | HEAD: `MUT_035`; EARS: `MUT_093`; TORSO: `MUT_132`; ARM: `MUT_158` ×2; HANDS: `MUT_177`; BACK: `MUT_248` | signature (key `Flytrap-Plant`) | Customers keep reaching for croutons | SYN_076, SYN_078, SYN_118 | customer (`EVT_031` Spring Sprout Bloom) |
| `CMB_126` | Broccoli Bee | HEAD: `MUT_030`; EYES: `MUT_080`; TORSO: `MUT_126` | generated (key `Broccoli-Bee`) | Brings its own honey for the broccoli | SYN_022 | customer |
| `CMB_127` | Rat Skunk | HEAD: `MUT_006`; TAIL: `MUT_220`; BACK: `MUT_251` | generated (key `Rat-Skunk`) | Clears the queue without trying | SYN_065 | customer |
| `CMB_128` | Shark Pufferfish | HEAD: `MUT_011`; TORSO: `MUT_129`; BACK: `MUT_243` | generated (key `Shark-Pufferfish`) | Puffs up when the bill arrives | SYN_040 | customer |
| `CMB_129` | T-Rex Stegosaurus | HEAD: `MUT_032`; TORSO: `MUT_133`; LEG: `MUT_194` ×2; TAIL: `MUT_223` | generated (key `T-Rex-Stegosaurus`) | Swings its tail at the dessert cart | SYN_061, SYN_067, SYN_127 | customer |
| `CMB_130` | Muscle Gorilla | HEAD: `MUT_024`; HORNS: `MUT_100`; TORSO: `MUT_124`; ARM: `MUT_148` ×2 | generated (key `Gorilla-Muscle`) | Breaks the door, apologizes, pays for the door | SYN_033, SYN_060, SYN_061, SYN_070, SYN_077, (SYN_034) | customer |

#### 36.5.6 Summary

| Measure | Value |
|---|---|
| Combinations listed | 130 (minimum required: 100 brief / 110 canon target) |
| Generated / signature names | 113 / 17 (every one of the 17 signature titles is shown at least once) |
| Distinct Morphdex keys shown | 126 of 5,292 possible |
| Seen as customer / NPC / employee / player preset / player-only | 81 / 7 / 16 / 20 / 6 |
| Rows with ≥ 1 synergy / with ≥ 3 synergies | 61 / 26 |
| "Just a …" (single-family) examples | 6 |
