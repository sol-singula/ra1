# Build the Biggest Raft: store thumbnails and the icon

![The 6 store thumbnails and the 4 icons](_all.jpg)

These are the pictures for **the game's own page** (its thumbnails on Home and on the game's page) and its icon. The
dark, text-free pictures for ads are in [`../ads/`](../ads/README.md).

Every thumbnail is **1920 × 1080 (16:9), JPG, under 0.6 MB** (Roblox takes up to 3 MB). The icon is
`../icon/icon_main.png`, **512 × 512 PNG**. `icon_raft_city_alt.png`, `icon_bottle_alt.png` and
`icon_shadow_alt.png` are alternates for an icon test.

**The idea: say what the game is.** Someone on the game's page is deciding whether to press Play, so these are
bright and plain. Each one carries the name, **BUILD THE BIGGEST RAFT**, and one short line about what you do, in
words a third grader reads easily. The name sits at the top like a logo, which Roblox allows. Roblox puts the
player count along the bottom, so nothing important goes there. The mystery is for the ads; these show the fun.

**They show what is in the game.** Each one was made with AI image generation (Higgsfield, GPT Image 2.5, high
quality, 2k) with **real renders of the game** as references (in [`../screenshots/`](../screenshots/README.md)): the
plank-tile rafts on their log floats, the blocky survivors, the rod, the drifting planks, barrels and crates, the
sail and helm, Palm Key's palms, chests and crabs, the dolphins, the harpoon turrets and the Leviathan's
long-jawed rig. In the game the survivors are the players' own avatars. The words were lettered afterwards in the
game's own font (Luckiest Guy, like the HUD) with `tools/gameplay/title_art.py`.

| # | File | Line | Picture | In the game |
|---|---|---|---|---|
| 1 | `01_build_the_biggest_raft.jpg` | START SMALL. GO BIG! | A giant raft with decks, sails, flags and gardens full of survivors, and beside it a tiny 2 × 2 raft with one survivor | Where you start (the 2 × 2 platform) and what it becomes |
| 2 | `02_catch_what_floats_by.jpg` | CATCH WHAT FLOATS BY | Two survivors on a small raft, one casting the rod at planks, barrels and a crate drifting past, an island behind | The rod and the debris: the first minute |
| 3 | `03_build_with_friends.jpg` | BUILD WITH FRIENDS | Three survivors building one raft: hammering a tile down, carrying planks, a sail going up | Friends join your raft and build with you |
| 4 | `04_sail_to_new_islands.jpg` | SAIL TO NEW ISLANDS | A raft under sail, a survivor at the helm, dolphins jumping alongside, a palm island ahead | Voyages: the sail, the helm, dolphins, Palm Key |
| 5 | `05_find_treasure.jpg` | FIND TREASURE | On a beach, a survivor opens a glowing chest while another chops a palm, crabs on the sand, the raft waiting offshore | Island chests, chopping palms, Reef Crabs |
| 6 | `06_face_the_leviathan.jpg` | FACE THE LEVIATHAN | Sunset: the Leviathan bursts out of the sea beside a fortress raft, survivors firing its harpoon turrets | The Leviathan at the Trench, the turrets |

Number 1 is the lead: it is the name in one picture. A few details are made up for the pictures: island chests
give blueprints, pearls, gear and old tech rather than glowing gold, and the Leviathan is drawn bigger than it is.

| Icon | Shows |
|---|---|
| `icon_main.png` (main) | A grinning survivor holding up a hammer in front of a huge raft with sails and flags: the name in one look, clear even at 150 pixels |
| `icon_raft_city_alt.png` | A towering raft with decks, sails and a crow's nest on bright water |
| `icon_bottle_alt.png` | A survivor on the raft reaching for a glowing bottle with a map at dusk (the last icon) |
| `icon_shadow_alt.png` | A raft seen from above with the Leviathan's shadow, one glowing eye, passing under it |

The plan says the raft must be recognisable at a glance and that the art must not copy *Raft*'s branding or
layout: every picture is built around the game's own plank-tile rafts and blocky survivors, and the title is
lettered in the game's own font.

## Checklist (Roblox thumbnail rules)

- [x] **Matches the game.** Every place, creature and piece in them is in the game (see the table).
- [x] **No promises.** No "FREE", "NEW", "UPDATE", rewards, prizes or prices. The lines say what you do.
- [x] **No fake interface.** No buttons, menus or prompts.
- [x] **Kid-friendly.** No blood, no gore.
- [x] **Text at the top.** The name and the line stay clear of the player count at the bottom.
- [x] **Size.** 16:9, 1920 × 1080, under 0.6 MB. Icon 512 × 512.

Roblox's thumbnail guide also asks for graphics that look like what a player will see. These are lit and finished
more richly than the game. If moderation pushes back, letter the game's own renders in
[`../screenshots/`](../screenshots/README.md) the same way (step 3 below) and use those.

## Upload them

On the Creator Hub: **Creator Dashboard** (create.roblox.com/dashboard/creations) → Build the Biggest Raft →
**Configurations → Places** → the start place (the one with the star).

1. **Icon**: media type Image → **Change** → `../icon/icon_main.png` → check the preview → **Save Changes**.
2. **Thumbnails → Experience Detail Page**: remove the old ones and upload `01` to `06` in that order (the first is
   the one people see first). Save.
3. **Thumbnails → Home Page**: turn on two to five of them (`01`, `02`, `04` and `06` to start). With two or more
   on, Roblox picks which one each player sees on Home.

Every upload is moderated before others see it. To compare icons, swap in an alternate for a week at a time and
watch the click-through rate in the experience's analytics.

## The description

For the game's page (Configurations → Basic Info), in the same plain words:

> Start on a tiny raft in the middle of the ocean. Catch the wood, barrels and crates that float by. Build your
> raft bigger and bigger! Raise a sail and find islands, wrecks and treasure. Play with your friends. Watch out
> for sharks... and for what lives in the deep.

## Making them again

1. Render the references: see [`../screenshots/README.md`](../screenshots/README.md) (a raft is `02` and `03`, an
   island `04`, the Leviathan `07`, a big raft `08`).
2. Upload the renders to Higgsfield and generate each picture with GPT Image 2.5 (high quality, 2k, 16:9; icons
   1:1) with one or two renders as image references. Each prompt describes the scene, asks for the blocky Roblox
   style of the references, bright daylight (sunset for the Leviathan), the top quarter kept simple for the title,
   and no text.
3. Letter them: `python3 tools/gameplay/title_art.py art.png out.jpg --font LuckiestGuy.ttf --caption "FIND TREASURE"
   --title-size 110 --at 1180,36`. The title is BUILD THE BIGGEST RAFT unless `--title` gives another (a `|` breaks
   it into lines, as in number 1: `--title "BUILD THE|BIGGEST RAFT" --title-size 120 --left`); `--left`, `--right`
   or `--at X,Y` (the top middle of the words) place it.
4. Make the sheet: `python3 tools/gameplay/contact_sheet.py _all.jpg --cols 3 --width 640 0*.jpg --icons
   ../icon/icon_main.png ../icon/icon_raft_city_alt.png ../icon/icon_bottle_alt.png ../icon/icon_shadow_alt.png`.
