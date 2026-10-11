### 36.4 Mutation Synergies Database

> Contributor: A8. Rules for reading, stacking and capping these rows are in §12.10. Parts are referenced by canon
> `MUT_` IDs (details in §36.3), abilities by `ABL_` (§36.6), statuses by `STS_` (§36.7). All magnitudes are
> **[TUNABLE]** balancing assumptions.

**How to read a row.**

- **Requirement** uses the §12.10.2 grammar. `family:octopus@ARM` means "at least one octopus-family part in an arm
  slot". `tag:chef>=5` means "five or more equipped parts carrying the `chef` tag". `tag:repair+claw@ARM` means "an
  arm part that carries *both* tags". Scopes: `ARM`/`LEG` = both sides; omitted = every non-FX slot.
- **Effect** starts with its effect type(s) from the §12.10.3 table. That table defines what each type does and
  how it is capped.
- **Stacking group (rank):** only the highest-ranked qualifying synergy of a group is active; r3 beats r2 beats r1,
  and on equal rank the lower ID wins. At most **5 synergies** are active at once (pins first, then rank, then ID).
- **Cap (synergy layer):** the limit for the sum of *all* active synergies of that effect type (per target where
  the type names one). `STAT` effects share **+25 points per stat**. Canon stat caps (§14) and the hard WalkSpeed
  ceiling of 21 studs/s still apply on top.
- **Example qualifying parts** is a minimal legal set that triggers the synergy on its own; ×2 means both arms or
  both legs. It is checked by the tool, together with the Plain Human defaults (`MUT_117`, `MUT_139`, `MUT_179`) in
  any unlisted mandatory slot.
- **Context:** where the effect matters: `cook`, `combat`, `repair`, `move`, `social`. In the Arena only `combat`
  and `move` synergies apply, at half strength (§12.10.5).

Every row is machine-checked by `python3 gdd/tools/check_synergies.py`: the requirement (and each OR-branch) is
satisfiable with canon parts under the slot rules, the examples exist, fit together and trigger the synergy, and
each example part contributes to the requirement.

#### 36.4.1 Brief Synergies

The four synergies named in the brief (Part 7.6). Each one also has a more generic, lower-ranked "cousin" in the same stacking group so the idea works with more parts.

| ID | Name | Requirement (§12.10 grammar) | Effect | Magnitude [TUNABLE] | Stacking group (rank) | Cap (synergy layer) | Example qualifying parts | Context |
|---|---|---|---|---|---|---|---|---|
| `SYN_001` | Eight-Arm Kitchen Nightmare | `family:octopus@ARM AND (family:chef OR tag:chef>=3)` | `PROC_TIME` While ≥ 2 of your items process at once, all of them cook faster; you may tend two adjacent station slots without stepping away. | −12 % process time | SG_MULTICOOK (r3) | −30 %/station | `MUT_145` ×2, `MUT_102` | cook |
| `SYN_002` | Unbearable Impact | `family:bear@ARM AND family:rhino@HORNS` | `KNOCKBACK` Melee hits, `ABL_010` Bear Slam and `ABL_013` Rhino Charge launch targets farther. | +20 % knockback | SG_KNOCK (r3) | +30 % | `MUT_140`, `MUT_099` | combat |
| `SYN_003` | Scuttle to the Scuffs | `family:spider@LEG AND tag:repair+claw@ARM` | `MOVE_CTX` + `REPAIR_SPD` While a damaged object (≤ 75 % durability) in your restaurant is within 25 studs and your hands are empty: WalkSpeed up and a dotted path to the nearest one; repairs slightly faster. | +12 % move; +5 % repair | SG_REPAIR_MOVE (r3) | +30 %; ≤ 21 studs/s; +30 %/class | `MUT_185` ×2, `MUT_153` | repair, move |
| `SYN_004` | Dragon's Own Kitchen | `family:dragon@HEAD AND family:fire@SKIN` | `PERFECT_WIN` + `BURN_GRACE` + `STATUS_IMMUNE` Within 7 studs of a heat station (grill, fryer, oven, pizza oven, stove, soup pot, steamer, anti-grav wok, infuser): wider Perfect window, later burn; immune to `STS_TOASTY` from station fires. | +15 % window; +1.5 s | SG_HEATCOOK (r3) | +30 %/station; +3 s; — | `MUT_031`, `MUT_254` | cook |

#### 36.4.2 Cooking Synergies

Speed, quality and money in the kitchen. Station names follow §5; recipe category codes follow §6.

| ID | Name | Requirement (§12.10 grammar) | Effect | Magnitude [TUNABLE] | Stacking group (rank) | Cap (synergy layer) | Example qualifying parts | Context |
|---|---|---|---|---|---|---|---|---|
| `SYN_005` | Many Hands Make Light Lunch | `tag:multi>=2 AND tag:chef>=2` | `PROC_TIME` While ≥ 2 of your items process at once, all of them cook faster. | −8 % process time | SG_MULTICOOK (r2) | −30 %/station | `MUT_249`, `MUT_150`, `MUT_167` | cook |
| `SYN_006` | Oven Mitts Optional | `tag:fire@HEAD AND (tag:armored@SKIN OR tag:fire@SCALES OR tag:fire@HANDS)` | `PERFECT_WIN` + `BURN_GRACE` Within 7 studs of a heat station: wider Perfect window, later burn. | +8 % window; +0.75 s | SG_HEATCOOK (r1) | +30 %/station; +3 s | `MUT_010`, `MUT_171` | cook |
| `SYN_007` | Grill Sergeant | `tag:fire>=3 AND tag:chef>=2` | `PROC_TIME` `STN_GRILL` and `STN_FRYER` process faster. | −10 % | SG_GRILL (r2) | −30 %/station | `MUT_031`, `MUT_171`, `MUT_163` | cook |
| `SYN_008` | Brain Freeze Brigade | `tag:ice>=2 AND tag:chef>=1` | `PROC_TIME` `STN_FREEZER`, `STN_ICECREAM` and `STN_BLENDER` process faster. | −10 % | SG_COLDCOOK (r2) | −30 %/station | `MUT_176`, `MUT_125` | cook |
| `SYN_009` | Walk-In Freezer | `family:fridge@TORSO AND tag:ice>=2` | `PROC_TIME` `STN_FREEZER`, `STN_ICECREAM` and `STN_BLENDER` process much faster (you are basically the freezer). | −18 % | SG_COLDCOOK (r3) | −30 %/station | `MUT_131`, `MUT_176` | cook |
| `SYN_010` | Sous-Chef Squad | `tag:chef>=5` | `STAT` Flat stat points. | +8 COOK_SPD, +6 COOK_QLT | SG_CHEFSTAT (r2) | +25/stat | `MUT_008`, `MUT_102`, `MUT_121`, `MUT_156`, `MUT_167` | cook |
| `SYN_011` | Five-Star Freak Chef | `tag:chef>=8` | `STAT` Flat stat points. | +12 COOK_SPD, +10 COOK_QLT | SG_CHEFSTAT (r3) | +25/stat | `MUT_008`, `MUT_050`, `MUT_069`, `MUT_102`, `MUT_121`, `MUT_156`, `MUT_167`, `MUT_173` | cook |
| `SYN_012` | Utensil Drawer Energy | `family:utensil>=3` | `INTERACT` Chop, mix-by-hand and assemble interactions take less time. | −12 % | SG_CHOP (r2) | −30 %/action | `MUT_156`, `MUT_167`, `MUT_173` | cook |
| `SYN_013` | Mantis Mise en Place | `family:mantis AND tag:chef>=2` | `CHOP_ZONE` The green "Clean cut" zone on every chop ring is wider. | +25 % zone | SG_CHOP (r3) | +30 % | `MUT_151`, `MUT_102`, `MUT_156` | cook |
| `SYN_014` | Garden-to-Table | `tag:plant>=3 AND tag:chef>=1` | `INTERACT` Chopping `veg`, `fruit` or `plant`-tagged ingredients takes less time. | −15 % | SG_CHOP (r1) | −30 %/action | `MUT_030`, `MUT_093`, `MUT_177` | cook |
| `SYN_015` | Sniff Test | `family:pig@NOSE AND tag:chef>=2` | `COOLDOWN` + `REVEAL` `ABL_064` Super Sniff recharges faster; without it equipped, the next ingredient the active ticket needs glows on the pantry shelf. | −25 % cooldown | SG_SNIFF (r2) | −30 %/ability; — | `MUT_058`, `MUT_102` | cook |
| `SYN_016` | Mustache Maestro | `family:mustache@FACE AND tag:chef@HORNS` | `SAT_BONUS` Customers served a dish you plated gain satisfaction. | +3 satisfaction | SG_PRESENT (r2) | MutationBonus ≤ +10 | `MUT_047`, `MUT_102` | cook, social |
| `SYN_017` | Golden Touch Kitchen | `tag:gold>=2 AND tag:chef>=1` | `TIP` All tips you earn are larger. | +10 % tips | SG_TIP (r3) | +30 % | `MUT_178`, `MUT_258` | cook, social |
| `SYN_018` | Microwave Generation | `family:microwave@HEAD AND tag:electric>=2` | `COOLDOWN` `ABL_066` Microwave Zap-Cook recharges faster. | −20 % cooldown | SG_ZAPCOOK (r2) | −30 %/ability | `MUT_036`, `MUT_155` | cook |
| `SYN_019` | You Are What You Cook | `category:FOOD>=3` | `STAT` Flat stat points (customers find you oddly appetizing). | +6 COOK_QLT, +4 CHARM | SG_FOODIE (r2) | +25/stat | `MUT_030`, `MUT_057`, `MUT_143` | cook, social |
| `SYN_020` | Bottomless Noodle | `family:noodle>=2` | `PROC_TIME` `STN_STOVE` and `STN_SOUP_POT` process `PST` recipes faster. | −15 % | SG_BOIL (r2) | −30 %/station | `MUT_143` ×2 | cook |
| `SYN_021` | Hive-Five Bakery | `family:bee>=2` | `PROC_TIME` `STN_OVEN` and `STN_MIXER` process `DES` recipes faster. | −10 % | SG_SWEET (r2) | −30 %/station | `MUT_126`, `MUT_236` | cook |
| `SYN_022` | Sugar Rush Hour | `tag:sweet@EYES AND tag:chef>=2` | `SAT_BONUS` Desserts (`DES`) and drinks (`DRK`) you serve please customers more. | +2 satisfaction | SG_SWEET (r1) | MutationBonus ≤ +10 | `MUT_080`, `MUT_126`, `MUT_102` | cook, social |
| `SYN_023` | Self-Rinsing Kitchen | `tag:water>=2 AND (tag:chef>=1 OR tag:repair>=1)` | `INTERACT` `STN_DISHWASH` washing and fire-extinguishing (`ANM_030`) take less time. | −25 % | SG_CLEAN (r2) | −30 %/action | `MUT_053`, `MUT_157`, `MUT_102` | cook, repair |
| `SYN_024` | Chicken Coop Diner | `family:chicken>=3` | `PERFECT_WIN` Wider Perfect window on `BRK` (breakfast) recipes. | +10 % window | SG_BREAKFAST (r2) | +30 %/station | `MUT_008`, `MUT_121`, `MUT_141` | cook |
| `SYN_025` | Sushi Shift | `tag:aquatic>=3 AND tag:chef>=2` | `PROC_TIME` `SEA` recipes process faster. | −10 % | SG_SEACOOK (r2) | −30 %/station | `MUT_029`, `MUT_119`, `MUT_201`, `MUT_145` | cook |
| `SYN_026` | Udderly Efficient | `family:cow@TORSO AND tag:tank>=2` | `STAT` Flat stat points (ingredient cost ↓ via EFFICIENCY). | +6 EFFICIENCY | SG_EFFICIENCY (r2) | +25/stat | `MUT_120`, `MUT_259` | cook |
| `SYN_027` | Robot Accountant Mode | `tag:robotic>=4` | `STAT` Flat stat points; the morph beeps at every receipt. | +8 EFFICIENCY | SG_EFFICIENCY (r3) | +25/stat | `MUT_022`, `MUT_044`, `MUT_092`, `MUT_123` | cook |
| `SYN_028` | Cosmic Cuisine | `tag:cosmic>=2 AND tag:chef>=1` | `PROC_TIME` `ALN` recipes process faster. | −10 % | SG_ALIENCOOK (r2) | −30 %/station | `MUT_168`, `MUT_228` | cook |
| `SYN_029` | Galaxy Brain Gourmet | `family:nebula>=2` | `PERFECT_WIN` Wider Perfect window on `ALN`, `MUT` and `LEG` recipes. | +12 % window | SG_ALIENCOOK (r3) | +30 %/station | `MUT_138`, `MUT_168` | cook |
| `SYN_030` | Burger Royalty | `family:burger@HEAD AND tag:gold>=2` | `PROC_TIME` `BRG` recipes process faster. | −10 % | SG_BURGER (r3) | −30 %/station | `MUT_039`, `MUT_258` | cook |
| `SYN_031` | Tentacle Tango | `tag:tentacle>=3` | `INTERACT` Assemble and plate interactions take less time. | −15 % | SG_PLATING (r2) | −30 %/action | `MUT_029`, `MUT_145` ×2 | cook |

#### 36.4.3 Combat Synergies

Abilities are referenced by canon `ABL_` ID (balance details in §36.6); statuses by `STS_` ID (§36.7). Every number below is halved in the Arena (§12.10 PvP normalization).

| ID | Name | Requirement (§12.10 grammar) | Effect | Magnitude [TUNABLE] | Stacking group (rank) | Cap (synergy layer) | Example qualifying parts | Context |
|---|---|---|---|---|---|---|---|---|
| `SYN_032` | Toast of the Town | `family:toaster@HEAD AND tag:fire>=2` | `ABILITY_MOD` `ABL_034` Toast Barrage launches one extra toast per volley. | +1 projectile | SG_TOAST (r2) | +1 tgt/proj · +2 hits · ±0.5 s | `MUT_010`, `MUT_171` | combat |
| `SYN_033` | Battering Ram | `tag:heavy@ARM>=2 AND tag:horn@HORNS` | `KNOCKBACK` Melee and horn abilities launch targets farther. | +12 % knockback | SG_KNOCK (r2) | +30 % | `MUT_148` ×2, `MUT_100` | combat |
| `SYN_034` | Heavyweight Division | `tag:heavy>=3` | `KNOCKBACK` + `STAT` Heavier hits. | +8 % knockback; +4 STR | SG_KNOCK (r1) | +30 %; +25/stat | `MUT_124`, `MUT_160` ×2 | combat |
| `SYN_035` | Sting Operation | `family:scorpion@TAIL AND tag:claw>=1` | `STATUS_DUR` `STS_STUN` from `ABL_009` Scorpion Tail Swipe lasts longer. | +25 % duration | SG_STUN (r2) | +30 %/status | `MUT_216`, `MUT_144` | combat |
| `SYN_036` | Nailed It | `family:hammerhead@HEAD AND tag:aquatic>=3` | `STATUS_DUR` `STS_STUN` from `ABL_054` Hammerhead Bash lasts longer. | +20 % duration | SG_STUN (r1) | +30 %/status | `MUT_025`, `MUT_119`, `MUT_214` | combat |
| `SYN_037` | Claws Out | `tag:claw>=2` | `ABILITY_DMG` Objects thrown by `ABL_017` Claw Grab & Toss and `ABL_005` Grab & Throw hit harder. | +15 % damage | SG_GRAB (r2) | +30 %/ability | `MUT_144`, `MUT_152` | combat |
| `SYN_038` | Full Crab Mode | `family:crab>=2 AND tag:armored>=1` | `GUARD` Block guard meter is larger (60 → 75). | +25 % guard | SG_GUARD (r2) | +30 % | `MUT_127`, `MUT_144` | combat |
| `SYN_039` | Spiky Situation | `family:porcupine@BACK AND tag:armored>=2` | `ABILITY_DMG` + `THORNS` `ABL_015` Spine Burst hits harder; melee attackers get a cartoon poke. | +20 %; 3 poke dmg | SG_THORNS (r2) | +30 %/ability; ≤ 4 dmg / 0.5 s | `MUT_243`, `MUT_122` | combat |
| `SYN_040` | Spiky Balloon | `family:pufferfish@TORSO AND family:porcupine@BACK` | `THORNS` + `STATUS_DUR` While `ABL_025` Puff Up is active, touching you hurts and the puff lasts longer. | 4 poke dmg; +20 % | SG_THORNS (r3) | ≤ 4 dmg / 0.5 s; +30 %/status | `MUT_129`, `MUT_243` | combat |
| `SYN_041` | Prickly Personality | `family:cactus@TORSO AND tag:armored>=2` | `ABILITY_DMG` `ABL_038` Cactus Hug hits harder (it is a very sincere hug). | +15 % damage | SG_THORNS (r1) | +30 %/ability | `MUT_132`, `MUT_244` | combat |
| `SYN_042` | Static Cling | `tag:electric>=2 AND tag:sticky>=1` | `STATUS_ADD` `STS_SHOCKED` you inflict also applies `STS_STICKY`. | 1 s rider | SG_ZAP (r1) | 1 rider ≤ 1 s | `MUT_155`, `MUT_253`, `MUT_142` | combat |
| `SYN_043` | Eel Be Back | `family:eel>=2` | `ABILITY_MOD` `ABL_014` Eel Zap chains to one extra target within 8 studs at 50 % damage. | +1 target | SG_ZAP (r3) | +1 tgt/proj · +2 hits · ±0.5 s | `MUT_159`, `MUT_253` | combat |
| `SYN_044` | Lightning Rod | `tag:electric+horn@HORNS AND tag:electric>=3` | `ABILITY_RANGE` `ABL_042` Thunder Clap radius is larger. | +20 % radius | SG_ZAP (r2) | +30 %/ability | `MUT_105`, `MUT_081`, `MUT_230` | combat |
| `SYN_045` | Storm Chaser | `family:storm>=3` | `STATUS_DUR` `STS_SHOCKED` you inflict lasts longer. | +20 % duration | SG_STORM (r2) | +30 %/status | `MUT_081`, `MUT_105`, `MUT_230` | combat |
| `SYN_046` | Hot Head | `tag:fire>=3 AND tag:fighter>=2` | `STATUS_DUR` `STS_TOASTY` (cartoon soot) you inflict lasts longer. | +25 % duration | SG_BURN (r2) | +30 %/status | `MUT_031`, `MUT_163`, `MUT_238` | combat |
| `SYN_047` | Full Dragon | `family:dragon>=4` | `ABILITY_RANGE` + `COOLDOWN` `ABL_018` Dragon Breath reaches farther and recharges faster. | +20 % range; −15 % cooldown | SG_DRAGON (r3) | +30 %/ability; −30 %/ability | `MUT_031`, `MUT_164`, `MUT_227`, `MUT_238` | combat |
| `SYN_048` | Cold Shoulder | `tag:ice>=3` | `STATUS_DUR` `STS_FROZEN` and `STS_SLOW` you inflict last longer. | +20 % duration | SG_CHILL (r2) | +30 %/status | `MUT_162`, `MUT_176`, `MUT_262` | combat |
| `SYN_049` | Fire and Ice Cream | `tag:fire>=2 AND tag:ice>=2` | `COOLDOWN` Using `ABL_018` or `ABL_043` cuts the remaining cooldown of `ABL_041`/`ABL_067` by 2 s, and vice versa (max once per 4 s). | 2 s refund | SG_TEMPER (r2) | −30 %/ability | `MUT_163`, `MUT_162`, `MUT_171`, `MUT_207` | combat |
| `SYN_050` | Elemental Mayhem | `category:ELEMENTAL>=3` | `STATUS_DUR` `STS_TOASTY`, `STS_FROZEN` and `STS_SHOCKED` you inflict last longer. | +10 % duration | SG_ELEMENT (r2) | +30 %/status | `MUT_034`, `MUT_162`, `MUT_230` | combat |
| `SYN_051` | Pack Leader | `family:wolf@HEAD AND tag:speed@LEG>=2` | `COOLDOWN` `ABL_004` Dodge Roll recharges faster (1.2 s → 1.02 s). | −15 % cooldown | SG_DODGE (r2) | −30 %/ability | `MUT_012`, `MUT_186` ×2 | combat, move |
| `SYN_052` | Cat-titude | `family:cat>=3` | `ABILITY_MOD` Dodge Roll invulnerability window is longer (0.25 s → 0.30 s); always lands on its feet. | +0.05 s i-frames | SG_DODGE (r1) | +1 tgt/proj · +2 hits · ±0.5 s | `MUT_002`, `MUT_041`, `MUT_211` | combat |
| `SYN_053` | Afterburner Roll | `tag:speed+fire@LEG>=2` | `ABILITY_MOD` Dodge Roll travels farther and leaves a harmless soot puff. | +20 % distance | SG_DODGE (r3) | +1 tgt/proj · +2 hits · ±0.5 s | `MUT_198` ×2 | combat, move |
| `SYN_054` | Kangaroo Court | `family:kangaroo>=2` | `ABILITY_DMG` + `COOLDOWN` `ABL_011` Kangaroo Kick hits harder and recharges faster. | +15 % damage; −10 % cooldown | SG_KICK (r2) | +30 %/ability; −30 %/ability | `MUT_149`, `MUT_184` | combat |
| `SYN_055` | Chomp Champ | `family:shark>=2` | `ABILITY_DMG` `ABL_019` Shark Chomp hits harder. | +15 % damage | SG_BITE (r2) | +30 %/ability | `MUT_011`, `MUT_062` | combat |
| `SYN_056` | Tank Engine | `tag:tank>=5` | `STAT` + `HP` Sturdier body. | +10 DEF; +20 HP | SG_TANKSTAT (r2) | +25/stat; +40 HP | `MUT_001`, `MUT_086`, `MUT_118`, `MUT_182` ×2 | combat |
| `SYN_057` | Absolute Unit | `tag:tank>=8` | `STAT` + `HP` + `KB_RESIST` Very sturdy body; harder to launch. | +15 DEF; +40 HP; −25 % knockback taken | SG_TANKSTAT (r3) | +25/stat; +40 HP; −30 % | `MUT_001`, `MUT_086`, `MUT_109`, `MUT_118`, `MUT_169`, `MUT_182` ×2, `MUT_205` | combat |
| `SYN_058` | Shell Shocked | `tag:armored>=4` | `DMG_TAKEN` Less damage taken. | −10 % damage taken | SG_ARMOR (r2) | −30 % | `MUT_023`, `MUT_122`, `MUT_244`, `MUT_267` | combat |
| `SYN_059` | Living Fortress | `tag:armored>=6 AND tag:heavy>=1` | `DMG_TAKEN` + `STATUS_RESIST` Much less damage taken; `STS_KNOCKDOWN` on you is shorter. | −15 %; −50 % knockdown | SG_ARMOR (r3) | −30 %; −50 %/status | `MUT_034`, `MUT_104`, `MUT_109`, `MUT_135`, `MUT_243`, `MUT_269` | combat |
| `SYN_060` | Glass-Jaw Slugger | `tag:fighter>=5 AND tag:armored<=0` | `MELEE_DMG` + `DMG_TAKEN` Melee hits harder, but you take more damage (shown as a red ▼ drawback). | +12 % melee; +10 % taken | SG_MELEE (r2) | +30 %; −30 % | `MUT_012`, `MUT_062`, `MUT_151` ×2, `MUT_216` | combat |
| `SYN_061` | Brawler's Instinct | `tag:fighter>=4` | `STAT` Flat stat points. | +6 STR | SG_FIGHTSTAT (r1) | +25/stat | `MUT_001`, `MUT_118`, `MUT_140` ×2 | combat |
| `SYN_062` | Final Boss Energy | `tag:fighter>=8` | `STAT` Flat stat points. | +12 STR, +6 DEF | SG_FIGHTSTAT (r3) | +25/stat | `MUT_032`, `MUT_067`, `MUT_076`, `MUT_108`, `MUT_163`, `MUT_164`, `MUT_227`, `MUT_194` | combat |
| `SYN_063` | Tongue Twister | `family:frog@MOUTH AND tag:sticky>=3` | `ABILITY_RANGE` `ABL_016` Tongue Yank reaches farther. | +20 % range | SG_YANK (r2) | +30 %/ability | `MUT_061`, `MUT_005`, `MUT_256` | combat |
| `SYN_064` | Sticky Situation | `tag:sticky>=4` | `STATUS_DUR` + `STATUS_IMMUNE` `STS_STICKY` you inflict lasts longer; you never slip on `STS_GREASY` puddles. | +25 % duration | SG_STICKY (r2) | +30 %/status; — | `MUT_005`, `MUT_142` ×2, `MUT_203` | combat, move |
| `SYN_065` | Stink Lines | `tag:stinky>=2` | `STATUS_DUR` + `ABILITY_RANGE` `STS_STINKY` lasts longer; `ABL_024` Skunk Cloud and `ABL_056` Stink Bomb clouds are wider. | +30 % duration; +15 % radius | SG_STINK (r3) | +30 %/status; +30 %/ability | `MUT_220`, `MUT_251` | combat |
| `SYN_066` | Feathered Fury | `category:BIRD>=4 AND tag:fighter>=1` | `ABILITY_DMG` `ABL_050` Beak Peck Combo and `ABL_051` Wing Buffet hit harder. | +12 % damage | SG_BIRD (r2) | +30 %/ability | `MUT_004`, `MUT_063`, `MUT_172`, `MUT_235` | combat |
| `SYN_067` | Dino-Might | `category:DINOSAUR>=3` | `STAT` Flat stat points. | +6 STR, +4 DEF | SG_DINO (r2) | +25/stat | `MUT_032`, `MUT_133`, `MUT_194` | combat |
| `SYN_068` | Tiny Arms, Big Dreams | `family:trex@HEAD AND family:trex@ARM>=2` | `ABILITY_MOD` + `SOCIAL` `ABL_002` Wallop charges faster (0.6 s → 0.45 s); unlocks the "Can't Reach" emote. | −0.15 s charge | SG_TREX (r2) | +1 tgt/proj · +2 hits · ±0.5 s; cosmetic | `MUT_032`, `MUT_161` ×2 | combat, social |
| `SYN_069` | Head-Butt Hall of Fame | `family:goat>=2 AND tag:horn>=2` | `COOLDOWN` `ABL_058` Goat Headbutt recharges faster. | −20 % cooldown | SG_HEADBUTT (r2) | −30 %/ability | `MUT_007`, `MUT_097` | combat |
| `SYN_070` | Bull in a China Shop | `family:bull@HORNS AND tag:heavy>=1` | `COOLDOWN` + `FURN_SAFE` `ABL_052` Horn Toss recharges faster; furniture you crash into takes half damage. | −15 % cooldown; −50 % self-crash damage | SG_HORNTOSS (r2) | −30 %/ability; −50 % | `MUT_100`, `MUT_124` | combat, repair |
| `SYN_071` | Rocket Science | `tag:robotic>=3 AND tag:fighter>=1` | `COOLDOWN` `ABL_031` Rocket Punch and `ABL_032` Laser Eyes recharge faster. | −12 % cooldown | SG_ROBOFIGHT (r2) | −30 %/ability | `MUT_078`, `MUT_154`, `MUT_123` | combat |
| `SYN_072` | Kraken Awakens | `family:kraken>=3` | `COOLDOWN` + `ABILITY_MOD` `ABL_060` Kraken Grasp recharges faster and grabs one extra target. | −15 % cooldown; +1 target | SG_KRAKEN (r3) | −30 %/ability; +1 tgt/proj · +2 hits · ±0.5 s | `MUT_038`, `MUT_137`, `MUT_165` | combat |
| `SYN_073` | Octo-Flurry Fury | `family:octopus@ARM>=2 AND tag:fighter>=2` | `ABILITY_MOD` `ABL_012` Octo-Flurry lands two extra slaps per flurry. | +2 hits | SG_FLURRY (r2) | +1 tgt/proj · +2 hits · ±0.5 s | `MUT_145` ×2, `MUT_001`, `MUT_118` | combat |
| `SYN_074` | Roll With It | `family:armadillo@TORSO AND tag:armored>=3` | `STATUS_DUR` + `DMG_TAKEN` `ABL_027` Armadillo Roll lasts longer; less damage taken while rolling. | +25 % duration; −10 % | SG_ROLL (r2) | +30 %/status; −30 % | `MUT_128`, `MUT_244`, `MUT_269` | combat |
| `SYN_075` | Boo-Fet Line | `family:ghost@BACK AND tag:light>=3` | `ABILITY_MOD` `ABL_059` Ghost Phase lasts longer. | +0.5 s | SG_PHASE (r2) | +1 tgt/proj · +2 hits · ±0.5 s | `MUT_252`, `MUT_233`, `MUT_180` | combat, move |
| `SYN_076` | Venus Fly-Snap | `family:flytrap@HEAD AND tag:grabby>=3` | `ABILITY_RANGE` `ABL_039` Flytrap Snap reaches farther. | +20 % range | SG_SNAP (r2) | +30 %/ability | `MUT_035`, `MUT_158`, `MUT_170` | combat |
| `SYN_077` | Banana Quake | `family:gorilla>=2` | `ABILITY_RANGE` `ABL_021` Ground Pound shockwave is wider. | +20 % radius | SG_POUND (r2) | +30 %/ability | `MUT_024`, `MUT_148` | combat |
| `SYN_078` | Spore-ts Fan | `family:mushroom@BACK AND category:PLANT>=3` | `STATUS_DUR` `STS_SLEEPY` from `ABL_040` Spore Puff lasts longer. | +20 % duration | SG_SPORE (r2) | +30 %/status | `MUT_248`, `MUT_093`, `MUT_177` | combat |
| `SYN_079` | Phoenix Rising | `family:phoenix>=2 AND tag:regen>=2` | `REVIVE` After a Seeing Stars KO you respawn at 80 % HP (not 60 %) and `STS_WOOZY` lasts 5 s (not 10 s). | +20 % respawn HP | SG_REVIVE (r3) | unique | `MUT_037`, `MUT_200` | combat |
| `SYN_080` | Lizard Brain Regrowth | `tag:regen>=3` | `REGEN` Heal over time once the In Combat flag clears. | +1.5 HP/s | SG_REGEN (r2) | 3 HP/s | `MUT_014`, `MUT_215`, `MUT_256` | combat |
| `SYN_081` | Photosynthesis Shift | `tag:plant>=3 AND tag:regen>=2` | `REGEN` Heal out of combat: +2.5 HP/s outdoors in Morph City by day, +1 HP/s otherwise. | +2.5 / +1 HP/s | SG_REGEN (r3) | 3 HP/s | `MUT_107`, `MUT_177`, `MUT_093` | combat |
| `SYN_082` | Moth to a Flame | `family:moth>=2 AND tag:glow>=1` | `STATUS_DUR` + `SOCIAL` `STS_BLINDED` from `ABL_057` Firefly Flash lasts longer; you glow in a 12-stud radius during `EVT_009` Blackout Night. | +20 % duration | SG_LIGHT (r2) | +30 %/status; cosmetic | `MUT_045`, `MUT_233` | combat, social |

#### 36.4.4 Repair & Cleaning Synergies

Repair speed, cleaning and fire safety. Repair targets and damage states follow §15.

| ID | Name | Requirement (§12.10 grammar) | Effect | Magnitude [TUNABLE] | Stacking group (rank) | Cap (synergy layer) | Example qualifying parts | Context |
|---|---|---|---|---|---|---|---|---|
| `SYN_083` | Handy-Spider | `tag:multi>=1 AND tag:repair>=3` | `REPAIR_SPD` All repairs are faster. | +10 % | SG_REPAIR (r2) | +30 %/class | `MUT_150`, `MUT_147`, `MUT_174` | repair |
| `SYN_084` | Industrial Strength | `family:robot@ARM>=2 AND tag:repair>=2` | `REPAIR_SPD` Appliance (station) repairs are faster. | +12 % | SG_REPAIR (r3) | +30 %/class | `MUT_153` ×2 | repair |
| `SYN_085` | Beaver Believer | `family:beaver>=2` | `REPAIR_SPD` Tables, chairs and booths repair faster (they respect the teeth). | +15 % | SG_WOODWORK (r2) | +30 %/class | `MUT_060`, `MUT_218` | repair |
| `SYN_086` | Mr. Fix-It-Bits | `tag:repair>=5` | `STAT` Flat stat points. | +10 REPAIR | SG_REPAIRSTAT (r2) | +25/stat | `MUT_022`, `MUT_060`, `MUT_123`, `MUT_147`, `MUT_218` | repair |
| `SYN_087` | Chief Engineer | `tag:repair>=8` | `STAT` + `REPAIR_COST` Flat stat points; cheaper repair materials. | +15 REPAIR; −10 % materials | SG_REPAIRSTAT (r3) | +25/stat; −10 % | `MUT_006`, `MUT_054`, `MUT_066`, `MUT_123`, `MUT_147`, `MUT_153`, `MUT_174`, `MUT_224` | repair |
| `SYN_088` | Robo-Mechanic | `category:ROBOT>=4 AND tag:repair>=2` | `COOLDOWN` `ABL_062` Repair Burst recharges faster. | −20 % cooldown | SG_REPAIRBURST (r2) | −30 %/ability | `MUT_022`, `MUT_044`, `MUT_123`, `MUT_187` | repair |
| `SYN_089` | Fire Marshal | `family:extinguisher@BACK AND (family:hydrant@HEAD OR tag:water>=2)` | `INTERACT` + `FURN_SAFE` Extinguishing station fires is twice as fast; burning appliances within 10 studs of you take half fire damage. | −50 % extinguish time | SG_CLEAN (r3) | −30 %/action; −50 % | `MUT_250`, `MUT_019` | repair, cook |
| `SYN_090` | Vacuum Sealed | `family:vacuum@MOUTH AND tag:multi>=1` | `INTERACT` Cleaning trash and spills takes less time. | −30 % | SG_CLEAN (r1) | −30 %/action | `MUT_066`, `MUT_150` | repair |
| `SYN_091` | Eight Eyes, Zero Mess | `family:spider>=3` | `ABILITY_RANGE` `ABL_068` Web Sweep cleans a wider radius. | +25 % radius | SG_WEB (r2) | +30 %/ability | `MUT_028`, `MUT_076`, `MUT_150` | repair |
| `SYN_092` | Mole Patrol | `family:mole>=2` | `ABILITY_MOD` `ABL_055` Mole Burrow travels farther and surfaces beside the nearest damaged object in range. | +20 % distance | SG_BURROW (r2) | +1 tgt/proj · +2 hits · ±0.5 s | `MUT_054`, `MUT_196` | repair, move |
| `SYN_093` | Cord Control | `family:cord@TAIL AND tag:electric>=2` | `REPAIR_SPD` Electric appliances (`STN_BLENDER`, `STN_MIXER`, `STN_DRINK`, `STN_ICECREAM`, `STN_INFUSER`) repair faster. | +20 % | SG_APPLIANCE (r2) | +30 %/class | `MUT_224`, `MUT_155` | repair |
| `SYN_094` | Rubble Rouser | `tag:heavy>=2 AND tag:repair>=2` | `REPAIR_SPD` Rebuild jobs (Destroyed → Pristine) finish faster. | +25 % | SG_REBUILD (r2) | +30 %/class | `MUT_148`, `MUT_153`, `MUT_189`, `MUT_060` | repair |
| `SYN_095` | Tool-Belt Tail | `family:monkey@TAIL AND tag:repair>=2` | `QOL` Starting a repair no longer makes you set down your carried item — it rides on your tail. | on/off | SG_TOOLBELT (r2) | — | `MUT_217`, `MUT_147`, `MUT_174` | repair |

#### 36.4.5 Movement Synergies

Walking, jumping, gliding and carrying. The hard WalkSpeed ceiling of 21 studs/s always applies (only dashes and dodges can briefly go faster).

| ID | Name | Requirement (§12.10 grammar) | Effect | Magnitude [TUNABLE] | Stacking group (rank) | Cap (synergy layer) | Example qualifying parts | Context |
|---|---|---|---|---|---|---|---|---|
| `SYN_096` | Fast Food, Faster Feet | `tag:speed@LEG>=2 AND tag:speed@FEET` | `MOVE_CTX` WalkSpeed bonus at all times. | +6 % WalkSpeed | SG_SPEED (r2) | +30 %; ≤ 21 studs/s | `MUT_186` ×2, `MUT_204` | move |
| `SYN_097` | Zoomies | `tag:speed>=6` | `STAT` Flat stat points. | +8 MOVE | SG_SPEEDSTAT (r2) | +25/stat | `MUT_002`, `MUT_085`, `MUT_186` ×2, `MUT_204`, `MUT_226` | move |
| `SYN_098` | Glide Waiter | `tag:flying@WINGS AND tag:light>=2` | `GLIDE` Fall speed is lower and a carried plate never spills while you are airborne. | −40 % fall speed | SG_GLIDE (r2) | −40 % | `MUT_235`, `MUT_121`, `MUT_180` | move |
| `SYN_099` | Jetpack Jockey | `tag:flying+speed@BACK AND tag:speed@LEG>=2` | `COOLDOWN` `ABL_069` Hover Serve recharges faster. | −15 % cooldown | SG_HOVER (r3) | −30 %/ability | `MUT_245`, `MUT_198` ×2 | move |
| `SYN_100` | Pogo Panic | `family:pogo@LEG>=2` | `JUMP` + `SOCIAL` Jump higher; every landing goes "boing". | +20 % JumpPower | SG_JUMP (r2) | +30 %; cosmetic | `MUT_191` ×2 | move, social |
| `SYN_101` | Cloud Nine | `family:cloud@LEG>=2 AND tag:flying>=1` | `JUMP` + `GLIDE` Jump higher and drift down gently. | +20 % JumpPower; −40 % fall speed | SG_JUMP (r3) | +30 %; −40 % | `MUT_197` ×2 | move |
| `SYN_102` | Fast Paws Delivery | `family:cheetah@LEG>=2 AND family:cat>=1` | `COOLDOWN` `ABL_063` Cheetah Dash recharges faster. | −15 % cooldown | SG_DASH (r2) | −30 %/ability | `MUT_186` ×2, `MUT_002` | move |
| `SYN_103` | Bee-Line Delivery | `family:bee@WINGS AND tag:speed>=3` | `MOVE_CTX` Faster while carrying a plate or tray. | +8 % WalkSpeed | SG_CARRYMOVE (r1) | +30 %; ≤ 21 studs/s | `MUT_236`, `MUT_126`, `MUT_180` | move, cook |
| `SYN_104` | Wheel Deal | `family:wheel@LEG AND tag:robotic>=3` | `MOVE_CTX` Faster while carrying anything. | +10 % WalkSpeed | SG_CARRYMOVE (r2) | +30 %; ≤ 21 studs/s | `MUT_192`, `MUT_022`, `MUT_123` | move, cook |
| `SYN_105` | Bog Standard | `category:AMPHIBIAN>=3` | `STATUS_IMMUNE` + `MOVE_CTX` Immune to `STS_SOAKED`; faster through flooded areas (`EVT_013` Sewer Flood, `DST_09`). | +6 % WalkSpeed | SG_AMPHIB (r2) | —; +30 %; ≤ 21 studs/s | `MUT_005`, `MUT_043`, `MUT_181` | move |
| `SYN_106` | Slime Slider | `family:slime@TORSO AND tag:sticky>=2` | `STATUS_IMMUNE` Immune to `STS_GREASY` and to `STS_SLOW` from spills. | on/off | SG_SLIDE (r2) | — | `MUT_134`, `MUT_256` | move, combat |

#### 36.4.6 Social, Luck & Show-Off Synergies

Charm, patience, tips, luck and pure flexing. `SOCIAL` effects are cosmetic only. Only these social-only synergies may count the FX slot.

| ID | Name | Requirement (§12.10 grammar) | Effect | Magnitude [TUNABLE] | Stacking group (rank) | Cap (synergy layer) | Example qualifying parts | Context |
|---|---|---|---|---|---|---|---|---|
| `SYN_107` | Four-Leaf Overload | `tag:luck>=5` | `STAT` Flat stat points. | +8 LUCK | SG_LUCKSTAT (r2) | +25/stat | `MUT_003`, `MUT_052`, `MUT_071`, `MUT_087`, `MUT_212` | social |
| `SYN_108` | Jackpot Junkie | `tag:luck>=9` | `STAT` Flat stat points. | +14 LUCK | SG_LUCKSTAT (r3) | +25/stat | `MUT_003`, `MUT_042`, `MUT_052`, `MUT_071`, `MUT_087`, `MUT_136`, `MUT_178`, `MUT_212`, `MUT_235` | social |
| `SYN_109` | Ninetail Fortune | `family:fox_spirit@TAIL AND tag:luck>=3` | `JACKPOT` Jackpot Tip chance increases. | +0.5 percentage points | SG_JACKPOT (r3) | +1.0 pp | `MUT_229`, `MUT_090`, `MUT_072` | social, cook |
| `SYN_110` | Who's a Good Chef | `family:dog>=3` | `STAT` Flat stat points. | +6 CHARM, +4 LUCK | SG_DOG (r2) | +25/stat | `MUT_003`, `MUT_052`, `MUT_212` | social |
| `SYN_111` | Peacock Strut | `family:peacock@TAIL AND tag:charm>=4` | `STATUS_DUR` + `TIP` `STS_CHARMED` from `ABL_029` Peacock Dazzle lasts longer; tips slightly larger. | +25 % duration; +5 % tips | SG_DAZZLE (r2) | +30 %/status; +30 % | `MUT_219`, `MUT_002`, `MUT_041`, `MUT_085` | social, combat |
| `SYN_112` | Snake Charmer | `family:snake>=2 AND tag:charm>=2` | `STATUS_DUR` + `STAT` `STS_CHARMED` you inflict lasts longer. | +15 % duration; +4 CHARM | SG_DAZZLE (r1) | +30 %/status; +25/stat | `MUT_020`, `MUT_222`, `MUT_085`, `MUT_202` | social |
| `SYN_113` | Heartthrob Hybrid | `tag:charm>=6` | `STAT` Flat stat points. | +8 CHARM | SG_CHARMSTAT (r2) | +25/stat | `MUT_002`, `MUT_041`, `MUT_085`, `MUT_202`, `MUT_211`, `MUT_232` | social |
| `SYN_114` | Oh Deer | `family:deer>=2` | `STAT` Flat stat points. | +6 CHARM | SG_CHARMSTAT (r1) | +25/stat | `MUT_013`, `MUT_098` | social |
| `SYN_115` | Celebrity Chef | `tag:charm>=4 AND tag:chef>=4` | `TIP` All tips you earn are larger. | +10 % tips | SG_TIP (r2) | +30 % | `MUT_013`, `MUT_047`, `MUT_063`, `MUT_085`, `MUT_102`, `MUT_156` | social, cook |
| `SYN_116` | Mer-Maître d' | `family:mermaid@TAIL AND tag:charm>=3` | `TIP` Tips on `SEA` recipes are larger. | +10 % tips | SG_TIP (r1) | +30 % | `MUT_225`, `MUT_183` ×2 | social, cook |
| `SYN_117` | Soothing Serenade | `family:fairy@WINGS AND tag:charm>=3` | `ABILITY_RANGE` + `ANGER` `ABL_065` Soothing Song radius larger; customers within 10 studs gain anger more slowly. | +20 % radius; −10 % anger gain | SG_SOOTHE (r2) | +30 %/ability; −30 % | `MUT_241`, `MUT_013`, `MUT_211` | social |
| `SYN_118` | Zen Garden | `category:PLANT>=4` | `ANGER` Customers within 12 studs gain anger more slowly (calming foliage). | −12 % anger gain | SG_SOOTHE (r1) | −30 % | `MUT_018`, `MUT_093`, `MUT_177`, `MUT_263` | social |
| `SYN_119` | Devilishly Polite | `family:demon@HORNS AND tag:charm>=3` | `ANGER` Customers' anger-escalation rolls against you are less likely to succeed. | ×0.9 escalation | SG_SOOTHE (r1) | −30 % | `MUT_108`, `MUT_013`, `MUT_041`, `MUT_211` | social |
| `SYN_120` | Loudmouth | `tag:loud>=3` | `ABILITY_RANGE` `ABL_006` Calm Down! reaches more customers. | +25 % radius | SG_SHOUT (r2) | +30 %/ability | `MUT_004`, `MUT_068`, `MUT_089` | social, combat |
| `SYN_121` | Majestic Pointy Friend | `family:unicorn@HORNS AND tag:glow>=2` | `PATIENCE` Customer patience is longer. | +8 % patience | SG_PATIENCE (r3) | +30 % | `MUT_101`, `MUT_241` | social |
| `SYN_122` | Too Cute to Yell At | `family:axolotl@HEAD AND tag:regen>=2` | `PATIENCE` Customer patience is longer. | +6 % patience | SG_PATIENCE (r2) | +30 % | `MUT_014`, `MUT_215` | social |
| `SYN_123` | Tall Order | `tag:tall>=2` | `PATIENCE` Customers can see you coming from across the room. | +5 % patience | SG_PATIENCE (r1) | +30 % | `MUT_015`, `MUT_110` | social |
| `SYN_124` | Now Showing: Your Order | `family:tv@HEAD AND family:moth>=1` | `ORDER_WAIT` Your TV face shows the order you are carrying; seated customers wait longer for their order to be taken. | +25 % ordering window | SG_TVMOTH (r2) | +30 % | `MUT_021`, `MUT_233` | social |
| `SYN_125` | Glow Up | `tag:glow>=3` | `SAT_BONUS` First-impression bonus for customers you seat or take orders from. | +2 satisfaction | SG_PRESENT (r1) | MutationBonus ≤ +10 | `MUT_021`, `MUT_233`, `MUT_270` | social |
| `SYN_126` | Close Encounters of the Fried Kind | `category:ALIEN>=3` | `PATIENCE` + `ABILITY_RANGE` `PER_029` Alien Tourist customers are more patient with you; `ABL_045` Tractor Beam reaches farther. | +15 % patience (PER_029); +15 % range | SG_ALIEN (r2) | +30 %; +30 %/ability | `MUT_033`, `MUT_166`, `MUT_210` | social, combat |
| `SYN_127` | Main Character Energy | `rarity:Epic>=3` | `SOCIAL` Arrival fanfare when you enter a restaurant; shimmering nameplate. | cosmetic | SG_SHOW (r1) | cosmetic | `MUT_031`, `MUT_164`, `MUT_238` | social |
| `SYN_128` | Museum Piece | `rarity:Legendary>=3` | `SOCIAL` Spotlight emote and a special entrance on the Showcase Stage (`BLD_22`). | cosmetic | SG_SHOW (r2) | cosmetic | `MUT_037`, `MUT_200`, `MUT_229` | social |
| `SYN_129` | Certified Mystery Morph | `distinct:category>=8` | `STAT` + `SOCIAL` A swirling "?" over your nameplate and a little luck. | +4 LUCK | SG_CHAOS (r2) | +25/stat; cosmetic | `MUT_021`, `MUT_076`, `MUT_085`, `MUT_119`, `MUT_145`, `MUT_180`, `MUT_215`, `MUT_232` | social |
| `SYN_130` | Purebred-ish | `distinct:family<=1 AND slot:ANY>=8` | `STAT` + `SOCIAL` Morphdex "Pure" stamp; customers respect the commitment. | +5 CHARM | SG_PURE (r2) | +25/stat; cosmetic | `MUT_001`, `MUT_086`, `MUT_118`, `MUT_140` ×2, `MUT_169`, `MUT_182` ×2 | social |
| `SYN_131` | Glitch in the Kitchen | `family:glitch@HEAD AND family:glitch@FX` | `SOCIAL` Your morph occasionally "lags" a few frames (cosmetic only); Morphdex photo gets a corrupted frame. | cosmetic | SG_GLITCH (r3) | cosmetic | `MUT_040`, `MUT_276` | social |
| `SYN_132` | Sparkle Motion | `family:sparkle@FX AND tag:charm>=4` | `SOCIAL` Emotes burst into sparkles; Morphdex photos get the "Sparkle" filter. | cosmetic | SG_SPARKLE (r1) | cosmetic | `MUT_272`, `MUT_002`, `MUT_085`, `MUT_202`, `MUT_211` | social |

#### 36.4.7 Category Synergies

One synergy per canon category that the families above do not already reward directly, so a pile of any one kind of creature always pays off a little.

| ID | Name | Requirement (§12.10 grammar) | Effect | Magnitude [TUNABLE] | Stacking group (rank) | Cap (synergy layer) | Example qualifying parts | Context |
|---|---|---|---|---|---|---|---|---|
| `SYN_133` | Bug Buffet | `category:INSECT>=3 AND tag:chef>=1` | `PERFECT_WIN` Wider Perfect window on dishes containing a `bug`-tagged ingredient (Bug Crunch & friends). | +10 % window | SG_BUGCOOK (r2) | +30 %/station | `MUT_026`, `MUT_126`, `MUT_236` | cook |
| `SYN_134` | Probe-ably Delicious | `tag:alien>=2 AND tag:chef>=1` | `PERFECT_WIN` Wider Perfect window on `ALN` recipes. | +8 % window | SG_ALIENCOOK (r1) | +30 %/station | `MUT_033`, `MUT_103`, `MUT_156` | cook |
| `SYN_135` | Warm-Blooded Workforce | `category:MAMMAL>=6` | `STAT` Flat stat points. | +4 EFFICIENCY, +4 CHARM | SG_MAMMAL (r1) | +25/stat | `MUT_001`, `MUT_086`, `MUT_118`, `MUT_140` ×2, `MUT_211` | cook, social |
| `SYN_136` | Arachnophile | `category:ARACHNID>=3` | `STATUS_DUR` `STS_STICKY` from `ABL_020` Web Shot lasts longer. | +20 % duration | SG_WEBSHOT (r2) | +30 %/status | `MUT_028`, `MUT_076`, `MUT_216` | combat |
| `SYN_137` | Cold-Blooded Calm | `category:REPTILE>=4` | `STATUS_RESIST` `STS_SLOW` and `STS_FROZEN` on you wear off sooner. | −30 % duration | SG_REPTILE (r2) | −50 %/status | `MUT_017`, `MUT_109`, `MUT_122`, `MUT_215` | combat |
| `SYN_138` | Kitchen Appliance Uprising | `category:OBJECT>=5` | `STAT` Flat stat points (you speak fluent toaster). | +6 REPAIR | SG_OBJECT (r2) | +25/stat | `MUT_010`, `MUT_047`, `MUT_066`, `MUT_156`, `MUT_171` | repair |
| `SYN_139` | Low Tide Hustle | `category:MARINE>=4` | `STATUS_IMMUNE` + `MOVE_CTX` Immune to `STS_SOAKED`; slightly faster on wet floors (spills, `EVT_013` Sewer Flood). | +4 % WalkSpeed | SG_AMPHIB (r1) | —; +30 %; ≤ 21 studs/s | `MUT_029`, `MUT_145` ×2, `MUT_206` | move |
| `SYN_140` | Fish Out of Water | `category:FISH>=4` | `STAT` Flat stat points (the flop is surprisingly fast). | +6 MOVE | SG_FISH (r2) | +25/stat | `MUT_009`, `MUT_046`, `MUT_119`, `MUT_214` | move |
| `SYN_141` | Legend Has It | `category:MYTHOLOGICAL>=4` | `STAT` Flat stat points; customers whisper about you. | +4 LUCK, +4 CHARM | SG_MYTH (r2) | +25/stat | `MUT_101`, `MUT_241`, `MUT_229`, `MUT_262` | social |

#### 36.4.8 Stacking Group Index

Groups with more than one member. Every other group has a single member and always stacks with the rest.

| Stacking group | Members (strongest first) | What they compete over |
|---|---|---|
| `SG_MULTICOOK` | `SYN_001` Eight-Arm Kitchen Nightmare (r3) > `SYN_005` Many Hands Make Light Lunch (r2) | cooking several items at once |
| `SG_KNOCK` | `SYN_002` Unbearable Impact (r3) > `SYN_033` Battering Ram (r2) > `SYN_034` Heavyweight Division (r1) | knockback |
| `SG_HEATCOOK` | `SYN_004` Dragon's Own Kitchen (r3) > `SYN_006` Oven Mitts Optional (r1) | heat-station window and burn grace |
| `SG_COLDCOOK` | `SYN_009` Walk-In Freezer (r3) > `SYN_008` Brain Freeze Brigade (r2) | cold-station speed |
| `SG_CHEFSTAT` | `SYN_011` Five-Star Freak Chef (r3) > `SYN_010` Sous-Chef Squad (r2) | flat cooking stats |
| `SG_CHOP` | `SYN_013` Mantis Mise en Place (r3) > `SYN_012` Utensil Drawer Energy (r2) > `SYN_014` Garden-to-Table (r1) | chopping & hand-prep speed |
| `SG_PRESENT` | `SYN_016` Mustache Maestro (r2) > `SYN_125` Glow Up (r1) | satisfaction bonus |
| `SG_TIP` | `SYN_017` Golden Touch Kitchen (r3) > `SYN_115` Celebrity Chef (r2) > `SYN_116` Mer-Maître d' (r1) | tip multiplier |
| `SG_SWEET` | `SYN_021` Hive-Five Bakery (r2) > `SYN_022` Sugar Rush Hour (r1) | dessert bonuses |
| `SG_CLEAN` | `SYN_089` Fire Marshal (r3) > `SYN_023` Self-Rinsing Kitchen (r2) > `SYN_090` Vacuum Sealed (r1) | cleaning & extinguishing |
| `SG_EFFICIENCY` | `SYN_027` Robot Accountant Mode (r3) > `SYN_026` Udderly Efficient (r2) | flat EFFICIENCY |
| `SG_ALIENCOOK` | `SYN_029` Galaxy Brain Gourmet (r3) > `SYN_028` Cosmic Cuisine (r2) > `SYN_134` Probe-ably Delicious (r1) | alien & legendary recipes |
| `SG_STUN` | `SYN_035` Sting Operation (r2) > `SYN_036` Nailed It (r1) | stun duration |
| `SG_THORNS` | `SYN_040` Spiky Balloon (r3) > `SYN_039` Spiky Situation (r2) > `SYN_041` Prickly Personality (r1) | retaliation pokes |
| `SG_ZAP` | `SYN_043` Eel Be Back (r3) > `SYN_044` Lightning Rod (r2) > `SYN_042` Static Cling (r1) | electric shocks |
| `SG_DODGE` | `SYN_053` Afterburner Roll (r3) > `SYN_051` Pack Leader (r2) > `SYN_052` Cat-titude (r1) | Dodge Roll |
| `SG_TANKSTAT` | `SYN_057` Absolute Unit (r3) > `SYN_056` Tank Engine (r2) | DEF & HP |
| `SG_ARMOR` | `SYN_059` Living Fortress (r3) > `SYN_058` Shell Shocked (r2) | damage reduction |
| `SG_FIGHTSTAT` | `SYN_062` Final Boss Energy (r3) > `SYN_061` Brawler's Instinct (r1) | flat STR |
| `SG_REGEN` | `SYN_081` Photosynthesis Shift (r3) > `SYN_080` Lizard Brain Regrowth (r2) | out-of-combat healing |
| `SG_REPAIR` | `SYN_084` Industrial Strength (r3) > `SYN_083` Handy-Spider (r2) | general repair speed |
| `SG_REPAIRSTAT` | `SYN_087` Chief Engineer (r3) > `SYN_086` Mr. Fix-It-Bits (r2) | flat REPAIR |
| `SG_JUMP` | `SYN_101` Cloud Nine (r3) > `SYN_100` Pogo Panic (r2) | jumping |
| `SG_CARRYMOVE` | `SYN_104` Wheel Deal (r2) > `SYN_103` Bee-Line Delivery (r1) | speed while carrying |
| `SG_AMPHIB` | `SYN_105` Bog Standard (r2) > `SYN_139` Low Tide Hustle (r1) | wet-floor movement |
| `SG_LUCKSTAT` | `SYN_108` Jackpot Junkie (r3) > `SYN_107` Four-Leaf Overload (r2) | flat LUCK |
| `SG_DAZZLE` | `SYN_111` Peacock Strut (r2) > `SYN_112` Snake Charmer (r1) | charm status |
| `SG_CHARMSTAT` | `SYN_113` Heartthrob Hybrid (r2) > `SYN_114` Oh Deer (r1) | flat CHARM |
| `SG_SOOTHE` | `SYN_117` Soothing Serenade (r2) > `SYN_118` Zen Garden (r1) > `SYN_119` Devilishly Polite (r1) | anger reduction |
| `SG_PATIENCE` | `SYN_121` Majestic Pointy Friend (r3) > `SYN_122` Too Cute to Yell At (r2) > `SYN_123` Tall Order (r1) | customer patience |
| `SG_SHOW` | `SYN_128` Museum Piece (r2) > `SYN_127` Main Character Energy (r1) | rarity flexing |

#### 36.4.9 Coverage Summary

| Measure | Value |
|---|---|
| Synergies | 141 (minimum required: 75 brief / 80 canon target) |
| By context (a synergy may list several) | cook 38 · combat 58 · repair 17 · move 19 · social 35 |
| Stacking groups | 100 (31 with several ranked members) |
| Requirement styles | family-in-slot, tag counts, combined tags (`+`), category counts, rarity counts, slot counts, distinct families/categories, `<=` drawback gates, OR-alternatives |
