--[[
The crop builds from Game Artist build-spec/01-crops.md (GA-01), row for row. Models/Crop turns these rows into parts;
nothing here is tuned by hand. Numbers are exactly the spec's (report a problem instead of changing one).

A row is { name, shape, size, pos, rot?, hex, opts? }:
  shape   "Block" | "Ball" (size is one number) | "Ell" (Block + Sphere SpecialMesh) | "CylV" | "Disc" (a Cylinder
          stood up: the rz = 90 is added by the builder, after rot) | "Wedge"
  pos     the part centre relative to O (the soil under the tile centre); rot (rx, ry, rz) in degrees, as
          CFrame.new(pos) * CFrame.Angles(rx, ry, rz)
  opts    on = "<part>": pos and rot are in that part's own frame (GA-01's "local" rows); rot nil = the same
          rotation as that part. reflectance = n. light = { name, hex, brightness, range }
Where GA-01 gives a part as "each Fruit + (0, 0.29, 0)" or "each husk + 0.08 toward -Z, +0.12 y", the row holds
the sum.

  thresholds      sprout 0.20, growing 0.50 (ripe = the tile's Ripe, or progress >= 1)
  root / seedStage / seedBall / sprouts / crops[seed] = { sprout, fx, growing, ripe }
  fx              the FxAnchor centroid per stage (seed, sprout; growing and ripe use the crop's)
  maxParts / maxHeight / footprint / farStuds    the GA-01 limits
]]
-- stylua: ignore start
local function R(name, shape, size, pos, rot, hex, opts)
	return { name = name, shape = shape, size = size, pos = pos, rot = rot, hex = hex, opts = opts }
end

local SOIL, SOIL_DARK = "#7A4E2D", "#5C3A1F"
local LEAF, LEAF_DARK = "#5BC236", "#2E7D32"
local STEM, WOOD, BARK = "#4E9A2A", "#A87B4F", "#6B4A2B"
local UNRIPE = "#9CC74A"
local CREAM, BUTTER = "#FFF8E7", "#FFD23F"

local CropVisuals = {}

CropVisuals.thresholds = { sprout = 0.20, growing = 0.50 }
CropVisuals.maxParts = 14
CropVisuals.maxHeight = 3.25
CropVisuals.footprint = 3.4
CropVisuals.farStuds = 120
CropVisuals.fx = { seed = { 0, 0.5, 0 }, sprout = { 0, 0.8, 0 } }

-- §1
CropVisuals.root = R("Root", "CylV", { 0.30, 2.8, 2.8 }, { 0, 0.15, 0 }, nil, SOIL)
CropVisuals.seedStage = {
	R("Hole", "Disc", { 0.04, 0.9, 0.9 }, { 0, 0.31, 0 }, nil, SOIL_DARK),
	-- Seed: CropVisuals.seedBall[seed]
	R("Stake", "Block", { 0.12, 1.0, 0.12 }, { 0.95, 0.80, -0.95 }, nil, WOOD),
	-- Tag: the crop's fruit hex
	R("Tag", "Block", { 0.60, 0.45, 0.08 }, { 0.95, 1.20, -1.01 }, { 0, -20, 0 }, nil),
}
CropVisuals.seedPos = { 0, 0.36, 0 }
CropVisuals.seedBall = {
	carrot = { 0.22, "#D9B98A" },
	strawberry = { 0.18, "#F2D45C" },
	blueberry = { 0.20, "#465AC8" },
	tomato = { 0.22, "#EADBB8" },
	corn = { 0.30, "#F5D23C" },
	pumpkin = { 0.32, "#F3E3C3" },
	watermelon = { 0.26, "#2B2B2B" },
	dragonfruit = { 0.20, "#1E1B2E" },
	moonmelon = { 0.30, "#E6EBFF" },
}

-- §2: Root, Stake and Tag stay from the seed stage; these are the seedlings
CropVisuals.sprouts = {
	carrot = {
		R("Leaf1", "Block", { 0.08, 0.55, 0.18 }, { 0, 0.575, 0 }, { 0, 0, 0 }, LEAF),
		R("Leaf2", "Block", { 0.08, 0.55, 0.18 }, { -0.10, 0.575, 0 }, { 0, 0, 18 }, LEAF_DARK),
		R("Leaf3", "Block", { 0.08, 0.55, 0.18 }, { 0.10, 0.575, 0 }, { 0, 0, -18 }, LEAF),
	},
	corn = {
		R("Leaf1", "Block", { 0.10, 0.80, 0.30 }, { 0, 0.70, 0 }, { 0, 90, 12 }, LEAF),
		R("Leaf2", "Block", { 0.10, 0.80, 0.30 }, { -0.10, 0.70, 0 }, { 0, 90, -12 }, LEAF_DARK),
	},
	dragonfruit = {
		R("Stem1", "Block", { 0.30, 0.50, 0.30 }, { 0, 0.55, 0 }, { 0, 45, 0 }, "#3E8E3E"),
		R("Leaf1", "Wedge", { 0.10, 0.18, 0.14 }, { 0.20, 0.70, 0 }, { 0, 90, 0 }, "#7BC043"),
		R("Leaf2", "Wedge", { 0.10, 0.18, 0.14 }, { -0.20, 0.62, 0 }, { 0, -90, 0 }, "#7BC043"),
	},
}
local function cotyledons(big, leaf3, stemHex, leafHex)
	local size = if big then { 0.62, 0.08, 0.40 } else { 0.48, 0.08, 0.30 }
	local x = if big then 0.31 else 0.24
	local rows = {
		R("Stem1", "Block", { 0.12, 0.40, 0.12 }, { 0, 0.50, 0 }, nil, stemHex or STEM),
		R("Leaf1", "Ell", size, { -x, 0.72, 0 }, { 0, 0, 15 }, leafHex or LEAF),
		R("Leaf2", "Ell", size, { x, 0.72, 0 }, { 0, 0, -15 }, leafHex or LEAF),
	}
	if leaf3 then
		table.insert(rows, R("Leaf3", "Ell", { 0.26, 0.06, 0.34 }, { 0, 0.78, -0.12 }, { -25, 0, 0 }, LEAF_DARK))
	end
	return rows
end
CropVisuals.sprouts.strawberry = cotyledons(false, true)
CropVisuals.sprouts.blueberry = cotyledons(false, true)
CropVisuals.sprouts.tomato = cotyledons(false, true)
CropVisuals.sprouts.pumpkin = cotyledons(true, false)
CropVisuals.sprouts.watermelon = cotyledons(true, false)
CropVisuals.sprouts.moonmelon = cotyledons(true, false, "#8FBFA8", "#A9DCCB")

-- §3 (Root is added to every build by the builder)
CropVisuals.crops = {}

-- §3.1
local carrotLeafG = { 0.10, 0.80, 0.30 }
local carrotLeafR = { 0.14, 1.10, 0.40 }
CropVisuals.crops.carrot = {
	fx = { 0, 0.6, 0 },
	growing = {
		R("Bud1", "CylV", { 0.30, 0.55, 0.55 }, { 0, 0.40, 0 }, nil, "#F7A85A"),
		R("Leaf1", "Block", carrotLeafG, { 0, 0.95, 0 }, { 0, 0, 0 }, LEAF),
		R("Leaf2", "Block", carrotLeafG, { -0.18, 0.90, 0 }, { 0, 0, 25 }, LEAF_DARK),
		R("Leaf3", "Block", carrotLeafG, { 0.18, 0.90, 0 }, { 0, 0, -25 }, LEAF_DARK),
		R("Leaf4", "Block", carrotLeafG, { 0, 0.90, 0.18 }, { 25, 0, 0 }, LEAF),
	},
	ripe = {
		R("Fruit1", "CylV", { 0.60, 0.90, 0.90 }, { 0, 0.55, 0 }, nil, "#F58C28"),
		R("FruitDetail1", "Disc", { 0.08, 0.70, 0.70 }, { 0, 0.89, 0 }, nil, "#E07A1E"),
		R("Leaf1", "Block", carrotLeafR, { 0, 1.45, 0 }, { 0, 0, 0 }, LEAF),
		R("Leaf2", "Block", carrotLeafR, { -0.25, 1.38, 0 }, { 0, 0, 28 }, LEAF_DARK),
		R("Leaf3", "Block", carrotLeafR, { 0.25, 1.38, 0 }, { 0, 0, -28 }, LEAF_DARK),
		R("Leaf4", "Block", carrotLeafR, { 0, 1.38, 0.25 }, { 28, 0, 0 }, LEAF),
		R("Leaf5", "Block", carrotLeafR, { 0, 1.38, -0.25 }, { -28, 0, 0 }, LEAF),
	},
}

-- §3.2
local flower = { 0.06, 0.36, 0.36 }
local berry = { 0.45, 0.55, 0.45 }
local calyx = { 0.36, 0.06, 0.36 }
local bushR = { 1.2, 0.6, 1.2 } -- GA-01: "the same 3 Leaf parts at 1.2x size (1.2, 0.6, 1.2)"
CropVisuals.crops.strawberry = {
	fx = { 0, 0.5, -0.5 },
	growing = {
		R("Leaf1", "Ell", { 1.0, 0.50, 1.0 }, { -0.45, 0.50, 0.25 }, nil, LEAF_DARK),
		R("Leaf2", "Ell", { 1.0, 0.50, 1.0 }, { 0.45, 0.50, 0.25 }, nil, LEAF),
		R("Leaf3", "Ell", { 1.0, 0.55, 1.0 }, { 0, 0.55, -0.35 }, nil, LEAF),
		R("Flower1", "Disc", flower, { -0.35, 0.82, -0.55 }, { -30, 0, 0 }, CREAM),
		R("Flower2", "Disc", flower, { 0.50, 0.80, -0.30 }, { -20, 0, 0 }, CREAM),
		R("Flower3", "Disc", flower, { 0.05, 0.85, 0.35 }, { 20, 0, 0 }, CREAM),
	},
	ripe = {
		R("Leaf1", "Ell", bushR, { -0.45, 0.50, 0.25 }, nil, LEAF_DARK),
		R("Leaf2", "Ell", bushR, { 0.45, 0.50, 0.25 }, nil, LEAF),
		R("Leaf3", "Ell", bushR, { 0, 0.55, -0.35 }, nil, LEAF),
		R("Fruit1", "Ell", berry, { -0.80, 0.42, -0.75 }, { 0, 0, 10 }, "#E63246"),
		R("Fruit2", "Ell", berry, { 0.78, 0.42, -0.62 }, { 0, 0, -10 }, "#E63246"),
		R("Fruit3", "Ell", berry, { 0.15, 0.40, -1.05 }, nil, "#E63246"),
		R("Fruit4", "Ell", berry, { -0.20, 0.48, 0.95 }, nil, "#E63246"),
		R("FruitDetail1", "Block", calyx, { -0.80, 0.71, -0.75 }, { 0, 45, 0 }, LEAF),
		R("FruitDetail2", "Block", calyx, { 0.78, 0.71, -0.62 }, { 0, 45, 0 }, LEAF),
		R("FruitDetail3", "Block", calyx, { 0.15, 0.69, -1.05 }, { 0, 45, 0 }, LEAF),
		R("FruitDetail4", "Block", calyx, { -0.20, 0.77, 0.95 }, { 0, 45, 0 }, LEAF),
	},
}

-- §3.3
CropVisuals.crops.blueberry = {
	fx = { 0, 1.4, -0.6 },
	growing = {
		R("Stem1", "CylV", { 0.60, 0.18, 0.18 }, { 0, 0.60, 0 }, nil, BARK),
		R("Leaf1", "Ell", { 1.30, 0.80, 1.30 }, { 0, 1.10, 0 }, nil, LEAF_DARK),
		R("Leaf2", "Ell", { 0.90, 0.65, 0.90 }, { 0.25, 1.45, -0.15 }, nil, LEAF),
		R("Bud1", "Ball", 0.20, { -0.45, 1.05, -0.55 }, nil, "#A8D08D"),
		R("Bud2", "Ball", 0.20, { 0.40, 1.20, -0.55 }, nil, "#A8D08D"),
		R("Bud3", "Ball", 0.20, { 0, 1.45, -0.55 }, nil, "#A8D08D"),
		R("Bud4", "Ball", 0.20, { 0.55, 1.50, -0.25 }, nil, "#A8D08D"),
	},
	ripe = {
		R("Stem1", "CylV", { 0.80, 0.20, 0.20 }, { 0, 0.70, 0 }, nil, BARK),
		R("Leaf1", "Ell", { 1.60, 1.00, 1.60 }, { 0, 1.30, 0 }, nil, LEAF_DARK),
		R("Leaf2", "Ell", { 1.10, 0.80, 1.10 }, { 0.30, 1.75, -0.20 }, nil, LEAF),
		R("Fruit1", "Ball", 0.28, { -0.55, 1.15, -0.70 }, nil, "#465AC8"),
		R("Fruit2", "Ball", 0.28, { -0.33, 1.10, -0.75 }, nil, "#465AC8"),
		R("Fruit3", "Ball", 0.28, { 0.45, 1.35, -0.72 }, nil, "#465AC8"),
		R("Fruit4", "Ball", 0.28, { 0.65, 1.28, -0.62 }, nil, "#465AC8"),
		R("Fruit5", "Ball", 0.28, { 0.10, 1.72, -0.68 }, nil, "#465AC8"),
		R("Fruit6", "Ball", 0.28, { 0.30, 1.80, -0.62 }, nil, "#465AC8"),
	},
}

-- §3.4
local vine = { 0.18, 0.90, 0.18 }
local tomatoLeaf = { 0.60, 0.08, 0.40 }
local function tomatoVine(stake)
	return {
		stake,
		R("Vine1", "Block", vine, { -0.15, 0.75, 0.15 }, { 0, 0, 15 }, STEM),
		R("Vine2", "Block", vine, { 0.15, 1.55, 0.15 }, { 0, 0, -15 }, STEM),
		R("Vine3", "Block", vine, { -0.10, 2.25, 0.15 }, { 0, 0, 12 }, STEM),
		R("Leaf1", "Block", tomatoLeaf, { -0.45, 1.05, 0.1 }, { 0, 0, 20 }, LEAF),
		R("Leaf2", "Block", tomatoLeaf, { 0.45, 1.45, 0.1 }, { 0, 0, -20 }, LEAF_DARK),
		R("Leaf3", "Block", tomatoLeaf, { -0.45, 1.85, 0.1 }, { 0, 0, 20 }, LEAF),
		R("Leaf4", "Block", tomatoLeaf, { 0.40, 2.35, 0.1 }, { 0, 0, -20 }, LEAF_DARK),
	}
end
local tomatoGrowing = tomatoVine(R("Stake", "Block", { 0.15, 2.40, 0.15 }, { 0, 1.50, 0.30 }, nil, WOOD))
table.insert(tomatoGrowing, R("Bud1", "Ball", 0.40, { -0.40, 0.95, -0.15 }, nil, UNRIPE))
table.insert(tomatoGrowing, R("Bud2", "Ball", 0.40, { 0.38, 1.40, -0.20 }, nil, UNRIPE))
table.insert(tomatoGrowing, R("Bud3", "Ball", 0.40, { -0.30, 1.90, -0.15 }, nil, UNRIPE))
local tomatoRipe = tomatoVine(R("Stake", "Block", { 0.15, 2.60, 0.15 }, { 0, 1.60, 0.30 }, nil, WOOD))
table.insert(tomatoRipe, R("Fruit1", "Ball", 0.55, { -0.45, 0.95, -0.20 }, nil, "#DC3228"))
table.insert(tomatoRipe, R("Fruit2", "Ball", 0.55, { 0.40, 1.40, -0.25 }, nil, "#DC3228"))
table.insert(tomatoRipe, R("Fruit3", "Ball", 0.50, { -0.35, 1.90, -0.20 }, nil, "#DC3228"))
table.insert(tomatoRipe, R("Fruit4", "Ball", 0.45, { 0.30, 2.35, -0.15 }, nil, "#DC3228"))
CropVisuals.crops.tomato = { fx = { 0, 1.6, -0.2 }, growing = tomatoGrowing, ripe = tomatoRipe }

-- §3.5 (kernels: each husk + 0.08 toward -Z and +0.12 y, the husk's rotation). The shortened corn: the tassel
-- (Stem2-4) is dropped 0.28 from GA-01's table (Stem2 3.30 -> 3.02, Stem3/4 3.25 -> 2.97), so the ripe corn tops
-- out at 3.245, inside maxHeight 3.25 (signed follow-up to 4c6a860)
local cornLeafG = { 0.10, 1.10, 0.32 }
local cornLeafR = { 0.10, 1.40, 0.35 }
local tassel = { 0.06, 0.45, 0.06 }
local TAN = "#B89A6A"
CropVisuals.crops.corn = {
	fx = { 0, 1.45, -0.2 },
	growing = {
		R("Stem1", "CylV", { 2.00, 0.24, 0.24 }, { 0, 1.30, 0 }, nil, STEM),
		R("Leaf1", "Block", cornLeafG, { -0.40, 1.00, 0 }, { 0, 0, 40 }, LEAF),
		R("Leaf2", "Block", cornLeafG, { 0.40, 1.30, 0 }, { 0, 0, -40 }, LEAF_DARK),
		R("Leaf3", "Block", cornLeafG, { 0, 1.60, -0.40 }, { -40, 0, 0 }, LEAF),
		R("Leaf4", "Block", cornLeafG, { 0, 1.90, 0.40 }, { 40, 0, 0 }, LEAF_DARK),
		R("Bud1", "Ell", { 0.34, 0.70, 0.34 }, { 0.25, 1.30, -0.20 }, { 0, 0, -20 }, "#8DC63F"),
		R("Bud2", "Ell", { 0.34, 0.70, 0.34 }, { -0.25, 1.70, 0.18 }, { 0, 0, 20 }, "#8DC63F"),
	},
	ripe = {
		R("Stem1", "CylV", { 2.80, 0.28, 0.28 }, { 0, 1.70, 0 }, nil, STEM),
		R("Stem2", "Block", tassel, { 0, 3.02, 0 }, { 0, 0, 0 }, TAN),
		R("Stem3", "Block", tassel, { -0.12, 2.97, 0 }, { 0, 0, 25 }, TAN),
		R("Stem4", "Block", tassel, { 0.12, 2.97, 0 }, { 0, 0, -25 }, TAN),
		R("Leaf1", "Block", cornLeafR, { -0.45, 1.30, 0 }, { 0, 0, 40 }, LEAF),
		R("Leaf2", "Block", cornLeafR, { 0.45, 1.60, 0 }, { 0, 0, -40 }, LEAF_DARK),
		R("Leaf3", "Block", cornLeafR, { 0, 2.10, -0.45 }, { -40, 0, 0 }, LEAF),
		R("Leaf4", "Block", cornLeafR, { 0, 2.40, 0.45 }, { 40, 0, 0 }, LEAF_DARK),
		R("FruitDetail1", "Ell", { 0.42, 0.90, 0.42 }, { 0.30, 1.50, -0.25 }, { 0, 0, -20 }, "#8DC63F"),
		R("FruitDetail2", "Ell", { 0.42, 0.90, 0.42 }, { -0.30, 2.00, 0.20 }, { 0, 0, 20 }, "#8DC63F"),
		R("Fruit1", "Ell", { 0.32, 0.70, 0.32 }, { 0.30, 1.62, -0.33 }, { 0, 0, -20 }, "#F5D23C"),
		R("Fruit2", "Ell", { 0.32, 0.70, 0.32 }, { -0.30, 2.12, 0.12 }, { 0, 0, 20 }, "#F5D23C"),
	},
}

-- §3.6 (Marketing-signed: Growing Vine1 1.25 long, Ripe Vine1 1.05 long, Ripe Leaf2 0.90 across)
CropVisuals.crops.pumpkin = {
	fx = { 0, 0.95, 0 },
	growing = {
		R("Bud1", "Ell", { 0.66, 0.70, 1.00 }, { 0, 0.62, 0 }, nil, UNRIPE),
		R("Bud2", "Ell", { 0.50, 0.66, 0.92 }, { 0.30, 0.60, 0 }, nil, "#8DBA3E"),
		R("Bud3", "Ell", { 0.50, 0.66, 0.92 }, { -0.30, 0.60, 0 }, nil, "#8DBA3E"),
		R("Vine1", "Block", { 0.15, 0.12, 1.25 }, { 0.60, 0.36, 1.10 }, { 0, 30, 0 }, STEM),
		R("Leaf1", "Disc", { 0.08, 0.90, 0.90 }, { -1.00, 0.42, 0.85 }, { 10, 0, 0 }, LEAF_DARK),
		R("Leaf2", "Disc", { 0.08, 0.90, 0.90 }, { 1.05, 0.42, -0.85 }, { -10, 0, 0 }, LEAF_DARK),
		R("Flower1", "Disc", { 0.06, 0.40, 0.40 }, { 0.95, 0.50, 0.70 }, nil, BUTTER),
	},
	ripe = {
		R("Fruit1", "Ell", { 1.20, 1.35, 1.90 }, { 0, 0.95, 0 }, nil, "#F0821E"),
		R("Fruit2", "Ell", { 0.90, 1.25, 1.70 }, { -0.55, 0.92, 0 }, nil, "#E27318"),
		R("Fruit3", "Ell", { 0.90, 1.25, 1.70 }, { 0.55, 0.92, 0 }, nil, "#E27318"),
		R("Stem1", "CylV", { 0.45, 0.22, 0.22 }, { 0, 1.80, 0 }, { 0, 0, 8 }, "#6B8E23"),
		R("Stem2", "Block", { 0.12, 0.12, 0.45 }, { 0, 2.00, 0.18 }, { 30, 0, 0 }, "#6B8E23"),
		R("Vine1", "Block", { 0.15, 0.12, 1.05 }, { 0.60, 0.36, 1.20 }, { 0, 30, 0 }, STEM),
		R("Leaf1", "Disc", { 0.08, 1.00, 1.00 }, { -1.15, 0.42, 0.95 }, { 10, 0, 0 }, LEAF_DARK),
		R("Leaf2", "Disc", { 0.08, 0.90, 0.90 }, { 1.20, 0.42, -0.95 }, { -10, 0, 0 }, LEAF_DARK),
	},
}

-- §3.7 (stripes: in the melon's own frame, its rotation)
CropVisuals.crops.watermelon = {
	fx = { 0, 0.9, 0 },
	growing = {
		R("Bud1", "Ell", { 0.80, 0.75, 1.20 }, { 0, 0.66, 0 }, { 0, 20, 0 }, "#7CC46A"),
		R("Bud2", "Ell", { 0.14, 0.76, 1.21 }, { -0.22, 0, 0 }, nil, "#3E8E3E", { on = "Bud1" }),
		R("Bud3", "Ell", { 0.14, 0.76, 1.21 }, { 0.22, 0, 0 }, nil, "#3E8E3E", { on = "Bud1" }),
		R("Vine1", "Block", { 0.15, 0.12, 2.00 }, { 0.90, 0.36, 0.40 }, { 0, 15, 0 }, STEM),
		R("Leaf1", "Disc", { 0.08, 0.80, 0.80 }, { -1.05, 0.42, 0.80 }, { 10, 0, 0 }, LEAF_DARK),
		R("Leaf2", "Disc", { 0.08, 0.80, 0.80 }, { 1.05, 0.42, -0.90 }, { -10, 0, 0 }, LEAF_DARK),
		R("Flower1", "Disc", { 0.06, 0.36, 0.36 }, { 1.00, 0.48, 1.00 }, nil, BUTTER),
	},
	ripe = {
		R("Fruit1", "Ell", { 1.30, 1.20, 2.00 }, { -0.20, 0.88, -0.10 }, { 0, 20, 0 }, "#3CA046"),
		R("FruitDetail1", "Ell", { 0.18, 1.21, 2.01 }, { -0.38, 0, 0 }, nil, "#1F6B2A", { on = "Fruit1" }),
		R("FruitDetail2", "Ell", { 0.18, 1.21, 2.01 }, { 0, 0, 0 }, nil, "#1F6B2A", { on = "Fruit1" }),
		R("FruitDetail3", "Ell", { 0.18, 1.21, 2.01 }, { 0.38, 0, 0 }, nil, "#1F6B2A", { on = "Fruit1" }),
		R("Fruit2", "Ell", { 0.70, 0.65, 1.00 }, { 1.05, 0.62, 0.95 }, { 0, -30, 0 }, "#3CA046"),
		R("FruitDetail4", "Ell", { 0.12, 0.66, 1.01 }, { 0, 0, 0 }, nil, "#1F6B2A", { on = "Fruit2" }),
		R("Vine1", "Block", { 0.15, 0.12, 2.00 }, { 0.90, 0.36, 0.20 }, { 0, 15, 0 }, STEM),
		R("Leaf1", "Disc", { 0.08, 0.90, 0.90 }, { -1.05, 0.42, 0.95 }, { 10, 0, 0 }, LEAF_DARK),
		R("Leaf2", "Disc", { 0.08, 0.90, 0.90 }, { 1.10, 0.42, -0.95 }, { -10, 0, 0 }, LEAF),
		R("Leaf3", "Disc", { 0.08, 0.90, 0.90 }, { -1.00, 0.42, -1.00 }, { 10, 0, 0 }, LEAF_DARK),
	},
}

-- §3.8 (scales: in each fruit's own frame; Fruit2's are Fruit1's mirrored across x)
local scale = { 0.15, 0.35, 0.30 }
local dragonStems = {
	R("Stem1", "Block", { 0.40, 1.00, 0.40 }, { 0, 0.80, 0 }, { 0, 45, 0 }, "#3E8E3E"),
	R("Stem2", "Block", { 0.36, 0.80, 0.36 }, { 0.38, 1.45, 0 }, { 0, 45, -35 }, "#4FA34F"),
	R("Stem3", "Block", { 0.36, 0.80, 0.36 }, { -0.38, 1.65, 0 }, { 0, 45, 35 }, "#4FA34F"),
}
local dragonGrowing = table.clone(dragonStems)
table.insert(dragonGrowing, R("Bud1", "Ell", { 0.40, 0.60, 0.40 }, { 0.68, 1.95, 0 }, { 0, 0, -35 }, "#B5D96A"))
table.insert(dragonGrowing, R("Bud2", "Ell", { 0.40, 0.60, 0.40 }, { -0.68, 2.15, 0 }, { 0, 0, 35 }, "#B5D96A"))
table.insert(dragonGrowing, R("Flower1", "Disc", { 0.06, 0.50, 0.50 }, { 0, 1.40, -0.25 }, { -60, 0, 0 }, CREAM))
local dragonRipe = table.clone(dragonStems)
for _, row in {
	R("Fruit1", "Ell", { 0.80, 1.00, 0.80 }, { 0.75, 2.05, 0 }, { 0, 0, -20 }, "#EB46A0"),
	R("Fruit2", "Ell", { 0.80, 1.00, 0.80 }, { -0.75, 2.25, 0 }, { 0, 0, 20 }, "#EB46A0"),
	R("FruitDetail1", "Wedge", scale, { 0.40, 0, 0 }, { -20, 90, 0 }, "#7BC043", { on = "Fruit1" }),
	R("FruitDetail2", "Wedge", scale, { -0.40, 0.1, 0 }, { -20, -90, 0 }, "#7BC043", { on = "Fruit1" }),
	R("FruitDetail3", "Wedge", scale, { 0, 0.35, -0.40 }, { -20, 0, 0 }, "#7BC043", { on = "Fruit1" }),
	R("FruitDetail4", "Wedge", scale, { -0.40, 0, 0 }, { -20, -90, 0 }, "#7BC043", { on = "Fruit2" }),
	R("FruitDetail5", "Wedge", scale, { 0.40, 0.1, 0 }, { -20, 90, 0 }, "#7BC043", { on = "Fruit2" }),
	R("FruitDetail6", "Wedge", scale, { 0, 0.35, -0.40 }, { -20, 0, 0 }, "#7BC043", { on = "Fruit2" }),
} do
	table.insert(dragonRipe, row)
end
CropVisuals.crops.dragonfruit = { fx = { 0, 2.15, 0 }, growing = dragonGrowing, ripe = dragonRipe }

-- §3.9
local SAGE = "#6FAF8F"
CropVisuals.crops.moonmelon = {
	fx = { 0, 1.05, 0 },
	growing = {
		R("Bud1", "Ell", { 1.00, 0.90, 1.00 }, { 0, 0.75, 0 }, nil, "#D7DDF7"),
		R("Vine1", "Block", { 0.15, 0.12, 1.60 }, { 0.80, 0.36, 0.50 }, { 0, 20, 0 }, SAGE),
		R("Leaf1", "Disc", { 0.08, 0.85, 0.85 }, { -1.05, 0.42, 0.80 }, { 10, 0, 0 }, SAGE),
		R("Leaf2", "Disc", { 0.08, 0.85, 0.85 }, { 1.05, 0.42, -0.85 }, { -10, 0, 0 }, SAGE),
		R("Flower1", "Disc", { 0.06, 0.36, 0.36 }, { 0.95, 0.48, 1.05 }, nil, "#E6EBFF"),
	},
	ripe = {
		R("Fruit1", "Ell", { 1.80, 1.50, 1.80 }, { 0, 1.05, 0 }, nil, "#BEC8FF", {
			reflectance = 0.05,
			light = { name = "MoonGlow", hex = "#BEC8FF", brightness = 0.8, range = 6 },
		}),
		R("FruitDetail1", "Ell", { 0.20, 1.51, 1.81 }, { -0.45, 1.05, 0 }, nil, "#A9B6F5"),
		R("FruitDetail2", "Ell", { 0.20, 1.51, 1.81 }, { 0.45, 1.05, 0 }, nil, "#A9B6F5"),
		R("FruitDetail3", "Disc", { 0.04, 0.60, 0.60 }, { 0, 1.15, -0.88 }, { 90, 0, 0 }, "#F3F5FF"),
		R("FruitDetail4", "Disc", { 0.05, 0.50, 0.50 }, { 0.14, 1.20, -0.89 }, { 90, 0, 0 }, "#BEC8FF"),
		R("Vine1", "Block", { 0.15, 0.12, 1.60 }, { 0.90, 0.36, 0.60 }, { 0, 20, 0 }, SAGE),
		R("Leaf1", "Disc", { 0.08, 0.95, 0.95 }, { -1.15, 0.42, 0.95 }, { 10, 0, 0 }, SAGE),
		R("Leaf2", "Disc", { 0.08, 0.95, 0.95 }, { 1.15, 0.42, -0.95 }, { -10, 0, 0 }, SAGE),
	},
}
-- stylua: ignore end

-- the part budgets of GA-01 §4 (Root included), checked by tests/Crops.spec.luau
CropVisuals.budget = {
	carrot = { seed = 5, sprout = 6, growing = 6, ripe = 8 },
	strawberry = { seed = 5, sprout = 7, growing = 7, ripe = 12 },
	blueberry = { seed = 5, sprout = 7, growing = 8, ripe = 10 },
	tomato = { seed = 5, sprout = 7, growing = 12, ripe = 13 },
	corn = { seed = 5, sprout = 5, growing = 8, ripe = 13 },
	pumpkin = { seed = 5, sprout = 6, growing = 8, ripe = 9 },
	watermelon = { seed = 5, sprout = 6, growing = 8, ripe = 11 },
	dragonfruit = { seed = 5, sprout = 6, growing = 7, ripe = 12 },
	moonmelon = { seed = 5, sprout = 6, growing = 6, ripe = 9 },
}

return CropVisuals
