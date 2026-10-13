-- The station: where every expedition starts and ends. A warm, enclosed Victorian train shed (iron arches, glass
-- roof, lamp posts along the platform) and a concourse behind it with the departure board, benches, chandeliers and,
-- on the back wall, the Hall of Records. Built once as a template; ExpeditionService puts it beside the train in the
-- lobby and takes it away when the train leaves.
--   handles: { model, board (TextLabel), hall = { top = { plaque, crew, mini, cf }, plaques = { TextLabel } } }
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Layout = require(ReplicatedStorage.Shared.World.Layout)

local StationBuilder = {}

local C, M = Kit.C, Kit.M
local box, wedge, cyl, disc = Kit.box, Kit.wedge, Kit.cyl, Kit.disc
local FLOOR = Layout.FLOOR_Y
local X0, X1 = -262, 262 -- the shed's ends
local BRICK = Kit.rgb(122, 70, 52)
local BRICK_DARK = Kit.rgb(84, 50, 40)
local TILE = Kit.rgb(190, 176, 150)
local TILE_DARK = Kit.rgb(122, 108, 92)

-- One iron arch rib over the shed, in the plane x = `x`, from z = za to z = zb, rising to `rise` above `base`.
local function arch(parent, x, za, zb, base, rise, color)
	local n = 8
	local mid = (za + zb) / 2
	local half = (zb - za) / 2
	local pts = {}
	for i = 0, n do
		local t = i / n
		local a = math.pi * t
		table.insert(pts, Vector3.new(x, base + math.sin(a) * rise, mid - math.cos(a) * half))
	end
	for i = 1, n do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		box(parent, "Rib", CFrame.lookAt((a + b) / 2, b), Vector3.new(0.9, 1.4, len + 0.3), color or C.iron, M.Metal, { CastShadow = false })
	end
	return pts
end

function StationBuilder.build(parent)
	local model = Kit.model("Station", parent)
	local rng = Random.new(5)
	local handles = { model = model }

	-- the ground under everything, the track bed and the track
	box(model, "Bed", CFrame.new(0, -0.6, -8), Vector3.new(X1 - X0 + 40, 1, 60), C.gravel, M.Pebble)
	Kit.track(model, CFrame.new(0, 0.1, 0), X1 - X0 + 30)
	-- the main platform (doors side) and the narrow far platform
	local pz0, pz1 = Layout.PLATFORM_Z0, 47
	box(model, "Platform", CFrame.new(0, FLOOR / 2, (pz0 + pz1) / 2), Vector3.new(X1 - X0, FLOOR, pz1 - pz0), TILE, M.Slate)
	box(model, "PlatformEdge", CFrame.new(0, FLOOR - 0.15, pz0 + 1), Vector3.new(X1 - X0, 0.32, 2), C.concrete, M.Concrete)
	box(model, "SafetyLine", CFrame.new(0, FLOOR + 0.02, pz0 + 2.4), Vector3.new(X1 - X0, 0.06, 0.6), Kit.rgb(230, 190, 60), M.SmoothPlastic, { CastShadow = false })
	box(model, "FarPlatform", CFrame.new(0, FLOOR / 2, -21), Vector3.new(X1 - X0, FLOOR, 16), TILE_DARK, M.Slate)
	-- walls: behind the far platform, and the two ends of the shed with a dark tunnel mouth for the track
	box(model, "FarWall", CFrame.new(0, 26, -30), Vector3.new(X1 - X0, 52, 2), BRICK, M.Brick)
	for i = -6, 6 do
		box(model, "Pilaster", CFrame.new(i * 40, 20, -28.6), Vector3.new(3, 40, 1), BRICK_DARK, M.Brick)
		local poster = box(model, "Poster", CFrame.new(i * 40 + 20, 10, -28.85), Vector3.new(7, 9, 0.2), C.cream:Lerp(C.dirt, 0.2), M.SmoothPlastic, { CastShadow = false })
		Kit.text(poster, Enum.NormalId.Back, ({ "VISIT THE\nOVERGROWN\nLINE", "MIND\nTHE\nGAP", "LAST\nTRAIN\nEVERY\nEVENING", "KEEP\nYOUR\nTICKET" })[(i + 7) % 4 + 1], {
			color = C.greenDark,
			font = Enum.Font.Oswald,
		})
	end
	for _, ex in { X0, X1 } do
		local dir = ex > 0 and 1 or -1
		-- wall with an arched tunnel opening over the track
		box(model, "EndWall", CFrame.new(ex, 30, 22), Vector3.new(2, 60, 70), BRICK, M.Brick)
		box(model, "EndWall", CFrame.new(ex, 36, -19), Vector3.new(2, 48, 22), BRICK, M.Brick)
		box(model, "EndWallTop", CFrame.new(ex, 46, 0), Vector3.new(2, 28, 22), BRICK, M.Brick)
		box(model, "Tunnel", CFrame.new(ex + dir * 6, 15, 0), Vector3.new(10, 30, 22), C.black, M.SmoothPlastic)
		for i = -3, 3 do
			local a = (i / 3) * (math.pi / 2)
			box(model, "TunnelArch", CFrame.new(ex - dir * 0.6, 22 + math.cos(a) * 9, math.sin(a) * 11), Vector3.new(1.4, 2.2, 5), C.concreteDark, M.Concrete, { CastShadow = false })
		end
	end

	-- the shed roof: iron arches every 22 studs, glass panels between them
	local roofBase, rise = 34, 22
	local za, zb = -30, 46
	for x = X0 + 11, X1 - 11, 22 do
		local pts = arch(model, x, za, zb, roofBase, rise)
		-- columns under the arch ends
		for _, z in { za + 1.5, zb - 1.5 } do
			disc(model, "Column", Vector3.new(x, roofBase / 2, z), 2.2, roofBase, C.iron, M.Metal)
			disc(model, "ColumnCap", Vector3.new(x, roofBase - 0.6, z), 3.2, 1.2, C.brassDark, M.Metal, { CastShadow = false })
			disc(model, "ColumnBase", Vector3.new(x, FLOOR + 0.6, z), 3, 1.2, C.iron, M.Metal, { CastShadow = false })
		end
		_ = pts
	end
	-- glass roof panels (one long strip per segment of the arch)
	do
		local n = 8
		local mid, half = (za + zb) / 2, (zb - za) / 2
		for i = 1, n do
			local a0, a1 = math.pi * (i - 1) / n, math.pi * i / n
			local p0 = Vector3.new(0, roofBase + math.sin(a0) * rise, mid - math.cos(a0) * half)
			local p1 = Vector3.new(0, roofBase + math.sin(a1) * rise, mid - math.cos(a1) * half)
			local len = (p1 - p0).Magnitude
			local cf = CFrame.lookAt((p0 + p1) / 2, p1)
			box(model, "RoofGlass", cf * CFrame.new(0, 0.6, 0), Vector3.new(X1 - X0, 0.3, len + 0.4), Kit.rgb(60, 70, 90), M.Glass, {
				Transparency = 0.35,
				CastShadow = false,
			})
		end
	end
	-- a solid roof cap behind the glass (so the night sky stays dark and the shed reads as enclosed)
	box(model, "RoofCap", CFrame.new(0, roofBase + rise + 3, (za + zb) / 2), Vector3.new(X1 - X0, 1, zb - za), C.roof, M.Metal, { CastShadow = false })

	-- lamp posts along the platform
	for x = X0 + 30, X1 - 30, 30 do
		Kit.lampPost(model, Vector3.new(x, FLOOR, pz0 + 6), 13)
	end
	-- benches and luggage on the platform
	for x = X0 + 45, X1 - 45, 60 do
		local bench = Kit.model("Bench", model)
		box(bench, "Seat", CFrame.new(x, FLOOR + 1.8, 34), Vector3.new(8, 0.5, 2.4), C.wood, M.WoodPlanks)
		box(bench, "Back", CFrame.new(x, FLOOR + 3.4, 35.1), Vector3.new(8, 2.6, 0.4), C.wood, M.WoodPlanks)
		for _, dx in { -3.4, 3.4 } do
			box(bench, "Leg", CFrame.new(x + dx, FLOOR + 0.9, 34), Vector3.new(0.4, 1.8, 2), C.iron, M.Metal, { CastShadow = false })
		end
		if rng:NextNumber() < 0.6 then
			Kit.crate(model, CFrame.new(x + 7, FLOOR + 1.2, 33) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Vector3.new(2.6, 2.4, 2.2), C.woodDark)
		end
	end
	-- a luggage cart and a pile of suitcases near the middle
	local cart = Kit.model("LuggageCart", model)
	box(cart, "CartBed", CFrame.new(-26, FLOOR + 1.6, 30), Vector3.new(7, 0.4, 3.4), C.iron, M.Metal)
	for _, dx in { -2.8, 2.8 } do
		for _, dz in { -1.4, 1.4 } do
			cyl(cart, "CartWheel", CFrame.new(-26 + dx, FLOOR + 0.8, 30 + dz) * CFrame.Angles(0, math.rad(90), 0), 0.4, 1.6, C.black, M.Rubber)
		end
	end
	local cases = { Kit.rgb(120, 60, 40), Kit.rgb(70, 50, 40), Kit.rgb(150, 110, 70), Kit.rgb(60, 70, 90) }
	for i = 0, 4 do
		box(cart, "Suitcase", CFrame.new(-28 + i * 1.3, FLOOR + 2.4 + (i % 2) * 0.9, 30) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), Vector3.new(1.1, 1.6, 2.6), cases[i % 4 + 1], M.Leather)
	end

	-- the platform sign
	Kit.sign(model, CFrame.new(0, 24, pz0 + 4) * CFrame.Angles(0, math.pi, 0), 30, 4, "PLATFORM 1 · THE LAST TRAIN · OVERGROWN LINE", { ppu = 20 })
	for _, x in { -2, 2 } do
		box(model, "SignChain", CFrame.new(x * 6, 29, pz0 + 4), Vector3.new(0.2, 6, 0.2), C.iron, M.Metal, { CastShadow = false, CanCollide = false })
	end

	-- the concourse: through three big arches behind the platform
	local cz0, cz1 = 46, 124
	local cx0, cx1 = -86, 86
	box(model, "ConcourseFloor", CFrame.new(0, FLOOR / 2, (cz0 + cz1) / 2), Vector3.new(cx1 - cx0, FLOOR, cz1 - cz0), TILE, M.Marble)
	-- checker inlay down the middle
	for i = 0, 7 do
		for j = 0, 3 do
			if (i + j) % 2 == 0 then
				box(model, "Inlay", CFrame.new(-21 + j * 14, FLOOR + 0.03, cz0 + 6 + i * 9), Vector3.new(14, 0.06, 9), TILE_DARK, M.Marble, { CastShadow = false })
			end
		end
	end
	-- the arch wall between the platform and the concourse
	local wallH = 40
	for _, seg in { { X0, -60 }, { -36, -12 }, { 12, 36 }, { 60, X1 } } do
		box(model, "ArchWall", CFrame.new((seg[1] + seg[2]) / 2, wallH / 2, cz0), Vector3.new(seg[2] - seg[1], wallH, 2.4), BRICK, M.Brick)
	end
	for _, opening in { { -60, -36 }, { -12, 12 }, { 36, 60 } } do
		local ox = (opening[1] + opening[2]) / 2
		box(model, "ArchHeader", CFrame.new(ox, 30, cz0), Vector3.new(24, 20, 2.4), BRICK, M.Brick)
		for i = -4, 4 do
			local a = (i / 4) * (math.pi / 2)
			box(model, "ArchStone", CFrame.new(ox + math.sin(a) * 12, 18 + math.cos(a) * 6, cz0 - 1.3), Vector3.new(3, 1.6, 0.4), C.concrete, M.Concrete, { CastShadow = false })
		end
	end
	-- concourse walls and ceiling
	box(model, "ConcourseWall", CFrame.new(cx0, 20, (cz0 + cz1) / 2), Vector3.new(2, 40, cz1 - cz0), BRICK, M.Brick)
	box(model, "ConcourseWall", CFrame.new(cx1, 20, (cz0 + cz1) / 2), Vector3.new(2, 40, cz1 - cz0), BRICK, M.Brick)
	box(model, "BackWall", CFrame.new(0, 20, cz1), Vector3.new(cx1 - cx0, 40, 2), BRICK_DARK, M.Brick)
	box(model, "ConcourseCeiling", CFrame.new(0, 40.5, (cz0 + cz1) / 2), Vector3.new(cx1 - cx0, 1, cz1 - cz0), C.cream:Lerp(C.dirt, 0.25), M.Plaster)
	for x = cx0 + 20, cx1 - 20, 20 do
		box(model, "CeilingBeam", CFrame.new(x, 39.4, (cz0 + cz1) / 2), Vector3.new(1.4, 1.4, cz1 - cz0), C.woodDark, M.Wood, { CastShadow = false })
	end
	-- wood panelling round the lower walls
	for _, side in { -1, 1 } do
		box(model, "Wainscot", CFrame.new(side * (cx1 - 1.2), FLOOR + 3.5, (cz0 + cz1) / 2), Vector3.new(0.4, 7, cz1 - cz0 - 2), C.woodDark, M.Wood)
	end
	-- chandeliers
	for _, p in { { -40, 70 }, { 40, 70 }, { -40, 100 }, { 40, 100 }, { 0, 86 } } do
		local x, z = p[1], p[2]
		box(model, "ChandelierChain", CFrame.new(x, 36.5, z), Vector3.new(0.2, 7, 0.2), C.iron, M.Metal, { CastShadow = false, CanCollide = false })
		disc(model, "ChandelierRing", Vector3.new(x, 32.8, z), 6, 0.4, C.brass, M.Metal, { CastShadow = false, CanCollide = false })
		for i = 0, 5 do
			local a = i * math.pi / 3
			local bulb = Kit.ball(model, "ChandelierBulb", Vector3.new(x + math.cos(a) * 2.8, 33.4, z + math.sin(a) * 2.8), 0.7, C.warm, M.Neon, { CastShadow = false, CanCollide = false })
			if i == 0 then
				Kit.light(bulb, "PointLight", { Range = 38, Brightness = 1.8, Color = C.warm })
			end
		end
	end
	-- benches in the concourse
	for _, x in { -54, -30, 30, 54 } do
		for _, z in { 64, 80 } do
			local bench = Kit.model("Bench", model)
			box(bench, "Seat", CFrame.new(x, FLOOR + 1.8, z), Vector3.new(12, 0.5, 2.6), C.wood, M.WoodPlanks)
			box(bench, "Back", CFrame.new(x, FLOOR + 3.6, z + 1.2), Vector3.new(12, 3, 0.4), C.wood, M.WoodPlanks)
			for _, dx in { -5, 5 } do
				box(bench, "Leg", CFrame.new(x + dx, FLOOR + 0.9, z), Vector3.new(0.5, 1.8, 2.2), C.iron, M.Metal, { CastShadow = false })
			end
		end
	end
	-- potted palms by the arches
	for _, x in { -72, -48, 48, 72 } do
		disc(model, "Planter", Vector3.new(x, FLOOR + 1.4, 52), 3, 2.8, C.brassDark, M.Metal)
		Kit.ball(model, "Palm", Vector3.new(x, FLOOR + 5, 52), 4.6, C.leaf, M.Grass)
		Kit.ball(model, "Palm", Vector3.new(x + 0.8, FLOOR + 7, 52.4), 3.2, C.moss, M.Grass, { CastShadow = false })
	end
	-- ticket windows on the east wall (decoration)
	for i = 0, 2 do
		local z = 62 + i * 16
		box(model, "TicketBooth", CFrame.new(cx1 - 3, FLOOR + 6, z), Vector3.new(4, 12, 11), C.woodDark, M.Wood)
		box(model, "TicketGlass", CFrame.new(cx1 - 5.05, FLOOR + 7.5, z), Vector3.new(0.2, 4, 7), C.glass, M.Glass, { Transparency = 0.5, CastShadow = false })
		local sign = box(model, "TicketSign", CFrame.new(cx1 - 5.1, FLOOR + 11, z), Vector3.new(0.2, 1.4, 8), C.greenDark, M.SmoothPlastic, { CastShadow = false })
		Kit.text(sign, Enum.NormalId.Left, "TICKETS", { color = C.brass })
		local glow = Kit.ball(model, "TicketLamp", Vector3.new(cx1 - 5.5, FLOOR + 9.8, z), 0.6, C.warm, M.Neon, { CastShadow = false, CanCollide = false })
		Kit.light(glow, "PointLight", { Range = 12, Brightness = 1.2, Color = C.warm })
	end
	-- the big clock over the middle arch
	local clock = cyl(model, "Clock", CFrame.new(0, 34, cz0 - 1.5) * CFrame.Angles(0, math.rad(90), 0), 0.6, 7, C.cream, M.SmoothPlastic)
	cyl(model, "ClockRim", CFrame.new(0, 34, cz0 - 1.4) * CFrame.Angles(0, math.rad(90), 0), 0.5, 7.8, C.brass, M.Metal, { CastShadow = false })
	box(model, "ClockHand", CFrame.new(0, 35.4, cz0 - 1.85), Vector3.new(0.3, 2.8, 0.1), C.black, M.SmoothPlastic, { CastShadow = false })
	box(model, "ClockHand", CFrame.new(1, 34, cz0 - 1.85), Vector3.new(2, 0.3, 0.1), C.black, M.SmoothPlastic, { CastShadow = false })
	_ = clock

	-- the departure board, facing the concourse (ExpeditionService writes the countdown)
	local boardCf = CFrame.new(0, 22, cz0 + 1.6) * CFrame.Angles(0, math.pi, 0)
	local board = box(model, "DepartureBoard", boardCf, Vector3.new(30, 8, 0.6), C.black, M.SmoothPlastic)
	box(model, "DepartureFrame", boardCf * CFrame.new(0, 0, 0.2), Vector3.new(31.2, 9.2, 0.4), C.brass, M.Metal)
	local boardText = Kit.text(board, Enum.NormalId.Front, "THE LAST TRAIN\nBOARDING", { color = Kit.rgb(255, 196, 90), font = Enum.Font.Oswald, ppu = 20 })
	handles.board = boardText
	-- and a second one on the platform side, facing the train
	local board2Cf = CFrame.new(0, 22, cz0 - 1.6)
	local board2 = box(model, "DepartureBoard", board2Cf * CFrame.new(0, -8, 0), Vector3.new(24, 6, 0.6), C.black, M.SmoothPlastic)
	handles.board2 = Kit.text(board2, Enum.NormalId.Front, "BOARDING", { color = Kit.rgb(255, 196, 90), font = Enum.Font.Oswald, ppu = 20 })

	-- the Hall of Records on the back wall
	local hallZ = cz1 - 1.2
	local title = box(model, "HallTitle", CFrame.new(0, 31, hallZ), Vector3.new(40, 4.4, 0.4), C.greenDark, M.SmoothPlastic, { CastShadow = false })
	Kit.text(title, Enum.NormalId.Front, "HALL OF RECORDS", { color = C.brass, font = Enum.Font.Oswald, ppu = 24 })
	box(model, "HallTitleFrame", CFrame.new(0, 31, hallZ + 0.15), Vector3.new(41, 5.4, 0.3), C.brass, M.Metal, { CastShadow = false })
	-- the top record: a stage with the crew, a miniature of their train and a plaque
	local stageCf = CFrame.new(0, FLOOR, cz1 - 14)
	box(model, "RecordStage", stageCf * CFrame.new(0, 0.8, 0), Vector3.new(34, 1.6, 14), C.woodDark, M.WoodPlanks)
	box(model, "RecordStageTrim", stageCf * CFrame.new(0, 1.65, -6.9), Vector3.new(34, 0.2, 0.3), C.brass, M.Metal, { CastShadow = false })
	box(model, "RecordCarpet", stageCf * CFrame.new(0, 1.65, 0), Vector3.new(30, 0.1, 11), C.carpet, M.Carpet, { CastShadow = false })
	local plaqueCf = CFrame.new(0, FLOOR + 12, hallZ - 0.1)
	local plaque = box(model, "RecordPlaque", plaqueCf, Vector3.new(26, 9, 0.4), C.black, M.SmoothPlastic)
	box(model, "RecordPlaqueFrame", plaqueCf * CFrame.new(0, 0, 0.15), Vector3.new(27.2, 10.2, 0.3), C.brass, M.Foil, { CastShadow = false })
	local plaqueText = Kit.text(plaque, Enum.NormalId.Front, "NO RECORD YET\nBe the first crew on this wall.", { color = C.cream, font = Enum.Font.Oswald, ppu = 20 })
	-- spotlights on the stage
	for _, x in { -12, 12 } do
		local can = cyl(model, "Spot", CFrame.new(x, 38.5, cz1 - 26) * CFrame.Angles(0, 0, math.rad(-60)) * CFrame.Angles(0, math.rad(90), 0), 2, 1.6, C.iron, M.Metal, { CastShadow = false })
		Kit.light(can, "SpotLight", { Face = Enum.NormalId.Right, Range = 40, Angle = 35, Brightness = 2.5, Color = C.warm })
	end
	local crew = Kit.folder("RecordCrew", model)
	local mini = Kit.folder("RecordTrain", model)
	handles.hall = {
		top = { plaque = plaqueText, crew = crew, mini = mini, cf = stageCf * CFrame.new(0, 1.7, 0) },
		plaques = {},
	}
	-- records 2-5: plaques on the back wall either side
	for i, x in { -30, 30, -52, 52 } do
		local pcf = CFrame.new(x, FLOOR + 13, hallZ - 0.1)
		local p = box(model, "Plaque", pcf, Vector3.new(16, 8, 0.4), C.black, M.SmoothPlastic)
		box(model, "PlaqueFrame", pcf * CFrame.new(0, 0, 0.15), Vector3.new(16.8, 8.8, 0.3), C.brassDark, M.Metal, { CastShadow = false })
		handles.hall.plaques[i] = Kit.text(p, Enum.NormalId.Front, `#{i + 1}\n—`, { color = C.cream, font = Enum.Font.Oswald, ppu = 20 })
		local lamp = Kit.ball(model, "PlaqueLamp", Vector3.new(x, FLOOR + 18.5, hallZ - 1.5), 0.6, C.warm, M.Neon, { CastShadow = false, CanCollide = false })
		Kit.light(lamp, "SpotLight", { Face = Enum.NormalId.Bottom, Range = 14, Angle = 70, Brightness = 2, Color = C.warm })
	end
	-- the station's welcome sign over the concourse entrance from the platform
	Kit.sign(model, CFrame.new(0, 17, cz0 + 1.6) * CFrame.Angles(0, math.pi, 0), 18, 2.6, "ALL ABOARD", { ppu = 24 })

	-- keep everyone in: invisible walls at the shed ends and over the far platform
	Kit.wall(model, CFrame.new(X0 + 2, 30, 8), Vector3.new(1, 60, 80))
	Kit.wall(model, CFrame.new(X1 - 2, 30, 8), Vector3.new(1, 60, 80))
	return handles
end

return StationBuilder
