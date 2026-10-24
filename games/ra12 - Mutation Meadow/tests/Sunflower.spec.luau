--[[
The Block Party sunflower of Game Artist build-spec/03-sunflower.md (GA-03): the 38 art parts and their bloom rest
pose, the four poses (a connected stem, the head lower each stage down), and SunflowerController's tweens, wilt,
bloom VFX, thirsty icon and LOD on the streamed street Model.
]]
local Assert = require("./mock/Assert")
local Client = require("./mock/Client")
local Engine = require("./mock/Engine")
local roblox = require("@lune/roblox")

local test, eq = Assert.test, Assert.eq

local engine = Engine.new()
local Sunflower = engine:require(engine:module("Shared/Models/Sunflower"))
local Config = engine:require(engine:module("Shared/Config"))
local SV = Config.SunflowerVisuals

local V3, CF, hex = roblox.Vector3, roblox.CFrame, roblox.Color3.fromHex
local O = CF.new(10, 0, -20) * CF.Angles(0, math.pi, 0)

local function near(a, b, msg)
	Assert.truthy((a - b).Magnitude < 1e-3, `{msg}: {a} vs {b}`)
end

local function flower()
	local m = Sunflower.build(nil, O)
	Sunflower.buildArt(m)
	return m
end

local function artParts(m)
	local out = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Stem" then
			table.insert(out, d)
		end
	end
	return out
end

-- a stem segment's two ends (Kit.cylinder runs along the part's X)
local function ends(part)
	local half = part.CFrame.RightVector * part.Size.X / 2
	return part.Position - half, part.Position + half
end

test("38 SmoothPlastic art parts (+ the server Stem); nothing collides, no Neon / Foil / Metal, no gold", function()
	local m = flower()
	local list = artParts(m)
	eq(#list, 38)
	eq(#list, SV.artParts)
	local names = {}
	for _, p in list do
		names[p.Name] = true
		eq(p.Material, engine.Enum.Material.SmoothPlastic, p.Name)
		eq({ p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch }, { true, false, false, false }, p.Name)
		Assert.truthy(p.Color ~= hex("#FFC300"), p.Name .. " is gold")
	end
	for _, name in { "Root", "StemBase", "Stem1", "Stem4", "LeafL1", "LeafR2", "HeadPivot", "Disc" } do
		Assert.truthy(names[name], name)
	end
	for i = 1, 8 do
		Assert.truthy(m.HeadPivot:FindFirstChild("SeedDot" .. i), "SeedDot" .. i)
	end
	for i = 1, 18 do
		eq(m.HeadPivot["Petal" .. i].ClassName, "WedgePart")
	end
	eq(m.HeadPivot.FxBloom.ClassName, "Attachment")
	eq(m.PrimaryPart, m.Root)
	eq(m.Stem.Transparency, 1, "the server Stem is the prompt host, not the look")
	eq(Sunflower.buildArt(m), Sunflower.parts(m), "built once")
	eq(#artParts(m), 38)
end)

test("the bloom rest pose: section 2 offsets, the colours, the disc centre at ~21 studs", function()
	local m = flower()
	for _, spec in SV.parts do
		near(
			m:FindFirstChild(spec.name, true).Position,
			(O * CF.new(spec.offset[1], spec.offset[2], spec.offset[3])).Position,
			spec.name
		)
	end
	local disc = m.HeadPivot.Disc
	Assert.near(disc.Position.Y, 21.1, 1e-3)
	near(disc.CFrame.RightVector:Cross(O.LookVector), V3.zero, "the disc faces the front")
	eq(disc.Color, hex("#7A4E2D"))
	eq(m.HeadPivot.SeedDot1.Color, hex("#5C3A1F"))
	eq(m.Stem2.Color, hex("#5BC236"))
	eq({ m.LeafL1.Color, m.LeafL2.Color }, { hex("#2E7D32"), hex("#4E9A2A") })
	for i = 1, 18 do
		local p = m.HeadPivot["Petal" .. i]
		eq(p.Color, hex("#FFD23F"))
		local inner = p.Position - p.CFrame.UpVector * (p.Size.Y / 2)
		Assert.near((inner - disc.Position).Magnitude, SV.head.petals.rim, 1e-2, `Petal{i}'s base on the rim`)
	end
	eq(m:GetAttribute("Pose"), "bloom")
	-- section 2.4: the petals stay in the disc plane; the top petal peaks ~23.5, its outer corner a little above
	Assert.near(m.HeadPivot.Petal1.Position.Y, 23.5, 0.05, "the top petal")
	for i = 1, 18 do
		local p = m.HeadPivot["Petal" .. i]
		Assert.near(math.abs(p.CFrame.RightVector:Dot(O.LookVector)), 1, 0.05, `Petal{i} lies in the disc plane`)
	end
end)

test("section 3: the disc-centre heights win (the stem leans only); Stem4 reaches the head", function()
	local m = flower()
	for stage, range in SV.discY do
		Sunflower.setPose(m, stage)
		local y = m.HeadPivot.Disc.Position.Y
		Assert.truthy(y >= range[1] and y <= range[2], `{stage}: disc at {y}, wants {range[1]}-{range[2]}`)
	end
	Sunflower.setPose(m, "drooping")
	local spec = SV.poses.drooping
	eq({ spec.tilt, spec.move }, { { 8, 7, 6, 5 }, { 0, -5.5, 3.2 } }, "the delta's tilts, the kept translate")
	eq({ SV.poses.standing.tilt[1], SV.poses.perking.tilt[1] }, { 2, 4 }, "standing +2; perking +5 nudged to +4")
end)

test(
	"every pose keeps the stem joined and the head on Stem4; each stage down is lower; drooping desaturates",
	function()
		local m = flower()
		local heights = {}
		for _, stage in { "bloom", "standing", "perking", "drooping" } do
			Sunflower.setPose(m, stage)
			local _, top = ends(m.StemBase)
			for _, name in { "Stem1", "Stem2", "Stem3", "Stem4" } do
				local bottom, nextTop = ends(m[name])
				near(bottom, top, `{stage}: {name} sits on the one below`)
				top = nextTop
			end
			Assert.truthy((m.HeadPivot.Position - top).Magnitude < 0.25, stage .. ": the head on Stem4")
			heights[stage] = m.HeadPivot.Disc.Position.Y
		end
		Assert.truthy(heights.bloom > heights.standing, "standing below bloom")
		Assert.truthy(heights.standing > heights.perking, "perking below standing")
		Assert.truthy(heights.perking > heights.drooping, "drooping lowest")
		Sunflower.setPose(m, "drooping")
		eq(m.HeadPivot.Petal1.Color, hex("#E6C96D"))
		eq({ m.Stem1.Color, m.LeafR1.Color, m.LeafR2.Color }, { hex("#6EAF56"), hex("#3F7041"), hex("#5B8B44") })
		eq(m.HeadPivot.Disc.Color, hex("#6B4528"))
		Assert.truthy(m.HeadPivot.CFrame.LookVector.Y < -0.8, "the face (-Z) toward the ground")
		local wilt = Sunflower.wiltPose(1)
		eq(wilt.petal, hex("#C8B070"), "deep wilt")
		eq(wilt.tilt, Sunflower.pose("drooping").tilt, "the wilt ends in drooping's pose")
	end
)

-- a client whose camera looks at the street sunflower from d studs
local function client(d)
	local c = Client.boot()
	local model = c.engine.workspace.Street.Sunflower
	local camera = c.engine.workspace.CurrentCamera
	camera.CFrame = CF.new(model.Stem.Position + V3.new(0, 10, -(d or 30)))
	c.engine:advance(0.1)
	return c, model, c.controllers.SunflowerController
end

local function pose(model, stage)
	local m = Sunflower.build(nil, model:GetAttribute("Origin"))
	Sunflower.buildArt(m)
	Sunflower.setPose(m, stage)
	return m
end

test("the client builds the art under the streamed Model; the Stem keeps its Water prompt", function()
	local c, model, ctrl = client()
	eq(ctrl.model(), model)
	eq(#artParts(model), 38)
	Assert.truthy(model.Stem:FindFirstChild("Water"), "the Water prompt")
	eq(c.engine.errors, {})
end)

test("watering steps drooping -> perking -> standing: a 0.6 s Back Out tween each", function()
	local c, model = client()
	for _, stage in { "perking", "standing" } do
		model:SetAttribute("Phase", "open")
		model:SetAttribute("Stage", stage)
		c.engine:advance(0.3)
		local mid = model.HeadPivot.Position
		Assert.truthy((mid - pose(model, stage).HeadPivot.Position).Magnitude > 1e-2, stage .. ": still moving")
		c.engine:advance(0.4)
		near(model.HeadPivot.Position, pose(model, stage).HeadPivot.Position, stage .. " reached")
		near(model.HeadPivot.Petal5.Position, pose(model, stage).HeadPivot.Petal5.Position, stage .. " petals")
	end
	eq(c.engine.errors, {})
end)

test("bloom: a 1.5 s tween, the petal pop (18) + burst (24) and the Rain column, gone after 1 s", function()
	local c, model, ctrl = client()
	model:SetAttribute("Weather", "rain")
	model:SetAttribute("Phase", "weather")
	model:SetAttribute("Stage", "bloom")
	c.engine:advance(0.1)
	local at = model.HeadPivot.FxBloom
	eq({ at.PetalPop:GetAttribute("Emitted"), at.Burst:GetAttribute("Emitted") }, { 18, 24 })
	eq(at.Column.Color.Keypoints[1].Value, hex("#3FA7F5"))
	eq(at.Burst.Color.Keypoints[1].Value, hex("#3FA7F5"))
	eq({ at.Column.Width0, at.Column.Width1, at.Column.Segments }, { 2.5, 0.4, 8 })
	Assert.near(model.HeadPivot.BloomLight.Range, 20, 1e-6)
	c.engine:advance(0.6)
	Assert.truthy(model.HeadPivot.BloomLight.Brightness < 1.2, "the flash fades")
	Assert.truthy((model.HeadPivot.Position - pose(model, "bloom").HeadPivot.Position).Magnitude > 1e-2, "still rising")
	c.engine:advance(0.5)
	eq(at:FindFirstChild("Column"), nil, "the VFX last 1 s")
	eq(model.HeadPivot:FindFirstChild("BloomLight"), nil)
	c.engine:advance(0.5)
	near(model.HeadPivot.Position, pose(model, "bloom").HeadPivot.Position, "bloom after 1.5 s")
	eq(ctrl.fx(), nil)
end)

test("Golden Hour colours the column #FFC300; reducedFx halves the emits and skips the column and light", function()
	local c, model = client()
	local Visuals = c.engine:require(c.engine:module("Shared/Visuals"))
	model:SetAttribute("Weather", "goldenHour")
	model:SetAttribute("Stage", "bloom")
	c.engine:advance(0.1)
	eq(model.HeadPivot.FxBloom.Column.Color.Keypoints[1].Value, hex("#FFC300"))
	c.engine:advance(2)
	eq(model.HeadPivot.Petal1.Color, hex("#FFD23F"), "the flower itself never gilt")
	model:SetAttribute("Stage", "drooping")
	c.engine:advance(2)
	Visuals.setReduced(true)
	model:SetAttribute("Stage", "bloom")
	c.engine:advance(0.1)
	local at = model.HeadPivot.FxBloom
	eq({ at.PetalPop:GetAttribute("Emitted"), at.Burst:GetAttribute("Emitted") }, { 9, 12 })
	eq(at:FindFirstChild("Column"), nil)
	eq(model.HeadPivot:FindFirstChild("BloomLight"), nil)
	Visuals.setReduced(false)
end)

test("wilt: a Linear sag from bloom into drooping over 60 s (by WiltEndsAt)", function()
	local c, model = client()
	local Clock = c.engine:require(c.engine:module("Shared/Clock"))
	model:SetAttribute("Stage", "bloom")
	c.engine:advance(2)
	model:SetAttribute("WiltEndsAt", Clock.now() + 30)
	model:SetAttribute("Phase", "wilt")
	c.engine:advance(0.1)
	local half = Sunflower.build(nil, model:GetAttribute("Origin"))
	Sunflower.buildArt(half)
	Sunflower.apply(half, Sunflower.wiltPose(0.5 + 0.1 / 60))
	Assert.truthy((model.HeadPivot.Position - half.HeadPivot.Position).Magnitude < 0.02, "halfway at 30 s left")
	local bloomY, droopY = pose(model, "bloom").HeadPivot.Position.Y, pose(model, "drooping").HeadPivot.Position.Y
	local y = model.HeadPivot.Position.Y
	Assert.truthy(y < bloomY and y > droopY, "mid-wilt")
	c.engine:advance(30)
	near(model.HeadPivot.Position, pose(model, "drooping").HeadPivot.Position, "fully sagged")
	eq(model.HeadPivot.Petal1.Color, hex("#C8B070"))
	model:SetAttribute("Phase", "drooped")
	model:SetAttribute("Stage", "drooping")
	c.engine:advance(0.7)
	eq(model.HeadPivot.Petal1.Color, hex("#E6C96D"), "then the drooping colours")
end)

test("the thirsty icon: a #3FA7F5 circle with a white ! while open and short of the goal, bobbing 3.3-3.7", function()
	local c, model = client()
	model:SetAttribute("Phase", "open")
	model:SetAttribute("Waters", 3)
	model:SetAttribute("Goal", 20)
	local gui = model.HeadPivot.Thirsty
	local lo, hi = math.huge, -math.huge
	for _ = 1, 30 do
		c.engine:advance(0.1)
		lo, hi = math.min(lo, gui.StudsOffset.Y), math.max(hi, gui.StudsOffset.Y)
	end
	eq(gui.Enabled, true)
	Assert.truthy(lo < 3.32 and lo >= 3.3 - 1e-6 and hi > 3.68 and hi <= 3.7 + 1e-6, `bob {lo}..{hi}`)
	eq({ gui.Adornee, gui.MaxDistance, gui.AlwaysOnTop }, { model.HeadPivot, 80, false })
	eq(gui.Icon.Circle.BackgroundColor3, hex("#3FA7F5"))
	eq({ gui.Icon.Circle.Mark.Text, gui.Icon.Circle.Mark.TextColor3 }, { "!", roblox.Color3.new(1, 1, 1) })
	model:SetAttribute("Waters", 20)
	c.engine:advance(0.1)
	eq(gui.Enabled, false, "the goal is met")
	model:SetAttribute("Waters", 5)
	model:SetAttribute("Phase", "weather")
	c.engine:advance(0.1)
	eq(gui.Enabled, false, "hidden in the weather")
end)

test("beyond 160 studs: the pose freezes, the seed dots and every other petal hide (9 stay), no VFX", function()
	local c, model = client(200)
	eq(model:GetAttribute("Far"), true)
	local shown = 0
	for i = 1, 18 do
		if model.HeadPivot["Petal" .. i].Transparency == 0 then
			shown += 1
		end
	end
	eq(shown, 9)
	eq(model.HeadPivot.SeedDot1.Transparency, 1)
	local frozen = model.HeadPivot.Position
	model:SetAttribute("Stage", "bloom")
	c.engine:advance(2)
	near(model.HeadPivot.Position, frozen, "frozen")
	eq(model.HeadPivot.FxBloom:FindFirstChild("PetalPop"), nil, "no VFX far away")
	c.engine.workspace.CurrentCamera.CFrame = CF.new(model.Stem.Position + V3.new(0, 10, -30))
	model:SetAttribute("Stage", "standing")
	c.engine:advance(1)
	eq(model:GetAttribute("Far"), false)
	eq(model.HeadPivot.SeedDot1.Transparency, 0)
	near(model.HeadPivot.Position, pose(model, "standing").HeadPivot.Position, "back near: posed again")
end)
