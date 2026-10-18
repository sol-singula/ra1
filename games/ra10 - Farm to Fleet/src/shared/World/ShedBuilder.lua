--[[
Stage 3's pieces (master plan §4): the packing shed with its packing table, the loading door and the order board;
the paved yard, the delivery vans, the box line, the sorting machine, the loading dock, the pallet wrapper and the
warehouse's site. FarmBuilder hands over its BUILD table; this adds to it, and adds FarmBuilder.vehicle.

  FarmBuilder.vehicle(parent, kind ("van" | "pickup" | "truck"), color, cf, big?) -> Model   (its pivot on the
                     ground, nose to -Z; big: a bigger truck's longer box)
  the shed's parts the services look for: "PackPad" (the packing table's pad), "BoardSlot" x3 (attribute Slot)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local PlotLayout = require(script.Parent.PlotLayout)
local Shapes = require(script.Parent.Shapes)

local P = Constants.PALETTE
local deco = Shapes.deco
local SPOTS = PlotLayout.SPOTS
local INK = Color3.fromRGB(30, 30, 34)
local WHITE = Color3.fromRGB(250, 250, 248)
local rgb = Color3.fromRGB
local SIDING = rgb(120, 178, 150) -- the shed's sage-green siding
local ROOF = rgb(70, 74, 82)
local CARDBOARD = rgb(196, 150, 96)
local CRATE_FRUIT = { rgb(230, 40, 60), rgb(250, 130, 30), rgb(250, 210, 50), rgb(70, 80, 200), rgb(90, 170, 60) }

return function(FarmBuilder, BUILD)
	-- A cardboard box (with a tape strip and a fruit-coloured label)
	local function box(L, x, z, y0, k, color)
		L:block(x, z, 1.6, 1.6, 1.2, deco({ color = CARDBOARD, name = "Box" }), y0)
		L:box(x, y0 + 1.21, z, 0.4, 0.02, 1.62, deco({ color = rgb(170, 130, 80), name = "Tape" }))
		L:box(
			x,
			y0 + 0.6,
			z - 0.81,
			0.9,
			0.5,
			0.02,
			deco({ color = color or CRATE_FRUIT[k % #CRATE_FRUIT + 1], name = "BoxLabel" })
		)
	end

	-- A wooden pallet, and optionally a stack of boxes on it
	local function pallet(L, x, z, layers, wrapped)
		for _, dz in { -1.6, 0, 1.6 } do
			L:block(x, z + dz, 4, 0.6, 0.4, deco({ color = P.wood, name = "PalletRail" }), 0)
		end
		L:block(x, z, 4, 4, 0.2, { color = rgb(200, 160, 110), name = "Pallet" }, 0.4)
		local k = 0
		for layer = 0, (layers or 0) - 1 do
			for _, dx in { -0.9, 0.9 } do
				for _, dz in { -0.9, 0.9 } do
					k += 1
					box(L, x + dx, z + dz, 0.6 + layer * 1.2, k + layer)
				end
			end
		end
		if wrapped and (layers or 0) > 0 then
			L:block(
				x,
				z,
				3.9,
				3.9,
				layers * 1.2,
				deco({ color = rgb(220, 235, 245), transparency = 0.45, name = "Wrap", reflect = 0.1 }),
				0.6
			)
		end
	end

	-- Corrugated siding: a wall with thin ribs on its face (face: the side ribs stand out to)
	local function wall(L, x, z, w, d, h, y0, face)
		L:block(x, z, w, d, h, { color = SIDING, name = "ShedWall" }, y0)
		local along = w > d and "x" or "z"
		local len = along == "x" and w or d
		for k = 1, math.floor(len / 1.6) - 1 do
			local off = -len / 2 + k * 1.6
			if along == "x" then
				L:block(
					x + off,
					z + face * (d / 2 + 0.06),
					0.25,
					0.12,
					h,
					deco({ color = rgb(104, 160, 134), name = "Rib" }),
					y0
				)
			else
				L:block(
					x + face * (w / 2 + 0.06),
					z + off,
					0.12,
					0.25,
					h,
					deco({ color = rgb(104, 160, 134), name = "Rib" }),
					y0
				)
			end
		end
	end

	-- The packing shed ---------------------------------------------------------------------------------------------
	BUILD.shed = function(L, plot)
		local c = SPOTS.shed
		local W, H, D = PlotLayout.SHED.X, PlotLayout.SHED.Y, PlotLayout.SHED.Z
		local x0, x1, z0, z1 = c.X - W / 2, c.X + W / 2, c.Z - D / 2, c.Z + D / 2
		local y0 = 0.6
		L:block(c.X, c.Z, W + 2, D + 2, y0, { color = P.concrete, name = "ShedSlab" }, 0)
		L:block(c.X, c.Z, W - 1, D - 1, 0.05, deco({ color = P.concreteDark, name = "ShedFloor" }), y0)
		-- the walls: the back and the sides whole; the front with the loading door and the side door cut out
		wall(L, x0 + 0.4, c.Z, 0.8, D, H, y0, -1)
		wall(L, x1 - 0.4, c.Z, 0.8, D, H, y0, 1)
		local door = SPOTS.door
		local DW, DH = 9, 10 -- the loading door
		local side, SW, SH = SPOTS.packPad.X, 3.6, 7.4 -- the side door, over the packing table's pad
		local fz = z0 + 0.4
		-- (the front wall: pieces round the two doors)
		wall(L, (x0 + side - SW / 2) / 2, fz, side - SW / 2 - x0, 0.8, H, y0, -1)
		wall(L, (side + SW / 2 + door.X - DW / 2) / 2, fz, door.X - DW / 2 - side - SW / 2, 0.8, H, y0, -1)
		wall(L, (door.X + DW / 2 + x1) / 2, fz, x1 - door.X - DW / 2, 0.8, H, y0, -1)
		L:block(side, fz, SW, 0.8, H - SH, { color = SIDING, name = "ShedWall" }, y0 + SH)
		-- the back wall, with a door lined up with the side door (through the shed to the warehouse)
		local bz = z1 - 0.4
		wall(L, (x0 + side - SW / 2) / 2, bz, side - SW / 2 - x0, 0.8, H, y0, 1)
		wall(L, (side + SW / 2 + x1) / 2, bz, x1 - side - SW / 2, 0.8, H, y0, 1)
		L:block(side, bz, SW, 0.8, H - SH, { color = SIDING, name = "ShedWall" }, y0 + SH)
		L:block(door.X, fz, DW, 0.8, H - DH, { color = SIDING, name = "ShedWall" }, y0 + DH)
		-- white trim at the corners and the door frames
		for _, tx in { x0, x1 } do
			for _, tz in { z0, z1 } do
				L:block(tx, tz, 0.9, 0.9, H, deco({ color = WHITE, name = "Trim" }), y0)
			end
		end
		for _, sx in { -1, 1 } do
			L:block(
				door.X + sx * (DW / 2 + 0.3),
				fz - 0.1,
				0.6,
				1,
				DH,
				deco({ color = P.safetyYellow, name = "DoorFrame" }),
				y0
			)
			L:block(side + sx * (SW / 2 + 0.2), fz - 0.1, 0.4, 1, SH, deco({ color = WHITE, name = "DoorFrame" }), y0)
		end
		L:box(door.X, y0 + DH + 0.3, fz - 0.1, DW + 1.2, 0.6, 1, deco({ color = P.safetyYellow, name = "DoorFrame" }))
		-- the roll-up door, rolled up: a drum over the opening, a few slats showing
		L:cyl(door.X, y0 + DH - 0.7, fz + 0.9, DW, 1.4, deco({ color = P.steel, name = "DoorDrum" }), "x")
		for k = 0, 1 do
			L:box(
				door.X,
				y0 + DH - 1.7 - k * 0.6,
				fz + 0.5,
				DW - 0.4,
				0.5,
				0.15,
				deco({ color = P.steelLight, name = "Slat" })
			)
		end
		-- hazard stripes on the floor at the door, and its bumpers
		for k = 0, 4 do
			local stripe = L:box(
				door.X - DW / 2 + 0.9 + k * 1.8,
				y0 + 0.06,
				fz + 1.2,
				0.8,
				0.04,
				1.8,
				deco({ color = k % 2 == 0 and P.safetyYellow or P.safetyBlack, name = "Hazard" })
			)
			stripe.CFrame = stripe.CFrame * CFrame.Angles(0, math.rad(30), 0)
		end
		for _, sx in { -1, 1 } do
			L:block(door.X + sx * 3.2, fz - 0.7, 1, 0.6, 1.4, { color = INK, name = "Bumper" }, 0.6)
		end
		-- the roof: two low slopes front to back, an overhang, a ridge vent
		local rise = 4
		L:wedge(
			c.X,
			y0 + H + rise / 2,
			c.Z - D / 4 - 0.5,
			W + 2,
			rise,
			D / 2 + 1,
			{ color = ROOF, name = "ShedRoof" },
			180
		)
		L:wedge(
			c.X,
			y0 + H + rise / 2,
			c.Z + D / 4 + 0.5,
			W + 2,
			rise,
			D / 2 + 1,
			{ color = ROOF, name = "ShedRoof" },
			0
		)
		L:box(c.X, y0 + H + rise + 0.25, c.Z, W - 4, 0.5, 1.6, deco({ color = P.steelLight, name = "RidgeVent" }))
		L:box(c.X, y0 + H - 0.2, z0 - 0.6, W + 2, 0.4, 0.6, deco({ color = WHITE, name = "Gutter" }))
		-- the sign band over the front, in the farm's colour
		local band = L:box(
			(x0 + door.X - DW / 2) / 2 + 2,
			y0 + H - 2.2,
			fz - 0.55,
			18,
			2.6,
			0.3,
			deco({ color = plot.color, name = "ShedSign" })
		)
		FarmBuilder.sign(band, "PACKING SHED", nil, WHITE)
		-- windows along the sides
		for k = -1, 1 do
			for _, sx in { -1, 1 } do
				local wx = sx > 0 and x1 + 0.08 or x0 - 0.08
				L:box(
					wx,
					y0 + H - 5,
					c.Z + k * 8,
					0.1,
					2.4,
					4,
					deco({ color = P.glass, name = "Window", transparency = 0.15 })
				)
				L:box(wx, y0 + H - 5, c.Z + k * 8, 0.14, 2.8, 0.3, deco({ color = WHITE, name = "Mullion" }))
			end
		end
		-- inside: the packing table under the lights, boxes, pallets of produce, a rack of crates
		local tz = z0 + 6
		L:block(side + 2, tz, 10, 3.4, 3, { color = P.wood, name = "PackTable" }, y0)
		L:block(side + 2, tz, 10.4, 3.8, 0.3, deco({ color = P.steelLight, name = "TableTop" }), y0 + 3)
		for k = 0, 3 do
			box(L, side - 1.5 + k * 2.4, tz, y0 + 3.3, k)
		end
		for k = 0, 2 do
			L:box(
				side + 2 - 3 + k * 3,
				y0 + H - 1.4,
				tz,
				1.6,
				0.3,
				1.6,
				deco({ color = rgb(255, 245, 220), material = Enum.Material.Neon, name = "ShedLight" })
			)
		end
		pallet(L, door.X - 1, z1 - 6, 2)
		pallet(L, door.X + 5, z1 - 6, 3)
		pallet(L, x1 - 5, c.Z + 2, 1)
		for k = 0, 3 do
			L:block(
				x0 + 2.5,
				c.Z - 6 + k * 3.4,
				2.6,
				2.6,
				1.6 + (k % 2) * 1.6,
				{ color = CRATE_FRUIT[k + 1], name = "Crate" },
				y0
			)
		end
		-- the packing table's pad, just outside the side door
		local pp = SPOTS.packPad
		L:block(pp.X, pp.Z, 6, 4.6, 0.3, deco({ color = P.sunflower, name = "PackRim" }), 0.25)
		local pad = L:block(pp.X, pp.Z, 5.2, 3.8, 0.4, { color = WHITE, name = "PackPad" }, 0.25)
		FarmBuilder.label(pad, "PACK ORDERS", "stand here", P.sunflower)
		-- a gravel drive from the road to the loading door, and the turn to the vans' spots
		L:block(
			door.X,
			(-110 + z0) / 2 - 1,
			9,
			z0 - -110 - 2,
			0.12,
			deco({ color = rgb(176, 166, 150), name = "Drive" }),
			0.2
		)
		L:block(
			(door.X + SPOTS.parks[2].X) / 2 + 2,
			-88,
			SPOTS.parks[2].X - door.X + 8,
			12,
			0.12,
			deco({ color = rgb(176, 166, 150), name = "Drive" }),
			0.2
		)
		-- produce crates stacked by the door, waiting to be packed
		for k = 0, 4 do
			L:block(
				door.X + 7 + (k % 3) * 2.2,
				z0 - 2.4,
				2,
				2,
				1.4,
				{ color = P.wood, name = "Crate" },
				(k >= 3) and 1.4 or 0
			)
			L:block(
				door.X + 7 + (k % 3) * 2.2,
				z0 - 2.4,
				1.7,
				1.7,
				0.2,
				deco({ color = CRATE_FRUIT[k + 1], name = "CrateFruit" }),
				((k >= 3) and 1.4 or 0) + 1.4
			)
		end
		-- the order board
		local b = SPOTS.board
		for _, sx in { -1, 1 } do
			L:block(b.X + sx * 6.4, b.Z, 0.6, 0.6, 9, { color = P.wood, name = "BoardPost" }, 0)
		end
		L:box(b.X, 5.2, b.Z, 13.4, 7, 0.5, { color = P.wood, name = "Board" })
		L:box(b.X, 9.3, b.Z, 14.6, 0.4, 2, deco({ color = plot.color, name = "BoardRoof" }))
		local head = L:box(b.X, 8.2, b.Z - 0.3, 12.6, 1.4, 0.1, deco({ color = rgb(40, 70, 56), name = "BoardHead" }))
		FarmBuilder.sign(head, "ORDERS", nil, WHITE)
		for slot = 1, 3 do
			local part = L:box(
				b.X - 4.2 + (slot - 1) * 4.2,
				4.6,
				b.Z - 0.3,
				3.9,
				5.6,
				0.1,
				deco({ color = rgb(40, 70, 56), name = "BoardSlot" })
			)
			part:SetAttribute("Slot", slot)
			FarmBuilder.board(part, "", {})
		end
	end

	-- The paved yard: asphalt in front of the shed, painted bays, kerbs, two lamps, planters
	BUILD.yard = function(L)
		local x0, x1, z0, z1 = 20, 80, -108, -75
		L:block((x0 + x1) / 2, (z0 + z1) / 2, x1 - x0, z1 - z0, 0.1, deco({ color = P.asphalt, name = "Yard" }), 0.26)
		for _, park in SPOTS.parks do
			for _, sx in { -1, 1 } do
				L:box(park.X + sx * 4, 0.38, park.Z - 1, 0.3, 0.02, 12, deco({ color = WHITE, name = "BayLine" }))
			end
		end
		for k = 0, 4 do
			L:box(
				SPOTS.door.X,
				0.38,
				z0 + 4 + k * 5,
				0.4,
				0.02,
				2.4,
				deco({ color = P.safetyYellow, name = "LaneDash" })
			)
		end
		for _, kx in { x0, x1 } do
			L:block(kx, (z0 + z1) / 2, 0.8, z1 - z0, 0.5, { color = P.concrete, name = "Kerb" }, 0)
		end
		for _, lx in { 30, 68 } do
			L:block(lx, -104, 0.5, 0.5, 12, { color = P.steel, name = "LampPost" }, 0)
			L:box(lx - 1, 12, -104, 2.4, 0.4, 0.9, deco({ color = P.steel, name = "LampArm" }))
			L:box(
				lx - 1.8,
				11.7,
				-104,
				1.2,
				0.2,
				0.7,
				deco({ color = rgb(255, 245, 220), material = Enum.Material.Neon, name = "LampLight" })
			)
		end
		for _, px in { 31, 56 } do
			L:block(px, -76.6, 4, 1.6, 1, { color = P.concrete, name = "Planter" }, 0)
			for k = 0, 2 do
				L:block(px - 1.2 + k * 1.2, -76.6, 1, 1, 0.8, deco({ color = CRATE_FRUIT[k + 2], name = "Flower" }), 1)
			end
		end
	end

	-- A vehicle: the farm's van (a box van in the farm's colour) or a buyer's pickup with crates in the bed
	function FarmBuilder.vehicle(parent, kind, color, cf, big)
		local model = Instance.new("Model")
		model.Name = "Vehicle"
		model:SetAttribute("Kind", kind)
		model.Parent = parent
		local s = Shapes.new(model, cf)
		local function wheels(z1, z2, half)
			for _, z in { z1, z2 } do
				for _, sx in { -1, 1 } do
					s:cyl(sx * half, 0.95, z, 0.8, 1.9, deco({ color = INK, name = "Wheel" }), "x")
					s:cyl(sx * (half + 0.42), 0.95, z, 0.06, 1, deco({ color = P.steelLight, name = "Hub" }), "x")
				end
			end
		end
		if kind == "van" then
			-- the cab at the front (-Z), the box behind, the farm's colour on the cab and a stripe on the box
			s:box(0, 2.3, -3.4, 4.6, 2.8, 2.8, deco({ color = color, name = "Cab" }))
			s:box(0, 3.2, -4.75, 4.2, 1.4, 0.1, deco({ color = P.glass, name = "Windscreen", transparency = 0.1 }))
			for _, sx in { -1, 1 } do
				s:box(sx * 2.31, 3.1, -3.6, 0.05, 1.2, 1.6, deco({ color = P.glass, name = "SideWindow" }))
				s:box(
					sx * 1.6,
					1.6,
					-4.85,
					0.8,
					0.5,
					0.1,
					deco({ color = rgb(255, 250, 220), material = Enum.Material.Neon, name = "Headlight" })
				)
				s:box(
					sx * 1.9,
					1.4,
					4.7,
					0.5,
					0.8,
					0.1,
					deco({ color = P.dockRed, material = Enum.Material.Neon, name = "TailLight" })
				)
			end
			s:box(0, 0.9, -4.95, 4.7, 0.6, 0.3, deco({ color = INK, name = "Bumper" }))
			local body = s:box(0, 3.1, 1.6, 4.8, 4.6, 6.4, deco({ color = WHITE, name = "VanBox" }))
			for _, sx in { -1, 1 } do
				local stripe = s:box(sx * 2.42, 2.4, 1.6, 0.05, 0.9, 6.2, deco({ color = color, name = "Stripe" }))
				FarmBuilder.sign(
					stripe,
					"FARM TO FLEET",
					nil,
					WHITE,
					sx > 0 and Enum.NormalId.Right or Enum.NormalId.Left
				)
			end
			s:box(0, 3.1, 4.82, 4.4, 4.2, 0.05, deco({ color = P.steelLight, name = "BackDoor" }))
			s:box(0, 0.8, 1, 4.4, 0.6, 9, deco({ color = INK, name = "Chassis" }))
			wheels(-3.2, 3.2, 2.1)
			model:SetAttribute("Body", body.Name)
		elseif kind == "truck" then
			-- a box truck (stage 4): a tall cab in the farm's colour, a long box (longer still with bigger trucks)
			local len = big and 11 or 8
			s:box(0, 2.8, -4.4, 5, 3.6, 3.2, deco({ color = color, name = "Cab" }))
			s:box(0, 3.9, -6.03, 4.4, 1.5, 0.1, deco({ color = P.glass, name = "Windscreen", transparency = 0.1 }))
			s:box(0, 5, -4.6, 4.6, 0.6, 2.6, deco({ color = color, name = "CabRoof" }))
			for _, sx in { -1, 1 } do
				s:box(
					sx * 1.7,
					1.7,
					-6.1,
					0.9,
					0.6,
					0.1,
					deco({ color = rgb(255, 250, 220), material = Enum.Material.Neon, name = "Headlight" })
				)
				s:box(sx * 2.55, 3.6, -5.6, 0.3, 0.9, 0.2, deco({ color = INK, name = "Mirror" }))
			end
			s:box(0, 1, -6.2, 5.1, 0.7, 0.3, deco({ color = P.steelLight, name = "Bumper" }))
			local zb = -2.6 + len / 2 + 0.2
			s:box(0, 3.9, zb, 5.2, 5.6, len, deco({ color = WHITE, name = "TruckBox" }))
			for _, sx in { -1, 1 } do
				local stripe = s:box(sx * 2.62, 3.2, zb, 0.05, 1.4, len - 0.4, deco({ color = color, name = "Stripe" }))
				FarmBuilder.sign(
					stripe,
					"FARM TO FLEET",
					nil,
					WHITE,
					sx > 0 and Enum.NormalId.Right or Enum.NormalId.Left
				)
			end
			s:box(0, 3.9, zb + len / 2 + 0.03, 4.8, 5.2, 0.05, deco({ color = P.steelLight, name = "BackDoor" }))
			s:box(0, 0.9, zb - 1, 4.6, 0.6, len + 4, deco({ color = INK, name = "Chassis" }))
			wheels(-4.4, zb + len / 2 - 1.6, 2.3)
			if big then
				wheels(zb + len / 2 - 3.6, zb + len / 2 - 3.6, 2.3)
			end
		else
			-- the buyer's pickup: a rounded cab, a bed with crates of produce
			s:box(0, 1.6, -2.6, 4.2, 1.3, 3.2, deco({ color = color, name = "Hood" }))
			s:box(0, 2.9, -0.4, 4.2, 2, 2.4, deco({ color = color, name = "Cab" }))
			s:box(0, 3.1, -1.65, 3.8, 1.3, 0.1, deco({ color = P.glass, name = "Windscreen" }))
			s:box(0, 1.5, 2.6, 4.2, 1, 4.6, deco({ color = color, name = "Bed" }))
			for _, sx in { -1, 1 } do
				s:box(sx * 2, 2.3, 2.6, 0.2, 0.8, 4.6, deco({ color = color, name = "BedSide" }))
				s:box(
					sx * 1.5,
					1.7,
					-4.25,
					0.7,
					0.45,
					0.1,
					deco({ color = rgb(255, 250, 220), material = Enum.Material.Neon, name = "Headlight" })
				)
			end
			s:box(0, 0.9, -4.3, 4.3, 0.5, 0.3, deco({ color = P.steelLight, name = "Bumper" }))
			for k = 0, 2 do
				s:box(-1 + (k % 2) * 2, 2.6, 1.4 + k * 1.1, 1.6, 1.2, 1, deco({ color = P.wood, name = "Crate" }))
				s:box(
					-1 + (k % 2) * 2,
					3.25,
					1.4 + k * 1.1,
					1.3,
					0.15,
					0.8,
					deco({ color = CRATE_FRUIT[k + 1], name = "CrateFruit" })
				)
			end
			wheels(-2.6, 2.8, 2)
		end
		model.WorldPivot = cf
		return model
	end

	local function van(L, plot, n)
		local park = SPOTS.parks[n]
		local cf = L.cf * CFrame.new(park.X, 0, park.Z) * CFrame.Angles(0, math.rad(180), 0)
		local model = FarmBuilder.vehicle(L.folder, "van", plot.color, cf)
		model:SetAttribute("Plot", plot.index)
		model:SetAttribute("Park", n)
		return model
	end
	BUILD.van = function(L, plot)
		van(L, plot, 1)
	end
	BUILD.van2 = function(L, plot)
		van(L, plot, 2)
	end

	-- The bigger order board: lights round it and a header that glows
	BUILD.orderBoard = function(L)
		local b = SPOTS.board
		for k = 0, 9 do
			L:box(
				b.X - 6.3 + k * 1.4,
				9.7,
				b.Z - 0.9,
				0.4,
				0.4,
				0.4,
				deco({ color = k % 2 == 0 and P.sunflower or WHITE, material = Enum.Material.Neon, name = "Bulb" })
			)
		end
		L:box(b.X, 1.2, b.Z - 1.2, 13.4, 0.4, 1.4, deco({ color = P.wood, name = "BoardShelf" }))
		for k = 0, 3 do
			L:block(
				b.X - 4.5 + k * 3,
				b.Z - 1.2,
				1.2,
				1.2,
				1,
				deco({ color = CRATE_FRUIT[k + 1], name = "ShelfFruit" }),
				1.4
			)
		end
	end

	-- The box line: a belt from the fields' side into the shed's west wall, boxes riding it, a folding machine
	BUILD.boxLine = function(L)
		local a = SPOTS.boxLine
		local x1 = SPOTS.shed.X - PlotLayout.SHED.X / 2
		local len = x1 - a.X
		L:block((a.X + x1) / 2, a.Z, len, 3, 2.2, { color = P.steel, name = "BoxBelt" }, 0)
		L:block((a.X + x1) / 2, a.Z, len, 2.4, 0.1, deco({ color = INK, name = "Belt" }), 2.2)
		for k = 0, math.floor(len / 3) - 1 do
			box(L, a.X + 1.5 + k * 3, a.Z, 2.3, k)
		end
		L:block(a.X - 2, a.Z, 4.4, 4.4, 4.6, { color = P.rackOrange, name = "BoxFolder" }, 0)
		L:block(a.X - 2, a.Z, 3, 3, 0.8, deco({ color = CARDBOARD, name = "FlatBoxes" }), 4.6)
		L:box(
			a.X - 2,
			3.4,
			a.Z - 2.22,
			2.4,
			1,
			0.05,
			deco({ color = rgb(80, 220, 110), material = Enum.Material.Neon, name = "Lamp" })
		)
	end

	-- The sorting machine: a hopper, a drum and coloured chutes into bins
	BUILD.sorter = function(L)
		local c = SPOTS.sorter
		L:block(c.X, c.Z, 8, 6, 0.4, { color = P.concrete, name = "SorterBase" }, 0)
		L:block(c.X, c.Z, 4, 4, 5, { color = P.rackBlue, name = "Sorter" }, 0.4)
		L:wedge(c.X, 6.6, c.Z, 4.4, 2.4, 4.4, { color = P.steelLight, name = "Hopper" }, 180)
		L:cyl(c.X, 3.4, c.Z - 2.4, 3.6, 2.2, deco({ color = P.steel, name = "Drum" }), "x")
		for k, color in { P.dockRed, P.sunflower, P.dockGreen } do
			local cx = c.X - 2.6 + (k - 1) * 2.6
			local chute = L:box(cx, 1.8, c.Z - 4, 1.2, 0.3, 3, deco({ color = color, name = "Chute" }))
			chute.CFrame = chute.CFrame * CFrame.Angles(math.rad(25), 0, 0)
			L:block(cx, c.Z - 5.6, 2, 1.8, 1.4, { color = color, name = "Bin" }, 0)
		end
	end

	-- The loading dock: a raised concrete lip at the door, black bumpers, a canopy, green and red dock lights
	BUILD.loadingDock = function(L)
		local d = SPOTS.door
		L:block(d.X, d.Z - 1.4, 11, 2.4, 1.2, { color = P.concrete, name = "Dock" }, 0)
		for _, sx in { -1, 1 } do
			L:block(d.X + sx * 3.8, d.Z - 2.8, 1.2, 0.5, 1.4, { color = INK, name = "DockBumper" }, 0)
			L:box(
				d.X + sx * 6.2,
				9,
				d.Z - 0.6,
				0.6,
				1.2,
				0.3,
				deco({ color = sx < 0 and P.dockGreen or P.dockRed, material = Enum.Material.Neon, name = "DockLight" })
			)
		end
		L:box(d.X, 11.8, d.Z - 2.4, 13, 0.4, 5, { color = P.safetyYellow, name = "Canopy" })
		for k = 0, 5 do
			L:box(
				d.X - 5.5 + k * 2.2,
				11.5,
				d.Z - 4.85,
				1,
				0.3,
				0.1,
				deco({ color = k % 2 == 0 and P.safetyBlack or P.safetyYellow, name = "CanopyStripe" })
			)
		end
	end

	-- The pallet wrapper: a turntable, a mast with its roll of film, wrapped pallets waiting
	BUILD.wrapper = function(L)
		local c = SPOTS.wrapper
		L:cyl(c.X, 0.4, c.Z, 0.6, 6, { color = P.steel, name = "Turntable" }, "y")
		L:block(c.X + 3.6, c.Z, 0.8, 0.8, 8, { color = P.rackOrange, name = "Mast" }, 0)
		L:cyl(c.X + 3, 4, c.Z, 2, 0.8, deco({ color = rgb(220, 235, 245), name = "FilmRoll" }), "y")
		pallet(L, c.X, c.Z, 2, true)
		pallet(L, c.X - 8, c.Z + 2, 3, true)
		pallet(L, c.X - 8, c.Z - 3, 2, true)
	end

	-- The warehouse's site: a long concrete footprint, stakes and string, a sign
	BUILD.warehouseDeed = function(L, plot)
		local c = SPOTS.warehouseSite
		local w, d = PlotLayout.WAREHOUSE.X, PlotLayout.WAREHOUSE.Z
		L:block(c.X, c.Z, w, d, 0.15, deco({ color = P.concrete, name = "WarehouseSite" }), 0.24)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				L:block(
					c.X + sx * w / 2,
					c.Z + sz * d / 2,
					0.4,
					0.4,
					2,
					deco({ color = P.safetyYellow, name = "Stake" }),
					0
				)
			end
		end
		local board = L:box(c.X, 3, c.Z - d / 2 - 1, 12, 2.8, 0.3, deco({ color = P.cream, name = "SiteSign" }))
		FarmBuilder.sign(board, "WAREHOUSE", "coming soon", plot.color)
	end
end
