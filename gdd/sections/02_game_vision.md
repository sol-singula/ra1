## 2. Game Vision

> **Owner:** A1 Vision & Onboarding. This section fixes *why* the game exists, *who* it is for, *how it feels*, and
> the design laws every other section must respect. The design laws (§2.9) are binding in the same way as canon
> constants: any feature that breaks a law needs a written exception in §38.

### 2.1 Player Fantasy

> *"I run the weirdest restaurant in the weirdest city, I can handle any customer, and every day I come back
> stronger, richer and more ridiculous-looking than before."*

The fantasy is built from seven roles the player switches between, often within a single minute. Each one maps
to a pillar in §3:

| Fantasy role | The player feels like… | Pillar | Example moment |
|---|---|---|---|
| The Chef | a kitchen virtuoso juggling grills and fryers | Cook | Flipping two patties at PERFECT while the soda pours itself |
| The Host | a charmer who reads every weirdo correctly | Serve | Spotting that the Picky Platypus (`PER_014`) wants exactly seventeen pickles |
| The Bouncer | an action hero in an apron | Survive | Blocking a handbag wallop, then calming down the Karenosaurus (`PER_001`) |
| The Collector | a mad scientist dressing up as a different monster every day | Morph | Swapping a Bear Arm (`MUT_140`) for a Kraken Tentacle Arm (`MUT_165`) and showing it off on Restaurant Row |
| The Builder | a restaurateur turning a shack into a palace | Build | Repairing a flipped table, then buying the booth that raises Atmosphere |
| The Explorer | a tourist in a city full of secrets | Explore | Throwing a paper menu off City Hall's roof into the fountain for a Secret part (`MUT_237`) |
| The Mogul | a boss whose staff work while they sleep | Earn | Opening the game to "WELCOME BACK, YOU WEIRDO!" and a pile of Morph Bucks |

### 2.2 Morph City: Setting and Lore

#### 2.2.1 The Great Blender Blunder (origin story)

One hundred and seventeen years ago, Morph City was called **Plainsville**. It was a perfectly normal town with a
petting zoo, a hardware store, and an annual picnic. For the 50th Plainsville Picnic, the mayor commissioned the
**World's Largest Blender** to make one enormous smoothie, so that everyone in town could share a cup and shake
hands with their neighbors.

Halfway through the blend, a fizzy, glittering space rock (scientists now call it **Morphite**) fell out of a clear
blue sky and plopped straight into the blender. The blender went *BLORP*. The smoothie turned purple, started
humming, and smelled faintly of grapes.

Everybody drank it anyway, because the samples were free.

Within seconds, every picnicker had swapped parts with whatever was nearest: the petting-zoo goat, the picnic
toaster, the hot-dog vendor's umbrella, a very surprised octopus from the aquarium tent, and a cheeseburger.
Nobody was hurt (Morphite doesn't do "hurt"; it does *tickle*). The parts were also **detachable**. Morphite parts
click on and off like building bricks, so the next morning half the town was trading heads over the garden fence.
Plainsville renamed itself **Morph City**, opened a **Mutation Mart** (`BLD_01`), and never looked back.

**The rules of the fiction** (writers and artists must keep these consistent):

1. **Every citizen is a mix of parts**, and parts swap painlessly. Changing parts is as normal as changing hats.
   Your "real" body is whatever you are wearing today. This is the in-world explanation for the whole morph
   system (§12, §13) and for customers being procedurally assembled (canon C11.1).
2. **Morphite makes feelings bigger.** A small annoyance becomes a medium tantrum, and a medium tantrum becomes a
   table flip. Everyone calms down afterwards, apologizes with a bow, and pays 40 %. This is the in-world reason
   for the anger ladder (canon C11.5) and the Apology Payment (canon C11.4).
3. **Nobody is ever really hurt.** Bonks produce cartoon stars, feathers and sauce splats. A defeated character is
   "Seeing Stars" or "Dizzy" and walks it off (canon C12.1). Objects get scuffed, cracked, broken and squashed into
   rubble piles, but always come back (canon C6).
4. **Morphite still falls.** Every so often the sky sprinkles a little more. That is the Mutation Meteor Shower
   (`EVT_006`), and it is why brand-new parts keep turning up (§33). The original blender stands in the Morph
   Museum (`BLD_16`), labeled *"Exhibit A. Do not press the button."*
5. **"Gross" food is never gross.** Eyeballs are gummy, tentacles are squishy calamari-style, bugs are crunchy
   candy "Bug Crunch," and slime is fruit jelly (canon C9). Leftover picnic smoothie is now sold as **Mutagen Goo**
   (`ING_MUTAGEN_GOO`). It is grape-flavored and makes you sparkle, which is why Mutation Cuisine gives customers
   a 60-second cosmetic mutation (canon C10).

#### 2.2.2 Your arrival

You step off the Morph Metro as a freshly assembled mutant with a plain torso, plain arms and legs, and one random
Common head (canon C13.8 starter morph). You have inherited your great-aunt **Nana Gristle**'s (`NPC_001`)
restaurant, the **Broken Burger Shack**. Nana was at the original picnic, which is how she ended up with a tortoise
head, a toaster torso and oven-mitt hands. She opened the shack that very afternoon ("Mutating works up an
appetite"). She is now 126 years old, which is young for a tortoise and old for a toaster. She has retired on the
*Sunny Shell Retirement Cruise* but refuses to stop managing, so she beams in as a **cranky hologram on the
shack's menu board**.

Three forces shape your career (story frame, canon C17.3; the campaign is written in §20):
- **Baron Von Bistro** (`NPC_003`), a snooty shark-headed rival who wants Restaurant Row for his luxury chain. You
  beat him by cooking, never by fighting, and he ends up a grumpy friend.
- **Madame Fourchette** (`NPC_016`), the giraffe-necked chief critic who holds the city's star ratings.
- **King Ratbeard** (`NPC_020`), the Sewer King who keeps "borrowing" ingredients from below.
- The finale is the **Legendary Chef Tournament** (`EVT_005`), hosted by **Chef Supreme Omnivora** (`NPC_029`).

### 2.3 Tone Bible

**The tone in one line:** *Saturday-morning cartoon slapstick, written by people who take their spreadsheets very
seriously.* The surface is loud, silly and generous. The rules underneath are precise and fair.

**Five tone principles**
1. **Absurd but sincere.** Characters believe completely in their ridiculous problems. The Karenosaurus is not
   "being funny"; she is genuinely outraged that the cheese is too cheesy.
2. **Escalation is the joke.** A small problem becomes a bigger problem in steps the player can watch and
   interrupt: a complaint, then a thrown pickle, then a flipped table.
3. **Slapstick, not violence.** Every impact is a cartoon: *BONK*, feathers, stars, confetti, soot puffs, sauce
   splats.
4. **Wordplay everywhere.** Names are puns or mash-ups (Pigeon Taxi, Morph Metro, Mutty McMutface, Sous-Chef
   Sniffles).
5. **Kindness underneath.** Nana is cranky but proud of you. Every tantrum ends in an apology. The game never
   laughs at the player for failing; it laughs *with* them.

**Do / Don't**

| Topic | Do | Don't |
|---|---|---|
| Customer complaints | "This soup is the wrong temperature. It should be FROZEN." | Insults about anyone's body, intelligence, family or background |
| Defeat | "You're Seeing Stars! Back in 4 s." / "Bonked!" | "You died," "killed," "dead," "K.O.'d to death" |
| Combat impact | Feathers, cartoon stars, sauce splats, a frying-pan *BONK* | Blood, wounds, realistic weapons, knives used as weapons |
| Gross-out food | Gummy eyeballs that wink, slime jelly that wobbles | Real insects, bodily fluids, vomit, bathroom humor |
| Mentor voice | "Burned it? Classic. I burned my first four hundred." | "You're bad at this." / sarcasm that humiliates |
| Spooky content | Bedsheet ghosts, a haunted toaster that pops toast dramatically (`PER_028`) | Jump scares with sudden loud audio, gore, real occult imagery |
| Romance | The Lovebird Jellyfish Couple (`PER_027`) holding tentacles under floating hearts | Kissing beyond a cartoon heart pop, dating talk |
| Parody | Pigeon Taxi, Morph Metro, "Le Fancy Fin" | Real brands, logos, celebrities, real people, copyrighted characters |
| The Karenosaurus | Jokes about the *behavior*: demanding the manager's manager's dinosaur | Any reference to gender, age, ethnicity or a real person |
| Money | "Cha-ching! +18 MB" | Real-world money language, gambling vocabulary ("jackpot" is allowed only for the canon Jackpot Tip) |

**Vocabulary list (UI and dialogue).** Use: *Seeing Stars, Dizzy, Bonked, Huff Points, Woozy, Apology Payment,
Peace Offering, Chef's Kiss, Sold Out, Closed for the Day!*. Never use: *die, kill, dead, blood, murder, weapon,
gamble, loot box*.

**Writing rules [TUNABLE].** Dialogue bubbles are ≤ 90 characters per line and at most 2 lines on screen. Core
instructions are written at reading level ≈ grade 3–5 and always paired with an icon or input glyph. Jokes live in
flavor text and dialogue. Instructions stay plain ("Hold Block!"), and the joke comes after ("…she swings that
purse like a pro").

### 2.4 Audience Segments

| | **Gigglers & Collectors (8–11)** | **Optimizers & Show-Offs (12–16)** |
|---|---|---|
| Core motivations | Silly visuals, collecting, simple clear goals, power fantasy, laughing with friends | Mastery, min-max builds, rare and Secret discoveries, status, competition, co-op teamwork |
| What they love here | Funny morphs, tantrum animations, flipping tables (and fixing them), Ollie's pickles | Synergies (§12.10), employee optimization, Perfect streaks, arena seasons, 100-part collection |
| Friction risks | Reading load, timing-window frustration, losing a fight, getting lost in the city | Repetition, solved metas, running out of goals, feeling "babysat" |
| Design responses | Icon + glyph prompts and voiced barks; Tutorial Assist (§32); generous windows at low tiers; failure is funny and free (§2.9 L4); auto-target abilities on touch (§24); guided trail to objectives | Tag-based synergies so new parts join old builds; Secret conditions (canon C13.8); later tiers tighten patience and add modifications; opt-in arena (§21); leaderboards that cannot be bought; skip after `QST_TUT_003` |
| Session shape | Short bursts (5–15 min), many check-ins | Long sessions (30–60 min), planning between sessions |

**Cross-segment groups:** siblings and friends playing co-op in one restaurant (§21), and **parents** who need to
trust the game (no paid randomness, kid-safe tone, no free-text chat beyond Roblox's own chat).

### 2.5 "Everything Should Be Just a Little Bit Ridiculous", System by System

| System | Ridiculous surface layer | Rigorous underlying layer | Spec |
|---|---|---|---|
| Cooking | Screaming cheese, patties that sizzle louder when you ignore them, fryers that catch (cartoon) fire | Heat timing model with T_ready, a Perfect window, T_burn, ON_FIRE at +4 s; 5 quality grades (canon C8) | §5 |
| Recipes | "Pizza With Only Crust," "The Unreasonably Large Burger" | Price curve `10 × 1.05^(L−1)` × difficulty × category; ingredient cost 25–40 % (canon C4.2) | §6, §7 |
| Orders | "I'm allergic to circles," "make my drink angry" | Every modification maps to a station action or a declared joke-request mechanic; no impossible orders | §6.18 |
| Customers | Karenosaurus, Sleepy Sloth-Rocket, Haunted Toaster | Patience formula (canon C11.2); satisfaction weights (C11.3); anger meter 0–100 with escalation rolls (C11.5) | §8–§10 |
| Combat | Handbag wallops, pan bonks, flung soggy pickles | Guard meter 60, 0.25 s i-frames, server hit validation, 6 s In-Combat flag (canon C12.1) | §11 |
| Mutations | Toaster heads, noodle necks, Golden Burger Heads | Stat budgets by rarity × slot weight × level; tag-based synergies with caps (canon C13.4–C13.5) | §12, §36.3 |
| Morph look | Mismatched legs give a wobbly gait | R15 skin-over-rig, named attachments, ≤ 40 MeshParts / 15,000 triangles (canon C13.7) | §13, §25 |
| Restaurant | A shack with a wobbly sign; tables flip spectacularly | 5 damage states by durability; placement validation keeps every seat reachable (canon C6, E10) | §15 |
| Employees | Sloth dishwasher, Octopus intern who pickles everything | Efficiency formula from role stats, morale and energy (canon C14.2) | §16 |
| Offline | "Your Sloth Dishwasher washed exactly four plates" | Deterministic seeded simulation, caps, atomic report, idempotent claims (canon C15, E11) | §17 |
| City | Pigeon Taxi, a Sewer King, a fountain you throw menus into | District unlock levels, travel costs, streaming budgets (canon C16) | §18, §30 |
| Economy | "Morph Bucks," Jackpot Tips | Single-writer `EconomyService`, sinks and sources, 50/50 spend intent (canon C4) | §22 |
| Progression | "Level up! …from surviving a dinosaur" | `XPReq(L) = round((180 + 30·L) × 1.045^(L−1))` (canon C5.1) | §14 |
| UI | "WELCOME BACK, YOU WEIRDO!" | Color-independent rarity shapes, readable HUD during chaos, input-adaptive glyphs | §24 |
| Tutorial | A cranky hologram great-aunt on a menu board | Sequential persisted steps, funnel analytics, resume and skip rules | §32 |

### 2.6 What This Game Is NOT

- **Not a horror or gore game.** Spooky events are silly. No blood, wounds or death (canon C0.7).
- **Not a fighting game first.** Combat is a pressure valve inside a restaurant game. A player who prefers peace
  can de-escalate with `ABL_006` Calm Down!, Peace Offerings, Security Guards (`ROLE_SECURITY`) and Perfect food.
  PvP exists only in the opt-in arena (§21).
- **Not pay-to-win, and not a loot-box game.** Robux buy cosmetics only. Capsules are earnable and their odds are
  disclosed (canon C4.7).
- **Not an idle clicker.** Offline income is capped (2–24 h, canon C14.3) and produces MB, MS and occasional
  crates, never XP, Research Tokens, recipes or story progress. Active play is always the fastest way forward.
- **Not a realistic cooking simulator.** There are no temperatures in degrees and no knife technique; timing rings
  and windows replace realism.
- **Not a freeform building sandbox.** Furniture snaps to a validated grid that guarantees paths (canon E10).
- **Not mean.** Humor never punches down at players, real people or real groups.
- **Not a reskin treadmill.** Every mutation part changes gameplay (stats, ability, passive, carry or movement),
  except FX parts, which are pure flavor by design (canon C13.4).

### 2.7 Mechanical Inspirations (genres and mechanics only, nothing copied)

| Genre | Mechanic we study | How Mystery Morph Restaurant adapts it | What we deliberately avoid |
|---|---|---|---|
| Co-op kitchen-chaos games | Station processing, timed hand-offs, ticket rail, burn and fire hazards | Single-button station interactions that work on mobile, forgiving low-tier windows, solo-viable kitchens, co-op as a bonus | Precision movement puzzles that need couch voice-chat to coordinate |
| Roguelite restaurant builders | Layout matters; automation replaces repetitive work | Employees (with personalities and incidents) instead of conveyor belts; validated grid placement | Run resets that wipe progress |
| First-person cooking simulators | Tactile, satisfying preparation actions | Chop timing rings, grill flips, plating flourishes at Roblox-friendly fidelity | Realistic recipes, tedious cleaning chores |
| Roblox restaurant tycoons | Tier upgrades, plots on a shared street, idle income | A visibly upgrading façade on Restaurant Row; morph-centric spending; emergent chaos | Buy-a-button progression with no skill expression |
| Creature collectors | Rarity tiers, a collection book, discovery | Collect *parts*, not creatures; the Morph Museum (`BLD_16`) as the collection book; Secret discovery conditions | Paid random rolls |
| Character creators and dress-up games | Modular slots, palettes, saved outfits | 22 anatomy slots, 3+ loadouts (Chef / Fighter / Repair) whose stats matter | Purely cosmetic choices with no gameplay identity |
| Beat-'em-up brawlers | Light combos, block, dodge, crowd control | Short cartoon brawls with an apology ending; abilities come from your body parts | Long fights, difficulty spikes, gore |
| Idle and incremental games | Offline report, managers who extend caps | Deterministic offline simulation with funny incidents; manager caps (canon C14.3) | Offline income exceeding active income per hour (≤ 60 %, canon C15) |
| Systemic sandbox games | Simple rules that collide into stories | Thrown-food arcs, anger contagion (`INSTIGATOR`), destructible furniture | Unbounded physics (props capped at 30, canon C3) |

### 2.8 The Player's Arc: Broken Burger Shack → Legendary Mutation Restaurant

The arc is ten chapters, one per tier (canon C17.3). Entry levels, hours and costs are canon (C4.4, C6). The story
beats are allusions only, since §20 writes the campaign.

| Ch. | Tier | Name | Entry level | Cum. active h | Tier cost (MB) | What the player feels | Morph state (typical) |
|---|---|---|---|---|---|---|---|
| 1 | TIER_01 | Broken Burger Shack | 1 | 0 | start | "I can barely flip a burger, and a dinosaur flipped my table." | Starter body + 1 tutorial part |
| 2 | TIER_02 | Tiny Mutation Diner | 5 | 1 | 1,000 | "I have a real menu and an octopus employee." | 2–3 Common/Uncommon swaps |
| 3 | TIER_03 | Neighborhood Freak Café | 10 | 3 | 2,000 | "Table service! Waiters! The critic noticed me." | First full Chef loadout |
| 4 | TIER_04 | Morph City Grill | 18 | 7 | 5,000 | "City Hall gave me a permit; the Baron is worried." | First Rare part; Fighter loadout |
| 5 | TIER_05 | Mutant Family Restaurant | 26 | 14 | 15,000 | "Aliens eat here now" (Alien Cuisine, chapter 5, Zorp `NPC_027`). | First Epic; first synergy build |
| 6 | TIER_06 | Monster Food Court | 35 | 25 | 40,000 | "My staff runs a shift for 8 hours without me." | Epic upgrades at Lv4+ using RT |
| 7 | TIER_07 | Mutation Megadiner | 45 | 40 | 100,000 | "I'm famous on Restaurant Row." | First Legendary within reach |
| 8 | TIER_08 | Luxury Freak Restaurant | 56 | 60 | 225,000 | "Madame Fourchette gives me stars." | Legendary build, chasing Secrets |
| 9 | TIER_09 | Morph City Food Palace | 68 | 85 | 525,000 | "The Baron asks *me* for advice." | Mythic fusion in sight |
| 10 | TIER_10 | Legendary Mutation Restaurant | 80 | 120 | 1,500,000 | "I won the Legendary Chef Tournament (`EVT_005`)." | Mythic or Secret signature morph |

Note: C4.4 lists the hour at which each tier becomes *affordable*. The level requirement (C5.1 pacing) arrives
1–4 h later for TIER_04–TIER_09, so the level gate binds and the surplus MB naturally flows into mutations, as
Law L1 intends.

### 2.9 Design Laws (the Creative Director Notes, formalized)

| Law | Statement | Why | How it is enforced and verified |
|---|---|---|---|
| L1 Morph is the destination | Mutations are the center of the economy and retention. The restaurant is how you earn; mutations are what you want. | A restaurant has a finite set of meaningful upgrades; 280 parts in 22 slots do not. | Every tier unlock introduces ≥ 1 new reason to want a part (a slot use, a recipe that rewards a tag, an ability counter). Telemetry: ≥ 40 % of cumulative MB spent on mutation acquisition and upgrades by the D30 median player [TUNABLE] (§31). |
| L2 Chaos is emergent | An unhappy customer must be able to start a chain reaction, not just play an angry animation. | Chain reactions are what set this game apart from conventional tycoons. | Every hostile action (thrown food, charge, slam, anger aura) can affect ≥ 1 *other* actor or object. Thrown food that hits a customer adds +25 anger × sensitivity (canon C11.5). QA must reproduce ≥ 3 distinct chain paths per tier band (§35). |
| L3 Ridiculous surface, rigorous rules | Every joke sits on a defined rule; no mechanic is "random nonsense". | Players forgive absurdity, not unfairness. | Every joke request in §6.18 lists its mechanic. Every incident in §36.9 lists its formula effect. Doc review rejects any un-specified "funny" behavior. |
| L4 Failure is funny, not devastating | No permanent loss from failure. Recovery takes at most a couple of minutes of normal play. | Kids quit after harsh losses; slapstick should be enjoyable to watch. | KO never removes mutations, items or currency (canon C12.1). Destroyed furniture is rebuilt for ≤ 25 % of price (canon C6). Balance never goes negative (canon E8). Median MB cost of a full brawl ≤ 5 min of that tier's net income [TUNABLE]. |
| L5 Offline keeps the loop turning, never replaces it | Employees move progression while you're away. Active play stays the fastest path. | "A reason to return every day" without making play optional. | Offline net/h ≤ 60 % of active net/h at the same tier (canon C15). Offline grants no XP, RT, recipes or story. Offline share of MB income is a KPI (§1.7). |
| L6 Never pay for power or randomness | Robux buy looks, never strength, currency, staff, caps or chances. | Fairness and trust (players and parents); Roblox policy. | §23 product audit (AC-01-02). Capsules are earnable only, with odds shown and pity (canon C4.7). |
| L7 Readable in chaos | The player can always tell the next action within 2 s, even mid-brawl. | Chaos is fun only when it is legible. | HUD priority rules (§24). Status is never color-only (canon C13.3 shapes). Playtest metric: ≥ 90 % of testers name the next objective when the game is paused at a random moment [TUNABLE]. |
| L8 Every session moves something forward | Even a 5-minute session advances at least one visible bar. | Short sessions dominate on mobile. | A 5-minute session at any tier earns ≥ 1 of: a level-up, a quest step, a mutation affordable or upgraded, a tier-progress increase ≥ 5 %, or a repair completed (§4.2). |
| L9 Kid-safe always | Content suits ages 8–16 everywhere, including user-visible generated text. | Audience and platform. | Tone bible (§2.3). Names generated from procedural parts pass a blocklist. Morph names use Roblox text filtering (`TextService:FilterStringAsync`) (§24, §29). |

### 2.10 Acceptance Criteria

- **AC-02-01:** All player-facing strings pass the §2.3 vocabulary check: zero occurrences of the "never use" list in the localization tables (automated grep in CI).
- **AC-02-02:** The origin story (§2.2.1) is presented in-game within the first 30 minutes (Nana's line in `QST_TUT_001` plus the Morph Museum plaque), and appears in no other contradictory form in §18–§20.
- **AC-02-03:** Every row of the §2.5 table names a spec section that contains the stated rigorous rule (doc review checklist).
- **AC-02-04:** Each design law L1–L9 has at least one automated test, telemetry query or review checklist item referenced in §35 or §31 before beta.
- **AC-02-05:** In a 20-tester playtest (10 aged 8–11, 10 aged 12–16), ≥ 80 % describe the game as "funny" and ≥ 70 % can explain why they want mutations (L1) after one 30-minute session [TUNABLE].
