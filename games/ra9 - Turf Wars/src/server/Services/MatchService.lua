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
  * A spectating admin (server/Admins.lua) is in the server but not in the match: People() and Everyone() leave
    them out, so they get no team, no body, no stats, no row in the results.

  MatchService:People() / :Everyone()   the real players / plus the bots
  MatchService:Join(player) / :Leave(player)   into the match / out of it (an admin starting to spectate)
  MatchService:Victory(winner)          "red" | "blue" | "draw"
  MatchService:NewMatch(mapKey?, size?) a new match; the arena's size is picked from everyone in it now (players
                                        and bots; size: a count or a tier's name instead). It only changes here.
  MatchService:SkipTo("fight" | "build" | "charge")   MatchService:Freeze(on)
  MatchService:Charging() -> bool       the CHARGE: the fight's last CHARGE_SECONDS, when the line is open to
                                        everyone and the blade comes out (workspace "Charge" says so to the clients)

Workspace attributes the clients read: Phase, PhaseEnds, Charge, Frontline, LoseRed, LoseBlue, MatchId, MapKey, MapName.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Notify = require(script.Parent.Parent.Notify)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Admins = require(script.Parent.Parent.Admins)

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
	ChargeChanged = Signal.new("MatchService.ChargeChanged"), -- (on) the CHARGE began or ended
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
local frozen -- seconds left on the clock while an admin holds it (nil: running)
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
		size = arena:Current() and arena:Current().tier,
		width = arena:Current() and arena:Current().width,
		push = Formulas.pushCells(#self:Everyone()) * Constants.CELL,
		red = teams:Count("red"),
		blue = teams:Count("blue"),
		matchId = matchId,
		winner = workspace:GetAttribute("Winner"),
		frozen = frozen ~= nil,
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
	MatchService:_charge()
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
-- The real people in the match: every player but a spectating admin (server/Admins.lua).
function MatchService:People()
	local list = {}
	for _, p in Players:GetPlayers() do
		if not Admins.spectating(p) then
			table.insert(list, p)
		end
	end
	return list
end
function MatchService:Everyone()
	local list = self:People()
	for _, b in self.extras() do
		table.insert(list, b)
	end
	return list
end
-- The plain body: Roblox's plain R15 shape at the standard size (no packages, no clothes). Bots wear it, and so does
-- anyone whose avatar can't be loaded (Studio's test players, a Roblox hiccup).
local uniformBody
local function sameBody()
	if uniformBody then
		return uniformBody
	end
	local ok, d = pcall(function()
		local desc = Instance.new("HumanoidDescription")
		for _, k in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
			desc[k] = 0 -- (0: the plain R15 part)
		end
		desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
		desc.BodyTypeScale, desc.ProportionScale = 0, 0
		desc.Shirt, desc.Pants, desc.GraphicTShirt = 0, 0, 0
		return desc
	end)
	uniformBody = ok and d or nil
	return uniformBody
end
MatchService.sameBody = sameBody

-- A player's own avatar (their skin tone, face, clothes, accessories, body parts), at the standard size whatever
-- their scaling is, so nobody is a bigger or smaller target. Asked of Roblox once per player and kept.
local avatars = {} -- [userId] = HumanoidDescription | false
local function ownBody(player)
	local id = player.UserId
	if type(id) ~= "number" or id <= 0 then
		return nil
	end
	if avatars[id] == nil then
		local ok, d = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(id)
		end)
		if ok and d then
			pcall(function()
				d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = 1, 1, 1, 1
				d.BodyTypeScale, d.ProportionScale = 0, 0
			end)
			avatars[id] = d
		else
			avatars[id] = false
		end
	end
	return avatars[id] or nil
end
MatchService.ownBody = ownBody

-- Keep the build phase going at least `seconds` from now (TutorialService: a new player's first build, which their
-- intro would otherwise eat). Only while building; true when it moved the clock.
function MatchService:HoldBuild(seconds)
	if phase ~= "build" or frozen then
		return false
	end
	local want = now() + seconds
	if want <= phaseEnds then
		return false
	end
	phaseEnds = want
	workspace:SetAttribute("PhaseEnds", phaseEnds)
	self:Broadcast()
	return true
end

-- A one-shot spawn point for a player (BotService: the second player takes over a bot where it stood).
MatchService.SpawnAt = {}
-- Extra cells a kill by this player moves the line (TutorialService: a new player's first match, alone).
MatchService.bonusCells = function(_killer)
	return 0
end

function MatchService:Spawn(player)
	if Admins.spectating(player) then
		respawnAt[player], pending[player] = nil, nil
		return -- (watching unseen: no body)
	end
	local team = teams:Team(player) or teams:Assign(player)
	respawnAt[player] = nil
	pending[player] = nil
	local desc = ownBody(player) or sameBody()
	local loaded = desc and pcall(function()
		player:LoadCharacterWithHumanoidDescription(desc)
	end)
	-- (gone while it loaded: nothing to do; LoadCharacter would throw on a player who left)
	if not player.Parent then
		return
	end
	if not loaded then
		pcall(function()
			player:LoadCharacter()
		end)
	end
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
		arena:Paint(frontline, team)
		build:ClearLost(frontline) -- (the losing side's walls on the turf it just lost come down)
		-- how close each side has come to losing (a win from 25% or less is a comeback)
		local lr, lb = arena:LoseLine("red"), arena:LoseLine("blue")
		closest.red = math.min(closest.red or 1, lr ~= 0 and (frontline - lr) / (0 - lr) or 1)
		closest.blue = math.min(closest.blue or 1, lb ~= 0 and (lb - frontline) / lb or 1)
		self.Pushed:Fire(frontline, team, killer, victim)
	end
	local vroot = victim.Character and victim.Character:FindFirstChild("HumanoidRootPart")
	local kp = killer and data:Get(killer)
	-- (the victim's kill cam: where the killer stood, how far, and the arrow's flight when it was one)
	local kc = killer and killer.Character
	local kroot = kc and kc:FindFirstChild("HumanoidRootPart")
	local killerPos = kroot and kroot.Position or nil
	Net.fireAll("Kill", {
		killerPos = killerPos,
		dist = killerPos and vroot and math.floor((killerPos - vroot.Position).Magnitude + 0.5) or nil,
		cam = info.cam,
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
	if phase ~= "loading" then
		-- (in the victory wait too: nobody is stuck dead on the results; they're back up to run about)
		respawnAt[victim] = now() + Constants.RESPAWN_SECONDS
	else
		pending[victim] = true
	end
end

-- The match's end ----------------------------------------------------------------------------------------------
function MatchService:Results(winner)
	local rows = {}
	local best, bestScore
	for _, p in self:People() do
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

-- winner: "red" | "blue" | "draw" (an admin's call: nobody wins or loses)
function MatchService:Victory(winner)
	if phase == "victory" or phase == "loading" then
		return false
	end
	frozen = nil
	local results = self:Results(winner)
	workspace:SetAttribute("Winner", winner) -- (the clients' fireworks, and anyone joining during the countdown)
	setPhase("victory", Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS)
	-- anyone down when it ended (the last kill's victim too) gets back up for the wait: nobody is stuck dead
	for _, p in self:Everyone() do
		if not combat:Alive(p) and not respawnAt[p] then
			respawnAt[p] = now() + Constants.RESPAWN_SECONDS
		end
	end
	local nextMap = Maps.next(mapKey, function(a, b)
		return random:NextInteger(a, b)
	end)
	self._nextMap = nextMap.key
	local t = now()
	for _, p in self:People() do
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
		if team == nil or winner == "draw" then
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
	-- (no centre alert here: the results card says who won; a banner for everyone says it too, and who was MVP)
	local winName = winner == "red" and "Red" or (winner == "blue" and "Blue" or nil)
	if winName then
		Notify.all(`{winName} team wins!`, "win", { color = Constants.TEAM_COLOR[winner] })
	else
		Notify.all("It's a draw!", "win")
	end
	if results.mvpPlayer then
		Notify.all(`{results.mvpPlayer.DisplayName} is MVP!`, "status", { icon = "👑" })
	end
	self.Ended:Fire(winner, results)
	local ended = matchId
	task.delay(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS, function()
		if matchId == ended then -- (unless an admin already started a new one)
			self:NewMatch(self._nextMap)
		end
	end)
	return true
end

function MatchService:NewMatch(key, size)
	frozen = nil
	workspace:SetAttribute("Frozen", nil)
	workspace:SetAttribute("Winner", nil)
	setPhase("loading", 1)
	build:Clear()
	mapKey = key or mapKey or Maps.list[1].key
	-- (the arena's size: how many are in the match as it starts; people joining or leaving later wait for the next)
	arena:Load(mapKey, size or #self:Everyone())
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
			-- (each in its own thread: a character takes a moment to load live, and 40 in a row would hold the match)
			task.spawn(function()
				local ok, err = pcall(self.Spawn, self, p)
				if not ok then
					warn("[MatchService] spawn failed: " .. tostring(err))
				end
			end)
		end
	end
	build:Refill()
	setPhase("build", Constants.BUILD_SECONDS)
	Net.fireAll("Alert", "BUILD", Color3.fromRGB(40, 40, 46), 2)
	local def = Maps.get(mapKey)
	Notify.all(`New game: {def and def.name or mapKey}`, "start", { icon = "⚔️" })
	self.Started:Fire(mapKey, matchId)
end

-- The CHARGE: the fight's last seconds. The line opens (the turf rule is off), the blade comes out, and everyone
-- may run across. When it's over, anyone still on the other side goes home (a fresh spawn on their own side).
function MatchService:Charging()
	return workspace:GetAttribute("Charge") == true
end

function MatchService:_charge()
	local on = phase == "fight" and phaseEnds - now() <= Constants.CHARGE_SECONDS
	if on == self:Charging() then
		return
	end
	workspace:SetAttribute("Charge", on or nil)
	if on then
		Net.fireAll("Alert", "CHARGE!", Color3.fromRGB(30, 30, 34), 1.8)
		Net.fireAll("Sfx", "horn")
		Notify.all("CHARGE! Cross the line, blades out!", "start", { icon = "⚔️", seconds = 4 })
	elseif phase == "build" then
		for _, player in self:Everyone() do
			local team = teams:Team(player)
			local c = player.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local fwd = team and Formulas.forward(team)
			if r and fwd and combat:Alive(player) and (r.Position.X - frontline) * fwd > 0 then
				task.spawn(function()
					pcall(self.Spawn, self, player)
				end)
			end
		end
	end
	self.ChargeChanged:Fire(on)
end

-- The clock ----------------------------------------------------------------------------------------------------
function MatchService:_tick()
	local t = now()
	if frozen then
		-- (held: the clock stays where it was, told to everyone about once a second)
		phaseEnds = t + frozen
		if t - (self._frozenSent or 0) >= 1 then
			self._frozenSent = t
			self:Broadcast()
		end
	elseif phase == "build" and t >= phaseEnds then
		setPhase("fight", Constants.FIGHT_SECONDS)
		Net.fireAll("Alert", "FIGHT!", Color3.fromRGB(30, 30, 34), 1.5)
		Net.fireAll("Sfx", "horn")
	elseif phase == "fight" and t >= phaseEnds then
		build:Refill()
		setPhase("build", Constants.BUILD_SECONDS)
		Net.fireAll("Alert", "BUILD", Color3.fromRGB(40, 40, 46), 1.5)
	end
	self:_charge()
	if (phase == "build" or phase == "fight") and not frozen and t - matchStart > Constants.WATCHDOG_SECONDS then
		warn(`[MatchService] match {matchId} ran {math.floor(t - matchStart)} s: restarting (no winner)`)
		self:NewMatch(Maps.next(mapKey).key)
		return
	end
	local due = {}
	for player, at in respawnAt do
		if t >= at and player.Parent then
			table.insert(due, player)
		end
	end
	for _, player in due do
		respawnAt[player] = nil
		task.spawn(function()
			local ok, err = pcall(self.Spawn, self, player)
			if not ok then
				warn("[MatchService] respawn failed: " .. tostring(err))
			end
		end)
	end
	-- the turf rule, and the kill plane
	if phase == "build" or phase == "fight" then
		for _, player in self:Everyone() do
			local team = teams:Team(player)
			local c = player.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if team and r and combat:Alive(player) and not self:Charging() then
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

-- Into the match: a team (unless BotService already gave them a bot's), then a body now or at the next match.
function MatchService:Join(player)
	if Admins.spectating(player) then
		return false
	end
	if not teams:Team(player) then
		teams:Assign(player)
	end
	statsOf(player)
	if phase == "loading" then
		pending[player] = true
	else
		self:Spawn(player)
	end
	self:Broadcast()
	return true
end

-- Out of the match, still in the server (an admin starting to spectate): no stats, no respawn, no body.
function MatchService:Leave(player)
	stats[player] = nil
	respawnAt[player] = nil
	pending[player] = nil
	self.SpawnAt[player] = nil
	self:Broadcast()
end

-- Admin controls (AdminService) ---------------------------------------------------------------------------------
-- End the phase now: "fight" from the build phase, "build" from the fight. Returns ok.
function MatchService:SkipTo(target)
	if target == "charge" then
		-- (straight to the fight's last seconds)
		if frozen or (phase ~= "fight" and not self:SkipTo("fight")) then
			return false
		end
		phaseEnds = math.min(phaseEnds, now() + Constants.CHARGE_SECONDS - 0.05)
		self:_tick()
		return self:Charging()
	end
	if frozen or (target ~= "fight" and target ~= "build") or phase == target then
		return false
	end
	if phase ~= "build" and phase ~= "fight" then
		return false
	end
	phaseEnds = now()
	self:_tick()
	return true
end

-- Hold the clock (on) or let it run again.
function MatchService:Freeze(on)
	if on and not frozen and (phase == "build" or phase == "fight") then
		frozen = math.max(1, phaseEnds - now())
	elseif not on and frozen then
		phaseEnds = now() + frozen
		frozen = nil
	else
		return false
	end
	workspace:SetAttribute("Frozen", frozen ~= nil or nil)
	self:Broadcast()
	return true
end

function MatchService:Frozen()
	return frozen ~= nil
end

function MatchService:MapKey()
	return mapKey
end

-- Someone new: a small chip for everyone else, "joined your team!" for their side, "a new enemy!" for the other
function MatchService:AnnounceJoin(player)
	local team = teams:Team(player)
	if not team or Admins.spectating(player) then
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and teams:Team(other) then
			local same = teams:Team(other) == team
			Notify.to(
				other,
				same and `{player.DisplayName} joined your team!`
					or `{player.DisplayName} joined {Constants.TEAM_NAME[team]}: new enemy!`,
				"join",
				{ color = Constants.TEAM_COLOR[team], icon = same and "🎉" or "⚔️", ally = same }
			)
		end
	end
end

function MatchService:OnPlayerReady(player)
	self:Join(player)
	self:AnnounceJoin(player)
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
		-- (one bad tick never stops the clock for good)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[MatchService] tick failed: " .. tostring(err))
		end
	end
end

-- (tests)
function MatchService:_setFrontline(x)
	frontline = x
	arena:Paint(frontline)
	build:ClearLost(frontline)
	self:Broadcast()
end
function MatchService:_setPhase(p, seconds)
	setPhase(p, seconds)
end

return MatchService
