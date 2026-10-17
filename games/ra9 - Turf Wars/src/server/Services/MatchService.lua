--[[
The match (master plan §2, §3): build → fight → build → ... until a team has no turf left, then results and the
next map in the same server. No lobby, no queue.

  * Phases: "build" (BUILD_SECONDS, building open, no damage), "fight" (FIGHT_SECONDS, bows), back to "build" with
    the frontline where it was; "victory" (the results) and "loading" (the next map) between matches.
  * The frontline is the server's number (X along the field). Each valid kill (opposing teams, the fight phase, a
    real attacker) moves it Formulas.pushCells(players) cells toward the victim's base (plus MatchService.bonusCells
    (killer), a hook: TutorialService's first-match boost). When it reaches a team's
    lose line (the edge of its spawn zone), that team is out.
  * Turf Wars' rule: you can't stand on enemy turf. Step over the line and you're put back on your side.
  * Players join straight into the running match (TeamService picks the side), spawn on their pads with a moment
    of protection, and respawn RESPAWN_SECONDS after going down.
  * A kill plane below the map; a watchdog that restarts a match running absurdly long (logged, never "won").

Workspace attributes the clients read: Phase, PhaseEnds, Frontline, LoseRed, LoseBlue, MatchId, MapKey, MapName.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local MatchService = {
	Name = "MatchService",
	Dependencies = {
		"PlayerDataService",
		"TeamService",
		"ArenaService",
		"CombatService",
		"BuildService",
		"ProgressService",
	},
	PhaseChanged = Signal.new("MatchService.PhaseChanged"), -- (phase, old)
	Pushed = Signal.new("MatchService.Pushed"), -- (frontline, byTeam, killer, victim)
	Ended = Signal.new("MatchService.Ended"), -- (winner, results)
	Started = Signal.new("MatchService.Started"), -- (mapKey, matchId)
}

local data, teams, arena, combat, build, progress
local phase = "loading"
local phaseEnds = 0
local frontline = 0
local matchId = 0
local matchStart = 0
local mapKey
local LONGSHOT = 90
local TRIPLE_SECONDS = 6
local closest = {} -- [team] = the least share of the way to their losing line they've had left this match
local stats = {} -- [player] = { joined, kills, deaths, assists, built, shots, hits, headshots, pushed, active }
local respawnAt = {} -- [player] = time
local pending = {} -- [player] = true: waiting for the next match to spawn
local random = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function statsOf(player)
	local s = stats[player]
	if not s then
		s = {
			joined = now(),
			kills = 0,
			deaths = 0,
			assists = 0,
			built = 0,
			shots = 0,
			hits = 0,
			headshots = 0,
			pushed = 0,
			longshots = 0, -- kills from LONGSHOT studs or more (a goal)
			triples = 0, -- 3 kills within TRIPLE_SECONDS (a goal)
			recent = {}, -- (the times of your last kills)
		}
		stats[player] = s
	end
	return s
end

function MatchService:Phase()
	return phase
end

function MatchService:Frontline()
	return frontline
end

function MatchService:Stats(player)
	return statsOf(player)
end

function MatchService:Snapshot()
	local m = Maps.get(mapKey)
	return {
		phase = phase,
		ends = phaseEnds,
		map = mapKey,
		mapName = m and m.name,
		tagline = m and m.tagline,
		frontline = frontline,
		loseRed = arena:LoseLine("red"),
		loseBlue = arena:LoseLine("blue"),
		push = Formulas.pushCells(#self:Everyone()) * Constants.CELL,
		red = teams:Count("red"),
		blue = teams:Count("blue"),
		matchId = matchId,
		winner = workspace:GetAttribute("Winner"),
	}
end

function MatchService:Broadcast()
	workspace:SetAttribute("Phase", phase)
	workspace:SetAttribute("PhaseEnds", phaseEnds)
	workspace:SetAttribute("Frontline", frontline)
	workspace:SetAttribute("MatchId", matchId)
	workspace:SetAttribute("LoseRed", arena:LoseLine("red"))
	workspace:SetAttribute("LoseBlue", arena:LoseLine("blue"))
	Net.fireAll("Match", self:Snapshot())
end

local function setPhase(new, seconds)
	local old = phase
	phase = new
	phaseEnds = now() + (seconds or 0)
	combat:SetEnabled(new == "fight")
	build:SetOpen(new == "build")
	MatchService:Broadcast()
	MatchService.PhaseChanged:Fire(new, old)
end

-- Spawning -----------------------------------------------------------------------------------------------------
-- Everyone in the match: the players, and BotService's bots when there are any (it sets MatchService.extras).
MatchService.extras = function()
	return {}
end
function MatchService:Everyone()
	local list = Players:GetPlayers()
	for _, b in self.extras() do
		table.insert(list, b)
	end
	return list
end
-- A one-shot spawn point for a player (BotService: the second player takes over a bot where it stood).
MatchService.SpawnAt = {}
-- Extra cells a kill by this player moves the line (TutorialService: a new player's first match, alone).
MatchService.bonusCells = function(_killer)
	return 0
end

function MatchService:Spawn(player)
	local team = teams:Team(player) or teams:Assign(player)
	respawnAt[player] = nil
	pending[player] = nil
	player:LoadCharacter()
	local c = player.Character
	if not c then
		return
	end
	local cf = self.SpawnAt[player] or arena:SpawnFor(team)
	self.SpawnAt[player] = nil
	local r = c:FindFirstChild("HumanoidRootPart")
	if r then
		r.CFrame = cf
	end
	player:SetAttribute("AcGrace", os.clock() + 2) -- (our teleport: the anti-cheat lets it go)
	teams:Dress(c, team)
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Constants.WALK_SPEED
		hum.BreakJointsOnDeath = false
		hum.Died:Connect(function()
			-- (Roblox killed it anyway: the menu's Reset, a glitch) the same as going down, no credit
			if player.Character == c and combat:Alive(player) then
				combat:Kill(player, nil, { kind = "reset" })
			end
		end)
	end
	combat:Spawned(player)
end

function MatchService:_onKilled(victim, killer, info)
	local vs = statsOf(victim)
	vs.deaths += 1
	local valid = phase == "fight"
		and killer ~= nil
		and killer ~= victim
		and killer.Parent ~= nil
		and teams:Team(killer) ~= nil
		and teams:Team(killer) ~= teams:Team(victim)
	local push = 0
	if valid then
		local ks = statsOf(killer)
		ks.kills += 1
		if info.head then
			ks.headshots += 1
		end
		for _, a in info.assists or {} do
			if teams:Team(a) == teams:Team(killer) then
				statsOf(a).assists += 1
			end
		end
		-- the goals' feats: a long shot, three kills in a few seconds
		local kr, vr = killer.Character, victim.Character
		kr = kr and kr:FindFirstChild("HumanoidRootPart")
		vr = vr and vr:FindFirstChild("HumanoidRootPart")
		if kr and vr and (kr.Position - vr.Position).Magnitude >= LONGSHOT then
			ks.longshots += 1
		end
		local t = now()
		table.insert(ks.recent, t)
		while #ks.recent > 0 and t - ks.recent[1] > TRIPLE_SECONDS do
			table.remove(ks.recent, 1)
		end
		if #ks.recent >= 3 then
			ks.triples += 1
			ks.recent = {}
		end
		local cells = Formulas.pushCells(#self:Everyone()) + (self.bonusCells(killer) or 0)
		push = cells * Constants.CELL
		ks.pushed += cells
		local team = teams:Team(killer)
		frontline = math.clamp(frontline + Formulas.forward(team) * push, arena:LoseLine("red"), arena:LoseLine("blue"))
		arena:Paint(frontline)
		-- how close each side has come to losing (a win from 25% or less is a comeback)
		local lr, lb = arena:LoseLine("red"), arena:LoseLine("blue")
		closest.red = math.min(closest.red or 1, lr ~= 0 and (frontline - lr) / (0 - lr) or 1)
		closest.blue = math.min(closest.blue or 1, lb ~= 0 and (lb - frontline) / lb or 1)
		self.Pushed:Fire(frontline, team, killer, victim)
	end
	local vroot = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
	local kp = killer and data:Get(killer)
	Net.fireAll("Kill", {
		effect = valid and kp and kp.equipped.effect or nil, -- (the killer's kill effect, drawn where you fell)
		pos = vroot and vroot.Position or nil,
		killer = killer and killer.UserId,
		killerName = killer and killer.DisplayName,
		killerTeam = killer and teams:Team(killer),
		victim = victim.UserId,
		victimName = victim.DisplayName,
		victimTeam = teams:Team(victim),
		weapon = info.weapon,
		head = info.head,
		push = push,
		kind = info.kind,
		frontline = frontline,
	})
	if valid then
		self:Broadcast()
		if frontline >= arena:LoseLine("blue") then
			self:Victory("red")
			return
		elseif frontline <= arena:LoseLine("red") then
			self:Victory("blue")
			return
		end
	end
	if phase ~= "victory" and phase ~= "loading" then
		respawnAt[victim] = now() + Constants.RESPAWN_SECONDS
	else
		pending[victim] = true
	end
end

-- The match's end ----------------------------------------------------------------------------------------------
function MatchService:Results(winner)
	local rows = {}
	local best, bestScore
	for _, p in Players:GetPlayers() do
		local s = statsOf(p)
		local row = {
			userId = p.UserId,
			name = p.DisplayName,
			team = teams:Team(p),
			kills = s.kills,
			deaths = s.deaths,
			assists = s.assists,
			built = s.built,
			pushed = s.pushed,
		}
		table.insert(rows, row)
		local score = Formulas.mvpScore(s)
		if score > 0 and (not bestScore or score > bestScore) then
			best, bestScore = p, score
		end
	end
	table.sort(rows, function(a, b)
		return Formulas.mvpScore(a) > Formulas.mvpScore(b)
	end)
	return { winner = winner, rows = rows, mvp = best and best.UserId or nil, mvpPlayer = best }
end

function MatchService:Victory(winner)
	if phase == "victory" or phase == "loading" then
		return
	end
	local results = self:Results(winner)
	workspace:SetAttribute("Winner", winner) -- (the clients' fireworks, and anyone joining during the countdown)
	setPhase("victory", Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS)
	local nextMap = Maps.next(mapKey, function(a, b)
		return random:NextInteger(a, b)
	end)
	self._nextMap = nextMap.key
	local t = now()
	for _, p in Players:GetPlayers() do
		local s = statsOf(p)
		local team = teams:Team(p)
		local info = {
			won = team ~= nil and team == winner,
			seconds = t - math.max(s.joined, matchStart),
			active = (s.shots + s.built + s.kills + s.assists) > 0,
			mvp = results.mvpPlayer == p,
			comeback = team ~= nil and team == winner and (closest[team] or 1) <= 0.25,
		}
		for k, v in s do
			if type(v) == "number" and k ~= "joined" then
				info[k] = v
			end
		end
		if team == nil then
			info.won = nil
		end
		local step, earned = progress:Award(p, info)
		Net.fire(p, "Results", {
			winner = winner,
			rows = results.rows,
			mvp = results.mvp,
			you = { team = team, won = info.won, qualified = Formulas.qualifies(info), step = step, earned = earned },
			next = { key = nextMap.key, name = nextMap.name, tagline = nextMap.tagline },
		})
	end
	-- (no centre alert here: the results card says who won, and nothing else lands on top of it)
	self.Ended:Fire(winner, results)
	task.delay(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS, function()
		self:NewMatch(self._nextMap)
	end)
end

function MatchService:NewMatch(key)
	workspace:SetAttribute("Winner", nil)
	setPhase("loading", 1)
	build:Clear()
	mapKey = key or mapKey or Maps.list[1].key
	arena:Load(mapKey)
	frontline = 0
	arena:Paint(frontline)
	teams:Rebalance()
	matchId += 1
	matchStart = now()
	stats = {}
	closest = {}
	respawnAt, pending = {}, {}
	self.SpawnAt = {}
	for _, p in self:Everyone() do
		statsOf(p)
		if teams:Team(p) then
			self:Spawn(p)
		end
	end
	build:Refill()
	setPhase("build", Constants.BUILD_SECONDS)
	Net.fireAll("Alert", "BUILD", Color3.fromRGB(40, 40, 46), 2)
	self.Started:Fire(mapKey, matchId)
end

-- The clock ----------------------------------------------------------------------------------------------------
function MatchService:_tick()
	local t = now()
	if phase == "build" and t >= phaseEnds then
		setPhase("fight", Constants.FIGHT_SECONDS)
		Net.fireAll("Alert", "FIGHT!", Color3.fromRGB(30, 30, 34), 1.5)
		Net.fireAll("Sfx", "horn")
	elseif phase == "fight" and t >= phaseEnds then
		build:Refill()
		setPhase("build", Constants.BUILD_SECONDS)
		Net.fireAll("Alert", "BUILD", Color3.fromRGB(40, 40, 46), 1.5)
	end
	if (phase == "build" or phase == "fight") and t - matchStart > Constants.WATCHDOG_SECONDS then
		warn(`[MatchService] match {matchId} ran {math.floor(t - matchStart)} s: restarting (no winner)`)
		self:NewMatch(Maps.next(mapKey).key)
		return
	end
	for player, at in respawnAt do
		if t >= at and player.Parent then
			self:Spawn(player)
		end
	end
	-- the turf rule, and the kill plane
	if phase == "build" or phase == "fight" then
		for _, player in self:Everyone() do
			local team = teams:Team(player)
			local c = player.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if team and r and combat:Alive(player) then
				local x = r.Position.X
				if r.Position.Y < -20 then
					combat:Kill(player, nil, { kind = "fall" })
				elseif team == "red" and x > frontline + Constants.TURF_MARGIN then
					r.CFrame = CFrame.new(frontline - 3, r.Position.Y + 0.5, r.Position.Z) * r.CFrame.Rotation
					player:SetAttribute("AcGrace", os.clock() + 1)
					pcall(function()
						r.AssemblyLinearVelocity = Vector3.new(-20, 10, 0)
					end)
				elseif team == "blue" and x < frontline - Constants.TURF_MARGIN then
					r.CFrame = CFrame.new(frontline + 3, r.Position.Y + 0.5, r.Position.Z) * r.CFrame.Rotation
					player:SetAttribute("AcGrace", os.clock() + 1)
					pcall(function()
						r.AssemblyLinearVelocity = Vector3.new(20, 10, 0)
					end)
				end
			end
		end
	end
end

function MatchService:Init(registry)
	data = registry.PlayerDataService
	teams = registry.TeamService
	arena = registry.ArenaService
	combat = registry.CombatService
	build = registry.BuildService
	progress = registry.ProgressService
	build:SetFrontline(function()
		return frontline
	end)
	teams:SetTurfLeader(function()
		if frontline > 0 then
			return "red"
		elseif frontline < 0 then
			return "blue"
		end
		return nil
	end)
	combat.Killed:Connect(function(victim, killer, info)
		self:_onKilled(victim, killer, info)
	end)
	combat.Shot:Connect(function(player)
		statsOf(player).shots += 1
	end)
	combat.Damaged:Connect(function(_, _, attacker)
		if attacker then
			statsOf(attacker).hits += 1
		end
	end)
	build.Built:Connect(function(player)
		statsOf(player).built += 1
	end)
	Players.PlayerRemoving:Connect(function(player)
		stats[player] = nil
		respawnAt[player] = nil
		pending[player] = nil
	end)
end

function MatchService:OnPlayerReady(player)
	if not teams:Team(player) then
		teams:Assign(player) -- (BotService may already have given them a bot's team)
	end
	statsOf(player)
	if phase == "victory" or phase == "loading" then
		pending[player] = true
	else
		self:Spawn(player)
	end
	data:WhenClientReady(player, function()
		Net.fire(player, "Match", self:Snapshot())
		combat:Push(player)
		build:Push(player)
		if phase == "fight" then
			Net.fire(player, "Toast", "The fight is on: shoot across the line to push it back!", "info")
		elseif phase == "build" then
			Net.fire(player, "Toast", "Build defences on your side, then fight!", "info")
		end
	end)
	self:Broadcast()
end

function MatchService:Start()
	self:NewMatch(Maps.list[1].key)
	while true do
		task.wait(0.2)
		self:_tick()
	end
end

-- (tests)
function MatchService:_setFrontline(x)
	frontline = x
	arena:Paint(frontline)
	self:Broadcast()
end
function MatchService:_setPhase(p, seconds)
	setPhase(p, seconds)
end

return MatchService
