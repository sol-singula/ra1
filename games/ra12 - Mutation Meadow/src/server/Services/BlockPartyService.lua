--[[
The hourly Block Party at the street's sunflower (§2 BlockPartyService, §6 timeline).

At the top of every UTC hour h a window opens: goal = max(goalMin, goalPerPlayer x players), fixed for the window,
stage Drooping. BlockParty:water (open, no bloom yet, within Config.Net.sunflowerRangeStuds of the sunflower, at
most once per waterEverySec per player) adds a water. Stages: Perking from ceil(perking x goal), Standing from
ceil(standing x goal), Bloom at the goal; at h + windowSec it blooms anyway. The bloom starts the weather
(WeatherService) and pays coinsPerLevelSq x plotLevel^2 once to everyone with reward.minWaters waters this window;
the sunflowerFriendAt-th reward earns sunflower_friend. When the weather ends the sunflower wilts for wiltSec,
then stays drooped until the next hour.

BlockPartyState { phase, stage, waters, goal, yourWaters, endsAt } goes to every player on each change and every
second while open.

  BlockPartyService.goalFor(players) / stageFor(waters, goal)
  BlockPartyService.state()          the window (or nil)
  BlockPartyService.open(now, forced?) / bloom(now) / finish()   (also the DevCommand "bp start|bloom|end")
  BlockPartyService.tick(now)
  BlockPartyService.Opened(window) / Watered(player) / Bloomed(window) / BadgeEarned(player, key)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Schedule = require(ReplicatedStorage.Shared.Schedule)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local DevCommands = require(script.Parent.Parent.Net.DevCommands)
local Guards = require(script.Parent.Parent.Net.Guards)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)
local WeatherService = require(script.Parent.WeatherService)

local BlockPartyService = {
	Opened = Signal.new(),
	Watered = Signal.new(),
	Bloomed = Signal.new(),
	BadgeEarned = Signal.new(),
}

local HOUR = 3600
local LOOKS = { drooping = "Drooping", perking = "Perking", standing = "Standing", bloom = "Bloom" }

local window -- { hour, startAt, endsAt, closesAt, goal, waters, stage, phase, wiltEndsAt }
local lastWater = setmetatable({}, { __mode = "k" }) -- [player] = time

function BlockPartyService.goalFor(players)
	local cfg = Config.BlockParty
	return math.max(cfg.goalMin, cfg.goalPerPlayer * players)
end

function BlockPartyService.stageFor(waters, goal)
	local stages = Config.BlockParty.stages
	if waters >= math.ceil(stages.bloom * goal) then
		return "bloom"
	elseif waters >= math.ceil(stages.standing * goal) then
		return "standing"
	elseif waters >= math.ceil(stages.perking * goal) then
		return "perking"
	end
	return "drooping"
end

function BlockPartyService.state()
	return window
end

local function sunflower()
	local street = workspace:FindFirstChild("Street")
	return street and street:FindFirstChild("Sunflower")
end

local function centre(model)
	local stem = model:FindFirstChild("Stem")
	if stem then
		return stem.Position
	end
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			return child.Position
		end
	end
	return nil
end

local function show()
	local model = sunflower()
	if not model or not window then
		return
	end
	local look = if window.phase == "wilt" then "Wilt" else LOOKS[window.stage]
	for _, name in { "Drooping", "Perking", "Standing", "Bloom", "Wilt" } do
		local part = model:FindFirstChild(name)
		if part then
			part.Transparency = if name == look then 0 else 1
		end
	end
	model:SetAttribute("Phase", window.phase)
	model:SetAttribute("Stage", window.stage)
	model:SetAttribute("Waters", window.waters)
	model:SetAttribute("Goal", window.goal)
end

local function yourWaters(player)
	local profile = DataService.get(player)
	if profile and window and profile.blockParty.window == window.hour then
		return profile.blockParty.waters
	end
	return 0
end

local function endsAt()
	if window.phase == "open" then
		return window.endsAt
	elseif window.phase == "weather" then
		local e = WeatherService.current()
		return e and e.endsAt or window.closesAt
	elseif window.phase == "wilt" then
		return window.wiltEndsAt
	end
	return window.closesAt
end

local function stateFor(player)
	return {
		phase = window.phase,
		stage = window.stage,
		waters = window.waters,
		goal = window.goal,
		yourWaters = yourWaters(player),
		endsAt = endsAt(),
	}
end

local function broadcast()
	if not window then
		return
	end
	show()
	for _, player in Players:GetPlayers() do
		NetService.fire(player, "BlockPartyState", stateFor(player))
	end
end

function BlockPartyService.open(now, forced)
	local hour = Schedule.hourStart(now)
	local startAt = if forced then now else hour
	window = {
		hour = hour,
		startAt = startAt,
		endsAt = startAt + Config.BlockParty.windowSec,
		closesAt = startAt + HOUR,
		goal = BlockPartyService.goalFor(#Players:GetPlayers()),
		waters = 0,
		stage = "drooping",
		phase = "open",
	}
	if now >= window.endsAt then
		window.phase = "drooped" -- the server started after this hour's window: wait for the next one
	end
	broadcast()
	BlockPartyService.Opened:Fire(window)
	return window
end

local function reward()
	local cfg = Config.BlockParty
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		local bp = profile and profile.blockParty
		if bp and bp.window == window.hour and bp.waters >= cfg.reward.minWaters and not bp.rewarded then
			bp.rewarded = true
			bp.rewardsTotal += 1
			NetService.change(player, { "blockParty" }, bp)
			InventoryService.addCoins(player, cfg.reward.coinsPerLevelSq * profile.plotLevel ^ 2, "blockParty")
			if bp.rewardsTotal == cfg.sunflowerFriendAt then
				BlockPartyService.BadgeEarned:Fire(player, "sunflower_friend")
			end
		end
	end
end

function BlockPartyService.bloom(now)
	if not window or window.phase ~= "open" then
		return false
	end
	window.phase = "weather"
	window.stage = "bloom"
	window.bloomAt = now
	WeatherService.startEvent()
	reward()
	broadcast()
	BlockPartyService.Bloomed:Fire(window)
	return true
end

local function wilt(now)
	window.phase = "wilt"
	window.wiltEndsAt = now + Config.BlockParty.wiltSec
	broadcast()
end

function BlockPartyService.finish()
	if not window then
		return
	end
	if window.phase == "weather" then
		WeatherService.stopEvent()
	end
	window.phase = "drooped"
	window.stage = "drooping"
	broadcast()
end

function BlockPartyService.tick(now)
	if not window or Schedule.hourStart(now) > window.hour then
		BlockPartyService.open(now)
		return
	end
	if window.phase == "open" then
		if now >= window.endsAt then
			BlockPartyService.bloom(now)
		else
			broadcast()
		end
	elseif window.phase == "weather" then
		if not WeatherService.current() then
			wilt(now)
		end
	elseif window.phase == "wilt" and now >= window.wiltEndsAt then
		window.phase = "drooped"
		window.stage = "drooping"
		broadcast()
	end
end

local function water(player, _, profile)
	if not window or window.phase ~= "open" then
		return false, "closed"
	end
	local model = sunflower()
	local pos = model and centre(model)
	if not pos or not Guards.near(player, pos, Guards.RANGE.sunflower) then
		return false, "too_far"
	end
	local now = Clock.now()
	if lastWater[player] and now - lastWater[player] < Config.BlockParty.waterEverySec then
		return false, "cooldown"
	end
	lastWater[player] = now
	local bp = profile.blockParty
	if bp.window ~= window.hour then
		bp.window = window.hour
		bp.waters = 0
		bp.rewarded = false
	end
	bp.waters += 1
	window.waters += 1
	NetService.change(player, { "blockParty" }, bp)
	BlockPartyService.Watered:Fire(player)
	window.stage = BlockPartyService.stageFor(window.waters, window.goal)
	if window.stage == "bloom" then
		BlockPartyService.bloom(now)
	else
		broadcast()
	end
	return true
end

function BlockPartyService:Init()
	NetService.on("BlockParty", "water", nil, water)
	NetService.snapshotPart("blockParty", function(player)
		return window and stateFor(player)
	end)
	DevCommands.register("bp", function(_, args)
		local now = Clock.now()
		local which = args[1]
		if which == "start" then
			BlockPartyService.open(now, true)
		elseif which == "bloom" then
			if not window or window.phase ~= "open" then
				BlockPartyService.open(now, true)
			end
			BlockPartyService.bloom(now)
		elseif which == "end" then
			BlockPartyService.finish()
		else
			return false, "usage: bp start|bloom|end"
		end
		return true
	end)
end

function BlockPartyService:Start()
	WeatherService.Ended:Connect(function()
		if window and window.phase == "weather" then
			wilt(Clock.now())
		end
	end)
	BlockPartyService.tick(Clock.now())
	while true do
		task.wait(1)
		BlockPartyService.tick(Clock.now())
	end
end

function BlockPartyService:OnPlayerLoaded(player)
	if window then
		NetService.fire(player, "BlockPartyState", stateFor(player))
	end
end

return BlockPartyService
