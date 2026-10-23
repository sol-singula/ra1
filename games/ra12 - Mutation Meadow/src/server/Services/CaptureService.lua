--[[
Staged scenes for ad thumbnails and the game icon (the Game Artist brief). Dev only: everything runs through the
gated DevCommand "capture" (NetService drops non-devs outside Studio as dev_gate before this runs).

  capture <scene>          street, offline_before, offline_after, golden_reveal, block_party_rain,
                           block_party_golden, pedestals, icon
  capture hud off|on       the client hides / restores every HUD, Patch's toasts and the player list
  capture guides on|off    the client overlays the frame and the safe line (Config.Capture.safeBottom)
  capture free             back to a free camera
  anything else            Result { ok = false, code = "unknown_scene" }

Scenes only stage models, lighting and cameras, in Workspace.Capture (far from the street). They never read or
write a profile, the plots, the weather or the saves. Loading a scene first tears down the last one (its models,
its weather VFX, its lighting), so Rain and Golden Hour never share a frame, just as a bloom picks one.

Workspace.Capture
  Cams/<scene>   an anchored, invisible part: its CFrame is the camera; attributes Width, Height, FieldOfView
  Stage          the staged models of the current scene
  attributes     Scene, Lighting ("day" | "night" | "rain" | "golden"), Hud, Guides, Free (the client follows them)

  CaptureService.SCENES / run(args) / scene() / camFor(scene)
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local Visuals = require(ReplicatedStorage.Shared.Visuals)

local DevCommands = require(script.Parent.Parent.Net.DevCommands)

local CaptureService = {}

CaptureService.SCENES = {
	"street",
	"offline_before",
	"offline_after",
	"golden_reveal",
	"block_party_rain",
	"block_party_golden",
	"pedestals",
	"icon",
}

local ORIGIN = Vector3.new(0, 0, 600) -- the stage, well away from the street
local PATCH_ORANGE = Color3.fromRGB(235, 120, 30)

local LIGHTS = {
	day = {
		ClockTime = 13,
		Brightness = 2.4,
		Ambient = Color3.fromRGB(110, 110, 110),
		OutdoorAmbient = Color3.fromRGB(150, 150, 150),
		ColorShift_Top = Color3.new(0, 0, 0),
		FogEnd = 100000,
		FogColor = Color3.fromRGB(192, 192, 192),
	},
	night = {
		ClockTime = 0.5,
		Brightness = 0.6,
		Ambient = Color3.fromRGB(40, 50, 80),
		OutdoorAmbient = Color3.fromRGB(50, 60, 100),
		ColorShift_Top = Color3.new(0, 0, 0),
		FogEnd = 100000,
		FogColor = Color3.fromRGB(30, 35, 60),
	},
	rain = {
		ClockTime = 15,
		Brightness = 1,
		Ambient = Color3.fromRGB(80, 90, 105),
		OutdoorAmbient = Color3.fromRGB(100, 110, 125),
		ColorShift_Top = Color3.new(0, 0, 0),
		FogEnd = 400,
		FogColor = Color3.fromRGB(130, 140, 155),
	},
	golden = {
		ClockTime = 17.6,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(150, 110, 60),
		OutdoorAmbient = Color3.fromRGB(190, 140, 80),
		ColorShift_Top = Color3.fromRGB(255, 190, 110),
		FogEnd = 100000,
		FogColor = Color3.fromRGB(255, 210, 160),
	},
}

local OUTFITS = {
	overalls = { shirt = Color3.fromRGB(240, 240, 235), pants = Color3.fromRGB(60, 90, 160) },
	sunhat = {
		shirt = Color3.fromRGB(250, 200, 120),
		pants = Color3.fromRGB(120, 90, 60),
		hat = Color3.fromRGB(230, 200, 120),
	},
	apron = {
		shirt = Color3.fromRGB(200, 80, 80),
		pants = Color3.fromRGB(70, 60, 50),
		apron = Color3.fromRGB(245, 240, 220),
	},
	rainboots = {
		shirt = Color3.fromRGB(90, 160, 210),
		pants = Color3.fromRGB(60, 60, 70),
		boots = Color3.fromRGB(240, 210, 40),
	},
	flannel = { shirt = Color3.fromRGB(170, 40, 40), pants = Color3.fromRGB(50, 70, 110) },
	gloves = {
		shirt = Color3.fromRGB(110, 170, 90),
		pants = Color3.fromRGB(90, 80, 60),
		gloves = Color3.fromRGB(120, 200, 120),
	},
}
local OUTFIT_ORDER = { "overalls", "sunhat", "apron", "rainboots", "flannel", "gloves" }

local folder, cams, stage
local current
local baseline -- the lighting before the first scene

local function part(parent, name, size, pos, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.Position = ORIGIN + pos
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function cam(name, eye, target, square)
	local c = Instance.new("Part")
	c.Name = name
	c.Anchored = true
	c.CanCollide = false
	c.Transparency = 1
	c.Size = Vector3.new(1, 1, 1)
	c.CFrame = CFrame.lookAt(ORIGIN + eye, ORIGIN + target)
	local size = if square then Config.Capture.icon else Config.Capture.thumb
	c:SetAttribute("Width", size[1])
	c:SetAttribute("Height", size[2])
	c:SetAttribute("FieldOfView", if square then 40 else 55)
	c.Parent = cams
end

function CaptureService.camFor(scene)
	return cams and cams:FindFirstChild(scene)
end

function CaptureService.scene()
	return current
end

---------------------------------------------------------------------------------------------------------------
-- staging pieces

local function ground(size)
	part(
		stage,
		"Ground",
		Vector3.new(size, 1, size),
		Vector3.new(0, -0.5, 0),
		Color3.fromRGB(96, 168, 72),
		Enum.Material.Grass
	)
end

-- a crop: seed colour, growth 0..1, a mutation key for its sparkles
local function crop(name, seed, pos, growth, mutKey)
	local size = 0.6 + 2.2 * growth
	local p = part(
		stage,
		name,
		Vector3.new(size, size, size),
		pos + Vector3.new(0, size / 2 + 0.5, 0),
		if growth >= 1 then Visuals.SEED[seed] else Visuals.LEAF:Lerp(Visuals.SEED[seed], growth),
		if growth >= 1 then Enum.Material.Neon else Enum.Material.SmoothPlastic
	)
	p:SetAttribute("Seed", seed)
	p:SetAttribute("Muts", mutKey)
	p:SetAttribute("Crop", true)
	Visuals.mutationFx(p, mutKey)
	return p
end

local function bed(prefix, center, seeds, growth, mutKey)
	part(
		stage,
		prefix .. "Soil",
		Vector3.new(14, 1, 14),
		center + Vector3.new(0, 0, 0),
		Color3.fromRGB(120, 84, 52),
		Enum.Material.Ground
	)
	local i = 0
	for r = -1, 1 do
		for c = -1, 1 do
			i += 1
			local seed = seeds[(i - 1) % #seeds + 1]
			crop(`{prefix}Crop{i}`, seed, center + Vector3.new(c * 4, 0, r * 4), growth, mutKey)
		end
	end
end

-- a blocky farmer; pose "wave" | "cheer" | nil
local function farmer(name, outfitKey, pos, pose)
	local o = OUTFITS[outfitKey]
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("Outfit", outfitKey)
	model.Parent = stage
	local skin = Color3.fromRGB(240, 200, 160)
	part(model, "Legs", Vector3.new(2, 2, 1), pos + Vector3.new(0, 1, 0), o.pants)
	part(model, "Torso", Vector3.new(2, 2, 1), pos + Vector3.new(0, 3, 0), o.shirt)
	part(model, "Head", Vector3.new(1.2, 1.2, 1.2), pos + Vector3.new(0, 4.6, 0), skin)
	local armY = if pose == "cheer" then 4.6 else 3
	part(model, "LeftArm", Vector3.new(1, 2, 1), pos + Vector3.new(-1.5, armY, 0), o.shirt)
	part(model, "RightArm", Vector3.new(1, 2, 1), pos + Vector3.new(1.5, if pose then 4.6 else 3, 0), o.shirt)
	if o.hat then
		part(model, "SunHat", Vector3.new(3, 0.3, 3), pos + Vector3.new(0, 5.3, 0), o.hat, Enum.Material.Fabric)
	end
	if o.apron then
		part(model, "Apron", Vector3.new(1.8, 2.6, 0.2), pos + Vector3.new(0, 2.4, -0.6), o.apron, Enum.Material.Fabric)
	end
	if o.boots then
		part(model, "Boots", Vector3.new(2.1, 0.8, 1.1), pos + Vector3.new(0, 0.4, 0), o.boots, Enum.Material.Plastic)
	end
	if o.gloves then
		part(
			model,
			"Gloves",
			Vector3.new(1.1, 0.5, 1.1),
			pos + Vector3.new(1.5, armY - 1, 0),
			o.gloves,
			Enum.Material.Fabric
		)
	end
	return model
end

-- Patch the shopkeeper: always his orange pumpkin head, never gold
local function patch(pos)
	local model = Instance.new("Model")
	model.Name = "Patch"
	model.Parent = stage
	part(
		model,
		"Body",
		Vector3.new(2, 4, 1),
		pos + Vector3.new(0, 2, 0),
		Color3.fromRGB(90, 120, 60),
		Enum.Material.Fabric
	)
	local head = part(
		model,
		"PumpkinHead",
		Vector3.new(2.4, 2, 2.4),
		pos + Vector3.new(0, 5, 0),
		PATCH_ORANGE,
		Enum.Material.SmoothPlastic
	)
	head:SetAttribute("Patch", true)
	return model
end

local function sunflower(pos)
	local model = Instance.new("Model")
	model.Name = "Sunflower"
	model:SetAttribute("Stage", "bloom")
	model.Parent = stage
	part(
		model,
		"Stem",
		Vector3.new(2, 14, 2),
		pos + Vector3.new(0, 7, 0),
		Color3.fromRGB(70, 140, 50),
		Enum.Material.Grass
	)
	part(model, "Bloom", Vector3.new(9, 9, 1.5), pos + Vector3.new(0, 18, 0), Color3.fromRGB(255, 205, 0))
	part(model, "Centre", Vector3.new(3.5, 3.5, 1.7), pos + Vector3.new(0, 18, -0.2), Color3.fromRGB(110, 70, 30))
	return model
end

local function rainFx()
	local cloud = part(stage, "RainFx", Vector3.new(80, 1, 80), Vector3.new(0, 40, 0), Color3.new(1, 1, 1))
	cloud.Transparency = 1
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Rate = 400
	rain.Speed = NumberRange.new(45, 55)
	rain.Lifetime = NumberRange.new(0.8, 1)
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
	rain.Parent = cloud
end

local function badge(target, text)
	local board = Instance.new("BillboardGui")
	board.Name = "Badge"
	board.Size = UDim2.fromOffset(120, 60)
	board.StudsOffset = Vector3.new(0, 3, 0)
	board.AlwaysOnTop = true
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
	label.BackgroundTransparency = 0.2
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = board
	board.Parent = target
end

---------------------------------------------------------------------------------------------------------------
-- scenes

local function lighting(kind)
	for k, v in LIGHTS[kind] do
		Lighting[k] = v
	end
	folder:SetAttribute("Lighting", kind)
end

local BUILD = {}

function BUILD.street()
	lighting("day")
	ground(160)
	part(
		stage,
		"Road",
		Vector3.new(160, 1.05, 14),
		Vector3.new(0, -0.45, -20),
		Color3.fromRGB(70, 70, 75),
		Enum.Material.Asphalt
	)
	bed("PlotA", Vector3.new(-30, 0, 0), { "carrot", "tomato", "corn" }, 1, nil)
	bed("PlotB", Vector3.new(0, 0, 0), { "strawberry", "blueberry" }, 0.7, nil)
	bed("PlotC", Vector3.new(30, 0, 0), { "pumpkin", "watermelon" }, 1, nil)
	sunflower(Vector3.new(0, 0, -36))
	for i, key in OUTFIT_ORDER do
		farmer("Farmer" .. i, key, Vector3.new(-40 + (i - 1) * 16, 0, -12), if i % 2 == 0 then "wave" else nil)
	end
	patch(Vector3.new(48, 0, -12))
end

local function offline(growth)
	ground(60)
	bed("Plot", Vector3.new(0, 0, 0), { "corn", "tomato", "watermelon" }, growth, nil)
	part(
		stage,
		"House",
		Vector3.new(10, 8, 8),
		Vector3.new(-14, 4, 10),
		Color3.fromRGB(200, 120, 90),
		Enum.Material.WoodPlanks
	)
end

function BUILD.offline_before()
	lighting("night")
	offline(0.15)
end

function BUILD.offline_after()
	lighting("day")
	offline(1)
end

function BUILD.golden_reveal()
	lighting("day")
	ground(60)
	local hero = crop("HeroCrop", "pumpkin", Vector3.new(0, 0, 0), 1, "golden")
	hero.Size = Vector3.new(5, 5, 5)
	hero.Position = ORIGIN + Vector3.new(0, 3, 0)
	farmer("Farmer1", "sunhat", Vector3.new(6, 0, 3), "cheer")
end

local function blockParty(kind)
	lighting(kind)
	ground(120)
	sunflower(Vector3.new(0, 0, -20))
	local mut = if kind == "rain" then "wet" else "golden"
	bed("PlotA", Vector3.new(-18, 0, 4), { "corn", "tomato" }, 1, mut)
	bed("PlotB", Vector3.new(18, 0, 4), { "pumpkin", "carrot" }, 1, mut)
	farmer("Farmer1", if kind == "rain" then "rainboots" else "flannel", Vector3.new(0, 0, 0), "cheer")
	if kind == "rain" then
		rainFx()
	end
end

function BUILD.block_party_rain()
	blockParty("rain")
end

function BUILD.block_party_golden()
	blockParty("golden")
end

function BUILD.pedestals()
	lighting("day")
	ground(40)
	local entries = {
		{ "wet", { wet = true }, Config.Mutations.wet.mult },
		{ "golden", { golden = true }, Config.Mutations.golden.mult },
		{ "wetgolden", { wet = true, golden = true }, Config.Mutations.stackMult },
	}
	for i, e in entries do
		local x = (i - 2) * 8
		part(
			stage,
			"Pedestal" .. i,
			Vector3.new(3, 3, 3),
			Vector3.new(x, 1.5, 0),
			Color3.fromRGB(220, 220, 225),
			Enum.Material.Marble
		)
		local c = crop("PedestalCrop" .. i, "pumpkin", Vector3.new(x, 2.5, 0), 1, e[1])
		badge(c, "×" .. e[3])
		c:SetAttribute("Mult", MutationMath.mult(e[2]))
	end
end

function BUILD.icon()
	lighting("golden")
	ground(30)
	local hero = crop("HeroCrop", "pumpkin", Vector3.new(0, 0, 0), 1, "golden")
	hero.Size = Vector3.new(6, 6, 6)
	hero.Position = ORIGIN + Vector3.new(0, 3.5, 0)
	farmer("Farmer1", "overalls", Vector3.new(5, 0, 2), "cheer")
end

local function build()
	folder = workspace:FindFirstChild("Capture")
	if folder then
		return
	end
	folder = Instance.new("Folder")
	folder.Name = "Capture"
	cams = Instance.new("Folder")
	cams.Name = "Cams"
	cams.Parent = folder
	stage = Instance.new("Folder")
	stage.Name = "Stage"
	stage.Parent = folder
	cam("street", Vector3.new(0, 30, -70), Vector3.new(0, 4, 0))
	cam("offline_before", Vector3.new(10, 18, -30), Vector3.new(0, 1, 0))
	cam("offline_after", Vector3.new(10, 18, -30), Vector3.new(0, 1, 0))
	cam("golden_reveal", Vector3.new(-4, 7, -14), Vector3.new(1, 3, 0))
	cam("block_party_rain", Vector3.new(0, 22, -55), Vector3.new(0, 8, -6))
	cam("block_party_golden", Vector3.new(0, 22, -55), Vector3.new(0, 8, -6))
	cam("pedestals", Vector3.new(0, 7, -20), Vector3.new(0, 3, 0))
	cam("icon", Vector3.new(-3, 7, -13), Vector3.new(1.5, 3.5, 0), true)
	folder:SetAttribute("Hud", true)
	folder:SetAttribute("Guides", false)
	folder:SetAttribute("Free", true)
	folder.Parent = workspace
end

local function teardown()
	for _, child in stage:GetChildren() do
		child:Destroy()
	end
	if baseline then
		for k, v in baseline do
			Lighting[k] = v
		end
	end
	folder:SetAttribute("Lighting", nil)
end

local function load(scene)
	build()
	if not baseline then
		baseline = {}
		for k in LIGHTS.day do
			baseline[k] = Lighting[k]
		end
	end
	teardown()
	BUILD[scene]()
	current = scene
	folder:SetAttribute("Scene", scene)
	folder:SetAttribute("Free", false)
end

local ONOFF = { on = true, off = false }

function CaptureService.run(args)
	local which, arg = args[1], args[2]
	if which == "hud" and ONOFF[arg] ~= nil then
		build()
		folder:SetAttribute("Hud", ONOFF[arg])
		return true
	elseif which == "guides" and ONOFF[arg] ~= nil then
		build()
		folder:SetAttribute("Guides", ONOFF[arg])
		return true
	elseif which == "free" and arg == nil then
		build()
		folder:SetAttribute("Free", true)
		return true
	elseif type(which) == "string" and BUILD[which] and arg == nil then
		load(which)
		return true
	end
	return false, "unknown_scene"
end

function CaptureService:Init()
	DevCommands.register("capture", function(_, args)
		return CaptureService.run(args)
	end)
end

CaptureService.PATCH_ORANGE = PATCH_ORANGE

return CaptureService
