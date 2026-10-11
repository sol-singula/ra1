# Gameplay Previews

52 mock in-game screenshots for **Mystery Morph Restaurant**. They are concept previews, not captures from a build:
an AI-generated 3D background plate (no text) with a GUI overlay built from the §24 UI/UX design tokens and real GDD data
(recipe names, prices, stats, offline-report numbers). Each caption cites the GDD section it illustrates.

| Path | Purpose |
|---|---|
| `NN.jpg` | Final 1920×1080 previews |
| `manifest.json` | Title, caption, GDD section and the background-plate prompt for each shot |
| `../tools/compose_previews.py`, `../tools/compose_previews_shots.py` | GUI overlay definitions (HTML/CSS) |
| `../tools/render_previews.js` | Renders overlays + plates to JPEG with headless Chromium |

Rebuild (plates are not committed; regenerate them from the prompts in `manifest.json` into a `plates/` folder named `NN.png`):

```bash
python3 gdd/tools/compose_previews.py --plates plates --html build/html --fonts node_modules/@fontsource
node gdd/tools/render_previews.js build/html gdd/previews [path/to/chromium]
```

Needs `puppeteer` plus `@fontsource/luckiest-guy` and `@fontsource/fredoka`.

## Onboarding

### 1. Title Screen

![Title Screen](01.jpg)

Main menu over Restaurant Row at dusk. *(§24.20)*

### 2. Tutorial: Nana Gristle

![Tutorial: Nana Gristle](02.jpg)

QST_TUT_001 — the cranky hologram great-aunt explains the shack. *(§32)*

### 3. Your First Mutation

![Your First Mutation](03.jpg)

QST_TUT_010 — pick one free starter part. *(§12, §32)*

### 4. Hire Help: Ollie the Octopus Intern

![Hire Help: Ollie the Octopus Intern](04.jpg)

QST_TUT_012 — first employee and the offline-income preview. *(§16, §17, §32)*

## Ordering & Cooking

### 5. Taking Orders

![Taking Orders](05.jpg)

Customers order with food-icon bubbles; patience rings track the wait. *(§8, §24.13)*

### 6. Cooking: The Grill

![Cooking: The Grill](06.jpg)

Flip at the right time: the Perfect window is 2 s at Lv1, wider with Cooking Quality. *(§5.4)*

### 7. Cooking: Chopping

![Cooking: Chopping](07.jpg)

Tap in rhythm: green = clean cut, yellow = 0.8, miss = 0.6. Octopus Arms chop two boards. *(§5.4)*

### 8. Cooking: Assembly

![Cooking: Assembly](08.jpg)

Stack order matters: one swap = ×0.85 quality. *(§5.4, §6.3)*

### 9. Cooking: The Fryer

![Cooking: The Fryer](09.jpg)

Basket timers and an overheat gauge; Lv5 'Ridiculous' fryers auto-salt. *(§5.3)*

### 10. Cooking: The Pizza Oven

![Cooking: The Pizza Oven](10.jpg)

Dial LOW / MED / HIGH per recipe; spin at halfway for an even bake. *(§5.3, §6.4)*

### 11. Cooking: The Soup Pot

![Cooking: The Soup Pot](11.jpg)

One pot = four servings. Pots boil over (no fire) if left too long. *(§5.3)*

### 12. Cooking: The Blender

![Cooking: The Blender](12.jpg)

Hold the lid! Past 100 % the smoothie turns MUSHY. *(§5.4)*

### 13. Ridiculous Modification: 'Make my drink angry'

![Ridiculous Modification: 'Make my drink angry'](13.jpg)

MOD_076 — joke request with a real mechanic: Agitate ×5 at the drink dispenser. *(§6.18)*

### 14. Cooking: Ice Cream Machine

![Cooking: Ice Cream Machine](14.jpg)

Swirl height scores the tower; too tall and it topples. *(§5.3)*

### 15. Serving & Satisfaction

![Serving & Satisfaction](15.jpg)

Satisfaction = accuracy, quality, cooking, wait, cleanliness and atmosphere (§10). *(§10)*

### 16. Kitchen Hazard: Grill Fire!

![Kitchen Hazard: Grill Fire!](16.jpg)

ON_FIRE 4 s after burning; extinguish, or Trunk Spray / Freeze Touch puts it out. *(§5.7)*

### 17. Co-op Kitchen

![Co-op Kitchen](17.jpg)

Friends cook in your restaurant; guests earn their own XP and MB paid by the game. *(§21)*

### 18. Late Game: Mutagen Infuser

![Late Game: Mutagen Infuser](18.jpg)

Mutation Cuisine: diners grow a random cosmetic part for 60 s (+10 'Whoa!'). *(§5.3, §6.16)*

### 19. Late Game: Anti-Gravity Wok

![Late Game: Anti-Gravity Wok](19.jpg)

Alien Cuisine: keep the ingredients airborne with FLOAT taps. *(§5.3, §6.15)*

## Customers

### 20. Dining Room at Tier 5

![Dining Room at Tier 5](20.jpg)

Mutant Family Restaurant: 12 seats, table service, employees run the floor. *(§8, §15)*

### 21. Ridiculous Modification: 'Exactly seventeen pickles'

![Ridiculous Modification: 'Exactly seventeen pickles'](21.jpg)

MOD_052 — a COUNT mod checked by the server on the Dish object. *(§6.18)*

### 22. The Food Critic

![The Food Critic](22.jpg)

Madame Fourchette scores five categories; a great review raises the star rating. *(§9 PER_004, §19)*

### 23. The Influencer

![The Influencer](23.jpg)

Vlogzilla's posts swing reputation ±0.1 ★ and bring follower customers. *(§9 PER_009)*

### 24. Party Pack Order

![Party Pack Order](24.jpg)

PER_016: one party, three tiny orders, one very sticky table. *(§9)*

### 25. The Mime Mantis

![The Mime Mantis](25.jpg)

PER_019 orders in pictograms only; Super Sniff (ABL_064) reveals hidden mods. *(§9)*

### 26. WRONG ORDER?! — A Tantrum Begins

![WRONG ORDER?! — A Tantrum Begins](26.jpg)

Anger climbs 0→6; each escalation past level 2 is a personality roll (§10). *(§10)*

## Chaos & Combat

### 27. Restaurant-Wide Chaos (Level 6)

![Restaurant-Wide Chaos (Level 6)](27.jpg)

Three angry customers ignite chaos: 45 s max, then a 3-minute cooldown. *(§10)*

### 28. Combat: Mutation Abilities

![Combat: Mutation Abilities](28.jpg)

Scorpion Tail Swipe (ABL_009) stuns; damage = base × STR × 100/(100+DEF). *(§11, §36.6)*

### 29. Emergent Chaos: The Chain Reaction

![Emergent Chaos: The Chain Reaction](29.jpg)

A thrown burger misses you, hits a bystander, and starts a whole new fight. *(§11.6)*

### 30. Security Guard at Work

![Security Guard at Work](30.jpg)

EMP_066 Rocco the Rhino intercepts angry customers (40 % Apology Payment). *(§16, §36.8)*

### 31. Seeing Stars (Knocked Out)

![Seeing Stars (Knocked Out)](31.jpg)

KO never costs mutations, items or currency: respawn in the kitchen with 60 % HP. *(§11.10)*

### 32. Repair Minigame

![Repair Minigame](32.jpg)

Damage states Pristine → Destroyed; Destroyed items rebuild for ≤ 25 % of price. *(§15.9)*

## Morphs & Progression

### 33. Customize Your Morph

![Customize Your Morph](33.jpg)

22 anatomy slots, rarity by color and shape, three free loadouts (Chef, Fighter, Repair). *(§13)*

### 34. Level Up & Get Stronger

![Level Up & Get Stronger](34.jpg)

2 stat points per level; the mockup's four headline stats with a 'More Stats' view. *(§14)*

### 35. Mutation Mart

![Mutation Mart](35.jpg)

Commons and Uncommons always stocked; Rares rotate. Prices from §36.3. *(§18 BLD_01, §36.3)*

### 36. Mutation Laboratory: Fusion

![Mutation Laboratory: Fusion](36.jpg)

Mythic fusion: 3 Legendaries from one route + 600 MS + 40 RT, deterministic output. *(§12.5, §18 BLD_11)*

### 37. Body Mods: Colors & Palettes

![Body Mods: Colors & Palettes](37.jpg)

Per-part tint palettes; cosmetic only, earnable or purchased. *(§13, §23)*

### 38. Synergy Unlocked

![Synergy Unlocked](38.jpg)

SYN_001 Eight-Arm Kitchen Nightmare: octopus arms + chef parts cook several items faster. *(§12.10, §36.4)*

## Restaurant Building & Staff

### 39. Restaurant Supplies

![Restaurant Supplies](39.jpg)

Stock appliances (Lv1 prices from §36.13) and upgrade paths Lv2–Lv5. *(§15, §36.13)*

### 40. Build Mode

![Build Mode](40.jpg)

2-stud grid, 90° rotation; every layout must keep the door connected to every seat. *(§15.5)*

### 41. Restaurant Upgrade: Tier 3 → Tier 4

![Restaurant Upgrade: Tier 3 → Tier 4](41.jpg)

Morph City Grill: 5,000 MB + City Hall permit; the Mutant Builders take 10 seconds. *(§15.2, §36.12)*

### 42. Recruitment Office

![Recruitment Office](42.jpg)

Candidates refresh every 4 h; rarity sets stats, wage and potential. *(§16.4, §36.8)*

### 43. Employee Roster

![Employee Roster](43.jpg)

Roles, efficiency, morale and energy; assign stations and review performance. *(§16.5)*

### 44. Welcome Back! (Offline Earnings)

![Welcome Back! (Offline Earnings)](44.jpg)

§17 Example C: TIER_05, Rare manager, 8 h with the long-absence taper. *(§17.10)*

### 45. Restaurant Hub: Finances

![Restaurant Hub: Finances](45.jpg)

Daily active vs offline income, best dishes, and bottleneck hints. *(§24.14)*

## Morph City

### 46. Morph City: Downtown

![Morph City: Downtown](46.jpg)

Walk, sprint (city-only ×1.35), Morph Metro or Pigeon Taxi between 10 districts. *(§18)*

### 47. City Map & Fast Travel

![City Map & Fast Travel](47.jpg)

Ten districts; the Sewers link via hidden manholes (dashed). *(§18.2, §24.17)*

### 48. Pigeon Taxi

![Pigeon Taxi](48.jpg)

Fly to any discovered district; the fare is charged on arrival. *(§18.4)*

### 49. City Event: Giant Rat King Attack

![City Event: Giant Rat King Attack](49.jpg)

EVT_007 every 4 h: the whole server defends the avenue together. *(§36.11)*

### 50. Mystery Market (Sewers)

![Mystery Market (Sewers)](50.jpg)

Weekly Legendary, daily Epics and Rares; odds-free, priced items only. *(§18, §36.10 BLD_13)*

### 51. Job Board & Quest Journal

![Job Board & Quest Journal](51.jpg)

157 quests: story chapters, dailies, weeklies and challenge lines. *(§20)*

### 52. Morph Arena (Opt-in PvP)

![Morph Arena (Opt-in PvP)](52.jpg)

Normalized stats, PvP damage ×0.7; never required for restaurant progression. *(§21.12)*
