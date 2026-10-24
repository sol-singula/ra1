--[[
Staged scenes for ad thumbnails and the game icon (the Game Artist brief). Dev only and Studio only: everything runs
through the gated DevCommand "capture" (NetService drops every call outside Studio as dev_gate before this runs),
and run itself also refuses outside Studio (studio_only).

  capture <scene>          street, offline_before, offline_after, golden_reveal, block_party_rain,
                           block_party_golden, pedestals, icon
  capture reveal           golden_reveal only: the hero pumpkin turns Golden with the in-game reveal VFX
                           (Visuals.goldenReveal, played by the client) and the farmer looks surprised
  capture size             the client prints workspace.CurrentCamera.ViewportSize (and whether it fits the scene)
  capture hud off|on       the client hides / restores every HUD, Patch's toasts and the player list
  capture guides on|off    the client overlays the frame, the safe line (Config.Capture.safeBottom) and a warning
                           when the viewport isn't the scene's exact size (1920x1080, the icon 1024x1024)
  capture free             back to a free camera
  anything else            Result { ok = false, code = "unknown_scene" } (reveal outside golden_reveal: no_reveal)

Everything staged is the live game's own models: crops through Models/Crop (the same calls TileController and
PedestalController make, so the Golden and Wet looks match), the sunflower (Models/Sunflower), Patch (Models/Patch)
and real R15 farmers (Models/Farmer: HumanoidDescriptions, the default face and hands, real poses).

Scenes only stage models, lighting and cameras, in Workspace.Capture (far from the street). They never read or
write a profile, the plots, the weather or the saves. Loading a scene first tears down the last one (its models,
its weather VFX, its lighting and atmosphere), so Rain and Golden Hour never share a frame, just as a bloom picks one.

  block_party_rain / _golden   the same camera (low, the sunflower centre-right), 7 farmers in an arc facing the
                               sunflower; Golden: exactly 1 Golden crop, in the foreground third, the rest plain
  offline_before / _after      a freshly planted plot at night with a farmer walking away; the grown plot by day.
                               No mutation in either
  golden_reveal                a plain ripe hero pumpkin among plain pumpkins, framed to ~35% of the height
  pedestals                    Wet x2, Golden x20, Wet + Golden x40 on a rising left-to-right diagonal, x40 tallest
                               and nearest; badges in the mutation chip colours (blue; gold; gold + blue); a farmer
  icon                         a Golden pumpkin framed close, a farmer waving, a deep-blue clear sky

Workspace.Capture
  Cams/<scene>   an anchored, invisible part: its CFrame is the camera; attributes Width, Height, FieldOfView
  Stage          the staged models of the current scene
  attributes     Scene, Lighting ("day" | "night" | "rain" | "golden" | "clear"), Hud, Guides, Free, Reveal and
                 SizeAsk (counters the client acts on)

  CaptureService.SCENES / run(args) / scene() / camFor(scene)
  CaptureService.ARC (7) / PATCH_ORANGE
]]
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CropModel = require(ReplicatedStorage.Shared.Models.Crop)
local Farmer = require(ReplicatedStorage.Shared.Models.Farmer)
local Kit = require(ReplicatedStorage.Shared.Models.Kit)
local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local PatchModel = require(ReplicatedStorage.Shared.Models.Patch)
local SunflowerModel = require(ReplicatedStorage.Shared.Models.Sunflower)

local DevCommands = require(script.Parent.Parent.Net.DevCommands)
local DevConfig = require(script.Parent.Parent.DevConfig)

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
CaptureService.ARC = 7
CaptureService.PATCH_ORANGE = PatchModel.ORANGE

local ORIGIN = Vector3.new(0, 0, 600) -- the stage, well away from the street
local SOIL_TOP = 0.5

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
	-- the icon: a deep-blue clear midday sky, no golden light
	clear = {
		ClockTime = 14,
		Brightness = 3,
		Ambient = Color3.fromRGB(105, 120, 150),
		OutdoorAmbient = Color3.fromRGB(125, 145, 185),
		ColorShift_Top = Color3.new(0, 0, 0),
		FogEnd = 100000,
		FogColor = Color3.fromRGB(110, 165, 255),
	},
}
-- the Atmosphere a preset sets (the clear sky's deep blue); the others leave the place's own alone
local ATMOSPHERES = {
	clear = {
		Density = 0.24,
		Offset = 0,
		Color = Color3.fromRGB(150, 195, 255),
		Decay = Color3.fromRGB(40, 90, 200),
		Glare = 0,
		Haze = 0,
	},
}

-- the badge on each pedestal: x2 / x20 / x40 (a letter x) in the game's mutation chip colours (GA-02 section 4 and
-- M8): Wet blue, Golden gold, Wet+Golden gold with a blue stroke; white text with a dark outline
local CHIPS = Config.MutationVisuals.chips
local BADGES = {}
for key in Config.MutationVisuals.labels do
	BADGES[key] = {
		bg = Color3.fromHex(CHIPS[key].fill),
		stroke = Color3.fromHex(CHIPS[key].stroke),
		text = Color3.fromHex(CHIPS.text),
		textStroke = Color3.fromHex(CHIPS.textStroke),
	}
end
CaptureService.BADGES = BADGES

local folder, cams, stage
local current
local baseline -- the lighting before the first scene
local atmosphere -- { made = Atmosphere } or { kept = Atmosphere, was = props }

local function part(parent, name, size, pos, color, material)
	return Kit.part(parent, name, size, CFrame.new(ORIGIN + pos), color, material)
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

-- a crop standing on the soil at pos (the same build TileController makes for a live tile); its number is its
-- tile id for the per-tile turn
local function crop(name, seed, pos, progress, muts)
	local at = CropModel.at(ORIGIN + pos + Vector3.new(0, SOIL_TOP, 0), string.match(name, "%d+$"))
	return CropModel.forTile(stage, name, seed, progress, progress >= 1, muts, at)
end

-- a 3 x 3 bed; mutFor(i) gives crop i its mutation key
local function bed(prefix, center, seeds, progress, mutFor)
	part(stage, prefix .. "Soil", Vector3.new(14, 1, 14), center, Color3.fromRGB(120, 84, 52), Enum.Material.Ground)
	local i = 0
	for r = -1, 1 do
		for c = -1, 1 do
			i += 1
			local seed = seeds[(i - 1) % #seeds + 1]
			crop(`{prefix}Crop{i}`, seed, center + Vector3.new(c * 4, 0, r * 4), progress, mutFor and mutFor(i))
		end
	end
end

-- a real R15 farmer standing at pos, facing the point face
local function farmer(name, outfitKey, skin, pos, face, pose)
	local at = ORIGIN + pos
	local look = ORIGIN + Vector3.new(face.X, pos.Y, face.Z)
	return Farmer.build(stage, name, outfitKey, skin, CFrame.lookAt(at, look), pose)
end

local function patch(pos)
	local model = Kit.model(stage, "Patch")
	PatchModel.build(model, CFrame.new(ORIGIN + pos))
	return model
end

local function sunflower(pos, face)
	local at = ORIGIN + pos
	local model = SunflowerModel.build(stage, CFrame.lookAt(at, ORIGIN + Vector3.new(face.X, pos.Y, face.Z)))
	SunflowerModel.setLook(model, "Bloom")
	model:SetAttribute("Stage", "bloom")
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

local function badge(target, key, text)
	local style = BADGES[key]
	local board = Instance.new("BillboardGui")
	board.Name = "Badge"
	board.Size = UDim2.fromOffset(130, 64)
	board.StudsOffset = Vector3.new(0, 2.6, 0)
	board.AlwaysOnTop = true
	board:SetAttribute("Style", key)
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundColor3 = style.bg
	label.BackgroundTransparency = 0
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = style.text
	label.TextStrokeColor3 = style.textStroke
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = style.stroke
	stroke.Thickness = CHIPS.strokeThickness
	stroke.Parent = label
	board.Parent = target
	return board
end

---------------------------------------------------------------------------------------------------------------
-- lighting

local function setAtmosphere(cfg)
	local a = Lighting:FindFirstChildOfClass("Atmosphere")
	if not a then
		a = Instance.new("Atmosphere")
		a.Name = "CaptureAtmosphere"
		a.Parent = Lighting
		atmosphere = { made = a }
	else
		local was = {}
		for k in cfg do
			was[k] = a[k]
		end
		atmosphere = { kept = a, was = was }
	end
	for k, value in cfg do
		a[k] = value
	end
end

local function restoreAtmosphere()
	if atmosphere and atmosphere.made then
		atmosphere.made:Destroy()
	elseif atmosphere and atmosphere.kept then
		for k, value in atmosphere.was do
			atmosphere.kept[k] = value
		end
	end
	atmosphere = nil
end

local function lighting(kind)
	for k, value in LIGHTS[kind] do
		Lighting[k] = value
	end
	if ATMOSPHERES[kind] then
		setAtmosphere(ATMOSPHERES[kind])
	end
	folder:SetAttribute("Lighting", kind)
end

---------------------------------------------------------------------------------------------------------------
-- scenes

local BUILD = {}

-- the Block Party set: the sunflower centre-right, 7 farmers in an arc behind it facing it (their faces to the
-- camera), two beds on the left; both weathers use this exact camera
local BP_SUNFLOWER = Vector3.new(6, 0, -6)
local BP_EYE, BP_TARGET = Vector3.new(-4, 3, 28), Vector3.new(0, 7.5, -6)
local ARC = {
	radius = 9,
	from = 200,
	step = 25,
	poses = { "cheer", "wave", "cheer", "watering", "cheer", "wave", "idle" },
	outfits = { "overalls", "sunhat", "apron", "rainboots", "flannel", "gloves", "rainboots" },
}
CaptureService.BLOCK_PARTY = { sunflower = BP_SUNFLOWER, eye = BP_EYE, target = BP_TARGET, arc = ARC }

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
	bed("PlotA", Vector3.new(-30, 0, 0), { "carrot", "tomato", "corn" }, 1)
	bed("PlotB", Vector3.new(0, 0, 0), { "strawberry", "blueberry" }, 0.6)
	bed("PlotC", Vector3.new(30, 0, 0), { "pumpkin", "watermelon" }, 1)
	sunflower(Vector3.new(0, 0, -36), Vector3.new(0, 0, -70))
	local poses = { "idle", "wave", "watering", "cheer", "walk", "wave" }
	for i, key in Farmer.OUTFIT_ORDER do
		local x = -40 + (i - 1) * 16
		farmer("Farmer" .. i, key, i, Vector3.new(x, 0, -12), Vector3.new(x, 0, -70), poses[i])
	end
	patch(Vector3.new(48, 0, -12))
end

local OFFLINE_SEEDS = { "corn", "tomato", "watermelon" }

local function offline(progress)
	ground(60)
	bed("Plot", Vector3.new(0, 0, 0), OFFLINE_SEEDS, progress)
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
	offline(0.05)
	-- done planting, heading home: walking away from the plot, towards the house
	farmer("Farmer1", "overalls", 3, Vector3.new(-7, 0, 6), Vector3.new(-14, 0, 12), "walk")
end

function BUILD.offline_after()
	lighting("day")
	offline(1)
end

-- the hero pumpkin's centre and the reveal camera (the pumpkin ~35% of the frame height)
local HERO = Vector3.new(0, 0, 0)
local REVEAL_EYE, REVEAL_TARGET = Vector3.new(-1.04, 2.85, -2.97), Vector3.new(-0.36, 1.81, 0)
CaptureService.REVEAL_FRACTION = 0.35

function BUILD.golden_reveal()
	lighting("day")
	ground(60)
	part(
		stage,
		"PlotSoil",
		Vector3.new(14, 1, 14),
		Vector3.new(0, 0, 0),
		Color3.fromRGB(120, 84, 52),
		Enum.Material.Ground
	)
	local i = 0
	for r = -1, 1 do
		for c = -1, 1 do
			if r ~= 0 or c ~= 0 then
				i += 1
				crop("PlotCrop" .. i, "pumpkin", Vector3.new(c * 4, 0, r * 4), 1, nil)
			end
		end
	end
	crop("HeroCrop", "pumpkin", HERO, 1, nil)
	farmer("Farmer1", "sunhat", 2, Vector3.new(-1.6, 0, 2.2), HERO, "idle") -- in the gap behind the row
end

local function blockParty(kind)
	lighting(kind)
	ground(120)
	sunflower(BP_SUNFLOWER, BP_EYE)
	local golden = kind == "golden"
	-- rain: every crop Wet; Golden Hour: one Golden crop, PlotA's front-right pumpkin (in the foreground third)
	local function mutFor(prefix)
		return function(i)
			if not golden then
				return "wet"
			end
			return if prefix == "PlotA" and i == 9 then "golden" else nil
		end
	end
	bed("PlotA", Vector3.new(-10, 0, 12), { "corn", "tomato", "pumpkin" }, 1, mutFor("PlotA"))
	bed("PlotB", Vector3.new(-14, 0, -2), { "watermelon", "strawberry" }, 1, mutFor("PlotB"))
	for i = 1, CaptureService.ARC do
		local a = math.rad(ARC.from + (i - 1) * ARC.step)
		local pos = BP_SUNFLOWER + Vector3.new(math.cos(a), 0, math.sin(a)) * ARC.radius
		farmer("Farmer" .. i, ARC.outfits[i], i, pos, BP_SUNFLOWER, ARC.poses[i])
	end
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

-- left to right: rising, and coming towards the camera; x40 is the tallest and nearest
local PEDESTALS = {
	{ "wet", { wet = true }, Vector3.new(-6, 0, -4), 2.5 },
	{ "golden", { golden = true }, Vector3.new(0, 0, 0), 4 },
	{ "wetgolden", { wet = true, golden = true }, Vector3.new(6, 0, 4), 5.5 },
}
CaptureService.PEDESTALS = PEDESTALS

function BUILD.pedestals()
	lighting("day")
	ground(40)
	for i, e in PEDESTALS do
		local pedestal = part(
			stage,
			"Pedestal" .. i,
			Vector3.new(3, e[4], 3),
			e[3] + Vector3.new(0, e[4] / 2, 0),
			Color3.fromRGB(220, 220, 225),
			Enum.Material.Marble
		)
		-- the same call PedestalController makes for a live pedestal
		local item = CropModel.onPedestal(stage, "PedestalCrop" .. i, "pumpkin", e[1], pedestal, 0.8)
		item:SetAttribute("Mult", MutationMath.mult(e[2]))
		badge(CropModel.main(item), e[1], "x" .. MutationMath.mult(e[2]))
	end
	farmer("Farmer1", "gloves", 4, Vector3.new(-11, 0, 5), Vector3.new(0, 0, 0), "cheer")
end

function BUILD.icon()
	lighting("clear")
	ground(30)
	part(stage, "Soil", Vector3.new(6, 1, 6), Vector3.new(0, 0, 0), Color3.fromRGB(120, 84, 52), Enum.Material.Ground)
	crop("HeroCrop", "pumpkin", Vector3.new(0, 0, 0), 1, "golden")
	farmer("Farmer1", "overalls", 2, Vector3.new(2.6, 0, -3.5), Vector3.new(-1.3, 0, 6), "wave")
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
	cam("golden_reveal", REVEAL_EYE, REVEAL_TARGET)
	cam("block_party_rain", BP_EYE, BP_TARGET)
	cam("block_party_golden", BP_EYE, BP_TARGET)
	cam("pedestals", Vector3.new(3, 5.5, 17), Vector3.new(0, 4, 0))
	cam("icon", Vector3.new(-0.85, 2.69, 3.39), Vector3.new(0.4, 1.95, 0), true)
	folder:SetAttribute("Hud", true)
	folder:SetAttribute("Guides", false)
	folder:SetAttribute("Free", true)
	folder.Parent = workspace
end

local function teardown()
	for _, child in stage:GetChildren() do
		if child:GetAttribute("Crop") then
			CropModel.destroy(child) -- its glints go back to the pool
		else
			child:Destroy()
		end
	end
	if baseline then
		for k, value in baseline do
			Lighting[k] = value
		end
	end
	restoreAtmosphere()
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
	current = scene
	folder:SetAttribute("Scene", scene)
	folder:SetAttribute("Free", false)
	BUILD[scene]()
end

local function reveal()
	local hero = stage and stage:FindFirstChild("HeroCrop")
	if current ~= "golden_reveal" or not hero then
		return false, "no_reveal"
	end
	CropModel.setMuts(hero, "golden")
	local farmerModel = stage:FindFirstChild("Farmer1")
	if farmerModel then
		Farmer.pose(farmerModel, "surprised")
	end
	folder:SetAttribute("Reveal", (folder:GetAttribute("Reveal") or 0) + 1)
	return true
end

local ONOFF = { on = true, off = false }

function CaptureService.run(args)
	if not DevConfig.isStudio() then
		return false, "studio_only"
	end
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
	elseif which == "reveal" and arg == nil then
		return reveal()
	elseif which == "size" and arg == nil then
		build()
		folder:SetAttribute("SizeAsk", (folder:GetAttribute("SizeAsk") or 0) + 1)
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

return CaptureService
