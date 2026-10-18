--[[
Stage 4's pieces (master plan §4, §13.1): the warehouse rising slice by slice, everything inside it you can count
(packing lines, rack rows with a pallet for every pallet the farm holds, forklifts), the station pads and the
Operations screen out front, the truck lane and lot with the box trucks, and the fields' boosts (pivot irrigation,
fertilizer tanks, greenhouses). FarmBuilder hands over its BUILD table; this adds to it.

  the warehouse (front slice A: the lines, the staging floor, the office; slice B: rack rows 1-2), then a bay a
  slice (C, D, E: rows 3-8). A slice's roof parts carry Roof = true (the client hides them when the camera's inside);
  a slice's back wall goes when the next slice comes; unbuilt slices stand as a steel skeleton on their slab.

  parts the services look for: "StationPad" (Track), "OpsScreen", "RackPallet" (Row, Slot), "Staged" (Slot),
  "Inbound" (Slot), "Forklift" (N), a "Vehicle" (Kind "truck", Park, ParkAt) per box truck
  FarmBuilder.forklift(parent, cf, color) -> Model   (its pivot on the ground, forks to -Z)
  FarmBuilder.pallet(L, x, y, z, name, hidden?) -> Model   a pallet of boxes
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
local STEEL_WALL = rgb(214, 218, 226)
local RIB = rgb(196, 201, 210)
local ROOF = rgb(120, 126, 136)
local CARDBOARD = rgb(196, 150, 96)
local FRUIT = { rgb(230, 40, 60), rgb(250, 130, 30), rgb(250, 210, 50), rgb(70, 80, 200), rgb(90, 170, 60) }

local X0, X1 = 6, 70 -- the walls' x
local H = PlotLayout.WAREHOUSE.Y

return function(FarmBuilder, BUILD)
	-- A pallet: the wooden base, a block of boxes with a tape line and a label (three parts; hidden till it's used)
	function FarmBuilder.pallet(L, x, y, z, name, hidden)
		local model = Instance.new("Model")
		model.Name = name or "Pallet"
		model.Parent = L.folder
		local s = L:sub(model)
		local t = hidden and 1 or 0
		s:box(x, y + 0.25, z, 4, 0.5, 4, deco({ color = rgb(200, 160, 110), name = "PalletBase", transparency = t }))
		s:box(x, y + 1.7, z, 3.7, 2.4, 3.7, deco({ color = CARDBOARD, name = "Boxes", transparency = t }))
		local k = math.floor(math.abs(x * 7 + z * 3)) % #FRUIT + 1
		s:box(x, y + 1.7, z - 1.86, 2.6, 0.8, 0.05, deco({ color = FRUIT[k], name = "Label", transparency = t }))
		return model
	end

	-- The Operations screen: the four stations' rates as bars, the slowest in red (master plan §13.2)
	--   rows = { { name, rate, red? } x 4 }, line: the words under the title
	function FarmBuilder.opsScreen(part, rows, line)
		local gui = part:FindFirstChild("Ops") or Instance.new("SurfaceGui")
		gui.Name = "Ops"
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(1000, 330)
		local function get(name, class, parent)
			local o = parent:FindFirstChild(name) or Instance.new(class)
			o.Name = name
			o.Parent = parent
			return o
		end
		local function text(name, value, x, y, w, h, color, parent, align)
			local l = get(name, "TextLabel", parent or gui)
			l.BackgroundTransparency = 1
			l.Position = UDim2.fromScale(x, y)
			l.Size = UDim2.fromScale(w, h)
			l.Font = Enum.Font.GothamBlack
			l.TextScaled = true
			l.TextColor3 = color
			l.TextXAlignment = align or Enum.TextXAlignment.Left
			l.Text = value
			return l
		end
		text("Title", "OPERATIONS", 0.03, 0.02, 0.5, 0.17, P.sunflower)
		text("Line", line or "", 0.45, 0.04, 0.52, 0.13, WHITE, nil, Enum.TextXAlignment.Right)
		local top = 1
		for _, r in rows do
			top = math.max(top, r.rate)
		end
		for i, r in rows do
			local y = 0.24 + (i - 1) * 0.19
			local color = r.red and rgb(240, 70, 60) or rgb(80, 210, 120)
			text("Name" .. i, r.name, 0.03, y, 0.16, 0.14, r.red and color or WHITE)
			local back = get("Bar" .. i, "Frame", gui)
			back.BackgroundColor3 = rgb(50, 58, 70)
			back.BorderSizePixel = 0
			back.Position = UDim2.fromScale(0.2, y + 0.02)
			back.Size = UDim2.fromScale(0.56, 0.1)
			local fill = get("Fill", "Frame", back)
			fill.BackgroundColor3 = color
			fill.BorderSizePixel = 0
			fill.Size = UDim2.fromScale(math.clamp(r.rate / top, 0.03, 1), 1)
			text(
				"Rate" .. i,
				(r.label or tostring(r.rate)) .. "/min",
				0.78,
				y,
				0.2,
				0.14,
				color,
				nil,
				Enum.TextXAlignment.Right
			)
		end
		gui.Parent = part
		return gui
	end

	-- A ribbed steel wall panel (ribs on the face side) -> its parts
	local function wall(L, x, z, w, d, h, y0, face, name)
		local parts = { L:block(x, z, w, d, h, { color = STEEL_WALL, name = name or "WarehouseWall" }, y0) }
		local along = w > d and "x" or "z"
		local len = along == "x" and w or d
		for k = 1, math.floor(len / 3.2) - 1 do
			local off = -len / 2 + k * 3.2
			local rib = deco({ color = RIB, name = name or "Rib" })
			if along == "x" then
				table.insert(parts, L:block(x + off, z + face * (d / 2 + 0.06), 0.3, 0.12, h, rib, y0))
			else
				table.insert(parts, L:block(x + face * (w / 2 + 0.06), z + off, 0.12, 0.3, h, rib, y0))
			end
		end
		return parts
	end

	-- A part that's roof: hidden by the client while the camera is inside the box it covers (local min, max)
	local function roofTag(part, plot, x0, z0, x1, z1)
		part:SetAttribute("Roof", true)
		part:SetAttribute("Plot", plot.index)
		part:SetAttribute("RoofMin", Vector3.new(x0, 0, z0))
		part:SetAttribute("RoofMax", Vector3.new(x1, H + 1.5, z1))
		return part
	end

	-- Everything a real warehouse has overhead and on its walls (master plan §1: detail from geometry): sprinkler
	-- mains with their heads, a ventilation duct with diffusers, a cable tray, high-bay lights, roof joists, columns
	-- with guards, electrical panels, conduit and extinguishers on the walls; outside: downspouts, wall lights, a
	-- pipe rack along the east wall, rooftop units with fans and an exhaust stack
	local RED_PIPE = rgb(200, 40, 40)
	local function detail(L, _plot, x0, x1, z0, z1, h, skipWest)
		h = h or H
		local cx, cz, d, w = (x0 + x1) / 2, (z0 + z1) / 2, z1 - z0, x1 - x0
		-- overhead: two sprinkler mains along X, their heads
		for _, k in { 0.3, 0.7 } do
			local z = z0 + d * k
			L:cyl(cx, h - 0.9, z, w - 2, 0.32, deco({ color = RED_PIPE, name = "Sprinkler" }), "x")
			for x = x0 + 4, x1 - 4, 8 do
				L:box(x, h - 1.25, z, 0.25, 0.4, 0.25, deco({ color = P.sunflower, name = "SprinklerHead" }))
			end
		end
		-- a ventilation duct with diffusers, and a yellow cable tray
		L:cyl(cx, h - 2.3, cz, w - 3, 1.6, deco({ color = P.steelLight, name = "Duct" }), "x")
		for x = x0 + 8, x1 - 8, 16 do
			L:box(x, h - 3.25, cz, 1.6, 0.3, 1.6, deco({ color = WHITE, name = "Diffuser" }))
			L:box(x, h - 1.2, cz, 0.1, 0.9, 0.1, deco({ color = INK, name = "Hanger" }))
		end
		L:box(cx, h - 1.5, cz + 2.4, w - 2, 0.15, 0.9, deco({ color = P.safetyYellow, name = "CableTray" }))
		-- high-bay lights: two rows
		for _, k in { 0.25, 0.75 } do
			for x = x0 + 6, x1 - 6, 12 do
				L:cyl(x, h - 3, z0 + d * k, 0.7, 1.5, deco({ color = P.steel, name = "LampShade" }), "y")
				L:cyl(
					x,
					h - 3.4,
					z0 + d * k,
					0.1,
					1.2,
					deco({
						color = rgb(255, 246, 220),
						material = Enum.Material.Neon,
						name = "LampGlow",
					}),
					"y"
				)
			end
		end
		-- roof joists along Z, and columns with yellow guards on the slice's back line
		for x = x0 + 16, x1 - 8, 16 do
			L:box(x, h - 0.25, cz, 0.5, 0.5, d, deco({ color = P.steel, name = "Joist" }))
			if d >= 10 then
				L:block(x, z1 - 0.6, 0.7, 0.7, h - 0.5, deco({ color = P.steel, name = "Column" }), 0.5)
				L:block(x, z1 - 0.6, 1.1, 1.1, 1.2, deco({ color = P.safetyYellow, name = "ColumnGuard" }), 0.5)
			end
		end
		-- on the walls: an electrical panel with conduit, an extinguisher, a safety sign
		for _, side in { { x0 + 0.9, 1 }, { x1 - 0.9, -1 } } do
			local wx, f = side[1], side[2]
			if skipWest and f == 1 then
				continue
			end
			L:box(wx, 4, cz - 2, 0.4, 2.6, 1.8, deco({ color = rgb(150, 154, 160), name = "Panel" }))
			L:box(wx + f * 0.21, 4.4, cz - 2, 0.02, 0.4, 0.6, deco({ color = P.safetyYellow, name = "PanelSign" }))
			for _, dz in { -2.4, -1.6 } do
				L:box(
					wx,
					(5.3 + h - 1) / 2,
					cz + dz,
					0.15,
					h - 1 - 5.3,
					0.15,
					deco({ color = P.steel, name = "Conduit" })
				)
			end
			L:cyl(wx + f * 0.3, 1.6, cz + 3, 1.3, 0.55, deco({ color = RED_PIPE, name = "Extinguisher" }), "y")
			L:box(wx, 3.1, cz + 3, 0.1, 0.6, 0.9, deco({ color = RED_PIPE, name = "ExtinguisherSign" }))
		end
	end

	-- The outside of a slice: downspouts, wall lights, the east wall's pipe rack, rooftop units
	local function outside(L, plot, x0, x1, z0, z1, h)
		h = h or H
		local cz = (z0 + z1) / 2
		for _, wx in { x0 - 0.35, x1 + 0.35 } do
			L:cyl(wx, (h + 0.5) / 2, z1 - 0.8, h, 0.5, deco({ color = P.steel, name = "Downspout" }), "y")
			L:box(wx, h - 6, cz, 0.6, 0.6, 1, deco({ color = INK, name = "WallLight" }))
			L:box(
				wx + (wx < x0 and -0.31 or 0.31),
				h - 6.2,
				cz,
				0.05,
				0.3,
				0.8,
				deco({
					color = rgb(255, 246, 220),
					material = Enum.Material.Neon,
					name = "WallLightGlow",
				})
			)
		end
		-- the pipe rack down the east wall: water, gas, compressed air
		for i, c in { rgb(60, 130, 220), P.safetyYellow, rgb(170, 175, 180) } do
			L:cyl(x1 + 0.8, 5 + i * 0.7, cz, z1 - z0, 0.42, deco({ color = c, name = "WallPipe" }), "z")
		end
		L:box(x1 + 0.6, 6.4, z0 + 1, 0.8, 2.6, 0.3, deco({ color = INK, name = "PipeBracket" }))
		-- on the roof: a unit with its fan, an exhaust stack
		local rx = x0 + (x1 - x0) * 0.72
		roofTag(L:block(rx, cz, 4, 3, 2, deco({ color = P.steelLight, name = "HVAC" }), h + 1.1), plot, x0, z0, x1, z1)
		roofTag(L:cyl(rx, h + 3.25, cz, 0.3, 2.4, deco({ color = INK, name = "HVACFan" }), "y"), plot, x0, z0, x1, z1)
		roofTag(
			L:cyl(x0 + (x1 - x0) * 0.3, h + 2.6, cz, 3.2, 0.9, deco({ color = P.steel, name = "Stack" }), "y"),
			plot,
			x0,
			z0,
			x1,
			z1
		)
	end

	-- A slice of the building: floor, side walls, roof (with skylights and a vent), and a back wall for now
	local function slice(L, plot, k)
		local z0, z1 = SLICES[k], SLICES[k + 1]
		local d, cz, cx = z1 - z0, (z0 + z1) / 2, (X0 + X1) / 2
		L:block(cx, cz, X1 - X0 + 1, d, 0.5, { color = P.concrete, name = "WarehouseFloor" }, 0)
		L:block(cx, cz, X1 - X0 - 2, d - 0.4, 0.04, deco({ color = rgb(186, 188, 190), name = "FloorSeal" }), 0.5)
		wall(L, X0 + 0.4, cz, 0.8, d, H, 0.5, -1)
		wall(L, X1 - 0.4, cz, 0.8, d, H, 0.5, 1)
		-- the plot-coloured band round the top, and clerestory windows
		for _, wx in { X0 - 0.1, X1 + 0.1 } do
			L:box(wx, H - 1.4, cz, 0.2, 1.6, d, deco({ color = plot.color, name = "Band" }))
			L:box(wx, H - 4.4, cz, 0.15, 2, d - 3, deco({ color = P.glass, name = "Clerestory", transparency = 0.1 }))
		end
		-- the roof: a low slab, skylights along it, a vent on top: all hidden from inside
		roofTag(L:box(cx, H + 0.8, cz, X1 - X0 + 2, 0.6, d, { color = ROOF, name = "Roof" }), plot, X0, z0, X1, z1)
		for _, sx in { -18, 0, 18 } do
			roofTag(
				L:box(
					cx + sx,
					H + 1.15,
					cz,
					6,
					0.2,
					d - 4,
					deco({ color = P.glass, name = "Skylight", transparency = 0.2 })
				),
				plot,
				X0,
				z0,
				X1,
				z1
			)
		end
		detail(L, plot, X0, X1, z0, z1)
		outside(L, plot, X0, X1, z0, z1)
		-- the back wall: until the next slice is built
		for _, part in wall(L, cx, z1 - 0.4, X1 - X0, 0.8, H, 0.5, 1, "BackWall") do
			part:SetAttribute("Slice", k)
		end
	end

	-- The slice before this one loses its back wall; this slice's skeleton goes
	local function open(plot, k)
		for _, d in plot.items:GetDescendants() do
			if
				(d.Name == "BackWall" and d:GetAttribute("Slice") == k - 1)
				or (d.Name == "Skeleton" and d:GetAttribute("Slice") == k)
			then
				d:Destroy()
			end
		end
	end

	-- A rack row: blue uprights, orange beams on three levels, and a hidden pallet in every slot
	local function rack(L, row)
		local z = PlotLayout.rackSlot(row, 1).Z
		local xa, xb = PlotLayout.RACK_X[1], PlotLayout.RACK_X[2]
		-- (each row labelled: what's racked is the excess, waiting for the trucks)
		FarmBuilder.hang(L, xa - 1.5, 13, z, `ROW {row} · EXCESS`, rgb(150, 200, 255), true, 6)
		local per = math.floor((xb - xa) / PlotLayout.SLOT)
		for i = 0, per do
			local x = xa + i * PlotLayout.SLOT
			for _, dz in { -1.2, 1.2 } do
				L:block(x, z + dz, 0.4, 0.4, 10.4, { color = P.rackBlue, name = "Upright" }, 0.5)
			end
		end
		for level = 1, PlotLayout.LEVELS - 1 do
			for _, dz in { -1.2, 1.2 } do
				L:box(
					(xa + xa + per * PlotLayout.SLOT) / 2,
					0.55 + level * 3.2 - 0.15,
					z + dz,
					per * PlotLayout.SLOT,
					0.3,
					0.3,
					deco({ color = P.rackOrange, name = "Beam" })
				)
			end
		end
		L:box(
			(xa + xa + per * PlotLayout.SLOT) / 2,
			10.9,
			z,
			per * PlotLayout.SLOT,
			0.3,
			2.8,
			deco({ color = P.rackOrange, name = "Beam" })
		)
		for n = 1, per * PlotLayout.LEVELS do
			local at = PlotLayout.rackSlot(row, n)
			local m = FarmBuilder.pallet(L, at.X, at.Y, z, "RackPallet", true)
			m:SetAttribute("Row", row)
			m:SetAttribute("Slot", n)
		end
		-- the aisle's painted edges
		local az = PlotLayout.aisle(row)
		if row % 2 == 1 then
			for _, dz in { -2.6, 2.6 } do
				L:box(
					(xa + xb) / 2 + 3,
					0.53,
					az + dz,
					xb - xa + 6,
					0.02,
					0.25,
					deco({ color = P.safetyYellow, name = "LaneLine" })
				)
			end
		end
	end

	-- A packing line: a belt along X with boxes on it, a packing machine at its end
	local function line(L, k)
		local z = -33 + (k - 1) * 3.4
		L:block(37, z, 22, 2, 2.2, { color = P.steel, name = "PackBelt" }, 0.5)
		L:block(37, z, 22, 1.6, 0.08, deco({ color = INK, name = "Belt" }), 2.7)
		for i = 0, 5 do
			L:block(28 + i * 3.6, z, 1.3, 1.3, 1, deco({ color = CARDBOARD, name = "Box" }), 2.78)
		end
		L:block(50, z, 4, 3, 3.6, { color = k % 2 == 1 and P.rackOrange or P.rackBlue, name = "Packer" }, 0.5)
		L:box(
			50,
			3.4,
			z - 1.52,
			2,
			0.8,
			0.05,
			deco({ color = rgb(80, 220, 110), material = Enum.Material.Neon, name = "PackerLamp" })
		)
		L:block(50, z, 2.6, 2, 0.6, deco({ color = P.steelLight, name = "Hopper" }), 4.1)
	end

	-- The forklift: a yellow body, a counterweight, the overhead guard, the mast and the forks (Carriage parts move)
	function FarmBuilder.forklift(parent, cf, color)
		local model = Instance.new("Model")
		model.Name = "Forklift"
		model.Parent = parent
		local s = Shapes.new(model, cf)
		local yellow = P.safetyYellow
		s:box(0, 1.5, 0.4, 2.6, 1.4, 3.4, deco({ color = yellow, name = "Body" }))
		s:box(0, 1.9, 2.1, 2.6, 1.8, 0.9, deco({ color = INK, name = "Counterweight" }))
		s:box(0, 2.5, 0.8, 1.2, 0.3, 1.2, deco({ color = INK, name = "Seat" }))
		for _, sx in { -1.15, 1.15 } do
			for _, sz in { -0.7, 1.7 } do
				s:box(sx, 3.6, sz, 0.15, 2.6, 0.15, deco({ color = INK, name = "Guard" }))
			end
			s:cyl(sx, 0.6, -0.9, 0.5, 1.2, deco({ color = INK, name = "Wheel" }), "x")
			s:cyl(sx, 0.5, 1.8, 0.5, 1, deco({ color = INK, name = "Wheel" }), "x")
		end
		s:box(0, 4.95, 0.5, 2.6, 0.15, 2.8, deco({ color = INK, name = "GuardTop" }))
		s:box(
			0,
			5.2,
			1.6,
			0.4,
			0.3,
			0.4,
			deco({ color = P.rackOrange, material = Enum.Material.Neon, name = "Beacon" })
		)
		s:box(0, 2.3, -1.3, 2.5, 0.3, 0.2, deco({ color = color or P.rackOrange, name = "Stripe" }))
		for _, sx in { -0.8, 0.8 } do
			s:box(sx, 3, -1.55, 0.2, 5, 0.2, deco({ color = P.steel, name = "Mast" }))
		end
		-- the carriage and forks: these ride up and down the mast (the client moves them)
		local carriage = {
			s:box(0, 1, -1.75, 2, 1.2, 0.15, deco({ color = INK, name = "Carriage" })),
			s:box(-0.6, 0.5, -2.75, 0.3, 0.12, 2, deco({ color = INK, name = "Carriage" })),
			s:box(0.6, 0.5, -2.75, 0.3, 0.12, 2, deco({ color = INK, name = "Carriage" })),
		}
		-- the load it carries (shown while it's carrying)
		local load = {
			s:box(0, 0.8, -2.75, 3, 0.4, 3, deco({ color = rgb(200, 160, 110), name = "Load", transparency = 1 })),
			s:box(0, 2, -2.75, 2.8, 2, 2.8, deco({ color = CARDBOARD, name = "Load", transparency = 1 })),
		}
		_ = carriage
		_ = load
		model.WorldPivot = cf
		return model
	end

	-- The steel skeleton of a slice not built yet
	local function skeleton(L, k)
		local z0, z1 = SLICES[k], SLICES[k + 1]
		local folder = Instance.new("Folder")
		folder.Name = "Skeleton"
		folder:SetAttribute("Slice", k)
		folder.Parent = L.folder
		local s = L:sub(folder)
		s:block((X0 + X1) / 2, (z0 + z1) / 2, X1 - X0, z1 - z0, 0.2, deco({ color = P.concrete, name = "Slab" }), 0.2)
		for _, x in { X0, (X0 + X1) / 2, X1 } do
			s:block(x, z1, 0.6, 0.6, H, deco({ color = P.rackOrange, name = "Column" }), 0)
		end
		s:box((X0 + X1) / 2, H, z1, X1 - X0, 0.6, 0.6, deco({ color = P.rackOrange, name = "Girder" }))
		for _, x in { X0, X1 } do
			s:box(x, H, (z0 + z1) / 2, 0.6, 0.6, z1 - z0, deco({ color = P.rackOrange, name = "Girder" }))
		end
	end

	local function forklift(L, plot, n)
		local home = Vector3.new(63 + (n - 1) % 2 * 4, 0.5, -28 + ((n - 1) // 2) * 4)
		local cf = L.cf * CFrame.new(home) * CFrame.Angles(0, math.rad(90), 0)
		local m = FarmBuilder.forklift(L.folder, cf, plot.color)
		m:SetAttribute("N", n)
		m:SetAttribute("Plot", plot.index)
		m:SetAttribute("Home", home)
		return m
	end

	local function truck(L, plot, n)
		local docks = plot.items:FindFirstChild("backDocks") ~= nil
		local at = docks and SPOTS.dockLot[n] or SPOTS.lot[n]
		local cf = L.cf * CFrame.new(at.X, 0, at.Z)
		local big = plot.items:FindFirstChild("biggerTrucks") ~= nil
		local m = FarmBuilder.vehicle(L.folder, "truck", plot.color, cf, big)
		m:SetAttribute("Plot", plot.index)
		m:SetAttribute("Park", n)
		m:SetAttribute("ParkAt", at)
		if docks then
			m:SetAttribute("Plan", "truckBack")
		end
		return m
	end

	-- The warehouse: slices A and B, the skeleton of the rest, and everything for one of each station ------------------
	BUILD.warehouse = function(L, plot)
		slice(L, plot, 1)
		slice(L, plot, 2)
		open(plot, 2)
		for k = 3, #SLICES - 1 do
			skeleton(L, k)
		end
		-- the front wall, round the people door and the truck door (all of it goes when the hub's front hall comes)
		local before = {}
		for _, c in L.folder:GetChildren() do
			before[c] = true
		end
		local fz = SLICES[1] + 0.4
		local pd, td = SPOTS.peopleDoor.X, SPOTS.truckDoor.X
		local PW, PH, TW, TH = 4, 8, 9, 11
		wall(L, (X0 + pd - PW / 2) / 2, fz, pd - PW / 2 - X0, 0.8, H, 0.5, -1)
		wall(L, (pd + PW / 2 + td - TW / 2) / 2, fz, td - TW / 2 - pd - PW / 2, 0.8, H, 0.5, -1)
		wall(L, (td + TW / 2 + X1) / 2, fz, X1 - td - TW / 2, 0.8, H, 0.5, -1)
		L:block(pd, fz, PW, 0.8, H - PH, { color = STEEL_WALL, name = "WarehouseWall" }, 0.5 + PH)
		L:block(td, fz, TW, 0.8, H - TH, { color = STEEL_WALL, name = "WarehouseWall" }, 0.5 + TH)
		for _, sx in { -1, 1 } do
			L:block(
				td + sx * (TW / 2 + 0.3),
				fz - 0.2,
				0.6,
				1.2,
				TH,
				deco({ color = P.safetyYellow, name = "DoorFrame" }),
				0.5
			)
			L:block(pd + sx * (PW / 2 + 0.2), fz - 0.2, 0.4, 1, PH, deco({ color = WHITE, name = "DoorFrame" }), 0.5)
		end
		L:box(td, 0.5 + TH + 0.3, fz - 0.2, TW + 1.2, 0.6, 1.2, deco({ color = P.safetyYellow, name = "DoorFrame" }))
		L:cyl(td, 0.5 + TH - 0.7, fz + 1, TW, 1.4, deco({ color = P.steel, name = "DoorDrum" }), "x")
		L:box(td, 0.55, fz - 1.4, TW, 0.04, 2.4, deco({ color = P.safetyYellow, name = "Hazard" }))
		-- the front's band and the big sign
		L:box((X0 + X1) / 2, H - 1.4, SLICES[1] - 0.1, X1 - X0, 1.6, 0.2, deco({ color = plot.color, name = "Band" }))
		local sign = L:box(22, H - 4.6, SLICES[1] - 0.15, 26, 3.4, 0.2, deco({ color = WHITE, name = "WarehouseSign" }))
		FarmBuilder.sign(sign, "FARM TO FLEET", nil, plot.color)
		-- the Operations screen over the station pads
		L:box(42, 11, SLICES[1] - 0.2, 21, 7.4, 0.3, deco({ color = INK, name = "ScreenFrame" }))
		local screen =
			L:box(42, 11, SLICES[1] - 0.4, 20, 6.6, 0.1, deco({ color = rgb(20, 26, 34), name = "OpsScreen" }))
		_ = screen
		-- the station pads
		for i, at in SPOTS.stations do
			local track = ({ "grow", "pack", "store", "ship" })[i]
			L:block(at.X, at.Z, 6.4, 5, 0.3, deco({ color = P.sunflower, name = "StationRim" }), 0.25)
			local pad = L:block(at.X, at.Z, 5.6, 4.2, 0.4, { color = WHITE, name = "StationPad" }, 0.25)
			pad:SetAttribute("Track", track)
		end
		-- the overhead conveyor from the shed's back wall into the warehouse
		local bx = 18
		L:box(bx, 9, (SLICES[1] - 46) / 2, 2.4, 0.6, 10.4, { color = P.steel, name = "Bridge" })
		L:box(bx, 9.35, (SLICES[1] - 46) / 2, 2, 0.1, 10.4, deco({ color = INK, name = "Belt" }))
		for _, z in { -44, -41, -38 } do
			L:block(bx, z, 1.2, 1.2, 1, deco({ color = CARDBOARD, name = "Box" }), 9.4)
		end
		for _, z in { -45, -37 } do
			L:block(bx, z, 0.5, 0.5, 8.7, deco({ color = P.steel, name = "BridgePost" }), 0)
		end
		L:block(64, -46, 14, 9, 0.12, deco({ color = P.asphalt, name = "Apron" }), 0.22)
		for _, c in L.folder:GetChildren() do
			if not before[c] and c.Name ~= "StationPad" and c.Name ~= "StationRim" then
				c:SetAttribute("Front", true)
			end
		end
		-- inside: the office (glass, a desk, its sign)
		L:block(13, -31.4, 14, 0.3, 7, { color = P.glass, name = "OfficeGlass", transparency = 0.35 }, 0.5)
		L:block(20, -33.7, 0.3, 4.6, 7, { color = P.glass, name = "OfficeGlass", transparency = 0.35 }, 0.5)
		L:box(13, 7.6, -33.7, 14.2, 0.3, 4.9, { color = STEEL_WALL, name = "OfficeRoof" })
		L:block(11, -34, 4, 2, 2.4, deco({ color = P.wood, name = "Desk" }), 0.5)
		L:box(
			11,
			3.4,
			-34.4,
			1.6,
			1,
			0.1,
			deco({ color = rgb(60, 160, 240), material = Enum.Material.Neon, name = "Monitor" })
		)
		local plate = L:box(13, 6, -31.2, 6, 1.2, 0.1, deco({ color = plot.color, name = "OfficeSign" }))
		FarmBuilder.sign(plate, "OFFICE", nil, WHITE)
		-- the inbound crates (filled as produce waits for the lines) and the drop chute from the bridge
		L:block(bx, -30, 2.4, 2.4, 0.4, deco({ color = P.steel, name = "Chute" }), 7.6)
		for i = 1, 8 do
			local x = 9.5 + ((i - 1) % 4) * 2.6
			local z = -24.5 + ((i - 1) // 4) * 2.6
			local crate = L:block(x, z, 2.2, 2.2, 1.8, { color = P.wood, name = "Inbound", transparency = 1 }, 0.5)
			crate:SetAttribute("Slot", i)
			local fruit = L:block(
				x,
				z,
				1.9,
				1.9,
				0.2,
				deco({ color = FRUIT[(i - 1) % #FRUIT + 1], name = "InboundFruit", transparency = 1 }),
				2.3
			)
			fruit:SetAttribute("Slot", i)
		end
		line(L, 1)
		-- the zones, labelled: where the produce comes in, the lines that box it, the pallets ready to go out
		FarmBuilder.hang(L, 13, 12, -21, "RECEIVING", P.safetyYellow, false, 10)
		FarmBuilder.hang(L, 32, 12, -28, "PACKING LINES", P.safetyYellow, false, 14)
		FarmBuilder.hang(L, 57, 12, -24, "ACTIVE ORDERS", rgb(120, 220, 120), true, 12)
		-- the staging floor: six pallet spots by the truck door, painted out
		for i = 1, 6 do
			local x = ({ 55, 59 })[(i - 1) % 2 + 1]
			local z = -31 + ((i - 1) // 2) * 4.5
			L:box(x, 0.53, z, 4.4, 0.02, 4.4, deco({ color = P.safetyYellow, name = "StageMark" }))
			local m = FarmBuilder.pallet(L, x, 0.5, z, "Staged", true)
			m:SetAttribute("Slot", i)
		end
		-- the cross aisle's lines
		for _, x in { 60.5, 69 } do
			L:box(
				x,
				0.53,
				(SLICES[2] + SLICES[#SLICES]) / 2,
				0.25,
				0.02,
				SLICES[#SLICES] - SLICES[2],
				deco({ color = P.safetyYellow, name = "LaneLine" })
			)
		end
		rack(L, 1)
		forklift(L, plot, 1)
		-- outside: the truck lane up the east edge, the lot behind the warehouse, the first box truck
		local lx = SPOTS.lane
		L:block(lx, (-110 + 30) / 2, 8, 140, 0.12, deco({ color = P.asphalt, name = "TruckLane" }), 0.22)
		L:block(59.5, 38, 41, 20, 0.12, deco({ color = P.asphalt, name = "TruckLot" }), 0.22)
		for _, at in SPOTS.lot do
			for _, sx in { -1, 1 } do
				L:box(at.X + sx * 3.4, 0.36, at.Z, 0.25, 0.02, 12, deco({ color = WHITE, name = "LotLine" }))
			end
		end
		for _, c in L.folder:GetChildren() do
			if c.Name == "TruckLot" or c.Name == "LotLine" then
				c:SetAttribute("OldLot", true) -- (the hub's back docks pave the court and move the lot)
			end
		end
		truck(L, plot, 1)
	end

	-- More of the warehouse: a slice a bay, its first rack row with it
	local function bay(k, row)
		return function(L, plot)
			open(plot, k)
			slice(L, plot, k)
			rack(L, row)
		end
	end
	-- The annex: a second giant warehouse out the back, its own sign, doors and crew, rack rows 9-16
	local function annexRows(L, rows)
		for _, row in rows do
			rack(L, row)
		end
	end
	BUILD.annex1 = function(L, plot)
		local c, size = PlotLayout.ANNEX, PlotLayout.ANNEX_SIZE
		local x0, x1 = c.X - size.X / 2, c.X + size.X / 2
		local z0, z1 = c.Z - size.Z / 2, c.Z + size.Z / 2
		L:block(c.X, c.Z, size.X + 2, size.Z + 2, 0.5, { color = P.concrete, name = "AnnexFloor" }, 0)
		for _, side in { { x0, z0, x0, z1 }, { x1, z0, x1, z1 } } do
			L:block(
				side[1],
				(side[2] + side[4]) / 2,
				0.6,
				size.Z,
				size.Y,
				{ color = STEEL_WALL, name = "AnnexWall" },
				0.5
			)
		end
		L:block(c.X, z1, size.X, 0.6, size.Y, { color = STEEL_WALL, name = "AnnexWall" }, 0.5)
		-- the front: wall either side of four big doors
		for k = 0, 4 do
			local x = x0 + 4 + k * 14
			L:block(x, z0, 8, 0.6, size.Y, { color = STEEL_WALL, name = "AnnexWall" }, 0.5)
		end
		for k = 1, 4 do
			local x = x0 + 4 + (k - 0.5) * 14
			L:box(x, 14, z0, 6, 7, 0.6, { color = STEEL_WALL, name = "AnnexWall" })
			local plate = L:box(x, 10.4, z0 - 0.4, 4, 1.4, 0.2, deco({ color = P.safetyYellow, name = "DockSign" }))
			FarmBuilder.sign(plate, `DOOR {k}`, "", INK)
		end
		local roof = L:box(c.X, size.Y + 0.8, c.Z, size.X + 1.4, 0.6, size.Z + 1.4, { color = RIB, name = "Roof" })
		roof:SetAttribute("Roof", true)
		roof:SetAttribute("Plot", plot.index)
		roof:SetAttribute("RoofMin", plot.cf * Vector3.new(x0, 0, z0))
		roof:SetAttribute("RoofMax", plot.cf * Vector3.new(x1, size.Y + 2, z1))
		local sign = L:box(c.X, size.Y - 2.5, z0 - 0.5, 30, 4, 0.4, deco({ color = plot.color, name = "AnnexSign" }))
		FarmBuilder.sign(sign, "WAREHOUSE ANNEX", "", WHITE)
		-- the drive back to it along the truck lane
		L:block(SPOTS.lane, (30 + z0) / 2, 8, z0 - 30, 0.12, deco({ color = P.asphalt, name = "TruckLane" }), 0.22)
		-- its own crew: parked forklifts by the doors
		for k = 1, 3 do
			local at = plot.cf * CFrame.new(x0 + 10 + k * 14, 0.5, z0 + 5) * CFrame.Angles(0, math.pi, 0)
			local f = FarmBuilder.forklift(L.folder, at, plot.color)
			f.Name = "AnnexForklift"
		end
		annexRows(L, { 9, 10, 11, 12 })
	end
	BUILD.annex2 = function(L)
		annexRows(L, { 13, 14, 15, 16 })
	end
	BUILD.bay2 = bay(3, 3)
	BUILD.bay3 = bay(4, 5)
	BUILD.bay4 = bay(5, 7)
	for _, row in { 2, 4, 6, 8 } do
		BUILD["rack" .. row] = function(L)
			rack(L, row)
		end
	end
	for k = 2, 4 do
		BUILD["packLine" .. k] = function(L)
			line(L, k)
		end
	end
	for n = 2, 5 do
		BUILD["forklift" .. n] = function(L, plot)
			forklift(L, plot, n)
		end
	end
	for n = 2, 4 do
		BUILD["boxTruck" .. n] = function(L, plot)
			truck(L, plot, n)
		end
	end

	-- Bigger trucks: every truck there now gets a longer box (trucks bought after are built long)
	BUILD.biggerTrucks = function(_, plot)
		for _, d in plot.items:GetDescendants() do
			if d.Name == "Vehicle" and d:GetAttribute("Kind") == "truck" and not d:GetAttribute("Big") then
				local cf = d:GetPivot()
				local parent = d.Parent
				local attrs = d:GetAttributes()
				d:Destroy()
				local m = FarmBuilder.vehicle(parent, "truck", plot.color, cf, true)
				for k, v in attrs do
					m:SetAttribute(k, v)
				end
				m:SetAttribute("Big", true)
			end
		end
	end

	-- Fast forklifts: a charging bay with its lights by the cross aisle
	BUILD.fastForklifts = function(L)
		L:block(67, -14, 5, 4, 3.4, { color = P.rackBlue, name = "Charger" }, 0.5)
		for k = 0, 2 do
			L:box(
				65.4 + k * 1.6,
				3,
				-16.05,
				0.8,
				0.8,
				0.05,
				deco({ color = rgb(80, 220, 110), material = Enum.Material.Neon, name = "ChargeLamp" })
			)
		end
		L:box(67, 4.2, -14, 5.2, 0.2, 4.2, deco({ color = P.safetyYellow, name = "ChargerTop" }))
	end

	-- The robot packer: a robot arm at the end of every line
	BUILD.autoPacker = function(L)
		for k = 1, 4 do
			local z = -33 + (k - 1) * 3.4
			L:cyl(46, 1.1, z + 1.3, 1.2, 1.4, deco({ color = P.steelLight, name = "RobotBase" }), "y")
			local arm = L:box(46, 3.2, z + 1.3, 0.6, 3, 0.6, deco({ color = P.rackOrange, name = "RobotArm" }))
			arm.CFrame = arm.CFrame * CFrame.Angles(math.rad(-25), 0, 0)
			L:box(46, 4.6, z + 0.6, 1.8, 0.5, 0.5, deco({ color = P.rackOrange, name = "RobotArm" }))
			L:box(46, 4.4, z, 0.6, 0.6, 0.6, deco({ color = INK, name = "Gripper" }))
		end
	end

	-- Pivot irrigation over the fields: towers on wheels carrying a long truss with drop sprinklers
	BUILD.irrigation = function(L)
		local z = 6.5
		local x0, x1 = -78, -10
		L:cyl(x1, 2, z, 4, 2, { color = P.steel, name = "PivotCenter" }, "y")
		L:box((x0 + x1) / 2, 7, z, x1 - x0, 0.5, 0.5, deco({ color = P.steelLight, name = "Truss" }))
		for i = 0, 3 do
			local x = x1 - (i + 1) * (x1 - x0) / 4
			L:box(x, 3.5, z, 0.4, 7, 0.4, deco({ color = P.steel, name = "Tower" }))
			for _, dz in { -1.2, 1.2 } do
				L:cyl(x, 0.8, z + dz, 0.5, 1.6, deco({ color = INK, name = "TowerWheel" }), "x")
			end
		end
		for i = 0, 16 do
			local x = x0 + 2 + i * 4
			L:box(x, 5.6, z, 0.1, 2.6, 0.1, deco({ color = P.steel, name = "Drop" }))
			L:box(x, 4.2, z, 0.5, 0.2, 0.5, deco({ color = P.water, name = "Spray", transparency = 0.3 }))
		end
	end

	-- Fertilizer tanks by the barn: three green tanks on a pad, a pipe to the fields
	BUILD.fertilizer = function(L)
		L:block(-22, -12, 13, 5, 0.3, { color = P.concrete, name = "TankPad" }, 0)
		for i, x in { -26, -22, -18 } do
			L:cyl(x, 3.4, -12, 6, 3.4, { color = rgb(60, 150, 80), name = "Tank" }, "y")
			L:cyl(x, 6.6, -12, 0.4, 3.6, deco({ color = WHITE, name = "TankCap" }), "y")
			L:box(
				x,
				3.4,
				-13.75,
				1.6,
				0.6,
				0.05,
				deco({ color = ({ P.sunflower, P.safetyYellow, P.sunflower })[i], name = "TankLabel" })
			)
		end
		L:box(-22, 1, -9.4, 0.4, 0.4, 3, deco({ color = P.steel, name = "Pipe" }))
	end

	-- Greenhouses behind the warehouse: glass houses on white frames, rows of plants inside
	BUILD.greenhouse = function(L)
		local c = SPOTS.greenhouses
		for _, dx in { -7, 7 } do
			local x = c.X + dx
			L:block(x, c.Z, 12, 26, 0.3, { color = P.concrete, name = "GreenhouseBase" }, 0)
			L:block(x, c.Z, 12, 26, 6, { color = P.glass, name = "Greenhouse", transparency = 0.45 }, 0.3)
			L:wedge(x - 3, 7.8, c.Z, 6, 3, 26, { color = P.glass, name = "GreenhouseRoof", transparency = 0.45 }, 90)
			L:wedge(x + 3, 7.8, c.Z, 6, 3, 26, { color = P.glass, name = "GreenhouseRoof", transparency = 0.45 }, -90)
			for k = 0, 4 do
				L:box(x, 3.4, c.Z - 12 + k * 6, 12.2, 6.4, 0.25, deco({ color = WHITE, name = "Frame" }))
			end
			for _, px in { -3, 3 } do
				L:block(x + px, c.Z, 2, 22, 1, deco({ color = rgb(110, 80, 60), name = "Bed" }), 0.3)
				for k = 0, 6 do
					L:block(
						x + px,
						c.Z - 10 + k * 3.3,
						1.4,
						1.4,
						1.4,
						deco({ color = FRUIT[(k % #FRUIT) + 1], name = "Plant" }),
						1.3
					)
				end
			end
		end
	end
	-- (stage 5's pieces: the hub)
	require(script.Parent.HubBuilder)(FarmBuilder, BUILD, {
		wall = wall,
		roofTag = roofTag,
		detail = detail,
		outside = outside,
		line = line,
		STEEL_WALL = STEEL_WALL,
		ROOF = ROOF,
		CARDBOARD = CARDBOARD,
		FRUIT = FRUIT,
	})
end
