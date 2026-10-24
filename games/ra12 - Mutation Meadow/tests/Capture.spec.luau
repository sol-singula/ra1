local Assert = require("./mock/Assert")
local Client = require("./mock/Client")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")
local roblox = require("@lune/roblox")

local test, eq = Assert.test, Assert.eq

local SCENES = {
	"street",
	"offline_before",
	"offline_after",
	"golden_reveal",
	"block_party_rain",
	"block_party_golden",
	"pedestals",
	"icon",
}

local function dev()
	local ctx = Farm.setup({ studio = true })
	local p = Farm.join(ctx, 1)
	local function capture(...)
		return Farm.call(ctx, p, "DevCommand", "run", { cmd = "capture", args = { ... } })
	end
	local function mod(path)
		return ctx.engine:require(ctx.engine:module(path))
	end
	ctx.Capture = mod("Server/Services/CaptureService")
	ctx.CropModel = mod("Shared/Models/Crop")
	ctx.Farmer = mod("Shared/Models/Farmer")
	ctx.Visuals = mod("Shared/Visuals")
	ctx.PatchModel = mod("Shared/Models/Patch")
	return ctx, p, capture
end

local function stage(ctx)
	return ctx.engine.workspace.Capture.Stage
end

local function camOf(ctx, scene)
	return ctx.engine.workspace.Capture.Cams[scene]
end

-- the staged crop models
local function crops(ctx)
	local out = {}
	for _, d in stage(ctx):GetChildren() do
		if d:GetAttribute("Crop") then
			table.insert(out, d)
		end
	end
	return out
end

-- every staged crop's mutation key, and whether any rain VFX is staged
local function look(ctx)
	local muts, rain = {}, false
	for _, c in crops(ctx) do
		local key = c:GetAttribute("Muts") or "none"
		muts[key] = (muts[key] or 0) + 1
	end
	for _, d in stage(ctx):GetDescendants() do
		if d.Name == "RainFx" then
			rain = true
		end
	end
	return muts, rain
end

-- the staged farmers: real avatars (a Humanoid inside)
local function farmers(ctx)
	local out = {}
	for _, d in stage(ctx):GetChildren() do
		if d:FindFirstChildOfClass("Humanoid") then
			table.insert(out, d)
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

local function flat(v)
	return roblox.Vector3.new(v.X, 0, v.Z)
end

-- where a point sits in a camera's frame: x and y in -1..1 (the frame's edges), and its depth
local function onScreen(cam, point)
	local fov = math.rad(cam:GetAttribute("FieldOfView"))
	local aspect = cam:GetAttribute("Width") / cam:GetAttribute("Height")
	local p = cam.CFrame:Inverse() * point
	local depth = -p.Z
	local half = math.tan(fov / 2) * depth
	return p.X / (half * aspect), p.Y / half, depth
end

-- a part counts as gold when it's a saturated yellow-orange-gold
-- gold: a saturated, bright yellow-orange (#FFC300 is hue 46, saturation 1); the warm creams and straws of
-- 05-patch / 06-avatars (#FFB066, #E8C56A, #F5C878) and the satin brass #B08D57 are muted, not gold
local function goldish(c)
	local max, min = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
	if max < 0.75 or max - min < 1e-6 or (max - min) / max < 0.7 or max ~= c.R then
		return false
	end
	local hue = 60 * (c.G - c.B) / (max - min)
	return hue >= 38 and hue <= 56
end

-- (both stop at the staging folder)
local function inside(d, ancestorName)
	local p = d.Parent
	while p and p.Name ~= "Stage" do
		if p.Name == ancestorName then
			return true
		end
		p = p.Parent
	end
	return false
end

local function cropOf(d)
	local p = d.Parent
	while p and p.Name ~= "Stage" do
		if p:GetAttribute("Crop") then
			return p
		end
		p = p.Parent
	end
	return nil
end

test("every scene id resolves to a camera (1920x1080, the icon 1024x1024)", function()
	local ctx, _, capture = dev()
	for _, scene in SCENES do
		eq(capture(scene), true, scene)
		local cam = ctx.engine.workspace.Capture.Cams:FindFirstChild(scene)
		Assert.truthy(cam, scene .. " camera")
		local square = scene == "icon"
		eq(
			{ cam:GetAttribute("Width"), cam:GetAttribute("Height") },
			if square then { 1024, 1024 } else { 1920, 1080 },
			scene
		)
		eq(ctx.engine.workspace.Capture:GetAttribute("Scene"), scene)
		Assert.truthy(#stage(ctx):GetChildren() > 0, scene .. " staged")
	end
	eq(ctx.engine.errors, {})
end)

test("only the listed args: block_party and junk are unknown_scene; reveal needs golden_reveal", function()
	local _, _, capture = dev()
	for _, args in
		{
			{ "block_party" },
			{ "nope" },
			{ "hud", "maybe" },
			{ "guides" },
			{ "street", "extra" },
			{ "free", "now" },
			{ "reveal", "now" },
			{ "size", "big" },
		}
	do
		eq({ capture(table.unpack(args)) }, { false, "unknown_scene" }, table.concat(args, " "))
	end
	for _, args in
		{ { "hud", "off" }, { "hud", "on" }, { "guides", "on" }, { "guides", "off" }, { "free" }, { "size" } }
	do
		eq(capture(table.unpack(args)), true, table.concat(args, " "))
	end
	eq({ capture("reveal") }, { false, "no_reveal" }, "no scene yet")
	capture("icon")
	eq({ capture("reveal") }, { false, "no_reveal" }, "only in golden_reveal")
end)

test("a non-dev call outside Studio is a no-op (dev_gate)", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	eq({ Farm.call(ctx, p, "DevCommand", "run", { cmd = "capture", args = { "street" } }) }, { nil, "no_result" })
	eq(ctx.engine.workspace:FindFirstChild("Capture"), nil)
	eq(ctx.Net.dropStats().byReason.dev_gate, 1)
end)

test(
	"outside Studio even the admin (Config.AdminUserIds) is dropped at the dev gate; capture itself refuses too",
	function()
		local ctx = Farm.setup()
		local Config = ctx.engine:require(ctx.engine:module("Shared/Config"))
		eq(Config.AdminUserIds, { 11787294097 })
		local admin = Farm.join(ctx, 11787294097)
		eq(
			{ Farm.call(ctx, admin, "DevCommand", "run", { cmd = "capture", args = { "street" } }) },
			{ nil, "no_result" }
		)
		eq(ctx.Net.dropStats().byReason.dev_gate, 1)
		local Capture = ctx.engine:require(ctx.engine:module("Server/Services/CaptureService"))
		eq({ Capture.run({ "street" }) }, { false, "studio_only" }, "the second check, behind the gate")
		eq(ctx.engine.workspace:FindFirstChild("Capture"), nil)
	end
)

test("capture never calls SaveQueue or touches a profile", function()
	local ctx, p, capture = dev()
	local SaveQueue = ctx.engine:require(ctx.engine:module("Server/Save/SaveQueue"))
	local calls = 0
	local real = SaveQueue.request
	SaveQueue.request = function(...)
		calls += 1
		return real(...)
	end
	local before = Server.deepCopy(ctx.Data.get(p))
	local writes = #ctx.engine.dataLog
	for _, scene in SCENES do
		capture(scene)
	end
	capture("golden_reveal")
	capture("reveal")
	capture("hud", "off")
	capture("free")
	eq(calls, 0)
	local after = Server.deepCopy(ctx.Data.get(p))
	-- the clock runs while scenes stage: only the played-time counters move
	after.firstSession.playedSec, after.playtime = before.firstSession.playedSec, before.playtime
	eq(after, before)
	eq(#ctx.engine.dataLog, writes)
	eq(ctx.Weather.current(), nil, "the real weather is untouched")
end)

test("the farmers are real R15 avatars: varied descriptions, the default face, skin-coloured mitten hands", function()
	local ctx, _, capture = dev()
	capture("street")
	local list = farmers(ctx)
	eq(#list, 6)
	local outfits, skins = {}, {}
	for _, f in list do
		outfits[f:GetAttribute("Outfit")] = true
		skins[f:GetAttribute("Skin")] = true
		local humanoid = f:FindFirstChildOfClass("Humanoid")
		eq(humanoid.RigType, ctx.engine.Enum.HumanoidRigType.R15)
		eq(humanoid.DisplayDistanceType, ctx.engine.Enum.HumanoidDisplayDistanceType.None, "no name tag")
		local desc = humanoid:FindFirstChildOfClass("HumanoidDescription")
		eq({ desc.Face, desc.Shirt, desc.Pants }, { 0, 0, 0 }, "the default face, colours instead of clothing")
		eq(f.Head.face.Texture, "rbxasset://textures/face.png", f.Name .. ": the default face")
		eq(
			{ f.LeftHand.Size, f.RightHand.Size },
			{ roblox.Vector3.new(1.05, 0.55, 1.05), roblox.Vector3.new(1.05, 0.55, 1.05) },
			"mittens"
		)
		local skin = desc.HeadColor
		eq(f.UpperTorso.Color, desc.TorsoColor, "the shirt")
		eq(f.LeftUpperArm.Color, desc.TorsoColor, "sleeves in the shirt colour")
		eq(f.LeftUpperLeg.Color, desc.LeftLegColor, "trousers")
		if f:GetAttribute("Outfit") ~= "gloves" then
			eq({ f.LeftHand.Color, f.RightHand.Color }, { skin, skin }, f.Name .. ": skin-coloured hands")
		end
		eq(f.HumanoidRootPart.Anchored, true, "staged, not falling")
		Assert.near(f.LeftFoot.Position.Y - f.LeftFoot.Size.Y / 2, 0, 0.05, f.Name .. " stands on the ground")
	end
	eq(outfits, { overalls = true, sunhat = true, apron = true, rainboots = true, flannel = true, gloves = true })
	eq(#ctx.engine.avatars, 6, "built from HumanoidDescriptions")
	local n = 0
	for _ in skins do
		n += 1
	end
	eq(n, 6, "six skin tones")
end)

test(
	"poses (06-avatars section 4): joint poses for idle / wave / cheer / watering / surprised; the stock walk",
	function()
		local ctx, _, capture = dev()
		capture("street")
		ctx.engine:advance(1)
		local byId = {}
		for _, t in ctx.engine.animTracks do
			byId[t.AnimationId] = t
		end
		local walk = byId[ctx.Farmer.ANIMS.walk]
		Assert.truthy(walk, "walk played")
		eq({ walk.IsPlaying, walk.Speed }, { true, 0 }, "walk frozen")
		for _, name in { "idle", "wave", "cheer" } do
			eq(ctx.Farmer.ANIMS[name], nil, name .. " needs no animation id")
		end
		local f = stage(ctx).Farmer1
		local rest = f.RightUpperArm.RightShoulder.C0
		ctx.Farmer.pose(f, "wave")
		local up = (rest:Inverse() * f.RightUpperArm.RightShoulder.C0):ToEulerAnglesXYZ()
		Assert.near(math.deg(up), 140, 1e-3, "wave: the right arm up 140")
		ctx.Farmer.pose(f, "cheer")
		Assert.near(
			(f.LowerTorso.Root.C0.Position - f.HumanoidRootPart.CFrame:Inverse() * f.LowerTorso.CFrame.Position).Y,
			0.4,
			1e-3,
			"cheer hops 0.4"
		)
		ctx.Farmer.pose(f, "idle")
		eq(f.RightUpperArm.RightShoulder.C0, rest, "idle resets the arm")
		local waterer = stage(ctx).Farmer3
		eq(waterer:GetAttribute("Pose"), "watering")
		local can = waterer.WateringCan.Can
		eq({ can.Size, can.Color, can.Material }, {
			roblox.Vector3.new(0.5, 0.6, 0.35),
			roblox.Color3.fromHex("#5AA0D2"),
			ctx.engine.Enum.Material.SmoothPlastic,
		})
		eq(can:FindFirstChildOfClass("WeldConstraint").Part0, waterer.LeftHand, "the can in the left hand")
		ctx.Farmer.pose(waterer, "surprised")
		eq(waterer:FindFirstChild("WateringCan"), nil, "a new pose resets the last")
		eq(waterer:GetAttribute("Pose"), "surprised")
		eq(ctx.Farmer.pose(waterer, "dance"), false)
	end
)

test("no gold on farmers: the #E8C56A Fabric sunhat, #3A7CBC rubber rainboots, no Metal / Foil anywhere", function()
	local ctx, _, capture = dev()
	local O = ctx.Farmer.OUTFITS
	eq(O.sunhat.hat, roblox.Color3.fromHex("#E8C56A"))
	eq(O.sunhat.shirt, roblox.Color3.fromHex("#F5C878"))
	eq(O.rainboots.boots, roblox.Color3.fromHex("#3A7CBC"))
	local banned = { "#FFC300", "#FFF1A8", "#B08D57" }
	for key, o in O do
		for part, c in o do
			if typeof(c) == "Color3" then
				Assert.truthy(not goldish(c), `{key}.{part} is gold`)
				for _, h in banned do
					Assert.truthy(c ~= roblox.Color3.fromHex(h), `{key}.{part} is {h}`)
				end
			end
		end
	end
	capture("street")
	for _, f in farmers(ctx) do
		for _, d in f:GetDescendants() do
			local ok, material = pcall(function()
				return d.Material -- the mock rig's parts leave it unset (Plastic)
			end)
			if d:IsA("BasePart") and ok then
				Assert.truthy(
					material ~= ctx.engine.Enum.Material.Metal and material ~= ctx.engine.Enum.Material.Foil,
					d:GetFullName()
				)
			end
			Assert.truthy(
				not d:IsA("Light") and d.ClassName ~= "ParticleEmitter",
				d:GetFullName() .. ": no lights / particles"
			)
		end
		local outfit = f:GetAttribute("Outfit")
		if outfit == "sunhat" then
			eq({ f.SunHat.Color, f.SunHat.Material, f.SunHat.Reflectance, f.SunHat.Size }, {
				O.sunhat.hat,
				ctx.engine.Enum.Material.Fabric,
				0,
				roblox.Vector3.new(1.2, 0.7, 1.2),
			})
			eq(f.SunHatBrim.Size, roblox.Vector3.new(0.15, 2.2, 2.2))
		elseif outfit == "rainboots" then
			eq({ f.LeftFoot.Color, f.RightFoot.Color }, { O.rainboots.boots, O.rainboots.boots })
		end
	end
end)

test("block_party_rain: rain lighting and VFX, only Wet crops (with beads)", function()
	local ctx, _, capture = dev()
	eq(capture("block_party_rain"), true)
	local muts, rain = look(ctx)
	eq(muts, { wet = 18 })
	eq(rain, true)
	eq(ctx.engine.workspace.Capture:GetAttribute("Lighting"), "rain")
	local lighting = ctx.engine.game.Lighting
	eq({ lighting.ClockTime, lighting.FogEnd }, { 15, 400 })
	local flower = stage(ctx).Sunflower
	eq({ flower:GetAttribute("Stage"), flower:GetAttribute("Pose") }, { "bloom", "bloom" })
	local column = flower.HeadPivot.FxBloom.Column
	eq(column.Color.Keypoints[1].Value, roblox.Color3.fromHex("#3FA7F5"), "the Rain column")
	eq(flower.HeadPivot.BloomLight.Color, roblox.Color3.fromHex("#3FA7F5"))
	for _, c in crops(ctx) do
		Assert.truthy(c:FindFirstChild("MutBead1"), c.Name .. " beads")
	end
end)

test("block_party_golden: exactly 1 Golden crop, in the foreground third; every other crop plain; no rain", function()
	local ctx, _, capture = dev()
	eq(capture("block_party_golden"), true)
	local muts, rain = look(ctx)
	eq(muts, { golden = 1, none = 17 })
	eq(rain, false)
	eq(ctx.engine.workspace.Capture:GetAttribute("Lighting"), "golden")
	eq(ctx.engine.game.Lighting.ClockTime, 17.6)
	local flower = stage(ctx).Sunflower
	eq(flower:GetAttribute("Pose"), "bloom")
	eq(
		flower.HeadPivot.FxBloom.Column.Color.Keypoints[1].Value,
		roblox.Color3.fromHex("#FFC300"),
		"the Golden Hour column"
	)
	eq(flower.HeadPivot.Petal1.Color, roblox.Color3.fromHex("#FFD23F"), "the flower stays Butter Sun")
	local eye = camOf(ctx, "block_party_golden").CFrame.Position
	local list = crops(ctx)
	table.sort(list, function(a, b)
		return (ctx.CropModel.main(a).Position - eye).Magnitude < (ctx.CropModel.main(b).Position - eye).Magnitude
	end)
	local rank
	for i, c in list do
		if c:GetAttribute("Muts") == "golden" then
			rank = i
			eq(c:GetAttribute("Seed"), "pumpkin")
		end
	end
	Assert.truthy(rank <= #list / 3, `the Golden crop is number {rank} of {#list} from the camera`)
	local _, _, depth = onScreen(camOf(ctx, "block_party_golden"), ctx.CropModel.main(list[rank]).Position)
	Assert.truthy(depth > 0, "in front of the camera")
end)

test(
	"both Block Party scenes: the same low camera, the sunflower centre-right, 7 farmers in an arc facing it",
	function()
		local ctx, _, capture = dev()
		local placed = {}
		for _, scene in { "block_party_rain", "block_party_golden" } do
			capture(scene)
			local cam = camOf(ctx, scene)
			local flower = stage(ctx).Sunflower
			local x, y = onScreen(cam, flower.HeadPivot.Disc.Position)
			Assert.truthy(x > 0.05 and x < 0.6, `{scene}: the bloom centre-right ({x})`)
			Assert.truthy(y > -0.6 and y < 0.9, `{scene}: the bloom in frame ({y})`)
			Assert.truthy(cam.CFrame.Position.Y < flower.Stem.Position.Y, scene .. ": a low camera")
			Assert.truthy(cam.CFrame.LookVector.Y > 0, scene .. ": looking up a little")
			local list = farmers(ctx)
			eq(#list, 7, scene)
			local centre = flower.Stem.Position
			for _, f in list do
				local root = f.HumanoidRootPart
				local toFlower = flat(centre - root.Position).Unit
				Assert.truthy(flat(root.CFrame.LookVector).Unit:Dot(toFlower) > 0.99, f.Name .. " faces the sunflower")
				Assert.near(flat(centre - root.Position).Magnitude, ctx.Capture.BLOCK_PARTY.arc.radius, 0.01)
				Assert.truthy(root.Position.Z < centre.Z, f.Name .. " behind it: the face to the camera")
				local fx = onScreen(cam, f.Head.Position)
				Assert.truthy(math.abs(fx) < 1, f.Name .. " in frame")
				placed[scene] = placed[scene] or {}
				table.insert(placed[scene], root.Position)
			end
		end
		eq(camOf(ctx, "block_party_rain").CFrame, camOf(ctx, "block_party_golden").CFrame, "the exact same camera")
		eq(placed.block_party_rain, placed.block_party_golden, "the same arc")
	end
)

test("one after the other leaves nothing of the first", function()
	local ctx, _, capture = dev()
	capture("block_party_rain")
	capture("block_party_golden")
	local muts, rain = look(ctx)
	eq({ muts.wet, rain, muts.golden }, { nil, false, 1 })
	eq(ctx.engine.game.Lighting.FogEnd, 100000, "the rain fog is gone")
	eq(#farmers(ctx), 7, "no farmers left over")
	capture("block_party_rain")
	muts, rain = look(ctx)
	eq({ muts.golden, rain, muts.wet }, { nil, true, 18 })
	eq(ctx.engine.game.Lighting.ClockTime, 15)
end)

test(
	"offline_before: a freshly planted plot at night, a farmer walking away; offline_after: grown; no mutations",
	function()
		local ctx, _, capture = dev()
		capture("offline_before")
		eq(ctx.engine.workspace.Capture:GetAttribute("Lighting"), "night")
		local muts = look(ctx)
		eq(muts, { none = 9 })
		for _, c in crops(ctx) do
			eq(c:GetAttribute("Stage"), "seed", c.Name .. " just planted")
		end
		local list = farmers(ctx)
		eq(#list, 1)
		local walker = list[1]
		eq(walker:GetAttribute("Pose"), "walk")
		local root = walker.HumanoidRootPart
		local plot = stage(ctx).PlotSoil.Position
		Assert.truthy(flat(root.CFrame.LookVector).Unit:Dot(flat(root.Position - plot).Unit) > 0.5, "walking away")
		capture("offline_after")
		eq(ctx.engine.workspace.Capture:GetAttribute("Lighting"), "day")
		eq(look(ctx), { none = 9 })
		for _, c in crops(ctx) do
			eq(c:GetAttribute("Stage"), "ripe")
		end
		eq(#farmers(ctx), 0)
	end
)

test("golden_reveal: a plain, normal-size hero pumpkin at ~35% of the frame; capture reveal turns it Golden", function()
	local ctx, _, capture = dev()
	capture("golden_reveal")
	local hero = stage(ctx).HeroCrop
	eq({ hero:GetAttribute("Seed"), hero:GetAttribute("Stage"), hero:GetAttribute("Muts") }, { "pumpkin", "ripe", nil })
	local others = 0
	for _, c in crops(ctx) do
		if c ~= hero then
			others += 1
			eq({ c:GetAttribute("Seed"), c:GetAttribute("Muts") }, { "pumpkin", nil }, c.Name .. " plain")
			eq(ctx.CropModel.main(c).Color, ctx.Visuals.SEED.pumpkin, c.Name .. " orange")
		end
	end
	eq(others, 8)
	-- the same size as a live tile's ripe pumpkin
	local live = ctx.CropModel.forTile(nil, "Live", "pumpkin", 1, true, nil, roblox.CFrame.new())
	eq(ctx.CropModel.main(hero).Size, ctx.CropModel.main(live).Size)
	local bottom, top = math.huge, -math.huge
	for _, p in ctx.CropModel.fruit(hero) do
		bottom = math.min(bottom, p.Position.Y - p.Size.Y / 2)
		top = math.max(top, p.Position.Y + p.Size.Y / 2)
	end
	local cam = camOf(ctx, "golden_reveal")
	local _, yTop =
		onScreen(cam, roblox.Vector3.new(ctx.CropModel.main(hero).Position.X, top, ctx.CropModel.main(hero).Position.Z))
	local _, yBottom = onScreen(
		cam,
		roblox.Vector3.new(ctx.CropModel.main(hero).Position.X, bottom, ctx.CropModel.main(hero).Position.Z)
	)
	local fraction = (yTop - yBottom) / 2
	Assert.truthy(math.abs(fraction - 0.35) < 0.05, `the pumpkin fills {fraction} of the frame height`)
	local f = farmers(ctx)[1]
	eq(f:GetAttribute("Pose"), "idle")
	eq(math.abs(onScreen(cam, f.Head.Position)) < 1, true, "the farmer in frame")

	eq(capture("reveal"), true)
	eq(hero:GetAttribute("Muts"), "golden")
	eq(ctx.CropModel.main(hero).Color, ctx.Visuals.GOLD)
	Assert.truthy(hero.Fx.MutLight and hero.GoldLight, "the MutLight and the painted GoldLight")
	eq(f:GetAttribute("Pose"), "surprised")
	eq(ctx.engine.workspace.Capture:GetAttribute("Reveal"), 1)
end)

test("the GA-02 looks: Golden #FFC300 Metal, GoldLight #FFF1A8, rare glints, 1 MutLight; Wet beads and drip", function()
	local ctx, _, capture = dev()
	for _, scene in SCENES do
		capture(scene)
		for _, c in crops(ctx) do
			local lights = 0
			for _, d in c:GetDescendants() do
				if d.ClassName == "PointLight" then
					lights += 1
				end
			end
			local key = c:GetAttribute("Muts")
			local golden = key == "golden" or key == "wetgolden"
			eq(lights, if golden then 1 else 0, `{scene}: {c.Name} lights`)
			if key == "golden" then
				local main = ctx.CropModel.main(c)
				eq(
					{ main.Color, main.Material, main.Reflectance },
					{ roblox.Color3.fromHex("#FFC300"), ctx.engine.Enum.Material.Metal, 0.15 }
				)
				local glint = c.Fx.MutFx
				eq(
					{ glint.Texture, glint:GetAttribute("Mode"), ctx.Visuals.rateOf(glint) },
					{ ctx.Visuals.SPARKLE, "glint", 0.35 }
				)
				eq(c.GoldLight.Color, roblox.Color3.fromHex("#FFF1A8"))
				eq({ c.Fx.MutLight.Color, c.Fx.MutLight.Brightness }, { roblox.Color3.fromHex("#FFD27A"), 0.6 })
			elseif key == "wet" then
				eq(
					ctx.Visuals.rateOf(c.Fx.MutDripAt.MutFx),
					if c:GetAttribute("Seed") == "pumpkin" or c:GetAttribute("Seed") == "watermelon" then 4 else 3
				)
			end
			eq(c:FindFirstChild("MutBead1") ~= nil, key == "wet" or key == "wetgolden", `{scene}: {c.Name} beads`)
		end
	end
end)

test("the stage builds crops with the live code: a staged crop equals Models/Crop's live tile crop", function()
	local ctx, _, capture = dev()
	capture("block_party_golden")
	local function shape(model)
		local out = {}
		for _, d in model:GetDescendants() do
			if d.ClassName == "Part" then
				table.insert(out, { d.Name, d.Size, d.Color, d.Material })
			end
		end
		table.sort(out, function(a, b)
			return a[1] < b[1]
		end)
		return out
	end
	for _, c in crops(ctx) do
		local ref = ctx.CropModel.forTile(
			nil,
			"Ref",
			c:GetAttribute("Seed"),
			1,
			true,
			c:GetAttribute("Muts"),
			c:GetAttribute("Origin")
		)
		eq(shape(c), shape(ref), c.Name)
		eq(ctx.CropModel.main(c).CFrame, ctx.CropModel.main(ref).CFrame, c.Name .. " in the same place")
	end
	-- no cube look left: every crop is a model of several parts
	for _, c in crops(ctx) do
		Assert.truthy(#shape(c) >= 3, c.Name .. " is a real model")
	end
end)

test(
	"pedestals: x2, x20, x40 (a letter x) rising left to right, x40 tallest and nearest; badge colours; a farmer",
	function()
		local ctx, _, capture = dev()
		capture("pedestals")
		local cam = camOf(ctx, "pedestals")
		local rows = {}
		for i = 1, 3 do
			local item = stage(ctx):FindFirstChild("PedestalCrop" .. i)
			local main = ctx.CropModel.main(item)
			local board = main.Badge
			local pedestal = stage(ctx)["Pedestal" .. i]
			local x, _, depth = onScreen(cam, main.Position)
			table.insert(rows, {
				key = item:GetAttribute("Muts"),
				text = board.Text.Text,
				mult = item:GetAttribute("Mult"),
				style = board:GetAttribute("Style"),
				height = pedestal.Size.Y,
				x = x,
				depth = depth,
			})
			eq(item:GetAttribute("Stage"), "item")
			Assert.truthy(not board.Text.Text:find("×"), "a letter x")
		end
		eq({
			{ rows[1].key, rows[1].text, rows[1].mult },
			{ rows[2].key, rows[2].text, rows[2].mult },
			{ rows[3].key, rows[3].text, rows[3].mult },
		}, { { "wet", "x2", 2 }, { "golden", "x20", 20 }, { "wetgolden", "x40", 40 } })
		Assert.truthy(rows[1].x < rows[2].x and rows[2].x < rows[3].x, "left to right")
		Assert.truthy(rows[1].height < rows[2].height and rows[2].height < rows[3].height, "rising")
		Assert.truthy(rows[3].depth < rows[2].depth and rows[2].depth < rows[1].depth, "x40 nearest the camera")
		-- GA-02 section 4 / M8: the game's chip colours, no purple
		local B = ctx.Capture.BADGES
		local hex = roblox.Color3.fromHex
		eq({ B.wet.bg, B.wet.stroke }, { hex("#50AAFF"), hex("#1E1B2E") }, "Wet: blue")
		eq({ B.golden.bg, B.golden.stroke }, { hex("#FFC300"), hex("#1E1B2E") }, "Golden: gold")
		eq({ B.wetgolden.bg, B.wetgolden.stroke }, { hex("#FFC300"), hex("#50AAFF") }, "Wet+Golden: gold, blue stroke")
		for _, style in B do
			eq({ style.text, style.textStroke }, { hex("#FFFFFF"), hex("#1E1B2E") })
		end
		local x40 = ctx.CropModel.main(stage(ctx).PedestalCrop3).Badge.Text
		eq({ x40.BackgroundColor3, x40.UIStroke.Color, x40.UIStroke.Thickness }, { hex("#FFC300"), hex("#50AAFF"), 2 })
		local list = farmers(ctx)
		eq(#list, 1)
		local fx = onScreen(cam, list[1].Head.Position)
		Assert.truthy(fx < rows[1].x and math.abs(fx) < 1, "at the side, in frame")
	end
)

test("icon: a normal-size Golden pumpkin framed close, the farmer waving, a deep-blue clear sky", function()
	local ctx, _, capture = dev()
	capture("icon")
	local hero = stage(ctx).HeroCrop
	eq(
		{ hero:GetAttribute("Seed"), hero:GetAttribute("Muts"), hero:GetAttribute("Stage") },
		{ "pumpkin", "golden", "ripe" }
	)
	local live = ctx.CropModel.forTile(nil, "Live", "pumpkin", 1, true, "golden", roblox.CFrame.new())
	eq(ctx.CropModel.main(hero).Size, ctx.CropModel.main(live).Size, "normal size")
	local cam = camOf(ctx, "icon")
	local main = ctx.CropModel.main(hero)
	local _, yTop = onScreen(cam, main.Position + roblox.Vector3.new(0, main.Size.Y / 2, 0))
	local _, yBottom = onScreen(cam, main.Position - roblox.Vector3.new(0, main.Size.Y / 2, 0))
	Assert.truthy((yTop - yBottom) / 2 > 0.4, "framed close")
	eq(farmers(ctx)[1]:GetAttribute("Pose"), "wave")
	eq(ctx.engine.workspace.Capture:GetAttribute("Lighting"), "clear")
	local lighting = ctx.engine.game.Lighting
	eq(lighting.ColorShift_Top, roblox.Color3.new(0, 0, 0), "no golden light")
	local atmo = lighting:FindFirstChildOfClass("Atmosphere")
	Assert.truthy(atmo and atmo.Decay.B > atmo.Decay.R, "a deep-blue sky")
	capture("street")
	eq(lighting:FindFirstChildOfClass("Atmosphere"), nil, "the atmosphere goes with the scene")
end)

test(
	"Patch: a cream #EADBB8 shirt, green #5BC236 apron, #FF8C1A head, no gold; nothing gold outside the crops",
	function()
		local ctx, _, capture = dev()
		local P = ctx.PatchModel
		eq(P.ORANGE, roblox.Color3.fromHex("#FF8C1A"))
		eq(ctx.Capture.PATCH_ORANGE, P.ORANGE)
		for _, scene in SCENES do
			capture(scene)
			for _, d in stage(ctx):GetDescendants() do
				if d:GetAttribute("Patch") then
					eq(d.Color, P.ORANGE, scene .. ": Patch's head")
					eq(d:FindFirstChild("MutFx"), nil)
				end
				if d.Name == "MutFx" and d:GetAttribute("Key") ~= "wet" then
					Assert.truthy(cropOf(d), scene .. ": gold VFX only on crops")
				end
				if d.ClassName == "Part" and not cropOf(d) and not inside(d, "Sunflower") and d.Transparency ~= 1 then
					Assert.truthy(not goldish(d.Color), `{scene}: {d:GetFullName()} is gold`)
				end
			end
		end
		capture("street")
		local patch = stage(ctx).Patch
		eq({ patch.Body.Color, patch.Apron.Color }, { P.SHIRT, P.APRON })
		Assert.truthy(P.APRON.G > P.APRON.R and P.APRON.G > P.APRON.B, "a green apron")
		eq(
			{ P.SHIRT, P.APRON },
			{ roblox.Color3.fromHex("#EADBB8"), roblox.Color3.fromHex("#5BC236") },
			"05-patch section 0"
		)
		Assert.truthy(
			goldish(roblox.Color3.fromHex("#FFC300")) and goldish(roblox.Color3.fromHex("#E0A100")),
			"the check sees gold"
		)
		for _, d in patch:GetDescendants() do
			if d.ClassName == "Part" then
				Assert.truthy(not goldish(d.Color) or d:GetAttribute("Patch"), "Patch: " .. d.Name .. " is gold")
			end
		end
	end
)

test("the live street uses the same Patch and sunflower models", function()
	local ctx = Farm.setup()
	local P = ctx.engine:require(ctx.engine:module("Shared/Models/Patch"))
	local street = ctx.engine.workspace.Street
	eq(street.Patch.PumpkinHead.Color, P.ORANGE)
	eq(street.Patch.Body.Color, P.SHIRT)
	eq(street.Patch.Apron.Color, P.APRON)
	eq(street.Sunflower:FindFirstChild("Bloom"), nil, "no look models (GA-03)")
	Assert.truthy(street.Sunflower:GetAttribute("Origin"), "the art's origin for SunflowerController")
	Assert.truthy(street.Sunflower.Stem:FindFirstChild("Water"), "the Water prompt")
end)

test(
	"the client: the camera locks to the scene, hud off/on, guides with the size warning, capture size, the reveal",
	function()
		local c = Client.boot()
		c.engine.studio = true
		local Capture = c.engine:require(c.engine:module("Server/Services/CaptureService"))
		local CaptureController = c.controllers.CaptureController
		c.gui("WelcomeBack").Enabled = false -- was hidden before: must stay hidden after
		c.engine:run(function()
			Capture.run({ "icon" })
		end)
		c.engine:advance(1.2)
		local camera = c.engine.workspace.CurrentCamera
		eq(camera.CameraType, c.engine.Enum.CameraType.Scriptable)
		eq(camera.CFrame, c.engine.workspace.Capture.Cams.icon.CFrame)
		c.engine:run(function()
			Capture.run({ "hud", "off" })
		end)
		for _, g in c.engine.game.Players.LocalPlayer.PlayerGui:GetChildren() do
			if g.ClassName == "ScreenGui" and g.Name ~= "CaptureGuides" then
				eq(g.Enabled, false, g.Name)
			end
		end
		eq(c.engine.coreGui.PlayerList, false)
		c.engine:run(function()
			Capture.run({ "hud", "on" })
		end)
		eq(c.gui("Hud").Enabled, true)
		eq(c.gui("WelcomeBack").Enabled, false)
		eq(c.engine.coreGui.PlayerList, true)
		eq(CaptureController.hidden(), nil)
		c.engine:run(function()
			Capture.run({ "guides", "on" })
		end)
		local guides = c.gui("CaptureGuides")
		eq(guides.Enabled, true)
		Assert.near(guides.Frame.SafeLine.Position.Y.Scale, 0.85, 1e-6)
		eq(guides.Frame.UIAspectRatioConstraint.AspectRatio, 1, "the icon is square")
		eq(guides.SizeWarning.Visible, true, "1920x1080 is the wrong size for the icon")
		eq(guides.SizeWarning.Text, "Viewport 1920x1080: this scene needs exactly 1024x1024")
		c.engine:run(function()
			Capture.run({ "size" })
		end)
		Assert.truthy(table.find(c.engine.output, "capture size: 1920x1080 (WRONG: icon wants 1024x1024)"), "printed")
		c.engine:run(function()
			Capture.run({ "street" })
		end)
		Assert.near(guides.Frame.UIAspectRatioConstraint.AspectRatio, 16 / 9, 1e-6)
		eq(guides.SizeWarning.Visible, false, "the street fits 1920x1080")
		c.engine:run(function()
			Capture.run({ "size" })
		end)
		Assert.truthy(table.find(c.engine.output, "capture size: 1920x1080 (fits street)"), "printed")
		camera.ViewportSize = roblox.Vector2.new(1600, 900)
		eq(guides.SizeWarning.Visible, true, "the warning follows the viewport")
		camera.ViewportSize = roblox.Vector2.new(1920, 1080)
		eq(guides.SizeWarning.Visible, false)
		c.engine:run(function()
			Capture.run({ "golden_reveal" })
		end)
		local hero = c.engine.workspace.Capture.Stage.HeroCrop
		c.engine:run(function()
			Capture.run({ "reveal" })
		end)
		local CropModel = c.engine:require(c.engine:module("Shared/Models/Crop"))
		local main = CropModel.main(hero)
		eq({ hero:GetAttribute("Revealed"), hero:GetAttribute("RevealKey") }, { 1, "golden" }, "the 04-reveal sequence")
		Assert.truthy(hero:FindFirstChild("RevealHighlight"), "the Highlight")
		c.engine:advance(0.1)
		eq(CropModel.fxHost(hero).RevealStars:GetAttribute("Emitted"), 12, "the star burst")
		c.engine:advance(3)
		eq(main.Color, c.engine:require(c.engine:module("Shared/Visuals")).GOLD, "ends gold")
		eq(hero:FindFirstChild("RevealHighlight"), nil, "cleaned up")
		eq(CropModel.fxHost(hero):FindFirstChild("RevealStars"), nil)
		c.engine:run(function()
			Capture.run({ "free" })
		end)
		eq(camera.CameraType, c.engine.Enum.CameraType.Custom)
		eq(c.engine.errors, {})
	end
)
