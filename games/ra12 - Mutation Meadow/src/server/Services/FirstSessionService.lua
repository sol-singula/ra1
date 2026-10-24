--[[
The first 10 minutes (§8.6 FTUE beats), timed on firstSession.playedSec: in-game seconds that persist across
rejoins until firstSession.done.

    0   welcome badge (RewardService) and Patch "plant" (PatchService)
  240   the Welcome Shower (WeatherService.startShower), Patch "shower", funnel 7. Block Party weather running:
        deferred to its end + deferIfWeatherSec. firstSession.showerAt keeps the played second it started at.
  +10   the guaranteed Wet (WeatherService) and Patch "mutation"; keeping it gives first_splash + Starter 3
  300   playtime gift 1 ready (RewardService)
 +150   the daily calendar opens (firstSession.calendarShown, which the client opens on), once the shop is closed
        and no Patch toast is showing; the client asks for the notification opt-in
  540   the HUD points at the update board: Toast kind "board" { nextUpdateAt, nextPartyAt } (client local time),
        and Patch's "update" line (held back on a first join so "plant" comes first)
  600   playtime gift 2 ready, funnel 10, extraRowEligible; done once showerDone and calendarShown

  FirstSessionService.tick(player, dt)   runs one step (the 1s loop calls it)
  FirstSessionService.Beat(player, name)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Schedule = require(ReplicatedStorage.Shared.Schedule)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local NetService = require(script.Parent.NetService)
local PatchService = require(script.Parent.PatchService)
local ShopService = require(script.Parent.ShopService)
local Telemetry = require(script.Parent.Parent.Telemetry)
local WeatherService = require(script.Parent.WeatherService)

local FirstSessionService = {
	Beat = Signal.new(),
}

FirstSessionService.BOARD_AT = 540
FirstSessionService.DONE_AT = 600

local lastTick = setmetatable({}, { __mode = "k" }) -- [player] = Clock time of the last tick
local deferTo = setmetatable({}, { __mode = "k" }) -- [player] = played second the shower waits for
local toastUntil = setmetatable({}, { __mode = "k" }) -- [player] = Clock time the last Patch toast hides
local boardSent = setmetatable({}, { __mode = "k" })

local function save(player, fs)
	NetService.change(player, { "firstSession" }, fs)
end

local function beat(player, name)
	FirstSessionService.Beat:Fire(player, name)
end

local function funnel(player, step)
	Telemetry.log(player, "funnel", { step = step })
end

local function shower(player, fs)
	local cfg = Config.Weather.welcomeShower
	local event = WeatherService.current()
	if event then
		-- Block Party weather is up: wait for its end + deferIfWeatherSec
		deferTo[player] = fs.playedSec + math.max(0, event.endsAt - Clock.now()) + cfg.deferIfWeatherSec
		return
	end
	if deferTo[player] and fs.playedSec < deferTo[player] then
		return
	end
	deferTo[player] = nil
	fs.showerAt = fs.playedSec
	fs.showerDone = true
	save(player, fs)
	WeatherService.startShower(player)
	PatchService.say(player, "shower")
	funnel(player, 7)
	beat(player, "shower")
end

local function calendar(player, fs)
	if ShopService.isOpen(player) or (toastUntil[player] or 0) > Clock.now() then
		return
	end
	fs.calendarShown = true
	save(player, fs)
	beat(player, "calendar")
end

local function board(player)
	boardSent[player] = true
	local now = Clock.now()
	local nextParty = Schedule.hourStart(now) + 3600
	NetService.toast(player, "board", "Check the update board!", {
		nextUpdateAt = Schedule.currentUpdate(now).nextAt,
		nextPartyAt = nextParty,
	})
	PatchService.say(player, "update")
	beat(player, "board")
end

local function finish(player, fs)
	if not fs.extraRowEligible then
		fs.extraRowEligible = true
		funnel(player, 10)
		beat(player, "ten")
	end
	if fs.showerDone and fs.calendarShown then
		fs.done = true
		beat(player, "done")
	end
	save(player, fs)
end

function FirstSessionService.tick(player, dt)
	local profile = DataService.get(player)
	local fs = profile and profile.firstSession
	if not fs or fs.done then
		return
	end
	fs.playedSec += dt
	local cfg = Config.Weather.welcomeShower
	if not fs.showerAt and fs.playedSec >= cfg.atSessionSec then
		shower(player, fs)
	end
	if fs.showerAt and not fs.calendarShown and fs.playedSec >= fs.showerAt + cfg.calendarAfterShowerSec then
		calendar(player, fs)
	end
	if not boardSent[player] and fs.playedSec >= FirstSessionService.BOARD_AT then
		board(player)
	end
	if fs.playedSec >= FirstSessionService.DONE_AT then
		finish(player, fs)
	end
end

function FirstSessionService:Start()
	Telemetry.Logged:Connect(function(player, name, data)
		if player and name == "patch_line_shown" then
			local line = Config.Patch.lines[data.id]
			toastUntil[player] = Clock.now() + (line and line.seconds or 0)
		end
	end)
	while true do
		task.wait(1)
		local now = Clock.now()
		for _, player in Players:GetPlayers() do
			if lastTick[player] then
				local dt = now - lastTick[player]
				lastTick[player] = now
				FirstSessionService.tick(player, dt)
			end
		end
	end
end

function FirstSessionService:OnPlayerLoaded(player)
	lastTick[player] = Clock.now()
end

function FirstSessionService:OnPlayerLeaving(player)
	lastTick[player], deferTo[player], toastUntil[player], boardSent[player] = nil, nil, nil, nil
end

return FirstSessionService
