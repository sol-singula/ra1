--[[
Server events on a clock: every SERVER_EVENT_EVERY seconds the whole ocean gets one (master plan §11: a reason to
stay for the next one), in turn:
  supply_rain   supply crates and a lane of debris for every raft
  golden_tide   everything reeled in counts double (OceanService reads workspace.GoldenTide)
  bottle_bloom  message bottles (charts to new places) for every raft
A minute before, everyone hears it's coming. The clients show the countdown from workspace attributes:
  NextEvent (key), NextEventAt (server time), EventName, EventIcon, EventEnds (server time while one is on).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local EventService = {
	Name = "EventService",
	Dependencies = { "RaftService", "OceanService" },
	Started = Signal.new("EventService.Started"), -- (key)
	Ended = Signal.new("EventService.Ended"), -- (key)
}

EventService.EVENTS = {
	{
		key = "supply_rain",
		name = "SUPPLY RAIN",
		icon = "🎁",
		seconds = 60,
		text = "Supply crates are drifting in for every raft: cast at them!",
	},
	{
		key = "golden_tide",
		name = "GOLDEN TIDE",
		icon = "✨",
		seconds = 120,
		text = "Everything you reel in counts DOUBLE for two minutes!",
	},
	{
		key = "bottle_bloom",
		name = "BOTTLE BLOOM",
		icon = "🍾",
		seconds = 60,
		text = "Bottles are floating by: the messages inside point to new islands!",
	},
}

local rafts, ocean
local turn = 0
local current -- { def, ends }

local function now()
	return workspace:GetServerTimeNow()
end

local function announce(text, color, seconds)
	for _, p in Players:GetPlayers() do
		Net.fire(p, "Alert", text, color, seconds)
	end
end

local function nextDef()
	return EventService.EVENTS[turn % #EventService.EVENTS + 1]
end

function EventService:Schedule(at)
	local def = nextDef()
	workspace:SetAttribute("NextEvent", def.key)
	workspace:SetAttribute("NextEventAt", at)
	workspace:SetAttribute("EventName", def.name)
	workspace:SetAttribute("EventIcon", def.icon)
	self.warned = false
end

-- Run the next event now (and the clock starts again from its end).
function EventService:Run()
	local def = nextDef()
	turn += 1
	current = { def = def, ends = now() + def.seconds }
	workspace:SetAttribute("EventEnds", current.ends)
	workspace:SetAttribute("EventName", def.name)
	workspace:SetAttribute("EventIcon", def.icon)
	announce(`{def.icon} {def.name}! {def.text}`, Color3.fromRGB(255, 220, 120), 5)
	for _, p in Players:GetPlayers() do
		Net.fire(p, "Sfx", "discover")
	end
	for plot in rafts:All() do
		if def.key == "supply_rain" then
			for i = 1, Constants.EVENT_CRATES do
				task.delay((i - 1) * def.seconds / Constants.EVENT_CRATES, function()
					if rafts:Get(plot) then
						ocean:Crate(plot, 1)
					end
				end)
			end
			ocean:Burst(plot, 14, def.seconds)
		elseif def.key == "bottle_bloom" then
			for i = 1, Constants.EVENT_BOTTLES do
				task.delay((i - 1) * def.seconds / Constants.EVENT_BOTTLES, function()
					if rafts:Get(plot) then
						ocean:Bottle(plot)
					end
				end)
			end
		end
	end
	if def.key == "golden_tide" then
		workspace:SetAttribute("GoldenTide", true)
	end
	self.Started:Fire(def.key)
	return def
end

function EventService:End()
	if not current then
		return
	end
	local def = current.def
	current = nil
	workspace:SetAttribute("EventEnds", nil)
	workspace:SetAttribute("GoldenTide", nil)
	self.Ended:Fire(def.key)
	self:Schedule(now() + Constants.SERVER_EVENT_EVERY)
end

function EventService:Current()
	return current and current.def or nil
end

function EventService:Init(registry)
	rafts = registry.RaftService
	ocean = registry.OceanService
end

function EventService:Start()
	self:Schedule(now() + Constants.SERVER_EVENT_FIRST)
	while true do
		task.wait(1)
		self:_tick()
	end
end

function EventService:_tick()
	local t = now()
	if current then
		if t >= current.ends then
			self:End()
		end
		return
	end
	local at = workspace:GetAttribute("NextEventAt")
	if not at then
		return
	end
	if not self.warned and at - t <= 60 then
		self.warned = true
		local def = nextDef()
		announce(`⏰ {def.icon} {def.name} in 1 minute!`, Color3.fromRGB(255, 240, 180), 3)
	end
	if t >= at then
		self:Run()
	end
end

-- (tests: the next event is this one)
function EventService:_setNext(key)
	for i, def in EventService.EVENTS do
		if def.key == key then
			turn = i - 1
		end
	end
end

return EventService
