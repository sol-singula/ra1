--[[
The mutation looks from Game Artist build-spec/02-mutations.md (GA-02), its tables as data. Models/Crop (the fruit
recolour, GoldLight, beads, soil, lights) and Visuals (the pooled MutFx / MutDrops emitters) read these; nothing
here is tuned by hand.

  golden / wetgolden   the fruit by Tone: { hex, material, reflectance }
  wet                  reflectance and the precomputed GA-02 section 3.1 colours, by crop and part name
  overrides            the crop exceptions of section 1.1 / 4: "keep" (the template look), "wet" (the wet colour),
                       "base" (the base tone's look) or a look table
  highlight            the GoldLight painted part (section 2.2); highlightOn = the largest fruit part per crop
  beads / glint / drip / light / soil / large / caps / chips / labels
]]
-- stylua: ignore start
local MutationVisuals = {}

MutationVisuals.golden = {
	base = { hex = "#FFC300", material = "Metal", reflectance = 0.15 },
	detail = { hex = "#E0A100", material = "Metal", reflectance = 0.10 },
}
MutationVisuals.wetgolden = {
	base = { hex = "#D9A600", material = "Metal", reflectance = 0.35 },
	detail = { hex = "#BE8900", material = "Metal", reflectance = 0.30 },
}

-- section 3.1 (V x 0.85, S x 1.15 of each template hex), material unchanged, Reflectance 0.30
local function each(names, hex, into)
	for _, name in names do
		into[name] = hex
	end
	return into
end
local function n(prefix, count)
	local out = {}
	for i = 1, count do
		out[i] = prefix .. i
	end
	return out
end
MutationVisuals.wet = {
	reflectance = 0.30,
	colours = {
		carrot = { Fruit1 = "#D06A08", FruitDetail1 = "#BE5B01" },
		strawberry = each(n("FruitDetail", 4), "#40A51C", each(n("Fruit", 4), "#C31427", {})),
		blueberry = each(n("Fruit", 6), "#2B3EAA", {}),
		tomato = each(n("Fruit", 4), "#BB150B", {}),
		corn = each(n("FruitDetail", 2), "#71A824", each(n("Fruit", 2), "#D0AE1B", {})),
		pumpkin = { Fruit1 = "#CC6100", Fruit2 = "#C05700", Fruit3 = "#C05700" },
		watermelon = each(n("FruitDetail", 4), "#115B1B", { Fruit1 = "#268830", Fruit2 = "#268830" }),
		dragonfruit = each(n("FruitDetail", 6), "#60A329", each(n("Fruit", 2), "#C8267E", {})),
		-- FruitDetail4 (the crescent cut) is the skin's #BEC8FF, so it takes the skin's wet colour
		moonmelon = {
			Fruit1 = "#99A3D9", FruitDetail1 = "#8693D0", FruitDetail2 = "#8693D0",
			FruitDetail3 = "#CDCFD9", FruitDetail4 = "#99A3D9",
		},
	},
}

-- section 1.1 / 4: corn husks stay green under Golden and wet green under Wet+Golden; the Moon Melon's crescent
-- becomes the highlight and its cut the base gold
local HIGHLIGHT_LOOK = { hex = "#FFF1A8", material = "SmoothPlastic", reflectance = 0 }
MutationVisuals.overrides = {
	corn = {
		golden = { FruitDetail1 = "keep", FruitDetail2 = "keep" },
		wetgolden = { FruitDetail1 = "wet", FruitDetail2 = "wet" },
	},
	moonmelon = {
		golden = { FruitDetail3 = HIGHLIGHT_LOOK, FruitDetail4 = "base" },
		wetgolden = { FruitDetail3 = HIGHLIGHT_LOOK, FruitDetail4 = "base" },
	},
}

-- section 2.2
MutationVisuals.highlight = {
	hex = "#FFF1A8",
	size = { 0.30, 0.20 }, -- x Fx, x Fy
	thickness = 0.06,
	min = { 0.14, 0.10 },
	direction = { -0.45, 0.55, -0.70 },
	push = 0.02,
}
MutationVisuals.highlightOn = {
	carrot = "Fruit1", strawberry = "Fruit3", blueberry = "Fruit1", tomato = "Fruit1", corn = "Fruit1",
	pumpkin = "Fruit1", watermelon = "Fruit1", dragonfruit = "Fruit1", -- moonmelon: none
}

-- section 3.2 (sizes in the 2:2:1 ratio)
MutationVisuals.beads = {
	sizes = { 0.16, 0.16, 0.20, 0.20, 0.24 },
	wet = { hex = "#DFF4FF", transparency = 0.35, reflectance = 0.25 },
	wetgolden = { hex = "#E8F6FF", transparency = 0.30, reflectance = 0.25 },
	sink = 0.4, -- of the diameter
	spacing = 0.25,
	minY = -0.2, -- x Fy
	frontZ = 0.3, -- x Fz
	seedA = 7919,
	counts = {
		carrot = 6, strawberry = 6, blueberry = 6, tomato = 8, corn = 6,
		pumpkin = 10, watermelon = 10, dragonfruit = 8, moonmelon = 10,
	},
	onDetails = { corn = true }, -- corn: on the kernels and the husk tips
}

-- section 2.3
MutationVisuals.glint = {
	rate = 0.35,
	rateWetGolden = 0.25,
	colours = { "#FFF1A8", "#FFFFFF" },
	lightEmission = 0.4,
	lightInfluence = 0,
	lifetime = { 0.35, 0.45 },
	size = 0.55,
	sizeLarge = 0.7,
	transparency = 0.1,
	rotation = { 0, 45 },
	zOffset = 0.3,
	bounds = 0.9, -- the Fx host is the fruit bounds x 0.9
}

-- section 3.3
MutationVisuals.drip = {
	rate = 3,
	rateLarge = 4,
	hex = "#8FD3FF",
	lightEmission = 0.1,
	lightInfluence = 1,
	lifetime = { 0.5, 0.8 },
	speed = { 0, 0.5 },
	acceleration = { 0, -16, 0 },
	size = { { 0, 0.10 }, { 0.2, 0.14 }, { 1, 0.12 } },
	squash = { { 0, 0.9 }, { 1, 1.3 } },
	transparency = { { 0, 0.15 }, { 0.8, 0.3 }, { 1, 1 } },
	at = { 0, -0.35, -0.25 }, -- x (Fx, Fy, Fz) from the fruit centre
}

-- section 2.4
MutationVisuals.light = { hex = "#FFD27A", golden = 0.6, wetgolden = 0.5, range = 5, rangeLarge = 6 }

-- section 3.4
MutationVisuals.soil = { hex = "#683D1C", reflectance = 0.10 }

MutationVisuals.large = { pumpkin = true, watermelon = true, moonmelon = true }

-- section 5
MutationVisuals.caps = {
	emittingPerPlot = 3,
	weights = { wet = 1, golden = 1, wetgolden = 2 },
	lights = 8,
	lodStuds = 160,
	beadStuds = 80,
}
MutationVisuals.maxMutParts = 11

-- section 4: the UI chips (Backpack, Index, pedestal tag)
MutationVisuals.chips = {
	wet = { fill = "#50AAFF", stroke = "#1E1B2E" },
	golden = { fill = "#FFC300", stroke = "#1E1B2E" },
	wetgolden = { fill = "#FFC300", stroke = "#50AAFF" },
	strokeThickness = 2,
	text = "#FFFFFF",
	textStroke = "#1E1B2E",
}
MutationVisuals.labels = { wet = "Wet x2", golden = "Golden x20", wetgolden = "Wet+Golden x40" }
-- stylua: ignore end

return MutationVisuals
