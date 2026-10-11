### 36.15 Sound Library

Owner: A16 Art & Audio. This appendix is the **only place `SFX_` and `MUS_` ids are defined**. Bus structure,
3D rolloff, ducking, the voice budget, adaptive music and accessibility are specified in §26. Other sections describe
audio in words and reference these ids.

#### 36.15.1 Conventions

| Column | Meaning |
|---|---|
| Category | kitchen · customer voice · creature · combat · destruction · repair · currency · level-up · mutation · UI · city ambience · event · stinger · restaurant music (and other `MUS_` music) |
| Trigger | The game event that plays the sound. It is often a `KeyframeMarker` on an `ANM_` track (§36.14) or a replicated state change. |
| Variations | Number of distinct takes. Playback picks at random with no immediate repeat, plus pitch jitter (default `PlaybackSpeed` 0.96–1.04). |
| 2D/3D | **3D** = `Sound` parented to a part or attachment (positional). **2D** = parented to `SoundService` or played with `SoundService:PlayLocalSound`. **2D/3D** = 2D for the acting player, 3D for everyone else. |
| Loop | `Sound.Looped`. Loops stop on state exit with a 0.15 s fade. |
| SoundGroup | Bus under Master: `Music`, `SFX`, `Alerts`, `Voice`, `UI`, `Ambience` (§26). `Alerts` holds the kitchen-warning cues behind the separate "Kitchen Alerts" slider (§5, §24): `SFX_009`, `SFX_022`, `SFX_029`, `SFX_030`, `SFX_032`, `SFX_157`. It is never ducked below −6 dB. |
| Priority | Voice-budget class (§26). **P1** critical gameplay cue, never culled. **P2** the player's own actions and hits on them. **P3** normal. **P4** low (other players' kitchens, crowd one-shots). **Bed** = music or ambience bed managed by its director, outside the one-shot budget. |

**Content rules (binding for every row):**
- All audio is original (studio-recorded Foley, synthesized, or composed for the game). No real songs, no brand
  jingles, no samples of real people.
- Customer "voices" are **gibberish only**. No intelligible words in any language.
- Pain is never voiced as pain: hits use comic yelps, "bonk" and "boing". Fire is cartoon crackle.
- Spooky event cues (EVT_009, EVT_029) are silly-spooky (theremin, kazoo, xylophone bones), never horror.

| Category | ID range | Rows |
|---|---|---|
| Kitchen | `SFX_001`–`SFX_035` | 35 |
| Customer voice | `SFX_036`–`SFX_062` | 27 |
| Creature | `SFX_063`–`SFX_077` | 15 |
| Combat | `SFX_078`–`SFX_110` | 33 |
| Destruction | `SFX_111`–`SFX_118` | 8 |
| Repair | `SFX_119`–`SFX_125` | 7 |
| Currency | `SFX_126`–`SFX_134` | 9 |
| Level-up | `SFX_135`–`SFX_139` | 5 |
| Mutation | `SFX_140`–`SFX_148` | 9 |
| UI | `SFX_149`–`SFX_162` | 14 |
| City ambience | `SFX_163`–`SFX_178` | 16 |
| Event | `SFX_179`–`SFX_189` | 11 |
| Stinger | `SFX_190`–`SFX_201` | 12 |
| Music (restaurant, city, arena, events, menus) | `MUS_001`–`MUS_036` | 36 |
| **Total** | | **237** |

#### 36.15.2 Kitchen

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_001` | Chop – clean cut | kitchen | Crisp "thock" with a veggie crunch. | `ANM_010` `Impact`, green-zone tap | 6 | 2D/3D | No | SFX | P2 |
| `SFX_002` | Chop – off-beat thud | kitchen | Duller, lower thud for yellow and miss taps. | Yellow or miss tap | 4 | 2D/3D | No | SFX | P2 |
| `SFX_003` | Mushy squelch | kitchen | Wet squish plus a tiny sad-trombone blip. | Over-chop → MUSHY | 2 | 2D/3D | No | SFX | P2 |
| `SFX_004` | Grill sizzle loop | kitchen | Bright sizzle bed. Volume scales with occupied grill slots (0.4 per slot). | STN_GRILL occupied | 3 | 3D | Yes | SFX | P3 |
| `SFX_005` | Grill flip | kitchen | "Fwip" then a sizzle swell. | `ANM_011` `Sfx` | 4 | 3D | No | SFX | P2 |
| `SFX_006` | Fryer dunk | kitchen | Bubbly "blorp-sssh". | `ANM_012` `Vfx` | 3 | 3D | No | SFX | P2 |
| `SFX_007` | Fryer bubble loop | kitchen | Rolling oil-bubble bed. | STN_FRYER active | 2 | 3D | Yes | SFX | P3 |
| `SFX_008` | Oven door | kitchen | Creak open, clunk shut. | `ANM_013`; unload | 3 | 3D | No | SFX | P3 |
| `SFX_009` | Ready ding | kitchen | Two-tone bell. Each heat station has its own pitch so ears can find it. | Heat item reaches T_ready | 6 (per station) | 3D | No | Alerts | P2 |
| `SFX_010` | Pizza peel swoosh | kitchen | Wooden scrape plus a whoosh. | `ANM_026` | 3 | 3D | No | SFX | P3 |
| `SFX_011` | Sauté toss sizzle | kitchen | Pan rattle and a sizzle burst. | `ANM_024` `Impact` | 4 | 3D | No | SFX | P3 |
| `SFX_012` | Pot bubble loop | kitchen | Thick blub-blub whose pitch drops as it nears done. | STN_SOUP_POT / STN_STOVE boil | 2 | 3D | Yes | SFX | P4 |
| `SFX_013` | Steam hiss | kitchen | Pressure hiss plus a puff. | `ANM_027`; STN_STEAMER done | 3 | 3D | No | SFX | P3 |
| `SFX_014` | Blender whirr loop | kitchen | Motor whine. `PlaybackSpeed` ramps 0.9→1.3 with progress. | STN_BLENDER active | 2 | 3D | Yes | SFX | P3 |
| `SFX_015` | Mixer whisk loop | kitchen | Rhythmic whisk clatter. | STN_MIXER; hand mix at STN_PREP | 2 | 3D | Yes | SFX | P4 |
| `SFX_016` | Drink pour & fizz | kitchen | Glug plus carbonation crackle. | `ANM_020` hold | 3 | 3D | Yes | SFX | P3 |
| `SFX_017` | Ice cream swirl | kitchen | Soft-serve "fwirrp" and a scoop thunk. | `ANM_025` | 3 | 3D | No | SFX | P3 |
| `SFX_018` | Freeze crackle | kitchen | Icy crackle and tinkle. | FREEZE done; `ANM_032`; `ABL_067` | 3 | 3D | No | SFX | P3 |
| `SFX_019` | Fridge & pantry grab | kitchen | Door pop, rustle, grab. | `ANM_031` | 5 | 3D | No | SFX | P4 |
| `SFX_020` | Stack plop | kitchen | Soft plop that rises +1 semitone per layer (major scale). | `ANM_017` per layer | 4 | 2D/3D | No | SFX | P2 |
| `SFX_021` | Plate & garnish clink | kitchen | Ceramic clink plus a sprinkle shimmer. | `ANM_018` | 3 | 3D | No | SFX | P3 |
| `SFX_022` | Order-up bell | kitchen | Counter bell "ding!". | Dish placed on STN_WINDOW; `ANM_230` | 2 | 3D | No | Alerts | P2 |
| `SFX_023` | Dish scrub loop | kitchen | Suds squeak and splash. | `ANM_021`, `ANM_235` | 2 | 3D | Yes | SFX | P4 |
| `SFX_024` | Trash thunk | kitchen | Lid flap and a thunk. A miss plays a clatter. | `ANM_023` | 4 | 3D | No | SFX | P4 |
| `SFX_025` | Mop squeak loop | kitchen | Wet rubbery squeaks. | `ANM_022` | 2 | 3D | Yes | SFX | P4 |
| `SFX_026` | Delivery honk & thump | kitchen | Toy-horn honk, then a crate thump. | Crate arrives at STN_DELIVERY | 2 | 3D | No | SFX | P3 |
| `SFX_027` | Mutagen pump gloop | kitchen | Bellows wheeze and a glowing gloop. | `ANM_028`; STN_INFUSER | 3 | 3D | Yes | SFX | P3 |
| `SFX_028` | Anti-grav hum | kitchen | Wobbly theremin hum and a whoosh. | STN_ANTIGRAV; `ANM_029` | 2 | 3D | Yes | SFX | P3 |
| `SFX_029` | Perfect window ting | kitchen | Bright "ting" paired with the ✓ visual. | Heat item enters Perfect window | 1 | 2D/3D | No | Alerts | P1 |
| `SFX_030` | Burn warning ticks | kitchen | Accelerating kettle "tss-tss" ticks. | Last 3 s before T_burn | 1 | 2D/3D | Yes | Alerts | P1 |
| `SFX_031` | Burnt poof | kitchen | Soot "pfoomf" plus a cough. | Item becomes BURNED; `ANM_035` | 2 | 3D | No | SFX | P2 |
| `SFX_032` | Station fire loop | kitchen | Cartoon crackle with a comedic "woo-woo" alarm. | ON_FIRE; `ANM_187` | 1 | 3D | Yes | Alerts | P1 |
| `SFX_033` | Extinguisher foam | kitchen | Foam whoosh, then a fizzle-out on success. | `ANM_030` | 2 | 3D | Yes | SFX | P2 |
| `SFX_034` | Spill splat | kitchen | Juicy splat. | Item SPILLED or dropped | 4 | 3D | No | SFX | P3 |
| `SFX_035` | Station upgrade clank | kitchen | Ratchet clank plus a rising sparkle chord, one per level. | Station Lv2–Lv5 purchased | 4 | 3D | No | SFX | P2 |

#### 36.15.3 Customer voice (gibberish)

Each bank is a set of 28 syllable grains (80–220 ms) plus 8 reaction takes. The gibberish synthesizer (§26) strings
3–9 grains per "sentence" and pitch-shifts them by mood. The bank is chosen from the customer's HEAD family.

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_036` | Gibberish – Grumbly Big | customer voice | Low, round "mrrb-grumf" syllables. | HEAD family bear, gorilla, trex, lava, dragon | 36 | 3D | No | Voice | P3 |
| `SFX_037` | Gibberish – Squeaky Small | customer voice | High, quick "pip-squee" chatter. | rat, axolotl | 36 | 3D | No | Voice | P3 |
| `SFX_038` | Gibberish – Birdy Chirp | customer voice | Chirpy "cheep-brrk-coo" syllables. | pigeon, chicken, owl, phoenix | 36 | 3D | No | Voice | P3 |
| `SFX_039` | Gibberish – Ribbit Gloop | customer voice | Throaty "rrbt-gloop" croaks. | frog | 36 | 3D | No | Voice | P3 |
| `SFX_040` | Gibberish – Bubbly Aquatic | customer voice | Underwater-filtered "blub-blorp". | fish, shark, hammerhead, octopus, kraken | 36 | 3D | No | Voice | P3 |
| `SFX_041` | Gibberish – Bark & Purr | customer voice | "Rruff-mrrow" syllables. | dog, cat, wolf | 36 | 3D | No | Voice | P3 |
| `SFX_042` | Gibberish – Bleat & Moo | customer voice | Wobbly "mehh-mooh" vowels. | goat, deer, giraffe | 36 | 3D | No | Voice | P3 |
| `SFX_043` | Gibberish – Hiss & Snap | customer voice | Sibilant "sss-tk-sss". | snake, lizard, crocodile | 36 | 3D | No | Voice | P3 |
| `SFX_044` | Gibberish – Beep-Boop | customer voice | Synth "bip-bwoop" with a ring-mod tint. | robot, tv, microwave, toaster, hydrant | 36 | 3D | No | Voice | P3 |
| `SFX_045` | Gibberish – Buzz & Click | customer voice | Buzzy "bzz-tik" chatter. | mantis, fly, spider | 36 | 3D | No | Voice | P3 |
| `SFX_046` | Gibberish – Leafy Rustle | customer voice | Crunchy, rustly "shrff-pop". | pumpkin, broccoli, flytrap, burger | 36 | 3D | No | Voice | P3 |
| `SFX_047` | Gibberish – Cosmic Warble | customer voice | Warbly "wee-oo-zorp" with a chorus effect. | alien_grey, glitch | 36 | 3D | No | Voice | P3 |
| `SFX_048` | Order call | customer voice | Eager two-syllable "hey-yo!" in gibberish. | `ANM_042` | 12 banks × 2 | 3D | No | Voice | P2 |
| `SFX_049` | Delighted cheer | customer voice | Joyful whoop. | Satisfaction ≥ 90; `ANM_102` | 12 × 2 | 3D | No | Voice | P3 |
| `SFX_050` | Happy hum | customer voice | Content "mm-hmm!". | Satisfaction 70–89 | 12 × 2 | 3D | No | Voice | P3 |
| `SFX_051` | Meh "hmm" | customer voice | Flat, unimpressed hum. | Satisfaction 50–69 | 12 × 2 | 3D | No | Voice | P3 |
| `SFX_052` | Unhappy groan | customer voice | Deflated groan. | Satisfaction 30–49; anger 1 | 12 × 2 | 3D | No | Voice | P3 |
| `SFX_053` | Furious rage-gibber | customer voice | Sputtering "HRRMBL-GRBL!", comic and never scary. | Satisfaction < 30; anger ≥ 3 | 12 × 3 | 3D | No | Voice | P2 |
| `SFX_054` | Complaint rant loop | customer voice | Fast continuous gibberish rant. | `ANM_047` (anger 2) | 12 × 2 | 3D | Yes | Voice | P3 |
| `SFX_055` | Dramatic boo-hoo | customer voice | Theatrical wail with sniffles. | `ANM_056`; `ANM_112` | 12 × 2 | 3D | No | Voice | P3 |
| `SFX_056` | Belly laugh | customer voice | Wheezy cartoon laugh. | Emotes; PER_007 mischief | 12 × 2 | 3D | No | Voice | P3 |
| `SFX_057` | Nom-nom & slurp | customer voice | Chomps, slurps, a tiny polite hiccup (10 %). | `ANM_043`; sip | 12 × 3 | 3D | No | Voice | P4 |
| `SFX_058` | Snore | customer voice | Whistling snore with a "Z" pop. | `ANM_109`; STS_SLEEPY | 12 × 1 | 3D | Yes | Voice | P4 |
| `SFX_059` | Apology mumble | customer voice | Embarrassed, shy mumble. | `ANM_053` | 12 × 2 | 3D | No | Voice | P3 |
| `SFX_060` | Nyah-nyah victory | customer voice | Sing-song taunt melody hummed in gibberish. | `ANM_051` | 12 × 1 | 3D | No | Voice | P2 |
| `SFX_061` | Surprise "Whoa!" | customer voice | Wide-eyed gasp or "whoa". | `ANM_106`; `ANM_105`; wrong-dish reveal | 12 × 2 | 3D | No | Voice | P3 |
| `SFX_062` | Instigator holler | customer voice | Rabble-rousing call-out with an echo. | `ANM_059` | 12 × 2 | 3D | No | Voice | P2 |

#### 36.15.4 Creature

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_063` | Footsteps – Standard | creature | Soft rubbery blocky steps. Surface sets (wood, tile, metal, carpet, street) swap by floor material. | `FootL`/`FootR`, gait Standard | 5 surfaces × 4 | 3D | No | SFX | P4 |
| `SFX_064` | Footsteps – Heavy | creature | Thuds with low-end and a cup-rattle tail. | Gait Heavy (`ANM_067`) | 6 | 3D | No | SFX | P3 |
| `SFX_065` | Footsteps – Hop | creature | Springy "boing" hops; pogo gets a coil twang. | Gait Hop (`ANM_068`) | 6 | 3D | No | SFX | P4 |
| `SFX_066` | Footsteps – Skitter | creature | Rapid tiny ticks. | Gait Skitter (`ANM_069`) | 6 | 3D | No | SFX | P4 |
| `SFX_067` | Footsteps – Glide | creature | Soft squelch or cloud puff swishes. | Gait Glide (`ANM_070`) | 6 | 3D | No | SFX | P4 |
| `SFX_068` | Footsteps – Roll | creature | Wheel or skate whirr loop, pitched by speed. | Gait Roll (`ANM_071`) | 2 | 3D | Yes | SFX | P4 |
| `SFX_069` | Footsteps – Strut | creature | Talon clicks and hoof clops. | Gait Strut (`ANM_072`) | 6 | 3D | No | SFX | P4 |
| `SFX_070` | Wing flap loop | creature | Feather, membrane or insect-buzz flap variants. | WINGS idle flaps; `ANM_073` | 4 | 3D | Yes | SFX | P4 |
| `SFX_071` | Tail swish & rattle | creature | Swish, rattle (rattlesnake) or zap-crackle (lightning tail). | Tail secondary motion peaks | 6 | 3D | No | SFX | P4 |
| `SFX_072` | Creature bark – Fur & Feather | creature | Cartoon woof, meow, oink, moo, cluck, coo, hoot. Emote and idle barks. | MAMMAL / BIRD part idle bark (1 per 20–40 s) | 14 | 3D | No | SFX | P4 |
| `SFX_073` | Creature bark – Scale & Fin | creature | Hiss, cute roar, ribbit, blub, whale-boop. | REPTILE / DINOSAUR / AMPHIBIAN / FISH / MARINE barks | 12 | 3D | No | SFX | P4 |
| `SFX_074` | Creature bark – Bug & Plant | creature | Buzz, chirp, leaf-rustle, pod-pop. | INSECT / ARACHNID / PLANT barks | 10 | 3D | No | SFX | P4 |
| `SFX_075` | Creature bark – Gadget | creature | Servo whirr, toaster pop, TV static blip, microwave beep. | ROBOT / OBJECT / FOOD barks | 12 | 3D | No | SFX | P4 |
| `SFX_076` | Creature bark – Myth & Cosmic | creature | Dragon rumble-purr, sparkle hum, alien warble. | MYTHOLOGICAL / ALIEN / ELEMENTAL barks | 10 | 3D | No | SFX | P4 |
| `SFX_077` | Jetpack & rotor loop | creature | Thruster whoosh or helicopter "chuff". | Jetpack, rotor, booster parts active; `ANM_369` | 3 | 3D | Yes | SFX | P3 |

#### 36.15.5 Combat

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_078` | Swipe whoosh | combat | Quick air whoosh. Each combo hit is pitched +2 semitones. | `ANM_301` `Impact` (`ABL_001`) | 4 | 2D/3D | No | SFX | P2 |
| `SFX_079` | Light hit "bap" | combat | Cartoon slap-bap plus a star "ting". | Any light hit confirmed | 6 | 3D | No | SFX | P2 |
| `SFX_080` | Heavy BONK | combat | Hollow coconut BONK with a cartoon bell tail. | `ANM_302` (`ABL_002`); heavy hits | 4 | 3D | No | SFX | P2 |
| `SFX_081` | Block thud | combat | Padded thump. Pitch drops as the Guard meter drains. | `ANM_303` absorbs (`ABL_003`) | 4 | 2D/3D | No | SFX | P2 |
| `SFX_082` | Guard break clang-boing | combat | Pot-lid clang into a spring boing. | Guard break → STS_STUN; `ANM_144` | 2 | 3D | No | SFX | P1 |
| `SFX_083` | Dodge whoosh | combat | Tumble whoosh with a cloth flap. | `ANM_304` (`ABL_004`) | 3 | 2D/3D | No | SFX | P2 |
| `SFX_084` | Heave & throw | combat | Effort grunt-gibber plus a release whoosh. | `ANM_305` (`ABL_005`) | 3 | 3D | No | SFX | P2 |
| `SFX_085` | Calm Down! chime | combat | Warm harp gliss with a soft "shhh". | `ANM_306` (`ABL_006`); peace offering | 2 | 3D | No | SFX | P2 |
| `SFX_086` | Pan bonk DOOONG | combat | Ringing frying-pan DOOONG. | `ANM_307` `Impact` (`ABL_007`) | 3 | 3D | No | SFX | P2 |
| `SFX_087` | Tray deflect tink | combat | Bright tin "tink-ting". | `ANM_308` deflect (`ABL_008`) | 3 | 3D | No | SFX | P2 |
| `SFX_088` | Food lob whoosh | combat | Wobbly airborne whoosh that follows the scripted arc. | `ANM_048` / `ANM_149` `Release` | 4 | 3D | No | SFX | P2 |
| `SFX_089` | Food splat hit | combat | Juicy splat with a "plap". Ketchup, cream and slime variants. | Thrown food impact; `ANM_159` | 6 | 3D | No | SFX | P2 |
| `SFX_090` | Knockdown boing-tumble | combat | Spring launch, tumble rattle, flop. | STS_KNOCKDOWN; `ANM_143` | 3 | 3D | No | SFX | P2 |
| `SFX_091` | Dizzy tweet loop | combat | Cartoon birdie tweets plus a wobble tone. | STS_DIZZY; `ANM_052` | 1 | 3D | Yes | SFX | P2 |
| `SFX_092` | Seeing Stars KO | combat | Slide-whistle down, thud, tweeting stars. | Player KO; `ANM_062` | 2 | 2D/3D | No | SFX | P1 |
| `SFX_093` | Respawn poof | combat | Confetti pop plus a "ta-da" blip. | `ANM_063` | 2 | 2D/3D | No | SFX | P2 |
| `SFX_094` | Calmed sparkle | combat | Descending sparkle and a relieved sigh. | Customer Huff Points 0 → calming; `ANM_058` | 2 | 3D | No | SFX | P2 |
| `SFX_095` | Status – chill & zap | combat | Ice-lock crunch, buzzy zap or treacle "bloop". | STS_FROZEN, STS_SHOCKED, STS_SLOW applied | 3 | 3D | No | SFX | P2 |
| `SFX_096` | Status – goo & pong | combat | Squelch, "pfft" puff, slippery squeak, splash, soot puff. | STS_STICKY, STS_STINKY, STS_GREASY, STS_SOAKED, STS_TOASTY applied | 5 | 3D | No | SFX | P2 |
| `SFX_097` | Status – head-spinners | combat | Wah-wah, woozy warble, blindfold "fwump", yawn chime, heart boing, float "whee". | STS_CONFUSED, STS_WOOZY, STS_BLINDED, STS_SLEEPY, STS_CHARMED, STS_FLOATING applied | 6 | 3D | No | SFX | P2 |
| `SFX_098` | Status – buffs | combat | Rising power chord, hype "whoop", shield shimmer. | STS_INSPIRED, STS_HYPED, STS_SHIELDED; `ANM_158` | 3 | 2D/3D | No | SFX | P2 |
| `SFX_099` | Ability – breath & beams | combat | Sparkly fwoosh, "pew-wee" laser sweep, tractor warble. | `ABL_018`, `ABL_032`, `ABL_045` | 3 × 2 | 3D | Yes | SFX | P2 |
| `SFX_100` | Ability – zaps & claps | combat | Eel crackle, thunder clap boom, soft flash "fwoom", psychic buzz. | `ABL_014`, `ABL_042`, `ABL_057`, `ABL_047` | 4 × 2 | 3D | No | SFX | P2 |
| `SFX_101` | Ability – frost & magma | combat | Snowflake burst and a bubbling magma "blorp-thud". | `ABL_041`, `ABL_043` | 2 × 3 | 3D | No | SFX | P2 |
| `SFX_102` | Ability – tentacles & tongues | combat | Wet slaps, whip crack, tongue "thwap-slurp". | `ABL_012`, `ABL_016`, `ABL_049` | 3 × 3 | 3D | No | SFX | P2 |
| `SFX_103` | Ability – chomps & snips | combat | Comic CHOMP, claw snip, scythe swish, flytrap snap, peck pecks, stinger "tsk". | `ABL_009`, `ABL_017`, `ABL_019`, `ABL_026`, `ABL_039`, `ABL_050` | 6 × 2 | 3D | No | SFX | P2 |
| `SFX_104` | Ability – slams & butts | combat | Ground thumps, jelly boing, horn "fwip", hammerhead clonk. | `ABL_010`, `ABL_013`, `ABL_021`, `ABL_037`, `ABL_052`, `ABL_054`, `ABL_058` | 7 × 2 | 3D | No | SFX | P2 |
| `SFX_105` | Ability – sprays & clouds | combat | Web "thwip", skunk "pfffft", trunk spray, spore puff, slime slide, stink-orb pop. | `ABL_020`, `ABL_024`, `ABL_028`, `ABL_040`, `ABL_048`, `ABL_056` | 6 × 2 | 3D | No | SFX | P2 |
| `SFX_106` | Ability – whooshes & blinks | combat | Spring kick, flappy hover, gust, comet "zwip", wing buffet, tail spin, burrow rumble, ghostly "wooo-hoo", dash zoom. | `ABL_011`, `ABL_022`, `ABL_044`, `ABL_046`, `ABL_051`, `ABL_053`, `ABL_055`, `ABL_059`, `ABL_063` | 9 × 2 | 3D | No | SFX | P2 |
| `SFX_107` | Ability – gadgets | combat | Rocket-fist "fwoosh-POW", magnet "vwomp", toaster pop-pop-pop, vacuum roar, umbrella "fwump". | `ABL_031`, `ABL_033`, `ABL_034`, `ABL_035`, `ABL_036` | 5 × 2 | 3D | No | SFX | P2 |
| `SFX_108` | Ability – show-offs | combat | Spine "shhk", screech rings, puff inflate, roll rumble, peacock fan "fwap", owl spin, cactus "boing-prick". | `ABL_015`, `ABL_023`, `ABL_025`, `ABL_027`, `ABL_029`, `ABL_030`, `ABL_038` | 7 × 2 | 3D | No | SFX | P2 |
| `SFX_109` | Ability – kitchen-helper chimes | combat | Bright utility chimes: mechanical unfold, sniff-sparkle, lullaby harp, microwave DING, frost tap, web swoop, jet lift, eagle "ting". | `ABL_061`, `ABL_064`, `ABL_065`, `ABL_066`, `ABL_067`, `ABL_068`, `ABL_069`, `ABL_070` | 8 × 2 | 2D/3D | No | SFX | P2 |
| `SFX_110` | Kraken Grasp ultimate | combat | Huge comic squelch, a tuba "BWOMP" and a squeeze-squeak. | `ANM_360` (`ABL_060`) | 2 | 3D | No | SFX | P1 |

#### 36.15.6 Destruction

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_111` | Wood creak-crack | destruction | Creak into a light crack. | Wood item → Scuffed or Cracked | 4 | 3D | No | SFX | P3 |
| `SFX_112` | Wood splinter snap | destruction | Cartoon plank SNAP with a boing tail. | Wood item → Broken | 4 | 3D | No | SFX | P2 |
| `SFX_113` | Collapse to rubble | destruction | Crash, rumble, then a tiny "tink" on the last piece. | Any item → Destroyed | 3 | 3D | No | SFX | P2 |
| `SFX_114` | Chunky plate smash | destruction | Rounded candy-crunch break with no sharp glass shriek. | Plate, cup or glass prop breaks | 5 | 3D | No | SFX | P3 |
| `SFX_115` | Chair & table clatter | destruction | Tumbling furniture clatter plus cutlery jingle. | `ANM_049` flip; chairs knocked over | 4 | 3D | No | SFX | P2 |
| `SFX_116` | Appliance sputter-spark | destruction | Motor sputter, spring "sproing", cartoon spark fizz. | Appliance → Broken | 3 | 3D | No | SFX | P2 |
| `SFX_117` | Aquarium jelly-crack & splash | destruction | Rubbery crack, slosh, fish "blub!". | Aquarium decor damaged | 3 | 3D | No | SFX | P3 |
| `SFX_118` | Debris patter | destruction | Small pieces landing; volume scales with piece count. | Client debris lands (≤ 4 s life) | 6 | 3D | No | SFX | P4 |

#### 36.15.7 Repair

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_119` | Hammer tap | repair | Bright wood-and-metal taps with a star twinkle. | `ANM_060` `Impact` | 6 | 3D | No | SFX | P3 |
| `SFX_120` | Ratchet & sparkle weld | repair | Ratchet clicks plus a fizzy sparkle (no torch roar). | `ANM_061` | 4 | 3D | Yes | SFX | P3 |
| `SFX_121` | Broom sweep | repair | Bristle swishes. | `ANM_180` | 3 | 3D | Yes | SFX | P4 |
| `SFX_122` | Repair progress tick | repair | Rising marimba note at every 25 % of progress. | Repair progress 25/50/75 % | 3 | 2D/3D | No | SFX | P3 |
| `SFX_123` | Repair complete ding | repair | Sparkle "ding!" plus "good as new" shimmer. | Item restored to Pristine | 2 | 2D/3D | No | SFX | P2 |
| `SFX_124` | Rebuild rewind | repair | Reverse whoosh, pieces clacking into place, then a pop. | `ANM_181` (Destroyed → rebuilt) | 2 | 3D | No | SFX | P2 |
| `SFX_125` | Repair Burst | repair | Spinning wrench whirr releasing a chiming repair ring. | `ANM_362` (`ABL_062`) | 2 | 3D | No | SFX | P2 |

#### 36.15.8 Currency, level-up and mutation

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_126` | Coin clink | currency | Single bright coin. Throttled to 10 per second. | Small MB gain | 4 | 2D | No | UI | P3 |
| `SFX_127` | Payment coin burst | currency | Coins slapped on the table plus a scatter. | `ANM_044` | 3 | 3D | No | SFX | P3 |
| `SFX_128` | Cash register cha-ching | currency | Classic drawer-pop "cha-ching". | `ANM_066`; `ANM_234` | 3 | 2D/3D | No | SFX | P2 |
| `SFX_129` | Tip jingle | currency | Jingle sized by TipRate tier (5/10/18/25 %). | `ANM_045` | 4 | 2D/3D | No | SFX | P2 |
| `SFX_130` | Jackpot Tip fanfare | currency | Brass hit, bell tree, coin rain (no slot-machine sounds). | Jackpot Tip (×5) | 2 | 2D | No | UI | P1 |
| `SFX_131` | Shard & token chimes | currency | Crystal chime (MS) or scholarly "bloop-ding" (RT). | MS or RT gain | 2 × 3 | 2D | No | UI | P3 |
| `SFX_132` | Purchase confirm | currency | Satisfying "ka-chunk" plus a sparkle. | Any successful purchase | 3 | 2D | No | UI | P2 |
| `SFX_133` | Can't afford boop | currency | Gentle descending "boop-bonk". | Insufficient funds | 2 | 2D | No | UI | P2 |
| `SFX_134` | Offline earnings cascade | currency | Rolling coin cascade whose length matches the count-up (≤ 3 s). | Collect on Welcome Back screen | 2 | 2D | No | UI | P2 |
| `SFX_135` | XP tick | level-up | Soft rising blip, throttled to 8 per second. | XP gain | 3 | 2D | No | UI | P4 |
| `SFX_136` | Level-up fanfare | level-up | 2.5 s brassy fanfare with a choir "la!" (gibberish). | Level gained; `ANM_064` | 2 | 2D | No | UI | P1 |
| `SFX_137` | Stat point pop | level-up | Bubbly pop; each further point in the same stat pitches up. | Allocate stat "+" | 3 | 2D | No | UI | P3 |
| `SFX_138` | Skill node unlock | level-up | Click-lock plus a shimmering chord (one tint per tree). | Skill node purchased | 5 | 2D | No | UI | P2 |
| `SFX_139` | Achievement & milestone jingle | level-up | Short trophy jingle. | Achievement or milestone reached | 2 | 2D | No | UI | P2 |
| `SFX_140` | Capsule rattle | mutation | Three escalating rattles. | `ANM_186` shakes | 3 | 2D | No | SFX | P2 |
| `SFX_141` | Capsule reveal | mutation | Reveal chord. Each rarity has its own instrument and length (0.8–2.5 s). | Capsule or fusion result | 7 (Common→Secret) | 2D | No | SFX | P1 |
| `SFX_142` | Equip snap-squish | mutation | Squishy "snap" with a tone per UI slot group. | Part equipped; `ANM_065` | 7 | 2D/3D | No | SFX | P2 |
| `SFX_143` | Unequip pop | mutation | Cork pop. | Part unequipped | 2 | 2D/3D | No | SFX | P3 |
| `SFX_144` | Loadout swap whirl | mutation | 3 s rising sparkle tornado that cuts off if interrupted. | `ANM_209` | 1 | 2D/3D | No | SFX | P2 |
| `SFX_145` | Mutation upgrade rise | mutation | Power-up riser that climbs a step per level. | Mutation upgraded | 3 | 2D | No | SFX | P2 |
| `SFX_146` | Lab fusion bubble-boom | mutation | Bubbling beakers, a building hum, a comic "BWOOMPH". | Fusion at BLD_11 | 2 | 2D | No | SFX | P2 |
| `SFX_147` | Temporary mutation bloop | mutation | Rubbery "bloop" as the part sprouts. Reversed when it fades after 60 s. | MUT dish effect; `ANM_106` | 2 | 3D | No | SFX | P3 |
| `SFX_148` | Secret discovery glitch-sparkle | mutation | Bit-crushed sparkle with a "?" chime. | Secret condition met (§C13.8) | 1 | 2D | No | SFX | P1 |

#### 36.15.9 UI

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_149` | Button click | UI | Soft rubbery click. | Any button activate | 3 | 2D | No | UI | P3 |
| `SFX_150` | Focus tick | UI | Tiny tick when focus moves (gamepad selection; mouse hover on desktop). | `GuiService.SelectedObject` change; hover | 2 | 2D | No | UI | P4 |
| `SFX_151` | Panel open | UI | Whoosh-pop. | Full-screen or overlay panel opens | 2 | 2D | No | UI | P3 |
| `SFX_152` | Panel close | UI | Reverse whoosh. | Panel closes (including auto-close on hostile, canon E2) | 2 | 2D | No | UI | P3 |
| `SFX_153` | Tab switch | UI | Paper-flip flick. | Tab or category change | 2 | 2D | No | UI | P4 |
| `SFX_154` | Error / denied | UI | Friendly double "bonk-bonk". | Invalid action; "Can't shop during a brawl!" | 2 | 2D | No | UI | P2 |
| `SFX_155` | Toast notification | UI | Light "plink". | HUD toast (quests, level-up deferral, hints) | 3 | 2D | No | UI | P3 |
| `SFX_156` | New order ticket | UI | Ticket-printer "zzt-zzt" plus a paper tear. | New order added to the queue | 2 | 2D | No | UI | P2 |
| `SFX_157` | Patience warning | UI | Rising two-note "uh-oh" chirp, plus a directional cue if the customer is off-screen. | Any customer patience ≤ 25 % | 1 | 2D | No | Alerts | P1 |
| `SFX_158` | Hostile alert | UI | Comic "dun-dun!" horn stab. | Customer reaches anger 5 targeting the player | 1 | 2D | No | UI | P1 |
| `SFX_159` | Quest accept & complete | UI | Accept: scroll unroll. Complete: stamp "THUNK" plus a mini fanfare. | Quest state change | 2 | 2D | No | UI | P2 |
| `SFX_160` | Placement valid / invalid | UI | Valid: soft snap. Invalid: muted buzz. | Build-mode placement attempt | 2 | 2D | No | UI | P3 |
| `SFX_161` | Countdown tick | UI | Woodblock tick that raises pitch over the last 3 s. | Event and minigame timers, last 5 s | 2 | 2D | No | UI | P2 |
| `SFX_162` | Friend arrives knock | UI | Cartoon door knock plus a doorbell "ding-dong". | Friend or guest enters your restaurant | 2 | 2D | No | UI | P3 |

#### 36.15.10 City ambience

District beds are stereo 2D loops (60–90 s, seamless) mixed under district music. Point emitters are 3D. Day and
night variants follow the 24 min cosmetic light cycle (§C3).

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_163` | Restaurant Row bed | city ambience | Sizzling vents, chatter, distant delivery toots, string-light hum. | Zone DST_01 | day + night | 2D | Yes | Ambience | Bed |
| `SFX_164` | Mutation Market bed | city ambience | Haggling gibberish, bubbling jars, stall awnings flapping. | Zone DST_02 | day + night | 2D | Yes | Ambience | Bed |
| `SFX_165` | Downtown bed | city ambience | Busy plaza, cartoon traffic, fountain wash, pigeon wings. | Zone DST_03 | day + night | 2D | Yes | Ambience | Bed |
| `SFX_166` | Industrial bed | city ambience | Rhythmic clanks, conveyor rattle, steam whistles. | Zone DST_04 | day + night | 2D | Yes | Ambience | Bed |
| `SFX_167` | Monster Mall bed | city ambience | Atrium reverb, escalator hum, shopping-bag rustles. | Zone DST_05 | 1 | 2D | Yes | Ambience | Bed |
| `SFX_168` | Research District bed | city ambience | Lab beeps, bubbling tubes, automatic-door swooshes. | Zone DST_06 | day + night | 2D | Yes | Ambience | Bed |
| `SFX_169` | Entertainment bed | city ambience | Marquee buzz, arcade blips, distant applause. | Zone DST_07 | day + night | 2D | Yes | Ambience | Bed |
| `SFX_170` | Residential bed | city ambience | Birds, lawn sprinklers, a far-off ice-cream-truck kazoo. | Zone DST_08 | day + night | 2D | Yes | Ambience | Bed |
| `SFX_171` | Sewers bed | city ambience | Musical drips, echoing squeaks, gentle flowing water. Never menacing. | Zone DST_09 | 1 | 2D | Yes | Ambience | Bed |
| `SFX_172` | Arena District bed | city ambience | Stadium roar swells, vendor calls, foam-finger squeaks. | Zone DST_10 | day + night | 2D | Yes | Ambience | Bed |
| `SFX_173` | Night layer | city ambience | Crickets, soft neon hum, an owl hoot. Added during the city night phase. | City ClockTime 19–5 | 2 | 2D | Yes | Ambience | Bed |
| `SFX_174` | Neon sign buzz | city ambience | Electric buzz with an occasional flicker crackle. | 3D emitter on Neon sign models | 3 | 3D | Yes | Ambience | P4 |
| `SFX_175` | Fountain splash | city ambience | Burbling water loop. | Downtown fountain; BLD_19 | 2 | 3D | Yes | Ambience | P4 |
| `SFX_176` | Metro train pass | city ambience | Choo-choo whistle, rumble, door "ding-dong". | Morph Metro arrivals; BLD_18 | 3 | 3D | No | Ambience | P3 |
| `SFX_177` | Cartoon traffic toots | city ambience | Bike-horn honks, "a-OOO-ga", squeaky brakes. | Client crowd vehicles pass | 8 | 3D | No | Ambience | P4 |
| `SFX_178` | Restaurant room tone | city ambience | Interior murmur. Volume = 0.2 + 0.8 × occupancy; brighter EQ per tier. | Inside any restaurant interior | 10 (per tier) | 2D | Yes | Ambience | Bed |

#### 36.15.11 Event

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_179` | Event start horn | event | Citywide "doot-da-DOO!" party horn plus crowd cheer. | Any city event begins (§36.11) | 2 | 2D | No | SFX | P2 |
| `SFX_180` | Meteor whistle & bonk | event | Descending whistle, soft crater "BONK", sparkle. | EVT_006 meteor lands | 3 | 3D | No | SFX | P3 |
| `SFX_181` | Pickle rain patter | event | Rubbery pickle boings on roofs and heads. | EVT_012 active | 2 | 2D | Yes | Ambience | Bed |
| `SFX_182` | Rat King squeak-roar | event | Giant squeaky roar with a crown jingle. | EVT_007; `ANM_284` | 3 | 3D | No | SFX | P1 |
| `SFX_183` | Blackout power-down / up | event | Comic "bwoooww" power-down and "ba-ding!" restore. | EVT_009 start and end | 2 | 2D | No | SFX | P2 |
| `SFX_184` | Giant & Tiny Day steps | event | Boomy stomps (Giant) or squeaky pitter-patter (Tiny) layered on footsteps. | EVT_016, EVT_015 | 2 × 4 | 3D | No | SFX | P4 |
| `SFX_185` | Upside-down flip | event | Whooshing gravity flip with a slide whistle up. | EVT_011 start and end | 2 | 2D | No | SFX | P2 |
| `SFX_186` | Weather swirl | event | Icy wind gusts (Frozen Snap) or heat-shimmer warble (Heatwave). | EVT_020, EVT_019 active | 2 | 2D | Yes | Ambience | Bed |
| `SFX_187` | Sewer flood gush | event | Bubbly water gush with rubber-duck squeaks. | EVT_013 | 2 | 3D | Yes | Ambience | P3 |
| `SFX_188` | Paparazzi clicks | event | Rapid camera clicks with flash whines. | EVT_014, EVT_008 arrivals; NPC_021 | 3 | 3D | No | SFX | P3 |
| `SFX_189` | Polite robot chorus | event | Overly courteous beep-boop gibberish in unison. | EVT_017 | 2 | 3D | Yes | Voice | P3 |

#### 36.15.12 Stingers

Stingers are 1–4 s musical cues on the `Music` bus. They duck the music bed by 6 dB for their length, and a 4 s
cooldown per stinger prevents spam.

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `SFX_190` | WRONG ORDER?! | stinger | Record scratch into a trombone "wah-wahhh". | Customer served a wrong dish (accuracy 0) | 2 | 2D | No | Music | P1 |
| `SFX_191` | Chef's Kiss | stinger | Sparkly harp gliss plus a "mwah". | Satisfaction ≥ 98 | 2 | 2D | No | Music | P2 |
| `SFX_192` | Tantrum begins | stinger | Plucky "uh-oh" pizzicato. | First customer crosses into anger 3 in a scene | 2 | 2D | No | Music | P1 |
| `SFX_193` | Fight! | stinger | Boxing-bell "ding-ding" plus a brass stab. | Customer enters anger 5 (hostile) | 2 | 2D | No | Music | P1 |
| `SFX_194` | CHAOS! | stinger | Slapstick crash cymbal plus a frantic klezmer clarinet run. | Restaurant-wide chaos (anger level 6) starts | 1 | 2D | No | Music | P1 |
| `SFX_195` | Peace restored | stinger | Relieved major chord with a birdsong tweet. | Last hostile calmed; chaos ends | 2 | 2D | No | Music | P2 |
| `SFX_196` | Seeing Stars sting | stinger | Wobbly tuba descent. Pairs with `SFX_092`. | Player KO | 1 | 2D | No | Music | P2 |
| `SFX_197` | Tier upgrade fanfare | stinger | Full brass fanfare with confetti cannon. | Tier upgrade complete; `ANM_184` | 1 | 2D | No | Music | P1 |
| `SFX_198` | Epic+ reveal | stinger | Choir "AAAH" (gibberish) plus a timpani roll, scaled by rarity. | Epic, Legendary, Mythic or Secret reveal | 4 | 2D | No | Music | P1 |
| `SFX_199` | Breaking news jingle | stinger | Newsroom-style synth jingle. | NPC_030 event announcement | 2 | 2D | No | Music | P2 |
| `SFX_200` | Chapter complete | stinger | Storybook flourish plus a page turn. | Story chapter finished (§20) | 1 | 2D | No | Music | P2 |
| `SFX_201` | Welcome Back | stinger | "Ta-daaa!" with a kazoo tag. | Offline report opens | 1 | 2D | No | Music | P2 |

#### 36.15.13 Music tracks

All tracks are 2D loops on the `Music` bus. They are composed in sections so loops land on bar lines, and every
stem of a multi-stem track has identical length and BPM (§26 adaptive music). Restaurant tier tracks ship three stems:
**Calm** (base groove), **Rush** (added percussion and bass), **Chaos** (frantic lead, brass stabs, cartoon percussion).

| ID | Name | Category | Description | Trigger | Variations | 2D/3D | Loop | SoundGroup | Priority |
|---|---|---|---|---|---|---|---|---|---|
| `MUS_001` | Mystery Morph Overture | menu music | Bouncy brass-and-ukulele theme with a kazoo hook. 112 BPM, 96 s loop. | Main menu; loading | 1 | 2D | Yes | Music | Bed |
| `MUS_002` | Nana's Shack | restaurant music | Plucky banjo and slightly wonky toy piano. 100 BPM. | Tutorial QST_TUT_001–QST_TUT_012 | 2 stems | 2D | Yes | Music | Bed |
| `MUS_003` | Broken Burger Shack | restaurant music | Junkyard skiffle: washboard, pots-and-pans kit, ukulele. 104 BPM. | TIER_01 interior | 3 stems | 2D | Yes | Music | Bed |
| `MUS_004` | Tiny Mutation Diner | restaurant music | Doo-wop: upright bass, finger snaps, "bop-shoo-wop" gibberish choir. 120 BPM. | TIER_02 interior | 3 stems | 2D | Yes | Music | Bed |
| `MUS_005` | Neighborhood Freak Café | restaurant music | Cozy café jazz: brushed drums, vibraphone, clarinet. 92 BPM. | TIER_03 interior | 3 stems | 2D | Yes | Music | Bed |
| `MUS_006` | Morph City Grill | restaurant music | Rockabilly: twangy guitar, slap bass, sizzle hi-hat. 132 BPM. | TIER_04 interior | 3 stems | 2D | Yes | Music | Bed |
| `MUS_007` | Mutant Family Restaurant | restaurant music | Sunny pop-polka: accordion, glockenspiel, handclaps. 116 BPM. | TIER_05 interior | 3 stems | 2D | Yes | Music | Bed |
| `MUS_008` | Monster Food Court | restaurant music | Synth-funk: retro synths, slap bass, cowbell. 110 BPM. | TIER_06 interior | 3 stems | 2D | Yes | Music | Bed |
| `MUS_009` | Mutation Megadiner | restaurant music | Big-band swing over neon synth pads. 140 BPM. | TIER_07 interior | 3 stems | 2D | Yes | Music | Bed |
| `MUS_010` | Luxury Freak Restaurant | restaurant music | Lounge bossa: string quartet, theremin lead. 98 BPM. | TIER_08 interior | 3 stems | 2D | Yes | Music | Bed |
| `MUS_011` | Morph City Food Palace | restaurant music | Regal march-waltz: orchestra, harpsichord, oompah tuba. 108 BPM. | TIER_09 interior | 3 stems | 2D | Yes | Music | Bed |
| `MUS_012` | Legendary Mutation Restaurant | restaurant music | Epic gibberish choir, orchestra, purple synth arpeggios. 124 BPM. | TIER_10 interior | 3 stems | 2D | Yes | Music | Bed |
| `MUS_013` | Closing Time | restaurant music | Sleepy music-box lullaby. | Restaurant Closing state (canon E1); empty interior | 1 | 2D | Yes | Music | Bed |
| `MUS_014` | Welcome Back, You Weirdo! | menu music | Celebratory count-up loop that resolves on Collect. | Offline report screen | 1 | 2D | Yes | Music | Bed |
| `MUS_015` | Restaurant Row Strut | city music | Street-party funk with sizzling hi-hats. | Zone DST_01 | day + night | 2D | Yes | Music | Bed |
| `MUS_016` | Market Bazaar Groove | city music | Hand drums, marimba, wobbly synth lead. | Zone DST_02 | day + night | 2D | Yes | Music | Bed |
| `MUS_017` | Downtown Brass Bop | city music | Big-city brass by day, neon synthwave-lite by night. | Zone DST_03 | day + night | 2D | Yes | Music | Bed |
| `MUS_018` | Clank Factory Work-Song | city music | Anvil-and-pipe percussion with whistles. | Zone DST_04 | 1 | 2D | Yes | Music | Bed |
| `MUS_019` | Mall Muzak Deluxe | city music | Cheesy elevator muzak with a kazoo melody. | Zone DST_05; BLD_12 | 1 | 2D | Yes | Music | Bed |
| `MUS_020` | Lab Bubbles | city music | Arpeggiated synth, glass harmonica, beaker plinks. | Zone DST_06 | 1 | 2D | Yes | Music | Bed |
| `MUS_021` | Showtime Swing | city music | Piano, trumpets, tap-dance percussion. | Zone DST_07 | day + night | 2D | Yes | Music | Bed |
| `MUS_022` | Picket Fence Breeze | city music | Acoustic guitar and whistling. | Zone DST_08 | day + night | 2D | Yes | Music | Bed |
| `MUS_023` | Sewer Dub | city music | Drippy dub: tuba bass, echoey steel drums. Silly, not scary. | Zone DST_09 | 1 | 2D | Yes | Music | Bed |
| `MUS_024` | Arena Stomp | city music | Stomp-clap stadium anthem with crowd "HEY!". | Zone DST_10 | 1 | 2D | Yes | Music | Bed |
| `MUS_025` | Arena Battle | arena music | Chiptune-rock at 150 BPM. The second stem joins under 30 s left or at match point. | BLD_08 match | 2 stems | 2D | Yes | Music | Bed |
| `MUS_026` | Rat King Rumble | event music | Boss polka-metal: accordion plus crunchy guitar. 160 BPM. | EVT_007 | 2 stems | 2D | Yes | Music | Bed |
| `MUS_027` | Legendary Chef Tournament | event music | Heroic cooking-show orchestra with a ticking-clock motif. | EVT_005; story finale | 2 stems | 2D | Yes | Music | Bed |
| `MUS_028` | Festival Funk | event music | Parade brass band and drumline. | EVT_001, EVT_002, EVT_028 | 1 | 2D | Yes | Music | Bed |
| `MUS_029` | Blackout Bossa | event music | Silly-spooky theremin, xylophone, finger snaps. | EVT_009 | 1 | 2D | Yes | Music | Bed |
| `MUS_030` | Seasonal Suite | event music | Kazoo-organ (October), sleigh bells (December), flutes and birdsong (April). | EVT_029, EVT_030, EVT_031 | 3 | 2D | Yes | Music | Bed |
| `MUS_031` | Dance-Off Beat | event music | Four-on-the-floor disco whose tempo rises 118→128 BPM by round. | EVT_027; BLD_22 | 3 (per round) | 2D | Yes | Music | Bed |
| `MUS_032` | Build-a-Beast | menu music | Curious pizzicato plus beeps. Each slot group adds a light layer. | Morph customization (§13); BLD_11 | 1 + 7 layers | 2D | Yes | Music | Bed |
| `MUS_033` | Shop Browse | menu music | Cheery muzak. The lead instrument swaps per shop. | BLD_01, BLD_02, BLD_03, BLD_12 interiors | 4 | 2D | Yes | Music | Bed |
| `MUS_034` | Under Construction | event music | Hammer-percussion build-up into a fanfare, 10 s, plus a 3 s short edit (hands off to `SFX_197` at the reveal). | Mutant Builders sequence (§15) | 2 (10 s, 3 s) | 2D | No | Music | Bed |
| `MUS_035` | Rush Hour Frenzy | event music | 140 BPM frantic swing. Replaces the tier track inside interiors during citywide rushes. | EVT_003, EVT_023 | 1 | 2D | Yes | Music | Bed |
| `MUS_036` | Midnight Market | event music | Mysterious-cute lounge: muted trumpet, harp, cricket shaker. | BLD_13; EVT_024 | 1 | 2D | Yes | Music | Bed |
