--[[
The crop builds against Game Artist build-spec/01-crops.md (GA-01): stages, part counts, the exact rows, roles,
FxAnchor, MoonGlow, the limits, the ground origin, rebuilds, the far LOD and the pedestal item.
]]
local Assert = require("./mock/Assert")
local Client = require("./mock/Client")
local Engine = require("./mock/Engine")
local roblox = require("@lune/roblox")

local test, eq = Assert.test, Assert.eq

local engine = Engine.new()
local Crop = engine:require(engine:module("Shared/Models/Crop"))
local Config = engine:require(engine:module("Shared/Config"))
local Visuals = engine:require(engine:module("Shared/Visuals"))
local V = Config.CropVisuals

local SEEDS =
	{ "carrot", "strawberry", "blueberry", "tomato", "corn", "pumpkin", "watermelon", "dragonfruit", "moonmelon" }
local V3, CF, hex = roblox.Vector3, roblox.CFrame, roblox.Color3.fromHex
local O = CF.new(10, 0, 20)

local function build(seed, stage, muts)
	return Crop.build(nil, "T", seed, stage, O, muts)
end

local function parts(model)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			out[d.Name] = d
		end
	end
	return out
end

local function count(model)
	local n = 0
	for _ in parts(model) do
		n += 1
	end
	return n
end

-- a part's centre relative to O
local function at(part)
	return O:PointToObjectSpace(part.Position)
end

local function near(a, b, msg)
	Assert.truthy((a - b).Magnitude < 1e-4, `{msg}: {a} vs {b}`)
end

test(
	"four stages: seed < 0.20 <= sprout < 0.50 <= growing; ripe = the tile's Ripe (or progress 1); no budding",
	function()
		eq(Crop.STAGES, { "seed", "sprout", "growing", "ripe" })
		eq(V.thresholds, { sprout = 0.20, growing = 0.50 })
		local cases = {
			{ 0, false, "seed" },
			{ 0.19, false, "seed" },
			{ 0.20, false, "sprout" },
			{ 0.49, false, "sprout" },
			{ 0.50, false, "growing" },
			{ 0.99, false, "growing" },
			{ 1, false, "ripe" },
			{ 0.3, true, "ripe" },
		}
		for _, c in cases do
			eq(Crop.stageFor(c[1], c[2]), c[3], `{c[1]} {c[2]}`)
		end
	end
)

test("the part budgets of GA-01 section 4, every crop at every stage (268 parts in all)", function()
	local total = 0
	for _, seed in SEEDS do
		for _, stage in Crop.STAGES do
			local m = build(seed, stage)
			eq(count(m), V.budget[seed][stage], `{seed} {stage}`)
			eq({ m:GetAttribute("Seed"), m:GetAttribute("Stage") }, { seed, stage })
			total += count(m)
		end
	end
	eq(total, 268)
end)

test("every build is its exact rows: names, sizes, colours and places relative to O", function()
	for _, seed in SEEDS do
		for _, stage in Crop.STAGES do
			local m = build(seed, stage)
			local byName = parts(m)
			for _, r in Crop.rows(seed, stage) do
				local p = byName[r.name]
				Assert.truthy(p, `{seed} {stage}: {r.name}`)
				near(p.Size, r.size, `{seed} {stage} {r.name} size`)
				eq(p.Color, r.color, `{seed} {stage} {r.name} colour`)
				near(at(p), r.cf.Position, `{seed} {stage} {r.name} place`)
			end
		end
	end
end)

test("section 1: the Root mound, Hole, per-crop Seed ball, Stake and the fruit-coloured Tag", function()
	local balls = {
		carrot = { 0.22, "#D9B98A" },
		strawberry = { 0.18, "#F2D45C" },
		blueberry = { 0.20, "#465AC8" },
		tomato = { 0.22, "#EADBB8" },
		corn = { 0.30, "#F5D23C" },
		pumpkin = { 0.32, "#F3E3C3" },
		watermelon = { 0.26, "#2B2B2B" },
		dragonfruit = { 0.20, "#1E1B2E" },
		moonmelon = { 0.30, "#E6EBFF" },
	}
	for _, seed in SEEDS do
		local m = build(seed, "seed")
		local p = parts(m)
		eq(m.PrimaryPart, p.Root, seed .. " PrimaryPart")
		near(p.Root.Size, V3.new(0.30, 2.8, 2.8), seed .. " Root")
		near(at(p.Root), V3.new(0, 0.15, 0), seed .. " Root at")
		eq(p.Root.Color, hex("#7A4E2D"))
		eq(p.Root.Shape, engine.Enum.PartType.Cylinder)
		Assert.truthy(math.abs(p.Root.CFrame.RightVector.Y) > 0.999, seed .. ": the mound's cylinder stands up")
		near(p.Hole.Size, V3.new(0.04, 0.9, 0.9), "Hole")
		eq(p.Hole.Color, hex("#5C3A1F"))
		Assert.near(p.Seed.Size.X, balls[seed][1], 1e-6)
		eq({ p.Seed.Color, p.Seed.Shape }, { hex(balls[seed][2]), engine.Enum.PartType.Ball })
		near(at(p.Seed), V3.new(0, 0.36, 0), "Seed at")
		near(at(p.Stake), V3.new(0.95, 0.80, -0.95), "Stake at")
		eq(p.Tag.Color, Visuals.SEED[seed], seed .. " Tag in the fruit colour")
		near(at(p.Tag), V3.new(0.95, 1.20, -1.01), "Tag at")
	end
	local sprout = parts(build("pumpkin", "sprout"))
	Assert.truthy(sprout.Stake and sprout.Tag and not sprout.Hole and not sprout.Seed, "the sprout keeps Stake and Tag")
	local growing = parts(build("pumpkin", "growing"))
	Assert.truthy(not growing.Stake and not growing.Tag, "no stake or tag from Growing on")
end)

test("GA-01 spot checks: the signed pumpkin nits, corn, the carrot shoulder, Moon Melon", function()
	local pg, pr = parts(build("pumpkin", "growing")), parts(build("pumpkin", "ripe"))
	near(pg.Vine1.Size, V3.new(0.15, 0.12, 1.25), "pumpkin Growing Vine1")
	near(pr.Vine1.Size, V3.new(0.15, 0.12, 1.05), "pumpkin Ripe Vine1")
	near(pr.Leaf2.Size, V3.new(0.08, 0.90, 0.90), "pumpkin Ripe Leaf2")
	near(pr.Leaf1.Size, V3.new(0.08, 1.00, 1.00), "pumpkin Ripe Leaf1")
	eq({ pr.Fruit1.Color, pr.Fruit2.Color, pr.Fruit3.Color }, { hex("#F0821E"), hex("#E27318"), hex("#E27318") })

	local corn = parts(build("corn", "ripe"))
	for _, name in { "Stem2", "Stem3", "Stem4" } do
		eq(corn[name].Color, hex("#B89A6A"), "a tan tassel, not gold")
	end
	near(at(corn.Stem2), V3.new(0, 3.02, 0), "the shortened tassel: Stem2 dropped 0.28")
	near(at(corn.Stem3), V3.new(-0.12, 2.97, 0), "Stem3 dropped 0.28")
	near(at(corn.Stem4), V3.new(0.12, 2.97, 0), "Stem4 dropped 0.28")
	for _, name in { "Fruit1", "Fruit2" } do
		eq({ corn[name].Material, corn[name].Reflectance }, { engine.Enum.Material.SmoothPlastic, 0 }, "matte kernels")
		eq(corn[name].Color, hex("#F5D23C"))
	end
	near(at(corn.Fruit1), V3.new(0.30, 1.62, -0.33), "kernels: the husk + 0.08 toward -Z, +0.12 y")
	Assert.truthy(corn.FruitDetail1.Size.X > corn.Fruit1.Size.X, "husk-dominant: the husks wrap the kernels")

	local carrot = parts(build("carrot", "ripe"))
	local bottom = at(carrot.Fruit1).Y - carrot.Fruit1.Size.X / 2
	local top = at(carrot.Fruit1).Y + carrot.Fruit1.Size.X / 2
	Assert.near(bottom, 0.25, 1e-4)
	Assert.near(top, 0.85, 1e-4)
	Assert.truthy(bottom < 0.30 and top > 0.30, "the ripe carrot half out of the mound (its top at 0.30)")

	local moon = build("moonmelon", "ripe")
	local glow = parts(moon).Fruit1:FindFirstChild("MoonGlow")
	Assert.truthy(glow, "MoonGlow")
	eq(
		{ glow.ClassName, glow.Color, glow.Brightness, glow.Range, glow.Shadows },
		{ "PointLight", hex("#BEC8FF"), 0.8, 6, false }
	)
	eq(parts(moon).Fruit1.Reflectance, 0.05)
	eq(build("moonmelon", "growing"):FindFirstChild("MoonGlow", true), nil, "only the ripe Moon Melon glows")
end)

test(
	"the flat storybook look: SmoothPlastic, no Neon, no particles, no lights but MoonGlow; flags and shadows",
	function()
		for _, seed in SEEDS do
			for _, stage in Crop.STAGES do
				local m = build(seed, stage)
				for name, p in parts(m) do
					local where = `{seed} {stage} {name}`
					eq(p.Material, engine.Enum.Material.SmoothPlastic, where)
					eq(
						p.Reflectance,
						if seed == "moonmelon" and stage == "ripe" and name == "Fruit1" then 0.05 else 0,
						where
					)
					eq(p.Transparency, 0, where)
					eq({ p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch }, { true, false, false, false }, where)
					local biggest = math.max(p.Size.X, p.Size.Y, p.Size.Z)
					local shadow = name == "Root" or string.match(name, "^Fruit%d") ~= nil or biggest >= 1
					eq(p.CastShadow, shadow, where .. " CastShadow")
				end
				for _, d in m:GetDescendants() do
					Assert.truthy(
						d.ClassName ~= "ParticleEmitter" and d.ClassName ~= "Beam" and d.ClassName ~= "Trail",
						seed
					)
					if d.ClassName == "PointLight" then
						eq({ seed, stage, d.Name }, { "moonmelon", "ripe", "MoonGlow" })
					end
				end
			end
		end
	end
)

test("roles for build-spec 02: Fruit# base, FruitDetail# detail, nothing else is a mutation target", function()
	for _, seed in SEEDS do
		for _, stage in Crop.STAGES do
			for name, p in parts(build(seed, stage)) do
				local role, tone = p:GetAttribute("Role"), p:GetAttribute("Tone")
				if string.match(name, "^FruitDetail%d") then
					eq({ role, tone }, { "fruit", "detail" }, `{seed} {stage} {name}`)
				elseif string.match(name, "^Fruit%d") then
					eq({ role, tone }, { "fruit", "base" }, `{seed} {stage} {name}`)
				else
					eq(role, nil, `{seed} {stage} {name} is not a target`)
				end
			end
		end
	end
end)

test("FxAnchor: an Attachment on Root at each crop's listed centroid (corn ripe at (0, 1.45, -0.2))", function()
	local fx = {
		carrot = { 0, 0.6, 0 },
		strawberry = { 0, 0.5, -0.5 },
		blueberry = { 0, 1.4, -0.6 },
		tomato = { 0, 1.6, -0.2 },
		corn = { 0, 1.45, -0.2 },
		pumpkin = { 0, 0.95, 0 },
		watermelon = { 0, 0.9, 0 },
		dragonfruit = { 0, 2.15, 0 },
		moonmelon = { 0, 1.05, 0 },
	}
	for _, seed in SEEDS do
		for _, stage in Crop.STAGES do
			local m = build(seed, stage)
			local anchor = Crop.anchor(m)
			Assert.truthy(anchor and anchor.ClassName == "Attachment", `{seed} {stage} FxAnchor`)
			eq(anchor.Parent, m.Root, "on Root")
			local want = if stage == "seed"
				then V3.new(0, 0.5, 0)
				elseif stage == "sprout" then V3.new(0, 0.8, 0)
				else V3.new(table.unpack(fx[seed]))
			near(O:PointToObjectSpace((m.Root.CFrame * anchor.CFrame).Position), want, `{seed} {stage} FxAnchor`)
		end
	end
end)

test("the limits: <= 14 parts, <= 3.4 footprint, <= 3.25 height, for every crop at every stage", function()
	local audit = Crop.audit()
	local found = {}
	for _, seed in SEEDS do
		for _, stage in Crop.STAGES do
			local a = audit[seed][stage]
			Assert.truthy(a.parts <= 14, `{seed} {stage}`)
			for _, w in a.warnings do
				table.insert(found, `{seed} {stage}: {w}`)
			end
		end
	end
	eq(found, {}, "no warnings")
	-- the shortened corn: the tassel dropped 0.28, its top (Stem2 0.45 tall at y 3.02) at 3.245
	Assert.near(audit.corn.ripe.height, 3.245, 1e-4)
	Assert.truthy(audit.pumpkin.growing.footprint <= 3.4 and audit.pumpkin.ripe.footprint <= 3.4, "pumpkin vines fit")
end)

test("crops stand on the ground under the tile, turned per tile; rebuilt only on a stage change", function()
	local c = Client.boot()
	local tile = c.plot.Tiles["2"]
	local now = c.engine.workspace:GetServerTimeNow()
	for k, v in { Active = true, Seed = "corn", Grown = 0, At = now, Rate = 1, GrowSec = 360, Ripe = false } do
		tile:SetAttribute(k, v)
	end
	c.engine:advance(0.5)
	local crop = c.engine.workspace.ClientCrops.Plot1_2
	local groundY = tile.Position.Y - tile.Size.Y / 2
	eq(groundY, 0, "the placeholder tile's bottom is the grass")
	Assert.near(
		crop.Root.Position.Y - crop.Root.Size.X / 2,
		groundY,
		1e-4,
		"the mound sits on the grass, not the tile top"
	)
	local origin = crop:GetAttribute("Origin")
	Assert.near(origin.Position.Y, groundY, 1e-4)
	local yaw = math.deg(math.atan2(-origin.LookVector.X, -origin.LookVector.Z)) % 360
	Assert.near(yaw, (2 * 37) % 360, 1e-3, "the per-tile turn")
	c.engine:advance(10)
	eq(c.engine.workspace.ClientCrops.Plot1_2, crop, "the same stage: the same model")
	c.engine:advance(80)
	local sprout = c.engine.workspace.ClientCrops.Plot1_2
	Assert.truthy(sprout ~= crop and sprout:GetAttribute("Stage") == "sprout", "a new model on the stage change")
	tile:SetAttribute("Ripe", true)
	c.engine:advance(0.5)
	local ripe = c.engine.workspace.ClientCrops.Plot1_2
	eq(ripe:GetAttribute("Stage"), "ripe")
	Assert.near(
		ripe.Stem1.Position.Y + ripe.Stem1.Size.X / 2,
		3.10,
		1e-4,
		"the corn stalk tops at 3.10 (its tassel: the limits test)"
	)
	eq(c.engine.errors, {})
end)

test("beyond 120 studs a crop is its far build (Root + Fruit1), checked every second", function()
	local c = Client.boot()
	local tile = c.plot.Tiles["3"]
	local now = c.engine.workspace:GetServerTimeNow()
	for k, v in { Active = true, Seed = "pumpkin", Grown = 720, At = now, Rate = 1, GrowSec = 720, Ripe = true } do
		tile:SetAttribute(k, v)
	end
	local camera = c.engine.workspace.CurrentCamera
	camera.CFrame = CF.new(tile.Position + V3.new(0, 20, -30))
	c.engine:advance(1.5)
	local crop = c.engine.workspace.ClientCrops.Plot1_3
	eq({ crop:GetAttribute("Far"), count(crop) }, { false, 9 })
	camera.CFrame = CF.new(tile.Position + V3.new(0, 20, -200))
	c.engine:advance(1.5)
	crop = c.engine.workspace.ClientCrops.Plot1_3
	eq(crop:GetAttribute("Far"), true)
	local names = {}
	for name in parts(crop) do
		table.insert(names, name)
	end
	table.sort(names)
	eq(names, { "Fruit1", "Root" })
	camera.CFrame = CF.new(tile.Position + V3.new(0, 20, -30))
	c.engine:advance(1.5)
	eq(count(c.engine.workspace.ClientCrops.Plot1_3), 9, "back near: the full build")
end)

test(
	"the pedestal item: the ripe Fruit* parts (+ the pumpkin's stems) at scale 0.5, resting on the pedestal",
	function()
		local pedestal = engine.Instance.new("Part")
		pedestal.Size = V3.new(2, 2, 2)
		pedestal.Position = V3.new(0, 1, 0)
		local item = Crop.onPedestal(nil, "ShownItem", "pumpkin", nil, pedestal)
		eq(Crop.PEDESTAL_SCALE, 0.5)
		local names = {}
		local bottom = math.huge
		for name, p in parts(item) do
			table.insert(names, name)
			bottom = math.min(bottom, p.Position.Y - p.Size.Y / 2)
		end
		table.sort(names)
		eq(names, { "Fruit1", "Fruit2", "Fruit3", "Stem1", "Stem2" })
		near(item.Fruit1.Size, V3.new(1.20, 1.35, 1.90) * 0.5, "half size")
		Assert.near(bottom, 2, 1e-3, "resting on the pedestal top")
		eq(item:GetAttribute("Stage"), "item")
		local berries = {}
		for name in parts(Crop.item(nil, "I", "strawberry", nil, CF.new(), 1)) do
			table.insert(berries, name)
		end
		table.sort(berries)
		eq(#berries, 8, "4 berries + 4 calyxes, no leaves")
	end
)

test(
	"Moon Melon: Golden and Wet + Golden swap MoonGlow for the Golden light; Wet keeps it; plain brings it back",
	function()
		local m = build("moonmelon", "ripe")
		local function lights()
			local out = {}
			for _, d in m:GetDescendants() do
				if d.ClassName == "PointLight" then
					table.insert(out, d.Name)
				end
			end
			table.sort(out)
			return out
		end
		eq(lights(), { "MoonGlow" })
		Crop.setMuts(m, "wet")
		eq(lights(), { "MoonGlow" })
		Crop.setMuts(m, "golden")
		eq(lights(), { "GoldLight" })
		Crop.setMuts(m, "wetgolden")
		eq(lights(), { "GoldLight" })
		Crop.setMuts(m, nil)
		eq(lights(), { "MoonGlow" })
		eq(m.Fruit1.Reflectance, 0.05, "its own sheen back")
	end
)

test("mutations touch only the fruit parts; glints sit on the FxAnchor", function()
	local m = build("strawberry", "ripe", "golden")
	for name, p in parts(m) do
		if p:GetAttribute("Role") == "fruit" then
			eq(p.Color, if p:GetAttribute("Tone") == "detail" then Visuals.GOLD_LIGHT else Visuals.GOLD, name)
		elseif p.Parent.Name ~= "MutLook" then
			Assert.truthy(p.Color ~= Visuals.GOLD and p.Color ~= Visuals.GOLD_LIGHT, name .. " stays its own colour")
		end
	end
	eq(Crop.anchor(m).MutFx:GetAttribute("Key"), "golden")
	local sprout = build("strawberry", "sprout", "wet")
	eq(sprout:FindFirstChild("MutLook"), nil, "no fruit yet: glints only")
	eq(Crop.anchor(sprout).MutFx:GetAttribute("Key"), "wet")
end)
