--[[
The new-player tutorial, the server's half (the show itself is TutorialController on the client): a private practice
of about 2:50 that ends in a win, then into the live match.

Who sees it: a brand-new player, once. Anyone back again (TutorialService.returning: tutorial done or skipped or
started, a match or a kill, or a second visit) never gets it or the intro again: they go straight into the fight
with a WELCOME BACK banner (Net "Hook" { kind = "welcome" }). Anyone can play it again on purpose (GOALS → REPLAY:
Net "Tutorial", "replay"; an admin's PLAY TUTORIAL), for that visit only, with no rewards. When it ends, the
missions start (HookService:Begin). Constants.TUTORIAL off: nobody gets it.

Private: the moment a brand-new player's save loads (OnPlayerLoaded, before anything joins them to the match) they
are taken out of the match: the "Practice" attribute (Admins.spectating says so: no team, not counted, no body in the
arena, never hit, not in the results, the bots, the team balance, the watchdog and the AFK room leave them be; the
anti-cheat doesn't judge their moves) and Net.hush (nothing from the match reaches them: no kill feed, joins,
invites, gift, hook, feedback or shop cards, banners, toasts, match state or music). They get a slot of their own
far out past the match's world (World/Practice: the server puts down only an invisible floor and walls; their own
client draws the place, the bots and what they build, so nobody else ever gets a part of it), and a body there.
Their shots and building come here instead of the match (Net.divert): they can never be knocked out.

How it goes: once their screen is listening the client is told { kind = "start", replay, practice = { origin, team,
slot, max } } and runs the show; it reports each step (Net "Tutorial": "step", name, how), each knockout ("kill":
Shards for it, paid like a real one, the first time only), the win ("win": the win's Shards and a free trail, worn
at once: { kind = "reward", key, name }), then "done" or "skip". A piece they build (Net "Build", diverted) is
checked here (their own turf of the practice, their points) and told back ({ kind = "built", id, key, min, max,
budget }). Nothing can get stuck: the client times every step out, and here it ends at TUTORIAL_MAX_SECONDS whatever
happens. At the end ({ kind = "leave", how }) they come back from the practice and join the live match the normal
way (a team, a spawn, the match's state, the join chips for everyone else).

The first live match boost, so the first real win comes fast too: in a new player's first match after it, while
they're alone with the bot, the bot is slower and shakier against them (BotService.easyFor) and each of their
knockouts moves the line TUTORIAL_PUSH_BONUS more cells (MatchService.bonusCells). Only that match.

Analytics: tutorial_start, tutorial_step (with t: the seconds since it started), tutorial_done and tutorial_skip
(with seconds, and timings: { [step] = t }) through AnalyticsService.event(player, name, data) when that service is
there (looked up when it's needed, never required).

  TutorialService.shouldShow(profile) -> bool     (pure: the rule above)
  TutorialService.joinIntro(profile, at?) -> bool  just the opening cinematic this join (not back within 2 min)
  TutorialService.returning(profile) -> bool
  TutorialService:Boosted(player) -> bool         the first-match boost is on for them right now
  TutorialService:Active(player) -> bool          the tutorial is running for them (not done or skipped yet)
  TutorialService:InPractice(player) -> bool      in their private practice right now
  TutorialService:Run(player)                     { slot, origin, team, t0, kills, built, timings, ... } (tests)
  TutorialService:Steps(player) -> { names }      the steps they reported, in order (tests)
  TutorialService:Finish(player, how)             end it now and join the match ("done" | "skip" | "timeout")
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Locker = require(ReplicatedStorage.Shared.Data.Locker)
local Net = require(ReplicatedStorage.Shared.Net)
local Practice = require(ReplicatedStorage.Shared.World.Practice)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local Structures = require(ReplicatedStorage.Shared.Data.Structures)

local TutorialService = {
	Name = "TutorialService",
	Dependencies = {
		"PlayerDataService",
		"MatchService",
		"BuildService",
		"BotService",
		"TeamService",
		"CombatService",
		"EconomyService",
		"ProgressService",
	},
}

-- the steps a client may report (TutorialController's, in their order)
local STEPS = {
	intro = true,
	first_kill = true,
	multi_kill = true,
	near_miss = true,
	build_view = true,
	pick_wall = true,
	place_wall = true,
	pick_tower = true,
	place_tower = true,
	fight_again = true,
	tnt = true,
	push = true,
	final_kill = true,
	victory = true,
	gate = true,
}
-- what a player in the practice may not send to the match (their shots and building are the practice's)
local DIVERTED = { Shoot = true, Draw = true, Swing = true, Equip = true, Reload = true, Demolish = true }
local MAX_BUILT = 6

local registry, data, match, teams, combat, build, economy, progress
local active = {} -- [player] = the run (below)
local boosts = {} -- [player] = the matchId of their first live match
local slots = {} -- [slot] = player

local function now()
	return workspace:GetServerTimeNow()
end

local function analytics(player, name, info)
	local a = registry and registry.AnalyticsService
	if a and type(a.event) == "function" then
		pcall(a.event, player, name, info or {})
	end
end

local function tut(profile)
	if type(profile.tutorial) ~= "table" then
		profile.tutorial = { done = false, skipped = false, replay = false, step = "", at = 0 }
	end
	return profile.tutorial
end

function TutorialService.shouldShow(profile)
	if not Constants.TUTORIAL or type(profile) ~= "table" then
		return false
	end
	local t = tut(profile)
	if t.replay then
		return true
	end
	local played = profile.stats and profile.stats.matches or 0
	return not t.done and played == 0
end

local function currentMatch()
	local snap = match:Snapshot()
	return snap.matchId, snap.phase
end

function TutorialService:Boosted(player)
	local id = boosts[player]
	if not id or #Players:GetPlayers() ~= 1 then
		return false
	end
	local cur, phase = currentMatch()
	return id == cur and (phase == "build" or phase == "fight")
end

function TutorialService:Active(player)
	return active[player] ~= nil and not active[player].finished
end

function TutorialService:InPractice(player)
	return player:GetAttribute("Practice") == true
end

function TutorialService:Run(player)
	return active[player]
end

function TutorialService:Steps(player)
	return active[player] and active[player].steps or {}
end

-- The practice ---------------------------------------------------------------------------------------------------
-- Out of the match and hushed: from here on nothing from the match reaches them, and the match doesn't count them
local function hush(player)
	player:SetAttribute("Practice", true)
	Net.hush(player, true)
end

local function freeSlot()
	local i = 1
	while slots[i] and slots[i].Parent do
		i += 1
	end
	return i
end

-- the side they practise on: the one they'd most likely join now (the smaller), red when even
local function practiceTeam()
	return teams:Count("blue") < teams:Count("red") and "blue" or "red"
end

-- A body in their practice, standing just behind the line and facing it (their own look, their team's bands)
local function spawnIn(player, run)
	local desc = match.ownBody(player) or match.sameBody()
	local loaded = desc and pcall(function()
		player:LoadCharacterWithHumanoidDescription(desc)
	end)
	if not player.Parent or active[player] ~= run or run.finished then
		return
	end
	if not loaded then
		pcall(function()
			player:LoadCharacter()
		end)
	end
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if not r then
		return
	end
	r.CFrame = Practice.spawn(run.origin, run.team)
	player:SetAttribute("AcGrace", os.clock() + 3)
	pcall(teams.Dress, teams, c, run.team)
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.WalkSpeed = Constants.WALK_SPEED
			hum.BreakJointsOnDeath = false
			hum.MaxHealth, hum.Health = Constants.MAX_HEALTH, Constants.MAX_HEALTH
			hum.Died:Connect(function()
				-- (the menu's Reset: never a knockout here, just back on your feet in the practice)
				if active[player] == run and not run.finished and player.Character == c then
					task.delay(1, spawnIn, player, run)
				end
			end)
		end)
	end
end

function TutorialService:Begin(player, replay)
	local p = data:Get(player)
	if not p or (active[player] and not active[player].finished) then
		return
	end
	if not self:InPractice(player) then
		-- (a replay from the match: out of it first, like the AFK room)
		teams:Clear(player)
		match:Leave(player)
		combat:Remove(player)
		hush(player)
	end
	local slot = freeSlot()
	slots[slot] = player
	local origin = Practice.origin(slot)
	local run = {
		steps = {},
		timings = {},
		replay = replay == true,
		-- (Shards and the trail only the first time through)
		pay = replay ~= true and not tut(p).done,
		t0 = now(),
		slot = slot,
		origin = origin,
		team = practiceTeam(),
		kills = 0,
		built = {},
		nextId = 0,
		budget = Constants.BUILD_BUDGET,
	}
	active[player] = run
	run.floor = Practice.collider(origin, workspace)
	run.floor.Name = "PracticeFloor" .. slot
	task.spawn(spawnIn, player, run)
	data:WhenClientReady(player, function()
		if active[player] == run and not run.finished then
			Net.fire(player, "Tutorial", {
				kind = "start",
				boost = run.pay,
				replay = run.replay,
				practice = {
					origin = origin,
					team = run.team,
					slot = slot,
					max = Constants.TUTORIAL_MAX_SECONDS,
					budget = run.budget,
				},
			})
		end
	end)
	analytics(player, "tutorial_start", { replay = run.replay, slot = slot })
end

-- Back from the practice into the live match, the normal way (a team, a spawn, the match's state)
local function leave(player, run, how)
	if run.floor then
		run.floor:Destroy()
		run.floor = nil
	end
	if slots[run.slot] == player then
		slots[run.slot] = nil
	end
	if not player.Parent then
		return
	end
	player:SetAttribute("Practice", nil)
	Net.hush(player, false)
	Net.fire(player, "Tutorial", { kind = "leave", how = how })
	player:SetAttribute("AcGrace", os.clock() + 3)
	-- (fresh to the match: the AFK room's join grace starts now, not when they arrived in the practice)
	local afk = registry and registry.AfkService
	if afk and type(afk.Touch) == "function" then
		pcall(afk.Touch, afk, player)
	end
	local ok, err = pcall(match.Join, match, player)
	if not ok then
		warn("[TutorialService] join failed: " .. tostring(err))
	end
	pcall(match.AnnounceJoin, match, player)
	Net.fire(player, "Match", match:Snapshot())
	pcall(build.Push, build, player)
	pcall(progress.Push, progress, player)
end

local function finish(player, how)
	local run = active[player]
	if not run or run.finished then
		return false
	end
	run.finished = true
	local p = data:Get(player)
	if p then
		local t = tut(p)
		t.done = true
		t.replay = false
		t.at = os.time()
		if how == "skip" then
			t.skipped = true
		end
		task.spawn(data.Save, data, player)
	end
	local seconds = math.floor((now() - run.t0) * 10 + 0.5) / 10
	if how == "skip" then
		analytics(player, "tutorial_skip", {
			steps = #run.steps,
			at = run.steps[#run.steps],
			seconds = seconds,
			timings = run.timings,
		})
	else
		analytics(player, "tutorial_done", {
			steps = #run.steps,
			replay = run.replay,
			seconds = seconds,
			how = how,
			timings = run.timings,
		})
	end
	-- (their first live match gets the boost: this one, or the next if this one is ending)
	if run.pay then
		local id, phase = currentMatch()
		boosts[player] = (phase == "build" or phase == "fight") and id or id + 1
	end
	leave(player, run, how)
	-- the missions after it (HookService, looked up when it's there)
	local hook = registry and registry.HookService
	if hook and type(hook.Begin) == "function" then
		task.defer(function()
			pcall(hook.Begin, hook, player)
		end)
	end
	return true
end

function TutorialService:Finish(player, how)
	return finish(player, how or "done")
end

-- A piece they built in the practice (Net "Build", diverted here): their own turf of it, their points
function TutorialService:_build(player, key, cx, cz, rot)
	local run = active[player]
	local def = Structures.get(key)
	if not run or run.finished or not def or type(cx) ~= "number" or type(cz) ~= "number" then
		return false
	end
	cx, cz, rot = math.floor(cx), math.floor(cz), rot == 1 and 1 or 0
	local why
	local w, d = Structures.footprint(def, rot)
	local mn, mx = Formulas.footprintBox(cx, cz, w, d, 0, def.h)
	local front = Formulas.forward(run.team) * Practice.PUSH * run.kills
	local z0 = run.origin.Z
	if run.budget < def.cost then
		why = "Not enough build points"
	elseif #run.built >= MAX_BUILT then
		why = "That's plenty for now"
	elseif
		mn.X < -Practice.EDGE
		or mx.X > Practice.EDGE
		or mn.Z < z0 - Practice.WIDTH / 2
		or mx.Z > z0 + Practice.WIDTH / 2
	then
		why = "Outside the battlefield"
	elseif (run.team == "red" and mx.X > front) or (run.team == "blue" and mn.X < front) then
		why = "Only on your own turf"
	else
		for _, s in run.built do
			if
				Formulas.boxesOverlap(mn + Vector3.new(0.01, 0, 0.01), mx - Vector3.new(0.01, 0, 0.01), s.min, s.max)
			then
				why = "Something's already there"
			end
		end
	end
	if why then
		Net.fire(player, "Tutorial", { kind = "refused", why = why })
		return false
	end
	run.nextId += 1
	run.budget -= def.cost
	local s = { id = run.nextId, key = def.key, team = run.team, min = mn, max = mx, rot = rot }
	table.insert(run.built, s)
	Net.fire(player, "Tutorial", {
		kind = "built",
		id = s.id,
		key = s.key,
		team = s.team,
		min = mn,
		max = mx,
		rot = rot,
		budget = run.budget,
	})
	return true
end

-- the win: its Shards, and a free trail (the first of TUTORIAL_TRAIL they don't own), worn at once
local function reward(player, run)
	local p = data:Get(player)
	local out = { kind = "reward" }
	if run.pay and p then
		pcall(economy.Add, economy, player, Shop.EARN.win, "match")
		for _, key in Constants.TUTORIAL_TRAIL do
			local it = Cosmetics.get(key)
			if it and not Locker.owns(p, key) then
				economy:Give(player, key)
				p.equipped = p.equipped or {}
				p.equipped.trail = key
				out.key, out.name = key, it.name
				break
			end
		end
		out.shards = Shop.EARN.win
		pcall(progress.Push, progress, player)
	end
	Net.fire(player, "Tutorial", out)
end

function TutorialService:_onClient(player, what, name, how)
	local p = data:Get(player)
	if not p then
		return
	end
	if what == "replay" then
		if not Constants.TUTORIAL then
			return
		end
		tut(p).replay = true
		self:Begin(player, true)
		return
	end
	local run = active[player]
	if not run or run.finished then
		return
	end
	if what == "step" and type(name) == "string" and STEPS[name] then
		if table.find(run.steps, name) then
			return -- (each once)
		end
		table.insert(run.steps, name)
		local t = math.floor((now() - run.t0) * 10 + 0.5) / 10
		run.timings[name] = t
		tut(p).step = name
		analytics(player, "tutorial_step", {
			step = name,
			n = #run.steps,
			t = t,
			how = type(how) == "string" and string.sub(how, 1, 12) or nil,
		})
	elseif what == "kill" then
		if run.kills < Practice.KILLS then
			run.kills += 1
			if run.pay then
				pcall(economy.Add, economy, player, Shop.EARN.perKill, "kill")
				pcall(progress.Push, progress, player)
			end
		end
	elseif what == "win" then
		if not run.won then
			run.won = true
			run.kills = Practice.KILLS
			reward(player, run)
		end
	elseif what == "done" then
		finish(player, "done")
	elseif what == "skip" then
		finish(player, "skip")
	end
end

-- a brand-new player off to their private practice? (the rule, and not someone back again)
local function wantsPractice(profile)
	return TutorialService.shouldShow(profile) and not TutorialService.returning(profile)
end

function TutorialService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	match = reg.MatchService
	teams = reg.TeamService
	combat = reg.CombatService
	build = reg.BuildService
	economy = reg.EconomyService
	progress = reg.ProgressService
	local bots = reg.BotService
	match.bonusCells = function(killer)
		return self:Boosted(killer) and Constants.TUTORIAL_PUSH_BONUS or 0
	end
	bots.easyFor = function(target)
		return target ~= nil and self:Boosted(target)
	end
	bots.away = function(_, profile)
		return wantsPractice(profile)
	end
	Net.divert = function(player, name, ...)
		if not self:InPractice(player) or not active[player] then
			return false
		end
		if name == "Build" then
			self:_build(player, ...)
			return true
		end
		return DIVERTED[name] == true
	end
	match.Ended:Connect(function()
		-- (their first live match is over: the boost goes with it)
		local id = currentMatch()
		for player, at in boosts do
			if at <= id then
				boosts[player] = nil
			end
		end
	end)
	Net.on("Tutorial", function(player, what, name, how)
		if type(what) == "string" then
			self:_onClient(player, what, name, how)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local run = active[player]
		if run then
			run.finished = true
			if run.floor then
				run.floor:Destroy()
			end
			if slots[run.slot] == player then
				slots[run.slot] = nil
			end
		end
		active[player] = nil
		boosts[player] = nil
		Net.hush(player, false)
	end)
end

-- Every quarter second: nobody's practice runs past TUTORIAL_MAX_SECONDS, and nobody falls out of it
function TutorialService:_tick()
	local t = now()
	for player, run in active do
		if not run.finished and player.Parent then
			if t - run.t0 >= Constants.TUTORIAL_MAX_SECONDS then
				finish(player, "timeout")
			else
				local c = player.Character
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if r and self:InPractice(player) and not Practice.inside(run.origin, r.Position, 6) then
					r.CFrame = Practice.spawn(run.origin, run.team)
					player:SetAttribute("AcGrace", os.clock() + 2)
				end
			end
		end
	end
end

function TutorialService:Start()
	while true do
		task.wait(0.25)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[TutorialService] tick failed: " .. tostring(err))
		end
	end
end

-- Back again: they've seen the tutorial (done or skipped), got some way into it, played a match, or this isn't their
-- first visit. They never get the tutorial or the intro again (only if they ask: GOALS → REPLAY).
function TutorialService.returning(profile)
	if type(profile) ~= "table" then
		return false
	end
	local t = tut(profile)
	local stats = profile.stats or {}
	local sessions = type(profile.meta) == "table" and profile.meta.sessions or 1
	return t.done
		or t.skipped
		or (t.step or "") ~= ""
		or (stats.matches or 0) > 0
		or (stats.kills or 0) > 0
		or (sessions or 1) >= 2
end

-- Their save is here, before the match takes them: a brand-new player goes to their private practice instead
function TutorialService:OnPlayerLoaded(player, profile)
	tut(profile).replay = false -- (a replay asked for last time and left unfinished never carries over)
	if wantsPractice(profile) then
		hush(player)
	end
end

function TutorialService:OnPlayerReady(player, profile)
	local t = tut(profile)
	if TutorialService.returning(profile) then
		-- straight into the fight: no tutorial, no intro, just a WELCOME BACK (HookController draws it)
		if not t.done then
			t.done = true
			t.skipped = true
		end
		local stats = profile.stats or {}
		data:WhenClientReady(player, function()
			Net.fire(player, "Hook", {
				kind = "welcome",
				wins = profile.wins or 0,
				streak = profile.streak or 0,
				kills = stats.kills or 0,
			})
		end)
		analytics(player, "welcome_back", { sessions = type(profile.meta) == "table" and profile.meta.sessions or nil })
		return
	end
	if self:InPractice(player) then
		self:Begin(player, false)
	end
end

-- The opening alone, for someone who has played the tutorial: on every join, unless they left less than
-- JOIN_INTRO_REJOIN_SECONDS ago (meta.lastSeen is their last save, made as they left)
function TutorialService.joinIntro(profile, at)
	if not Constants.TUTORIAL or not Constants.JOIN_INTRO or type(profile) ~= "table" then
		return false
	end
	local last = type(profile.meta) == "table" and tonumber(profile.meta.lastSeen) or 0
	return (at or os.time()) - last >= Constants.JOIN_INTRO_REJOIN_SECONDS
end

return TutorialService
