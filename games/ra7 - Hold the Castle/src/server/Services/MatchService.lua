--[[
The match (master plan §4), owned by the server from start to finish:

  intermission  the hangout between matches (the results show here; a short wait, never a long one)
  build         everyone is a dwarf: mine, build the castle around Shrine 1, pick a job. A clock counts down.
                At FIRST_SCARE_AT the sky dims, a horn blows and monsters show up on the far hill; scouts come
                after that (HordeService).
  plague        the sky turns, a horn, about 1 in 4 dwarves turn into monsters (TeamService)
  fight         monsters attack; a shrine drains while monsters near it outnumber dwarves (ShrineService).
                When a shrine falls the monsters spawn there and the dwarves run back to the next one.
  laststand     the fight, once only Shrine 3 is left: music faster, light redder
  ended         who won, how long the dwarves held, who did the most; coins and XP (ProgressService)

Dwarves win when the fight clock runs out with a shrine standing. Monsters win when the last shrine falls or
every dwarf is gone. Clients only display: the phase, the clock and the shrines are server state (workspace
attributes Phase, PhaseEnds, FightEnds, Fallen, and the "Match" view).
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local MatchService = {
	Name = "MatchService",
	Dependencies = { "PlayerDataService" },
	PhaseChanged = Signal.new("MatchService.PhaseChanged"), -- (phase, previous)
	Started = Signal.new("MatchService.Started"), -- (match) build time begins: a fresh castle, everyone a dwarf
	Scare = Signal.new("MatchService.Scare"), -- () the first scare
	Plague = Signal.new("MatchService.Plague"), -- () the plague begins
	FightStarted = Signal.new("MatchService.FightStarted"), -- ()
	ShrineFell = Signal.new("MatchService.ShrineFell"), -- (index, isLast)
	Ended = Signal.new("MatchService.Ended"), -- (result) { winner, reason, held, fallen, number, id }
	Reset = Signal.new("MatchService.Reset"), -- () back to the hangout: clear the castle and the horde
}

local registry
local match -- the current match state

local function now()
	return workspace:GetServerTimeNow()
end

local function newId()
	local ok, guid = pcall(HttpService.GenerateGUID, HttpService, false)
	return ok and guid or tostring(os.time()) .. "-" .. math.random(1e6)
end

local function publish()
	workspace:SetAttribute("Phase", match.phase)
	workspace:SetAttribute("PhaseEnds", match.phaseEnds or 0)
	workspace:SetAttribute("FightEnds", match.fightEnds or 0)
	workspace:SetAttribute("Fallen", match.fallen)
	workspace:SetAttribute("MatchNumber", match.number)
	workspace:SetAttribute("Scared", match.scared == true)
	Net.fireAll("Match", MatchService:View())
end

function MatchService:View()
	return {
		phase = match.phase,
		ends = match.phaseEnds,
		fightEnds = match.fightEnds,
		fightStarted = match.fightStarted,
		number = match.number,
		id = match.id,
		fallen = match.fallen,
		active = math.min(3, match.fallen + 1),
		buildSeconds = match.buildSeconds,
		scared = match.scared == true,
		result = match.result,
	}
end

function MatchService:State()
	return match
end

function MatchService:Phase()
	return match.phase
end

-- Is the match running (build through the last stand)?
function MatchService:InMatch()
	local p = match.phase
	return p == "build" or p == "plague" or p == "fight" or p == "laststand"
end

-- Has the plague come (monsters exist)?
function MatchService:IsFight()
	local p = match.phase
	return p == "plague" or p == "fight" or p == "laststand"
end

function MatchService:TimeLeft()
	return math.max(0, (match.phaseEnds or 0) - now())
end

-- Seconds since the fight began (0 before it).
function MatchService:FightSeconds()
	if not match.fightStarted then
		return 0
	end
	return math.max(0, now() - match.fightStarted)
end

-- Seconds since build time began (0 outside it).
function MatchService:BuildElapsed()
	if match.phase ~= "build" then
		return match.buildStarted and match.buildSeconds or 0
	end
	return math.max(0, now() - (match.buildStarted or now()))
end

-- The shrine the monsters are after (1-3).
function MatchService:ActiveShrine()
	return math.min(3, match.fallen + 1)
end

function MatchService:Fallen()
	return match.fallen
end

local function setPhase(phase, seconds)
	local prev = match.phase
	match.phase = phase
	match.phaseStarted = now()
	match.phaseEnds = seconds and (now() + seconds) or 0
	publish()
	MatchService.PhaseChanged:Fire(phase, prev)
end

function MatchService:_startBuild()
	local players = #Players:GetPlayers()
	match = {
		number = (match and match.number or 0) + 1,
		id = newId(),
		phase = match and match.phase or "intermission",
		fallen = 0,
		scared = false,
		buildSeconds = Formulas.buildSeconds(players),
		playersAtStart = players,
		startedAt = os.time(),
		buildStarted = now(),
	}
	setPhase("build", match.buildSeconds)
	self.Started:Fire(match)
end

function MatchService:_startPlague()
	setPhase("plague", Constants.PLAGUE_SECONDS)
	self.Plague:Fire()
end

function MatchService:_startFight()
	match.fightStarted = now()
	match.fightEnds = now() + Constants.FIGHT_SECONDS
	setPhase(match.fallen >= 2 and "laststand" or "fight", Constants.FIGHT_SECONDS)
	self.FightStarted:Fire()
end

-- The match is over. winner: "dwarf" | "monster". reason: "held" | "shrines" | "wiped" | "empty".
function MatchService:End(winner, reason)
	if not self:InMatch() then
		return
	end
	local held = self:FightSeconds()
	match.result = {
		winner = winner,
		reason = reason,
		held = math.floor(held),
		fallen = match.fallen,
		number = match.number,
		id = match.id,
		buildSeconds = match.buildSeconds,
	}
	setPhase("ended", Constants.ENDED_SECONDS)
	self.Ended:Fire(match.result)
end

function MatchService:_toIntermission(quick)
	match.result = match.result
	setPhase("intermission", quick and Constants.FIRST_MATCH_DELAY or Constants.INTERMISSION_SECONDS)
	self.Reset:Fire()
end

-- ShrineService: a shrine fell.
function MatchService:ShrineFall(index)
	if not self:IsFight() or index <= match.fallen then
		return
	end
	match.fallen = index
	local last = index >= 3
	publish()
	self.ShrineFell:Fire(index, last)
	if last then
		self:End("monster", "shrines")
	elseif index >= 2 and match.phase == "fight" then
		match.phase = "laststand"
		publish()
		self.PhaseChanged:Fire("laststand", "fight")
	end
end

-- How many dwarves are still standing (players and NPC helpers).
function MatchService:DwarvesLeft()
	local n = 0
	if registry.TeamService then
		n += registry.TeamService:DwarfCount()
	end
	if registry.HordeService then
		n += registry.HordeService:DwarfCount()
	end
	return n
end

function MatchService:CheckEnd()
	if (match.phase == "fight" or match.phase == "laststand") and self:DwarvesLeft() <= 0 then
		self:End("monster", "wiped")
	end
end

-- Move on to the next phase now (tests, the render tools, admin).
function MatchService:Skip()
	local p = match.phase
	if p == "intermission" then
		self:_startBuild()
	elseif p == "build" then
		self:_startPlague()
	elseif p == "plague" then
		self:_startFight()
	elseif p == "fight" or p == "laststand" then
		self:End("dwarf", "held")
	elseif p == "ended" then
		self:_toIntermission(false)
	end
end

function MatchService:_tick()
	local p = match.phase
	local t = now()
	if p == "intermission" then
		if #Players:GetPlayers() > 0 and match.phaseEnds > 0 and t >= match.phaseEnds then
			self:_startBuild()
		elseif #Players:GetPlayers() > 0 and match.phaseEnds == 0 then
			match.phaseEnds = t + Constants.FIRST_MATCH_DELAY
			publish()
		end
	elseif p == "build" then
		if not match.scared and t - match.buildStarted >= Constants.FIRST_SCARE_AT then
			match.scared = true
			publish()
			self.Scare:Fire()
		end
		if t >= match.phaseEnds then
			self:_startPlague()
		end
	elseif p == "plague" then
		if t >= match.phaseEnds then
			self:_startFight()
		end
	elseif p == "fight" or p == "laststand" then
		if t >= match.fightEnds then
			self:End("dwarf", "held")
		else
			self:CheckEnd()
		end
	elseif p == "ended" then
		if t >= match.phaseEnds then
			self:_toIntermission(false)
		end
	end
	-- nobody left mid-match: stop and wait in the hangout
	if #Players:GetPlayers() == 0 and self:InMatch() then
		self:End("monster", "empty")
	end
end

function MatchService:Init(reg)
	registry = reg
	match = {
		number = 0,
		id = newId(),
		phase = "intermission",
		phaseStarted = now(),
		phaseEnds = 0, -- waits for the first player
		fallen = 0,
	}
	publish()
	Players.PlayerAdded:Connect(function()
		-- the first player into an empty server starts at once (no standing around, §12)
		if match.phase == "intermission" and (match.phaseEnds == 0 or match.number == 0) then
			match.phaseEnds = now() + Constants.FIRST_MATCH_DELAY
			publish()
		end
	end)
end

function MatchService:Start()
	while true do
		task.wait(0.25)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[MatchService] " .. tostring(err))
		end
	end
end

function MatchService:OnPlayerReady(player)
	Net.fire(player, "Match", self:View())
end

return MatchService
