--[[
The run (master plan §3, §8): one finite survival run per server at a time.

  idle -> day 1 -> dusk -> night 1 -> dawn -> day 2 -> ... -> night 6 -> dawn -> day 7 -> dusk -> boss (night 7)
       -> results -> (the world resets) -> day 1 of the next run

  * The first player into an empty server starts a run at once: they spawn by the fire and can move straight
    away (§4). Friends who join during day 1 join the run; the roster locks when night 1 starts (§8: a fixed
    roster). Anyone who joins after that waits for the next run (watching, or off to a new run: JoinService).
  * Day 1 is also when the team votes on the difficulty at the standing stones (any difficulty someone in the
    server has unlocked). It locks with the roster.
  * The camp bell: when every survivor rings it, the day ends early and the night comes (faster runs: §9).
  * Nights 3-6 may bring an event (Constants.EVENTS).
  * The run is won when Mega Kermy goes down on night 7 (BossService calls Win), lost when every survivor is down
    or a ghost at once (SurvivorService calls Wipe), or when night 7 runs out (dawn comes, he leaves).
  * Someone who leaves can come back to the same server and take their place again (JoinService offers it after a
    dropped connection); if nobody from the roster is left, the run is thrown away.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local RunService = {
	Name = "RunService",
	Dependencies = { "PlayerDataService" },
	Reset = Signal.new("RunService.Reset"), -- (run) a new run is being prepared: put the world back
	Started = Signal.new("RunService.Started"), -- (run) day 1 begins
	PhaseChanged = Signal.new("RunService.PhaseChanged"), -- (phase, run, previous)
	RosterLocked = Signal.new("RunService.RosterLocked"), -- (run)
	NightStarted = Signal.new("RunService.NightStarted"), -- (night, event, run)
	NightSurvived = Signal.new("RunService.NightSurvived"), -- (night, run)
	DayStarted = Signal.new("RunService.DayStarted"), -- (day, run)
	BossStarted = Signal.new("RunService.BossStarted"), -- (run)
	Ended = Signal.new("RunService.Ended"), -- (result)
	Joined = Signal.new("RunService.Joined"), -- (player, run): in the roster, spawn them
	Waiting = Signal.new("RunService.Waiting"), -- (player, run): joined after the roster locked
	Left = Signal.new("RunService.Left"), -- (player, run)
	Voted = Signal.new("RunService.Voted"), -- (player, kind, value)
}

local data
local run -- the current run (nil while idle)
local waiting = {} -- [player] = true: in the server, not in the run
local runNumber = 0
local emptySince

local function now()
	return workspace:GetServerTimeNow()
end

local function setAttrs()
	workspace:SetAttribute("Phase", run and run.phase or "idle")
	workspace:SetAttribute("PhaseEnds", run and run.phaseEnds or 0)
	workspace:SetAttribute("PhaseStart", run and run.phaseStart or 0)
	workspace:SetAttribute("Day", run and run.day or 0)
	workspace:SetAttribute("Night", run and run.night or 0)
	workspace:SetAttribute("Event", run and run.event or "")
	workspace:SetAttribute("Difficulty", run and run.difficulty or 1)
	workspace:SetAttribute("RosterLocked", run and run.locked or false)
end

-- Queries ------------------------------------------------------------------------------------------------------
function RunService:Get()
	return run
end

function RunService:Phase()
	return run and run.phase or "idle"
end

function RunService:IsNight()
	local p = self:Phase()
	return p == "night" or p == "boss"
end

function RunService:IsDay()
	return self:Phase() == "day"
end

function RunService:Day()
	return run and run.day or 0
end

function RunService:Night()
	return run and run.night or 0
end

function RunService:Difficulty()
	return run and run.difficulty or 1
end

function RunService:Event()
	return run and run.event or nil
end

function RunService:InRun(player)
	return run ~= nil and run.roster[player.UserId] ~= nil and run.roster[player.UserId].active
end

function RunService:IsWaiting(player)
	return waiting[player] == true
end

-- Players in the roster and still in the server.
function RunService:Active()
	local out = {}
	if run then
		for _, r in run.roster do
			if r.active and r.player.Parent then
				table.insert(out, r.player)
			end
		end
	end
	return out
end

-- Survivors counted for the next stage's difficulty (§8: adjusts at stage boundaries).
function RunService:StagePlayers()
	return run and run.stagePlayers or 1
end

function RunService:Seconds()
	return run and (now() - run.startedAt) or 0
end

function RunService:TimeLeft()
	if not run or not run.phaseEnds or run.phaseEnds <= 0 then
		return nil
	end
	return math.max(0, run.phaseEnds - now())
end

-- The difficulties someone in the server has unlocked (the stones that light up).
function RunService:UnlockedMax()
	local best = 1
	for _, p in Players:GetPlayers() do
		local profile = data:Get(p)
		if profile then
			best = math.max(best, profile.unlocked or 1)
		end
	end
	return math.min(best, #Constants.DIFFICULTIES)
end

function RunService:View()
	if not run then
		return { phase = "idle", waiting = true }
	end
	local roster = {}
	for userId, r in run.roster do
		table.insert(roster, { userId = userId, name = r.name, active = r.active })
	end
	local counts = {}
	for _, n in run.votes.difficulty do
		counts[n] = (counts[n] or 0) + 1
	end
	local bells, need = 0, 0
	for _, p in self:Active() do
		need += 1
		if run.votes.bell[p.UserId] then
			bells += 1
		end
	end
	return {
		id = run.id,
		number = run.number,
		phase = run.phase,
		day = run.day,
		night = run.night,
		phaseStart = run.phaseStart,
		phaseEnds = run.phaseEnds,
		startedAt = run.startedAt,
		difficulty = run.difficulty,
		event = run.event,
		locked = run.locked,
		roster = roster,
		votes = { difficulty = counts, bell = bells, need = need },
		unlockedMax = self:UnlockedMax(),
	}
end

function RunService:Broadcast()
	setAttrs()
	Net.fireAll("Run", self:View())
end

-- Phases ---------------------------------------------------------------------------------------------------------
function RunService:_setPhase(phase, seconds)
	local prev = run.phase
	run.phase = phase
	run.phaseStart = now()
	run.phaseEnds = seconds and (run.phaseStart + seconds) or 0
	run.votes.bell = {}
	self:Broadcast()
	self.PhaseChanged:Fire(phase, run, prev)
end

function RunService:_countStage()
	run.stagePlayers = math.max(1, #self:Active())
end

function RunService:_rollEvent(night)
	run.event = nil
	if night < 3 or night > 6 then
		return
	end
	if run.rng:NextNumber() > Constants.EVENT_CHANCE then
		return
	end
	local options = {}
	for key, e in Constants.EVENTS do
		for _, n in e.nights do
			if n == night and not run.eventsSeen[key] then
				table.insert(options, key)
			end
		end
	end
	table.sort(options)
	if #options > 0 then
		run.event = options[run.rng:NextInteger(1, #options)]
		run.eventsSeen[run.event] = true
	end
end

function RunService:_startDay(n)
	run.day = n
	run.event = nil
	self:_countStage()
	self:_setPhase("day", Constants.DAY_SECONDS[n] or 95)
	self.DayStarted:Fire(n, run)
	if n > 1 then
		Net.fireAll("Alert", `☀️ DAY {n}`, Color3.fromRGB(255, 226, 120), 3)
	end
end

function RunService:_startDusk()
	self:_setPhase("dusk", Constants.DUSK_SECONDS)
	local night = run.day
	Net.fireAll(
		"Callout",
		night >= 7 and "The seventh night is coming... something BIG is coming." or "Night is coming! Get back to camp.",
		"bad"
	)
	Net.fireAll("Sfx", "horn")
end

function RunService:LockRoster()
	if not run or run.locked then
		return
	end
	run.locked = true
	-- the difficulty: the most votes wins (a tie goes to the easier one); nobody voted: Normal
	local counts = {}
	for _, n in run.votes.difficulty do
		counts[n] = (counts[n] or 0) + 1
	end
	local best, bestN = 1, 0
	for n = 1, #Constants.DIFFICULTIES do
		if (counts[n] or 0) > bestN then
			best, bestN = n, counts[n]
		end
	end
	run.difficulty = math.min(best, self:UnlockedMax())
	self:Broadcast()
	self.RosterLocked:Fire(run)
end

function RunService:_startNight(n)
	if n == 1 then
		self:LockRoster()
	end
	run.night = n
	self:_countStage()
	if n >= 7 then
		run.event = nil
		self:_setPhase("boss", Constants.BOSS_MAX_SECONDS)
		Net.fireAll("Alert", "🌕 NIGHT 7: MEGA KERMY", Color3.fromRGB(150, 255, 120), 4)
		self.BossStarted:Fire(run)
		return
	end
	self:_rollEvent(n)
	self:_setPhase("night", Constants.NIGHT_SECONDS[n] or 100)
	local title = n == 6 and "🌙 NIGHT 6 (the 7th is coming)" or `🌙 NIGHT {n}`
	Net.fireAll("Alert", title, Color3.fromRGB(150, 180, 255), 3)
	if run.event then
		local e = Constants.EVENTS[run.event]
		Net.fireAll("Callout", `{e.name}! {e.text}`, "bad")
	end
	self.NightStarted:Fire(n, run.event, run)
end

function RunService:_dawn()
	local n = run.night
	run.nightsSurvived = math.max(run.nightsSurvived, n)
	self:_setPhase("dawn", Constants.DAWN_SECONDS)
	Net.fireAll("Alert", `You survived night {n}!`, Color3.fromRGB(255, 214, 160), 3)
	self.NightSurvived:Fire(n, run)
end

-- The run ends: won or lost, then the results, then a fresh run.
function RunService:_end(won, reason)
	if not run or run.phase == "results" then
		return
	end
	if won then
		run.nightsSurvived = 7
	end
	local result = {
		id = run.id,
		number = run.number,
		won = won,
		reason = reason,
		nights = run.nightsSurvived,
		night = run.night,
		seconds = math.floor(now() - run.startedAt),
		bossSeconds = run.phase == "boss" and math.floor(now() - run.phaseStart) or nil,
		difficulty = run.difficulty,
		roster = {},
		players = #self:Active(),
	}
	for userId, r in run.roster do
		result.roster[userId] = { name = r.name, active = r.active, joinedAt = r.joinedAt }
	end
	run.result = result
	run.won = won
	self:_setPhase("results", Constants.RESULTS_SECONDS)
	if reason ~= "empty" then
		Net.fireAll(
			"Alert",
			won and "🏆 YOU SURVIVED THE 6-7!" or "💀 THE FOREST WINS THIS TIME",
			won and Color3.fromRGB(255, 214, 80) or Color3.fromRGB(255, 120, 110),
			5
		)
		Net.fireAll("Sfx", won and "win" or "downed")
	end
	self.Ended:Fire(result)
end

function RunService:Win()
	if run and run.phase == "boss" then
		self:_end(true, "boss")
	end
end

function RunService:Wipe()
	if run and run.phase ~= "results" and run.locked then
		self:_end(false, "wipe")
	end
end

-- A new run: reset the world, put everyone in the server into the roster, day 1.
function RunService:NewRun()
	runNumber += 1
	local seed = math.floor((os.time() + runNumber * 7919) % 2147483647)
	run = {
		id = `{game.JobId ~= "" and string.sub(game.JobId, 1, 8) or "studio"}-{runNumber}`,
		number = runNumber,
		seed = seed,
		rng = Random.new(seed),
		phase = "idle",
		day = 0,
		night = 0,
		difficulty = 1,
		locked = false,
		roster = {},
		votes = { difficulty = {}, bell = {} },
		startedAt = now(),
		nightsSurvived = 0,
		eventsSeen = {},
		stagePlayers = 1,
	}
	self.Reset:Fire(run)
	local everyone = {}
	for p in waiting do
		table.insert(everyone, p)
	end
	table.clear(waiting)
	run.startedAt = now()
	self:_startDay(1)
	self.Started:Fire(run)
	for _, p in everyone do
		if p.Parent then
			self:_addToRoster(p)
		end
	end
	return run
end

function RunService:_addToRoster(player)
	local existing = run.roster[player.UserId]
	if existing then
		existing.active = true
		existing.player = player
		existing.rejoins = (existing.rejoins or 0) + 1
	else
		run.roster[player.UserId] = {
			userId = player.UserId,
			name = player.DisplayName,
			player = player,
			active = true,
			joinedAt = now(),
		}
	end
	waiting[player] = nil
	self:Broadcast()
	self.Joined:Fire(player, run)
end

-- A player is ready: into this run (day 1), or waiting for the next.
function RunService:Join(player)
	if not run or run.phase == "idle" then
		waiting[player] = true
		self:NewRun()
		return "run"
	end
	-- back after a dropped connection: your place in the roster is still yours
	local entry = run.roster[player.UserId]
	if entry and not entry.active and run.phase ~= "results" then
		self:_addToRoster(player)
		return "rejoined"
	end
	if run.phase == "results" or run.locked then
		waiting[player] = true
		Net.fire(player, "Run", self:View())
		self.Waiting:Fire(player, run)
		return "waiting"
	end
	self:_addToRoster(player)
	return "run"
end

-- Votes ------------------------------------------------------------------------------------------------------------
function RunService:Vote(player, kind, value)
	if not run or not self:InRun(player) then
		return false
	end
	if kind == "difficulty" then
		if run.locked or type(value) ~= "number" then
			return false
		end
		value = math.floor(value)
		if value < 1 or value > self:UnlockedMax() then
			Net.fire(player, "Toast", "Nobody here has unlocked that difficulty yet.", "bad")
			return false
		end
		run.votes.difficulty[player.UserId] = value
		self:Broadcast()
		self.Voted:Fire(player, kind, value)
		return true
	elseif kind == "bell" then
		if run.phase ~= "day" then
			return false
		end
		local left = self:TimeLeft() or 0
		if left < Constants.BELL_MIN_LEFT then
			return false
		end
		run.votes.bell[player.UserId] = value ~= false or nil
		self:Broadcast()
		self.Voted:Fire(player, kind, value ~= false)
		local need, have = 0, 0
		for _, p in self:Active() do
			need += 1
			if run.votes.bell[p.UserId] then
				have += 1
			end
		end
		if need > 0 and have >= need then
			Net.fireAll("Callout", "🔔 Everyone rang the bell. Here comes the night!", "info")
			self:_startDusk()
		else
			Net.fireAll("Toast", `🔔 {player.DisplayName} rang the bell ({have}/{need} ready for the night)`, "info")
		end
		return true
	end
	return false
end

-- The loop ---------------------------------------------------------------------------------------------------------
function RunService:_tick()
	if not run then
		return
	end
	-- nobody from the roster left: throw the run away (anyone waiting starts a fresh one)
	if run.phase ~= "results" and #self:Active() == 0 then
		emptySince = emptySince or now()
		if now() - emptySince >= Constants.EMPTY_ABORT then
			emptySince = nil
			self:_end(false, "empty")
		end
		return
	end
	emptySince = nil
	if not run.phaseEnds or run.phaseEnds <= 0 or now() < run.phaseEnds then
		return
	end
	local phase = run.phase
	if phase == "day" then
		self:_startDusk()
	elseif phase == "dusk" then
		self:_startNight(run.day)
	elseif phase == "night" then
		self:_dawn()
	elseif phase == "dawn" then
		self:_startDay(run.night + 1)
	elseif phase == "boss" then
		self:_end(false, "dawn")
	elseif phase == "results" then
		local anyone = false
		for _, p in Players:GetPlayers() do
			if data:Get(p) then
				anyone = true
				waiting[p] = true
			end
		end
		if anyone then
			self:NewRun()
		else
			run = nil
			table.clear(waiting)
			setAttrs()
		end
	end
end

function RunService:Init(registry)
	data = registry.PlayerDataService
	Net.on("Vote", function(player, kind, value)
		if type(kind) == "string" then
			self:Vote(player, kind, value)
		end
	end)
	setAttrs()
end

-- The standing stones (vote on the difficulty, day 1) and the camp bell (call the night early): prompts on the
-- camp's props, lit up only when they can be used.
local prompts = { stones = {} }
local function addPrompt(model, name, action, object, hold)
	local part = model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true))
	if not part then
		return nil
	end
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Parent = part
	return p
end

function RunService:_refreshPrompts()
	local day1 = run ~= nil and run.phase == "day" and run.day == 1 and not run.locked
	local unlocked = self:UnlockedMax()
	for i, p in prompts.stones do
		local d = Constants.DIFFICULTIES[i]
		p.Enabled = day1
		p.ActionText = i <= unlocked and `Vote: {d.name}` or "Locked"
		p.ObjectText = i <= unlocked and "Standing Stone" or `Win on {Constants.DIFFICULTIES[i - 1].name} to unlock`
	end
	if prompts.bell then
		prompts.bell.Enabled = run ~= nil and run.phase == "day"
	end
end

function RunService:_makePrompts()
	local map = workspace:FindFirstChild("Map")
	local campModel = map and map:FindFirstChild("Camp")
	if not campModel then
		return
	end
	for i = 1, #Constants.DIFFICULTIES do
		local stone = campModel:FindFirstChild("Stone" .. i)
		local p = addPrompt(stone, "Vote", "Vote", "Standing Stone", 0.3)
		if p then
			prompts.stones[i] = p
			p.Triggered:Connect(function(player)
				self:Vote(player, "difficulty", i)
			end)
		end
	end
	local bell = addPrompt(campModel:FindFirstChild("Bell"), "Ring", "Ring the bell", "Ready for the night", 0.5)
	if bell then
		prompts.bell = bell
		bell.Triggered:Connect(function(player)
			self:Vote(player, "bell", true)
		end)
	end
	self.PhaseChanged:Connect(function()
		self:_refreshPrompts()
	end)
	self.RosterLocked:Connect(function()
		self:_refreshPrompts()
	end)
	self:_refreshPrompts()
end

function RunService:Start()
	pcall(self._makePrompts, self)
	while true do
		task.wait(0.25)
		self:_tick()
	end
end

function RunService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		Net.fire(player, "Run", self:View())
	end)
	self:Join(player)
	self:_refreshPrompts()
end

function RunService:OnPlayerLeaving(player)
	waiting[player] = nil
	if run and run.roster[player.UserId] then
		run.roster[player.UserId].active = false
		if run.votes.difficulty[player.UserId] and not run.locked then
			run.votes.difficulty[player.UserId] = nil
		end
		run.votes.bell[player.UserId] = nil
		self.Left:Fire(player, run)
		self:Broadcast()
	end
end

-- (tests) jump the clock of the current phase so it ends now
function RunService:_skip()
	if run then
		run.phaseEnds = now()
	end
end

return RunService
