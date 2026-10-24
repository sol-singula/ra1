--[[
The Block Party sunflower of Game Artist build-spec/03-sunflower.md (GA-03), its tables as data. Models/Sunflower
builds and poses the parts from these; SunflowerController times the tweens, the wilt, the bloom VFX, the thirsty
icon and the LOD. Offsets are from the origin O (the ground under the flower, front = -Z); degrees throughout.

  parts        section 2.1 / 2.2: { name, shape, size, offset, rot (degrees), hex }; shape "block" | "cylV" | "wedge"
  stemOf       which stem segment each leaf rides on (the leaf at that height)
  head         section 2.3 / 2.4: the disc, the seed dots, the 18 petals, FxBloom
  poses        section 3: per stage, the deltas from bloom (stem tilts, head tilt, petal cup, leaf droop) and colours
  wilt         section 3.4 / 0: the wilt's petal colour (deep wilt)
  tween / bloom / fx / thirsty / lod   sections 3, 3.5, 4, 5, 6
]]
-- stylua: ignore start
local SunflowerVisuals = {}

SunflowerVisuals.parts = {
	{ name = "Root", shape = "block", size = { 0.2, 0.2, 0.2 }, offset = { 0, 0.1, 0 }, hex = "#7A4E2D", transparency = 1 },
	{ name = "StemBase", shape = "cylV", size = { 1.6, 1.4, 1.4 }, offset = { 0, 0.8, 0 }, hex = "#4E9A2A", shadow = true },
	{ name = "Stem1", shape = "cylV", size = { 5.0, 1.1, 1.1 }, offset = { 0, 4.1, 0 }, hex = "#5BC236", shadow = true },
	{ name = "Stem2", shape = "cylV", size = { 5.0, 1.0, 1.0 }, offset = { 0, 9.1, 0 }, hex = "#5BC236", shadow = true },
	{ name = "Stem3", shape = "cylV", size = { 5.0, 0.9, 0.9 }, offset = { 0, 14.1, 0 }, hex = "#5BC236", shadow = true },
	{ name = "Stem4", shape = "cylV", size = { 3.5, 0.8, 0.8 }, offset = { 0, 18.35, 0 }, hex = "#5BC236" },
	{ name = "HeadPivot", shape = "block", size = { 0.3, 0.3, 0.3 }, offset = { 0, 20.3, 0 }, hex = "#7A4E2D", transparency = 1 },
	{ name = "LeafL1", shape = "wedge", size = { 0.25, 1.6, 3.2 }, offset = { -1.6, 6.0, 0.2 }, rot = { 0, 90, -25 }, hex = "#2E7D32", shadow = true },
	{ name = "LeafR1", shape = "wedge", size = { 0.25, 1.6, 3.2 }, offset = { 1.6, 7.5, -0.2 }, rot = { 0, -90, 25 }, hex = "#2E7D32", shadow = true },
	{ name = "LeafL2", shape = "wedge", size = { 0.22, 1.3, 2.6 }, offset = { -1.3, 11.5, -0.4 }, rot = { 0, 110, -20 }, hex = "#4E9A2A", shadow = true },
	{ name = "LeafR2", shape = "wedge", size = { 0.22, 1.3, 2.6 }, offset = { 1.3, 13.0, 0.3 }, rot = { 0, -110, 20 }, hex = "#4E9A2A", shadow = true },
}
SunflowerVisuals.stems = { "Stem1", "Stem2", "Stem3", "Stem4" }
SunflowerVisuals.stemBaseTop = 1.6 -- StemBase (0.8 + 1.6 / 2): where Stem1 hinges
SunflowerVisuals.headGap = 0.2 -- HeadPivot (20.3) above Stem4's top (18.35 + 3.5 / 2)
SunflowerVisuals.stemOf = { LeafL1 = "Stem1", LeafR1 = "Stem2", LeafL2 = "Stem2", LeafR2 = "Stem3" }
SunflowerVisuals.leafTone = { LeafL1 = "leafTop", LeafR1 = "leafTop", LeafL2 = "leafUnder", LeafR2 = "leafUnder" }

SunflowerVisuals.head = {
	discAt = 0.8, -- above HeadPivot
	disc = { size = { 0.70, 3.6, 3.6 }, hex = "#7A4E2D" },
	seeds = { count = 8, size = 0.35, ring = 1.1, z = -0.40, hex = "#5C3A1F" }, -- 7 on the ring + 1 in the centre
	petals = { count = 18, size = { 0.18, 1.1, 3.4 }, rim = 1.85, step = 20, cup = -8, hex = "#FFD23F" },
	fxAt = { 0, 0.8, -0.35 },
}

-- section 3: deltas from bloom; tilt = the four stem segments (each relative to the one below), head = the head's
-- nod (the face toward the ground), cup = the petals closing over the face, leaf = the leaf tips down
SunflowerVisuals.poses = {
	bloom = {
		tilt = { 0, 0, 0, 0 }, head = 0, cup = 0, leaf = 0,
		petal = "#FFD23F", disc = "#7A4E2D", seed = "#5C3A1F", stem = "#5BC236", leafTop = "#2E7D32", leafUnder = "#4E9A2A",
	},
	standing = {
		tilt = { 4, 4, 4, 4 }, head = 10, cup = -35, leaf = 12,
		petal = "#FFD23F", disc = "#7A4E2D", seed = "#5C3A1F", stem = "#5BC236", leafTop = "#2E7D32", leafUnder = "#4E9A2A",
	},
	perking = {
		tilt = { 10, 10, 10, 10 }, head = 28, cup = -55, leaf = 22,
		petal = "#FFD23F", disc = "#7A4E2D", seed = "#5C3A1F", stem = "#5BC236", leafTop = "#2E7D32", leafUnder = "#4E9A2A",
	},
	-- the spec gives drooping no leaf angle; the leaves keep perking's +22 so they never lift as it droops
	drooping = {
		tilt = { 16, 14, 12, 10 }, head = 55, cup = -70, leaf = 22,
		petal = "#E6C96D", disc = "#6B4528", seed = "#6B4528", stem = "#6EAF56", leafTop = "#3F7041", leafUnder = "#5B8B44",
	},
}
SunflowerVisuals.wilt = { petal = "#C8B070" } -- section 0: deep wilt; the rest lerps to drooping

SunflowerVisuals.tween = { sec = 0.6 } -- Back Out
SunflowerVisuals.bloom = { sec = 1.5, shakeSec = 0.2, shakeAmp = 0.15, shakeStuds = 60 } -- Back Out

-- section 4
SunflowerVisuals.fx = {
	sec = 1.0,
	colours = { rain = "#3FA7F5", goldenHour = "#FFC300" },
	pop = {
		emit = 18, colours = { "#FFD23F", "#FFE066" }, lifetime = { 0.4, 0.6 }, speed = { 6, 10 },
		size = { { 0, 0.4 }, { 0.5, 0.7 }, { 1, 0 } }, transparency = { { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } },
		lightEmission = 0.3, squash = 0,
	},
	burst = {
		emit = 24, lifetime = { 0.5, 0.8 }, speed = { 10, 16 }, spread = { 180, 180 }, acceleration = { 0, -8, 0 },
		size = { { 0, 0.3 }, { 1, 0 } }, transparency = { { 0, 0.1 }, { 1, 1 } }, lightEmission = 0.5,
	},
	beam = {
		bottom = -8, top = 14, width = { 2.5, 0.4 }, transparency = { { 0, 0.2 }, { 0.7, 0.4 }, { 1, 1 } },
		lightEmission = 0.6, segments = 8,
	},
	light = { brightness = 1.2, range = 20 },
	reducedEmit = 0.5, -- 9 / 12
}

-- section 5
SunflowerVisuals.thirsty = {
	size = 64, offset = 3.5, bob = { 3.3, 3.7 }, bobSec = 1.2, maxDistance = 80, hex = "#3FA7F5",
}

-- section 6
SunflowerVisuals.lod = { studs = 160 }
SunflowerVisuals.artParts = 38
-- stylua: ignore end

return SunflowerVisuals
