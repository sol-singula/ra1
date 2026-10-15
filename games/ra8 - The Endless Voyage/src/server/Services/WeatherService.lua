--[[
The sky and the sea's moods (master plan §1, §10). A calm day-night cycle for the whole server (the clock is in
workspace attributes, so every client draws the same sun); storms come with voyages (VoyageService) and now and
then at home, and while one is over a plot its raft takes a hit every few seconds (RaftService.DamageRandom:
railings, walls and an anchor soften it, a hammer fixes it). Night changes the fishing and lights the lamps.

  workspace attributes   Phase ("day" | "night"), PhaseStart, PhaseEnds, Storm (a storm over every home plot)
  "Weather" (per player)  { phase, storm, stormEnds, ends, clock }
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local WeatherService = {
	Name = "WeatherService",
	Dependencies = { "PlayerDataService", "RaftService", "PlayerService" },
	PhaseChanged = Signal.new("WeatherService.PhaseChanged"), -- (phase)
	StormStarted = Signal.new("WeatherService.StormStarted"), -- (plot, source)
	StormEnded = Signal.new("WeatherService.StormEnded"), -- (plot, survivors)
}

local rafts, players, data, registry
local phase = "day"
local phaseStart, phaseEnds = 0, 0
local storms = {} -- [plot] = { ends, nextHit, source, home }
local homeStormAt = 0
local rng = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

function WeatherService:Phase()
	return phase
end

function WeatherService:IsNight()
	return phase == "night"
end

function WeatherService:StormAt(plot)
	return storms[plot]
end

function WeatherService:Clock()
	return Formulas.clockTime(phase, now() - phaseStart)
end

function WeatherService:View(player)
	local plot = players:Here(player)
	local storm = plot and storms[plot]
	return {
		phase = phase,
		ends = phaseEnds,
		clock = self:Clock(),
		storm = storm ~= nil,
		stormEnds = storm and storm.ends or nil,
	}
end

function WeatherService:Push(player)
	Net.fire(player, "Weather", self:View(player))
end

function WeatherService:PushAll()
	for _, player in Players:GetPlayers() do
		if data:Get(player) then
			self:Push(player)
		end
	end
end

local function setPhase(p)
	phase = p
	phaseStart = now()
	phaseEnds = phaseStart + (p == "night" and Constants.NIGHT_SECONDS or Constants.DAY_SECONDS)
	workspace:SetAttribute("Phase", p)
	workspace:SetAttribute("PhaseStart", phaseStart)
	workspace:SetAttribute("PhaseEnds", phaseEnds)
end

-- A storm over a plot for `seconds`.
function WeatherService:Storm(plot, seconds, source)
	local raft = rafts:Get(plot)
	if not raft then
		return false
	end
	local t = now()
	storms[plot] = {
		ends = t + (seconds or Constants.STORM_SECONDS),
		nextHit = t + 2,
		source = source or "storm",
		home = source == "home",
	}
	for _, player in players:PlayersOnPlot(plot) do
		Net.fire(player, "Callout", "⛈️ A storm! Hold on, and hammer what breaks.", "bad")
		Net.fire(player, "Sfx", "thunder")
		Net.fire(player, "Fx", "storm", { seconds = seconds })
		self:Push(player)
	end
	self.StormStarted:Fire(plot, source)
	return true
end

function WeatherService:_endStorm(plot)
	local storm = storms[plot]
	storms[plot] = nil
	if not storm then
		return
	end
	local survivors = players:PlayersOnPlot(plot)
	for _, player in survivors do
		Net.fire(player, "Callout", "🌤️ The storm passed.", "good")
		self:Push(player)
	end
	self.StormEnded:Fire(plot, survivors)
end

function WeatherService:_tick()
	local t = now()
	if t >= phaseEnds then
		setPhase(phase == "day" and "night" or "day")
		self.PhaseChanged:Fire(phase)
		self:PushAll()
		for _, player in Players:GetPlayers() do
			Net.fire(
				player,
				"Callout",
				phase == "night" and "🌙 Night falls. The lamps come on; the rare fish wake up."
					or "☀️ Morning. A new day on the water.",
				"info"
			)
		end
	end
	for plot, storm in storms do
		local raft = rafts:Get(plot)
		if not raft then
			storms[plot] = nil
		elseif t >= storm.ends then
			self:_endStorm(plot)
		elseif t >= storm.nextHit then
			storm.nextHit = t + Constants.STORM_HIT_EVERY
			rafts:DamageRandom(raft, 2, Constants.STORM_TILE_DAMAGE, { kind = "storm" })
			for _, player in players:PlayersOnPlot(plot) do
				Net.fire(player, "Fx", "wave", { center = rafts:Center(raft) })
			end
		end
	end
	-- a storm at home now and then, over every docked raft at once (the sky says so)
	if t >= homeStormAt then
		homeStormAt = t + rng:NextNumber(Constants.HOME_STORM_EVERY[1], Constants.HOME_STORM_EVERY[2])
		local voyages = registry.VoyageService
		local any = false
		for plot in rafts:All() do
			if not storms[plot] and (not voyages or voyages:State(plot) == "docked") then
				self:Storm(plot, Constants.STORM_SECONDS * 0.7, "home")
				any = true
			end
		end
		if any then
			workspace:SetAttribute("Storm", true)
			task.delay(Constants.STORM_SECONDS * 0.7 + 0.5, function()
				workspace:SetAttribute("Storm", false)
			end)
		end
	end
end

function WeatherService:Init(reg)
	registry = reg
	rafts = reg.RaftService
	players = reg.PlayerService
	data = reg.PlayerDataService
	setPhase("day")
	workspace:SetAttribute("Storm", false)
	homeStormAt = now() + rng:NextNumber(Constants.HOME_STORM_EVERY[1], Constants.HOME_STORM_EVERY[2])
	players.Moved:Connect(function(player)
		self:Push(player)
	end)
	rafts.Released:Connect(function(_, raft)
		storms[raft.plot] = nil
	end)
end

function WeatherService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function WeatherService:Start()
	while true do
		task.wait(1)
		self:_tick()
	end
end

-- (tests)
function WeatherService:_setPhaseEnds(t)
	phaseEnds = t
	workspace:SetAttribute("PhaseEnds", t)
end
function WeatherService:_setHomeStormAt(t)
	homeStormAt = t
end
return WeatherService
