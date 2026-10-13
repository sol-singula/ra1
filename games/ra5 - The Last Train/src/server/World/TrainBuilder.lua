-- The train: seven cars built from plain parts (World/Layout says where everything is). Racing green and cream with
-- brass trim outside; wood, brass and warm lamps inside. Returns the handles the services need:
--   doors        every outside door: { leaves = { {part, closed, open} }, lamp, beacon }
--   cabins       [index] = { model, shell = { finish parts }, color = { colour parts }, plate (TextLabel), items folder }
--   engineStages [1..3] = models shown as the Engine Overhaul is built; lampStages [1..2] likewise
--   fuelBar      the engine room's fuel gauge bar; boards (upgrade board and crew board SurfaceGui labels)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Layout = require(ReplicatedStorage.Shared.World.Layout)

local TrainBuilder = {}

local C, M = Kit.C, Kit.M
local box, wedge, cyl, disc = Kit.box, Kit.wedge, Kit.cyl, Kit.disc
local FLOOR, CEIL, ROOF = Layout.FLOOR_Y, Layout.CEIL_Y, Layout.ROOF_Y
local HALF_OUT = Layout.CAR_W / 2
local HALF_IN = Layout.HALF_IN

-- the exterior colour bands (bottom to top) and the window band they leave
local BANDS = {
	{ FLOOR - 0.6, 8, C.green, M.SmoothPlastic },
	{ 8, 8.35, C.brass, M.Metal },
	{ 8.35, 13, C.cream, M.SmoothPlastic },
	{ 13, 13.35, C.brass, M.Metal },
	{ 13.35, CEIL + 0.6, C.green, M.SmoothPlastic },
}

-- A wall in the plane z = `z` from x0 to x1, built as bands with rectangular holes cut out.
-- holes: { { xa, xb, ya, yb } }; bands: { { y0, y1, color, material } }; thickness along Z.
-- `frame` (optional) places the whole wall: end walls use a frame turned 90 degrees, so their local X runs along
-- the world's -Z.
local function holeyWall(parent, name, x0, x1, z, thickness, bands, holes, extra, frame)
	frame = frame or CFrame.new()
	for _, band in bands do
		local y0, y1 = band[1], band[2]
		-- the x intervals of this band not covered by a hole that overlaps it
		local cuts = {}
		for _, h in holes do
			if h[3] < y1 - 1e-3 and h[4] > y0 + 1e-3 then
				table.insert(cuts, { math.max(h[1], x0), math.min(h[2], x1), h[3], h[4] })
			end
		end
		-- split the band vertically where holes start or end, so partial overlaps work
		local ys = { y0, y1 }
		for _, c in cuts do
			for _, y in { c[3], c[4] } do
				if y > y0 + 1e-3 and y < y1 - 1e-3 then
					table.insert(ys, y)
				end
			end
		end
		table.sort(ys)
		for i = 1, #ys - 1 do
			local ya, yb = ys[i], ys[i + 1]
			if yb - ya > 1e-3 then
				local open = {}
				for _, c in cuts do
					if c[3] < yb - 1e-3 and c[4] > ya + 1e-3 then
						table.insert(open, c)
					end
				end
				table.sort(open, function(a, b)
					return a[1] < b[1]
				end)
				local cursor = x0
				local function seg(a, b)
					if b - a > 0.05 then
						box(
							parent,
							name,
							frame * CFrame.new((a + b) / 2, (ya + yb) / 2, z),
							Vector3.new(b - a, yb - ya, thickness),
							band[3],
							band[4],
							extra
						)
					end
				end
				for _, c in open do
					seg(cursor, c[1])
					cursor = math.max(cursor, c[2])
				end
				seg(cursor, x1)
			end
		end
	end
end
TrainBuilder.holeyWall = holeyWall

-- Windows: a glass pane in each hole of the window band, with a brass sill and a dark header.
local function glass(parent, xa, xb, ya, yb, z, side)
	box(
		parent,
		"Window",
		CFrame.new((xa + xb) / 2, (ya + yb) / 2, z),
		Vector3.new(xb - xa, yb - ya, 0.25),
		C.glass,
		M.Glass,
		{
			Transparency = 0.6,
			CastShadow = false,
		}
	)
	box(
		parent,
		"Sill",
		CFrame.new((xa + xb) / 2, ya - 0.15, z + side * 0.35),
		Vector3.new(xb - xa + 0.6, 0.3, 0.6),
		C.brass,
		M.Metal,
		{ CastShadow = false }
	)
end

-- An outside door: two sliding leaves (green with a window), a status lamp over it inside and a beacon outside.
local function door(parent, d, doors)
	local x, z = d.x, HALF_OUT - 0.55
	local leaves = {}
	for i, side in { -1, 1 } do
		local w = Layout.DOOR_W / 2
		local closed = CFrame.new(x + side * w / 2, FLOOR + Layout.DOOR_H / 2, z)
		local open = closed * CFrame.new(side * (w - 0.3), 0, 0)
		local leaf = box(parent, "DoorLeaf", closed, Vector3.new(w, Layout.DOOR_H, 0.3), C.greenDark, M.SmoothPlastic)
		local pane =
			box(parent, "DoorPane", closed * CFrame.new(0, 2, 0.05), Vector3.new(w - 0.8, 2.6, 0.3), C.glass, M.Glass, {
				Transparency = 0.5,
				CanCollide = false,
				CastShadow = false,
			})
		leaves[i] = { part = leaf, closed = closed, open = open }
		leaves[i + 2] = { part = pane, closed = pane.CFrame, open = open * CFrame.new(0, 2, 0.05) }
	end
	-- the frame
	box(
		parent,
		"DoorFrame",
		CFrame.new(x, FLOOR + Layout.DOOR_H + 0.3, HALF_OUT - 0.3),
		Vector3.new(Layout.DOOR_W + 1, 0.6, 0.7),
		C.brass,
		M.Metal,
		{ CastShadow = false }
	)
	for _, side in { -1, 1 } do
		box(
			parent,
			"DoorFrame",
			CFrame.new(x + side * (Layout.DOOR_W / 2 + 0.25), FLOOR + Layout.DOOR_H / 2, HALF_OUT - 0.3),
			Vector3.new(0.5, Layout.DOOR_H, 0.7),
			C.brass,
			M.Metal,
			{ CastShadow = false }
		)
	end
	-- step plate on the sill
	box(
		parent,
		"DoorStep",
		CFrame.new(x, FLOOR - 0.05, HALF_OUT - 0.2),
		Vector3.new(Layout.DOOR_W, 0.3, 1.2),
		C.steel,
		M.DiamondPlate
	)
	-- lamp over the inside of the door (green: open, red: closing)
	local lamp = box(
		parent,
		"DoorLamp",
		CFrame.new(x, FLOOR + Layout.DOOR_H + 1.1, HALF_IN - 0.15),
		Vector3.new(2.2, 0.5, 0.3),
		C.iron,
		M.Neon,
		{ CastShadow = false, CanCollide = false }
	)
	local lampLight =
		Kit.light(lamp, "PointLight", { Range = 10, Brightness = 0, Color = Color3.fromRGB(90, 255, 120) })
	-- beacon outside, over the door: flashes amber during warnings (the client flashes it)
	local beacon = Kit.ball(
		parent,
		"DoorBeacon",
		Vector3.new(x, FLOOR + Layout.DOOR_H + 2.2, HALF_OUT + 0.3),
		1.1,
		Color3.fromRGB(255, 170, 40),
		M.Neon,
		{ CastShadow = false, CanCollide = false }
	)
	local beaconLight =
		Kit.light(beacon, "PointLight", { Range = 20, Brightness = 0, Color = Color3.fromRGB(255, 160, 40) })
	beacon:SetAttribute("Beacon", true)
	-- the opening itself is blocked while the doors are shut (an invisible plate, so nobody walks through a gap)
	local blocker = box(
		parent,
		"DoorBlock",
		CFrame.new(x, FLOOR + Layout.DOOR_H / 2, HALF_OUT - 0.55),
		Vector3.new(Layout.DOOR_W, Layout.DOOR_H, 0.4),
		C.black,
		M.SmoothPlastic,
		{
			Transparency = 1,
			CastShadow = false,
			CanQuery = false,
		}
	)
	local handle = {
		leaves = leaves,
		lamp = lamp,
		lampLight = lampLight,
		beacon = beacon,
		beaconLight = beaconLight,
		blocker = blocker,
		x = x,
	}
	table.insert(doors, handle)
	return handle
end

-- Two bogies with wheels under a car, buffers at the ends.
local function underframe(parent, car)
	for _, side in { -1, 1 } do
		local bx = car.cx + side * (car.length / 2 - 10)
		box(parent, "Bogie", CFrame.new(bx, 2.35, 0), Vector3.new(9, 1, 13), C.iron, M.Metal)
		for _, ax in { -2.4, 2.4 } do
			for _, wz in { -2.9, 2.9 } do
				cyl(
					parent,
					"Wheel",
					CFrame.new(bx + ax, 1.9, wz) * CFrame.Angles(0, math.rad(90), 0),
					0.6,
					2.6,
					C.iron,
					M.Metal
				)
				cyl(
					parent,
					"Hub",
					CFrame.new(bx + ax, 1.9, wz + (wz > 0 and 0.35 or -0.35)) * CFrame.Angles(0, math.rad(90), 0),
					0.15,
					1.6,
					C.wheel,
					M.Metal,
					{ CastShadow = false }
				)
			end
		end
		box(
			parent,
			"Spring",
			CFrame.new(bx, 2.6, 6.8 * 1),
			Vector3.new(6, 0.8, 0.6),
			C.steel,
			M.Metal,
			{ CastShadow = false }
		)
		box(
			parent,
			"Spring",
			CFrame.new(bx, 2.6, -6.8),
			Vector3.new(6, 0.8, 0.6),
			C.steel,
			M.Metal,
			{ CastShadow = false }
		)
	end
	box(parent, "Underframe", CFrame.new(car.cx, 3.15, 0), Vector3.new(car.length - 2, 0.5, 20), C.iron, M.Metal)
	-- equipment boxes between the bogies
	for _, x in { -6, 6 } do
		box(
			parent,
			"Battery",
			CFrame.new(car.cx + x, 2.4, 7),
			Vector3.new(7, 1.3, 3),
			C.iron,
			M.Metal,
			{ CastShadow = false }
		)
	end
end

-- Floor, roof and the two end walls (with the gangway opening) for any car.
local function shell(parent, car, opts)
	local x0, x1 = car.x0, car.x1
	-- floor slab
	box(
		parent,
		"FloorSlab",
		CFrame.new(car.cx, FLOOR - 0.4, 0),
		Vector3.new(car.length, 0.8, Layout.CAR_W),
		C.iron,
		M.Metal
	)
	-- ceiling (cream, warm) and roof (dark, rounded shoulders)
	box(
		parent,
		"Ceiling",
		CFrame.new(car.cx, CEIL + 0.25, 0),
		Vector3.new(car.length - 0.2, 0.5, Layout.CAR_W - 1),
		opts.ceiling or C.cream,
		M.SmoothPlastic
	)
	box(
		parent,
		"Roof",
		CFrame.new(car.cx, ROOF - 0.5, 0),
		Vector3.new(car.length, 1, Layout.CAR_W - 7),
		C.roof,
		M.Metal
	)
	for _, side in { -1, 1 } do
		wedge(
			parent,
			"RoofShoulder",
			CFrame.new(car.cx, CEIL + 1.55, side * (HALF_OUT - 1.8)) * CFrame.Angles(0, side > 0 and math.pi or 0, 0),
			Vector3.new(car.length, 2.1, 3.6),
			C.roof,
			M.Metal
		)
		box(
			parent,
			"Gutter",
			CFrame.new(car.cx, CEIL + 0.55, side * (HALF_OUT - 0.1)),
			Vector3.new(car.length, 0.3, 0.4),
			C.brassDark,
			M.Metal,
			{ CastShadow = false }
		)
	end
	-- roof vents
	for i = -2, 2 do
		box(
			parent,
			"Vent",
			CFrame.new(car.cx + i * (car.length / 6), ROOF + 0.25, 0),
			Vector3.new(2.4, 0.6, 3),
			C.iron,
			M.Metal,
			{ CastShadow = false }
		)
	end
	-- end walls with a gangway opening in the middle (the locomotive's front is closed)
	for _, e in { { x1, 1 }, { x0, -1 } } do
		local ex, dir = e[1], e[2]
		local holes = {}
		if not (car.kind == "loco" and dir > 0) then
			holes = { { -2.5, 2.5, FLOOR, FLOOR + 9 } }
		end
		-- end walls are planes of constant x: holeyWall in a frame turned 90 degrees
		holeyWall(parent, "EndWall", -HALF_OUT + 0.3, HALF_OUT - 0.3, 0, 0.8, {
			{ FLOOR - 0.6, CEIL + 0.6, opts.endColor or C.greenDark, M.SmoothPlastic },
		}, holes, nil, CFrame.new(ex - dir * 0.4, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
		-- inside face: wood
		holeyWall(
			parent,
			"EndPanel",
			-HALF_IN,
			HALF_IN,
			0,
			0.2,
			{ { FLOOR, CEIL, C.wood, M.Wood } },
			holes,
			nil,
			CFrame.new(ex - dir * 0.9, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
		)
		-- buffers and gangway bellows toward the next car
		if not (car.kind == "loco" and dir > 0) and ex > Layout.BACK_X + 0.5 then
			local gx = ex - Layout.GAP / 2
			if dir < 0 then
				-- the gangway: floor plate, bellows walls and a roof, bridging to the next car
				box(
					parent,
					"GangwayFloor",
					CFrame.new(gx, FLOOR - 0.1, 0),
					Vector3.new(Layout.GAP + 0.6, 0.4, 6),
					C.steel,
					M.DiamondPlate
				)
				for _, side in { -1, 1 } do
					box(
						parent,
						"Bellows",
						CFrame.new(gx, FLOOR + 4.6, side * 3.2),
						Vector3.new(Layout.GAP + 0.4, 9.4, 0.6),
						C.black,
						M.Fabric
					)
				end
				box(
					parent,
					"Bellows",
					CFrame.new(gx, FLOOR + 9.5, 0),
					Vector3.new(Layout.GAP + 0.4, 0.6, 7),
					C.black,
					M.Fabric
				)
			end
			for _, z in { -8, 8 } do
				cyl(
					parent,
					"Buffer",
					CFrame.new(ex + dir * 0.4, 3.6, z),
					1.2,
					1.2,
					C.steel,
					M.Metal,
					{ CastShadow = false }
				)
			end
		end
	end
end

-- The two long sides of a car: exterior bands and an inner wood layer, with windows and door holes.
local function sides(parent, car, holesPlus, holesMinus)
	for _, s in { { HALF_OUT - 0.3, holesPlus, 1 }, { -(HALF_OUT - 0.3), holesMinus, -1 } } do
		local z, holes, side = s[1], s[2], s[3]
		holeyWall(parent, "Side", car.x0, car.x1, z, 0.6, BANDS, holes)
		holeyWall(parent, "Panel", car.x0 + 0.9, car.x1 - 0.9, side * (HALF_IN + 0.25), 0.3, {
			{ FLOOR, 7.6, C.woodDark, M.Wood },
			{ 7.6, 8.3, C.brassDark, M.Metal },
			{ 8.3, CEIL, C.wood, M.WoodPlanks },
		}, holes)
		for _, h in holes do
			if h[5] == true then -- (the 5th entry marks a window)
				glass(parent, h[1], h[2], h[3], h[4], side * (HALF_OUT - 0.4), side)
			end
		end
	end
end

local function window(xa, xb)
	return { xa, xb, 8.7, 12.6, true }
end

local function doorHole(x)
	return { x - Layout.DOOR_W / 2, x + Layout.DOOR_W / 2, FLOOR, FLOOR + Layout.DOOR_H }
end

-- Side lettering: the train's name in brass on the green band, and the car name.
local function lettering(parent, _car, text, x)
	local plate = box(
		parent,
		"Lettering",
		CFrame.new(x, 15.2, HALF_OUT + 0.02),
		Vector3.new(16, 1.6, 0.1),
		C.green,
		M.SmoothPlastic,
		{ CastShadow = false, CanCollide = false }
	)
	Kit.text(plate, Enum.NormalId.Back, text, { color = C.brass, font = Enum.Font.Oswald, ppu = 30 })
	-- Back face points at +Z for this part's orientation (CFrame has no rotation; Back = +Z)
	return plate
end

-- Ceiling lamps down a strip of the car (warm neon + light).
local function ceilingLamps(parent, car, z, every, lights)
	local n = math.floor((car.length - 8) / every)
	for i = 0, n do
		local x = car.x0 + 4 + i * every + ((car.length - 8) - n * every) / 2
		local fixture = box(
			parent,
			"LampFixture",
			CFrame.new(x, CEIL - 0.25, z),
			Vector3.new(1.8, 0.5, 1.8),
			C.brass,
			M.Metal,
			{ CastShadow = false, CanCollide = false }
		)
		local glow = box(
			parent,
			"LampGlow",
			CFrame.new(x, CEIL - 0.6, z),
			Vector3.new(1.3, 0.3, 1.3),
			C.warm,
			M.Neon,
			{ CastShadow = false, CanCollide = false }
		)
		local l = Kit.light(glow, "PointLight", { Range = 15, Brightness = 1.4, Color = C.warm })
		table.insert(lights, l)
		_ = fixture
	end
end

-- A cabin car: corridor along -Z, four cabins on the +Z side, vestibules with doors at both ends.
local function cabinCar(parent, car, out)
	local model = Kit.model(car.key, parent)
	local doorXs = { car.x1 - Layout.VESTIBULE / 2, car.x0 + Layout.VESTIBULE / 2 }
	local plus = { doorHole(doorXs[1]), doorHole(doorXs[2]) }
	for _, cabin in car.cabins do
		local cx = cabin.center.X
		table.insert(plus, window(cx - 4.2, cx + 4.2))
	end
	local minus = {}
	for i = 0, 6 do
		local x = car.x0 + Layout.VESTIBULE + 4 + i * 8.6
		if x + 2.5 < car.x1 - Layout.VESTIBULE then
			table.insert(minus, window(x - 2.4, x + 2.4))
		end
	end
	underframe(model, car)
	shell(model, car, {})
	sides(model, car, plus, minus)
	for _, x in doorXs do
		door(model, { x = x }, out.doors)
	end
	-- floors: diamond plate in the vestibules, a red runner down the corridor
	for _, x in doorXs do
		box(
			model,
			"VestibuleFloor",
			CFrame.new(x, FLOOR + 0.05, 0),
			Vector3.new(Layout.VESTIBULE - 0.2, 0.1, HALF_IN * 2),
			C.steel,
			M.DiamondPlate
		)
	end
	local corridorLen = car.length - Layout.VESTIBULE * 2
	box(
		model,
		"CorridorFloor",
		CFrame.new(car.cx, FLOOR + 0.05, (Layout.CORRIDOR_Z - HALF_IN) / 2),
		Vector3.new(corridorLen, 0.1, HALF_IN + Layout.CORRIDOR_Z),
		C.woodDark,
		M.WoodPlanks
	)
	box(
		model,
		"Runner",
		CFrame.new(car.cx, FLOOR + 0.12, (Layout.CORRIDOR_Z - HALF_IN) / 2),
		Vector3.new(corridorLen - 1, 0.05, 3),
		C.carpet,
		M.Carpet,
		{ CastShadow = false }
	)
	-- the corridor wall: wood panels with a doorway into each cabin
	local holes = {}
	for _, cabin in car.cabins do
		local cx = cabin.center.X
		table.insert(holes, { cx - 2.25, cx + 2.25, FLOOR, FLOOR + 8.6 })
	end
	local x0, x1 = car.x0 + Layout.VESTIBULE, car.x1 - Layout.VESTIBULE
	holeyWall(model, "CorridorWall", x0, x1, Layout.CORRIDOR_Z - 0.2, 0.4, {
		{ FLOOR, 7.6, C.woodDark, M.Wood },
		{ 7.6, 8.1, C.brassDark, M.Metal },
		{ 8.1, CEIL, C.wood, M.WoodPlanks },
	}, holes)
	-- end walls of the cabin section (to the vestibules)
	for _, x in { x0, x1 } do
		box(
			model,
			"SectionWall",
			CFrame.new(x, (FLOOR + CEIL) / 2, (Layout.CORRIDOR_Z + HALF_IN) / 2),
			Vector3.new(0.6, CEIL - FLOOR, HALF_IN - Layout.CORRIDOR_Z),
			C.wood,
			M.Wood
		)
	end
	-- dividers between cabins
	for j = 1, 3 do
		local x = car.x1 - Layout.VESTIBULE - j * Layout.CABIN_LEN
		box(
			model,
			"Divider",
			CFrame.new(x, (FLOOR + CEIL) / 2, (Layout.CORRIDOR_Z + HALF_IN) / 2),
			Vector3.new(0.6, CEIL - FLOOR, HALF_IN - Layout.CORRIDOR_Z),
			C.woodDark,
			M.Wood
		)
	end
	ceilingLamps(model, { x0 = x0, length = x1 - x0 }, (Layout.CORRIDOR_Z - HALF_IN) / 2, 9, out.lights)
	-- car sign over each corridor end, and the side lettering
	local first, last = car.cabins[1].number, car.cabins[#car.cabins].number
	for _, x in { x0 + 0.35, x1 - 0.35 } do
		local sign = box(
			model,
			"CarSign",
			CFrame.new(x, FLOOR + 10.2, (Layout.CORRIDOR_Z - HALF_IN) / 2),
			Vector3.new(0.2, 1.6, 5),
			C.greenDark,
			M.SmoothPlastic,
			{ CastShadow = false }
		)
		local face = x < car.cx and Enum.NormalId.Left or Enum.NormalId.Right
		Kit.text(sign, face, `{string.upper(car.name)} · CABINS {first}–{last}`, { color = C.brass, ppu = 40 })
	end
	lettering(model, car, "THE LAST TRAIN", car.cx)
	local num = box(
		model,
		"CarNumber",
		CFrame.new(car.x1 - 9, 15.2, HALF_OUT + 0.02),
		Vector3.new(4, 1.6, 0.1),
		C.green,
		M.SmoothPlastic,
		{ CastShadow = false, CanCollide = false }
	)
	Kit.text(num, Enum.NormalId.Back, car.key, { color = C.brass, ppu = 30 })
	-- the cabins
	for _, cabin in car.cabins do
		out.cabins[cabin.index] = TrainBuilder.cabin(model, cabin, out)
	end
	return model
end

-- One cabin's shell: finishable floor and walls, ceiling, curtains, door sign and the bare starting things.
function TrainBuilder.cabin(parent, cabin, _out)
	local model = Kit.model("Cabin" .. cabin.index, parent)
	local cf = cabin.cf
	local L, D = Layout.CABIN_LEN, HALF_IN - Layout.CORRIDOR_Z -- 14 x 18
	local hx, hz = L / 2 - 0.3, D / 2
	local shellParts = {}
	local function finishPart(name, lcf, size, role)
		local p = box(model, name, cf * lcf, size, C.wood, M.SmoothPlastic, { CastShadow = false })
		p:SetAttribute("Role", role)
		table.insert(shellParts, p)
		return p
	end
	finishPart("Floor", CFrame.new(0, 0.1, 0), Vector3.new(L - 0.6, 0.12, D - 0.2), "floor")
	for _, side in { -1, 1 } do
		finishPart(
			"SideWall",
			CFrame.new(side * (hx - 0.1), (CEIL - FLOOR) / 2, 0),
			Vector3.new(0.12, CEIL - FLOOR - 0.2, D - 0.4),
			"wall"
		)
	end
	-- window wall (inside face) around the window
	local wz = hz - 0.55
	finishPart("WindowWall", CFrame.new(0, 2.35, wz), Vector3.new(L - 0.8, 4.5, 0.12), "wall")
	finishPart("WindowWall", CFrame.new(0, 11, wz), Vector3.new(L - 0.8, 4.4, 0.12), "wall")
	for _, side in { -1, 1 } do
		finishPart("WindowWall", CFrame.new(side * 5.55, 6.65, wz), Vector3.new(2.3, 4.1, 0.12), "wall")
	end
	-- door wall (inside face) around the doorway
	local dz = -hz + 0.35
	for _, side in { -1, 1 } do
		finishPart(
			"DoorWall",
			CFrame.new(side * 4.65, (CEIL - FLOOR) / 2, dz),
			Vector3.new(4.8, CEIL - FLOOR - 0.2, 0.12),
			"wall"
		)
	end
	finishPart("DoorWall", CFrame.new(0, 10.8, dz), Vector3.new(4.6, 4.4, 0.12), "wall")
	-- trim: a brass chair rail all round
	for _, side in { -1, 1 } do
		box(
			model,
			"Trim",
			cf * CFrame.new(side * (hx - 0.2), 4.2, 0),
			Vector3.new(0.15, 0.25, D - 0.5),
			C.brassDark,
			M.Metal,
			{ CastShadow = false }
		)
	end
	-- curtains (cabin colour)
	local colorParts = {}
	for _, side in { -1, 1 } do
		local c = box(
			model,
			"Curtain",
			cf * CFrame.new(side * 4.9, 6.9, wz - 0.25),
			Vector3.new(1.4, 5, 0.2),
			C.cream,
			M.Fabric,
			{ CastShadow = false, CanCollide = false }
		)
		table.insert(colorParts, c)
	end
	box(
		model,
		"CurtainRod",
		cf * CFrame.new(0, 9.6, wz - 0.25),
		Vector3.new(11, 0.18, 0.18),
		C.brass,
		M.Metal,
		{ CastShadow = false, CanCollide = false }
	)
	-- the door sign in the corridor
	local plate = box(
		parent,
		"DoorPlate",
		cabin.plateCf,
		Vector3.new(3.2, 1.4, 0.15),
		C.greenDark,
		M.SmoothPlastic,
		{ CastShadow = false, CanCollide = false }
	)
	local plateText = Kit.text(plate, Enum.NormalId.Front, `{cabin.number} · VACANT`, { color = C.cream, ppu = 50 })
	local plateTrim = box(
		parent,
		"DoorPlateTrim",
		cabin.plateCf * CFrame.new(0, 0, 0.05),
		Vector3.new(3.5, 1.7, 0.1),
		C.brass,
		M.Metal,
		{ CastShadow = false, CanCollide = false }
	)
	table.insert(colorParts, plate)
	-- the bare things you start with: a bedroll, a dim bulb, a cardboard box (CabinBuilder swaps them out)
	local bare = Kit.folder("Bare", model)
	local bedroll = box(
		bare,
		"Bedroll",
		cf * CFrame.new(2.6, 0.35, 6.8),
		Vector3.new(7, 0.5, 3),
		C.cream:Lerp(C.dirt, 0.3),
		M.Fabric
	)
	box(
		bare,
		"Pillow",
		cf * CFrame.new(5.4, 0.75, 6.8),
		Vector3.new(1.4, 0.5, 2.4),
		C.cream,
		M.Fabric,
		{ CastShadow = false }
	)
	table.insert(colorParts, bedroll)
	local bulb = Kit.ball(
		bare,
		"DimBulb",
		cf.Position + Vector3.new(0, CEIL - FLOOR - 2, 0),
		0.6,
		C.warm,
		M.Neon,
		{ CastShadow = false, CanCollide = false }
	)
	Kit.light(bulb, "PointLight", { Range = 12, Brightness = 0.7, Color = C.warm })
	box(
		bare,
		"Wire",
		cf * CFrame.new(0, CEIL - FLOOR - 0.95, 0),
		Vector3.new(0.08, 1.6, 0.08),
		C.black,
		M.SmoothPlastic,
		{ CastShadow = false, CanCollide = false }
	)
	box(
		bare,
		"Box",
		cf * CFrame.new(-5.2, 0.9, -7.4),
		Vector3.new(2.2, 1.6, 2),
		Color3.fromRGB(176, 140, 96),
		M.Cardboard
	)
	local items = Kit.folder("Items", model)
	return {
		index = cabin.index,
		model = model,
		cf = cf,
		shell = shellParts,
		color = colorParts,
		plate = plateText,
		plateTrim = plateTrim,
		bare = bare,
		items = items,
	}
end

-- The crew car: entry seats, the crew board, a navigation table and a shared workshop corner.
local function crewCar(parent, car, out)
	local model = Kit.model(car.key, parent)
	local doorXs = { car.x1 - Layout.VESTIBULE / 2, car.x0 + Layout.VESTIBULE / 2 }
	local plus = { doorHole(doorXs[1]), doorHole(doorXs[2]) }
	local minus = {}
	for i = 0, 5 do
		local x = car.x0 + 12 + i * 8
		table.insert(plus, window(x - 2.6, x + 2.6))
		if math.abs(x - car.cx) > 10 then -- the crew board hangs on the -Z wall in the middle
			table.insert(minus, window(x - 2.6, x + 2.6))
		end
	end
	-- the crew board window gap on -Z (the board hangs there)
	underframe(model, car)
	shell(model, car, {})
	sides(model, car, plus, minus)
	for _, x in doorXs do
		door(model, { x = x }, out.doors)
	end
	box(
		model,
		"Floor",
		CFrame.new(car.cx, FLOOR + 0.05, 0),
		Vector3.new(car.length - 1.8, 0.1, HALF_IN * 2),
		C.woodDark,
		M.WoodPlanks
	)
	box(
		model,
		"Rug",
		CFrame.new(car.cx, FLOOR + 0.12, 0),
		Vector3.new(car.length - 16, 0.05, 8),
		C.carpet,
		M.Carpet,
		{ CastShadow = false }
	)
	ceilingLamps(model, car, 0, 10, out.lights)
	-- entry seats: two facing benches near the rear door (where late joiners arrive)
	local seatX = car.x0 + 16
	for _, dx in { -3.2, 3.2 } do
		local m = Kit.model("EntrySeat", model)
		box(m, "SeatBase", CFrame.new(seatX + dx, FLOOR + 1.1, -7), Vector3.new(2.6, 2.2, 8), C.woodDark, M.Wood)
		box(m, "Cushion", CFrame.new(seatX + dx, FLOOR + 2.35, -7), Vector3.new(2.4, 0.4, 7.6), C.carpet, M.Fabric)
		box(
			m,
			"Back",
			CFrame.new(seatX + dx + (dx > 0 and 1.1 or -1.1), FLOOR + 4, -7),
			Vector3.new(0.5, 3.6, 7.6),
			C.carpet,
			M.Fabric
		)
	end
	box(model, "EntryTable", CFrame.new(seatX, FLOOR + 2.6, -9.5), Vector3.new(3, 0.3, 3), C.wood, M.Wood)
	local entrySign = box(
		model,
		"EntrySign",
		CFrame.new(seatX, FLOOR + 8.8, -HALF_IN + 0.3),
		Vector3.new(6, 1.4, 0.2),
		C.greenDark,
		M.SmoothPlastic,
		{ CastShadow = false }
	)
	Kit.text(entrySign, Enum.NormalId.Back, "WELCOME ABOARD", { color = C.brass })
	-- the crew board: what the crew is doing (ExpeditionService writes it)
	local board = box(model, "CrewBoard", Layout.CREW_BOARD_CF, Vector3.new(14, 6.5, 0.4), C.black, M.SmoothPlastic)
	box(
		model,
		"CrewBoardFrame",
		Layout.CREW_BOARD_CF * CFrame.new(0, 0, -0.1),
		Vector3.new(14.8, 7.3, 0.3),
		C.brass,
		M.Metal
	)
	local boardText = Kit.text(
		board,
		Enum.NormalId.Back,
		"THE LAST TRAIN",
		{ color = C.cream, font = Enum.Font.Oswald, ppu = 30, align = Enum.TextXAlignment.Left }
	)
	boardText.TextYAlignment = Enum.TextYAlignment.Top
	boardText.TextScaled = false
	boardText.TextSize = 26
	out.crewBoard = boardText
	-- navigation table with a map (it lights up with the Searchlight)
	local navX = car.cx + 6
	box(model, "NavTable", CFrame.new(navX, FLOOR + 2.4, 4), Vector3.new(7, 0.5, 4.5), C.woodDark, M.Wood)
	for _, dx in { -3, 3 } do
		for _, dz in { -1.8, 1.8 } do
			box(
				model,
				"NavLeg",
				CFrame.new(navX + dx, FLOOR + 1.1, 4 + dz),
				Vector3.new(0.4, 2.2, 0.4),
				C.woodDark,
				M.Wood,
				{ CastShadow = false }
			)
		end
	end
	local map = box(
		model,
		"NavMap",
		CFrame.new(navX, FLOOR + 2.7, 4),
		Vector3.new(6, 0.08, 3.8),
		Color3.fromRGB(214, 196, 150),
		M.SmoothPlastic,
		{ CastShadow = false }
	)
	out.navMap = map
	local navLamp =
		Kit.bulb(model, "NavLamp", Vector3.new(navX, FLOOR + 7.5, 4), 0.8, Color3.fromRGB(150, 210, 255), 12, 0)
	out.navLamp = navLamp
	-- shared workshop corner near the front door
	local wx = car.x1 - 14
	box(model, "Workbench", CFrame.new(wx, FLOOR + 2.1, 9.5), Vector3.new(8, 0.6, 3.6), C.wood, M.Wood)
	box(model, "WorkbenchBase", CFrame.new(wx, FLOOR + 1, 9.5), Vector3.new(7.6, 2, 3.2), C.woodDark, M.Wood)
	box(
		model,
		"Vise",
		CFrame.new(wx - 2.5, FLOOR + 2.8, 9),
		Vector3.new(1, 0.9, 1.2),
		C.steel,
		M.Metal,
		{ CastShadow = false }
	)
	box(
		model,
		"Toolboard",
		CFrame.new(wx, FLOOR + 6.5, HALF_IN - 0.3),
		Vector3.new(7, 4, 0.2),
		C.woodLight,
		M.WoodPlanks,
		{ CastShadow = false }
	)
	for i = -2, 2 do
		box(
			model,
			"Tool",
			CFrame.new(wx + i * 1.3, FLOOR + 6.5, HALF_IN - 0.5),
			Vector3.new(0.25, 2.4, 0.2),
			i % 2 == 0 and C.steel or C.wheel,
			M.Metal,
			{ CastShadow = false, CanCollide = false }
		)
	end
	lettering(model, car, "CREW CAR", car.cx)
	-- the radio mast on the roof (Scout Lamp stage 2)
	local mast = Kit.model("RadioMast", model)
	disc(mast, "Mast", Vector3.new(car.cx - 10, ROOF + 7, -4), 0.5, 14, C.steel, M.Metal)
	for i = 1, 3 do
		box(
			mast,
			"Spar",
			CFrame.new(car.cx - 10, ROOF + 4 + i * 3, -4),
			Vector3.new(0.25, 0.25, 6 - i),
			C.steel,
			M.Metal,
			{ CastShadow = false }
		)
	end
	local tip = Kit.ball(
		mast,
		"MastLight",
		Vector3.new(car.cx - 10, ROOF + 14.3, -4),
		0.7,
		C.signal,
		M.Neon,
		{ CastShadow = false }
	)
	tip:SetAttribute("Blink", true)
	out.lampStages[2] = mast
	return model
end

-- The locomotive: boiler, chimney, headlamp and cab up front; the engine room behind (where the Engine Overhaul
-- shows), with the fuel gauge and the train upgrades board.
local function loco(parent, car, out)
	local model = Kit.model(car.key, parent)
	local roomX1 = car.x1 - 30 -- the engine room runs from x0 to here; the cab and boiler are in front
	local cabX0, cabX1 = roomX1, roomX1 + 9
	local frontX = car.x1
	-- engine room body (same profile as the coaches)
	local roomCar = { x0 = car.x0, x1 = roomX1, cx = (car.x0 + roomX1) / 2, length = roomX1 - car.x0, kind = "room" }
	underframe(model, car)
	local plus = { doorHole(car.x0 + 4) }
	local minus = {}
	for i = 0, 2 do
		local x = car.x0 + 12 + i * 7
		table.insert(plus, window(x - 2, x + 2))
		if math.abs(x - Layout.UPGRADE_BOARD_CF.Position.X) > 8.5 then -- the upgrades board hangs on the -Z wall
			table.insert(minus, window(x - 2, x + 2))
		end
	end
	sides(model, roomCar, plus, minus)
	door(model, { x = car.x0 + 4 }, out.doors)
	box(
		model,
		"FloorSlab",
		CFrame.new(car.cx, FLOOR - 0.4, 0),
		Vector3.new(car.length, 0.8, Layout.CAR_W),
		C.iron,
		M.Metal
	)
	box(
		model,
		"RoomFloor",
		CFrame.new(roomCar.cx, FLOOR + 0.05, 0),
		Vector3.new(roomCar.length - 1.8, 0.1, HALF_IN * 2),
		C.steel,
		M.DiamondPlate
	)
	box(
		model,
		"Ceiling",
		CFrame.new(roomCar.cx, CEIL + 0.25, 0),
		Vector3.new(roomCar.length - 0.2, 0.5, Layout.CAR_W - 1),
		C.concreteDark,
		M.Metal
	)
	box(
		model,
		"Roof",
		CFrame.new(roomCar.cx, ROOF - 0.5, 0),
		Vector3.new(roomCar.length, 1, Layout.CAR_W - 7),
		C.roof,
		M.Metal
	)
	for _, side in { -1, 1 } do
		wedge(
			model,
			"RoofShoulder",
			CFrame.new(roomCar.cx, CEIL + 1.55, side * (HALF_OUT - 1.8))
				* CFrame.Angles(0, side > 0 and math.pi or 0, 0),
			Vector3.new(roomCar.length, 2.1, 3.6),
			C.roof,
			M.Metal
		)
	end
	-- rear end wall with the gangway hole
	holeyWall(
		model,
		"EndWall",
		-HALF_OUT + 0.3,
		HALF_OUT - 0.3,
		0,
		0.8,
		{ { FLOOR - 0.6, CEIL + 0.6, C.greenDark, M.SmoothPlastic } },
		{ { -2.5, 2.5, FLOOR, FLOOR + 9 } },
		nil,
		CFrame.new(car.x0 + 0.4, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	)
	holeyWall(
		model,
		"EndPanel",
		-HALF_IN,
		HALF_IN,
		0,
		0.2,
		{ { FLOOR, CEIL, C.iron, M.Metal } },
		{ { -2.5, 2.5, FLOOR, FLOOR + 9 } },
		nil,
		CFrame.new(car.x0 + 0.9, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	)
	for _, z in { -8, 8 } do
		cyl(model, "Buffer", CFrame.new(car.x0 - 0.4, 3.6, z), 1.2, 1.2, C.steel, M.Metal, { CastShadow = false })
	end
	-- wall between the engine room and the cab, with a doorway
	holeyWall(
		model,
		"CabWall",
		-HALF_IN,
		HALF_IN,
		0,
		0.6,
		{ { FLOOR, CEIL, C.iron, M.Metal } },
		{ { -2.2, 2.2, FLOOR, FLOOR + 8 } },
		nil,
		CFrame.new(cabX0, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	)

	-- the cab: a taller box with big front windows looking over the boiler
	local cabLen = cabX1 - cabX0
	local cabCx = (cabX0 + cabX1) / 2
	holeyWall(model, "CabSide", cabX0, cabX1, HALF_OUT - 0.3, 0.6, BANDS, { window(cabX0 + 1.5, cabX1 - 1.5) })
	holeyWall(model, "CabSide", cabX0, cabX1, -(HALF_OUT - 0.3), 0.6, BANDS, { window(cabX0 + 1.5, cabX1 - 1.5) })
	glass(model, cabX0 + 1.5, cabX1 - 1.5, 8.7, 12.6, HALF_OUT - 0.4, 1)
	glass(model, cabX0 + 1.5, cabX1 - 1.5, 8.7, 12.6, -(HALF_OUT - 0.4), -1)
	box(
		model,
		"CabFloor",
		CFrame.new(cabCx, FLOOR + 0.05, 0),
		Vector3.new(cabLen - 0.6, 0.1, HALF_IN * 2),
		C.woodDark,
		M.WoodPlanks
	)
	box(
		model,
		"CabRoof",
		CFrame.new(cabCx, ROOF + 0.4, 0),
		Vector3.new(cabLen + 2, 1, Layout.CAR_W + 1),
		C.roof,
		M.Metal
	)
	box(
		model,
		"CabCeiling",
		CFrame.new(cabCx, CEIL + 0.25, 0),
		Vector3.new(cabLen, 0.5, Layout.CAR_W - 1),
		C.woodDark,
		M.Wood
	)
	holeyWall(
		model,
		"CabFront",
		-HALF_OUT + 0.3,
		HALF_OUT - 0.3,
		0,
		0.6,
		BANDS,
		{ { -10, -3, 9.5, 13.5, true }, { 3, 10, 9.5, 13.5, true } },
		nil,
		CFrame.new(cabX1 - 0.3, 0, 0) * CFrame.Angles(0, math.rad(90), 0)
	)
	for _, z in { -6.5, 6.5 } do
		box(
			model,
			"Windscreen",
			CFrame.new(cabX1 - 0.3, 11.5, z),
			Vector3.new(0.25, 4, 7),
			C.glass,
			M.Glass,
			{ Transparency = 0.55, CastShadow = false }
		)
	end
	-- driver's controls
	box(model, "Controls", CFrame.new(cabX1 - 2, FLOOR + 2.4, -5), Vector3.new(2.4, 4.8, 6), C.iron, M.Metal)
	for i = 0, 2 do
		local gauge = box(
			model,
			"Gauge",
			CFrame.new(cabX1 - 3.25, FLOOR + 4.2, -7 + i * 2),
			Vector3.new(0.1, 1.2, 1.2),
			Color3.fromRGB(255, 236, 190),
			M.Neon,
			{ CastShadow = false }
		)
		_ = gauge
	end
	box(
		model,
		"Lever",
		CFrame.new(cabX1 - 3.4, FLOOR + 5.6, -3.4) * CFrame.Angles(0, 0, math.rad(20)),
		Vector3.new(0.25, 2.4, 0.25),
		C.brass,
		M.Metal,
		{ CastShadow = false }
	)

	-- the boiler: a long green cylinder with brass bands, smokebox, chimney and dome
	local bx0, bx1 = cabX1, frontX - 2
	local boilerCx = (bx0 + bx1) / 2
	local bl = bx1 - bx0
	box(
		model,
		"Running",
		CFrame.new(boilerCx, FLOOR + 0.2, 0),
		Vector3.new(bl + 2, 0.4, Layout.CAR_W - 2),
		C.iron,
		M.Metal
	)
	cyl(model, "Boiler", CFrame.new(boilerCx, 10, 0), bl, 13, C.green, M.SmoothPlastic)
	for i = 1, 4 do
		cyl(
			model,
			"BoilerBand",
			CFrame.new(bx0 + i * bl / 5, 10, 0),
			0.5,
			13.3,
			C.brass,
			M.Metal,
			{ CastShadow = false }
		)
	end
	cyl(model, "Smokebox", CFrame.new(bx1 - 2.5, 10, 0), 5, 13.4, C.iron, M.Metal)
	cyl(model, "SmokeboxDoor", CFrame.new(bx1 + 0.1, 10, 0), 0.6, 11, C.black, M.Metal)
	-- the headlamp: big brass lamp with a spotlight down the line
	cyl(model, "Headlamp", CFrame.new(bx1 + 0.9, 16, 0), 2, 3.4, C.brass, M.Metal)
	local lens = cyl(
		model,
		"HeadlampLens",
		CFrame.new(bx1 + 1.95, 16, 0),
		0.2,
		2.8,
		Color3.fromRGB(255, 246, 214),
		M.Neon,
		{ CastShadow = false }
	)
	Kit.light(
		lens,
		"SpotLight",
		{ Face = Enum.NormalId.Right, Range = 60, Angle = 50, Brightness = 4, Color = Color3.fromRGB(255, 240, 200) }
	)
	-- chimney and dome
	disc(model, "Chimney", Vector3.new(bx1 - 4, 18.5, 0), 3, 5, C.black, M.Metal)
	disc(model, "ChimneyLip", Vector3.new(bx1 - 4, 21.1, 0), 3.8, 0.6, C.black, M.Metal)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(200, 196, 190))
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Lifetime = NumberRange.new(3, 5)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(6, 10)
	smoke.EmissionDirection = Enum.NormalId.Top
	local smokeAt = box(
		model,
		"SmokeOut",
		CFrame.new(bx1 - 4, 21.5, 0),
		Vector3.new(1, 0.2, 1),
		C.black,
		M.SmoothPlastic,
		{ Transparency = 1, CanCollide = false, CastShadow = false }
	)
	smoke.Parent = smokeAt
	out.smoke = smoke
	disc(model, "Dome", Vector3.new(boilerCx - 2, 17.2, 0), 3.4, 2.4, C.brass, M.Metal)
	Kit.ball(model, "DomeTop", Vector3.new(boilerCx - 2, 18.3, 0), 3.4, C.brass, M.Metal)
	-- cowcatcher, buffer beam and front plate
	box(
		model,
		"BufferBeam",
		CFrame.new(frontX - 0.5, 3.6, 0),
		Vector3.new(1.2, 2, Layout.CAR_W - 4),
		C.wheel,
		M.SmoothPlastic
	)
	wedge(
		model,
		"Cowcatcher",
		CFrame.new(frontX + 1.2, 1.6, 0) * CFrame.Angles(0, math.rad(-90), 0),
		Vector3.new(Layout.CAR_W - 6, 2.6, 3.4),
		C.wheel,
		M.Metal
	)
	for _, z in { -8, 8 } do
		cyl(model, "Buffer", CFrame.new(frontX + 0.4, 3.6, z), 1.2, 1.2, C.steel, M.Metal, { CastShadow = false })
	end
	local plate = box(
		model,
		"FrontPlate",
		CFrame.new(bx1 + 0.45, 10, 0),
		Vector3.new(0.1, 2.2, 6),
		C.brass,
		M.Metal,
		{ CastShadow = false, CanCollide = false }
	)
	Kit.text(plate, Enum.NormalId.Right, "LT · 01", { color = C.black, ppu = 30 })
	-- big driving wheels along the boiler (classic red spokes)
	for i = 0, 2 do
		for _, wz in { -5.2, 5.2 } do
			cyl(
				model,
				"DriveWheel",
				CFrame.new(bx0 + 4 + i * 6, 3, wz) * CFrame.Angles(0, math.rad(90), 0),
				0.8,
				5.4,
				C.wheel,
				M.Metal
			)
			cyl(
				model,
				"DriveHub",
				CFrame.new(bx0 + 4 + i * 6, 3, wz + (wz > 0 and 0.5 or -0.5)) * CFrame.Angles(0, math.rad(90), 0),
				0.3,
				1.6,
				C.iron,
				M.Metal,
				{ CastShadow = false }
			)
		end
	end
	for _, wz in { -5.9, 5.9 } do
		box(
			model,
			"Rod",
			CFrame.new(bx0 + 10, 3, wz),
			Vector3.new(13, 0.5, 0.3),
			C.steel,
			M.Metal,
			{ CastShadow = false }
		)
	end

	-- engine room inside: the engine, furnace, fuel gauge and the upgrades board
	local ex = roomCar.cx + 1
	local engine = Kit.model("Engine", model)
	-- painted in the train's green with brass trim, so it reads as a proud machine, not a black lump
	box(engine, "EngineBlock", CFrame.new(ex, FLOOR + 3, 3), Vector3.new(12, 6, 7), C.green, M.Metal)
	box(
		engine,
		"EngineTrim",
		CFrame.new(ex, FLOOR + 5.9, 3),
		Vector3.new(12.3, 0.3, 7.3),
		C.brass,
		M.Metal,
		{ CastShadow = false }
	)
	box(engine, "EngineBase", CFrame.new(ex, FLOOR + 0.35, 3), Vector3.new(13, 0.7, 8), C.iron, M.Metal)
	Kit.bulb(engine, "EngineLamp", Vector3.new(ex, CEIL - 2.2, 0), 0.8, C.warm, 22, 1.4)
	for i = -1, 1 do
		cyl(
			engine,
			"Cylinder",
			CFrame.new(ex + i * 3.6, FLOOR + 7, 3) * CFrame.Angles(0, 0, math.rad(90)),
			3,
			2.2,
			C.steel,
			M.Metal
		)
	end
	cyl(
		engine,
		"Flywheel",
		CFrame.new(ex - 7.2, FLOOR + 4.5, 3) * CFrame.Angles(0, math.rad(90), 0),
		0.8,
		7,
		C.wheel,
		M.Metal
	)
	cyl(
		engine,
		"FlywheelHub",
		CFrame.new(ex - 7.25, FLOOR + 4.5, 3) * CFrame.Angles(0, math.rad(90), 0),
		1,
		2,
		C.brass,
		M.Metal,
		{ CastShadow = false }
	)
	local furnace = box(engine, "Furnace", CFrame.new(ex + 8, FLOOR + 3, 8), Vector3.new(5, 6, 6), C.iron, M.Metal)
	_ = furnace
	box(
		engine,
		"FurnaceDoorFrame",
		CFrame.new(ex + 8, FLOOR + 2.8, 4.95),
		Vector3.new(3.4, 2.8, 0.15),
		C.brass,
		M.Metal,
		{ CastShadow = false }
	)
	local fire = box(
		engine,
		"FurnaceGlow",
		CFrame.new(ex + 8, FLOOR + 2.8, 4.9),
		Vector3.new(2.6, 2, 0.2),
		Color3.fromRGB(255, 120, 40),
		M.Neon,
		{ CastShadow = false }
	)
	out.furnaceLight =
		Kit.light(fire, "PointLight", { Range = 18, Brightness = 2.2, Color = Color3.fromRGB(255, 130, 60) })
	out.furnace = fire
	box(
		engine,
		"Pipe",
		CFrame.new(ex, CEIL - 1.5, 6),
		Vector3.new(16, 0.8, 0.8),
		C.steel,
		M.Metal,
		{ CastShadow = false }
	)
	box(
		engine,
		"Pipe",
		CFrame.new(ex - 2, CEIL - 2.5, 9),
		Vector3.new(14, 0.6, 0.6),
		C.brassDark,
		M.Metal,
		{ CastShadow = false }
	)
	-- fuel gauge: a tall glass tube with a red bar (TrainService sets the bar height)
	local gx = car.x0 + 8
	box(
		model,
		"FuelTube",
		CFrame.new(gx, FLOOR + 6, -11.3),
		Vector3.new(1.6, 9, 0.6),
		C.glass,
		M.Glass,
		{ Transparency = 0.5, CastShadow = false }
	)
	box(
		model,
		"FuelFrame",
		CFrame.new(gx, FLOOR + 6, -11.7),
		Vector3.new(2.6, 10, 0.3),
		C.brass,
		M.Metal,
		{ CastShadow = false }
	)
	local bar = box(
		model,
		"FuelBar",
		CFrame.new(gx, FLOOR + 1.5 + 2, -11.3),
		Vector3.new(1.1, 4, 0.4),
		C.fuel,
		M.Neon,
		{ CastShadow = false, CanCollide = false }
	)
	out.fuelBar = bar
	out.fuelBase = Vector3.new(gx, FLOOR + 1.5, -11.3)
	local fuelLabel = box(
		model,
		"FuelLabel",
		CFrame.new(gx, FLOOR + 11.6, -11.6),
		Vector3.new(3.4, 1.2, 0.2),
		C.greenDark,
		M.SmoothPlastic,
		{ CastShadow = false }
	)
	out.fuelText = Kit.text(fuelLabel, Enum.NormalId.Back, "FUEL", { color = C.brass })
	-- the train upgrades board
	local board = box(model, "UpgradeBoard", Layout.UPGRADE_BOARD_CF, Vector3.new(12, 7, 0.4), C.black, M.SmoothPlastic)
	box(
		model,
		"UpgradeBoardFrame",
		Layout.UPGRADE_BOARD_CF * CFrame.new(0, 0, -0.1),
		Vector3.new(12.8, 7.8, 0.3),
		C.brass,
		M.Metal
	)
	local boardText = Kit.text(
		board,
		Enum.NormalId.Back,
		"TRAIN UPGRADES",
		{ color = C.cream, ppu = 30, align = Enum.TextXAlignment.Left }
	)
	boardText.TextYAlignment = Enum.TextYAlignment.Top
	boardText.TextScaled = false
	boardText.TextSize = 24
	out.upgradeBoard = boardText
	out.upgradeBoardPart = board
	ceilingLamps(model, roomCar, 0, 9, out.lights)

	-- Engine Overhaul stages (hidden until built; TrainService shows them)
	local s1 = Kit.model("EngineStage1", model)
	for i = 0, 3 do
		cyl(
			s1,
			"CopperPipe",
			CFrame.new(ex - 6 + i * 4, FLOOR + 9.5, 0.5) * CFrame.Angles(0, 0, math.rad(90)),
			4.5,
			0.7,
			Color3.fromRGB(196, 110, 60),
			M.Metal,
			{ CastShadow = false }
		)
	end
	for i = 0, 2 do
		box(
			s1,
			"PressureGauge",
			CFrame.new(ex - 3 + i * 3, FLOOR + 6.5, -0.6),
			Vector3.new(1.4, 1.4, 0.2),
			Color3.fromRGB(255, 240, 200),
			M.Neon,
			{ CastShadow = false }
		)
	end
	local s2 = Kit.model("EngineStage2", model)
	cyl(s2, "SecondBoiler", CFrame.new(ex, FLOOR + 3.5, -5) * CFrame.Angles(0, 0, 0), 9, 4.5, C.brassDark, M.Metal)
	for i = -1, 1 do
		box(
			s2,
			"Valve",
			CFrame.new(ex + i * 3, FLOOR + 6.2, -5),
			Vector3.new(0.8, 1.2, 0.8),
			C.wheel,
			M.Metal,
			{ CastShadow = false }
		)
	end
	local s3 = Kit.model("EngineStage3", model)
	box(
		s3,
		"GoldTrim",
		CFrame.new(ex, FLOOR + 6.1, 3),
		Vector3.new(12.4, 0.4, 7.4),
		C.brass,
		M.Foil,
		{ CastShadow = false }
	)
	cyl(
		s3,
		"GoldBand",
		CFrame.new(boilerCx, 10, 0),
		bl * 0.98,
		13.25,
		C.brass,
		M.Foil,
		{ CastShadow = false, Transparency = 0 }
	)
	local blue = box(
		s3,
		"BlueFlame",
		CFrame.new(ex + 8, FLOOR + 2.8, 4.85),
		Vector3.new(2.7, 2.1, 0.2),
		Color3.fromRGB(90, 170, 255),
		M.Neon,
		{ CastShadow = false }
	)
	_ = blue
	out.engineStages = { s1, s2, s3 }
	-- the searchlight on the cab roof (Scout Lamp stage 1)
	local sl = Kit.model("Searchlight", model)
	disc(sl, "SearchlightBase", Vector3.new(cabCx, ROOF + 1.6, 0), 2.4, 1.2, C.iron, M.Metal)
	cyl(sl, "SearchlightBody", CFrame.new(cabCx + 0.6, ROOF + 3, 0), 3, 2.6, C.steel, M.Metal)
	local slLens = cyl(
		sl,
		"SearchlightLens",
		CFrame.new(cabCx + 2.15, ROOF + 3, 0),
		0.15,
		2.2,
		Color3.fromRGB(230, 245, 255),
		M.Neon,
		{ CastShadow = false }
	)
	Kit.light(
		slLens,
		"SpotLight",
		{ Face = Enum.NormalId.Right, Range = 60, Angle = 30, Brightness = 3, Color = Color3.fromRGB(220, 235, 255) }
	)
	out.lampStages[1] = sl
	lettering(model, roomCar, "ENGINE", roomCar.cx)
	return model
end

-- Build the whole train into `parent`. Returns the handles (see the top of this file).
function TrainBuilder.build(parent)
	local out = { doors = {}, cabins = {}, lights = {}, lampStages = {}, engineStages = {} }
	local train = Kit.model("Train", parent)
	for _, car in Layout.CARS do
		if car.kind == "loco" then
			loco(train, car, out)
		elseif car.kind == "crew" then
			crewCar(train, car, out)
		else
			cabinCar(train, car, out)
		end
	end
	-- tail lamps on the last car
	local last = Layout.CARS[#Layout.CARS]
	for _, z in { -9, 9 } do
		local tail = Kit.disc(
			train,
			"TailLamp",
			Vector3.new(last.x0 - 0.2, 6, z),
			1.2,
			0.3,
			C.signal,
			M.Neon,
			{ CastShadow = false }
		)
		tail.CFrame = CFrame.new(last.x0 - 0.2, 6, z) * CFrame.Angles(0, 0, 0)
	end
	out.model = train
	return out
end

return TrainBuilder
