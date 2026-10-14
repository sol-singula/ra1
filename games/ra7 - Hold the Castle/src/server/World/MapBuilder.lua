--[[
Builds the first map (master plan §6) from the coordinates in Shared/World/MapLayout. The land is Roblox smooth
terrain (TerrainBuilder): the green valley and its creek, the stone hill under Shrine 1 (cliffs all round, four
ramps up), the ridges, the sandstone canyon of Shrine 2, the mountain with its tunnels and the cave of Shrine 3,
the dark forest where the monsters spawn. On it, from parts: the bridges, the camp, the shrines, the mines, the
walls of magic, the job boards, the hangout on the north ridge, and the trees, rocks, flowers, ruins and lights.

Bright and full of colour (§14), with Roblox's textured materials (cobblestone, wood planks, slate, fabric...).
Kept to a few thousand parts for phones: decor never collides or casts shadows unless it's big.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Jobs = require(ReplicatedStorage.Shared.Data.Jobs)
local Groups = require(script.Parent.Groups)
local TerrainBuilder = require(script.Parent.TerrainBuilder)

local MapBuilder = {
	shrines = {}, -- [i] = { model, crystal, core, ring = { parts }, bar, label }
	barriers = {}, -- [i] = model (MonsterWall)
	jobBoards = {}, -- [i] = part with the ProximityPrompt
	hangout = {}, -- { podium = { parts }, board = part, shop = part }
	folder = nil,
}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new
local HILL = MapLayout.HILL

local function decor(extra)
	local t = { CanCollide = false, CastShadow = false }
	for k, v in extra or {} do
		t[k] = v
	end
	return t
end

-- A point on the walkable ground (the valley's rolls, the hill, the canyon and cave floors).
local function at(x, z)
	return V3(x, MapLayout.groundY(x, z), z)
end
-- A point on the land anywhere (ridge tops, canyon rims, mountain sides).
local function onLand(x, z)
	return V3(x, TerrainBuilder.surfaceY(x, z), z)
end

-- The stone hill under Shrine 1 (the land is terrain): stone curbs and torches on the ramps, banners at their tops,
-- boulders at the foot of the cliffs, and an invisible ring at the cliff edge so the only ways up are the ramps.
local function hill(f, rng)
	local cx, cz = HILL.center.X, HILL.center.Y
	local m = Kit.model("Hill", f)
	-- boulders tumbled at the foot of the cliffs (not on the ramps)
	local n = 44
	for k = 1, n do
		local a = (k + rng:NextNumber(-0.35, 0.35)) / n * math.pi * 2
		local dir = Vector2.new(math.cos(a), math.sin(a))
		local onRamp = false
		for _, ramp in HILL.ramps do
			if dir:Dot(ramp.dir) > math.cos(math.rad(13)) then
				onRamp = true
			end
		end
		if not onRamp then
			local r = HILL.top + rng:NextNumber(3.5, 7)
			Kit.boulder(
				m,
				at(cx + dir.X * r, cz + dir.Y * r) - V3(0, 0.6, 0),
				rng:NextNumber(2.5, 6.5),
				rng,
				(rng:NextNumber() < 0.5 and C.rock or C.cliffDark),
				rng:NextNumber() < 0.6 and M.Slate or M.Rock
			)
		end
	end
	-- the invisible ring at the edge (monsters can't jump the cliffs; the ramps are the way up)
	local ringR = HILL.top + 1.4
	local segs = 96
	for k = 0, segs - 1 do
		local a = (k + 0.5) / segs * math.pi * 2
		local dir = Vector2.new(math.cos(a), math.sin(a))
		local onRamp = false
		for _, ramp in HILL.ramps do
			if dir:Dot(ramp.dir) > math.cos(math.asin((HILL.rampWidth / 2 + 0.6) / ringR)) then
				onRamp = true
			end
		end
		if not onRamp then
			local pos = V3(cx + dir.X * ringR, (HILL.height - 1) / 2, cz + dir.Y * ringR)
			local wall = Kit.wall(
				m,
				CFrame.lookAt(pos, V3(cx, pos.Y, cz)),
				V3(2 * math.pi * ringR / segs + 0.6, HILL.height + 1, 1)
			)
			wall.Name = "CliffEdge"
		end
	end
	-- the four ramps: cobbled terrain, with stone curbs, torches at the top and banners
	local slope = math.atan2(HILL.height, HILL.foot - HILL.top)
	for _, ramp in HILL.ramps do
		local mid = (HILL.top + HILL.foot) / 2
		local pos = V3(cx + ramp.dir.X * mid, HILL.height / 2, cz + ramp.dir.Y * mid)
		local cf = CFrame.lookAt(pos, pos + V3(ramp.dir.X, 0, ramp.dir.Y))
		for _, side in { -1, 1 } do
			Kit.box(
				m,
				"Curb",
				cf
					* CFrame.new(side * (HILL.rampWidth / 2 + 0.6), 0, 0)
					* CFrame.Angles(-slope, 0, 0)
					* CFrame.new(0, 0.7, 0),
				V3(1.6, 1.8, HILL.foot - HILL.top + 1),
				C.castleDark,
				M.Cobblestone,
				{ CastShadow = false }
			)
		end
		for _, side in { -1, 1 } do
			local t = Vector2.new(-ramp.dir.Y, ramp.dir.X) * side * (HILL.rampWidth / 2 + 2)
			local top = HILL.center + ramp.dir * (HILL.top - 3) + t
			Kit.torch(m, V3(top.X, HILL.height, top.Y), 6)
			local foot = HILL.center + ramp.dir * (HILL.foot + 3) + t * 1.15
			Kit.torch(m, at(foot.X, foot.Y), 5.5)
			local b = HILL.center + ramp.dir * (HILL.top + 6) + t * 1.25
			local bp = V3(b.X, MapLayout.groundY(b.X, b.Y), b.Y)
			Kit.banner(
				m,
				CFrame.lookAt(bp, bp + V3(ramp.dir.X, 0, ramp.dir.Y)) * CFrame.Angles(0, math.pi, 0),
				11,
				side > 0 and C.roofBlue or C.roofRed,
				C.gold
			)
		end
	end
	-- flowers round the edge of the top (not where the castle goes)
	for _ = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(82, 96)
		Kit.flowers(m, V3(cx + math.cos(a) * r, HILL.height, cz + math.sin(a) * r), rng, 4)
	end
	return m
end

-- The creek across the valley (its channel and water are terrain): the bridges, stepping stones, reeds and lilies.
local function creek(f, rng)
	local m = Kit.model("Creek", f)
	local x, w = MapLayout.CREEK.x, MapLayout.CREEK.width
	local water = MapLayout.CREEK.water
	local stone, rope
	for _, b in MapLayout.bridges do
		if b.key == "stone" then
			stone = b
		else
			rope = b
		end
	end
	-- the stone bridge (middle lane): wide and open, with a ramp at each end and a pier in the water
	local deckLen = (stone.halfX - stone.ramp) * 2
	Kit.box(
		m,
		"StoneBridge",
		CFrame.new(x, stone.y / 2, stone.z),
		V3(deckLen, stone.y, stone.halfZ * 2),
		C.castle,
		M.Cobblestone
	)
	for _, s in { -1, 1 } do
		Kit.wedge(
			m,
			"BridgeRamp",
			CFrame.new(x + s * (deckLen / 2 + stone.ramp / 2), stone.y / 2, stone.z)
				* CFrame.Angles(0, s > 0 and math.rad(-90) or math.rad(90), 0),
			V3(stone.halfZ * 2, stone.y, stone.ramp),
			C.castle,
			M.Cobblestone
		)
		Kit.box(
			m,
			"Parapet",
			CFrame.new(x, stone.y + 0.8, stone.z + s * (stone.halfZ - 0.5)),
			V3(deckLen, 1.6, 1),
			C.castleDark,
			M.Cobblestone
		)
		Kit.box(
			m,
			"ParapetCap",
			CFrame.new(x, stone.y + 1.75, stone.z + s * (stone.halfZ - 0.5)),
			V3(deckLen + 0.4, 0.3, 1.3),
			C.stoneDark,
			M.Slate,
			{ CastShadow = false }
		)
		for _, e in { -1, 1 } do
			Kit.box(
				m,
				"ParapetPost",
				CFrame.new(x + e * (deckLen / 2 - 0.6), stone.y + 1.2, stone.z + s * (stone.halfZ - 0.5)),
				V3(1.6, 2.6, 1.6),
				C.castleDark,
				M.Cobblestone
			)
		end
	end
	Kit.box(m, "Pier", CFrame.new(x, -2, stone.z), V3(3, 4.4, stone.halfZ * 2 - 2), C.castleDark, M.Cobblestone)
	-- the thin rope bridge (north lane): easy to guard
	local bz = rope.z
	local span = (rope.halfX - rope.ramp) * 2
	Kit.box(m, "Deck", CFrame.new(x, rope.y - 0.3, bz), V3(span, 0.6, rope.halfZ * 2), C.woodLight, M.WoodPlanks)
	for _, s in { -1, 1 } do
		Kit.wedge(
			m,
			"BridgeRamp",
			CFrame.new(x + s * (span / 2 + rope.ramp / 2), rope.y / 2, bz)
				* CFrame.Angles(0, s > 0 and math.rad(-90) or math.rad(90), 0),
			V3(rope.halfZ * 2, rope.y, rope.ramp),
			C.woodLight,
			M.WoodPlanks
		)
		for _, zs in { -1, 1 } do
			Kit.box(
				m,
				"Post",
				CFrame.new(x + s * (span / 2 - 0.5), rope.y + 1.6, bz + zs * (rope.halfZ + 0.1)),
				V3(0.7, 4, 0.7),
				C.woodDark,
				M.Wood
			)
		end
		Kit.box(
			m,
			"Rope",
			CFrame.new(x, rope.y + 2.4, bz + s * (rope.halfZ + 0.1)),
			V3(span - 1, 0.25, 0.25),
			C.cream,
			M.Fabric,
			decor()
		)
	end
	for k = -2, 2 do
		Kit.box(
			m,
			"Plank",
			CFrame.new(x + k * 3.6, rope.y + 0.02, bz),
			V3(0.5, 0.06, rope.halfZ * 2 + 0.2),
			C.woodDark,
			M.Wood,
			decor()
		)
	end
	-- stepping stones (south)
	for k = -2, 2 do
		Kit.disc(m, "SteppingStone", V3(x + k * 3.2, water - 0.4, -118 + (k % 2) * 1.5), 2.8, 2.2, C.rock, M.Slate)
	end
	-- lilies on the water, reeds along the banks
	for _ = 1, 18 do
		local z = rng:NextNumber(-196, 196)
		if math.abs(z - stone.z) > 14 and math.abs(z - bz) > 8 then
			Kit.disc(
				m,
				"Lily",
				V3(x + rng:NextNumber(-3.5, 3.5), water + 0.06, z),
				rng:NextNumber(1.4, 2.4),
				0.08,
				C.leafDark,
				M.Grass,
				decor()
			)
		end
	end
	for _ = 1, 46 do
		local z = rng:NextNumber(-198, 198)
		if math.abs(z - stone.z) > 14 and math.abs(z - bz) > 6 and math.abs(z + 118) > 6 then
			local side = rng:NextNumber() < 0.5 and -1 or 1
			local rx = x + side * rng:NextNumber(w / 2 - 2.5, w / 2 + 1.5)
			local base = at(rx, z)
			for _ = 1, rng:NextInteger(3, 6) do
				local h = rng:NextNumber(2.2, 4.4)
				local p = base + V3(rng:NextNumber(-0.8, 0.8), h / 2 - 0.3, rng:NextNumber(-0.8, 0.8))
				Kit.box(
					m,
					"Reed",
					CFrame.new(p)
						* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 3), rng:NextNumber(-0.15, 0.15)),
					V3(0.18, h, 0.18),
					C.leafDark:Lerp(C.dirt, rng:NextNumber(0, 0.35)),
					M.Grass,
					decor()
				)
				if rng:NextNumber() < 0.35 then
					Kit.box(
						m,
						"Cattail",
						CFrame.new(p + V3(0, h / 2 + 0.3, 0)),
						V3(0.32, 0.9, 0.32),
						C.bark,
						M.Fabric,
						decor()
					)
				end
			end
		end
	end
	return m
end

-- The valley's mountain walls (north and south, terrain): invisible walls at their foot, and pines on top.
local function ridges(f, rng)
	local m = Kit.model("Ridges", f)
	local zr = MapLayout.RIDGE_Z
	for _, side in { 1, -1 } do
		-- invisible walls at the foot (the slopes are steep, but a character could still scramble up them)
		Kit.wall(m, CFrame.new(-375, 40, side * (zr + 1)), V3(490, 80, 2))
		local a = Vector2.new(-130, side * zr)
		local b = Vector2.new(MapLayout.CANYON.minX, side * MapLayout.CANYON.halfWidth)
		local t = (b - a).Unit
		local mid = (a + b) / 2
		local n = V3(t.X, 0, t.Y):Cross(V3(0, 1, 0)) * (side > 0 and 1 or -1)
		Kit.wall(
			m,
			CFrame.fromMatrix(V3(mid.X, 40, mid.Y) + n * 1, V3(t.X, 0, t.Y), V3(0, 1, 0)),
			V3((b - a).Magnitude + 2, 80, 2)
		)
		-- pines along the tops (the hangout's view stays open), thinning out up the mountains
		local placed = 0
		for _ = 1, 160 do
			if placed >= 46 then
				break
			end
			local x = rng:NextNumber(-700, -40)
			local z = side * rng:NextNumber(MapLayout.valleyLimit(x) + 30, 330)
			local open = side > 0 and x > -280 and x < -120 and math.abs(z) < 330
			local p = onLand(x, z)
			local q = onLand(x + 4, z + 4)
			if not open and p.Y < 118 and math.abs(q.Y - p.Y) < 3.4 then
				placed += 1
				Kit.toonPine(m, p - V3(0, 0.4, 0), rng:NextNumber(18, 32), rng)
			end
		end
	end
	return m
end

-- The canyon of Shrine 2 (its floor, walls and rock spine are terrain): invisible walls along its sides, fallen
-- boulders, dead trees and pines on the rims, and a natural stone arch high over the far end.
local function canyon(f, rng)
	local m = Kit.model("Canyon", f)
	local C0 = MapLayout.CANYON
	local len = C0.maxX - C0.minX
	local cx = (C0.minX + C0.maxX) / 2
	local sand = Kit.rgb(214, 150, 100)
	for _, side in { 1, -1 } do
		Kit.wall(m, CFrame.new(cx, 40, side * (C0.halfWidth + 0.5)), V3(len, 80, 1))
		-- boulders along the foot of the walls
		for _ = 1, 10 do
			local x = rng:NextNumber(C0.minX + 6, C0.maxX - 6)
			local z = side * (C0.halfWidth - rng:NextNumber(0, 2.5))
			Kit.boulder(m, at(x, z) - V3(0, 0.5, 0), rng:NextNumber(4, 9), rng, sand, M.Sandstone)
		end
		-- pines and dead trees on the rims
		local placed = 0
		for _ = 1, 60 do
			if placed >= 12 then
				break
			end
			local x, z =
				rng:NextNumber(C0.minX - 10, C0.maxX), side * rng:NextNumber(C0.halfWidth + 10, C0.halfWidth + 80)
			local p, q = onLand(x, z), onLand(x + 4, z + 4)
			if math.abs(q.Y - p.Y) < 3 and p.Y > 40 then
				placed += 1
				if rng:NextNumber() < 0.75 then
					Kit.toonPine(m, p - V3(0, 0.4, 0), rng:NextNumber(14, 22), rng)
				else
					Kit.deadTree(m, p, rng:NextNumber(8, 12), rng)
				end
			end
		end
	end
	-- scrub and bones on the floor
	for _ = 1, 26 do
		local x, z = rng:NextNumber(C0.minX + 4, C0.maxX - 8), rng:NextNumber(-C0.halfWidth + 3, C0.halfWidth - 3)
		if MapLayout.walkable(x, z) and not MapLayout.inZone(2, x, z) then
			local lane = math.min(
				MapLayout.distToLane(MapLayout.lanes[2][1].points, x, z),
				MapLayout.distToLane(MapLayout.lanes[2][2].points, x, z)
			)
			if lane > 8 then
				if rng:NextNumber() < 0.7 then
					Kit.bush(m, at(x, z), rng:NextNumber(1.6, 2.8), rng, Kit.rgb(140, 150, 70))
				else
					Kit.boulder(m, at(x, z), rng:NextNumber(1.6, 3), rng, sand, M.Sandstone)
				end
			end
		end
	end
	-- the rock spine down the middle (terrain) gets a pine on top
	local S = MapLayout.SPINE
	local scx = (S.minX + S.maxX) / 2
	Kit.toonPine(m, onLand(scx + 4, 0) - V3(0, 0.5, 0), 14, rng)
	-- a natural arch of sandstone high across the far end (out of reach: just for the view)
	local ax, ay = 196, 52
	local seg = 14
	for k = 0, seg - 1 do
		local a0, a1 = k / seg * math.pi, (k + 1) / seg * math.pi
		local p0 = V3(ax, ay + math.sin(a0) * 10, -math.cos(a0) * (C0.halfWidth + 10))
		local p1 = V3(ax, ay + math.sin(a1) * 10, -math.cos(a1) * (C0.halfWidth + 10))
		local thick = 6 + math.abs(math.cos((a0 + a1) / 2)) * 5
		Kit.box(
			m,
			"Arch",
			CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05)),
			V3(9 + rng:NextNumber(0, 2), thick, (p1 - p0).Magnitude + 1.5),
			sand:Lerp(Kit.rgb(232, 196, 150), rng:NextNumber(0, 0.4)),
			M.Sandstone,
			{ CanCollide = false }
		)
	end
	return m
end

-- The mountain (terrain, with the tunnels and the cave hollowed out): a stone arch and old mine beams at the
-- tunnel mouths, and inside, crystals, stalactites and stalagmites, glowing mushrooms and lamps.
local function mountain(f, rng)
	local m = Kit.model("Mountain", f)
	local CV = MapLayout.CAVE
	local rockDark = C.caveDark
	local mt, st = CV.mainTunnel, CV.sideTunnel
	-- the cave's roof height at r from its middle (the dome TerrainBuilder carves)
	local function roof(r)
		local t = 1 - (r / CV.radius) ^ 4
		return t > 0 and CV.ceiling * math.sqrt(t) or 0
	end
	-- the tunnel mouths: a stone arch on the main tunnel, old mine beams on the side crack, torches
	for _, s in { -1, 1 } do
		Kit.box(
			m,
			"ArchPillar",
			CFrame.new(230.5, mt.height / 2, s * (mt.maxZ + 1.2)),
			V3(4, mt.height, 3.4),
			C.castleDark,
			M.Cobblestone
		)
		Kit.box(
			m,
			"Beam",
			CFrame.new(230, st.height / 2, (st.minZ + st.maxZ) / 2 + s * ((st.maxZ - st.minZ) / 2 - 0.6)),
			V3(2, st.height, 1.6),
			C.woodDark,
			M.Wood
		)
		Kit.torch(m, V3(225, 0, s * (mt.maxZ + 4)), 7)
	end
	Kit.box(
		m,
		"ArchTop",
		CFrame.new(230.5, mt.height + 0.6, 0),
		V3(4.4, 3.4, mt.maxZ * 2 + 6),
		C.castleDark,
		M.Cobblestone
	)
	Kit.box(
		m,
		"Keystone",
		CFrame.new(228.2, mt.height + 0.4, 0),
		V3(0.4, 3.2, 3),
		C.gold,
		M.Metal,
		{ CastShadow = false, CanCollide = false }
	)
	Kit.box(
		m,
		"BeamTop",
		CFrame.new(230, st.height - 1, (st.minZ + st.maxZ) / 2),
		V3(2, 1.6, st.maxZ - st.minZ),
		C.woodDark,
		M.Wood
	)
	-- inside: crystals round the wall, stalactites, stalagmites, glowing mushrooms
	for k = 0, 17 do
		local a = k / 18 * math.pi * 2 + 0.2
		local r = CV.radius - rng:NextNumber(5, 10)
		local pos = V3(CV.center.X + math.cos(a) * r, 0, CV.center.Y + math.sin(a) * r)
		local nearTunnel = pos.X < CV.center.X - 40 and (math.abs(pos.Z) < 18 or math.abs(pos.Z - 40) < 14)
		if not nearTunnel then
			local cr = Kit.crystals(m, pos, rng:NextNumber(5, 11), k % 2 == 0 and C.crystal or C.crystalPink, rng, 5)
			if k % 3 == 0 then
				Kit.light(
					cr:FindFirstChildWhichIsA("BasePart"),
					"PointLight",
					{ Color = k % 2 == 0 and C.crystal or C.crystalPink, Range = 30, Brightness = 1.4 }
				)
			end
		end
	end
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(8, CV.radius - 14)
		local top = roof(r)
		local h = rng:NextNumber(5, 12)
		Kit.cone(
			m,
			"Stalactite",
			V3(CV.center.X + math.cos(a) * r, top + 1.5, CV.center.Y + math.sin(a) * r),
			h * 0.38,
			-h,
			rockDark,
			4,
			M.Slate,
			decor()
		)
	end
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(CV.radius - 16, CV.radius - 6)
		local p = V3(CV.center.X + math.cos(a) * r, 0, CV.center.Y + math.sin(a) * r)
		if p.X > CV.center.X - 30 or math.abs(p.Z) > 20 then
			Kit.cone(
				m,
				"Stalagmite",
				p - V3(0, 0.3, 0),
				rng:NextNumber(2.4, 4),
				rng:NextNumber(4, 9),
				rockDark,
				4,
				M.Slate
			)
		end
	end
	for _, p in { V3(350, 0, 30), V3(452, 0, -18), V3(424, 0, -54), V3(340, 0, -26), V3(458, 0, 34) } do
		local mush = Kit.mushroom(m, p, rng:NextNumber(5, 8), C.mushroomPurple, rng)
		local cap = mush:FindFirstChild("Cap")
		if cap then
			Kit.light(cap, "PointLight", { Color = C.mushroomPurple, Range = 16, Brightness = 0.8 })
		end
	end
	for _, t in { mt, st } do
		for _, tx in { t.minX + 18, (t.minX + t.maxX) / 2 + 10 } do
			Kit.light(
				Kit.box(
					m,
					"TunnelLamp",
					CFrame.new(tx, t.height - 2.2, (t.minZ + t.maxZ) / 2),
					V3(1.2, 1.2, 1.2),
					C.crystal,
					M.Neon,
					decor()
				),
				"PointLight",
				{ Color = C.crystal, Range = 30, Brightness = 1.2 }
			)
		end
	end
	return m
end

-- The dark forest where the monsters spawn (its floor is terrain) -------------------------------------------------
local function forest(f, rng)
	local m = Kit.model("MonsterForest", f)
	local edge = MapLayout.DWARF_BARRIER_X
	local spawn = MapLayout.FOREST_SPAWN
	for _ = 1, 90 do
		local x, z = rng:NextNumber(-612, edge - 6), rng:NextNumber(-200, 200)
		local clear = (Vector2.new(x, z) - Vector2.new(spawn.X, spawn.Z)).Magnitude > 34
		local lane = math.huge
		for _, l in MapLayout.lanes[1] do
			lane = math.min(lane, MapLayout.distToLane(l.points, x, z))
		end
		if clear and lane > 14 and MapLayout.walkable(x, z) then
			local r = rng:NextNumber()
			if r < 0.68 then
				Kit.toonPine(
					m,
					at(x, z),
					rng:NextNumber(22, 38),
					rng,
					rng:NextNumber() < 0.5 and C.forestLeaf or C.forest
				)
			elseif r < 0.86 then
				Kit.mushroom(
					m,
					at(x, z),
					rng:NextNumber(6, 11),
					rng:NextNumber() < 0.5 and C.mushroomPurple or C.forestGlow,
					rng
				)
			else
				Kit.deadTree(m, at(x, z), rng:NextNumber(9, 14), rng, C.caveDark:Lerp(C.bark, 0.4))
			end
		end
	end
	for _ = 1, 12 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(18, 30)
		local x, z = spawn.X + math.cos(a) * r, spawn.Z + math.sin(a) * r
		Kit.crystals(m, at(x, z), rng:NextNumber(3, 6), C.forestGlow, rng, 3)
	end
	-- the spawn clearing and the rift: a ring of dark stone with a purple glow, facing the valley
	Kit.disc(m, "SpawnStone", spawn + V3(0, 0.25, 0), 30, 0.5, C.caveDark, M.Slate)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local p = spawn + V3(math.cos(a) * 17, 0, math.sin(a) * 17)
		if math.cos(a) < 0.7 then -- open toward the valley
			Kit.box(
				m,
				"StandingStone",
				CFrame.new(p + V3(0, 2.6, 0)) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), -a, rng:NextNumber(-0.1, 0.1)),
				V3(2.2, 5.6 + rng:NextNumber(0, 2.4), 1.4),
				C.caveDark,
				M.Slate
			)
		end
	end
	local rift = spawn + V3(-10, 11, 0)
	local seg = 18
	for k = 0, seg - 1 do
		local a = k / seg * math.pi * 2
		local p = rift + V3(0, math.sin(a) * 10, math.cos(a) * 10)
		Kit.box(
			m,
			"RiftStone",
			CFrame.new(p) * CFrame.Angles(-a, 0, 0),
			V3(2.4, 2.4, 3.8),
			C.caveDark:Lerp(C.black, 0.2),
			M.Basalt,
			{ CastShadow = false }
		)
	end
	local glow = Kit.cyl(m, "Rift", CFrame.new(rift), 0.6, 18, C.magic, M.Neon, decor({ Transparency = 0.2 }))
	Kit.light(glow, "PointLight", { Color = C.magic, Range = 40, Brightness = 2 })
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		Kit.ellipsoid(
			m,
			"FloatingRock",
			rift + V3(4, math.sin(a) * 15, math.cos(a) * 15),
			V3(2.4, 1.8, 2.2),
			C.caveDark,
			M.Basalt,
			decor()
		)
	end
	-- glowing runes along the forest edge (the line dwarves can't cross)
	for z = -196, 196, 14 do
		Kit.box(
			m,
			"Rune",
			CFrame.new(at(edge, z) + V3(0, 0.1, 0)) * CFrame.Angles(0, math.rad(45), 0),
			V3(2.4, 0.2, 2.4),
			C.forestGlow,
			M.Neon,
			decor()
		)
	end
	local wall = Kit.wall(m, CFrame.new(edge, 40, 0), V3(2, 80, MapLayout.RIDGE_Z * 2))
	wall.Name = "DwarfWall"
	Groups.set(wall, "DwarfWall")
	return m
end

-- The mines in the hills on the sides: a timber-framed mouth dug into the ridge, rails and a cart of gold ----------
local function mines(f)
	local m = Kit.model("Mines", f)
	for _, mine in MapLayout.mines do
		local p = mine.pos
		local face = mine.facing -- -1: opens to -z (south)
		local cf = CFrame.new(p) * CFrame.Angles(0, face < 0 and 0 or math.pi, 0) -- -Z of cf faces the valley
		Kit.box(m, "MineHead", cf * CFrame.new(0, 8, 7), V3(26, 16, 14), C.cliffDark, M.Slate)
		for _, s in { -1, 1 } do
			Kit.wedge(
				m,
				"MineSide",
				cf * CFrame.new(s * 15, 5, 5) * CFrame.Angles(0, s > 0 and math.rad(-90) or math.rad(90), 0),
				V3(10, 10, 5),
				C.cliffDark,
				M.Slate
			)
		end
		Kit.box(
			m,
			"Doorway",
			cf * CFrame.new(0, 5, -0.05),
			V3(10, 10, 0.3),
			C.black,
			M.SmoothPlastic,
			{ CastShadow = false }
		)
		for _, s in { -1, 1 } do
			Kit.box(m, "MinePost", cf * CFrame.new(s * 5.6, 5.2, -0.5), V3(1.3, 10.4, 1.3), C.woodDark, M.Wood)
			Kit.box(
				m,
				"Brace",
				cf * CFrame.new(s * 4.4, 9.4, -0.5) * CFrame.Angles(0, 0, s * math.rad(45)),
				V3(0.7, 3, 0.8),
				C.woodDark,
				M.Wood,
				decor()
			)
		end
		Kit.box(m, "MineBeam", cf * CFrame.new(0, 10.6, -0.5), V3(13.5, 1.4, 1.5), C.woodDark, M.Wood)
		Kit.sign(
			m,
			cf * CFrame.new(0, 12.4, -1.4),
			8,
			2,
			"GOLD MINE",
			{ font = Enum.Font.LuckiestGuy, textColor = C.gold, color = C.woodDark }
		)
		-- rails on sleepers and a cart full of gold
		for _, s in { -1, 1 } do
			Kit.box(m, "Rail", cf * CFrame.new(s * 1.6, 0.25, -6), V3(0.4, 0.3, 14), C.iron, M.Metal, decor())
		end
		for k = 0, 6 do
			Kit.box(
				m,
				"Sleeper",
				cf * CFrame.new(0, 0.08, -0.5 - k * 2),
				V3(4.4, 0.25, 0.9),
				C.woodDark,
				M.Wood,
				decor()
			)
		end
		Kit.box(m, "Cart", cf * CFrame.new(5, 1.6, -8), V3(3.6, 2.2, 4.4), C.wood, M.WoodPlanks)
		for _, s in { -1, 1 } do
			Kit.box(m, "CartBand", cf * CFrame.new(5, 1.6, -8 + s * 1.6), V3(3.75, 2.3, 0.3), C.iron, M.Metal, decor())
		end
		Kit.ellipsoid(m, "CartGold", (cf * CFrame.new(5, 2.9, -8)).Position, V3(3.2, 1.4, 4), C.gold, M.Foil, decor())
		Kit.bulb(m, "Lantern", (cf * CFrame.new(-4.4, 9, -1.4)).Position, 0.9, C.warm, 18, 1.5)
	end
	return m
end

-- Resource nodes (ResourceService builds them through this) ------------------------------------------------------
-- A node's model: stone (a pile of round rocks), wood (a tree), gold (a vein: rock with gold crystals).
function MapBuilder.nodeModel(node, parent)
	local rng = Random.new(node.id * 977)
	local m = Kit.model("Node" .. node.id, parent)
	local p = node.pos
	if node.kind == "stone" then
		local colors = { C.stone, C.rock, C.stoneDark }
		local mats = { M.Slate, M.Rock, M.Slate }
		for k = 1, 6 do
			local a = k / 5 * math.pi * 2 + rng:NextNumber(0, 1)
			local r = k == 1 and 0 or (k <= 4 and 2 or 3.4)
			local size = k == 1 and 5 or (k <= 4 and rng:NextNumber(2.6, 3.6) or rng:NextNumber(1.2, 1.8))
			local rock = Kit.ellipsoid(
				m,
				"Rock",
				p + V3(math.cos(a) * r, size * 0.32, math.sin(a) * r),
				V3(size, size * 0.8, size * 0.9),
				colors[(k - 1) % 3 + 1],
				mats[(k - 1) % 3 + 1],
				{ CastShadow = k == 1 }
			)
			rock.CFrame = rock.CFrame * CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2))
		end
		if node.starter then
			Kit.disc(m, "Glow", p + V3(0, 0.1, 0), 9, 0.12, C.gold, M.Neon, decor({ Transparency = 0.45 }))
		end
	elseif node.kind == "wood" then
		local inCave = p.X > MapLayout.CANYON.maxX
		if inCave then
			Kit.mushroom(m, p, 9, C.mushroom, rng)
		else
			Kit.toonTree(m, p, rng:NextNumber(17, 22), rng, rng:NextNumber() < 0.3 and C.autumn or C.leaf)
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Trunk" or d.Name == "Stem") then
				d.CanCollide = true
			end
		end
	else
		Kit.ellipsoid(m, "Vein", p + V3(0, 2.2, 0), V3(6, 4.6, 5), C.cliffDark, M.Slate)
		Kit.ellipsoid(m, "Vein", p + V3(1.8, 1.2, 1.4), V3(3, 2.4, 2.8), C.cliff, M.Rock, { CastShadow = false })
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2
			local cf = CFrame.new(p + V3(math.cos(a) * 1.8, 3.2 + (k % 2), math.sin(a) * 1.8))
				* CFrame.Angles(rng:NextNumber(-0.6, 0.6), a, rng:NextNumber(-0.6, 0.6))
			Kit.box(m, "Gold", cf, V3(1.2, 1.8, 1.2), C.gold, M.Neon, decor())
		end
	end
	m:SetAttribute("Kind", node.kind)
	m:SetAttribute("NodeId", node.id)
	return m
end

-- Shrines ---------------------------------------------------------------------------------------------------------
local function shrine(f, s)
	local m = Kit.model("Shrine" .. s.index, f)
	local p = s.pos
	Kit.disc(m, "Step1", p + V3(0, 0.4, 0), 20, 0.8, C.castleDark, M.Cobblestone)
	Kit.disc(m, "Step2", p + V3(0, 1.2, 0), 14, 0.8, C.castle, M.Marble)
	Kit.disc(m, "Step3", p + V3(0, 2, 0), 9, 0.8, C.castleDark, M.Marble)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local q = p + V3(math.cos(a) * 8.4, 0, math.sin(a) * 8.4)
		Kit.box(m, "PillarBase", CFrame.new(q + V3(0, 0.9, 0)), V3(2.4, 1, 2.4), C.castleDark, M.Marble)
		Kit.box(m, "Pillar", CFrame.new(q + V3(0, 3.6, 0)), V3(1.6, 7.2, 1.6), C.castle, M.Marble)
		Kit.box(
			m,
			"PillarCap",
			CFrame.new(q + V3(0, 7.5, 0)),
			V3(2.2, 0.6, 2.2),
			C.gold,
			M.Metal,
			{ CastShadow = false }
		)
		Kit.box(
			m,
			"Rune",
			CFrame.new(q + V3(0, 4, 0)) * CFrame.Angles(0, -a, 0),
			V3(0.2, 1.2, 0.8),
			C.shrine,
			M.Neon,
			decor()
		)
	end
	local crystal = Kit.box(
		m,
		"Crystal",
		CFrame.new(p + V3(0, 9, 0)) * CFrame.Angles(0, math.rad(45), 0),
		V3(3.8, 8, 3.8),
		C.shrine,
		M.Neon,
		{ CanCollide = false }
	)
	Kit.light(crystal, "PointLight", { Name = "Glow", Color = C.shrine, Range = 40, Brightness = 2.4 })
	local core = Kit.box(
		m,
		"Core",
		CFrame.new(p + V3(0, 9, 0)) * CFrame.Angles(0, math.rad(45), 0),
		V3(1.6, 4, 1.6),
		C.white,
		M.Neon,
		decor()
	)
	-- the ring on the ground: inside it, you count as "near" the shrine
	local ring = {}
	local n = 36
	local R = 26
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		local q = p + V3(math.cos(a) * R, 0.12, math.sin(a) * R)
		table.insert(
			ring,
			Kit.box(
				m,
				"RingTile",
				CFrame.new(q) * CFrame.Angles(0, -a, 0),
				V3(1.2, 0.14, 3.2),
				C.shrine,
				M.Neon,
				decor({ Transparency = 0.25 })
			)
		)
	end
	-- the name and health over it
	local bb = Instance.new("BillboardGui")
	bb.Name = "Bar"
	bb.Size = UDim2.fromOffset(220, 56)
	bb.StudsOffset = V3(0, 16, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 420
	bb.LightInfluence = 0
	bb.Parent = crystal
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Size = UDim2.new(1, 0, 0.55, 0)
	label.BackgroundTransparency = 1
	label.Text = string.upper(s.name)
	label.TextScaled = true
	label.Font = Enum.Font.LuckiestGuy
	label.TextColor3 = C.white
	label.TextStrokeTransparency = 0.2
	label.Parent = bb
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Position = UDim2.new(0.05, 0, 0.62, 0)
	back.Size = UDim2.new(0.9, 0, 0.3, 0)
	back.BackgroundColor3 = C.black
	back.BackgroundTransparency = 0.25
	back.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = C.shrine
	fill.Parent = back
	local c2 = Instance.new("UICorner")
	c2.CornerRadius = UDim.new(1, 0)
	c2.Parent = fill
	m:SetAttribute("Index", s.index)
	MapBuilder.shrines[s.index] = { model = m, crystal = crystal, core = core, ring = ring, fill = fill, label = label }
	return m
end

-- The walls of magic between the shrines (monsters only) --------------------------------------------------------
local function barriers(f)
	for _, b in MapLayout.barriers do
		local m = Kit.model("Barrier" .. b.index, f)
		local width = b.maxZ - b.minZ
		local wall = Kit.box(
			m,
			"Veil",
			CFrame.new(b.x, b.height / 2, (b.minZ + b.maxZ) / 2),
			V3(2, b.height, width),
			C.magic,
			M.ForceField,
			{ Transparency = 0.55, CastShadow = false }
		)
		Groups.set(wall, "MonsterWall")
		for z = b.minZ + 4, b.maxZ - 4, 8 do
			Kit.box(
				m,
				"Rune",
				CFrame.new(b.x, 0.14, z) * CFrame.Angles(0, math.rad(45), 0),
				V3(2.2, 0.14, 2.2),
				C.magic,
				M.Neon,
				decor()
			)
		end
		m:SetAttribute("Index", b.index)
		MapBuilder.barriers[b.index] = m
	end
end

-- Job boards: tap one to change jobs before the plague --------------------------------------------------------------
local function jobBoards(f)
	for i, jb in MapLayout.jobBoards do
		local m = Kit.model("JobBoard" .. i, f)
		local p = jb.pos
		local cf = CFrame.lookAt(p, MapLayout.shrines[jb.shrine].pos * V3(1, 0, 1) + V3(0, p.Y, 0))
		for _, s in { -1, 1 } do
			Kit.box(m, "Post", cf * CFrame.new(s * 4.4, 4, 0), V3(0.8, 8, 0.8), C.woodDark, M.Wood)
		end
		local board = Kit.box(m, "Board", cf * CFrame.new(0, 4.6, 0), V3(8.4, 4.6, 0.5), C.woodLight, M.WoodPlanks)
		Kit.wedge(
			m,
			"Roof",
			cf * CFrame.new(0, 7.8, -0.6),
			V3(9.6, 1.4, 2.4),
			C.roofRed,
			M.ClayRoofTiles,
			{ CastShadow = false }
		)
		local icons = {}
		for _, j in Jobs.dwarf do
			table.insert(icons, j.icon)
		end
		Kit.text(
			board,
			Enum.NormalId.Front,
			"JOBS\n" .. table.concat(icons, " "),
			{ font = Enum.Font.LuckiestGuy, color = C.woodDark, ppu = 30 }
		)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "JobPrompt"
		prompt.ActionText = "Pick a job"
		prompt.ObjectText = "Job Board"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = board
		m:SetAttribute("Shrine", jb.shrine)
		MapBuilder.jobBoards[i] = board
	end
end

-- The camp at Shrine 1 (§7 stage 1): a workshop tent, crates, logs, stone blocks, and the big sign -----------------
local function camp(f, rng)
	local m = Kit.model("Camp", f)
	local y = HILL.height
	local tent = CFrame.new(-166, y, 36) * CFrame.Angles(0, math.rad(200), 0)
	for _, c in { { -4, -3 }, { 4, -3 }, { -4, 3 }, { 4, 3 } } do
		Kit.box(m, "TentPole", tent * CFrame.new(c[1], 3.2, c[2]), V3(0.5, 6.4, 0.5), C.woodDark, M.Wood)
	end
	for k, s in { -1, 1 } do
		Kit.wedge(
			m,
			"Canvas",
			tent * CFrame.new(s * 2.4, 7.6, 0) * CFrame.Angles(0, s > 0 and math.rad(-90) or math.rad(90), 0),
			V3(7.4, 2.6, 5),
			k == 1 and C.red or C.white,
			M.Fabric
		)
	end
	Kit.box(m, "Workbench", tent * CFrame.new(0, 1.6, 0), V3(5, 0.5, 2.4), C.woodLight, M.WoodPlanks)
	for _, s in { -1, 1 } do
		Kit.box(m, "BenchLeg", tent * CFrame.new(s * 2.2, 0.7, 0), V3(0.4, 1.4, 2), C.woodDark, M.Wood)
	end
	Kit.box(
		m,
		"Saw",
		tent * CFrame.new(-1, 1.95, 0.2) * CFrame.Angles(0, 0.4, 0),
		V3(2, 0.1, 0.7),
		C.steel,
		M.Metal,
		decor()
	)
	Kit.crate(m, CFrame.new(-158, y + 1.5, 30) * CFrame.Angles(0, 0.3, 0), V3(3, 3, 3))
	Kit.crate(m, CFrame.new(-158.6, y + 4.2, 30.3) * CFrame.Angles(0, 0.9, 0), V3(2.4, 2.4, 2.4))
	Kit.barrel(m, V3(-162, y, 44))
	Kit.barrel(m, V3(-159.4, y, 41.6))
	Kit.logs(m, CFrame.new(-176, y, 44) * CFrame.Angles(0, 0.2, 0), 8, 3)
	for k = 0, 5 do
		Kit.box(
			m,
			"StoneBlock",
			CFrame.new(-150 + (k % 3) * 2.3, y + 0.9 + math.floor(k / 3) * 1.8, 18)
				* CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0),
			V3(2.2, 1.8, 2.2),
			C.castle,
			M.Limestone
		)
	end
	-- a campfire ringed with stones, a cart of stone and a hay bale
	local fire = V3(-172, y, 22)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		Kit.boulder(m, fire + V3(math.cos(a) * 2.2, -0.1, math.sin(a) * 2.2), 1.1, rng, C.rockDark, M.Slate)
	end
	for k = 0, 2 do
		Kit.cyl(
			m,
			"Firewood",
			CFrame.new(fire + V3(0, 0.45, 0)) * CFrame.Angles(0, k * math.pi / 3, math.rad(20)),
			2.6,
			0.45,
			C.bark,
			M.Wood,
			decor()
		)
	end
	local flame = Kit.ellipsoid(m, "Flame", fire + V3(0, 1.3, 0), V3(1.4, 2, 1.4), C.fire, M.Neon, decor())
	Kit.light(flame, "PointLight", { Color = C.warm, Range = 20, Brightness = 1.8 })
	local cart = CFrame.new(-150, y, 34) * CFrame.Angles(0, math.rad(-20), 0)
	Kit.box(m, "CartBed", cart * CFrame.new(0, 1.9, 0), V3(4, 0.4, 6), C.wood, M.WoodPlanks)
	for _, s in { -1, 1 } do
		Kit.box(m, "CartSide", cart * CFrame.new(s * 1.9, 2.6, 0), V3(0.3, 1.2, 6), C.woodDark, M.WoodPlanks)
		Kit.cyl(m, "Wheel", cart * CFrame.new(s * 2.3, 1.2, 0), 0.5, 2.4, C.woodDark, M.Wood)
	end
	for k = 0, 3 do
		Kit.box(
			m,
			"CartStone",
			cart * CFrame.new((k % 2 - 0.5) * 1.6, 2.7, (math.floor(k / 2) - 0.5) * 2.2) * CFrame.Angles(0, k * 0.3, 0),
			V3(1.5, 1.2, 1.5),
			C.castle,
			M.Limestone,
			decor()
		)
	end
	Kit.cyl(
		m,
		"HayBale",
		CFrame.new(-182, y + 1.2, 48) * CFrame.Angles(0, 0.6, 0),
		3,
		2.4,
		Kit.rgb(226, 196, 110),
		M.Fabric
	)
	-- a few fences and torches round the shrine
	Kit.fence(m, V3(-224, y, -16), V3(-224, y, 16))
	Kit.fence(m, V3(-176, y, -42), V3(-150, y, -42))
	for _, p in { V3(-214, y, -14), V3(-214, y, 14), V3(-186, y, -14), V3(-186, y, 14) } do
		Kit.torch(m, p, 6)
	end
	-- the big sign: HELP BUILD THE CASTLE (§12, 0:00)
	local signCF = CFrame.lookAt(V3(-214, y + 9, 28), V3(-180, y + 9, 10))
	for _, s in { -1, 1 } do
		Kit.box(m, "SignPost", signCF * CFrame.new(s * 7, -4.5, 0.4), V3(0.9, 9.5, 0.9), C.woodDark, M.Wood)
	end
	local sign = Kit.sign(m, signCF, 16, 5.4, "HELP BUILD\nTHE CASTLE!", {
		font = Enum.Font.LuckiestGuy,
		color = C.roofRed,
		frame = C.gold,
		textColor = C.white,
		ppu = 26,
	})
	sign.Name = "BigSign"
	return m
end

-- Trees, bushes, flowers and boulders round the valley (never on a lane, the hill top or the creek) -------------------
local function scenery(f, rng)
	local m = Kit.model("Scenery", f)
	local nodes = MapLayout.nodes
	local function clear(x, z, room)
		if not MapLayout.walkable(x, z) or x < MapLayout.DWARF_BARRIER_X + 6 or x > MapLayout.CANYON.minX - 6 then
			return false
		end
		if math.abs(x - MapLayout.CREEK.x) < MapLayout.CREEK.width / 2 + 4 then
			return false
		end
		local hd = math.sqrt((x - HILL.center.X) ^ 2 + (z - HILL.center.Y) ^ 2)
		if hd < HILL.foot + 4 then
			return false
		end
		for _, l in MapLayout.lanes[1] do
			if MapLayout.distToLane(l.points, x, z) < room + 9 then
				return false
			end
		end
		for _, l in MapLayout.lanes[2] do
			if MapLayout.distToLane(l.points, x, z) < room + 9 then
				return false
			end
		end
		for _, n in nodes do
			if (Vector2.new(n.pos.X, n.pos.Z) - Vector2.new(x, z)).Magnitude < room + 8 then
				return false
			end
		end
		for _, mine in MapLayout.mines do
			if (Vector2.new(mine.pos.X, mine.pos.Z) - Vector2.new(x, z)).Magnitude < 26 then
				return false
			end
		end
		return true
	end
	-- trees in loose groves (a grove's trees share a kind), lone boulders and fallen logs
	local placed = 0
	for _ = 1, 600 do
		if placed >= 104 then
			break
		end
		local x, z = rng:NextNumber(-468, -40), rng:NextNumber(-200, 200)
		local grove = math.noise(x / 60, z / 60, 4.4)
		if clear(x, z, 6) and (grove > -0.1 or rng:NextNumber() < 0.25) then
			placed += 1
			local r = rng:NextNumber()
			if r < 0.84 then
				if grove > 0.15 then
					Kit.toonPine(m, at(x, z) - V3(0, 0.3, 0), rng:NextNumber(20, 32), rng)
				else
					Kit.toonTree(
						m,
						at(x, z) - V3(0, 0.3, 0),
						rng:NextNumber(16, 25),
						rng,
						rng:NextNumber() < 0.18 and C.autumn or nil
					)
				end
			elseif r < 0.93 then
				Kit.boulder(m, at(x, z) - V3(0, 0.8, 0), rng:NextNumber(5, 10), rng, nil, M.Rock)
			else
				Kit.fallenLog(m, at(x, z), rng:NextNumber(8, 12), rng)
			end
		end
	end
	for _ = 1, 340 do
		local x, z = rng:NextNumber(-468, -30), rng:NextNumber(-200, 200)
		if clear(x, z, 1) then
			local r = rng:NextNumber()
			if r < 0.36 then
				Kit.bush(m, at(x, z), rng:NextNumber(3, 5), rng)
			elseif r < 0.78 then
				Kit.flowers(m, at(x, z), rng, 5)
			elseif r < 0.92 then
				Kit.boulder(m, at(x, z) - V3(0, 0.3, 0), rng:NextNumber(2, 4.5), rng, nil, M.Slate)
			else
				Kit.stump(m, at(x, z), rng)
			end
		end
	end
	-- old dwarf ruins by the creek: broken pillars and a fallen arch, half sunk in the grass
	local ruins = { V3(-404, 0, 150), V3(-318, 0, -168), V3(-436, 0, -150) }
	for k, c in ruins do
		local base = at(c.X, c.Z)
		for j = 0, 4 do
			local a = j / 5 * math.pi * 2 + k
			local p = base + V3(math.cos(a) * 7, 0, math.sin(a) * 7)
			local h = rng:NextNumber(2, 9)
			Kit.box(
				m,
				"RuinPillar",
				CFrame.new(p + V3(0, h / 2 - 0.4, 0))
					* CFrame.Angles(rng:NextNumber(-0.06, 0.06), a, rng:NextNumber(-0.06, 0.06)),
				V3(2.2, h, 2.2),
				C.castle:Lerp(C.rock, rng:NextNumber(0.2, 0.6)),
				M.Cobblestone,
				{ CastShadow = h > 5 }
			)
		end
		Kit.box(
			m,
			"RuinBlock",
			CFrame.new(base + V3(2, 0.5, -1)) * CFrame.Angles(0.15, rng:NextNumber(0, 3), 0.25),
			V3(6, 1.6, 2.2),
			C.castleDark,
			M.Cobblestone
		)
	end
	return m
end

-- The hangout between matches: a mead hall terrace on the north ridge --------------------------------------------
local function hangout(f, rng)
	local m = Kit.model("Hangout", f)
	local H = MapLayout.hangout
	local d = H.deck
	local y = MapLayout.RIDGE_TOP
	local cx, cz = (d.minX + d.maxX) / 2, (d.minZ + d.maxZ) / 2
	Kit.box(
		m,
		"Deck",
		CFrame.new(cx, y + 0.3, cz),
		V3(d.maxX - d.minX, 0.6, d.maxZ - d.minZ),
		C.woodLight,
		M.WoodPlanks
	)
	-- railings at the front (the valley view) and the sides, with invisible walls
	for x = d.minX + 2, d.maxX - 2, 6 do
		Kit.box(m, "RailPost", CFrame.new(x, y + 2, d.minZ + 0.5), V3(0.6, 3.4, 0.6), C.woodDark, M.Wood)
	end
	Kit.box(m, "Rail", CFrame.new(cx, y + 3.5, d.minZ + 0.5), V3(d.maxX - d.minX, 0.5, 0.6), C.woodDark, M.Wood)
	Kit.wall(m, CFrame.new(cx, y + 10, d.minZ - 0.5), V3(d.maxX - d.minX + 4, 20, 1))
	Kit.wall(m, CFrame.new(d.minX - 0.5, y + 10, cz), V3(1, 20, d.maxZ - d.minZ + 4))
	Kit.wall(m, CFrame.new(d.maxX + 0.5, y + 10, cz), V3(1, 20, d.maxZ - d.minZ + 4))
	-- the mead hall at the back: a big timber front, a red roof, round shields, banners
	local hz = d.maxZ + 4
	Kit.box(m, "Hall", CFrame.new(cx, y + 9, hz + 8), V3(70, 18, 16), C.wood, M.WoodPlanks)
	for k = -3, 3 do
		Kit.box(m, "Beam", CFrame.new(cx + k * 10, y + 9, hz - 0.2), V3(1.4, 18, 0.8), C.woodDark, M.Wood)
	end
	Kit.box(m, "Lintel", CFrame.new(cx, y + 17.6, hz - 0.3), V3(72, 1.6, 1), C.woodDark, M.Wood)
	for _, s in { -1, 1 } do
		Kit.wedge(
			m,
			"Roof",
			CFrame.new(cx, y + 23, hz + 8 + s * 5) * CFrame.Angles(0, s > 0 and math.pi or 0, 0),
			V3(76, 10, 10),
			C.roofRed,
			M.ClayRoofTiles
		)
	end
	Kit.box(m, "Door", CFrame.new(cx, y + 5, hz - 0.4), V3(8, 10, 0.4), C.woodDark, M.WoodPlanks)
	for k, x in { -24, -12, 12, 24 } do
		Kit.cyl(
			m,
			"Shield",
			CFrame.new(cx + x, y + 11, hz - 0.6) * CFrame.Angles(0, math.rad(90), 0),
			0.4,
			4.4,
			k % 2 == 0 and C.blue or C.red,
			M.SmoothPlastic,
			{ CastShadow = false }
		)
		Kit.ball(m, "Boss", V3(cx + x, y + 11, hz - 0.9), 1, C.gold, M.Metal, decor())
	end
	for _, x in { -32, 32 } do
		Kit.banner(m, CFrame.new(cx + x, y, hz - 2) * CFrame.Angles(0, math.pi, 0), 14, C.roofBlue, C.gold)
		Kit.torch(m, V3(cx + x * 0.5, y, hz - 3), 6)
	end
	Kit.sign(
		m,
		CFrame.new(cx, y + 20.4, hz - 0.9),
		30,
		4,
		"THE HANGOUT",
		{ font = Enum.Font.LuckiestGuy, color = C.woodDark, frame = C.gold, textColor = C.gold, ppu = 24 }
	)
	-- long tables with benches and mugs
	for _, tz in { cz - 6, cz + 6 } do
		Kit.box(m, "Table", CFrame.new(cx - 2, y + 3, tz), V3(30, 0.6, 4), C.woodDark, M.WoodPlanks)
		for _, s in { -1, 1 } do
			Kit.box(m, "Bench", CFrame.new(cx - 2, y + 1.6, tz + s * 3.6), V3(30, 0.5, 1.6), C.wood, M.WoodPlanks)
			Kit.box(m, "TableLeg", CFrame.new(cx - 2 + s * 13, y + 1.6, tz), V3(0.8, 2.8, 3), C.woodDark, M.Wood)
		end
		for k = -5, 5, 2 do
			Kit.disc(
				m,
				"Mug",
				V3(cx - 2 + k * 2.4, y + 3.9, tz + rng:NextNumber(-1, 1)),
				0.9,
				1.2,
				C.gold:Lerp(C.wood, 0.5),
				M.SmoothPlastic,
				decor()
			)
		end
	end
	-- the podium for the match's best (1st in the middle)
	MapBuilder.hangout.podium = {}
	for k, p in H.podium do
		local h = ({ 3, 2, 1.2 })[k]
		local step = Kit.box(
			m,
			"Podium" .. k,
			CFrame.new(p.X, y + h / 2, p.Z),
			V3(7, h, 6),
			({ C.gold, C.steel, C.autumn })[k],
			M.SmoothPlastic
		)
		Kit.text(step, Enum.NormalId.Front, tostring(k), { font = Enum.Font.LuckiestGuy, color = C.white, ppu = 16 })
		MapBuilder.hangout.podium[k] = step
	end
	-- the shop stall and the leaderboard
	local shop = CFrame.lookAt(V3(H.shop.X, y, H.shop.Z), V3(cx, y, cz))
	Kit.box(m, "ShopCounter", shop * CFrame.new(0, 1.8, 0), V3(10, 3.6, 3), C.woodLight, M.WoodPlanks)
	for _, s in { -1, 1 } do
		Kit.box(m, "ShopPole", shop * CFrame.new(s * 4.8, 4, 1.2), V3(0.5, 8, 0.5), C.woodDark, M.Wood)
	end
	for k = 0, 3 do
		Kit.wedge(
			m,
			"ShopAwning",
			shop * CFrame.new(-3.75 + k * 2.5, 8.4, 0.6),
			V3(2.5, 1.2, 4),
			k % 2 == 0 and C.roofBlue or C.white,
			M.Fabric,
			decor()
		)
	end
	local shopSign = Kit.sign(
		m,
		shop * CFrame.new(0, 10, 1.2),
		8,
		2,
		"LOOKS SHOP",
		{ font = Enum.Font.LuckiestGuy, color = C.roofBlue, frame = C.gold, textColor = C.white }
	)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "Shop"
	prompt.ObjectText = "Looks"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = shopSign
	MapBuilder.hangout.shop = shopSign
	local boardCF = CFrame.lookAt(V3(H.board.X, y, H.board.Z), V3(cx, y, cz))
	for _, s in { -1, 1 } do
		Kit.box(m, "BoardPost", boardCF * CFrame.new(s * 6.4, 5, 0.3), V3(0.8, 10, 0.8), C.woodDark, M.Wood)
	end
	local board = Kit.box(m, "Leaderboard", boardCF * CFrame.new(0, 6, 0), V3(12, 8, 0.6), C.woodDark, M.WoodPlanks)
	MapBuilder.hangout.board = board
	return m
end

-- The edges of the world (invisible walls).
local function bounds(f)
	local B = MapLayout.BOUNDS
	local m = Kit.model("Bounds", f)
	local w, d = B.maxX - B.minX, B.maxZ - B.minZ
	local cx, cz = (B.minX + B.maxX) / 2, (B.minZ + B.maxZ) / 2
	Kit.wall(m, CFrame.new(B.minX, 100, cz), V3(2, 200, d))
	Kit.wall(m, CFrame.new(B.maxX, 100, cz), V3(2, 200, d))
	Kit.wall(m, CFrame.new(cx, 100, B.minZ), V3(w, 200, 2))
	Kit.wall(m, CFrame.new(cx, 100, B.maxZ), V3(w, 200, 2))
	-- a kill floor far below, in case anyone falls through the world
	local floor = Kit.wall(m, CFrame.new(cx, -60, cz), V3(w, 2, d))
	floor.Name = "KillFloor"
	return m
end

function MapBuilder.build()
	Groups.setup()
	local old = workspace:FindFirstChild("Map")
	if old then
		old:Destroy()
	end
	local f = Kit.folder("Map", workspace)
	MapBuilder.folder = f
	local rng = Random.new(7)
	TerrainBuilder.build()
	hill(f, rng)
	creek(f, rng)
	ridges(f, rng)
	canyon(f, rng)
	mountain(f, rng)
	forest(f, rng)
	mines(f)
	camp(f, rng)
	scenery(f, rng)
	for _, s in MapLayout.shrines do
		shrine(f, s)
	end
	barriers(f)
	jobBoards(f)
	hangout(f, rng)
	bounds(f)
	Kit.folder("Nodes", workspace)
	Kit.folder("Castle", workspace)
	LightingPresets.apply("build")
	workspace:SetAttribute("MapBuilt", true)
	return f
end

return MapBuilder
