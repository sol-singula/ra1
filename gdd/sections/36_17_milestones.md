### 36.17 Progression Milestones Database

> Milestones are one-time progression beats (except `MLS_045`) that mark onboarding firsts,
> level bands and restaurant tiers, unlock or explain features, and anchor the analytics funnel (brief Part 20, §31).

**Rules & Mechanics.**

- **Trigger** is a server-observed fact (ProgressionService listens to service signals); a milestone fires once per
  account (`achievements.milestones[ID] = timestamp`, §28.9.12), is idempotent across rejoin/server change, and toasts per §C22 E14.
- **Unlocks** names what becomes available at that moment — the gates themselves are canon (§C6, §C7.1, §C13.3, §C16.1)
  or §14 (skill rows, specializations); the milestone surfaces them with a one-card "What's new" popup the next time the
  player is idle (never mid-rush).
- **Rewards** use the §C17.4 vocabulary but **never MS or RT**: canon §C4.1 lists milestones as a Morph Bucks source
  only, while Morph Capsules are explicitly allowed (§C4.7). XP is written **XP n XPU** (§14.3). **Exactly 6 milestones
  grant 1 skill point each** (feeds §14.14).
- **Analytics.** Each row fires its listed event once plus `mmr_milestone_reached {mls_id, level, hours_active,
  session_index}`. `MLS_001`–`MLS_013` also call `AnalyticsService:LogFunnelStepEvent(player, "mmr_first_session", sessionId, step, name)`
  with step = 1–13 in ID order (the onboarding funnel itself is reserved for the tutorial, §31.8); level bands call `LogProgressionEvent(player, "PlayerLevel",
  Enum.AnalyticsProgressionType.Complete, level)`; tier rows call it with path `"RestaurantTier"` and the tier number.

| ID | Milestone | Trigger | Unlocks | Reward | Analytics event |
|---|---|---|---|---|---|
| `MLS_001` | Welcome to the Shack | First entry into your restaurant interior (`QST_TUT_001`) | Tutorial chain, HUD basics | 50 MB | `mmr_onboarding_enter_restaurant` |
| `MLS_002` | First Order | First order taken from a seated customer | Order rail + patience meters | XP 2 XPU | `mmr_first_order` |
| `MLS_003` | First Successful Meal | First dish served with satisfaction S ≥ 50 (paid in full) | Wallet HUD, satisfaction faces | 50 MB + XP 2 XPU | `mmr_first_successful_meal` |
| `MLS_004` | First Tip | First tip received (S ≥ 70) | Tip-rate tooltip | 25 MB | `mmr_first_tip` |
| `MLS_005` | First Tantrum | First customer reaches anger level 3 (scripted `PER_001` in `QST_TUT_006`) | Combat hint cards | emote “Facepalm” | `mmr_first_tantrum` |
| `MLS_006` | First Combat | First damage dealt to a hostile customer | Ability bar (`ABL_001`–`ABL_006`) | XP 2 XPU | `mmr_first_combat` |
| `MLS_007` | First Calm-Down | First hostile customer reaches Apologizing | Apology Payment explainer | 100 MB | `mmr_first_calm_down` |
| `MLS_008` | First Repair | First object repaired (`QST_TUT_008`) | Repair overlay, damage states legend | 50 MB | `mmr_first_repair` |
| `MLS_009` | First Seeing Stars | First player KO (`ANM_062`) | "Nothing was lost!" KO card | title “Dizzy Rookie” | `mmr_first_ko` |
| `MLS_010` | First Mutation | First part equipped (starter choice in `QST_TUT_010`) | Morph screen, 3 loadout slots | 1 Morph Capsule | `mmr_first_mutation` |
| `MLS_011` | First Restaurant Upgrade | First restaurant upgrade or furniture purchase (`QST_TUT_011`) | Build mode | 100 MB | `mmr_first_restaurant_upgrade` |
| `MLS_012` | First Hire | `EMP_001` Ollie hired (`QST_TUT_012`) | Staff tab, offline income preview | palette “Intern Orange” | `mmr_first_employee_hire` |
| `MLS_013` | Tutorial Graduate | `QST_TUT_001`–`QST_TUT_012` all complete | Job Board `BLD_10` quests, daily quests | 500 MB + title “Shack Graduate” | `mmr_tutorial_complete` |
| `MLS_014` | First Level-Up | Reach Level 2 | Skill trees (Row 1), Level panel | emote “Level-Up Wiggle” | `mmr_first_level_up` |
| `MLS_015` | Points Well Spent | First stat point allocated | Respec explainer | 1 stat respec token | `mmr_first_stat_allocation` |
| `MLS_016` | Branching Out | First skill node committed | Skill-tree tooltips | 100 MB | `mmr_first_skill_node` |
| `MLS_017` | First Offline Collect | First Welcome Back report collected (§17) | Offline report history | 1 Morph Capsule | `mmr_first_offline_collect` |
| `MLS_018` | First City Trip | First entry into any district other than `DST_01` | City map, Pigeon Taxi | XP 5 XPU | `mmr_first_city_trip` |
| `MLS_019` | First Quest | First non-tutorial quest completed | Quest journal history | 200 MB | `mmr_first_quest_complete` |
| `MLS_020` | First Synergy | First mutation synergy activated (§36.4) | Synergy codex | 1 Morph Capsule | `mmr_first_synergy` |
| `MLS_021` | Back to School | First recipe learned at the Cooking Academy `BLD_06` | Recipe book filters | 200 MB | `mmr_first_recipe_learned` |
| `MLS_022` | First Perfect Plate | First dish served at Food Quality Q ≥ 0.95 | Quality breakdown tooltip | emote “Chef's Pinch” | `mmr_first_perfect_dish` |
| `MLS_023` | First Capsule Opened | First Morph Capsule opened | Odds disclosure screen, pity counter (§C4.7) | XP 3 XPU | `mmr_first_capsule` |
| `MLS_024` | First Mutation Upgrade | First part upgraded to Lv2 | Upgrade panel | 300 MB | `mmr_first_mutation_upgrade` |
| `MLS_025` | First Co-op | First visit as a guest, or first guest hosted (§21) | Co-op permissions panel | emote “Kitchen Hug” | `mmr_first_coop_visit` |
| `MLS_026` | First Metro Ride | First Morph Metro fast-travel | Metro map | 100 MB | `mmr_first_metro_ride` |
| `MLS_027` | First City Event | First participation in any city event (§36.11) | Event calendar | 1 Morph Capsule | `mmr_first_city_event` |
| `MLS_028` | First Arena Match | First opt-in arena match at `BLD_08` (L12+) | Arena ladder | title “Ring Debutant” | `mmr_first_arena_match` |
| `MLS_029` | First Fusion | First fusion at the Mutation Laboratory `BLD_11` (L15+) | Fusion log | 1 Morph Capsule | `mmr_first_lab_fusion` |
| `MLS_030` | First Station Upgrade | First station reaches Lv2 Tuned (§C4.9) | Station upgrade panel | 300 MB | `mmr_first_station_upgrade` |
| `MLS_031` | Came Back! | First session on a second distinct UTC day | Daily login streak | 1 Morph Capsule | `mmr_return_visit` |
| `MLS_032` | Level 5 — Line Cook | Reach Level 5 | `TIER_02` eligible; Uncommon parts; skill Row 2 | 500 MB + title “Line Cook” | `mmr_level_band_reached` {level: 5} |
| `MLS_033` | Level 10 — Sous-Mutant | Reach Level 10 | `TIER_03` eligible; `DST_07`; skill Row 3 | 1 skill point + 2,000 MB | `mmr_level_band_reached` {level: 10} |
| `MLS_034` | Level 12 — Ready to Rumble | Reach Level 12 | `DST_10`; `BLD_08` arena (opt-in) and `BLD_05`; Rare parts | 1 Morph Capsule | `mmr_level_band_reached` {level: 12} |
| `MLS_035` | Level 15 — Lab Rat | Reach Level 15 | `DST_06`; `BLD_11` fusion; `BLD_16` museum | 1 Morph Capsule + palette “Lab Green” | `mmr_level_band_reached` {level: 15} |
| `MLS_036` | Level 20 — Specialist | Reach Level 20 | First specialization (SVC or MGMT); `DST_09`; `BLD_13` | 1 stat respec token + title “Specialist” | `mmr_level_band_reached` {level: 20} |
| `MLS_037` | Level 25 — Epic Appetite | Reach Level 25 | Epic parts | 1 skill point + 1 Morph Capsule | `mmr_level_band_reached` {level: 25} |
| `MLS_038` | Level 30 — Gravity Optional | Reach Level 30 | `STN_ANTIGRAV` (with `TIER_05`); first ALN recipe learnable | 10,000 MB + emote “Zero-G Float” | `mmr_level_band_reached` {level: 30} |
| `MLS_039` | Level 40 — Legend in Training | Reach Level 40 | Legendary parts; `STN_INFUSER` (with `TIER_06`) | 2 Morph Capsules + title “Legend in Training” | `mmr_level_band_reached` {level: 40} |
| `MLS_040` | Level 50 — Double Specialist | Reach Level 50 | Second specialization | 1 skill point + 1 stat respec token | `mmr_level_band_reached` {level: 50} |
| `MLS_041` | Level 60 — Mythic Mutant | Reach Level 60 | Mythic parts; Row 8 and S5 capstones | 2 Morph Capsules + palette “Mythic Magenta” | `mmr_level_band_reached` {level: 60} |
| `MLS_042` | Level 75 — Kitchen Royalty | Reach Level 75 | — (bragging rights; `RCP_LEG_003` at L80 next) | 1 skill point + title “Kitchen Royalty” | `mmr_level_band_reached` {level: 75} |
| `MLS_043` | Level 90 — Almost Legendary | Reach Level 90 | — (`RCP_LEG_005` learnable at L95 next) | 3 Morph Capsules | `mmr_level_band_reached` {level: 90} |
| `MLS_044` | Level 100 — Maximum Mutant | Reach Level 100 | Overtime Bars | 1 skill point + title “Maximum Mutant” + emote “Crown Toss” | `mmr_level_band_reached` {level: 100} |
| `MLS_045` | Overtime Bar (repeatable) | At L100, each full bar of `XPReq(99)` = 235,346 XP | — | 1 Morph Capsule + title “Overtime Legend” (every 10th bar) | `mmr_overtime_bar` {bar_index} |
| `MLS_046` | Tiny Mutation Diner | Upgrade to `TIER_02` | 6 seats, 8 appliance slots, 3 staff; Lv2 station upgrades; `STN_MIXER`, `STN_FREEZER`, `STN_PLATING` | palette “Diner Chrome” | `mmr_restaurant_tier_up` {tier: TIER_02} |
| `MLS_047` | Neighborhood Freak Café | Upgrade to `TIER_03` | Table service, 8 seats, 4 staff | 1 Morph Capsule + title “Café Keeper” | `mmr_restaurant_tier_up` {tier: TIER_03} |
| `MLS_048` | Morph City Grill | Upgrade to `TIER_04` (City Hall permit) | 10 seats, 6 staff; Lv3 station upgrades | 1 Morph Capsule + emote “Grill Salute” | `mmr_restaurant_tier_up` {tier: TIER_04} |
| `MLS_049` | Mutant Family Restaurant | Upgrade to `TIER_05` | 12 seats, 8 staff; story Chapter 5 (Alien Cuisine course) | 2 Morph Capsules + palette “Family Picnic” | `mmr_restaurant_tier_up` {tier: TIER_05} |
| `MLS_050` | Monster Food Court | Upgrade to `TIER_06` | 14 seats, 10 staff; Lv4 station upgrades | 2 Morph Capsules + title “Food Court Monarch” | `mmr_restaurant_tier_up` {tier: TIER_06} |
| `MLS_051` | Mutation Megadiner | Upgrade to `TIER_07` | 16 seats, 14 menu slots, 12 staff | 2 Morph Capsules + emote “Mega Wave” | `mmr_restaurant_tier_up` {tier: TIER_07} |
| `MLS_052` | Luxury Freak Restaurant | Upgrade to `TIER_08` | 18 seats, 14 staff; Lv5 Ridiculous upgrades | 3 Morph Capsules + palette “Velvet Freak” | `mmr_restaurant_tier_up` {tier: TIER_08} |
| `MLS_053` | Morph City Food Palace | Upgrade to `TIER_09` | 20 seats, 20 menu slots, 16 staff | 3 Morph Capsules + title “Palace Chef” | `mmr_restaurant_tier_up` {tier: TIER_09} |
| `MLS_054` | Legendary Mutation Restaurant | Upgrade to `TIER_10` | 24 seats, 24 appliance and menu slots, 20 staff | 1 skill point + 3 Morph Capsules + emote “Legendary Bow” | `mmr_restaurant_tier_up` {tier: TIER_10} |

**Coverage:** onboarding firsts `MLS_001`–`MLS_031` (all Part 20 funnel events: first order, first successful meal, first
tantrum, first combat, first mutation, first upgrade, first hire, first offline collect, first city trip, first quest,
first synergy, return visit), level bands `MLS_032`–`MLS_045`, every tier `MLS_046`–`MLS_054` (`TIER_01` is the starting
state, marked by `MLS_001`). **Skill points:** `MLS_033`, `MLS_037`, `MLS_040`, `MLS_042`, `MLS_044`, `MLS_054` = 6.

**Funnel use (§31).** Drop-off between consecutive onboarding milestones flags tutorial friction (target ≥ 85 % step
conversion for `MLS_001`→`MLS_013`); median hours to each level band are compared with the §14.4 table — a band arriving
> 15 % late for the median player triggers the §14.5.4 tuning levers.
