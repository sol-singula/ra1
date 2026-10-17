--[[
The first-minute tutorial, the server's half (the show itself is TutorialController on the client).

Who sees it: a brand-new player, once. Anyone back again (TutorialService.returning: tutorial done or skipped or
started, a match or a kill, or a second visit) never gets it or the intro again: they go straight into the fight
with a WELCOME BACK banner (Net "Hook" { kind = "welcome" }). Anyone can watch it again on purpose (GOALS → REPLAY:
Net "Tutorial", "replay"), for that visit only. When it ends, the missions start (HookService:Begin).
Constants.TUTORIAL off: nobody gets it.

How it goes: once their screen is listening the client is told { kind = "start", boost, replay }. The client plays
the intro and the guided steps and reports each one (Net "Tutorial": "step", name), then "done" or "skip"; the
profile keeps the furthest step and, at the end, done = true (saved straight away). The server also tells the
client when they really built something ({ kind = "built" }) so the build step ends on the real thing.

The first-match boost, so the first win comes fast: in a new player's very first match, while they're alone with
the bot, the bot is slower and shakier against them (BotService.easyFor) and each of their knockouts moves the line
TUTORIAL_PUSH_BONUS more cells (MatchService.bonusCells). Only that match: the next one is a normal one.

Analytics: tutorial_start, tutorial_step, tutorial_done, tutorial_skip through AnalyticsService.event(player, name,
data) when that service is there (looked up when it's needed, never required).

  TutorialService.shouldShow(profile) -> bool     (pure: the rule above)
  TutorialService.joinIntro(profile, at?) -> bool  just the opening cinematic this join (not back within 2 min)
  TutorialService:Boosted(player) -> bool         the first-match boost is on for them right now
  TutorialService:Active(player) -> bool          the guide is running for them (not done or skipped yet)
  TutorialService:Steps(player) -> { names }      the steps they reported, in order (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local TutorialService = {
	Name = "TutorialService",
	Dependencies = { "PlayerDataService", "MatchService", "BuildService", "BotService" },
}

-- the steps a client may report (TutorialController's, in their usual order)
local STEPS = {
	intro = true,
	pick = true,
	place = true,
	fight = true,
	aim = true,
	draw = true,
	release = true,
	hit = true,
	knockout = true,
	push = true,
	tip_blade = true,
	tip_run = true,
	win = true,
}

local registry, data, match
local active = {} -- [player] = { steps = { names }, replay }
local boosts = {} -- [player] = the matchId of their first match

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
	local now, phase = currentMatch()
	return id == now and (phase == "build" or phase == "fight")
end

function TutorialService:Active(player)
	return active[player] ~= nil and not active[player].finished
end

function TutorialService:Steps(player)
	return active[player] and active[player].steps or {}
end

local function finish(player, how)
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
	-- (kept, finished: the tips and the first win still report afterwards)
	if active[player] then
		active[player].finished = true
	end
	-- the missions after it (HookService, looked up when it's there)
	local hook = registry and registry.HookService
	if hook and type(hook.Begin) == "function" then
		task.defer(function()
			pcall(hook.Begin, hook, player)
		end)
	end
end

function TutorialService:Begin(player, replay)
	local p = data:Get(player)
	if not p then
		return
	end
	local id, phase = currentMatch()
	-- (the boost is for a brand-new player's first match: this one, or the next if this one is ending)
	if not replay and not tut(p).done and (p.stats.matches or 0) == 0 then
		boosts[player] = (phase == "build" or phase == "fight") and id or id + 1
	end
	active[player] = { steps = {}, replay = replay == true }
	data:WhenClientReady(player, function()
		if self:Active(player) then
			Net.fire(player, "Tutorial", { kind = "start", boost = boosts[player] ~= nil, replay = replay == true })
			-- (alone in their first match: the build phase waits long enough for the intro and their first wall)
			if self:Boosted(player) then
				match:HoldBuild(Constants.TUTORIAL_BUILD_SECONDS)
			end
		end
	end)
	analytics(player, "tutorial_start", { replay = replay == true, phase = phase })
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
	if not run then
		return
	end
	if what == "step" and type(name) == "string" and STEPS[name] then
		if table.find(run.steps, name) then
			return -- (each once)
		end
		table.insert(run.steps, name)
		tut(p).step = name
		analytics(player, "tutorial_step", { step = name, n = #run.steps, how = type(how) == "string" and how or nil })
	elseif run.finished then
		return -- (done or skipped once is enough)
	elseif what == "done" then
		finish(player, "done")
		analytics(player, "tutorial_done", { steps = #run.steps, replay = run.replay })
	elseif what == "skip" then
		finish(player, "skip")
		analytics(player, "tutorial_skip", {
			steps = #run.steps,
			at = run.steps[#run.steps],
			where = type(name) == "string" and string.sub(name, 1, 20) or nil,
		})
	end
end

function TutorialService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	match = reg.MatchService
	local build, bots = reg.BuildService, reg.BotService
	match.bonusCells = function(killer)
		return self:Boosted(killer) and Constants.TUTORIAL_PUSH_BONUS or 0
	end
	bots.easyFor = function(target)
		return target ~= nil and self:Boosted(target)
	end
	build.Built:Connect(function(player)
		if self:Active(player) then
			Net.fire(player, "Tutorial", { kind = "built" })
		end
	end)
	match.Ended:Connect(function()
		-- (the first match is over: the boost goes with it)
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
		active[player] = nil
		boosts[player] = nil
	end)
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

function TutorialService:OnPlayerReady(player, profile)
	local t = tut(profile)
	-- (a replay asked for last time and left unfinished never carries over: a replay is for that visit only)
	t.replay = false
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
	if TutorialService.shouldShow(profile) then
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
