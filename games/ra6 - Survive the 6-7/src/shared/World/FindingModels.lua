--[[
How the forest's findings look (master plan §11: cabins and landmarks identifiable from a distance). Each builder
makes one finding round a clearing's centre and says where its containers, nodes and special spots go;
WorldService fills them in for each run.

  FindingModels.build(key, cf, rng, parent) -> model, spots
    spots = { loot = { { kind, cf } }, nodes = { { kind, pos } }, page = cf, special = { [name] = cf }, guard = pos }
]]
local Kit = require(script.Parent.Kit)

local FindingModels = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new

local function at(cf, x, y, z)
	return cf * CFrame.new(x, y, z)
end

local function spots()
	return { loot = {}, nodes = {}, special = {} }
end

local function wallBox(m, cf, size, color, material)
	return Kit.box(m, "Wall", cf, size, color or C.wood, material or M.Wood)
end

-- A gable roof over a w x d box whose walls are h tall.
local function gableRoof(m, cf, w, d, h, rise, color, material)
	for _, side in { -1, 1 } do
		Kit.wedge(
			m,
			"Roof",
			at(cf, side * w / 4, h + rise / 2, 0) * CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0),
			V3(d + 1.6, rise, w / 2 + 0.8),
			color or C.woodDark,
			material or M.WoodPlanks
		)
	end
end

local builders = {}

-- An abandoned log cabin: four walls with a door and a window, a gable roof, a chimney; a locker and a crate inside.
function builders.cabin(m, cf, rng)
	local s = spots()
	local w, d, h = 14, 10, 8
	local col = C.bark:Lerp(C.wood, 0.35)
	Kit.box(m, "Floor", at(cf, 0, 0.25, 0), V3(w, 0.5, d), C.plank, M.WoodPlanks)
	wallBox(m, at(cf, 0, h / 2, d / 2), V3(w, h, 1), col)
	wallBox(m, at(cf, -w / 2, h / 2, 0), V3(1, h, d), col)
	wallBox(m, at(cf, w / 2, h / 2, 0), V3(1, h, d), col)
	-- the front: a door gap in the middle and a window on the right
	wallBox(m, at(cf, -4.5, h / 2, -d / 2), V3(5, h, 1), col)
	wallBox(m, at(cf, 4.5, 1.5, -d / 2), V3(5, 3, 1), col)
	wallBox(m, at(cf, 4.5, h - 1.25, -d / 2), V3(5, 2.5, 1), col)
	wallBox(m, at(cf, 6.5, 4.25, -d / 2), V3(1, 2.5, 1), col)
	wallBox(m, at(cf, 2.5, 4.25, -d / 2), V3(1, 2.5, 1), col)
	wallBox(m, at(cf, 0, h - 1, -d / 2), V3(4, 2, 1), col)
	Kit.box(m, "Window", at(cf, 4.5, 4.25, -d / 2), V3(3, 2.5, 0.2), C.moon, M.Glass, { Transparency = 0.5 })
	gableRoof(m, cf, w, d, h, 4.5, C.barkDark, M.WoodPlanks)
	Kit.box(m, "Gable", at(cf, 0, h + 1.5, -d / 2), V3(w - 4, 3, 0.8), col, M.Wood)
	Kit.box(m, "Gable2", at(cf, 0, h + 1.5, d / 2), V3(w - 4, 3, 0.8), col, M.Wood)
	Kit.box(m, "Chimney", at(cf, -w / 2 + 2, h + 3.5, d / 4), V3(2, 7, 2), C.stone, M.Cobblestone)
	-- a porch light and a woodpile
	Kit.lantern(m, at(cf, -2.6, 0, -d / 2 - 1.2).Position, (cf.LookVector * -1), 7)
	Kit.logs(m, at(cf, w / 2 + 2.5, 0, 1) * CFrame.Angles(0, math.rad(90), 0), 6, 2)
	-- a cot inside
	Kit.box(m, "Cot", at(cf, -3.5, 1.1, 2.8), V3(5, 0.8, 2.4), C.canvasRed, M.Fabric)
	table.insert(s.loot, { "locker", at(cf, 5, 0.5, 3.2) * CFrame.Angles(0, math.pi, 0) })
	table.insert(s.loot, { "crate", at(cf, -4.5, 0.5, -2) })
	table.insert(s.loot, { "crate", at(cf, w / 2 + 3, 0, -4) })
	s.page = at(cf, 0, 1.2, 3)
	_ = rng
	return s
end

-- The old ranger tower: four tall legs, a lookout cabin on top, a ladder; the chest and the map are up there.
function builders.ranger_tower(m, cf, rng)
	local s = spots()
	local h = 24
	for _, x in { -4, 4 } do
		for _, z in { -4, 4 } do
			Kit.box(m, "Leg", at(cf, x, h / 2, z), V3(1, h, 1), C.woodDark, M.Wood)
		end
	end
	for y = 6, h - 4, 8 do
		for _, z in { -4, 4 } do
			Kit.box(m, "Brace", at(cf, 0, y, z) * CFrame.Angles(0, 0, math.rad(40)), V3(11, 0.5, 0.5), C.wood, M.Wood, {
				CastShadow = false,
			})
		end
	end
	Kit.box(m, "Deck", at(cf, 0, h, 0), V3(11, 0.6, 11), C.plank, M.WoodPlanks)
	for _, z in { -5.3, 5.3 } do
		Kit.box(m, "Rail", at(cf, 0, h + 1.6, z), V3(11, 0.4, 0.3), C.wood, M.Wood, { CastShadow = false })
	end
	Kit.box(m, "RailSide", at(cf, -5.3, h + 1.6, 0), V3(0.3, 0.4, 11), C.wood, M.Wood, { CastShadow = false })
	for _, x in { -3.8, 3.8 } do
		for _, z in { -3.8, 3.8 } do
			Kit.box(m, "RoofPost", at(cf, x, h + 3, z), V3(0.4, 5.4, 0.4), C.woodDark, M.Wood, { CastShadow = false })
		end
	end
	gableRoof(m, at(cf, 0, h + 5.6, 0), 9, 9, 0, 3, C.canvasRed, M.WoodPlanks)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Anchored = true
	ladder.Size = V3(2, h, 2)
	ladder.CFrame = at(cf, 0, h / 2, -5.6)
	ladder.Color = C.woodLight
	ladder.Material = M.Wood
	ladder.Parent = m
	local flag = Kit.box(m, "Flag", at(cf, 4.6, h + 10, 4.6), V3(0.2, 2, 3), C.yellow, M.Fabric, { CanCollide = false })
	Kit.box(m, "FlagPole", at(cf, 4.6, h + 8, 3.1), V3(0.3, 7, 0.3), C.woodDark, M.Wood, { CanCollide = false })
	_ = flag
	table.insert(s.loot, { "chest", at(cf, 2, h + 0.3, 2) })
	s.special.map = at(cf, -2, h + 1.5, 2)
	s.page = at(cf, -3, 0.6, 3)
	_ = rng
	return s
end

-- A crashed ice cream truck: nose in a tree, back doors open, a giant cone on the roof.
function builders.ice_cream_truck(m, cf, rng)
	local s = spots()
	local tcf = cf * CFrame.Angles(0, 0, math.rad(6)) * CFrame.Angles(math.rad(-4), 0, 0)
	Kit.box(m, "Body", at(tcf, 0, 4, 1.5), V3(7, 6, 11), C.white, M.SmoothPlastic)
	Kit.box(m, "Stripe", at(tcf, 0, 3.2, 1.5), V3(7.1, 1, 11.1), C.flowerPink, M.SmoothPlastic, { CastShadow = false })
	Kit.box(m, "Cab", at(tcf, 0, 3.2, -6.5), V3(7, 4.4, 5), C.white, M.SmoothPlastic)
	Kit.box(m, "Windshield", at(tcf, 0, 4.4, -9.05), V3(6, 2, 0.2), C.moon, M.Glass, { Transparency = 0.4 })
	Kit.box(m, "Bumper", at(tcf, 0, 1.4, -9.2), V3(7.2, 0.8, 0.6), C.steel, M.Metal)
	for _, x in { -3.6, 3.6 } do
		for _, z in { -6, 4 } do
			Kit.cyl(m, "Wheel", at(tcf, x, 1.3, z), 1, 2.6, C.black, M.Rubber, { CastShadow = false })
		end
	end
	-- the cone on the roof
	Kit.cyl(m, "Cone", at(tcf, 0, 8.4, 1.5) * CFrame.Angles(0, 0, math.rad(90)), 3, 1.8, C.woodLight, M.SmoothPlastic)
	Kit.ball(m, "Scoop", at(tcf, 0, 10.4, 1.5).Position, 2.6, C.flowerPink, M.SmoothPlastic)
	Kit.ball(m, "Cherry", at(tcf, 0, 11.9, 1.5).Position, 0.8, C.red, M.SmoothPlastic, { CanCollide = false })
	-- the open back doors
	for _, side in { -1, 1 } do
		Kit.box(
			m,
			"Door",
			at(tcf, side * 3.4, 4, 7.2) * CFrame.Angles(0, side * math.rad(80), 0) * CFrame.new(-side * 1.7, 0, 0),
			V3(3.4, 5.4, 0.3),
			C.white,
			M.SmoothPlastic,
			{ CanCollide = false }
		)
	end
	table.insert(s.loot, { "cooler", at(cf, 0, 0, 10) })
	for _ = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		table.insert(s.nodes, { "scrap", (cf * CFrame.new(math.cos(a) * 10, 0, math.sin(a) * 10)).Position })
	end
	s.page = at(cf, 4, 0.5, 9)
	return s
end

-- A bear cave: a mound of big rocks with a dark mouth; a chest at the back.
function builders.bear_cave(m, cf, rng)
	local s = spots()
	local rock = C.rock:Lerp(C.rockMoss, 0.25)
	-- the back and sides: overlapping boulders
	for k = 0, 8 do
		local a = math.rad(-120 + k * 30)
		local p = at(cf, math.sin(a) * 10, 0, math.cos(a) * 10 + 4)
		Kit.boulder(m, p.Position - V3(0, 1, 0), rng:NextNumber(9, 13), rng, rock, M.Rock)
	end
	-- the roof slab over the mouth
	Kit.box(m, "Roof", at(cf, 0, 9, 4) * CFrame.Angles(math.rad(8), 0, 0), V3(16, 3, 14), rock, M.Rock)
	Kit.box(
		m,
		"Dark",
		at(cf, 0, 4, 6),
		V3(10, 8, 8),
		C.black,
		M.SmoothPlastic,
		{ CanCollide = false, Transparency = 0.15 }
	)
	Kit.box(m, "Floor", at(cf, 0, 0.1, 4), V3(11, 0.2, 12), C.dirt, M.Ground, { CanCollide = false })
	-- bones by the mouth
	for k = 1, 4 do
		Kit.box(
			m,
			"Bone",
			at(cf, rng:NextNumber(-5, 5), 0.25, rng:NextNumber(-6, -2)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			V3(1.6, 0.35, 0.35),
			C.cream,
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
		_ = k
	end
	table.insert(s.loot, { "chest", at(cf, 0, 0.2, 7.5) * CFrame.Angles(0, math.pi, 0) })
	s.guard = at(cf, 0, 0, -10).Position
	s.page = at(cf, 3, 0.5, 6)
	return s
end

-- A witch's crooked hut with a bubbling cauldron out front.
function builders.witch_hut(m, cf, rng)
	local s = spots()
	local hcf = cf * CFrame.Angles(0, 0, math.rad(5))
	local col = C.woodDark:Lerp(C.purple, 0.15)
	for _, x in { -3.5, 3.5 } do
		for _, z in { -3.5, 3.5 } do
			Kit.box(m, "Stilt", at(cf, x, 1.5, z), V3(0.6, 3, 0.6), C.barkDark, M.Wood)
		end
	end
	Kit.box(m, "Floor", at(hcf, 0, 3.2, 0), V3(9, 0.5, 9), C.plank, M.WoodPlanks)
	wallBox(m, at(hcf, 0, 6, 4.2), V3(8.4, 5.6, 0.6), col)
	wallBox(m, at(hcf, -4.2, 6, 0), V3(0.6, 5.6, 8.4), col)
	wallBox(m, at(hcf, 4.2, 6, 0), V3(0.6, 5.6, 8.4), col)
	wallBox(m, at(hcf, -2.8, 6, -4.2), V3(2.8, 5.6, 0.6), col)
	wallBox(m, at(hcf, 2.8, 6, -4.2), V3(2.8, 5.6, 0.6), col)
	Kit.roofCone(m, "Roof", at(hcf, 0, 8.8, 0).Position, 6.4, 8, C.purple, M.Fabric, 8)
	Kit.box(
		m,
		"Steps",
		at(cf, 0, 1.2, -6.2) * CFrame.Angles(math.rad(-30), 0, 0),
		V3(2.4, 0.4, 5),
		C.wood,
		M.WoodPlanks
	)
	-- jars on a shelf by the door
	for k = 1, 3 do
		Kit.ball(
			m,
			"Jar",
			at(cf, -3 + k * 1.2, 3.9, -5).Position,
			0.7,
			({ C.green, C.purple, C.glowcap })[k],
			M.Glass,
			{
				CanCollide = false,
				CastShadow = false,
			}
		)
	end
	Kit.box(
		m,
		"Broom",
		at(cf, 4.8, 2.4, -4.8) * CFrame.Angles(0, 0, math.rad(15)),
		V3(0.25, 4.8, 0.25),
		C.wood,
		M.Wood,
		{
			CanCollide = false,
		}
	)
	table.insert(s.loot, { "cauldron", at(cf, 0, 0, -10) })
	s.page = at(hcf, 0, 4, 2)
	_ = rng
	return s
end

-- A ring of standing stones round an altar (offer a Strange Idol for a blessing).
function builders.stone_circle(m, cf, rng)
	local s = spots()
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		local h = rng:NextNumber(7, 10)
		local p = at(cf, math.cos(a) * 12, h / 2 - 0.5, math.sin(a) * 12)
		Kit.box(
			m,
			"Stone",
			p * CFrame.Angles(rng:NextNumber(-0.08, 0.08), a, rng:NextNumber(-0.08, 0.08)),
			V3(2.6, h, 1.6),
			C.stone:Lerp(C.rockMoss, 0.3),
			M.Rock
		)
		Kit.box(m, "Rune", p * CFrame.Angles(0, a, 0) * CFrame.new(0, 1, -0.82), V3(1, 1.4, 0.1), C.glowcap, M.Neon, {
			CanCollide = false,
			CastShadow = false,
			Transparency = 0.4,
		})
	end
	Kit.box(m, "Altar", at(cf, 0, 1.2, 0), V3(5, 2.4, 3), C.stoneDark, M.Slate)
	Kit.box(m, "AltarTop", at(cf, 0, 2.55, 0), V3(5.6, 0.3, 3.6), C.stone, M.Slate)
	s.special.altar = at(cf, 0, 3, 0)
	s.page = at(cf, 6, 0.4, 3)
	return s
end

-- A lost campsite: a torn tent, a cold campfire, a backpack left behind.
function builders.lost_camp(m, cf, rng)
	local s = spots()
	for _, side in { -1, 1 } do
		Kit.wedge(
			m,
			"Canvas",
			at(cf, side * 1.6, 1.8, 4) * CFrame.Angles(0, side > 0 and 0 or math.pi, math.rad(side * 6)),
			V3(5, 3.6, 3.2),
			C.canvas:Lerp(C.dirt, 0.3),
			M.Fabric
		)
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		Kit.ellipsoid(
			m,
			"Stone",
			at(cf, math.cos(a) * 2, 0.35, math.sin(a) * 2 - 2).Position,
			V3(1, 0.7, 0.9),
			C.stone,
			M.Rock,
			{
				CastShadow = false,
			}
		)
	end
	Kit.cyl(
		m,
		"Charcoal",
		at(cf, 0, 0.4, -2) * CFrame.Angles(0, 0.7, 0),
		2.6,
		0.5,
		C.black,
		M.Wood,
		{ CanCollide = false }
	)
	Kit.box(m, "SleepingBag", at(cf, 4, 0.3, -1) * CFrame.Angles(0, 0.4, 0), V3(2, 0.5, 5), C.blue, M.Fabric, {
		CanCollide = false,
	})
	table.insert(s.loot, { "backpack", at(cf, -3, 0, -3) })
	table.insert(s.loot, { "crate", at(cf, 5, 0, 4) })
	s.page = at(cf, 1, 0.5, 2)
	_ = rng
	return s
end

-- A ring of giant glowing mushrooms; glowcaps grow inside.
function builders.mushroom_ring(m, cf, rng)
	local s = spots()
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local p = at(cf, math.cos(a) * 11, 0, math.sin(a) * 11).Position
		local mush = Kit.mushroom(m, p, rng:NextNumber(6, 10), k % 2 == 0 and C.glowcap or C.glowPurple, rng)
		local cap = mush:FindFirstChild("Cap")
		if cap then
			cap.Material = M.Neon
			Kit.light(cap, "PointLight", { Color = cap.Color, Range = 14, Brightness = 1 })
		end
	end
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + 0.4
		table.insert(s.nodes, { "glowcap", at(cf, math.cos(a) * 5, 0, math.sin(a) * 5).Position })
	end
	s.guard = cf.Position
	s.page = at(cf, 0, 0.4, 0)
	return s
end

-- A giant hollow log you can walk through (a chest inside).
function builders.hollow_log(m, cf, rng)
	local s = spots()
	local len, r = 26, 5
	local col = C.bark:Lerp(C.barkDark, 0.3)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		do
			local off = V3(math.cos(a) * r, math.sin(a) * r + r, 0)
			local seg = Kit.box(
				m,
				"Bark",
				at(cf, off.X, off.Y, 0) * CFrame.Angles(0, 0, a + math.pi / 2),
				V3(2 * math.pi * r / 10 + 0.6, 1.2, len),
				col,
				M.Wood
			)
			if k == 7 then
				seg.Name = "Floor"
				seg.Color = C.dirt
				seg.Material = M.Ground
			end
		end
	end
	Kit.box(m, "Moss", at(cf, 0, 2 * r + 0.5, 0), V3(5, 0.5, len * 0.7), C.moss, M.Grass, { CanCollide = false })
	Kit.mushrooms(m, at(cf, 2, 2 * r + 0.6, 6).Position, rng)
	table.insert(s.loot, { "chest", at(cf, 0, 0.8, 0) * CFrame.Angles(0, math.rad(90), 0) })
	s.page = at(cf, 0, 1.2, -9)
	return s
end

-- A hunter's blind: a hide on stilts with a ladder; a weapon rack up top.
function builders.hunter_blind(m, cf, rng)
	local s = spots()
	local h = 8
	for _, x in { -2.8, 2.8 } do
		for _, z in { -2.8, 2.8 } do
			Kit.box(m, "Leg", at(cf, x, h / 2, z), V3(0.7, h, 0.7), C.woodDark, M.Wood)
		end
	end
	Kit.box(m, "Deck", at(cf, 0, h, 0), V3(7, 0.5, 7), C.plank, M.WoodPlanks)
	wallBox(m, at(cf, 0, h + 1.6, 3.3), V3(7, 3.2, 0.4), C.canvasGreen, M.Fabric)
	wallBox(m, at(cf, -3.3, h + 1.6, 0), V3(0.4, 3.2, 7), C.canvasGreen, M.Fabric)
	wallBox(m, at(cf, 3.3, h + 1.6, 0), V3(0.4, 3.2, 7), C.canvasGreen, M.Fabric)
	Kit.box(
		m,
		"Roof",
		at(cf, 0, h + 3.6, 0.5) * CFrame.Angles(math.rad(-10), 0, 0),
		V3(7.6, 0.4, 8),
		C.canvasGreen,
		M.Fabric
	)
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Anchored = true
	ladder.Size = V3(2, h, 2)
	ladder.CFrame = at(cf, 0, h / 2, -4.2)
	ladder.Color = C.woodLight
	ladder.Material = M.Wood
	ladder.Parent = m
	table.insert(s.loot, { "rack", at(cf, 0, h + 0.25, 2.2) * CFrame.Angles(0, math.pi, 0) })
	s.page = at(cf, 2, 0.5, -3)
	_ = rng
	return s
end

-- An old rusty car with mossy seats; scrap all round.
function builders.rusty_car(m, cf, rng)
	local s = spots()
	local rust = Color3.fromRGB(150, 92, 66)
	local ccf = cf * CFrame.Angles(0, 0, math.rad(-4))
	Kit.box(m, "Body", at(ccf, 0, 2.2, 0), V3(5.6, 2.2, 11), rust, M.CorrodedMetal)
	Kit.box(m, "Cabin", at(ccf, 0, 4, 0.6), V3(5.2, 1.8, 5.6), rust:Lerp(C.iron, 0.3), M.CorrodedMetal)
	Kit.box(
		m,
		"Moss",
		at(ccf, 0, 5, 0.6),
		V3(4.4, 0.3, 4.4),
		C.moss,
		M.Grass,
		{ CanCollide = false, CastShadow = false }
	)
	for _, x in { -2.9, 2.9 } do
		for _, z in { -3.6, 3.6 } do
			Kit.cyl(m, "Wheel", at(ccf, x, 1, z), 0.9, 2, C.black, M.Rubber, { CastShadow = false })
		end
	end
	Kit.box(
		m,
		"Hood",
		at(ccf, 0, 3.6, -4.6) * CFrame.Angles(math.rad(-35), 0, 0),
		V3(5.4, 0.2, 3),
		rust,
		M.CorrodedMetal,
		{
			CanCollide = false,
		}
	)
	for k = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		table.insert(s.nodes, { "scrap", (cf * CFrame.new(math.cos(a) * 8, 0, math.sin(a) * 8)).Position })
		_ = k
	end
	table.insert(s.loot, { "crate", at(cf, 5, 0, 6) })
	s.page = at(ccf, 0, 3.4, 2)
	return s
end

-- A big old tree with a huge beehive (honey! and bees).
function builders.beehive_tree(m, cf, rng)
	local s = spots()
	local t =
		{ x = cf.Position.X, y = cf.Position.Y, z = cf.Position.Z, h = 26, trunk = 1.8, seed = rng:NextInteger(1, 1e6) }
	Kit.oak(m, t)
	local hive = Kit.ellipsoid(
		m,
		"Hive",
		at(cf, 2.6, 11, 0).Position,
		V3(3, 4.2, 3),
		C.yellow:Lerp(C.goldDark, 0.3),
		M.SmoothPlastic
	)
	for k = 1, 3 do
		Kit.disc(
			m,
			"Ring",
			hive.Position + V3(0, -1.4 + k * 0.7, 0),
			3.1 - math.abs(k - 2) * 0.4,
			0.2,
			C.goldDark,
			M.SmoothPlastic,
			{
				CanCollide = false,
				CastShadow = false,
			}
		)
	end
	s.special.hive = at(cf, 2.6, 2, -2)
	s.page = at(cf, -4, 0.5, 3)
	return s
end

-- Kermy's lair: a throne of logs, his old jersey on a stick, the hoard. He naps here by day.
function builders.kermy_lair(m, cf, rng)
	local s = spots()
	-- the throne
	Kit.box(m, "Seat", at(cf, 0, 2, 6), V3(7, 1.2, 5), C.bark, M.Wood)
	for _, x in { -3.2, 3.2 } do
		Kit.cyl(m, "Arm", at(cf, x, 3.2, 6) * CFrame.Angles(0, math.rad(90), 0), 5, 1.4, C.bark, M.Wood)
		for _, z in { 4, 8 } do
			Kit.disc(m, "Leg", at(cf, x, 1, z).Position, 1.2, 2, C.barkDark, M.Wood)
		end
	end
	for k = -2, 2 do
		Kit.disc(
			m,
			"Back",
			at(cf, k * 1.5, 5.5, 8.4).Position,
			1.4,
			7 + (2 - math.abs(k)) * 1.2,
			C.bark:Lerp(C.barkDark, (k + 2) * 0.1),
			M.Wood
		)
	end
	-- the jersey on a stick
	Kit.box(m, "Stick", at(cf, -7, 3.5, 4), V3(0.4, 7, 0.4), C.woodDark, M.Wood)
	local jersey = Kit.box(m, "Jersey", at(cf, -7, 5.4, 4), V3(3.2, 3.4, 0.3), C.jersey, M.Fabric)
	Kit.text(jersey, Enum.NormalId.Front, "67", { font = Enum.Font.LuckiestGuy, color = C.jerseyTrim, ppu = 40 })
	Kit.text(jersey, Enum.NormalId.Back, "67", { font = Enum.Font.LuckiestGuy, color = C.jerseyTrim, ppu = 40 })
	-- a ring of bones and sandwich crusts
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		Kit.box(
			m,
			k % 2 == 0 and "Bone" or "Crust",
			at(cf, math.cos(a) * 12, 0.25, math.sin(a) * 12) * CFrame.Angles(0, a, 0),
			k % 2 == 0 and V3(1.6, 0.35, 0.35) or V3(1, 0.3, 0.6),
			k % 2 == 0 and C.cream or C.woodLight,
			M.SmoothPlastic,
			{ CanCollide = false, CastShadow = false }
		)
	end
	table.insert(s.loot, { "hoard", at(cf, 5.5, 0, 0) })
	s.special.throne = at(cf, 0, 2.6, 6) * CFrame.Angles(0, math.pi, 0)
	s.page = at(cf, -6, 0.5, -3)
	_ = rng
	return s
end

function FindingModels.build(key, cf, rng, parent)
	local m = Kit.model(key, nil)
	local fn = builders[key]
	assert(fn, "no finding model for " .. tostring(key))
	local s = fn(m, cf, rng or Random.new(1))
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	m.Parent = parent
	return m, s
end

FindingModels.has = function(key)
	return builders[key] ~= nil
end

return FindingModels
