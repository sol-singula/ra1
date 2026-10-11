### 36.16 Achievements Database

> Rules live in §14 (XP Unit **XPU**, §14.3; reward granting, §14.18). Checked by
> `python3 gdd/tools/render_progression.py --check` (IDs, categories, C17.4 reward vocabulary, skill-point totals).

**Rules & Mechanics.**

- **Tracking.** Every condition reads a server-side counter in the profile (`achievements.counters`, §28.9.12; flags are
  0/1 counters), advanced only by server services through `ProgressionService.IncrementCounter` / `SetFlag` — never by a
  client remote.
  Bracketed keys (e.g. `served_recipe[RCP_BRG_001]`) are maps keyed by ID. Counters start at 0 at account creation and
  are lifetime unless the condition says "in a row", "at once" or "within".
- **Unlocking.** Evaluated on every counter change; an unlock is recorded once (`achievements.unlocked[ID] = timestamp`). The toast
  follows §C22 E14 (no modal, never interrupts cooking); the Achievements journal (Quest Journal tab, §24) lists categories,
  progress bars (`current / target`) and unlock dates.
- **Hidden achievements** ("Hidden? = Yes") show as "??? — a secret in the *Category* tab" with no condition text until
  unlocked; secret-mutation achievements unlock together with the discovery that grants the part (§C13.8), so their
  reward never includes the part itself.
- **Rewards** use only the canon §C17.4 vocabulary and are granted automatically by `ProgressionService.UnlockAchievement`
  (§27.8.19), idempotent by achievement ID. XP is written as **XP n XPU** (converted at the player's level when granted). Duplicate
  mutation parts follow the canon duplicate rule (§C4.7: auto-convert to MS unless kept for upgrades). A trophy decoration
  the player already owns (e.g. also granted by a quest or event) is replaced by **100 MS** (same rule as §18). Recipe unlocks below the
  player's level become vouchers (§14 EC-14-16). **Exactly 10 achievements grant 1 skill point each** (feeds §14.14).
- **Analytics.** `mmr_achievement_unlocked {ach_id, category, level, hours_active, hidden}` via
  `AnalyticsService:LogCustomEvent` plus the internal event; journal opens log `mmr_journal_opened`.
- **Live-ops.** New achievements take the next free ID; IDs are never reused. On release, counters that already exist
  are evaluated retroactively.

| ID | Name | Description | Condition (measurable) | Tracking counter | Reward | Hidden? | Category |
|---|---|---|---|---|---|---|---|
| `ACH_001` | Burger Baby | Everyone starts somewhere. Usually with a burger. | Serve `RCP_BRG_001` Basic Burger ≥ 1 time | `served_recipe[RCP_BRG_001]` | 100 MB + title “Burger Baby” | No | cooking |
| `ACH_002` | Short-Order Legend-ish | Triple digits! Nana's hologram is mildly impressed. | Serve ≥ 100 dishes (accuracy A > 0) | `dishes_served` | 1,000 MB + XP 10 XPU | No | cooking |
| `ACH_003` | Thousand-Plate Club | The dishwasher has filed a complaint. | Serve ≥ 1,000 dishes | `dishes_served` | 10,000 MB + 25 MS + 1 Morph Capsule | No | cooking |
| `ACH_004` | Plate Tectonics | You have moved more plates than continents. | Serve ≥ 10,000 dishes | `dishes_served` | 150,000 MB + 5 RT + 1 skill point + title “Plate Tectonics” | No | cooking |
| `ACH_005` | Perfectionist Pancake | Golden. Fluffy. Flawless. Fifty times. | Serve ≥ 50 dishes with Food Quality Q ≥ 0.95 | `perfect_dishes` | 2,500 MB + emote “Chef's Kiss” | No | cooking |
| `ACH_006` | Flawless Flapjack Flipper | Not one burnt crumb. Suspicious, honestly. | ≥ 25 PERFECT dishes in a row with no BURNED or UNDERCOOKED component | `perfect_streak_best` | 40 MS + 1 skill point + palette “Golden Crust” | No | cooking |
| `ACH_007` | Smoke Detector's Nemesis | You and fire have an understanding. It's complicated. | Extinguish ≥ 25 station fires | `fires_extinguished` | 1,500 MB + title “Fire Marshmallow” | No | cooking |
| `ACH_008` | Recipe Hoarder | Your recipe book now needs its own chair. | Know ≥ 25 recipes | `recipes_known` | 5,000 MB + 20 MS + recipe unlock `RCP_SAN_005` Peanut Butter & Jellyfish | No | cooking |
| `ACH_009` | Walking Cookbook | You dream in ingredient lists. | Know ≥ 100 recipes | `recipes_known` | 60,000 MB + 10 RT + title “Walking Cookbook” | No | cooking |
| `ACH_010` | Category Collector | Burgers to Black Hole Bagels: you've plated it all. | Serve ≥ 1 dish from each of the 15 recipe categories | `categories_served` (15-bit set) | 30,000 MB + 1 skill point + palette “Food Pyramid” | No | cooking |
| `ACH_011` | Controversial Chef | Pineapple belongs on pizza. Ten customers agree. | Serve `RCP_PIZ_004` to ≥ 10 customers who end Delighted (S ≥ 90) | `delighted_recipe[RCP_PIZ_004]` | 3,000 MB + emote “Pineapple Shrug” | No | cooking |
| `ACH_012` | Legend of the Ladle | Five legends, five perfect plates, zero chill. | Serve each of `RCP_LEG_001`–`RCP_LEG_005` once at Q ≥ 0.95 | `perfect_recipe_set.LEG` (5) | 25 RT + `MUT_178` Golden Chef Hands + title “Legend of the Ladle” | No | cooking |
| `ACH_013` | Smile Factory | One hundred mutants left happier than they came in. | ≥ 100 customers end Delighted (S ≥ 90) | `customers_delighted` | 2,000 MB + XP 15 XPU | No | service |
| `ACH_014` | Chef's Kiss Collector | Mwah. Mwah. Mwah. (×50) | ≥ 50 customers end at S ≥ 98 | `customers_chefs_kiss` | 25 MS + emote “Chef's Kiss Blow” | No | service |
| `ACH_015` | Five-Star Freak | Madame Fourchette raised one eyebrow. A first. | Restaurant reputation ≥ 4.95 ★ (displays 5.0 ★) | `reputation_peak` | 50 MS + title “Five-Star Freak” | No | service |
| `ACH_016` | Hold the Fourchette | The critic finished the whole plate. Twice. Ten times. | `PER_004` The Food Critic ends Delighted ≥ 10 times | `delighted_personality[PER_004]` | 30 MS + recipe unlock `RCP_DES_014` Galaxy Cheesecake | No | service |
| `ACH_017` | Jackpot! | A tip so big it needed its own tray. | Receive ≥ 1 Jackpot Tip (§C11.4) | `jackpot_tips` | 500 MB + emote “Confetti Rain” | No | service |
| `ACH_018` | Tip Tycoon | The tip jar has its own tip jar now. | Earn ≥ 100,000 MB from tips (lifetime) | `tips_earned_mb` | 1 Morph Capsule + title “Tip Tycoon” | No | service |
| `ACH_019` | Modification Maestro | Seventeen pickles, no circles, served angry: done. | Satisfy ≥ 200 order modifications (§6.18) | `mods_satisfied` | 5,000 MB + 20 MS | No | service |
| `ACH_020` | Dino Diplomat | The Karenosaurus asked for the manager… to compliment you. | `PER_001` The Karenosaurus ends Delighted ≥ 25 times | `delighted_personality[PER_001]` | 40 MS + title “Dino Diplomat” | No | service |
| `ACH_021` | Speed Demon Server | Food arrives before the order is finished. Almost. | ≥ 50 customers served within 25 % of their patience | `fast_serves` | 2,500 MB + palette “Racing Stripes” | No | service |
| `ACH_022` | Splash Zone | Your first faceful of flying food. You'll live. | Be hit by thrown food ≥ 1 time | `times_hit_by_food` | 300 MB + title “Splash Zone” | No | chaos |
| `ACH_023` | Table Unflipper | Flipped at 7:02, fixed by 7:03. | Repair a table within 60 s of it being flipped (`ANM_049`) | `fast_table_repairs` | 1,000 MB + emote “Table Unflip” | No | chaos |
| `ACH_024` | Total Restaurant Meltdown | Chairs flew. Soup rained. Someone still paid. | End an anger-level-6 chaos episode with ≥ 1 customer still paying | `chaos6_survived_paying` | 40 MS + emote “Deep Breath” | No | chaos |
| `ACH_025` | Domino Diner | One meatball. Three food fights. Zero regrets. | One thrown item starts a chain in which ≥ 3 customers throw food | `food_chain_max` | 25 MS + title “Domino Diner” | Yes | chaos |
| `ACH_026` | Calm Before the Storm | Words: mightier than the spatula. | De-escalate ≥ 50 customers without combat (`CALM_TALK`, §14.5) | `calm_talks` | 5,000 MB + `MUT_241` Fairy Wings | No | chaos |
| `ACH_027` | Pickle Apocalypse | It rained pickles and you kept cooking. | Serve ≥ 50 dishes during `EVT_012` Pickle Rain (lifetime) | `served_during_event[EVT_012]` | 30 MS + palette “Pickle Green” | No | chaos |
| `ACH_028` | Invisible Box | You talked a mime down. Without words? With words. | Calm a hostile `PER_019` The Mime Mantis using only `ABL_006` (no damage dealt) | `mime_calmed_by_voice` | emote “Invisible Box” | Yes | chaos |
| `ACH_029` | Gremlin Whisperer | The Chaos Gremlin… behaved? | Serve `PER_007` The Chaos Gremlin ≥ 20 times without it reaching anger level 3 | `gremlin_peaceful_serves` | 3,000 MB + title “Gremlin Whisperer” | No | chaos |
| `ACH_030` | Dizzy Spells | Ten tantrums, ten apology bows. | Calm ≥ 10 hostile customers through combat (`CALM_FIGHT`) | `calm_fights` | 1,000 MB + XP 10 XPU | No | combat |
| `ACH_031` | Bouncer of the Month | Your photo is on the break-room wall. | Calm ≥ 100 hostile customers through combat | `calm_fights` | 40 MS + title “Bouncer of the Month” | No | combat |
| `ACH_032` | Untouchable Chef | Not a single sauce splat on the apron. | Calm a level-5 customer without taking any damage during that fight | `flawless_calm_fights` | 20 MS + emote “Brush Off Shoulders” | No | combat |
| `ACH_033` | Tank Tamer | You made a walking wall say sorry. | Calm a customer with ≥ 250 Huff Points | `max_huff_calmed` | 30 MS + title “Tank Tamer” | No | combat |
| `ACH_034` | Pan-tastic | Bonk. Bonk. Bonk. (×100) | Land ≥ 100 `ABL_007` Pan Bonk hits | `ability_hits[ABL_007]` | 1,500 MB + emote “Pan Twirl” | No | combat |
| `ACH_035` | Arena Rookie | The crowd goes mild! | Win ≥ 1 opt-in arena match (`BLD_08`) | `arena_wins` | 25 MS | No | combat |
| `ACH_036` | Arena Champion | Rex Rumbleton can't stop shouting your name. | Win ≥ 50 arena matches | `arena_wins` | 15 RT + 1 skill point + `FRN_904` Arena Champion Belt Case | No | combat |
| `ACH_037` | Professional Napper | You've seen so many stars you could open a planetarium. | Be KO'd ("Seeing Stars") ≥ 10 times | `player_kos` | 500 MB + title “Professional Napper” | No | combat |
| `ACH_038` | Perfect Parry | Not today, flying lasagna. | Block ≥ 100 thrown-food arcs with `ABL_003` or `ABL_008` | `projectiles_blocked` | 2,000 MB + `MUT_157` Umbrella Arm | No | combat |
| `ACH_039` | Fresh Mutant | Ten parts and counting. Mirrors fear you. | Own ≥ 10 different mutation parts | `parts_owned_unique` | 1,000 MB + 10 MS | No | morph |
| `ACH_040` | Collector of Weird | Your closet has tentacles now. | Own ≥ 50 different parts | `parts_owned_unique` | 50 MS + 1 Morph Capsule | No | morph |
| `ACH_041` | Museum Patron | Curator Fossilbottom wants to exhibit *you*. | Own ≥ 150 different parts | `parts_owned_unique` | 30 RT + 1 skill point + `FRN_909` Museum Replica Fossil | No | morph |
| `ACH_042` | Matching Socks | Both arms match. Both legs match. Groundbreaking. | Equip a matched arm pair and a matched leg pair at the same time | `matched_pairs_equipped` (2) | 500 MB + 1 stat respec token + title “Matching Socks” | No | morph |
| `ACH_043` | Synergy Seeker | Parts that work together, stay together. | Activate ≥ 10 different synergies (§36.4) | `synergies_unique` | 40 MS | No | morph |
| `ACH_044` | Synergy Scholar | Dr. Splice is taking notes on you. | Activate ≥ 40 different synergies | `synergies_unique` | 20 RT + palette “Lab Coat Neon” | No | morph |
| `ACH_045` | Rarity Rainbow | Gray, green, blue, purple, orange, magenta: collected. | Own ≥ 1 part of each rarity Common through Mythic | `rarities_owned` (6) | 25 RT + title “Rainbow Mutant” | No | morph |
| `ACH_046` | Max Power | One part, fully cranked. It hums. | Upgrade any part to its rarity's max level (§C4.6) | `parts_maxed` | 50 MS + XP 20 XPU | No | morph |
| `ACH_047` | Fusion Confusion | Three became one. Ten times. | Perform ≥ 10 fusions at the Mutation Laboratory `BLD_11` | `lab_fusions` | 60 MS + 2 RT | No | morph |
| `ACH_048` | Full Body Makeover | Every slot filled. Nothing is normal. | Have ≥ 21 anatomy slots filled at once (FUR and SCALES are exclusive) | `slots_filled_max` | 1 Morph Capsule + emote “Strike a Pose” | No | morph |
| `ACH_049` | Patchwork Pal | A little bit of everything, a lot of weird. | Equip parts from ≥ 8 different categories at once | `categories_equipped_max` | 30 MS + 1 stat respec token + title “Patchwork Pal” | No | morph |
| `ACH_050` | Interior Decorator | The shack has *throw pillows* now. | Place ≥ 25 furniture items | `furniture_placed` | 2,000 MB | No | building |
| `ACH_051` | Atmosphere Architect | Customers come for the food and stay for the lamps. | Reach Atmosphere ≥ 80 (§15) | `atmosphere_peak` | 25 MS + palette “Neon Diner” | No | building |
| `ACH_052` | Full House | Not one empty chair. Fire marshal is nervous. | Every seat occupied at once at `TIER_05` or above | `full_house_events` | 5,000 MB + emote “Take a Bow” | No | building |
| `ACH_053` | Ridiculously Equipped | It's not a grill anymore. It's a lifestyle. | Upgrade any station to Lv5 Ridiculous (§C4.9) | `station_lv5` | 30 MS + title “Ridiculously Equipped” | No | building |
| `ACH_054` | Mister Fix-a-Lot | Duct tape is your love language. | Repair ≥ 500 objects | `objects_repaired` | 40 MS + 1 skill point | No | building |
| `ACH_055` | Rubble to Riches | From cartoon rubble pile to "good as new-ish". | Rebuild ≥ 25 Destroyed objects | `objects_rebuilt` | 3,000 MB + title “Rubble Wrangler” | No | building |
| `ACH_056` | Legendary Landlord | From Broken Burger Shack to Legendary Mutation Restaurant. | Reach `TIER_10` | `tier` (10) | 50 RT + title “Legendary Restaurateur” | No | building |
| `ACH_057` | Spotless | You could eat off the floor. Please don't. | Keep cleanliness K ≥ 95 for ≥ 30 consecutive minutes of service | `clean_streak_minutes` | 2,500 MB + palette “Sparkle White” | No | building |
| `ACH_058` | Ollie's Favorite Boss | Eight arms, one brain cell, total loyalty. | Keep `EMP_001` Ollie employed for ≥ 30 days | `emp001_days_employed` | title “Ollie's Favorite Boss” + palette “Octo-Purple” | No | staff |
| `ACH_059` | Full Payroll | Every apron has a mutant in it. | Fill the employee cap at `TIER_04` or above | `staff_cap_full` | 5,000 MB | No | staff |
| `ACH_060` | Dream Team | Chef to Stocker, all twelve jobs covered. | Employ all 12 roles (§C14.1) at once | `roles_staffed` (12) | 30 MS + 1 skill point | No | staff |
| `ACH_061` | Morale Booster | Pizza party? You *are* the pizza party. | Keep every employee at Morale ≥ 90 for ≥ 120 min of online play | `high_morale_minutes` | 25 MS + emote “Pep Talk” | No | staff |
| `ACH_062` | Sleep Tycoon | You earned a million Morph Bucks in your pajamas. | Collect ≥ 1,000,000 MB of offline earnings (lifetime) | `offline_mb_collected` | 1 Morph Capsule + title “Sleep Tycoon” | No | staff |
| `ACH_063` | Legendary Recruiter | Ms. Hirewell fainted onto her filing cabinet. | Hire ≥ 1 Legendary employee | `legendary_hires` | 50 MS | No | staff |
| `ACH_064` | Hero of the Night | Your staff saved the day. While you slept. Ten times. | Receive ≥ 10 employee hero-moment incidents in offline reports (§36.9) | `hero_incidents` | 20 MS + emote “Salute” | No | staff |
| `ACH_065` | Never Sleeps | The restaurant runs all day. You don't have to. | Reach the 24 h offline cap (§C14.3) | `offline_cap_hours` (24) | title “Never Sleeps” + palette “Midnight Shift” | No | staff |
| `ACH_066` | Tourist Trap | Seen the sewers, the arena, and the museum gift shop. | Discover all 10 districts `DST_01`–`DST_10` | `districts_discovered` (10) | 30 MS + `MUT_235` Pigeon Wings | No | city |
| `ACH_067` | Metro Mole | Conductor Choo knows you by name. | Discover every Morph Metro station | `metro_stations_discovered` (all) | emote “All Aboard” | No | city |
| `ACH_068` | Frequent Flapper | The pigeons have a loyalty card for you. | Take ≥ 25 Pigeon Taxi rides | `taxi_rides` | title “Frequent Flapper” | No | city |
| `ACH_069` | Event Enthusiast | Parades, meteors, pickle rain: you were there. | Take part in ≥ 10 different city events | `events_unique` | 40 MS | No | city |
| `ACH_070` | Event Completionist | Every festival, every fiasco. | Take part in every non-seasonal event (`EVT_001`–`EVT_028` and `EVT_032`; 29 total) | `events_unique_nonseasonal` (29) | 30 RT + 1 skill point + title “Been There, Ate That” | No | city |
| `ACH_071` | Sewer Saver | The Rat King's crown is a little crooked now. | Take part in a successful defeat of King Ratbeard in `EVT_007` | `rat_king_defeats` | 30 MS + title “Sewer Saver” | No | city |
| `ACH_072` | Meet the Locals | You know everyone. Everyone has opinions about soup. | Talk to ≥ 50 different named NPCs | `npcs_met` | 2,500 MB + emote “Friendly Wave” | No | city |
| `ACH_073` | Quest Machine | Pinboard Pete is running out of pins. | Complete ≥ 100 quests (any type) | `quests_completed` | 20 RT + 1 skill point | No | city |
| `ACH_074` | Kitchen Buddies | Two chefs, one grill, zero arguments. | Help in a friend's restaurant for ≥ 10 minutes | `coop_guest_minutes` | 500 MB + emote “High Five” | No | social |
| `ACH_075` | Open House | The more the merrier (and messier). | Host ≥ 3 guests at once in your restaurant | `max_guests_hosted` | 1,000 MB + palette “Welcome Mat” | No | social |
| `ACH_076` | Guest Star | Everyone's favorite visiting chef. | Serve ≥ 100 dishes as a guest in friends' restaurants | `guest_dishes_served` | 30 MS + title “Guest Star” | No | social |
| `ACH_077` | Showoff | Ten mutants admired your tentacle-to-wing ratio. | Show your morph on the Showcase Stage `BLD_22` to ≥ 10 different players | `showcase_viewers_unique` | 25 MS + palette “Spotlight” | No | social |
| `ACH_078` | Noodle Dancer | All limbs, no rhythm, maximum effort. | Take part in `EVT_027` Downtown Dance-Off | `events_joined[EVT_027]` | emote “Noodle Dance” | No | social |
| `ACH_079` | Error 404: Chef Not Found | The billboard blinked back. | Discover `MUT_040` Glitch Head (§C13.8) | `secret_found[MUT_040]` | title “Error 404: Chef Not Found” | Yes | secret |
| `ACH_080` | Endless Noodle | It just keeps going. | Discover `MUT_116` Noodle Neck (§C13.8) | `secret_found[MUT_116]` | title “Noodle Legend” | Yes | secret |
| `ACH_081` | Paper Pilot | Nothing but fountain. | Discover `MUT_237` Paper Airplane Wings (§C13.8) | `secret_found[MUT_237]` | emote “Paper Plane Toss” | Yes | secret |
| `ACH_082` | Dead Pixel Detective | Eight tiny glitches, one sharp eye. | Discover `MUT_276` Pixel Glitch (§C13.8) | `secret_found[MUT_276]` | palette “8-Bit” | Yes | secret |
| `ACH_083` | Busker's Ballad | The torn poster was sheet music all along. | Discover `MUT_112` Accordion Neck (§C13.8) | `secret_found[MUT_112]` | emote “Accordion Squeeze” | Yes | secret |
| `ACH_084` | Stared Into the Void | The void served you a snack. | Discover `MUT_048` Cosmic Void Face (§C13.8) | `secret_found[MUT_048]` | title “Stared Into the Void” | Yes | secret |
| `ACH_085` | Foggy Five Stars | Fifty perfect visits, one midnight market, a lot of fog. | Discover `MUT_280` Mystery Fog (§C13.8) | `secret_found[MUT_280]` | title “Fog of Flavor” | Yes | secret |
| `ACH_086` | Handstand Hero | Upside-down burger, upside-down day, right-side-up customer. | Serve `RCP_BRG_013` Upside-Down Burger during `EVT_011` Upside-Down Day | `served_during_event[EVT_011].RCP_BRG_013` | emote “Handstand” | Yes | secret |
| `ACH_087` | Toast Whisperer | A haunted toaster ate grilled cheese and wept (happily). | Serve `RCP_SAN_001` Grilled Cheese at Q ≥ 0.95 to `PER_028` The Haunted Toaster | `toaster_perfect_cheese` | title “Toast Whisperer” | Yes | secret |
| `ACH_088` | Nana Would Be Proud | You won the Legendary Chef Tournament. The hologram cried. | Win the story finale at `EVT_005` Legendary Chef Tournament | `story_finale_won` | 25 RT + 1 skill point + title “Morph City's Greatest” | Yes | secret |

**Category totals:** cooking 12 · service 9 · chaos 8 · combat 9 · morph 11 · building 8 · staff 8 · city 8 · social 5 ·
secret 10 = **88 achievements** (12 hidden). **Skill points:** `ACH_004`, `ACH_006`, `ACH_010`, `ACH_036`, `ACH_041`,
`ACH_054`, `ACH_060`, `ACH_070`, `ACH_073`, `ACH_088` = 10.

**Reward pacing [TUNABLE].** MB rewards stay ≤ 1 active hour of §C4.4 income at the tier where the achievement is
typically earned (e.g. `ACH_003` ≈ 10,000 MB at `TIER_04`–`TIER_05`); MS/RT rewards stay within one week of normal
quest income; Legendary-or-better parts are granted only by end-game achievements (`ACH_012`).
