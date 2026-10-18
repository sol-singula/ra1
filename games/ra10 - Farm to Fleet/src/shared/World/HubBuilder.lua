--[[
Stage 5's pieces, the Distribution Hub (master plan §13.1: the operation visibly explodes in scale): the warehouse
takes over the front of the plot. FarmBuilder hands over its BUILD table and WarehouseBuilder its kit (walls, roof
tags, the detail layer); this adds:

  hubDeed       survey stakes over the front and a sign: the hub is coming
  backDocks     four dock doors along the warehouse's back wall (seals, levelers, bumpers, lights, canopies,
                numbers), the truck court paved behind it, light poles and a guard booth; the box trucks move to the
                court (in line with their docks: World/Trips "truckBack")
  frontHall     the warehouse grows forward over the packing shed (the shed, the sorter, the wrapper and the box line
                go: Upgrades "replaces"), its old front wall comes down, and the hall rises: a façade with the order
                board, the PACK ORDERS pad and the van's loading door where they were, a sign band, an entrance
                canopy; inside a sorting line, packing tables, the wrapper, an overhead conveyor loop, a mezzanine
                office, compressors, pallets, the Operations screen hanging over the station pads, and the detail
                layer (pipes, ducts, lights) like every slice
  semi1, semi2  a dock door each (5, 6) for the semis that come in from the shared road
  controlTower  an HQ tower on the hall's corner: a glass cab, the farm's sign, an antenna with a beacon
  solarRoof     solar panels on every roof there is
  marketHall    a red market hall along the road where the farm stand stood: a glass storefront, a striped
                awning, a gable roof with a cupola; inside produce stalls, fridge cases, a checkout where the sell pad
                now is, the buy-pads at an upgrades desk (the stand comes down; the pads move in)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local PlotLayout = require(script.Parent.PlotLayout)
local Shapes = require(script.Parent.Shapes)

local P = Constants.PALETTE
local deco = Shapes.deco
local SPOTS = PlotLayout.SPOTS
local SLICES = PlotLayout.SLICES
local INK = Color3.fromRGB(30, 30, 34)
local WHITE = Color3.fromRGB(250, 250, 248)
local rgb = Color3.fromRGB
local NEON = Enum.Material.Neon

local X0, X1 = 6, 70
local H = PlotLayout.WAREHOUSE.Y

return function(FarmBuilder, BUILD, kit)
	local wall, roofTag, detail, outside = kit.wall, kit.roofTag, kit.detail, kit.outside
	local CARDBOARD, FRUIT = kit.CARDBOARD, kit.FRUIT

	-- A wall along X from x0 to x1 at z with door openings ({ x, w, h }), lintels over them; face: -1 front, 1 back
	local function wallWithDoors(L, x0, x1, z, h, doors, face, color)
		table.sort(doors, function(a, b)
			return a.x < b.x
		end)
		local at = x0
		for _, door in doors do
			local left = door.x - door.w / 2
			if left > at + 0.1 then
				wall(L, (at + left) / 2, z, left - at, 0.8, h, 0.5, face)
			end
			L:block(
				door.x,
				z,
				door.w,
				0.8,
				h - door.h,
				{ color = color or kit.STEEL_WALL, name = "WarehouseWall" },
				0.5 + door.h
			)
			at = door.x + door.w / 2
		end
		if x1 > at + 0.1 then
			wall(L, (at + x1) / 2, z, x1 - at, 0.8, h, 0.5, face)
		end
	end

	local function sign(L, x, y, z, w, h, title, color, text)
		local part = L:box(x, y, z, w, h, 0.2, deco({ color = color or WHITE, name = "HubSign" }))
		FarmBuilder.sign(part, title, nil, text or INK)
		return part
	end

	local function boxes(L, x, z, y0, n)
		for i = 0, n - 1 do
			L:block(
				x + (i % 2) * 1.4,
				z + (i // 2 % 2) * 1.4,
				1.3,
				1.3,
				1.1,
				deco({ color = CARDBOARD, name = "Box" }),
				y0 + (i // 4) * 1.1
			)
		end
	end

	-- The hub's deed: survey stakes and flags over the front, a sign -----------------------------------------------
	BUILD.hubDeed = function(L, plot)
		for _, c in { { X0, -74 }, { X1, -74 }, { X0, -36 }, { X1, -36 }, { -36, -108 }, { 6, -108 }, { -36, -87 } } do
			L:block(c[1], c[2], 0.4, 0.4, 3, deco({ color = P.safetyYellow, name = "Stake" }), 0)
			L:box(c[1] + 0.6, 2.7, c[2], 1, 0.6, 0.05, deco({ color = P.rackOrange, name = "Flag" }))
		end
		local board = L:box(-15, 3.4, -89, 14, 3.2, 0.3, deco({ color = P.cream, name = "SiteSign" }))
		FarmBuilder.sign(board, "DISTRIBUTION HUB", "coming soon", plot.color)
		for _, sx in { -6, 6 } do
			L:block(-15 + sx, -89, 0.4, 0.4, 5, deco({ color = P.wood, name = "SignPost" }), 0)
		end
	end

	-- The back docks: four dock doors on the back wall, the truck court, the trucks moved round ----------------------
	local BACK = SLICES[#SLICES]

	-- Dock door i on the back wall: its approach lines, lip and leveler, the door behind a black seal, bumpers, a light
	-- each side, a canopy and its number; a box truck's dock (1-4) also gets its bay in the lot
	local function dock(L, i)
		local x = SPOTS.docks[i]
		local lot = SPOTS.dockLot[i]
		for _, sx in { -3.4, 3.4 } do
			L:box(x + sx, 0.36, 34, 0.3, 0.02, 18, deco({ color = P.safetyYellow, name = "DockLine" }))
			if lot then
				L:box(lot.X + sx, 0.36, lot.Z, 0.25, 0.02, 16, deco({ color = WHITE, name = "LotLine" }))
			end
		end
		L:block(x, BACK + 0.75, 10, 1.5, 1.3, { color = P.concrete, name = "DockLip" }, 0)
		L:box(x, 1.32, BACK + 1.6, 8, 0.12, 1.4, deco({ color = P.steel, name = "Leveler" }))
		L:box(x, 5.6, BACK + 0.06, 8.2, 10, 0.1, deco({ color = rgb(120, 126, 136), name = "DockDoor" }))
		for k = 1, 6 do
			L:box(x, 1 + k * 1.5, BACK + 0.12, 8.2, 0.12, 0.05, deco({ color = rgb(96, 102, 112), name = "Slat" }))
		end
		for _, sx in { -1, 1 } do
			L:box(x + sx * 4.4, 5.8, BACK + 0.4, 0.6, 10.6, 0.7, deco({ color = INK, name = "DockSeal" }))
			L:block(x + sx * 3.2, BACK + 1.6, 1, 0.5, 1.2, { color = INK, name = "DockBumper" }, 0.2)
			L:box(
				x + sx * 4.9,
				12.2,
				BACK + 0.3,
				0.5,
				0.8,
				0.3,
				deco({
					color = sx < 0 and P.dockGreen or P.dockRed,
					material = NEON,
					name = "DockLight",
				})
			)
		end
		L:box(x, 11.4, BACK + 0.4, 9.4, 0.8, 0.7, deco({ color = INK, name = "DockSeal" }))
		L:box(x, 13, BACK + 2.4, 10, 0.4, 4.6, deco({ color = P.safetyYellow, name = "Canopy" }))
		sign(L, x, 14.8, BACK + 0.15, 2.2, 2.2, tostring(i), P.safetyYellow, INK)
		if lot then
			L:block(lot.X, lot.Z + 7.5, 3, 0.6, 0.4, deco({ color = P.safetyYellow, name = "WheelStop" }), 0.2)
		end
	end
	BUILD.backDocks = function(L, plot)
		for _, d in plot.items:GetDescendants() do
			if d:GetAttribute("OldLot") then
				d:Destroy()
			end
		end
		-- the court: asphalt behind the warehouse out to the lot, painted bays, approach lines
		L:block(44, 55, 72, 62, 0.12, deco({ color = P.asphalt, name = "TruckCourt" }), 0.22)
		for i = 1, 4 do
			dock(L, i)
		end
		-- light poles and a guard booth by the lane
		for _, x in { 27.25, 48.25 } do
			L:block(x, 52, 0.6, 0.6, 14, { color = P.steel, name = "LightPole" }, 0)
			L:box(x, 14, 52, 3, 0.5, 1.2, deco({ color = P.steel, name = "LightHead" }))
			L:box(x, 13.7, 52, 2.6, 0.1, 1, deco({ color = rgb(255, 246, 220), material = NEON, name = "LightGlow" }))
		end
		L:block(68, 30, 4, 4, 4, { color = WHITE, name = "GuardBooth" }, 0)
		L:box(68, 2.8, 27.95, 3.2, 1.6, 0.1, deco({ color = P.glass, name = "BoothWindow" }))
		L:box(68, 4.3, 30, 5, 0.5, 5, deco({ color = plot.color, name = "BoothRoof" }))
		L:box(72, 1.4, 30, 0.3, 0.3, 6, deco({ color = P.dockRed, name = "Barrier" }))
		-- the trucks: to the court, each in line with its dock
		for _, d in plot.items:GetDescendants() do
			if d.Name == "Vehicle" and d:GetAttribute("Kind") == "truck" then
				local n = d:GetAttribute("Park") or 1
				d:SetAttribute("ParkAt", SPOTS.dockLot[n])
				d:SetAttribute("Plan", "truckBack")
				d:SetAttribute("Parked", nil)
			end
		end
	end

	-- The semis' docks (5, 6): a dock door each, with a SEMIS sign over it
	for n = 1, 2 do
		BUILD["semi" .. n] = function(L)
			dock(L, 4 + n)
			local x = SPOTS.docks[4 + n]
			sign(L, x, 17, BACK + 0.15, 6, 1.4, "SEMIS", P.rackOrange, WHITE)
			L:box(x, 0.37, 50, 0.4, 0.02, 30, deco({ color = P.rackOrange, name = "SemiLine" }))
		end
	end

	-- The front hall: the warehouse grows over the shed ---------------------------------------------------------------
	local FZ = PlotLayout.FRONT -- the hall's front wall
	local HZ = SLICES[1] -- where the old front wall stood (the hall's back)
	BUILD.frontHall = function(L, plot)
		-- the old front wall, its sign, screen and the shed's bridge come down
		for _, d in plot.items:GetDescendants() do
			if d:GetAttribute("Front") then
				d:Destroy()
			end
		end
		local cx, cz, d = (X0 + X1) / 2, (FZ + HZ) / 2, HZ - FZ
		L:block(cx, cz, X1 - X0 + 1, d, 0.5, { color = P.concrete, name = "WarehouseFloor" }, 0)
		L:block(cx, cz, X1 - X0 - 2, d - 0.4, 0.04, deco({ color = rgb(186, 188, 190), name = "FloorSeal" }), 0.5)
		wall(L, X0 + 0.4, cz, 0.8, d, H, 0.5, -1)
		wall(L, X1 - 0.4, cz, 0.8, d, H, 0.5, 1)
		local pd, ld = SPOTS.peopleDoor.X, SPOTS.door.X
		wallWithDoors(L, X0, X1, FZ + 0.4, H, { { x = pd, w = 4, h = 8 }, { x = ld, w = 9, h = 10 } }, -1)
		-- the façade: a band of windows, the sign band, the doors' frames, a canopy over the entrance, bollards
		for _, seg in { { 8, pd - 3 }, { pd + 3, ld - 6 }, { ld + 6, 68 } } do
			L:box(
				(seg[1] + seg[2]) / 2,
				12,
				FZ - 0.05,
				seg[2] - seg[1],
				2.4,
				0.1,
				deco({ color = P.glass, name = "Window", transparency = 0.1 })
			)
		end
		L:box(cx, H - 1.6, FZ - 0.15, X1 - X0 + 0.4, 3, 0.3, deco({ color = plot.color, name = "Band" }))
		sign(L, 40, H - 1.6, FZ - 0.35, 40, 2.6, "FARM TO FLEET DISTRIBUTION", plot.color, WHITE)
		for _, sx in { -1, 1 } do
			L:block(ld + sx * 4.8, FZ - 0.2, 0.6, 1.2, 10, deco({ color = P.safetyYellow, name = "DoorFrame" }), 0.5)
			L:block(pd + sx * 2.2, FZ - 0.2, 0.4, 1, 8, deco({ color = WHITE, name = "DoorFrame" }), 0.5)
			L:block(pd + sx * 3, FZ - 4, 0.4, 0.4, 9, { color = WHITE, name = "CanopyPost" }, 0)
		end
		L:box(ld, 10.8, FZ - 0.2, 10.2, 0.6, 1.2, deco({ color = P.safetyYellow, name = "DoorFrame" }))
		L:cyl(ld, 9.8, FZ + 1, 9, 1.4, deco({ color = P.steel, name = "DoorDrum" }), "x")
		L:box(pd, 9.2, FZ - 2.2, 8, 0.5, 5, { color = plot.color, name = "Canopy" })
		L:box(pd, 9.5, FZ - 2.2, 8.2, 0.15, 5.2, deco({ color = WHITE, name = "CanopyTrim" }))
		for _, x in { 30, 34, 50, 54, 58 } do
			L:block(x, FZ - 1.6, 0.6, 0.6, 1.8, { color = P.safetyYellow, name = "Bollard" }, 0)
		end
		-- the order board and the PACK ORDERS pad, where they've always been
		FarmBuilder.orderBoard(L, plot, Vector3.new(14, 0, FZ - 0.45), true)
		FarmBuilder.packPad(L, SPOTS.packPad)
		-- the roof and the detail layer
		roofTag(L:box(cx, H + 0.8, cz, X1 - X0 + 2, 0.6, d, { color = kit.ROOF, name = "Roof" }), plot, X0, FZ, X1, HZ)
		for _, sx in { -18, 0, 18 } do
			roofTag(
				L:box(
					cx + sx,
					H + 1.15,
					cz,
					6,
					0.2,
					d - 6,
					deco({ color = P.glass, name = "Skylight", transparency = 0.2 })
				),
				plot,
				X0,
				FZ,
				X1,
				HZ
			)
		end
		detail(L, plot, X0, X1, FZ, HZ)
		outside(L, plot, X0, X1, FZ, HZ)
		-- inside: the Operations screen hangs over the station pads, facing the entrance
		L:box(42, 12, HZ - 2.4, 21, 7.4, 0.3, deco({ color = INK, name = "ScreenFrame" }))
		L:box(42, 12, HZ - 2.6, 20, 6.6, 0.1, deco({ color = rgb(20, 26, 34), name = "OpsScreen" }))
		for _, sx in { -9, 9 } do
			L:box(42 + sx, (15.7 + H) / 2, HZ - 2.4, 0.1, H - 15.7, 0.1, deco({ color = INK, name = "Chain" }))
		end
		-- the sorting line: a long belt with boxes into the sorter, its chutes and bins
		L:block(44, -67, 32, 2.2, 2.2, { color = P.steel, name = "SortBelt" }, 0.5)
		L:block(44, -67, 32, 1.8, 0.08, deco({ color = INK, name = "Belt" }), 2.7)
		for i = 0, 9 do
			L:block(30 + i * 3, -67, 1.3, 1.3, 1, deco({ color = CARDBOARD, name = "Box" }), 2.78)
		end
		L:block(63, -64, 6, 7, 6, { color = P.rackBlue, name = "Sorter" }, 0.5)
		L:wedge(63, 8.1, -64, 6.4, 3, 7.4, { color = P.steelLight, name = "Hopper" }, 180)
		for i, c in { P.dockRed, P.sunflower, P.dockGreen, P.rackOrange } do
			local x = 58.5 + (i - 1) * 3
			local chute = L:box(x, 2.6, -58.6, 1.4, 0.3, 3.4, deco({ color = c, name = "Chute" }))
			chute.CFrame = chute.CFrame * CFrame.Angles(math.rad(-25), 0, 0)
			L:block(x, -56, 2.4, 2, 1.6, { color = c, name = "Bin" }, 0.5)
		end
		-- packing tables with their boxes, scales and screens
		for _, x in { 32, 44 } do
			L:block(x, -57, 8, 3, 3, { color = P.wood, name = "PackTable" }, 0.5)
			L:block(x, -57, 8.4, 3.4, 0.3, deco({ color = P.steelLight, name = "TableTop" }), 3.5)
			boxes(L, x - 3, -57.6, 3.8, 4)
			L:box(x + 2.5, 3.9, -57, 1.6, 0.2, 1.6, deco({ color = P.steel, name = "Scale" }))
			L:box(x + 2.5, 5, -58.2, 1.4, 1, 0.1, deco({ color = rgb(60, 160, 240), material = NEON, name = "Screen" }))
			L:box(x, 9, -57, 4, 0.2, 1, deco({ color = rgb(255, 246, 220), material = NEON, name = "TableLight" }))
		end
		-- the wrapper and wrapped pallets
		L:cyl(60, 0.8, -47, 0.6, 6, { color = P.steel, name = "Turntable" }, "y")
		L:block(63.6, -47, 0.8, 0.8, 8, { color = P.rackOrange, name = "Mast" }, 0.5)
		FarmBuilder.pallet(L, 60, 1.1, -47, "WrapPallet", false)
		FarmBuilder.pallet(L, 67, 0.5, -72, "Pallet", false)
		FarmBuilder.pallet(L, 67, 3.1, -72, "Pallet", false)
		-- the overhead conveyor loop, on posts, boxes riding round it
		local y = 10
		for _, run in { { 26, 62, -70 }, { 26, 62, -50 } } do
			L:box(
				(run[1] + run[2]) / 2,
				y,
				run[3],
				run[2] - run[1],
				0.5,
				2,
				deco({ color = P.steel, name = "LoopBelt" })
			)
			for x = run[1] + 3, run[2] - 3, 6 do
				L:block(x, run[3], 1.1, 1.1, 0.9, deco({ color = CARDBOARD, name = "Box" }), y + 0.25)
			end
		end
		for _, x in { 26, 62 } do
			L:box(x, y, -60, 2, 0.5, 20, deco({ color = P.steel, name = "LoopBelt" }))
			for _, z in { -70, -50 } do
				L:box(x, y / 2, z, 0.4, y, 0.4, deco({ color = P.steel, name = "LoopPost" }))
			end
		end
		-- the mezzanine office in the corner, its stairs and railing
		L:box(13, 8, -65, 12, 0.5, 16, { color = P.steel, name = "Mezzanine" })
		for _, c in { { 7.5, -72.5 }, { 18.5, -72.5 }, { 18.5, -57.5 }, { 7.5, -57.5 } } do
			L:block(c[1], c[2], 0.5, 0.5, 7.5, { color = P.safetyYellow, name = "MezzPost" }, 0.5)
		end
		L:box(19, 9, -65, 0.2, 1, 16, deco({ color = P.safetyYellow, name = "Railing" }))
		L:box(13, 9, -57.1, 12, 1, 0.2, deco({ color = P.safetyYellow, name = "Railing" }))
		L:block(12, -66, 9, 10, 5.6, { color = P.glass, name = "MezzOffice", transparency = 0.35 }, 8.25)
		L:box(12, 14, -66, 9.4, 0.4, 10.4, deco({ color = kit.STEEL_WALL, name = "MezzRoof" }))
		L:block(11, -68, 4, 2, 2, deco({ color = P.wood, name = "Desk" }), 8.25)
		L:box(11, 11, -68.6, 1.6, 1, 0.1, deco({ color = rgb(60, 160, 240), material = NEON, name = "Monitor" }))
		local stairs = L:wedge(20.5, 4.25, -52, 3, 7.5, 9, { color = P.steel, name = "Stairs" }, 180)
		_ = stairs
		-- compressors and air tanks in the corner, a walkway to the station pads
		for i = 0, 1 do
			L:cyl(66, 1.6, -40 - i * 3, 4, 2.2, { color = rgb(60, 130, 220), name = "AirTank" }, "x")
		end
		L:block(60, -40, 3, 2.6, 2.4, { color = P.steelLight, name = "Compressor" }, 0.5)
		L:box(pd, 0.53, (FZ + HZ - 6) / 2, 3, 0.02, d - 6, deco({ color = P.dockGreen, name = "Walkway" }))
		L:box((pd + 54) / 2, 0.53, HZ - 9, 54 - pd, 0.02, 3, deco({ color = P.dockGreen, name = "Walkway" }))
	end

	-- The control tower: an HQ on the hall's corner -------------------------------------------------------------------
	BUILD.controlTower = function(L, plot)
		local x, z = 12, -68
		L:block(x, z, 8, 8, 14, { color = kit.STEEL_WALL, name = "TowerShaft" }, H + 1)
		for k = 0, 2 do
			L:box(x, H + 4 + k * 4, z - 4.05, 2, 2, 0.1, deco({ color = P.glass, name = "TowerWindow" }))
		end
		local cab = H + 15
		L:block(x, z, 13, 13, 0.8, { color = INK, name = "CabFloor" }, cab)
		L:block(x, z, 12, 12, 7, { color = P.glass, name = "TowerCab", transparency = 0.25 }, cab + 0.8)
		for _, sx in { -6, 6 } do
			for _, sz in { -6, 6 } do
				L:block(x + sx, z + sz, 0.5, 0.5, 7, { color = INK, name = "CabPost" }, cab + 0.8)
			end
		end
		L:block(x, z, 14, 14, 1, { color = plot.color, name = "CabRoof" }, cab + 7.8)
		sign(L, x, cab + 10.2, z - 3.6, 12, 2.4, "HQ", plot.color, WHITE)
		L:block(x + 3, z + 3, 0.3, 0.3, 10, { color = P.steel, name = "Antenna" }, cab + 8.8)
		L:box(x + 3, cab + 19, z + 3, 0.8, 0.8, 0.8, deco({ color = P.dockRed, material = NEON, name = "Beacon" }))
		L:cyl(x - 3, cab + 9.6, z + 3, 0.4, 2.6, deco({ color = WHITE, name = "Dish" }), "z")
	end

	-- The solar roof: panels on every roof there is --------------------------------------------------------------------
	BUILD.solarRoof = function(L, plot)
		for _, roof in plot.items:GetDescendants() do
			if roof.Name == "Roof" and roof:IsA("BasePart") and roof:GetAttribute("Roof") then
				local mn, mx = roof:GetAttribute("RoofMin"), roof:GetAttribute("RoofMax")
				if typeof(mn) ~= "Vector3" then
					continue
				end
				local l = plot.cf:PointToObjectSpace(roof.Position)
				local z0, z1 = mn.Z, mx.Z
				for z = z0 + 2.6, z1 - 2.6, 4.4 do
					for _, x in { 13, 28, 48, 63 } do
						local panel =
							L:box(x, l.Y + 1.2, z, 12, 0.25, 3, deco({ color = rgb(30, 50, 110), name = "SolarPanel" }))
						panel.CFrame = panel.CFrame * CFrame.Angles(math.rad(-15), 0, 0)
						roofTag(panel, plot, mn.X, z0, mx.X, z1)
						roofTag(
							L:box(x, l.Y + 0.75, z + 0.6, 0.3, 0.6, 0.3, deco({ color = P.steel, name = "PanelLeg" })),
							plot,
							mn.X,
							z0,
							mx.X,
							z1
						)
					end
				end
			end
		end
		L:block(X1 + 1, -20, 1.2, 3, 2.4, { color = P.steelLight, name = "Inverter" }, 1.5)
		L:box(X1 + 1, 2.6, -18.3, 0.1, 0.6, 0.6, deco({ color = P.dockGreen, material = NEON, name = "InverterLamp" }))
	end

	-- The market hall: where the farm stand stood ----------------------------------------------------------------------
	BUILD.marketHall = function(L, plot)
		local c, size = SPOTS.market, PlotLayout.MARKET
		local x0, x1, z0, z1 = c.X - size.X / 2, c.X + size.X / 2, c.Z - size.Z / 2, c.Z + size.Z / 2
		local h = size.Y
		local RED = rgb(176, 44, 38)
		-- the stand comes down; its sell pad and the buy-pads move in
		local building = plot.items:FindFirstChild("StandBuilding")
		if building then
			building:Destroy()
		end
		for _, d in plot.items:GetChildren() do
			if d:IsA("BasePart") then
				local l = plot.cf:PointToObjectSpace(d.Position)
				local name = d.Name
				local standish = name == "Stand"
					or name == "Counter"
					or name == "StandPost"
					or name == "StandRoof"
					or name == "Crate"
					or name == "Produce"
					or name == "StandSign"
				if standish and l.X > -37 and l.X < -23 and l.Z > -104 and l.Z < -95 then
					d:Destroy()
				end
			end
		end
		local function move(part, at, y)
			local l = plot.cf:PointToObjectSpace(part.Position)
			part.CFrame = plot.cf * CFrame.new(at.X, y or l.Y, at.Z)
		end
		local sellPad, sellRim
		for _, d in plot.items:GetChildren() do
			if d.Name == "SellPad" then
				sellPad = d
			elseif d.Name == "SellRim" then
				sellRim = d
			end
		end
		if sellPad then
			move(sellPad, SPOTS.marketSell)
			FarmBuilder.label(sellPad, "SELL", "checkout", P.sunflower)
		end
		if sellRim then
			move(sellRim, SPOTS.marketSell)
		end
		for _, d in plot.items:GetChildren() do
			if d.Name == "BuyPad" and d:GetAttribute("Slot") then
				move(d, SPOTS.marketPads[d:GetAttribute("Slot")])
			elseif d.Name == "PadRim" then
				-- (each rim goes with the pad it was under)
				local l = plot.cf:PointToObjectSpace(d.Position)
				for slot, at in SPOTS.pads do
					if math.abs(l.X - at.X) < 1 and math.abs(l.Z - at.Z) < 1 then
						move(d, SPOTS.marketPads[slot])
					end
				end
			end
		end
		-- the floor, the red walls with white trim, the glass storefront and its doors
		L:block(c.X, c.Z, size.X + 1, size.Z + 1, 0.5, { color = P.concrete, name = "MarketFloor" }, 0)
		L:block(c.X, c.Z, size.X - 1, size.Z - 1, 0.04, deco({ color = rgb(214, 196, 168), name = "MarketTiles" }), 0.5)
		L:block(c.X, z1 - 0.4, size.X, 0.8, h, { color = RED, name = "MarketWall" }, 0.5)
		L:block(x1 - 0.4, c.Z, 0.8, size.Z, h, { color = RED, name = "MarketWall" }, 0.5)
		-- (the west wall has a door toward the spawn)
		L:block(x0 + 0.4, (z0 + -102) / 2, 0.8, -102 - z0, h, { color = RED, name = "MarketWall" }, 0.5)
		L:block(x0 + 0.4, (-98 + z1) / 2, 0.8, z1 + 98, h, { color = RED, name = "MarketWall" }, 0.5)
		L:block(x0 + 0.4, -100, 0.8, 4, h - 8, { color = RED, name = "MarketWall" }, 8.5)
		for _, wx in { x0, x1 } do
			for _, wz in { z0, z1 } do
				L:block(wx, wz, 1, 1, h, deco({ color = WHITE, name = "Trim" }), 0.5)
			end
		end
		local doors = { -26, -4 }
		for x = x0 + 3, x1 - 3, 6 do
			L:block(x, z0 + 0.3, 0.6, 0.6, h, { color = WHITE, name = "StorePillar" }, 0.5)
		end
		for _, seg in { { x0 + 1, doors[1] - 2 }, { doors[1] + 2, doors[2] - 2 }, { doors[2] + 2, x1 - 1 } } do
			L:block(
				(seg[1] + seg[2]) / 2,
				z0 + 0.3,
				seg[2] - seg[1],
				0.2,
				8,
				{ color = P.glass, name = "Storefront", transparency = 0.3 },
				0.5
			)
		end
		L:block(c.X, z0 + 0.3, size.X, 0.8, h - 8, { color = RED, name = "MarketWall" }, 8.5)
		-- the awning: plot colour and white stripes over the storefront; the sign over it
		for i = 0, 13 do
			local stripe = L:box(
				x0 + 1.5 + i * 3,
				8.6,
				z0 - 1.6,
				3,
				0.2,
				3.6,
				deco({
					color = i % 2 == 0 and plot.color or WHITE,
					name = "Awning",
				})
			)
			stripe.CFrame = stripe.CFrame * CFrame.Angles(math.rad(-18), 0, 0)
		end
		sign(L, c.X, 11, z0 - 0.15, 30, 2.6, "FARM TO FLEET MARKET", WHITE, RED)
		-- the gable roof (ridge along X), a cupola with a weathervane
		local rise = 6
		for _, sz in { -1, 1 } do
			local slope = L:wedge(
				c.X,
				h + 0.5 + rise / 2,
				c.Z + sz * size.Z / 4,
				size.X + 2,
				rise,
				size.Z / 2 + 1,
				{ color = rgb(70, 74, 82), name = "Roof" },
				sz < 0 and 180 or 0
			)
			roofTag(slope, plot, x0, z0, x1, z1)
		end
		roofTag(
			L:block(c.X, c.Z, 3.4, 3.4, 3, { color = WHITE, name = "Cupola" }, h + 0.5 + rise),
			plot,
			x0,
			z0,
			x1,
			z1
		)
		roofTag(
			L:block(c.X, c.Z, 4, 4, 0.5, deco({ color = rgb(70, 74, 82), name = "CupolaRoof" }), h + 3.5 + rise),
			plot,
			x0,
			z0,
			x1,
			z1
		)
		roofTag(
			L:block(c.X, c.Z, 0.2, 0.2, 2.4, deco({ color = INK, name = "Vane" }), h + 4 + rise),
			plot,
			x0,
			z0,
			x1,
			z1
		)
		-- inside: the checkout by the sell pad, the upgrades desk behind the buy-pads, stalls, fridges, banners
		local s = SPOTS.marketSell
		L:block(s.X - 4.6, s.Z, 2, 5, 3.2, { color = P.wood, name = "Checkout" }, 0.5)
		L:box(s.X - 4.6, 4, s.Z, 1.2, 0.6, 1, deco({ color = INK, name = "Register" }))
		sign(L, s.X, 9, s.Z + 2.6, 7, 1.4, "CHECKOUT", P.sunflower, INK)
		L:block(-7, z1 - 2.2, 22, 2, 3.4, { color = P.wood, name = "UpgradeDesk" }, 0.5)
		sign(L, -7, 9, z1 - 1.1, 12, 1.6, "UPGRADES", plot.color, WHITE)
		for i, x in { -18, -7 } do
			L:block(x, -103.5, 6, 3.4, 2.2, { color = P.wood, name = "Stall" }, 0.5)
			for k = 0, 3 do
				L:block(
					x - 2.25 + k * 1.5,
					-103.5,
					1.3,
					2.8,
					0.6,
					deco({ color = FRUIT[(k + i) % #FRUIT + 1], name = "Produce" }),
					2.7
				)
			end
			L:box(x, 7.5, -103.5, 4, 1.6, 0.1, deco({ color = FRUIT[i + 1], name = "Banner" }))
		end
		for k = 0, 2 do
			L:block(x1 - 2, -105 + k * 5, 2.4, 4, 6, { color = WHITE, name = "Fridge" }, 0.5)
			L:box(
				x1 - 3.25,
				3.5,
				-105 + k * 5,
				0.1,
				5,
				3.6,
				deco({ color = P.glass, name = "FridgeGlass", transparency = 0.2 })
			)
			for j = 0, 2 do
				L:box(
					x1 - 2.8,
					1.8 + j * 1.6,
					-105 + k * 5,
					0.6,
					0.5,
					3,
					deco({ color = FRUIT[(k + j) % #FRUIT + 1], name = "FridgeGoods" })
				)
			end
		end
		-- the barn's conveyor arrives here: a hatch in the west wall
		L:block(x0 - 0.2, -92, 1.4, 3.4, 3.4, { color = P.steel, name = "ConveyorHatch" }, 0.5)
		-- the detail layer, sized to the market
		detail(L, plot, x0, x1, z0, z1, h, true)
		-- benches and planters out front
		for _, x in { -32, -15, 2 } do
			L:block(x, -109.2, 3, 1, 0.9, deco({ color = P.wood, name = "Bench" }), 0)
		end
	end
end
