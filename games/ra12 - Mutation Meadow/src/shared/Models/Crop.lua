--[[
The crop models, built row for row from Game Artist build-spec/01-crops.md (the rows live in Config.CropVisuals).
The live tiles (TileController), the pedestals (PedestalController) and the capture stage (CaptureService) all build
crops through here, so a staged crop is exactly what players see.

Stages (Crop.stageFor(progress, ripe)): seed below 0.20, sprout below 0.50, growing until ripe, ripe once the tile is
Ripe (or progress reaches 1). Every build stands on O, the soil under the tile centre, and carries its own Root soil
mound (PrimaryPart) with an FxAnchor Attachment at the crop's listed centroid. An item (a kept crop on a pedestal)
is the ripe build's Fruit* parts (and the pumpkin's Stem#), resting on its own bottom. A far build (beyond
CropVisuals.farStuds) is Root and Fruit1 only.

Parts: SmoothPlastic, Reflectance 0 (the Moon Melon's Fruit1 0.05), anchored, no collide, query or touch, no Neon, no
particles. CastShadow on Root, Fruit# and any part at least 1 stud. Fruit# parts carry Role = "fruit", Tone = "base";
FruitDetail# Role = "fruit", Tone = "detail"; each its own BaseColor. Leaves, stems and soil are never mutation
targets. The ripe Moon Melon has its MoonGlow PointLight in Fruit1.

Looks (Crop.applyMutation(model, key), alias setMuts), from Game Artist build-spec/02-mutations.md (the numbers
live in Config.MutationVisuals). Only Role = "fruit" parts change colour; the template look is cached on first apply
(BaseColor, BaseMaterial, BaseReflectance) and restored on nil, and every added instance is named Mut* / GoldLight /
Fx, so cleanup is one loop.
  Golden     base #FFC300 / detail #E0A100, Metal; one GoldLight painted highlight (Ell #FFF1A8) on the largest
             fruit part (not the Moon Melon: its crescent is the highlight); a rare MutFx glint (Rate 0.35) and a
             MutLight PointLight (#FFD27A) on the Fx host; the MoonGlow goes. Corn: the kernels only, husks stay green
  Wet        the section 3.1 colours, Reflectance 0.30; MutBead# glass beads; a MutFx drip (Rate 3, large 4) on the
             MutDripAt attachment; wet soil on Root; no light (the MoonGlow stays)
  Wet+Golden gold first (#D9A600 / #BE8900, Metal), GoldLight kept, wet beads, MutDrops drip + MutFx glint (Rate
             0.25), MutLight 0.5, wet soil; the MoonGlow goes. Counts as 2 emitting crops
The Fx host is an invisible part sized to the fruit bounds x 0.9 (before the crop fruits, the emitters sit on the
FxAnchor). Crop.setFxState(model, emit, light, beads) is the per-crop switch the TileController caps use.
The model carries Crop = true, Seed, Stage, Muts, Far and Origin (the CFrame it was built on).

  Crop.stageFor(progress, ripe) -> "seed" | "sprout" | "growing" | "ripe"
  Crop.build(parent, name, seed, stage, cf, muts?, scale?, far?) -> Model     stage may also be "item"
  Crop.forTile(parent, name, seed, progress, ripe, muts, cf, far?)             a tile's crop (cf is O)
  Crop.item(parent, name, seed, muts, cf, scale) / onPedestal(parent, name, seed, muts, pedestal, scale)
  Crop.applyMutation(model, key) / setMuts(model, muts)   key "wet" | "golden" | "wetgolden" | nil; muts may also
                                                          be a { wet, golden } table
  Crop.setFxState(model, emit, light, beads) / weightOf(model)
  Crop.main(model) / fruit(model) / anchor(model) / fxHost(model) / destroy(model)
  Crop.tileCFrame(tilePart) / at(position, tileId) / yawFor(tileId)      O and the per-tile turn
  Crop.rows(seed, stage) / bounds(rows) / audit()      the resolved GA-01 rows and their checks (tests, QA)
]]
local Config = require(script.Parent.Parent.Config)
local Kit = require(script.Parent.Kit)
local MutationMath = require(script.Parent.Parent.MutationMath)
local Visuals = require(script.Parent.Parent.Visuals)

local V = Config.CropVisuals

local Crop = {}

Crop.STAGES = { "seed", "sprout", "growing", "ripe" }
Crop.MAX_LIGHTS = 1
Crop.PEDESTAL_SCALE = 0.5

local rad = math.rad
local UPRIGHT = CFrame.Angles(0, 0, rad(90)) -- CylV / Disc: a Roblox cylinder runs along X
local CYLINDER = { CylV = true, Disc = true }

-- the light specs by name, so setMuts can put a MoonGlow back
local LIGHTS = {}
for _, spec in V.crops do
	for _, row in spec.ripe do
		if row.opts and row.opts.light then
			LIGHTS[row.opts.light.name] = row.opts.light
		end
	end
end

function Crop.stageFor(progress, ripe)
	if ripe or progress >= 1 then
		return "ripe"
	elseif progress >= V.thresholds.growing then
		return "growing"
	elseif progress >= V.thresholds.sprout then
		return "sprout"
	end
	return "seed"
end

function Crop.yawFor(tileId)
	return ((tonumber(tileId) or 0) * 37) % 360
end

-- O at a position, with the per-tile turn
function Crop.at(position, tileId)
	return CFrame.new(position) * CFrame.Angles(0, rad(Crop.yawFor(tileId)), 0)
end

-- O for a tile part: the soil under its centre (its bottom, never its top), its own yaw and the per-tile turn
function Crop.tileCFrame(tile)
	local turn = tile.CFrame - tile.CFrame.Position
	local o = tile.Position - Vector3.new(0, tile.Size.Y / 2, 0)
	return CFrame.new(o) * turn * CFrame.Angles(0, rad(Crop.yawFor(tile.Name)), 0)
end

---------------------------------------------------------------------------------------------------------------
-- rows

local function vec(t)
	return Vector3.new(t[1], t[2], t[3])
end

local function angles(rot)
	return if rot then CFrame.Angles(rad(rot[1]), rad(rot[2]), rad(rot[3])) else CFrame.new()
end

local function isFruit(name)
	return string.sub(name, 1, 5) == "Fruit"
end

local function rawRows(seed, stage)
	local spec = V.crops[seed] or V.crops.carrot
	local out = { V.root }
	if stage == "seed" then
		local ball = V.seedBall[seed] or V.seedBall.carrot
		table.insert(out, V.seedStage[1])
		table.insert(out, { name = "Seed", shape = "Ball", size = ball[1], pos = V.seedPos, hex = ball[2] })
		table.insert(out, V.seedStage[2])
		table.insert(out, V.seedStage[3])
	elseif stage == "sprout" then
		table.insert(out, V.seedStage[2])
		table.insert(out, V.seedStage[3])
		for _, row in V.sprouts[seed] or V.sprouts.carrot do
			table.insert(out, row)
		end
	else
		for _, row in spec[if stage == "growing" then "growing" else "ripe"] do
			table.insert(out, row)
		end
	end
	return out
end

-- the GA-01 rows of one build, resolved: { name, shape, size (Vector3), cf (relative to O), color, reflectance,
-- light } in build order. The Tag takes the crop's fruit colour.
function Crop.rows(seed, stage)
	local frames = {}
	local out = {}
	for _, row in rawRows(seed, stage) do
		local opts = row.opts or {}
		local frame
		if opts.on then
			frame = frames[opts.on] * CFrame.new(vec(row.pos)) * angles(row.rot)
		else
			frame = CFrame.new(vec(row.pos)) * angles(row.rot)
		end
		frames[row.name] = frame
		local size = if type(row.size) == "number" then Vector3.new(row.size, row.size, row.size) else vec(row.size)
		local color = if row.hex then Color3.fromHex(row.hex) else Visuals.SEED[seed]
		table.insert(out, {
			name = row.name,
			shape = row.shape,
			size = size,
			cf = if CYLINDER[row.shape] then frame * UPRIGHT else frame,
			color = color,
			reflectance = opts.reflectance or 0,
			light = opts.light,
		})
	end
	return out
end

local function fxFor(seed, stage)
	local spec = V.crops[seed] or V.crops.carrot
	local p = if stage == "seed" or stage == "sprout" then V.fx[stage] else spec.fx
	return vec(p)
end

-- each row's half extents along O's axes (exact for the shape: a box, an ellipsoid, a ball or a cylinder)
local function extents(r)
	local c = r.cf
	local X, Y, Z = c.RightVector, c.UpVector, -c.LookVector
	local h = r.size / 2
	local out = {}
	for i, axis in { "X", "Y", "Z" } do
		local x, y, z = X[axis], Y[axis], Z[axis]
		if r.shape == "Ball" then
			out[i] = h.X
		elseif r.shape == "Ell" then
			out[i] = math.sqrt((x * h.X) ^ 2 + (y * h.Y) ^ 2 + (z * h.Z) ^ 2)
		elseif CYLINDER[r.shape] then
			out[i] = math.abs(x) * h.X + h.Y * math.sqrt(math.max(0, 1 - x * x))
		else
			out[i] = math.abs(x) * h.X + math.abs(y) * h.Y + math.abs(z) * h.Z
		end
	end
	return out
end

function Crop.bounds(rows)
	local b = {
		minX = math.huge,
		maxX = -math.huge,
		minY = math.huge,
		maxY = -math.huge,
		minZ = math.huge,
		maxZ = -math.huge,
	}
	for _, r in rows do
		local e = extents(r)
		local p = r.cf.Position
		b.minX, b.maxX = math.min(b.minX, p.X - e[1]), math.max(b.maxX, p.X + e[1])
		b.minY, b.maxY = math.min(b.minY, p.Y - e[2]), math.max(b.maxY, p.Y + e[2])
		b.minZ, b.maxZ = math.min(b.minZ, p.Z - e[3]), math.max(b.maxZ, p.Z + e[3])
	end
	return b
end

-- every crop at every stage against GA-01's limits: { [seed] = { [stage] = { parts, height, half, warnings } } }
function Crop.audit()
	local out = {}
	local eps = 1e-6
	for seed in V.crops do
		out[seed] = {}
		for _, stage in Crop.STAGES do
			local rows = Crop.rows(seed, stage)
			local b = Crop.bounds(rows)
			local half = math.max(-b.minX, b.maxX, -b.minZ, b.maxZ)
			local warnings = {}
			if #rows > V.maxParts then
				table.insert(warnings, `{#rows} parts > {V.maxParts}`)
			end
			if b.maxY > V.maxHeight + eps then
				table.insert(warnings, string.format("height %.3f > %.2f", b.maxY, V.maxHeight))
			end
			if half > V.footprint / 2 + eps then
				table.insert(warnings, string.format("footprint %.3f > %.2f", half * 2, V.footprint))
			end
			if b.minY < -eps then
				table.insert(warnings, string.format("below the ground at %.3f", b.minY))
			end
			out[seed][stage] = { parts = #rows, height = b.maxY, footprint = half * 2, warnings = warnings }
		end
	end
	return out
end

-- the item's rows: the ripe Fruit* (and the pumpkin's Stem#), moved to rest on their own bottom centre
local function itemRows(seed)
	local rows = {}
	for _, r in Crop.rows(seed, "ripe") do
		if isFruit(r.name) or (seed == "pumpkin" and string.sub(r.name, 1, 4) == "Stem") then
			table.insert(rows, r)
		end
	end
	local b = Crop.bounds(rows)
	local shift = Vector3.new(-(b.minX + b.maxX) / 2, -b.minY, -(b.minZ + b.maxZ) / 2)
	for i, r in rows do
		local copy = table.clone(r)
		copy.cf = CFrame.new(shift) * r.cf
		rows[i] = copy
	end
	return rows, shift
end

---------------------------------------------------------------------------------------------------------------
-- building

local function make(m, r, size, cf)
	if r.shape == "Ball" then
		return Kit.sphere(m, r.name, size.X, cf, r.color)
	elseif r.shape == "Ell" then
		return Kit.ball(m, r.name, size, cf, r.color)
	elseif r.shape == "Wedge" then
		return Kit.wedge(m, r.name, size, cf, r.color)
	end
	local p = Kit.part(m, r.name, size, cf, r.color)
	if CYLINDER[r.shape] then
		p.Shape = Enum.PartType.Cylinder
	end
	return p
end

local function addLight(part, spec)
	local light = Instance.new("PointLight")
	light.Name = spec.name
	light.Color = Color3.fromHex(spec.hex)
	light.Brightness = spec.brightness
	light.Range = spec.range
	light.Shadows = false
	light.Parent = part
	part:SetAttribute("Light", spec.name)
	LIGHTS[spec.name] = spec
	return light
end

local function scaled(cf, s)
	return CFrame.new(cf.Position * s) * (cf - cf.Position)
end

local function tagged(model, attr, value)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(attr) == value then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

-- the Role = "fruit" parts (Fruit# and FruitDetail#)
function Crop.fruit(model)
	return tagged(model, "Role", "fruit")
end

-- the part the light, shine and beads sit on: Fruit1, or Root before the crop fruits
function Crop.main(model)
	return tagged(model, "Main", true)[1]
end

function Crop.anchor(model)
	for _, d in model:GetDescendants() do
		if d.Name == "FxAnchor" and d:IsA("Attachment") then
			return d
		end
	end
	return nil
end

function Crop.build(parent, name, seed, stage, cf, muts, scale, far)
	local s = scale or 1
	local rows, fx
	if stage == "item" then
		local shift
		rows, shift = itemRows(seed)
		fx = fxFor(seed, "ripe") + shift
	else
		rows = Crop.rows(seed, stage)
		fx = fxFor(seed, stage)
		if far then
			local near = rows
			rows = {}
			for _, r in near do
				if r.name == "Root" or r.name == "Fruit1" then
					table.insert(rows, r)
				end
			end
		end
	end
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("Crop", true)
	m:SetAttribute("Seed", seed)
	m:SetAttribute("Stage", stage)
	m:SetAttribute("Origin", cf)
	m:SetAttribute("Far", far == true)
	for _, r in rows do
		local p = make(m, r, r.size * s, cf * scaled(r.cf, s))
		p.Reflectance = r.reflectance
		local biggest = math.max(r.size.X, r.size.Y, r.size.Z)
		p.CastShadow = r.name == "Root" or string.match(r.name, "^Fruit%d") ~= nil or biggest >= 1
		if isFruit(r.name) then
			p:SetAttribute("Role", "fruit")
			p:SetAttribute("Tone", if string.sub(r.name, 1, 11) == "FruitDetail" then "detail" else "base")
			p:SetAttribute("BaseColor", r.color)
			p:SetAttribute("BaseReflectance", r.reflectance)
		end
		if r.light then
			addLight(p, r.light)
		end
	end
	local root = m:FindFirstChild("Root")
	local main = m:FindFirstChild("Fruit1") or root
	if main then
		main:SetAttribute("Main", true)
	end
	local holder = root or main
	if holder then
		local anchor = Instance.new("Attachment")
		anchor.Name = "FxAnchor"
		anchor.CFrame = holder.CFrame:Inverse() * (cf * CFrame.new(fx * s))
		anchor.Parent = holder
		m.PrimaryPart = holder
	end
	Crop.setMuts(m, muts)
	m.Parent = parent
	return m
end

function Crop.forTile(parent, name, seed, progress, ripe, muts, cf, far)
	return Crop.build(parent, name, seed, Crop.stageFor(progress, ripe), cf, muts, nil, far)
end

function Crop.item(parent, name, seed, muts, cf, scale)
	return Crop.build(parent, name, seed, "item", cf, muts, scale)
end

function Crop.onPedestal(parent, name, seed, muts, pedestal, scale)
	local top = CFrame.new(pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0))
	return Crop.item(parent, name, seed, muts, top, scale or Crop.PEDESTAL_SCALE)
end

---------------------------------------------------------------------------------------------------------------
-- mutation looks (Game Artist build-spec/02-mutations.md; the numbers are Config.MutationVisuals)

local MV = Config.MutationVisuals

local function isGolden(key)
	return key == "golden" or key == "wetgolden"
end

local function isWet(key)
	return key == "wet" or key == "wetgolden"
end

-- the template look, cached on first apply
local function remember(p)
	if p:GetAttribute("BaseMaterial") == nil then
		p:SetAttribute("BaseColor", p:GetAttribute("BaseColor") or p.Color)
		p:SetAttribute("BaseReflectance", p:GetAttribute("BaseReflectance") or p.Reflectance)
		p:SetAttribute("BaseMaterial", p.Material.Name)
	end
end

local function restore(p)
	if p:GetAttribute("BaseMaterial") ~= nil then
		p.Color = p:GetAttribute("BaseColor")
		p.Reflectance = p:GetAttribute("BaseReflectance")
		p.Material = Enum.Material[p:GetAttribute("BaseMaterial")]
	end
end

local function look(spec)
	return { color = Color3.fromHex(spec.hex), material = Enum.Material[spec.material], reflectance = spec.reflectance }
end

-- one fruit part's look under a key (GA-02 sections 2.1, 3.1, 4 and the section 1.1 exceptions)
local function fruitLook(seed, key, p)
	local name = p.Name
	local overrides = MV.overrides[seed] and MV.overrides[seed][key]
	local over = overrides and overrides[name]
	if over == "keep" then
		return nil
	elseif type(over) == "table" then
		return look(over)
	end
	if key == "wet" or over == "wet" then
		local hex = MV.wet.colours[seed] and MV.wet.colours[seed][name]
		return {
			color = if hex then Color3.fromHex(hex) else p:GetAttribute("BaseColor"),
			material = Enum.Material[p:GetAttribute("BaseMaterial")],
			reflectance = MV.wet.reflectance,
		}
	end
	local tone = if over == "base" then "base" else p:GetAttribute("Tone") or "base"
	return look(MV[key][tone])
end

local function partShape(p)
	if p.ClassName == "WedgePart" then
		return "Wedge"
	elseif p.Shape == Enum.PartType.Ball then
		return "Ball"
	elseif p.Shape == Enum.PartType.Cylinder then
		return "CylV"
	elseif p:FindFirstChildOfClass("SpecialMesh") then
		return "Ell"
	end
	return "Block"
end

-- a fruit part's own upright frame and size (a CylV stood back up, so "up" is up)
local function uprightFrame(p)
	if p.ClassName ~= "WedgePart" and p.Shape == Enum.PartType.Cylinder then
		return p.CFrame * CFrame.Angles(0, 0, -rad(90)), Vector3.new(p.Size.Y, p.Size.X, p.Size.Z)
	end
	return p.CFrame, p.Size
end

-- the point on a part's ellipsoid along a local direction, and the outward normal there (both local)
local function surface(size, dir)
	local d = dir.Unit
	local k = math.sqrt((d.X / size.X) ^ 2 + (d.Y / size.Y) ^ 2 + (d.Z / size.Z) ^ 2)
	local p = d * 0.5 / k
	local n = Vector3.new(p.X / size.X ^ 2, p.Y / size.Y ^ 2, p.Z / size.Z ^ 2).Unit
	return p, n
end

local function bigFruit(model, seed)
	return model:FindFirstChild(MV.highlightOn[seed] or "Fruit1") or model:FindFirstChild("Fruit1")
end

-- GA-02 section 2.2: the painted highlight on the largest fruit part
local function goldHighlight(model, fruit)
	local h = MV.highlight
	local frame, size = uprightFrame(fruit)
	local p, n = surface(size, Vector3.new(h.direction[1], h.direction[2], h.direction[3]))
	local at = frame * (p + n * h.push)
	local normal = frame:VectorToWorldSpace(n)
	local part = Kit.ball(
		model,
		"GoldLight",
		Vector3.new(math.max(h.size[1] * size.X, h.min[1]), math.max(h.size[2] * size.Y, h.min[2]), h.thickness),
		CFrame.lookAt(at, at + normal, frame.UpVector),
		Color3.fromHex(h.hex)
	)
	part.Reflectance = 0
	part.CastShadow = false
	return part
end

local function tileNumber(model)
	return tonumber(string.match(model.Name, "(%d+)$")) or 0
end

-- GA-02 section 3.2: glass beads on the fruit, deterministic per tile and crop
local function addBeads(model, seed, key)
	local b = MV.beads
	local style = b[key]
	local candidates = {}
	for _, p in Crop.fruit(model) do
		if p:GetAttribute("Tone") == "base" or b.onDetails[seed] then
			table.insert(candidates, p)
		end
	end
	if #candidates == 0 then
		return
	end
	local tier = Config.Seeds[seed] and Config.Seeds[seed].tier or 0
	local rng = Random.new(tileNumber(model) * b.seedA + tier)
	local placed = {}
	for i = 1, b.counts[seed] or 6 do
		local diameter = b.sizes[(i - 1) % #b.sizes + 1]
		local fruit = candidates[(i - 1) % #candidates + 1]
		local frame, size = uprightFrame(fruit)
		local best
		for attempt = 1, 40 do
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
			if dir.Magnitude > 0.05 then
				local p, n = surface(size, dir)
				local upper = p.Y >= b.minY * size.Y
				local front = attempt > 25 or p.Z <= b.frontZ * size.Z -- front-facing preferred
				local world = frame * (p + n * (diameter / 2 - b.sink * diameter))
				local clear = true
				for _, other in placed do
					clear = clear and (other - world).Magnitude >= b.spacing
				end
				best = best or world
				if upper and front and clear then
					best = world
					break
				end
			end
		end
		table.insert(placed, best)
		local bead = Kit.sphere(
			model,
			"MutBead" .. i,
			diameter,
			CFrame.new(best),
			Color3.fromHex(style.hex),
			Enum.Material.Glass
		)
		bead.Transparency = style.transparency
		bead.Reflectance = style.reflectance
		bead.CastShadow = false
		bead:SetAttribute("BaseTransparency", style.transparency)
	end
end

local function partRow(p, frame)
	return { shape = partShape(p), size = p.Size, cf = frame:Inverse() * p.CFrame }
end

-- the invisible Fx host over the fruit (bounds x 0.9), with the MutDripAt attachment under the largest fruit
local function fxHost(model, seed, fruitParts)
	local origin = model:GetAttribute("Origin") or CFrame.new()
	local rows = {}
	for _, p in fruitParts do
		table.insert(rows, partRow(p, origin))
	end
	local b = Crop.bounds(rows)
	local centre = origin * Vector3.new((b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2, (b.minZ + b.maxZ) / 2)
	local k = MV.glint.bounds
	local size = Vector3.new(
		math.max((b.maxX - b.minX) * k, 0.2),
		math.max((b.maxY - b.minY) * k, 0.2),
		math.max((b.maxZ - b.minZ) * k, 0.2)
	)
	local host = Kit.part(model, "Fx", size, CFrame.new(centre) * (origin - origin.Position), Color3.new(1, 1, 1))
	host.Transparency = 1
	host.CastShadow = false
	local fruit = bigFruit(model, seed)
	local frame, fsize = uprightFrame(fruit)
	local d = MV.drip.at
	local at = Instance.new("Attachment")
	at.Name = "MutDripAt"
	at.CFrame = host.CFrame:Inverse() * (frame * CFrame.new(d[1] * fsize.X, d[2] * fsize.Y, d[3] * fsize.Z))
	at.Parent = host
	return host, at
end

function Crop.fxHost(model)
	return model:FindFirstChild("Fx")
end

-- every added instance goes (Mut*, GoldLight, Fx); the template look comes back
local function clear(model)
	local host = Crop.fxHost(model)
	if host then
		Visuals.release(host)
		local at = host:FindFirstChild("MutDripAt")
		if at then
			Visuals.release(at)
		end
	end
	local anchor = Crop.anchor(model)
	if anchor then
		Visuals.release(anchor)
	end
	for _, child in model:GetChildren() do
		if child.Name == "Fx" or child.Name == "GoldLight" or string.sub(child.Name, 1, 3) == "Mut" then
			child:Destroy()
		end
	end
	for _, p in Crop.fruit(model) do
		restore(p)
		p:SetAttribute("Gold", nil)
	end
	local root = model:FindFirstChild("Root")
	if root then
		restore(root)
	end
end

function Crop.applyMutation(model, muts)
	local key = if type(muts) == "table" then MutationMath.key(muts) else muts
	if model:GetAttribute("LookSet") and model:GetAttribute("Muts") == key then
		return
	end
	model:SetAttribute("LookSet", true)
	model:SetAttribute("Muts", key)
	-- fresh emitters start on; the caps (TileController) look again
	model:SetAttribute("Emitting", nil)
	model:SetAttribute("Lit", nil)
	model:SetAttribute("Beads", nil)
	clear(model)
	local seed = model:GetAttribute("Seed")
	local targets = Crop.fruit(model)
	local golden, wet = isGolden(key), isWet(key)
	for _, p in targets do
		remember(p)
		local l = key and fruitLook(seed, key, p)
		if l then
			p.Color = l.color
			p.Material = l.material
			p.Reflectance = l.reflectance
		end
		p:SetAttribute("Gold", if golden and l and l.material == Enum.Material.Metal then true else nil)
		-- the Moon Melon's MoonGlow: the Golden light replaces it; Wet keeps it
		local lightName = p:GetAttribute("Light")
		local own = lightName and p:FindFirstChild(lightName)
		if golden and own then
			own:Destroy()
		elseif not golden and lightName and not own and LIGHTS[lightName] then
			addLight(p, LIGHTS[lightName])
		end
	end
	local root = model:FindFirstChild("Root")
	if root and wet then
		remember(root)
		root.Color = Color3.fromHex(MV.soil.hex)
		root.Reflectance = MV.soil.reflectance
	end
	if not key then
		return
	end
	local large = MV.large[seed] == true
	if #targets == 0 then
		-- before the crop fruits: the emitters alone, on the FxAnchor
		local anchor = Crop.anchor(model)
		if anchor then
			Visuals.mutationFx(anchor, key, { large = large })
		end
		return
	end
	local host, dripAt = fxHost(model, seed, targets)
	Visuals.mutationFx(host, key, { drip = dripAt, large = large })
	if golden then
		local light = Instance.new("PointLight")
		light.Name = "MutLight"
		light.Color = Color3.fromHex(MV.light.hex)
		light.Brightness = MV.light[key]
		light.Range = if large then MV.light.rangeLarge else MV.light.range
		light.Shadows = false
		light.Parent = host
		if MV.highlightOn[seed] then
			goldHighlight(model, bigFruit(model, seed))
		end
	end
	if wet then
		addBeads(model, seed, key)
	end
end

Crop.setMuts = Crop.applyMutation

-- the TileController caps: emitters on or off, the MutLight on or off, beads shown or hidden
function Crop.setFxState(model, emit, light, beads)
	for _, d in model:GetDescendants() do
		if d.ClassName == "ParticleEmitter" and (d.Name == "MutFx" or d.Name == "MutDrops") then
			d.Enabled = emit
		elseif d.Name == "MutLight" then
			d.Enabled = light
		elseif string.sub(d.Name, 1, 7) == "MutBead" then
			d.Transparency = if beads then d:GetAttribute("BaseTransparency") else 1
		end
	end
	model:SetAttribute("Emitting", emit)
	model:SetAttribute("Lit", light)
	model:SetAttribute("Beads", beads)
end

-- how many emitting crops a crop counts as for the per-plot cap (Wet+Golden is 2)
function Crop.weightOf(model)
	local key = model:GetAttribute("Muts")
	return if key then MV.caps.weights[key] else 0
end

-- hands the pooled emitters back, then destroys the model
function Crop.destroy(model)
	clear(model)
	model:Destroy()
end

return Crop
