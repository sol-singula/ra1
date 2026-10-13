-- Builds an arena for a round: a walled square of studded floor with cover, houses or props, towers with ramps
-- and bridges, and a centrepiece, in the map's theme. Three sizes (half widths from Constants.MAP_SIZES).
-- The same map and size always comes out the same (seeded), so players learn the maps.
-- Returns { model, spawns = { Vector3 }, center, half, floorY, key, size }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Scenery = require(script.Parent.Scenery)

local MapBuilder = {}

MapBuilder.ARENA_CENTER = Vector3.new(0, 0, 1400)
MapBuilder.WALL_HEIGHT = 30

local part, rgb = Scenery.part, Scenery.rgb
local INK = rgb(30, 30, 44)

local function sizeOf(sizeKey)
	for _, s in Constants.MAP_SIZES do
		if s.key == sizeKey then
			return s
		end
	end
	return Constants.MAP_SIZES[1]
end

-- Which size fits this many players.
function MapBuilder.sizeFor(players)
	for _, s in Constants.MAP_SIZES do
		if players <= s.maxPlayers then
			return s.key
		end
	end
	return Constants.MAP_SIZES[#Constants.MAP_SIZES].key
end

local function block(parent, name, size, pos, color, material, extra)
	local props = {
		Name = name,
		Size = size,
		CFrame = typeof(pos) == "CFrame" and pos or CFrame.new(pos),
		Color = color,
		Material = material or Enum.Material.Plastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end

local function wedge(parent, size, cf, color)
	local w = Instance.new("WedgePart")
	w.Name = "Ramp"
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = Enum.Material.Plastic
	w.Anchored = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

local function ball(parent, name, pos, d, color, material)
	return part({
		Name = name,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(d, d, d),
		CFrame = CFrame.new(pos),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

local function cylinder(parent, name, pos, d, h, color, material)
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(h, d, d),
		CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	})
end

-- Footprints taken so far (x, z, half-x, half-z), so nothing overlaps and spawns stay clear.
local function overlaps(taken, x, z, hx, hz, pad)
	for _, r in taken do
		if math.abs(x - r[1]) < hx + r[3] + pad and math.abs(z - r[2]) < hz + r[4] + pad then
			return true
		end
	end
	return false
end

-- Props --------------------------------------------------------------------------------------------------------
local function house(parent, theme, pos, w, d, h, rng)
	local color = theme.cover[rng:NextInteger(1, #theme.cover)]
	block(parent, "House", Vector3.new(w, h, d), pos + Vector3.new(0, h / 2, 0), color)
	-- a roof: two wedges
	local roofH = math.min(5, w / 2)
	wedge(
		parent,
		Vector3.new(d + 1, roofH, w / 2 + 0.5),
		CFrame.new(pos + Vector3.new(-w / 4, h + roofH / 2, 0)) * CFrame.Angles(0, math.rad(90), 0),
		theme.roof
	)
	wedge(
		parent,
		Vector3.new(d + 1, roofH, w / 2 + 0.5),
		CFrame.new(pos + Vector3.new(w / 4, h + roofH / 2, 0)) * CFrame.Angles(0, math.rad(-90), 0),
		theme.roof
	)
	-- windows (just dark panes on the faces, not holes)
	for _, side in { -1, 1 } do
		block(
			parent,
			"Window",
			Vector3.new(2.2, 2.2, 0.2),
			pos + Vector3.new(0, h * 0.6, side * (d / 2 + 0.1)),
			rgb(60, 90, 130),
			Enum.Material.Glass,
			{ CanCollide = false }
		)
	end
	block(
		parent,
		"Door",
		Vector3.new(2.4, 4, 0.2),
		pos + Vector3.new(w / 4, 2, d / 2 + 0.1),
		rgb(120, 80, 50),
		Enum.Material.Wood,
		{ CanCollide = false }
	)
end

local function crate(parent, theme, pos, s, rng)
	local color = theme.cover[rng:NextInteger(1, #theme.cover)]
	block(parent, "Crate", Vector3.new(s, s, s), pos + Vector3.new(0, s / 2, 0), color)
	if theme.props == "dock" then
		block(
			parent,
			"Stripe",
			Vector3.new(s + 0.1, 0.5, s + 0.1),
			pos + Vector3.new(0, s * 0.7, 0),
			theme.accent,
			Enum.Material.Neon,
			{ CanCollide = false, CanQuery = false }
		)
	end
end

local function lollipop(parent, theme, pos, rng)
	local h = rng:NextInteger(9, 14)
	cylinder(parent, "Stick", pos + Vector3.new(0, h / 2, 0), 1, h, rgb(255, 255, 255))
	local candy = cylinder(
		parent,
		"Candy",
		pos + Vector3.new(0, h + 2.5, 0),
		7,
		1.4,
		theme.cover[rng:NextInteger(1, #theme.cover)]
	)
	candy.CFrame = CFrame.new(pos + Vector3.new(0, h + 2.5, 0))
	ball(parent, "Swirl", pos + Vector3.new(0, h + 2.5, 0), 2.4, rgb(255, 255, 255))
end

local function tree(parent, pos, rng)
	local h = rng:NextInteger(5, 8)
	block(
		parent,
		"Trunk",
		Vector3.new(1.4, h, 1.4),
		pos + Vector3.new(0, h / 2, 0),
		rgb(120, 80, 50),
		Enum.Material.Wood
	)
	ball(parent, "Leaves", pos + Vector3.new(0, h + 2.5, 0), 7, rgb(70, 170, 70), Enum.Material.Plastic)
end

local function wallBit(parent, theme, pos, len, h, alongX)
	local size = alongX and Vector3.new(len, h, 2) or Vector3.new(2, h, len)
	block(parent, "WallBit", size, pos + Vector3.new(0, h / 2, 0), theme.wall, Enum.Material.Plastic)
	if theme.props == "castle" then
		for i = 0, math.floor(len / 3) - 1 do
			local off = -len / 2 + 1.5 + i * 3
			if i % 2 == 0 then
				local p = alongX and Vector3.new(off, 0, 0) or Vector3.new(0, 0, off)
				block(parent, "Merlon", Vector3.new(1.6, 1.4, 2), pos + p + Vector3.new(0, h + 0.7, 0), theme.wall)
			end
		end
	end
end

-- A tower: a platform on four posts, a ramp up, and a little railing. Returns its top centre.
local function tower(parent, theme, pos, rng)
	local h = rng:NextInteger(10, 14)
	local s = 10
	local top = pos + Vector3.new(0, h, 0)
	block(parent, "Deck", Vector3.new(s, 1, s), top + Vector3.new(0, -0.5, 0), theme.path)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		block(
			parent,
			"Post",
			Vector3.new(1.2, h - 1, 1.2),
			pos + Vector3.new(c[1] * (s / 2 - 0.6), (h - 1) / 2, c[2] * (s / 2 - 0.6)),
			theme.wall
		)
	end
	-- railing (low, so you can shoot over it while scoped)
	for _, side in { -1, 1 } do
		block(parent, "Rail", Vector3.new(s, 2.2, 0.6), top + Vector3.new(0, 1.1, side * (s / 2 - 0.3)), theme.accent)
	end
	block(parent, "Rail", Vector3.new(0.6, 2.2, s), top + Vector3.new(s / 2 - 0.3, 1.1, 0), theme.accent)
	-- ramp up the open side (-X)
	local rampLen = h * 1.6
	wedge(
		parent,
		Vector3.new(4, h, rampLen),
		CFrame.new(pos + Vector3.new(-s / 2 - rampLen / 2, h / 2, 0)) * CFrame.Angles(0, math.rad(90), 0),
		theme.path
	)
	return top, rampLen
end

local function centerpiece(parent, theme, c, rng)
	if theme.props == "town" then
		cylinder(parent, "Fountain", c + Vector3.new(0, 1, 0), 14, 2, rgb(200, 200, 210))
		cylinder(parent, "Water", c + Vector3.new(0, 2.05, 0), 12, 0.2, rgb(80, 170, 255), Enum.Material.Glass)
		block(parent, "Spout", Vector3.new(2, 6, 2), c + Vector3.new(0, 3, 0), rgb(200, 200, 210))
		ball(parent, "SpoutTop", c + Vector3.new(0, 6.5, 0), 3, rgb(80, 170, 255), Enum.Material.Glass)
	elseif theme.props == "candy" then
		ball(parent, "Gumdrop", c + Vector3.new(0, 4, 0), 12, rgb(255, 120, 170))
		ball(parent, "Cherry", c + Vector3.new(0, 10.5, 0), 3, rgb(230, 30, 50))
	elseif theme.props == "dock" then
		cylinder(parent, "Pad", c + Vector3.new(0, 0.5, 0), 16, 1, rgb(110, 115, 150))
		block(parent, "Rocket", Vector3.new(5, 16, 5), c + Vector3.new(0, 9, 0), rgb(235, 235, 245))
		wedge(parent, Vector3.new(5, 4, 3), CFrame.new(c + Vector3.new(0, 19, 0.0)), rgb(220, 60, 60))
		for _, s in { -1, 1 } do
			block(parent, "Fin", Vector3.new(0.6, 5, 3), c + Vector3.new(s * 3, 3.5, 0), rgb(220, 60, 60))
		end
		block(
			parent,
			"Window",
			Vector3.new(5.1, 2, 2),
			c + Vector3.new(0, 13, 0),
			rgb(120, 220, 255),
			Enum.Material.Neon,
			{ CanCollide = false }
		)
	else
		-- castle: a small keep you can walk around
		block(parent, "Keep", Vector3.new(12, 14, 12), c + Vector3.new(0, 7, 0), theme.wall)
		for _, corner in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
			block(
				parent,
				"Merlon",
				Vector3.new(2.5, 2, 2.5),
				c + Vector3.new(corner[1] * 4.75, 15, corner[2] * 4.75),
				theme.wall
			)
		end
		block(parent, "Banner", Vector3.new(0.3, 5, 3), c + Vector3.new(6.2, 9, 0), theme.accent, Enum.Material.Fabric)
	end
	_ = rng
end

-- Build ----------------------------------------------------------------------------------------------------------
function MapBuilder.build(mapKey, sizeKey, parent, center)
	local theme = Maps.byKey[mapKey] or Maps.list[1]
	local size = sizeOf(sizeKey)
	local H = size.half
	local c = center or MapBuilder.ARENA_CENTER
	local seed = #mapKey * 131 + H
	for i = 1, #mapKey do
		seed += string.byte(mapKey, i) * i
	end
	local rng = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = "Arena_" .. theme.key
	-- floor, a path cross, and the walls
	block(model, "Floor", Vector3.new(H * 2 + 8, 2, H * 2 + 8), c + Vector3.new(0, -1, 0), theme.floor)
	block(
		model,
		"PathX",
		Vector3.new(H * 2, 0.2, 10),
		c + Vector3.new(0, 0.1, 0),
		theme.path,
		nil,
		{ CanCollide = false }
	)
	block(
		model,
		"PathZ",
		Vector3.new(10, 0.2, H * 2),
		c + Vector3.new(0, 0.1, 0),
		theme.path,
		nil,
		{ CanCollide = false }
	)
	local WH = MapBuilder.WALL_HEIGHT
	for _, s in { -1, 1 } do
		block(model, "Wall", Vector3.new(H * 2 + 8, WH, 4), c + Vector3.new(0, WH / 2, s * (H + 2)), theme.wall)
		block(model, "Wall", Vector3.new(4, WH, H * 2 + 8), c + Vector3.new(s * (H + 2), WH / 2, 0), theme.wall)
		block(
			model,
			"WallTrim",
			Vector3.new(H * 2 + 8, 1, 4.4),
			c + Vector3.new(0, WH, s * (H + 2)),
			theme.accent,
			nil,
			{ CanCollide = false }
		)
		block(
			model,
			"WallTrim",
			Vector3.new(4.4, 1, H * 2 + 8),
			c + Vector3.new(s * (H + 2), WH, 0),
			theme.accent,
			nil,
			{ CanCollide = false }
		)
	end
	-- an invisible lid so nobody climbs out
	block(
		model,
		"Lid",
		Vector3.new(H * 2 + 8, 1, H * 2 + 8),
		c + Vector3.new(0, WH + 40, 0),
		INK,
		nil,
		{ Transparency = 1, CanQuery = false }
	)

	-- spawns: around the edge every ~18 studs, plus four inside
	local spawns = {}
	local taken = {}
	local step = 18
	local n = math.floor((H * 2 - 12) / step)
	for i = 0, n do
		local t = -H + 6 + i * ((H * 2 - 12) / math.max(1, n))
		for _, p in
			{
				Vector3.new(t, 0, -H + 6),
				Vector3.new(t, 0, H - 6),
				Vector3.new(-H + 6, 0, t),
				Vector3.new(H - 6, 0, t),
			}
		do
			local dup = false
			for _, q in spawns do
				if (q - (c + p)).Magnitude < 8 then
					dup = true
				end
			end
			if not dup then
				table.insert(spawns, c + p)
				table.insert(taken, { p.X, p.Z, 3, 3 })
			end
		end
	end
	for _, p in
		{ Vector3.new(-H / 2, 0, 0), Vector3.new(H / 2, 0, 0), Vector3.new(0, 0, -H / 2), Vector3.new(0, 0, H / 2) }
	do
		table.insert(spawns, c + p)
		table.insert(taken, { p.X, p.Z, 3, 3 })
	end
	-- keep the paths mostly open and the centre for the centrepiece
	table.insert(taken, { 0, 0, 9, 9 })
	centerpiece(model, theme, c, rng)

	-- towers in the four quadrants (two on small maps), bridges between neighbours on big maps
	local towers = {}
	local tq = H >= 60 and { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } or { { -1, -1 }, { 1, 1 } }
	for _, q in tq do
		local tx, tz = q[1] * H * 0.55, q[2] * H * 0.55
		local top, rampLen = tower(model, theme, c + Vector3.new(tx, 0, tz), rng)
		table.insert(towers, top)
		table.insert(taken, { tx - rampLen / 2, tz, 5 + rampLen / 2, 6 })
		table.insert(spawns, top + Vector3.new(0, 0, 0))
	end
	if H >= 80 then
		for i = 1, 2 do
			local a, b = towers[i * 2 - 1], towers[i * 2]
			if a and b and math.abs(a.Z - b.Z) < 1 then
				local mid = (a + b) / 2
				local len = math.abs(a.X - b.X) - 10
				if len > 4 then
					block(model, "Bridge", Vector3.new(len, 0.8, 4), mid + Vector3.new(0, -0.4, 0), theme.path)
				end
			end
		end
	end

	-- cover on a grid: low walls, crates, houses/props
	local cell = 14
	local cells = math.floor((H * 2 - 8) / cell)
	for gx = 0, cells - 1 do
		for gz = 0, cells - 1 do
			local x = -H + 4 + cell / 2 + gx * cell + rng:NextNumber(-3, 3)
			local z = -H + 4 + cell / 2 + gz * cell + rng:NextNumber(-3, 3)
			local roll = rng:NextNumber()
			local onPath = math.abs(x) < 6 or math.abs(z) < 6
			if onPath then
				roll = roll * 0.4 -- only small things on the paths
			end
			local base = c + Vector3.new(x, 0, z)
			if roll < 0.3 then
				-- empty: open ground is important for sniping
				_ = roll
			elseif roll < 0.55 then
				local len = rng:NextInteger(6, 10)
				local alongX = rng:NextNumber() < 0.5
				local hx, hz = alongX and len / 2 or 1, alongX and 1 or len / 2
				if not overlaps(taken, x, z, hx, hz, 2) then
					wallBit(model, theme, base, len, 4, alongX)
					table.insert(taken, { x, z, hx, hz })
				end
			elseif roll < 0.75 then
				local s = rng:NextInteger(4, 6)
				if not overlaps(taken, x, z, s / 2, s / 2, 2) then
					crate(model, theme, base, s, rng)
					if rng:NextNumber() < 0.4 then
						crate(model, theme, base + Vector3.new(0, s, 0), s - 1, rng)
					end
					table.insert(taken, { x, z, s / 2, s / 2 })
				end
			elseif not onPath then
				local w, d = rng:NextInteger(8, 11), rng:NextInteger(7, 10)
				if not overlaps(taken, x, z, w / 2, d / 2, 3) then
					if theme.props == "town" then
						house(model, theme, base, w, d, rng:NextInteger(7, 10), rng)
					elseif theme.props == "candy" then
						if rng:NextNumber() < 0.5 then
							lollipop(model, theme, base, rng)
							w, d = 7, 7
						else
							ball(
								model,
								"Gumdrop",
								base + Vector3.new(0, 3, 0),
								7,
								theme.cover[rng:NextInteger(1, #theme.cover)]
							)
						end
					elseif theme.props == "dock" then
						block(
							model,
							"Container",
							Vector3.new(w, 7, d),
							base + Vector3.new(0, 3.5, 0),
							theme.cover[rng:NextInteger(1, #theme.cover)]
						)
						block(
							model,
							"Glow",
							Vector3.new(w + 0.1, 0.4, d + 0.1),
							base + Vector3.new(0, 6.6, 0),
							theme.accent,
							Enum.Material.Neon,
							{ CanCollide = false, CanQuery = false }
						)
					else
						house(model, theme, base, w, d, rng:NextInteger(8, 11), rng)
					end
					table.insert(taken, { x, z, w / 2, d / 2 })
				end
			end
		end
	end
	-- decoration outside the walls (can't be reached)
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		-- on a square just outside the walls
		local cx, sz = math.cos(a), math.sin(a)
		local k = (H + 14) / math.max(math.abs(cx), math.abs(sz))
		local p = c + Vector3.new(cx * k, 0, sz * k)
		if theme.props == "town" or theme.props == "castle" then
			tree(model, p, rng)
		elseif theme.props == "candy" then
			lollipop(model, theme, p, rng)
		else
			block(model, "Antenna", Vector3.new(1, 20, 1), p + Vector3.new(0, 10, 0), rgb(150, 160, 190))
			ball(model, "Beacon", p + Vector3.new(0, 20.5, 0), 2, theme.accent, Enum.Material.Neon)
		end
	end
	block(
		model,
		"Ground",
		Vector3.new(H * 2 + 120, 1, H * 2 + 120),
		c + Vector3.new(0, -2.6, 0),
		theme.floor:Lerp(INK, 0.15)
	)
	model.Parent = parent
	return {
		model = model,
		spawns = spawns,
		center = c,
		half = H,
		floorY = c.Y,
		key = theme.key,
		name = theme.name,
		size = size.key,
	}
end

return MapBuilder
