--[[
Patch's look of Game Artist build-spec/05-patch.md (the parts, palette, faces, poses, LOD and the client's pose
driver), the 06-avatars Block Party crowd ring, and the Marketing rule: brass never in a frame with a Golden crop.
]]
local Assert = require("./mock/Assert")
local Client = require("./mock/Client")
local Engine = require("./mock/Engine")
local Farm = require("./mock/Farm")
local roblox = require("@lune/roblox")

local test, eq = Assert.test, Assert.eq

local engine = Engine.new()
local Patch = engine:require(engine:module("Shared/Models/Patch"))
local Config = engine:require(engine:module("Shared/Config"))
local PV = Config.PatchVisuals

local V3, CF, hex = roblox.Vector3, roblox.CFrame, roblox.Color3.fromHex
local O = CF.new(36, 0, -26)
local COUNTER = { Root = true, Counter = true, CounterTop = true }

local function near(a, b, msg)
	Assert.truthy((a - b).Magnitude < 1e-3, `{msg}: {a} vs {b}`)
end

local function goldish(c)
	local max, min = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	if max < 0.75 or max - min < 1e-6 or (max - min) / max < 0.7 or max ~= c.R then
		return false
	end
	local hue = 60 * (c.G - c.B) / (max - min)
	return hue >= 38 and hue <= 56
end

local function patch()
	local m = engine.Instance.new("Model")
	m.Name = "Patch"
	Patch.build(m, O)
	return m
end

local function parts(m)
	local out = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			out[d.Name] = d
		end
	end
	return out
end

test(
	"30 character parts + a 3-part Counter; SmoothPlastic (WoodPlanks Counter); no gold, Neon, Foil, Metal, lights",
	function()
		local m = patch()
		local character, counter = 0, 0
		for name, p in parts(m) do
			if COUNTER[name] then
				counter += 1
			else
				character += 1
				eq(p.Material, engine.Enum.Material.SmoothPlastic, name)
				Assert.truthy(not goldish(p.Color), name .. " is gold")
			end
		end
		eq({ character, counter }, { 30, 3 })
		eq({ m.Counter.Material, m.Counter.Color }, { engine.Enum.Material.WoodPlanks, hex("#BE8C5A") })
		eq(m.CounterTop.Color, hex("#A0784B"))
		for _, d in m:GetDescendants() do
			Assert.truthy(not d:IsA("Light") and d.ClassName ~= "ParticleEmitter" and d.ClassName ~= "Decal", d.Name)
		end
		eq(m.PrimaryPart, m.Root)
	end
)

test("the section 0 palette and the section 2 rest offsets", function()
	local m = patch()
	eq(
		{ m.PumpkinHead.Color, m.HeadShadeL.Color, m.HeadLight.Color },
		{ hex("#FF8C1A"), hex("#D9661A"), hex("#FFB066") }
	)
	eq({ m.Body.Color, m.Apron.Color, m.ApronPocket.Color }, { hex("#EADBB8"), hex("#5BC236"), hex("#2E7D32") })
	eq({ m.SeedPacket.Color, m.SeedDot.Color }, { hex("#FFF8E7"), hex("#E63246") })
	eq(
		{ m.ArmL.Color, m.LegR.Color, m.HandL.Color, m.FootL.Color },
		{ hex("#5BC236"), hex("#5BC236"), hex("#2E7D32"), hex("#7A4E2D") }
	)
	eq({ m.StemCurl.Color, m.Cowlick.Color }, { hex("#6B8E23"), hex("#2E7D32") })
	local head = m.PumpkinHead
	eq({ head.EyeL.Color, head.EyeShineL.Color, head.CheekL.Color }, { hex("#1E1B2E"), hex("#FFF8E7"), hex("#FF8FB1") })
	for _, spec in PV.parts do
		if spec.offset and spec.name ~= "ArmL" and spec.name ~= "ArmR" then
			near(
				m:FindFirstChild(spec.name).Position,
				(O * CF.new(spec.offset[1], spec.offset[2], spec.offset[3])).Position,
				spec.name
			)
		end
	end
	near(m.ArmL.Position, (O * CF.new(-1.05, 1.55, 0)).Position, "ArmL")
	near(head.EyeL.Position, (O * CF.new(-0.40, 2.95 + 0.15, -0.90)).Position, "EyeL on the head")
	Assert.near(head.Size.X / m.Body.Size.X, 2.0 / 1.5, 1e-6, "head 1.3x the body")
	Assert.truthy(
		m.HandL.Position.Y < m.ArmL.Position.Y and O:PointToObjectSpace(m.ArmL.Position).X < -1,
		"the arms hang at the sides"
	)
	eq(head:GetAttribute("Patch"), true)
end)

test("faces are part swaps: wow, thinking, wink, sleepy", function()
	local m = patch()
	local head = m.PumpkinHead
	local function shown(name)
		return head[name].Transparency < 1
	end
	eq(
		{ shown("EyeL"), shown("EyeR"), shown("Mouth"), shown("MouthOpen"), shown("Brow") },
		{ true, true, true, false, false }
	)
	Assert.near(head.CheekL.Transparency, 0.15, 1e-6)
	Patch.setFace(m, "wow")
	eq({ head.EyeL.Size, shown("MouthOpen"), shown("Mouth") }, { V3.one * 0.36, true, false })
	Patch.setFace(m, "thinking")
	eq({ shown("Brow"), head.Mouth.Size, head.EyeL.Size }, { true, V3.new(0.35, 0.08, 0.10), V3.one * 0.28 })
	near(head.EyeL.Position, (O * CF.new(-0.32, 3.10, -0.90)).Position, "EyeL drifts +0.08 x")
	Patch.setFace(m, "wink")
	eq({ shown("EyeR"), shown("EyeRFlat"), shown("EyeShineR"), shown("EyeL") }, { false, true, false, true })
	Patch.setFace(m, "sleepy")
	eq({ shown("EyeL"), shown("EyeR"), shown("EyeLFlat"), shown("EyeRFlat") }, { false, false, true, true })
	Assert.near(head.CheekR.Transparency, 0.4, 1e-6)
	Assert.truthy(math.abs(head.CFrame.RightVector.Y) > 0.1, "the sleepy head tilts")
	eq(m:GetAttribute("Face"), "sleepy")
	Patch.setFace(m, "happy")
	eq({ shown("EyeL"), shown("EyeShineR"), shown("EyeLFlat") }, { true, true, false })
end)

test("poses: wave raises the right arm, cheer both arms and a hop, lean forward over the counter", function()
	local m = patch()
	local restHand, restBody = m.HandR.Position, m.Body.Position
	Patch.setPose(m, "wave")
	Assert.truthy(m.HandR.Position.Y > m.PumpkinHead.Position.Y - 0.5, "the hand up by the head")
	near(
		m.HandL.Position,
		(O * CF.new(-1.05, 1.55, 0) * CF.Angles(0, 0, math.rad(-12)) * CF.new(0, -0.7, 0)).Position,
		"the left arm stays"
	)
	Patch.setPose(m, "cheer")
	Assert.truthy(
		m.HandL.Position.Y > m.Body.Position.Y + 0.5 and m.HandR.Position.Y > m.Body.Position.Y + 0.5,
		"both arms up"
	)
	Assert.near(m.FootL.Position.Y - 0.18, 0.3, 1e-3, "the hop")
	Patch.setPose(m, "lean")
	Assert.truthy(m.PumpkinHead.Position.Z < restBody.Z - 0.6, "towards the counter (-Z)")
	Assert.truthy(m.HandR.Position.Z < restHand.Z, "the arms fold forward")
	Patch.setPose(m, "idle")
	near(m.HandR.Position, restHand, "idle is the rest pose")
	-- the hand always rides its arm
	for _, anim in Patch.ANIMS do
		Patch.setPose(m, anim)
		near(m.HandR.Position, (m.ArmR.CFrame * CF.new(0, -0.7, 0)).Position, anim .. ": the hand on the arm")
	end
end)

test("the low counter (top ~1.8): Patch's head clears it by a stud; the lean puts his chin on it", function()
	local m = patch()
	local top = m.CounterTop.Position.Y + m.CounterTop.Size.Y / 2
	Assert.near(top, 1.85, 1e-3, "CounterTop at 1.775 (top 1.85, the spec's ~1.8)")
	eq(m.Counter.Size, V3.new(8, 1.7, 3))
	Assert.near(m.Counter.Position.Y, 0.85, 1e-5)
	Assert.truthy(m.PumpkinHead.Position.Y - top >= 1 - 1e-6, "the head clears the counter by >= 1")
	Assert.truthy(m.StemTip.Position.Y > 4, "Patch keeps his authored ~4.0 height")
	Patch.setPose(m, "lean")
	local head = m.PumpkinHead.Position.Y
	Assert.truthy(head >= 2.55 and head <= 2.65, `the head centre at {head}`)
	Assert.near(head - m.PumpkinHead.Size.Y / 2, 1.8, 0.1, "the chin at the CounterTop")
	Assert.truthy(math.abs(m.HandR.Position.Y - top) < 0.6, "the forearms on the counter")
	Assert.truthy(O:PointToObjectSpace(m.HandR.Position).Z < -1.5, "the hands over the counter")
	near(m.LegL.Position, (O * CF.new(-0.35, 0.55, 0)).Position, "the legs stay put")
end)

test("LOD: beyond 120 studs SeedPacket, SeedDot, the eye shines, cheeks and Cowlick hide", function()
	local m = patch()
	Patch.setFar(m, true)
	for _, name in { "SeedPacket", "SeedDot", "Cowlick" } do
		eq(m[name].Transparency, 1, name)
	end
	for _, name in { "EyeShineL", "EyeShineR", "CheekL", "CheekR" } do
		eq(m.PumpkinHead[name].Transparency, 1, name)
	end
	eq(m.PumpkinHead.EyeL.Transparency, 0, "the silhouette stays")
	Patch.setFar(m, false)
	eq({ m.SeedDot.Transparency, m.PumpkinHead.EyeShineL.Transparency }, { 0, 0 })
	Assert.near(m.PumpkinHead.CheekL.Transparency, 0.15, 1e-6)
end)

test('the street rig keeps the contract: PumpkinHead, Counter.ShopPrompt, Animations (ids ""), Anim / Face', function()
	local ctx = Farm.setup()
	local rig = ctx.engine.workspace.Street.Patch
	Assert.truthy(rig.PumpkinHead and rig.Counter.ShopPrompt, "the required names")
	for _, a in rig.Animations:GetChildren() do
		eq(a.AnimationId, "", a.Name)
	end
	Assert.truthy(rig:FindFirstChildOfClass("AnimationController"):FindFirstChildOfClass("Animator"), "an Animator")
	eq({ rig:GetAttribute("Anim"), rig:GetAttribute("Face") }, { "idle", "happy" })
	eq(rig.Body.Color, hex("#EADBB8"))
	local p = Farm.join(ctx, 1)
	eq(rig:GetAttribute("Anim"), "point", "the plant line")
	ctx.engine:advance(Config.Patch.lines.plant.seconds + 0.5)
	eq({ rig:GetAttribute("Anim"), rig:GetAttribute("Face") }, { "idle", "happy" }, "back to idle after the line")
	Assert.truthy(p, "joined")
end)

-- a client with a Patch rig on its street
local function client()
	local c = Client.boot()
	local m = c.engine.Instance.new("Model")
	m.Name = "Patch"
	local P = c.engine:require(c.engine:module("Shared/Models/Patch"))
	P.build(m, CF.new(36, 0, -26))
	m.Parent = c.engine.workspace.Street
	c.engine.workspace.CurrentCamera.CFrame = CF.new(36, 6, -40)
	c.engine:advance(0.1)
	return c, m, P, c.controllers.PatchRigController
end

test("the client tweens to each Anim (0.25 s Quad / 0.35 s Back), breathes in idle, and swaps the face", function()
	local c, m, P, ctrl = client()
	eq(ctrl.rig(), m)
	local y1 = m.Body.Position.Y
	c.engine:advance(0.5)
	Assert.truthy(math.abs(m.Body.Position.Y - y1) > 1e-4, "idle breathes")
	m:SetAttribute("Anim", "announce")
	c.engine:advance(0.1)
	local target = P.pose("announce")
	Assert.truthy(math.abs(ctrl.params().nod - target.nod) > 0.5, "mid tween")
	c.engine:advance(0.4)
	eq(ctrl.params().nod, target.nod, "announce reached in 0.35 s")
	m:SetAttribute("Anim", "cheer")
	c.engine:advance(0.3)
	Assert.truthy(ctrl.params().lift.Y > 0.2, "the hop")
	c.engine:advance(0.5)
	Assert.near(ctrl.params().lift.Y, 0, 1e-6, "landed after 0.4 s")
	m:SetAttribute("Face", "sleepy")
	c.engine:advance(0.1)
	eq(m.PumpkinHead.EyeLFlat.Transparency, 0)
	c.engine.workspace.CurrentCamera.CFrame = CF.new(36, 6, -200)
	c.engine:advance(0.1)
	eq(m.SeedDot.Transparency, 1, "far: the LOD")
	eq(c.engine.errors, {})
end)

test("the Block Party crowd: 7 farmers 8-12 studs from the sunflower, facing it, in OUTFIT_ORDER", function()
	local ctx = Farm.setup({ studio = true })
	local p = Farm.join(ctx, 1)
	local Farmer = ctx.engine:require(ctx.engine:module("Shared/Models/Farmer"))
	for _, scene in { "block_party_rain", "block_party_golden" } do
		Farm.call(ctx, p, "DevCommand", "run", { cmd = "capture", args = { scene } })
		local stage = ctx.engine.workspace.Capture.Stage
		local centre = stage.Sunflower.Stem.Position
		local n = 0
		for i = 1, 8 do
			local f = stage:FindFirstChild("Farmer" .. i)
			if f then
				n += 1
				eq(f:GetAttribute("Outfit"), Farmer.OUTFIT_ORDER[(i - 1) % 6 + 1], f.Name)
				local d = V3.new(centre.X - f.HumanoidRootPart.Position.X, 0, centre.Z - f.HumanoidRootPart.Position.Z)
				Assert.truthy(d.Magnitude >= 8 and d.Magnitude <= 12, `{scene}: {f.Name} at {d.Magnitude}`)
			end
		end
		Assert.truthy(n >= 6 and n <= 8, `{scene}: {n} farmers`)
	end
end)

test("Marketing: no capture scene has brass and a Golden crop in one frame", function()
	local ctx = Farm.setup({ studio = true })
	local p = Farm.join(ctx, 1)
	local brass = hex(Config.Brass.hex)
	for _, scene in
		{
			"street",
			"offline_before",
			"offline_after",
			"golden_reveal",
			"block_party_rain",
			"block_party_golden",
			"pedestals",
			"icon",
		}
	do
		Farm.call(ctx, p, "DevCommand", "run", { cmd = "capture", args = { scene } })
		local golden, brassy = false, false
		for _, d in ctx.engine.workspace.Capture.Stage:GetDescendants() do
			local muts = d:GetAttribute("Muts")
			if d:GetAttribute("Crop") and muts and string.find(muts, "golden") then
				golden = true
			end
			local ok, colour = pcall(function()
				return d.Color
			end)
			if d:IsA("BasePart") and ok and colour == brass then
				brassy = true
			end
		end
		Assert.truthy(not (golden and brassy), scene .. ": brass with a Golden crop")
	end
end)
