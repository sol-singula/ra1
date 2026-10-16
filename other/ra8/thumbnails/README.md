# The Endless Voyage: thumbnails and the icon

![All 6 thumbnails and the 3 icons](_all.jpg)

Every thumbnail is **1920 × 1080 (16:9), JPG, under 0.5 MB**, for experience thumbnails and the Ads Manager. The
icon is `../icon/icon_bottle.png`, **512 × 512 PNG**. `icon_shadow_alt.png` and `icon_rod_alt.png` are alternates
for an icon A/B test.

**The idea: make them wonder.** Each thumbnail is one simple picture with one question, in words a third grader
reads easily. It shows something strange the game really has, and leaves the answer for the game. No title and no
captions beyond the question, because the store prints the game's name under every thumbnail.

**They show what is in the game.** Each one was made with AI image generation (Higgsfield, GPT Image 2.5, high
quality, 2k) from **real renders of the game** as references (the renders are in
[`../screenshots/`](../screenshots/README.md)): the plank-tile rafts on their log floats, the blocky survivors,
the Leviathan's long-jawed rig, the bottle that drifts in with a chart, Mist Hollow's empty huts and lanterns, the
Ruin's totems, the ship frozen into the Frost Shelf, and a fortress raft built from the game's own pieces (two
decks, crow's nest, lanterns, harpoon turrets, flags). In the game the survivors are the players' own avatars.
A few details are artistic: the totems' eyes glow, the frozen ship has a lit porthole, and the Leviathan's shadow
is bigger than it looks from a raft. The questions were lettered afterwards in the game's own font (Luckiest Guy,
like the HUD) with `tools/gameplay/title_art.py --caption-only`, kept off faces and off the thing the picture is
about.

| # | File | Question | Scene | In the game |
|---|---|---|---|---|
| 1 | `01_whats_down_there.jpg` | WHAT'S DOWN THERE? | From high above: a small raft alone on deep teal water, three survivors looking over the edge, and a giant long-jawed shadow sliding underneath | The Leviathan at the Trench |
| 2 | `02_who_sent_this.jpg` | WHO SENT THIS? | Sunset: a green bottle with a glowing rolled-up map bumps the raft, a survivor reaching for it | Bottles drift in with charts to new places |
| 3 | `03_where_did_they_go.jpg` | WHERE DID THEY GO? | Fog at dusk: a survivor with a lantern walks up the beach toward empty huts, one doorway lit, footprints in the sand | Mist Hollow |
| 4 | `04_who_built_that.jpg` | WHO BUILT THAT? | Thick fog: a huge two-deck raft fortress with lanterns and turrets looms over a tiny 2 × 2 starter raft | Other players' rafts (VISIT), and what yours can become |
| 5 | `05_what_are_they_watching.jpg` | WHAT ARE THEY WATCHING? | Sunset, low angle: three mossy stone totems tower over an explorer | The Ruin's totems |
| 6 | `06_who_was_on_it.jpg` | WHO WAS ON IT? | Pink dawn, snow falling: an old ship frozen into the ice, a survivor walking toward it | The Frost Shelf's frozen ship |

Number 1 is the lead: it has the raft, the ocean and the biggest mystery in one picture.

| Icon | Shows |
|---|---|
| `icon_bottle.png` (main) | A glowing bottle with a treasure map floating at dusk, a survivor on the raft reaching for it |
| `icon_shadow_alt.png` | A raft seen from above with the Leviathan's shadow, one glowing eye, passing under it |
| `icon_rod_alt.png` | A survivor with the rod on a raft under a white sail, looking at a glowing light on the horizon |

The plan says the raft must be recognisable at a glance and that the art must not copy *Raft*'s branding or
layout: every image is built around the game's own plank-tile rafts and blocky survivors, and none uses another
game's title layout. Test the thumbnails against each other and keep the one with the most clicks that also keeps
players.

## Checklist (Roblox thumbnail and ad rules)

- [x] **Matches the game.** Every place and thing in them is in the game (see the table).
- [x] **No promises.** No "FREE", "NEW", "UPDATE", rewards or prizes.
- [x] **No fake interface.** No fake buttons, menus or prompts.
- [x] **Kid-friendly.** Mysterious, not scary: no blood, no gore, no jump scares.
- [x] **Simple and readable.** One subject, one question, big letters that read on a phone.
- [x] **Size.** 16:9, 1920 × 1080, under 0.5 MB. Icons 512 × 512.

## Upload them

In Studio, with the place open: **Home → Game Settings → Basic Info**.

1. **Game Icon**: upload `../icon/icon_bottle.png`.
2. **Thumbnails**: remove the old ones and upload `01` to `06` in that order (the first is the one people see
   first). Save.

(The same fields are on the experience's page on the Creator Hub, create.roblox.com.) To compare them, put a
different one first for a week at a time and watch the click-through rate in the experience's analytics.

## Making them again

1. Render the references: see [`../screenshots/README.md`](../screenshots/README.md) (the mystery scenes are
   `11` to `16`; the Leviathan is `07`, a raft is `03`).
2. Upload the renders to Higgsfield and generate each picture with GPT Image 2.5 (high quality, 2k, 16:9; icons
   1:1) with one or two renders as image references. Each prompt describes the scene, asks for the blocky Roblox
   style of the references, one clear subject with the top third left free for the question, "mysterious and
   curious, kid-friendly, not scary", and no text.
3. Letter them: `python3 tools/gameplay/title_art.py art.png out.jpg --font LuckiestGuy.ttf --caption-only
   --caption "WHO SENT THIS?" --left` (`--at X,Y`, `--size`, and a `|` to break a long question).
