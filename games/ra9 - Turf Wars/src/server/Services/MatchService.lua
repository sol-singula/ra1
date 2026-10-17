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
    of protection, and respawn RESPAWN_SECONDS after going down (beside their team's Rally Banner while one
    stands: BuildService:RallySpawn).
  * A kill plane below the map; a watchdog that restarts a match running absurdly long (logged, never "won").
  * A spectating admin (server/Admins.lua) is in the server but not in the match: People() and Everyone() leave
    them out, so they get no team, no body, no stats, no row in the results.
  * The mode (Constants.MODE) picks the rules (Rules, below): Turf Wars as above, or Capture the Flag (CtfService
    holds the flags, the scores and the READY queue): the line stays at the middle (your half is your turf in the
    build phase), the whole fight is open with blades out (the CHARGE from the first second, no call), kills push
    nothing, one fight (CTF.FIGHT_SECONDS) to CTF.CAPTURES_TO_WIN captures or the most when it ends, a tie into
    sudden death (one more minute, the first capture wins) and then a draw; and the match only starts when enough
    players are READY: until then "waiting", everyone on their decks with the arena up.

  MatchService:People() / :Everyone()   the real players / plus the bots
  MatchService:Join(player) / :Leave(player)   into the match / out of it (an admin starting to spectate)
  MatchService:Victory(winner)          "red" | "blue" | "draw"
  MatchService:NewMatch(mapKey?, size?) a new match; the arena's size is picked from everyone in it now (players
                                        and bots; size: a count or a tier's name instead). It only changes here.
  MatchService:SkipTo("fight" | "build" | "charge")   MatchService:Freeze(on)
  MatchService:Charging() -> bool       the CHARGE: the fight's last CHARGE_SECONDS, when the line is open to
                                        everyone and the blade comes out (workspace "Charge" says so to the clients)
  MatchService:SuddenDeath() -> bool    (Capture the Flag) the tie-breaker minute is on
  MatchService.rules                    the match's rules, as Turf Wars plays them; a mode (BrawlService) changes
                                        them before the first match: push (kills move the line and win), turf (no
                                        standing on enemy turf), tips (the joining toasts), phaseSeconds(phase) ->
                                        seconds or nil (how long a build or fight lasts), respawn(victim, seconds)
                                        -> seconds or false (no respawn at all). Capture the Flag's own rules are
                                        the Rules table below, keyed by Constants.MODE.

Workspace attributes the clients read: Phase, PhaseEnds, Charge, Frontline, LoseRed, LoseBlue, MatchId, MapKey, MapName,
Mode.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Net = require(ReplicatedStorage.Shared.Net)
local Notify = require(script.Parent.Parent.Notify)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Admins = require(script.Parent.Parent.Admins)

local MatchService = {
	Name = "MatchService",
	Modes = { "turf", "ctf", "brawl" }, -- (a match's: never in the lobby)
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

local data, teams, arena, combat, build, progress, economy
local ctf -- CtfService (Capture the Flag's flags, scores and queue), when the build has it
local phase = "loading"
local phaseEnds = 0
local frontline = 0
local sudden = false -- (Capture the Flag: the fight ended in a tie and its last minute is on)
local matchId = 0
local matchStart = 0
local mapKey
local LONGSHOT = 90
local TRIPLE_SECONDS = 6
local closest = {} -- [team] = the least share of the way to their losing line they've had left this match
local stats = {} -- [player] = { joined, kills, deaths, assists, built, shots, hits, headshots, pushed, active }
local respawnAt = {} -- [player] = time
local spawning = {} -- [player] = when a body started loading (the watchdog waits for it)
local stuckAt = {} -- [player] = since when they've had no body and nothing coming (the watchdog)
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

function MatchService:SuddenDeath()
	return sudden
end

function MatchService:Snapshot()
	local m = Maps.get(mapKey)
	return {
		mode = Constants.MODE,
		phase = phase,
		ends = phaseEnds,
		sudden = sudden or nil,
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
	workspace:SetAttribute("Mode", Constants.MODE)
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

-- The rules (see the header): Turf Wars' own unless a mode changes them
MatchService.rules = { push = true, turf = true, tips = true, phaseSeconds = nil, respawn = nil }

-- How long a phase lasts: the mode's say, else the constants
local function phaseSeconds(which)
	local r = MatchService.rules
	local s = r.phaseSeconds and r.phaseSeconds(which)
	return s or (which == "fight" and Constants.FIGHT_SECONDS or Constants.BUILD_SECONDS)
end

-- The rules by mode (Constants.MODE): what Turf Wars and Capture the Flag do differently. Everything else (the
-- phases and their clocks, spawning, kills and their Shards, the results and the rewards, the watchdog) is the
-- same match. A mode without rules of its own plays Turf Wars'.
local Rules = {}
local function rules()
	return Rules[Constants.MODE] or Rules.turf
end
-- Turf Wars: the line, pushed by kills; the CHARGE at the fight's end; build, fight, build again until a side is out
Rules.turf = {
	-- the line is open (and the blade out) in the CHARGE: the fight's last CHARGE_SECONDS
	lineOpen = function()
		return phase == "fight" and phaseEnds - now() <= Constants.CHARGE_SECONDS
	end,
	chargeCall = true, -- (CHARGE! when it opens; anyone over the line goes home when it closes)
	fightSeconds = function()
		return phaseSeconds("fight")
	end,
	-- a valid kill moves the line toward the victim's base; returns the push in studs
	onKill = function(killer, victim, ks)
		local cells = Formulas.pushCells(#MatchService:Everyone()) + (MatchService.bonusCells(killer) or 0)
		local push = cells * Constants.CELL
		ks.pushed += cells
		local team = teams:Team(killer)
		frontline = math.clamp(frontline + Formulas.forward(team) * push, arena:LoseLine("red"), arena:LoseLine("blue"))
		arena:Paint(frontline, team)
		build:ClearLost(frontline) -- (the losing side's walls on the turf it just lost come down)
		-- how close each side has come to losing (a win from 25% or less is a comeback)
		local lr, lb = arena:LoseLine("red"), arena:LoseLine("blue")
		closest.red = math.min(closest.red or 1, lr ~= 0 and (frontline - lr) / (0 - lr) or 1)
		closest.blue = math.min(closest.blue or 1, lb ~= 0 and (lb - frontline) / lb or 1)
		MatchService.Pushed:Fire(frontline, team, killer, victim)
		return push
	end,
	-- the fight's clock ran out: back to building, the line where it is
	fightOver = function()
		build:Refill()
		setPhase("build", phaseSeconds("build"))
		Net.fireAll("Alert", "BUILD", Color3.fromRGB(40, 40, 46), 1.5)
	end,
	-- the side ahead (TeamService rule 2 sends a solo joiner to the other one)
	leader = function()
		if frontline > 0 then
			return "red"
		elseif frontline < 0 then
			return "blue"
		end
		return nil
	end,
	ready = function()
		return true -- (a match starts as soon as its map is up)
	end,
	score = Formulas.mvpScore, -- (the MVP, and the results' order)
	row = function(_row, _stats) end, -- (nothing more on a results row)
	-- someone tried to cross the line: when they'll be able to (the CHARGE)
	crossText = function(t)
		local wait = phaseEnds - t - Constants.CHARGE_SECONDS
		if phase == "build" then
			wait = (phaseEnds - t) + Constants.FIGHT_SECONDS - Constants.CHARGE_SECONDS
		end
		wait = math.max(0, math.ceil(wait))
		return string.format("Not yet! You can charge across in %d:%02d", wait // 60, wait % 60)
	end,
	-- the one-line tip for someone joining in this phase
	tip = function(p)
		if p == "fight" then
			return "The fight is on: shoot across the line to push it back!"
		elseif p == "build" then
			return "Build defences on your side, then fight!"
		end
		return nil
	end,
}
-- Capture the Flag (CtfService: the flags, the scores, the READY queue): the line stays at the middle and holds
-- only until the fight; then everyone may cross, blades out; kills push nothing; one fight, to the captures or the
-- clock; a tie goes to sudden death, then a draw; and nothing starts until enough players are READY
Rules.ctf = {
	lineOpen = function()
		return phase == "fight"
	end,
	chargeCall = false, -- (FIGHT! said it; nobody is sent home after)
	fightSeconds = function()
		return Constants.CTF.FIGHT_SECONDS
	end,
	onKill = function(_killer, _victim, _ks)
		return 0 -- (no line; CtfService drops whatever the victim carried)
	end,
	fightOver = function()
		local ahead = ctf and ctf:Leader(true)
		if ahead then
			MatchService:Victory(ahead)
		elseif not sudden then
			-- a tie: one more minute, and the first capture wins (CtfService ends it)
			sudden = true
			setPhase("fight", Constants.CTF.SUDDEN_DEATH_SECONDS)
			Net.fireAll("Alert", "SUDDEN DEATH", Color3.fromRGB(30, 30, 34), 2)
			Net.fireAll("Sfx", "horn")
			Notify.all("Sudden death! The first capture wins", "start", { icon = "⚑", seconds = 4 })
		else
			MatchService:Victory("draw")
		end
	end,
	leader = function()
		return ctf and ctf:Leader() or nil -- (captures, then knockouts: a solo joiner goes to the side behind)
	end,
	ready = function()
		return ctf == nil or ctf:ReadyCount() >= Constants.CTF.READY_PLAYERS
	end,
	score = function(s)
		return Formulas.mvpScore(s) + (s.captures or 0) * 25 + (s.returns or 0) * 5
	end,
	row = function(row, s)
		row.captures, row.returns = s.captures or 0, s.returns or 0
	end,
	crossText = function(t)
		if phase == "build" then
			local wait = math.max(0, math.ceil(phaseEnds - t))
			return string.format("Not yet! Stay on your half until the fight: %d:%02d", wait // 60, wait % 60)
		end
		return "Not yet! You can cross when the match starts"
	end,
	tip = function(p)
		if p == "fight" then
			return "Grab their flag and run it home to your stand!"
		elseif p == "build" then
			return "Build on your half, then go for their flag!"
		elseif p == "waiting" then
			return `Press READY when you're set: the match starts with {Constants.CTF.READY_PLAYERS} players`
		end
		return nil
	end,
}
function MatchService:Rules()
	return rules()
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
	spawning[player] = now() -- (a body takes a moment to load live: the watchdog leaves it alone meanwhile)
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
	-- (always facing the line: straight across the field toward the enemy)
	cf = CFrame.lookAt(cf.Position, cf.Position + Vector3.new(Formulas.forward(team), 0, 0))
	local r = c:FindFirstChild("HumanoidRootPart")
	if r then
		-- (standing on the deck, whatever the avatar's size: down from above the spot to the floor, then up by the
		-- legs, so nobody comes in half sunk into it)
		pcall(function()
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { c }
			local hit = workspace:Raycast(cf.Position + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
			local hum = c:FindFirstChildOfClass("Humanoid")
			if hit and hum then
				local y = hit.Position.Y + hum.HipHeight + r.Size.Y / 2 + 0.1
				cf = CFrame.new(cf.Position.X, math.max(cf.Position.Y, y), cf.Position.Z) * cf.Rotation
			end
		end)
		r.CFrame = cf
	end
	player:SetAttribute("AcGrace", os.clock() + 2) -- (our teleport: the anti-cheat lets it go)
	-- (from here on nothing may stop them coming alive: a look that fails to put on, or a hiccup, is only warned)
	local ok, err = pcall(teams.Dress, teams, c, team)
	if not ok then
		warn("[MatchService] dress failed: " .. tostring(err))
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.WalkSpeed = Constants.WALK_SPEED
			hum.BreakJointsOnDeath = false
			hum.Died:Connect(function()
				-- (Roblox killed it anyway: the menu's Reset, a glitch) the same as going down, no credit
				if player.Character == c and combat:Alive(player) then
					combat:Kill(player, nil, { kind = "reset" })
				end
			end)
		end)
	end
	ok, err = pcall(combat.Spawned, combat, player)
	if not ok then
		warn("[MatchService] spawned failed: " .. tostring(err))
	end
	spawning[player] = nil
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
		-- Shards for the kill, right now (up to EARN.killCap kills a match), the +N flying to their counter
		if economy and typeof(killer) == "Instance" and ks.kills <= Shop.EARN.killCap then
			pcall(
				economy.Add,
				economy,
				killer,
				Shop.EARN.perKill + (info.head and Shop.EARN.headshot or 0),
				info.head and "headshot" or "kill"
			)
		end
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
		-- (Turf Wars: the line moves toward the victim's base; Capture the Flag: nothing moves; Bot Brawl: no line)
		if self.rules.push then
			push = rules().onKill(killer, victim, ks)
		end
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
		if self.rules.push and frontline >= arena:LoseLine("blue") then
			self:Victory("red")
			return
		elseif self.rules.push and frontline <= arena:LoseLine("red") then
			self:Victory("blue")
			return
		end
	end
	if phase ~= "loading" then
		-- (in the victory wait too: nobody is stuck dead on the results; they're back up to run about)
		-- (still waiting for their first knockout: back even sooner)
		local wait = combat:Novice(victim) and Constants.RESPAWN_SECONDS_NEW or Constants.RESPAWN_SECONDS
		if self.rules.respawn then
			wait = self.rules.respawn(victim, wait) -- (the mode's say; false: down for good, a Bot Brawl bot)
		end
		if wait then
			respawnAt[victim] = now() + wait
		end
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
		rules().row(row, s) -- (Capture the Flag: captures and returns)
		table.insert(rows, row)
		local score = rules().score(s)
		if score > 0 and (not bestScore or score > bestScore) then
			best, bestScore = p, score
		end
	end
	table.sort(rows, function(a, b)
		return rules().score(a) > rules().score(b)
	end)
	return { winner = winner, rows = rows, mvp = best and best.UserId or nil, mvpPlayer = best }
end

-- winner: "red" | "blue" | "draw" (an admin's call: nobody wins or loses)
function MatchService:Victory(winner)
	if phase == "victory" or phase == "loading" or phase == "waiting" then
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
			active = (s.shots + s.built + s.kills + s.assists + (s.captures or 0) + (s.returns or 0)) > 0,
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
	local winName = Constants.TEAM_NAME[winner]
	if winName then
		-- ("Red team wins!": the side's name as the mode spells it, in sentence case)
		winName = string.upper(string.sub(winName, 1, 1)) .. string.lower(string.sub(winName, 2))
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
	-- (and the mice split between the sides: TeamService rule 4)
	local spread, spreadErr = pcall(teams.SpreadDevices, teams)
	if not spread then
		warn("[MatchService] spreading devices failed: " .. tostring(spreadErr))
	end
	matchId += 1
	matchStart = now()
	sudden = false
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
	if not rules().ready() then
		-- (Capture the Flag: not enough players READY yet. The arena is up to wait in; when they are, the match
		-- starts from here again: _tick)
		setPhase("waiting", 0)
		return
	end
	setPhase("build", phaseSeconds("build"))
	Net.fireAll("Alert", "BUILD", Color3.fromRGB(40, 40, 46), 2)
	local def = Maps.get(mapKey)
	Notify.all(`New game: {def and def.name or mapKey}`, "start", { icon = "⚔️" })
	self.Started:Fire(mapKey, matchId)
end

-- Someone tried to cross the line: when they'll be able to (the CHARGE), at most every few seconds
local toldAt = {}
function MatchService:_tellCharge(player)
	local t = now()
	if t - (toldAt[player] or -math.huge) < 4 then
		return
	end
	toldAt[player] = t
	Net.fire(player, "Toast", rules().crossText(t), "info")
end

-- The CHARGE: the fight's last seconds. The line opens (the turf rule is off), the blade comes out, and everyone
-- may run across. When it's over, anyone still on the other side goes home (a fresh spawn on their own side).
-- (Capture the Flag: the whole fight, and no call: Rules.ctf)
function MatchService:Charging()
	return workspace:GetAttribute("Charge") == true
end

function MatchService:_charge()
	local on = rules().lineOpen()
	if on == self:Charging() then
		return
	end
	workspace:SetAttribute("Charge", on or nil)
	-- (a mode without the call: FIGHT! opened the line, and the match's end closes it; nobody is sent home)
	local call = rules().chargeCall
	if call and on then
		Net.fireAll("Alert", "CHARGE!", Color3.fromRGB(30, 30, 34), 1.8)
		Net.fireAll("Sfx", "horn")
		Notify.all("CHARGE! Cross the line, blades out!", "start", { icon = "⚔️", seconds = 4 })
	elseif call and phase == "build" then
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
		setPhase("fight", rules().fightSeconds())
		Net.fireAll("Alert", "FIGHT!", Color3.fromRGB(30, 30, 34), 1.5)
		Net.fireAll("Sfx", "horn")
	elseif phase == "fight" and t >= phaseEnds then
		rules().fightOver() -- (Turf Wars: back to building; Capture the Flag: the scores decide)
	elseif phase == "waiting" and rules().ready() then
		self:NewMatch(mapKey) -- (enough players READY: the match starts)
		return
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
		if phase == "build" or phase == "fight" then
			-- (their team's Rally Banner stands: back up beside it, not in the spawn room; BuildService:RallySpawn)
			local ok, cf = pcall(build.RallySpawn, build, player)
			self.SpawnAt[player] = self.SpawnAt[player] or (ok and cf or nil)
		end
		task.spawn(function()
			local ok, err = pcall(self.Spawn, self, player)
			if not ok then
				warn("[MatchService] respawn failed: " .. tostring(err))
			end
		end)
	end
	-- the watchdog: nobody in the match is ever left without a body and nothing coming (a rejoin, a body that never
	-- loaded, a respawn lost somewhere): down with no respawn due, or "alive" with no body, for a few seconds
	if phase == "build" or phase == "fight" or phase == "waiting" then
		for _, player in self:Everyone() do
			local c = player.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			local fine = (combat:Alive(player) and r ~= nil)
				or respawnAt[player] ~= nil
				or pending[player]
				or (spawning[player] and t - spawning[player] < 12)
			if not teams:Team(player) then
				-- (in the server, loaded, and still on no team: Join went wrong somewhere; join them again)
				if not player.IsBot and data:Get(player) then
					stuckAt[player] = stuckAt[player] or t
					if t - stuckAt[player] >= Constants.STUCK_RESPAWN_SECONDS then
						stuckAt[player] = nil
						task.spawn(function()
							local ok, err = pcall(self.Join, self, player)
							if not ok then
								warn("[MatchService] rejoin failed: " .. tostring(err))
							end
						end)
					end
				else
					stuckAt[player] = nil
				end
			elseif fine then
				stuckAt[player] = nil
			else
				stuckAt[player] = stuckAt[player] or t
				if t - stuckAt[player] >= Constants.STUCK_RESPAWN_SECONDS then
					stuckAt[player] = nil
					spawning[player] = nil
					respawnAt[player] = t
				end
			end
		end
	end
	-- the turf rule, and the kill plane
	if phase == "build" or phase == "fight" or phase == "waiting" then
		for _, player in self:Everyone() do
			local team = teams:Team(player)
			local c = player.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if team and r and combat:Alive(player) and not self:Charging() then
				local x = r.Position.X
				if r.Position.Y < -20 then
					combat:Kill(player, nil, { kind = "fall" })
				elseif not self.rules.turf then
					-- (no turf rule: anyone anywhere; Bot Brawl)
					continue
				elseif team == "red" and x > frontline + Constants.TURF_MARGIN then
					self:_tellCharge(player)
					r.CFrame = CFrame.new(frontline - 3, r.Position.Y + 0.5, r.Position.Z) * r.CFrame.Rotation
					player:SetAttribute("AcGrace", os.clock() + 1)
					pcall(function()
						r.AssemblyLinearVelocity = Vector3.new(-20, 10, 0)
					end)
				elseif team == "blue" and x < frontline - Constants.TURF_MARGIN then
					self:_tellCharge(player)
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
	economy = registry.EconomyService
	teams = registry.TeamService
	arena = registry.ArenaService
	combat = registry.CombatService
	build = registry.BuildService
	progress = registry.ProgressService
	ctf = registry.CtfService -- (nil in a build without Capture the Flag)
	build:SetFrontline(function()
		return frontline
	end)
	teams:SetTurfLeader(function()
		return rules().leader()
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
		toldAt[player] = nil
		stats[player] = nil
		respawnAt[player] = nil
		pending[player] = nil
		spawning[player] = nil
		stuckAt[player] = nil
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
	stuckAt[player] = nil
	statsOf(player)
	if phase == "loading" then
		pending[player] = true
	else
		self:Spawn(player)
	end
	self:Broadcast()
	return true
end

-- Out of the match, still in the server (an admin starting to spectate; a bot gone): no stats, no respawn, no body.
function MatchService:Leave(player)
	stats[player] = nil
	respawnAt[player] = nil
	pending[player] = nil
	spawning[player] = nil
	stuckAt[player] = nil
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
		local tip = self.rules.tips and rules().tip(phase) -- (a mode with its own words says nothing here: BrawlService)
		if tip then
			Net.fire(player, "Toast", tip, "info")
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
