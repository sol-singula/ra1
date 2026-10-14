--[[
Builds the first map (master plan §6) from plain parts, from the coordinates in Shared/World/MapLayout:
the green valley and its creek, the stone hill under Shrine 1 (cliffs all round, four ramps up), the camp, the
paths the monsters walk, the mines in the hills on the sides, the rocky canyon with Shrine 2, the mountain with
its tunnels and the cave of Shrine 3, the dark forest where the monsters spawn, the walls of magic between the
shrines, and the hangout on the north ridge.

Bright and full of colour (§14): smooth cartoon shapes, flat bright ground with lighter patches, chunky rock.
Kept to a few thousand parts for phones: decor never collides or casts shadows unless it's big.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local LightingPresets = require(ReplicatedStorage.Shared.World.LightingPresets)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Jobs = require(ReplicatedStorage.Shared.Data.Jobs)
local Groups = require(script.Parent.Groups)

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

-- The ground ---------------------------------------------------------------------------------------------------
local function ground(f, rng)
	Kit.box(f, "Valley", CFrame.new(-322, -2, 0), V3(596, 4, 480), C.grass)
	Kit.box(f, "CanyonFloor", CFrame.new(104, -2, 0), V3(256, 4, 240), C.path:Lerp(C.cliffWarm, 0.35))
	Kit.box(f, "MountainFloor", CFrame.new(396, -2, 0), V3(328, 4, 480), C.cave)
	-- lighter and darker patches in the grass
	for _ = 1, 34 do
		local x, z = rng:NextNumber(-600, -40), rng:NextNumber(-190, 190)
		local d = math.sqrt((x - HILL.center.X) ^ 2 + (z - HILL.center.Y) ^ 2)
		if d > HILL.foot + 10 and x > -470 then
			Kit.disc(
				f,
				"Patch",
				V3(x, 0.05, z),
				rng:NextNumber(24, 70),
				0.12,
				rng:NextNumber() < 0.6 and C.grassLight or C.grassDark,
				M.SmoothPlastic,
				decor()
			)
		end
	end
	-- the canyon floor: sandy, with darker gravel streaks
	for _ = 1, 10 do
		Kit.disc(
			f,
			"Gravel",
			V3(rng:NextNumber(-10, 220), 0.05, rng:NextNumber(-48, 48)),
			rng:NextNumber(14, 30),
			0.12,
			C.cliffWarm,
			M.SmoothPlastic,
			decor()
		)
	end
end

-- A sandy path along a polyline (x, z points) at the ground's height.
local function path(f, points, width, color)
	for k = 1, #points - 1 do
		local a, b = points[k], points[k + 1]
		local ya, yb = MapLayout.groundY(a.X, a.Y), MapLayout.groundY(b.X, b.Y)
		local pa, pb = V3(a.X, ya + 0.08, a.Y), V3(b.X, yb + 0.08, b.Y)
		local len = (pb - pa).Magnitude
		if len > 0.5 then
			Kit.box(
				f,
				"Path",
				CFrame.lookAt((pa + pb) / 2, pb),
				V3(width, 0.16, len + width * 0.6),
				color or C.path,
				M.SmoothPlastic,
				decor()
			)
			Kit.disc(f, "PathJoint", pb, width, 0.16, color or C.path, M.SmoothPlastic, decor())
		end
	end
end

-- The stone hill under Shrine 1 -------------------------------------------------------------------------------
local function hill(f, rng)
	local cx, cz = HILL.center.X, HILL.center.Y
	local m = Kit.model("Hill", f)
	Kit.disc(m, "Rock", V3(cx, (HILL.height - 0.4 - 2) / 2, cz), HILL.top * 2, HILL.height - 0.4 + 2, C.cliff)
	Kit.disc(m, "Top", V3(cx, HILL.height - 0.2, cz), HILL.top * 2 + 2, 0.4, C.grass)
	-- chunky rocks round the cliff (not on the ramps)
	local n = 48
	for k = 1, n do
		local a = (k + rng:NextNumber(-0.3, 0.3)) / n * math.pi * 2
		local dir = Vector2.new(math.cos(a), math.sin(a))
		local onRamp = false
		for _, ramp in HILL.ramps do
			if dir:Dot(ramp.dir) > math.cos(math.rad(9)) then
				onRamp = true
			end
		end
		if not onRamp then
			local r = HILL.top + rng:NextNumber(-0.5, 1.5)
			local pos = V3(cx + dir.X * r, rng:NextNumber(2.5, 6), cz + dir.Y * r)
			local size = V3(rng:NextNumber(9, 15), rng:NextNumber(6, 10), rng:NextNumber(5, 8))
			Kit.box(
				m,
				"Cliff",
				CFrame.lookAt(pos, pos + V3(dir.X, 0, dir.Y))
					* CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.2, 0.2)),
				size,
				(rng:NextNumber() < 0.5 and C.cliff or C.cliffDark):Lerp(C.cliffWarm, rng:NextNumber(0, 0.4)),
				M.SmoothPlastic,
				{ CastShadow = k % 3 == 0 }
			)
		end
	end
	-- the four ramps (path-coloured wedges with stone curbs)
	local slope = math.atan2(HILL.height, HILL.foot - HILL.top)
	for _, ramp in HILL.ramps do
		local mid = (HILL.top + HILL.foot) / 2
		local pos = V3(cx + ramp.dir.X * mid, HILL.height / 2, cz + ramp.dir.Y * mid)
		local cf = CFrame.lookAt(pos, pos + V3(ramp.dir.X, 0, ramp.dir.Y))
		Kit.wedge(m, "Ramp", cf, V3(HILL.rampWidth, HILL.height, HILL.foot - HILL.top), C.path)
		for _, side in { -1, 1 } do
			Kit.box(
				m,
				"Curb",
				cf
					* CFrame.new(side * (HILL.rampWidth / 2 + 0.6), 0, 0)
					* CFrame.Angles(-slope, 0, 0)
					* CFrame.new(0, 0.9, 0),
				V3(1.6, 1.8, HILL.foot - HILL.top + 1),
				C.castleDark,
				M.SmoothPlastic,
				{ CastShadow = false }
			)
		end
		-- torches at the top of each ramp
		for _, side in { -1, 1 } do
			local t = Vector2.new(-ramp.dir.Y, ramp.dir.X) * side * (HILL.rampWidth / 2 + 2)
			local at = HILL.center + ramp.dir * (HILL.top - 3) + t
			Kit.torch(m, V3(at.X, HILL.height, at.Y), 6)
		end
	end
	-- a few flowers round the edge of the top (not where the castle goes)
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(82, 95)
		Kit.flowers(m, V3(cx + math.cos(a) * r, HILL.height, cz + math.sin(a) * r), rng, 3)
	end
	return m
end

-- The creek across the valley, with its bridges -----------------------------------------------------------------
local function creek(f, rng)
	local m = Kit.model("Creek", f)
	local x, w = MapLayout.CREEK.x, MapLayout.CREEK.width
	local len = MapLayout.RIDGE_Z * 2
	Kit.box(m, "Water", CFrame.new(x, 0.08, 0), V3(w, 0.2, len), C.water, M.SmoothPlastic, { CastShadow = false })
	for _, side in { -1, 1 } do
		Kit.box(
			m,
			"Bank",
			CFrame.new(x + side * (w / 2 + 1), 0.1, 0),
			V3(2.4, 0.22, len),
			C.path,
			M.SmoothPlastic,
			decor()
		)
	end
	for _ = 1, 14 do
		Kit.disc(
			m,
			"Lily",
			V3(x + rng:NextNumber(-5, 5), 0.22, rng:NextNumber(-190, 190)),
			rng:NextNumber(1.6, 2.6),
			0.1,
			C.leafDark,
			M.SmoothPlastic,
			decor()
		)
	end
	-- the thin rope bridge (north lane): easy to guard
	local bz = 112
	Kit.box(m, "Deck", CFrame.new(x, 1.2, bz), V3(w + 10, 0.6, 7), C.woodLight, M.WoodPlanks)
	for _, s in { -1, 1 } do
		Kit.wedge(
			m,
			"BridgeRamp",
			CFrame.new(x + s * (w / 2 + 7), 0.75, bz) * CFrame.Angles(0, s > 0 and math.rad(-90) or math.rad(90), 0),
			V3(7, 1.5, 4),
			C.woodLight,
			M.WoodPlanks
		)
		for _, zs in { -1, 1 } do
			Kit.box(
				m,
				"Post",
				CFrame.new(x + s * (w / 2 + 4.5), 2.6, bz + zs * 3.6),
				V3(0.7, 4, 0.7),
				C.woodDark,
				M.Wood
			)
		end
		Kit.box(m, "Rope", CFrame.new(x, 3.4, bz + s * 3.6), V3(w + 9, 0.25, 0.25), C.cream, M.Fabric, decor())
	end
	-- the stone bridge (middle lane): wide open
	Kit.box(m, "StoneBridge", CFrame.new(x, 0.6, 0), V3(w + 12, 1.2, 22), C.castle)
	for _, s in { -1, 1 } do
		Kit.box(m, "Parapet", CFrame.new(x, 1.9, s * 10.6), V3(w + 12, 1.6, 1), C.castleDark)
	end
	-- stepping stones (south)
	for k = -2, 2 do
		Kit.disc(m, "SteppingStone", V3(x + k * 3.2, 0.25, -118 + (k % 2) * 1.5), 2.6, 0.5, C.rock)
	end
	return m
end

-- The mountain walls of the valley (north and south), closing in on the canyon -----------------------------------
local function ridges(f, rng)
	local m = Kit.model("Ridges", f)
	local top = MapLayout.RIDGE_TOP
	local zr = MapLayout.RIDGE_Z
	local depth = 34
	for _, side in { 1, -1 } do
		-- the straight part, x -620 .. -130
		for k = 0, 6 do
			local xc = -620 + 35 + k * 70
			local cf = CFrame.new(xc, top / 2, side * (zr + depth / 2))
			if side < 0 then
				cf = cf * CFrame.Angles(0, math.pi, 0)
			end
			Kit.wedge(
				m,
				"Slope",
				cf,
				V3(72, top, depth),
				(k % 2 == 0 and C.grassDark or C.leafDark):Lerp(C.cliff, 0.15)
			)
		end
		Kit.box(m, "RidgeTop", CFrame.new(-375, top / 2, side * (zr + depth + 45)), V3(490, top, 90), C.grassDark)
		-- the part that closes in on the canyon mouth
		local a = Vector2.new(-130, side * zr)
		local b = Vector2.new(MapLayout.CANYON.minX, side * MapLayout.CANYON.halfWidth)
		local t = (b - a).Unit
		local tx = V3(t.X, 0, t.Y)
		local n = tx:Cross(V3(0, 1, 0))
		if side < 0 then
			n = -n
		end
		local len = (b - a).Magnitude
		local segs = 3
		for k = 0, segs - 1 do
			local p = a + (b - a) * ((k + 0.5) / segs)
			local pos = V3(p.X, top / 2, p.Y) + n * (depth / 2)
			local xAxis = side > 0 and tx or -tx
			Kit.wedge(
				m,
				"Slope",
				CFrame.fromMatrix(pos, xAxis, V3(0, 1, 0)),
				V3(len / segs + 4, top, depth),
				C.grassDark:Lerp(C.cliff, 0.2)
			)
		end
		local mid = (a + b) / 2
		local backPos = V3(mid.X, top / 2, mid.Y) + n * (depth + 60)
		Kit.box(
			m,
			"RidgeBack",
			CFrame.fromMatrix(backPos, side > 0 and tx or -tx, V3(0, 1, 0)),
			V3(len + 60, top, 120),
			C.grassDark
		)
		-- invisible walls at the foot (the slopes are steep, but a character could still walk up them)
		Kit.wall(m, CFrame.new(-375, 40, side * (zr + 1)), V3(490, 80, 2))
		Kit.wall(m, CFrame.fromMatrix(V3(mid.X, 40, mid.Y) + n * 1, tx, V3(0, 1, 0)), V3(len + 2, 80, 2))
		-- pines and rocks along the ridge top, and snowy peaks behind
		for _ = 1, 22 do
			local x = rng:NextNumber(-610, -150)
			local z = side * rng:NextNumber(zr + depth + 4, zr + depth + 40)
			if not (side > 0 and x > -260 and x < -140) then -- the hangout's view stays open
				Kit.toonPine(m, V3(x, top, z), rng:NextNumber(18, 30), rng)
			end
		end
		for k = 0, 5 do
			local x = -600 + k * 95 + rng:NextNumber(-20, 20)
			local base = V3(x, top - 2, side * (zr + depth + 130 + rng:NextNumber(0, 40)))
			local h = rng:NextNumber(70, 110)
			local w = rng:NextNumber(120, 160)
			Kit.ellipsoid(
				m,
				"Peak",
				base,
				V3(w, h * 2, w * 0.9),
				C.cliff:Lerp(C.cave, 0.35),
				M.SmoothPlastic,
				{ CanCollide = false }
			)
			Kit.ellipsoid(
				m,
				"Snow",
				base + V3(0, h * 0.72, 0),
				V3(w * 0.5, h * 0.62, w * 0.46),
				C.snow,
				M.SmoothPlastic,
				decor()
			)
		end
	end
	return m
end

-- The canyon of Shrine 2 -------------------------------------------------------------------------------------------
local function canyon(f, rng)
	local m = Kit.model("Canyon", f)
	local C0 = MapLayout.CANYON
	local len = C0.maxX - C0.minX
	local cx = (C0.minX + C0.maxX) / 2
	local h = 60
	local bands = { Kit.rgb(226, 150, 96), Kit.rgb(244, 206, 150), Kit.rgb(206, 116, 80), Kit.rgb(240, 180, 120) }
	for _, side in { 1, -1 } do
		Kit.box(m, "Wall", CFrame.new(cx, h / 2, side * (C0.halfWidth + 41)), V3(len, h, 82), Kit.rgb(232, 168, 112))
		-- layered rock (strata) standing out of the inner face
		for k, y in { 9, 22, 36, 50 } do
			Kit.box(
				m,
				"Strata",
				CFrame.new(cx, y, side * (C0.halfWidth + 0.6)),
				V3(len, rng:NextNumber(4, 7), 2),
				bands[k],
				M.SmoothPlastic,
				{ CastShadow = false }
			)
		end
		-- boulders along the foot
		for _ = 1, 9 do
			Kit.boulder(
				m,
				V3(rng:NextNumber(C0.minX + 6, C0.maxX - 6), 0, side * (C0.halfWidth - rng:NextNumber(0, 2))),
				rng:NextNumber(5, 9),
				rng,
				C.cliffWarm
			)
		end
		-- scrub and pines on top
		for _ = 1, 8 do
			Kit.toonPine(
				m,
				V3(rng:NextNumber(C0.minX, C0.maxX), h, side * rng:NextNumber(C0.halfWidth + 6, C0.halfWidth + 70)),
				rng:NextNumber(14, 22),
				rng
			)
		end
	end
	-- the rock spine down the middle (two lanes)
	local S = MapLayout.SPINE
	local scx = (S.minX + S.maxX) / 2
	Kit.box(m, "Spine", CFrame.new(scx, 4, 0), V3(S.maxX - S.minX, 8, S.halfWidth * 2 - 2), C.cliff)
	for k = 0, 4 do
		local x = S.minX + 6 + k * (S.maxX - S.minX - 12) / 4
		local rh = rng:NextNumber(12, S.height + 2)
		Kit.ellipsoid(
			m,
			"SpineRock",
			V3(x, rh * 0.42, rng:NextNumber(-2, 2)),
			V3(rng:NextNumber(14, 18), rh, S.halfWidth * 2 + rng:NextNumber(0, 3)),
			(k % 2 == 0 and C.cliffWarm or C.cliff):Lerp(C.dirt, 0.15),
			M.SmoothPlastic
		)
	end
	Kit.toonPine(m, V3(scx + 4, S.height - 1, 0), 14, rng)
	return m
end

-- The mountain: tunnels and the cave of Shrine 3 ------------------------------------------------------------------
local function mountain(f, rng)
	local m = Kit.model("Mountain", f)
	local CV = MapLayout.CAVE
	local rock, rockDark = C.cave:Lerp(C.cliff, 0.35), C.caveDark
	local function block(name, x0, x1, z0, z1, y0, y1, color)
		Kit.box(
			m,
			name,
			CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
			V3(x1 - x0, y1 - y0, z1 - z0),
			color or rock
		)
	end
	local mt, st = CV.mainTunnel, CV.sideTunnel
	block("RockSouth", 232, mt.maxX - 6, -120, mt.minZ, 0, 70)
	block("RockMiddle", 232, mt.maxX, mt.maxZ, st.minZ, 0, 70)
	block("RockNorth", 232, st.maxX, st.maxZ, 120, 0, 70)
	block("MainRoof", 232, mt.maxX - 6, mt.minZ, mt.maxZ, mt.height, 70, rockDark)
	block("SideRoof", 232, st.maxX, st.minZ, st.maxZ, st.height, 70, rockDark)
	-- the cave's walls: a ring of rock with gaps where the tunnels come in
	local ringN = 22
	for k = 0, ringN - 1 do
		local a = k / ringN * math.pi * 2
		local skip = (k == 11) or (k == 9)
		if not skip then
			local r = CV.radius + 10
			local pos = V3(CV.center.X + math.cos(a) * r, CV.ceiling / 2, CV.center.Y + math.sin(a) * r)
			Kit.box(
				m,
				"CaveWall",
				CFrame.lookAt(pos, V3(CV.center.X, CV.ceiling / 2, CV.center.Y)),
				V3(2 * math.pi * r / ringN + 3, CV.ceiling + 2, 20),
				k % 2 == 0 and rock or rockDark
			)
		end
	end
	Kit.disc(m, "CaveRoof", V3(CV.center.X, CV.ceiling + 4, CV.center.Y), (CV.radius + 22) * 2, 8, rockDark)
	block("RockEast", 472, 560, -120, 120, 0, 72)
	block("RockNorthCave", 330, 476, 90, 120, 0, 72)
	block("RockSouthCave", 330, 476, -120, -90, 0, 72)
	-- the outside: a big terraced cartoon mountain with a snowy top
	local peak = V3(396, 62, 0)
	Kit.box(m, "MountainTop", CFrame.new(396, 66, 0), V3(260, 8, 240), rock)
	Kit.ellipsoid(m, "Dome", peak, V3(290, 150, 250), rock:Lerp(C.cliff, 0.2), M.SmoothPlastic, { CanCollide = false })
	Kit.ellipsoid(
		m,
		"Shoulder",
		peak + V3(-60, 4, 70),
		V3(150, 110, 120),
		rock:Lerp(C.cliff, 0.35),
		M.SmoothPlastic,
		{ CanCollide = false }
	)
	Kit.ellipsoid(
		m,
		"Shoulder",
		peak + V3(-40, 2, -80),
		V3(160, 100, 120),
		rock,
		M.SmoothPlastic,
		{ CanCollide = false }
	)
	Kit.ellipsoid(m, "SnowCap", peak + V3(0, 56, 0), V3(130, 50, 112), C.snow, M.SmoothPlastic, decor())
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(110, 140)
		local pos = V3(peak.X + math.cos(a) * r, 74, math.sin(a) * r)
		Kit.ellipsoid(
			m,
			"Crag",
			pos,
			V3(rng:NextNumber(30, 50), rng:NextNumber(26, 40), rng:NextNumber(26, 44)),
			rock:Lerp(C.cliff, rng:NextNumber(0, 0.4)),
			M.SmoothPlastic,
			{ CanCollide = false }
		)
	end
	-- the tunnel mouths: a stone arch on the main tunnel, old mine beams on the side crack, torches
	for _, s in { -1, 1 } do
		Kit.box(m, "ArchPillar", CFrame.new(231, mt.height / 2, s * (mt.maxZ + 1.5)), V3(4, mt.height, 3), C.castleDark)
		Kit.box(
			m,
			"Beam",
			CFrame.new(231, st.height / 2, (st.minZ + st.maxZ) / 2 + s * (st.maxZ - st.minZ) / 2),
			V3(2, st.height, 1.6),
			C.woodDark,
			M.Wood
		)
		Kit.torch(m, V3(226, 0, s * (mt.maxZ + 4)), 7)
	end
	Kit.box(m, "ArchTop", CFrame.new(231, mt.height + 1.2, 0), V3(4, 3, mt.maxZ * 2 + 6), C.castleDark)
	Kit.box(
		m,
		"BeamTop",
		CFrame.new(231, st.height - 0.6, (st.minZ + st.maxZ) / 2),
		V3(2, 1.6, st.maxZ - st.minZ + 2),
		C.woodDark,
		M.Wood
	)
	-- inside: crystals, stalactites, glowing mushrooms, a purple path
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2 + 0.2
		local r = CV.radius - rng:NextNumber(4, 9)
		local pos = V3(CV.center.X + math.cos(a) * r, 0, CV.center.Y + math.sin(a) * r)
		if math.abs(math.cos(a) + 1) > 0.08 then
			local cr = Kit.crystals(m, pos, rng:NextNumber(5, 10), k % 2 == 0 and C.crystal or C.crystalPink, rng, 4)
			if k % 3 == 0 then
				Kit.light(
					cr:FindFirstChildWhichIsA("BasePart"),
					"PointLight",
					{ Color = k % 2 == 0 and C.crystal or C.crystalPink, Range = 30, Brightness = 1.3 }
				)
			end
		end
	end
	for _ = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, CV.radius - 6)
		local h = rng:NextNumber(5, 12)
		Kit.ellipsoid(
			m,
			"Stalactite",
			V3(CV.center.X + math.cos(a) * r, CV.ceiling - h / 2 + 1, CV.center.Y + math.sin(a) * r),
			V3(h * 0.4, h, h * 0.4),
			rockDark,
			M.SmoothPlastic,
			decor()
		)
	end
	for _, p in { V3(350, 0, 30), V3(452, 0, -18), V3(424, 0, -54), V3(340, 0, -26) } do
		Kit.mushroom(m, p, rng:NextNumber(5, 8), C.mushroomPurple, rng)
	end
	for _, t in { mt, st } do
		Kit.light(
			Kit.box(
				m,
				"TunnelLamp",
				CFrame.new((t.minX + t.maxX) / 2, t.height - 1.2, (t.minZ + t.maxZ) / 2),
				V3(1.2, 1.2, 1.2),
				C.crystal,
				M.Neon,
				decor()
			),
			"PointLight",
			{ Color = C.crystal, Range = 30, Brightness = 1.2 }
		)
	end
	Kit.disc(
		m,
		"CavePath",
		V3(CV.center.X, 0.06, CV.center.Y),
		(CV.radius - 4) * 2,
		0.12,
		C.cave:Lerp(C.magic, 0.15),
		M.SmoothPlastic,
		decor()
	)
	return m
end

-- The dark forest where the monsters spawn --------------------------------------------------------------------------
local function forest(f, rng)
	local m = Kit.model("MonsterForest", f)
	local edge = MapLayout.DWARF_BARRIER_X
	Kit.box(
		m,
		"ForestFloor",
		CFrame.new((-620 + edge) / 2, 0.06, 0),
		V3(edge + 620, 0.12, MapLayout.RIDGE_Z * 2),
		C.forestDark,
		M.SmoothPlastic,
		decor()
	)
	local spawn = MapLayout.FOREST_SPAWN
	for _ = 1, 64 do
		local x, z = rng:NextNumber(-612, edge - 6), rng:NextNumber(-200, 200)
		local clear = (Vector2.new(x, z) - Vector2.new(spawn.X, spawn.Z)).Magnitude > 34
		local lane = math.huge
		for _, l in MapLayout.lanes[1] do
			lane = math.min(lane, MapLayout.distToLane(l.points, x, z))
		end
		if clear and lane > 14 then
			if rng:NextNumber() < 0.75 then
				Kit.toonPine(
					m,
					V3(x, 0, z),
					rng:NextNumber(22, 36),
					rng,
					rng:NextNumber() < 0.5 and C.forestLeaf or C.forest
				)
			else
				Kit.mushroom(
					m,
					V3(x, 0, z),
					rng:NextNumber(6, 11),
					rng:NextNumber() < 0.5 and C.mushroomPurple or C.forestGlow,
					rng
				)
			end
		end
	end
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(18, 30)
		Kit.crystals(m, spawn + V3(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(3, 6), C.forestGlow, rng, 3)
	end
	-- the spawn clearing and the rift: a ring of dark stone with a purple glow, facing the valley
	Kit.disc(m, "SpawnStone", spawn + V3(0, 0.3, 0), 44, 0.6, C.caveDark)
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
			M.SmoothPlastic,
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
			M.SmoothPlastic,
			decor()
		)
	end
	-- glowing runes along the forest edge (the line dwarves can't cross)
	for z = -196, 196, 14 do
		Kit.box(
			m,
			"Rune",
			CFrame.new(edge, 0.12, z) * CFrame.Angles(0, math.rad(45), 0),
			V3(2.4, 0.12, 2.4),
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

-- The mines in the hills on the sides ---------------------------------------------------------------------------
local function mines(f)
	local m = Kit.model("Mines", f)
	for _, mine in MapLayout.mines do
		local p = mine.pos
		local face = mine.facing -- -1: opens to -z (south)
		local cf = CFrame.new(p) * CFrame.Angles(0, face < 0 and 0 or math.pi, 0) -- -Z of cf faces the valley
		Kit.box(m, "MineHead", cf * CFrame.new(0, 8, 6), V3(24, 16, 12), C.cliff)
		Kit.box(
			m,
			"Doorway",
			cf * CFrame.new(0, 5, 0.05),
			V3(10, 10, 0.3),
			C.black,
			M.SmoothPlastic,
			{ CastShadow = false }
		)
		for _, s in { -1, 1 } do
			Kit.box(m, "MinePost", cf * CFrame.new(s * 5.6, 5.2, -0.5), V3(1.3, 10.4, 1.3), C.woodDark, M.Wood)
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
		-- rails and a cart full of gold
		for _, s in { -1, 1 } do
			Kit.box(m, "Rail", cf * CFrame.new(s * 1.6, 0.2, -6), V3(0.4, 0.3, 12), C.iron, M.Metal, decor())
		end
		Kit.box(m, "Cart", cf * CFrame.new(5, 1.6, -8), V3(3.6, 2.2, 4.4), C.wood, M.WoodPlanks)
		Kit.ellipsoid(
			m,
			"CartGold",
			(cf * CFrame.new(5, 2.9, -8)).Position,
			V3(3.2, 1.4, 4),
			C.gold,
			M.SmoothPlastic,
			decor()
		)
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
		for k = 1, 4 do
			local a = k / 4 * math.pi * 2 + rng:NextNumber(0, 1)
			local r = k == 1 and 0 or 2
			local size = k == 1 and 5 or rng:NextNumber(2.6, 3.6)
			Kit.ellipsoid(
				m,
				"Rock",
				p + V3(math.cos(a) * r, size * 0.35, math.sin(a) * r),
				V3(size, size * 0.8, size * 0.9),
				colors[(k - 1) % 3 + 1],
				M.SmoothPlastic,
				{ CastShadow = k == 1 }
			)
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
		Kit.ellipsoid(m, "Vein", p + V3(0, 2.2, 0), V3(6, 4.6, 5), C.cliff, M.SmoothPlastic)
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
	Kit.disc(m, "Step1", p + V3(0, 0.4, 0), 20, 0.8, C.castleDark)
	Kit.disc(m, "Step2", p + V3(0, 1.2, 0), 14, 0.8, C.castle)
	Kit.disc(m, "Step3", p + V3(0, 2, 0), 9, 0.8, C.castleDark)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local q = p + V3(math.cos(a) * 8.4, 0, math.sin(a) * 8.4)
		Kit.box(m, "Pillar", CFrame.new(q + V3(0, 3.6, 0)), V3(1.6, 7.2, 1.6), C.castle)
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
			M.SmoothPlastic,
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
			C.castle
		)
	end
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
	local placed = 0
	for _ = 1, 400 do
		if placed >= 78 then
			break
		end
		local x, z = rng:NextNumber(-468, -40), rng:NextNumber(-200, 200)
		if clear(x, z, 6) then
			placed += 1
			local r = rng:NextNumber()
			if r < 0.55 then
				Kit.toonTree(m, V3(x, 0, z), rng:NextNumber(16, 24), rng, rng:NextNumber() < 0.2 and C.autumn or nil)
			elseif r < 0.85 then
				Kit.toonPine(m, V3(x, 0, z), rng:NextNumber(20, 30), rng)
			else
				Kit.boulder(m, V3(x, 0, z), rng:NextNumber(6, 11), rng)
			end
		end
	end
	for _ = 1, 220 do
		local x, z = rng:NextNumber(-468, -30), rng:NextNumber(-200, 200)
		if clear(x, z, 1) then
			local r = rng:NextNumber()
			if r < 0.4 then
				Kit.bush(m, V3(x, 0, z), rng:NextNumber(3, 5), rng)
			elseif r < 0.8 then
				Kit.flowers(m, V3(x, 0, z), rng, 4)
			else
				Kit.boulder(m, V3(x, 0, z), rng:NextNumber(2.5, 4.5), rng)
			end
		end
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
			C.roofRed
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
	ground(f, rng)
	for _, lane in MapLayout.lanes[1] do
		path(f, lane.points, 10)
	end
	path(f, MapLayout.lanes[2][1].points, 9, C.path:Lerp(C.cliffWarm, 0.2))
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
