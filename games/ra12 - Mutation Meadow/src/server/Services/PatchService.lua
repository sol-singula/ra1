--[[
Patch, the pumpkin-headed shopkeeper (§9): his rig at the shop, his prompt, and his lines.

Rig: Workspace.Street.Patch, an anchored Model with an AnimationController + Animator (no Humanoid), an Animations
folder (idle, wave, point, cheer, announce, lean) and a Face attribute (happy, wow, thinking, wink, sleepy). When
the place has none, he is built from the shared Models/Patch (Game Artist build-spec/05-patch.md: a cream shirt, a
leafy green apron and limbs, the #FF8C1A pumpkin head, a Decal-free face); PatchRigController poses him on the
client from Anim / Face (procedural tweens while the AnimationIds are ""). A line's look holds for the line's
seconds, then he goes back to idle / happy. After 60s with nobody within the restock range he dozes (sleepy).

Prompt: Config.Patch.prompt (Shop / Patch's Seed Shop / 10 studs / no hold). Triggered is checked on the server
(within Config.Patch.serverRange) and opens the shop.

Lines come only from Config.Patch.lines. say(player, id, fmt?) fires PatchLine { id, text, display, hideSec, hideOn }:
a flagged line only once per profile (patchTips[id], or weekly.lineSeen = the current updateId for "update"), set
before it fires, in the same profile write; an unflagged line every time.

Triggers here: plant (first spawn with nothing planted), shopHello / shopAgain (ShopService), restock and rare
(ShopService), mutation (the first mutation on your own crop: "Wet" or "Golden"), blockParty (the first window
open while you're on). shower and update come from M8 (WeatherService / WeeklyService call say).

Remotes: Settings:set {key, value}, Settings:patchAck {id, how} (logged as patch_line_dismissed).

  PatchService.say(player, id, fmt?) -> boolean
  PatchService.textFor(id, fmt?)
  PatchService.isNear(player, studs)
  PatchService.rig()
  PatchService.LINE_LOOK          [id] = { anim, face }
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local PatchModel = require(ReplicatedStorage.Shared.Models.Patch)
local Schedule = require(ReplicatedStorage.Shared.Schedule)

local BlockPartyService = require(script.Parent.BlockPartyService)
local DataService = require(script.Parent.DataService)
local Guards = require(script.Parent.Parent.Net.Guards)
local MutationService = require(script.Parent.MutationService)
local NetService = require(script.Parent.NetService)
local ShopService = require(script.Parent.ShopService)
local Telemetry = require(script.Parent.Parent.Telemetry)

local PatchService = {}

PatchService.ANIMS = { "idle", "wave", "point", "cheer", "announce", "lean" }
PatchService.FACES = { "happy", "wow", "thinking", "wink", "sleepy" }
PatchService.LINE_LOOK = {
	plant = { "point", "happy" },
	shopHello = { "wave", "happy" },
	shopAgain = { "lean", "wink" },
	restock = { "cheer", "happy" },
	rare = { "announce", "wow" },
	shower = { "point", "thinking" },
	mutation = { "cheer", "wow" },
	blockParty = { "point", "happy" },
	update = { "announce", "wow" },
}

local SLEEPY_SEC = 60

local rig
local lastNear = 0

-- makes sure the rig has everything (a Studio-placed one may only bring its parts)
local function setUp(model)
	local base = model:FindFirstChild("Counter") or model:FindFirstChild("Body")
	if not base then
		PatchModel.build(model, CFrame.new(36, 0, -26))
		base = model.Counter
	end
	if not model:FindFirstChildOfClass("AnimationController") then
		local controller = Instance.new("AnimationController")
		controller.Name = "AnimationController"
		local animator = Instance.new("Animator")
		animator.Parent = controller
		controller.Parent = model
	end
	if not model:FindFirstChild("Animations") then
		local folder = Instance.new("Folder")
		folder.Name = "Animations"
		for _, name in PatchService.ANIMS do
			local anim = Instance.new("Animation")
			anim.Name = name
			anim.AnimationId = "" -- TODO: the artist's animation ids
			anim.Parent = folder
		end
		folder.Parent = model
	end
	local prompt = model:FindFirstChild("ShopPrompt", true)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ShopPrompt"
		prompt.Parent = base
	end
	local cfg = Config.Patch.prompt
	prompt.ActionText = cfg.actionText
	prompt.ObjectText = cfg.objectText
	prompt.MaxActivationDistance = cfg.maxDistance
	prompt.HoldDuration = cfg.hold
	prompt.RequiresLineOfSight = false
	model:SetAttribute("Anim", "idle")
	model:SetAttribute("Face", "happy")
	return prompt
end

function PatchService.rig()
	return rig
end

local function centre()
	local head = rig
		and (rig:FindFirstChild("PumpkinHead") or rig:FindFirstChild("Body") or rig:FindFirstChild("Counter"))
	return head and head.Position
end

function PatchService.isNear(player, studs)
	local pos = centre()
	return pos ~= nil and Guards.near(player, pos, studs)
end

-- sets the rig's Anim / Face (PatchRigController poses him from them); with holdSec, back to idle / happy after
-- that long unless a newer look came first
local lookToken = 0
local function look(anim, face, holdSec)
	if not rig then
		return
	end
	lookToken += 1
	local mine = lookToken
	rig:SetAttribute("Anim", anim)
	rig:SetAttribute("Face", face)
	local animator = rig:FindFirstChildOfClass("AnimationController")
	animator = animator and animator:FindFirstChildOfClass("Animator")
	local anims = rig:FindFirstChild("Animations")
	local animation = anims and anims:FindFirstChild(anim)
	if animator and animation and animation.AnimationId ~= "" then
		pcall(function()
			animator:LoadAnimation(animation):Play()
		end)
	end
	if holdSec then
		task.delay(holdSec, function()
			if lookToken == mine and rig then
				rig:SetAttribute("Anim", "idle")
				rig:SetAttribute("Face", "happy")
			end
		end)
	end
end

function PatchService.textFor(id, fmt)
	local line = Config.Patch.lines[id]
	if fmt ~= nil then
		return string.format(line.text, fmt)
	end
	return line.text
end

-- the flag a line uses: patchTips[id] (flag = true), or weekly.lineSeen vs the current update (flag = "weekly.lineSeen")
local function seen(profile, id, line)
	if line.flag == true then
		return profile.patchTips[id] == true
	elseif line.flag == "weekly.lineSeen" then
		return profile.weekly.lineSeen == Schedule.currentUpdate(Clock.now()).updateId
	end
	return false
end

local function mark(player, profile, id, line)
	if line.flag == true then
		profile.patchTips[id] = true
		NetService.change(player, { "patchTips" }, profile.patchTips)
	elseif line.flag == "weekly.lineSeen" then
		profile.weekly.lineSeen = Schedule.currentUpdate(Clock.now()).updateId
		NetService.change(player, { "weekly" }, profile.weekly)
	end
end

function PatchService.say(player, id, fmt)
	local line = Config.Patch.lines[id]
	local profile = DataService.get(player)
	if not line or not profile then
		return false
	end
	if seen(profile, id, line) then
		return false
	end
	mark(player, profile, id, line)
	NetService.fire(player, "PatchLine", {
		id = id,
		text = PatchService.textFor(id, fmt),
		display = line.kind,
		hideSec = line.seconds,
		hideOn = line.hideOn,
	})
	local lookFor = PatchService.LINE_LOOK[id]
	if lookFor then
		look(lookFor[1], lookFor[2], line.seconds)
	end
	Telemetry.log(player, "patch_line_shown", { id = id })
	return true
end

local SETTING_FIELDS =
	{ patchAlerts = "settings", music = "settings", sfx = "settings", reducedFx = "settings", gnomeOn = "root" }

local function setSetting(player, payload, profile)
	local where = SETTING_FIELDS[payload.key]
	if where == "root" then
		profile[payload.key] = payload.value
		NetService.change(player, { payload.key }, payload.value)
	else
		profile.settings[payload.key] = payload.value
		NetService.change(player, { "settings" }, profile.settings)
	end
	return true
end

local function patchAck(player, payload)
	Telemetry.log(player, "patch_line_dismissed", { id = payload.id, how = payload.how })
	return true
end

local function doze(now)
	if not rig then
		return
	end
	local range = Config.Patch.lines.restock.rangeStuds
	for _, player in Players:GetPlayers() do
		if PatchService.isNear(player, range) then
			lastNear = now
			if rig:GetAttribute("Face") == "sleepy" then
				look("idle", "happy")
			end
			return
		end
	end
	if now - lastNear >= SLEEPY_SEC and rig:GetAttribute("Face") ~= "sleepy" then
		look("idle", "sleepy")
	end
end

function PatchService:Init()
	local street = workspace:FindFirstChild("Street")
	rig = street and street:FindFirstChild("Patch")
	if not rig and street then
		rig = Instance.new("Model")
		rig.Name = "Patch"
		rig.Parent = street
	end
	if rig then
		rig.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		local prompt = setUp(rig)
		prompt.Triggered:Connect(function(player)
			if PatchService.isNear(player, Config.Patch.serverRange) then
				ShopService.open(player, "prompt")
			end
		end)
	end
	NetService.on("Settings", "set", nil, setSetting)
	NetService.on("Settings", "patchAck", nil, patchAck)
end

function PatchService:Start()
	lastNear = Clock.now()
	MutationService.Mutated:Connect(function(player, _, key)
		PatchService.say(player, "mutation", if key == "wet" then "Wet" else "Golden")
	end)
	BlockPartyService.Opened:Connect(function()
		for _, player in Players:GetPlayers() do
			PatchService.say(player, "blockParty")
		end
	end)
	while true do
		task.wait(1)
		doze(Clock.now())
	end
end

function PatchService:OnPlayerLoaded(player, profile)
	if next(profile.tiles) == nil then
		PatchService.say(player, "plant")
	end
	local window = BlockPartyService.state()
	if window and window.phase == "open" then
		PatchService.say(player, "blockParty")
	end
end

return PatchService
