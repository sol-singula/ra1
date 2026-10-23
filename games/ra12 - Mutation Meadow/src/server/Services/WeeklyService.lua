--[[
The weekly update (§6): every Saturday 10:00 Mountain (Schedule: 16:00 UTC in daylight time, 17:00 otherwise).

Each player gets WeeklyState { updateId, startsAt, nextAt, eventWeek, claimed } on join and again at the exact nextAt
(a task.delay timer re-armed each week, and after a Studio clock jump). Weekly:claim {updateId} needs the current
updateId, once: 1000 x plotLevel^2 coins + 3 top-tier seeds (source "weekly"); weekly.claimed keeps the last 8 ids.
Patch's update line goes out on the first join (a brand-new player gets it with the FTUE board beat instead), on
viewing the world UpdateBoard, and to everyone in the server at the rollover; once per update (flag weekly.lineSeen). What's new: Config.WeeklyNotes[updateId] (or .default).

DevCommands (dev + Studio only): "clock +<sec>" and "week next" move the virtual clock (workspace ClockOffset).

  WeeklyService.current() -> { updateId, startsAt, nextAt }
  WeeklyService.stateFor(player)
  WeeklyService.notes(updateId)
  WeeklyService.Rolled(update)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Schedule = require(ReplicatedStorage.Shared.Schedule)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local DevCommands = require(script.Parent.Parent.Net.DevCommands)
local InventoryService = require(script.Parent.InventoryService)
local NetService = require(script.Parent.NetService)

local WeeklyService = {
	Rolled = Signal.new(),
}

local KEEP = 8

local services
local current
local timer
local armedFor

function WeeklyService.current()
	return current
end

function WeeklyService.notes(updateId)
	return Config.WeeklyNotes[updateId] or Config.WeeklyNotes.default
end

function WeeklyService.stateFor(player)
	local profile = DataService.get(player)
	return {
		updateId = current.updateId,
		startsAt = current.startsAt,
		nextAt = current.nextAt,
		eventWeek = Schedule.isEventWeek(current.updateId),
		claimed = profile ~= nil and profile.weekly.claimed[current.updateId] == true,
		notes = WeeklyService.notes(current.updateId),
	}
end

local function send(player)
	NetService.fire(player, "WeeklyState", WeeklyService.stateFor(player))
end

local arm

local function roll()
	current = Schedule.currentUpdate(Clock.now())
	for _, player in Players:GetPlayers() do
		send(player)
		if services and services.PatchService then
			services.PatchService.say(player, "update")
		end
	end
	WeeklyService.Rolled:Fire(current)
	arm()
end

function arm()
	if timer then
		task.cancel(timer)
	end
	current = Schedule.currentUpdate(Clock.now())
	armedFor = current.nextAt
	timer = task.delay(math.max(0, current.nextAt - Clock.now()), function()
		timer = nil
		roll()
	end)
end

-- re-arm when the virtual clock moved (Studio)
function WeeklyService.rearm()
	local before = current and current.updateId
	arm()
	if current.updateId ~= before then
		roll()
	end
end

local function claim(player, payload, profile)
	if payload.updateId ~= current.updateId then
		return false, "old_update"
	end
	local claimed = profile.weekly.claimed
	if claimed[payload.updateId] then
		return false, "claimed"
	end
	claimed[payload.updateId] = true
	local ids = {}
	for id in claimed do
		table.insert(ids, id)
	end
	table.sort(ids)
	for i = 1, #ids - KEEP do
		claimed[ids[i]] = nil
	end
	local gift = Config.Weekly.gift
	InventoryService.addCoins(player, gift.coinsPerLevelSq * profile.plotLevel ^ 2, "weekly")
	local seed = services.RewardService and services.RewardService.topTierSeed(profile)
	if seed then
		InventoryService.addSeeds(player, seed, gift.topTierSeeds, "weekly")
	end
	NetService.change(player, { "weekly" }, profile.weekly)
	send(player)
	return true
end

local function moveClock(by)
	workspace:SetAttribute("ClockOffset", (workspace:GetAttribute("ClockOffset") or 0) + by)
	WeeklyService.rearm()
end

function WeeklyService:Init(all)
	services = all
	current = Schedule.currentUpdate(Clock.now())
	NetService.on("Weekly", "claim", nil, claim)
	NetService.snapshotPart("weekly", function(player)
		return WeeklyService.stateFor(player)
	end)
	DevCommands.register("clock", function(_, args)
		local by = tonumber(tostring(args[1]):match("^%+?(%d+%.?%d*)$"))
		if not RunService:IsStudio() then
			return false, "studio_only"
		end
		if not by then
			return false, "usage: clock +<sec>"
		end
		moveClock(by)
		return true
	end)
	DevCommands.register("week", function(_, args)
		if not RunService:IsStudio() then
			return false, "studio_only"
		end
		if args[1] ~= "next" then
			return false, "usage: week next"
		end
		moveClock(current.nextAt - Clock.now() + 1)
		return true
	end)
end

function WeeklyService:Start()
	arm()
	-- viewing the world update board is the other way Patch's update line goes out
	local street = workspace:FindFirstChild("Street")
	local board = street and street:FindFirstChild("Boards") and street.Boards:FindFirstChild("UpdateBoard")
	local prompt = board and board:FindFirstChild("View")
	if prompt then
		prompt.Triggered:Connect(function(player)
			if services.PatchService then
				services.PatchService.say(player, "update")
			end
		end)
	end
end

function WeeklyService:OnPlayerLoaded(player, profile)
	if armedFor ~= Schedule.currentUpdate(Clock.now()).nextAt then
		WeeklyService.rearm()
	end
	send(player)
	-- a brand-new player hears Patch's plant tip first: their update line comes with the board beat (FTUE 540s)
	if services.PatchService and profile.firstSession.done then
		services.PatchService.say(player, "update")
	end
end

return WeeklyService
