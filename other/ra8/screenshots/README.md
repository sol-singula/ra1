# The Endless Voyage: gameplay renders

![The renders](_all.jpg)

These are **renders of the game's own models**, not AI: the ocean and the island terrain (`OceanBuilder` writes
the water, `IslandBuilder` the islands' smooth terrain and their palms, bushes, rocks, ore, wrecks, ruins and
containers), the raft pieces at their real grid positions the way `RaftService` builds them (`RaftModels`), the
debris that drifts past (`OceanModels`), the creatures' rigs posed the way the client poses them (`Rigs`), the
tools and items (`ItemModels`) and the effects' shapes, staged into a few moments by
`games/ra8 - The Endless Voyage/tools/gameplay/thumbs.luau`, drawn with three.js (`render.js` + `terrain.js`),
then the shader pass (`thumbs_post.py`: levels, colour grade, bloom, depth of field, vignette). The survivors are
plain blocky Roblox avatars (in the game they're the players' own avatars). They are the references the
[thumbnails and icon](../thumbnails/README.md) were made from.

The renderer stands in for Roblox's: the terrain's voxels are meshed and textured per material, and parts get
textures for their Roblox material (free CC0 sets from ambientCG picked to look like Roblox's own,
`fetch_textures.py`). The water is a flat plane here; in Roblox it's terrain water with waves.

| File | Moment |
|---|---|
| `01_first_cast.jpg` | The first minute: two survivors on the 2 x 2 driftwood platform, the rod's line cast out to a plank, debris drifting past |
| `02_build_your_raft.jpg` | A survival raft growing: a tile being hammered down, the workbench behind, more wood coming aboard |
| `03_set_sail.jpg` | Setting sail: the sail up, a hand at the helm, dolphins alongside, Palm Key ahead |
| `04_palm_key.jpg` | Ashore on Palm Key: chopping a palm, a chest among the bushes, crabs on the beach |
| `05_the_wreck.jpg` | The Drifter: a hull on its side, a crowbar at the salvage, a lurker in the reeds |
| `06_storm.jpg` | A storm at sea: spray over the deck, a cracked tile, the hammer out, a shark at the edge |
| `07_the_leviathan.jpg` | Night at the Trench: the Leviathan surfacing beside a floating fortress, harpoons flying |
| `08_legendary_vessel.jpg` | A legendary vessel at dusk: two decks, gold flags, the aquarium, the trophy stand |
| `09_the_cast.jpg` | Everything that lives out there, on Gull Rock's shore: gulls, crabs, lurkers, a serpent, the Guardian |
| `10_the_ocean.jpg` | The ocean from above: six plots and their rafts, an island or two, the horizon's isles |

Re-render them from the game folder:

```bash
python3 tools/gameplay/fetch_textures.py textures        # once: the PBR texture sets
tools/luaurun/target/release/luaurun tools/gameplay/thumbs.luau out          # [only,...] renders a few
node tools/gameplay/render.js out renders --modules <node_modules with puppeteer, three, @fontsource> --textures textures
cp out/*.json renders/   # (the shader pass reads each shot's camera from its snapshot)
python3 tools/gameplay/thumbs_post.py renders post --font <LuckiestGuy.ttf>
```

`post/<name>_notext.jpg` are the images here; `post/<name>.jpg` have the title and a caption.
