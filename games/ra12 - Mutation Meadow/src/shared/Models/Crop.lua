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

Looks (Crop.setMuts(model, muts)), until build-spec 02 replaces them:
  Golden   the fruit parts turn Visuals.GOLD (base) / Visuals.GOLD_LIGHT (detail), a shine, star glints on the
           FxAnchor and ONE PointLight on the Main part (Fruit1); the MoonGlow goes
  Wet      droplet beads on the Main part, a wet sheen and blue glints on the FxAnchor (the MoonGlow stays)
  both     gold with beads (still one light)
The model carries Crop = true, Seed, Stage, Muts, Far and Origin (the CFrame it was built on).

  Crop.stageFor(progress, ripe) -> "seed" | "sprout" | "growing" | "ripe"
  Crop.build(parent, name, seed, stage, cf, muts?, scale?, far?) -> Model     stage may also be "item"
  Crop.forTile(parent, name, seed, progress, ripe, muts, cf, far?)             a tile's crop (cf is O)
  Crop.item(parent, name, seed, muts, cf, scale) / onPedestal(parent, name, seed, muts, pedestal, scale)
  Crop.setMuts(model, muts)      muts is a key ("wet" | "golden" | "wetgolden" | nil) or a { wet, golden } table
  Crop.main(model) / fruit(model) / anchor(model) / destroy(model)
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
-- mutation looks (interim, until build-spec 02)

local function beads(look, main)
	local size = main.Size
	local r = math.min(size.X, size.Y, size.Z)
	for i = 1, 7 do
		local a = i * 2.4
		local elev = 0.3 + 0.18 * (i % 4)
		local dir = Vector3.new(math.cos(a) * math.cos(elev), math.sin(elev), math.sin(a) * math.cos(elev))
		local bead = Kit.ball(
			look,
			"Bead" .. i,
			Vector3.one * math.clamp(r * (0.09 + 0.03 * (i % 3)), 0.08, 0.32),
			main.CFrame * CFrame.new(dir * size / 2),
			Visuals.DROP,
			Enum.Material.Glass
		)
		bead.Transparency = 0.25
		bead.Reflectance = 0.3
	end
end

function Crop.setMuts(model, muts)
	local key = if type(muts) == "table" then MutationMath.key(muts) else muts
	if model:GetAttribute("LookSet") and model:GetAttribute("Muts") == key then
		return
	end
	model:SetAttribute("LookSet", true)
	model:SetAttribute("Muts", key)
	local golden = key == "golden" or key == "wetgolden"
	local wet = key == "wet" or key == "wetgolden"
	local targets = Crop.fruit(model)
	for _, p in targets do
		local base = p:GetAttribute("BaseColor") or p.Color
		local shine = p:GetAttribute("BaseReflectance") or 0
		if golden then
			p.Color = if p:GetAttribute("Tone") == "detail" then Visuals.GOLD_LIGHT else Visuals.GOLD
			p.Reflectance = 0.3
			p:SetAttribute("Gold", true)
		else
			p.Color = base
			p.Reflectance = if wet then shine + 0.12 else shine
			p:SetAttribute("Gold", nil)
		end
		-- the Moon Melon's MoonGlow: the Golden light replaces it; Wet keeps it
		local lightName = p:GetAttribute("Light")
		local own = lightName and p:FindFirstChild(lightName)
		if golden and own then
			own:Destroy()
		elseif not golden and lightName and not own and LIGHTS[lightName] then
			addLight(p, LIGHTS[lightName])
		end
	end
	local old = model:FindFirstChild("MutLook")
	if old then
		old:Destroy()
	end
	local main = Crop.main(model)
	local anchor = Crop.anchor(model)
	if main then
		local light = main:FindFirstChild("GoldLight")
		if light then
			light:Destroy()
		end
	end
	if anchor or main then
		Visuals.mutationFx(anchor or main, key)
	end
	if not key or not main or #targets == 0 then
		return -- before the crop fruits, a mutation shows as glints only
	end
	local look = Instance.new("Folder")
	look.Name = "MutLook"
	if golden then
		local light = Instance.new("PointLight")
		light.Name = "GoldLight"
		light.Color = Visuals.GOLD
		light.Brightness = 1.2
		light.Range = 9
		light.Shadows = false
		light.Parent = main
		local size = main.Size
		Kit.ball(
			look,
			"Shine",
			Vector3.one * math.min(size.X, size.Y, size.Z) * 0.2,
			main.CFrame * CFrame.new(-size.X * 0.22, size.Y * 0.3, -size.Z * 0.3),
			Visuals.GOLD_LIGHT,
			Enum.Material.Neon
		)
	end
	if wet then
		beads(look, main)
	end
	look.Parent = model
end

-- hands the pooled glints back, then destroys the model
function Crop.destroy(model)
	local anchor = Crop.anchor(model)
	if anchor then
		Visuals.release(anchor)
	end
	local main = Crop.main(model)
	if main then
		Visuals.release(main)
	end
	model:Destroy()
end

return Crop
