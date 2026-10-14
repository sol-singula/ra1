--[[
Analytics: every play session and everything players do in it, so we can see whether people get the game in the
first five minutes, finish runs, and come back (master plan §12: what we measure). Same pipeline as the studio's
other games: rows go to Supabase through the roblox-analytics function, tagged game = "ra6".
  roblox_sessions  one row per session: new or returning, session number, days since the last one, country,
                   device, how they joined, friends in the server, progress at the start; at the end what they did,
                   how long they stayed, the phase and their status when they left, idle or not, what happened last
  roblox_events    one row per thing that happened, with seconds since the session started:
                     loading (join, loaded, ui_ready, left_while_loading)
                     the first five minutes (§4): first_wood, first_build, first_crate, first_equip, first_kill,
                       first_dodge, kermy_seen, first_night, survived_night_1, the guide's steps, left_first_minute
                     the run: run_start, joined_run, waiting (joined after the roster locked), roster_locked,
                       night_start, night_survived, boss_start, run_end (won, how, nights, the player's stats),
                       finished_run
                     the survivor: downed (by what, which night), revived, ghost, respawned
                     the camp: built, upgraded, tier_up, repaired; items: craft, use, throw, trap, looted, mimic,
                       discovery, page, finding, blessing
                     progress: level_up, mastery_up, achievement, trophy
                     friends: friend_friend / friend_retry / friend_private / friend_newrun / friend_rejoin and
                       their results
                     requests the client sends (not the moves themselves: too many), prompts, pings, panels opened
                     button taps (batched), frame rate and window focus (from the client)
                     a snapshot every 30 s (and the live row the team dashboard reads): phase, day, status, hp, camp,
                       kills, loot, revives, difficulty, level, idle
                     the leave
Uses the same "discord_log" secret as the game log. Nothing is sent in Studio (unless GAME_LOG_IN_STUDIO).
]]
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)

local AnalyticsService = {
	Name = "AnalyticsService",
	Dependencies = {
		"PlayerDataService",
		"RunService",
		"SurvivorService",
		"InventoryService",
		"ResourceService",
		"CampService",
		"CraftService",
		"LootService",
		"MonsterService",
		"BossService",
		"CombatService",
		"WorldService",
		"TutorialService",
		"ProgressService",
		"JoinService",
		"PingService",
		"AntiCheatService",
	},
}

local data, runs, survivors, camp, progress
local sessions = {} -- [player] = session
local queue = { sessions = {}, events = {} }
local secret -- the key from the Secrets Store, or false if there isn't one
local MAX_EVENTS = 3000
-- requests that are moves or bookkeeping, not decisions (counted another way, or not at all)
local SKIP_REQUESTS = {
	Act = true,
	Ready = true,
	Friends = true,
	Analytics = true,
	Sprint = true,
	Dodge = true,
	Mash = true,
	Viewed = true,
	Select = true,
	Move = true,
}

local function now()
	return os.clock()
end

local function iso(t)
	return os.date("!%Y-%m-%dT%H:%M:%SZ", t)
end

-- Keep client-sent data small and plain.
local function clean(v, depth)
	depth = depth or 0
	local t = typeof(v)
	if t == "string" then
		return string.sub(v, 1, 80)
	elseif t == "number" then
		return v == v and math.clamp(v, -1e15, 1e15) or 0
	elseif t == "boolean" then
		return v
	elseif t == "table" and depth < 2 then
		local out, n = {}, 0
		for k, val in v do
			n += 1
			if n > 40 then
				break
			end
			out[string.sub(tostring(k), 1, 40)] = clean(val, depth + 1)
		end
		return out
	end
	return nil
end

local function upsertSession(s, fields)
	local row = queue.sessions[s.id]
	if not row then
		row = { session_id = s.id, user_id = s.userId }
		queue.sessions[s.id] = row
	end
	for k, v in fields do
		row[k] = v
	end
end

-- Log one event for a player (or a session table).
function AnalyticsService.track(player, kind, extra)
	local s = typeof(player) == "table" and player or sessions[player]
	if not s or #queue.events >= MAX_EVENTS then
		return
	end
	table.insert(queue.events, {
		session_id = s.id,
		user_id = s.userId,
		t = math.floor((now() - s.t0) * 10) / 10,
		kind = kind,
		data = extra,
	})
	if kind ~= "snapshot" and kind ~= "ui" and kind ~= "perf" and kind ~= "focus" then
		s.counts[kind] = (s.counts[kind] or 0) + 1
		table.insert(s.last, kind)
		if #s.last > 12 then
			table.remove(s.last, 1)
		end
		s.lastActionAt = now()
	end
end
local track = AnalyticsService.track

-- Send one batch (tests replace this). Returns true if it went out.
function AnalyticsService.send(payload)
	if RunService:IsStudio() and not Constants.GAME_LOG_IN_STUDIO then
		return false
	end
	if secret == nil then
		local ok, value = pcall(HttpService.GetSecret, HttpService, "discord_log")
		secret = ok and value or false
	end
	if not secret then
		return false
	end
	local ok, res = pcall(HttpService.RequestAsync, HttpService, {
		Url = Constants.ANALYTICS_URL,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json", ["X-Game-Key"] = secret },
		Body = HttpService:JSONEncode(payload),
	})
	if not ok or not res.Success then
		print("[Analytics] post failed: " .. tostring(ok and res.StatusCode or res))
		return false
	end
	return true
end

function AnalyticsService.flush()
	local rows = {}
	for _, row in queue.sessions do
		table.insert(rows, row)
	end
	if #rows == 0 and #queue.events == 0 then
		return
	end
	local payload = {
		game = Constants.ANALYTICS_GAME,
		server = { jobId = game.JobId, version = game.PlaceVersion, players = #Players:GetPlayers() },
		sessions = rows,
		events = queue.events,
	}
	queue = { sessions = {}, events = {} }
	AnalyticsService.send(payload)
end

local function progressOf(profile)
	local st, rec = profile.stats, profile.records
	return {
		level = (Formulas.level(profile.xp)),
		xp = profile.xp,
		runs = st.runs,
		wins = st.wins,
		unlocked = profile.unlocked,
		best_difficulty = rec.bestDifficulty,
		best_night = rec.bestNight,
		nights = rec.nights,
		monsters = rec.monsters,
		rescues = rec.rescues,
		kermy_ko = st.kermyKO,
		downs = st.downs,
		wood = st.wood,
		crafted = st.crafted,
		built = st.built,
		looted = st.looted,
		achievements = rec.achievementCount,
		kit = profile.kit,
		tutorial_step = profile.tutorial.step,
		tutorial_done = profile.tutorial.done == true,
	}
end

local function joinSource(player)
	local source = "direct"
	pcall(function()
		local jd = player:GetJoinData()
		local td = jd and jd.TeleportData
		if type(td) == "table" and type(td.from) == "string" then
			source = "teleport:" .. string.sub(td.from, 1, 20) -- "friend", "newrun", "private", "rejoin" (JoinService)
		elseif player.FollowUserId and player.FollowUserId ~= 0 then
			source = "followed_friend"
		elseif jd and jd.ReferredByPlayerId and jd.ReferredByPlayerId ~= 0 then
			source = "invite_link"
		elseif jd and jd.LaunchData and jd.LaunchData ~= "" then
			source = "launch:" .. string.sub(tostring(jd.LaunchData), 1, 40)
		elseif jd and jd.SourcePlaceId and jd.SourcePlaceId ~= 0 and jd.SourcePlaceId ~= game.PlaceId then
			source = "teleport:" .. tostring(jd.SourcePlaceId)
		end
	end)
	return source
end

local function friendsInServer(player)
	local n = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, yes = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and yes then
				n += 1
			end
		end
	end
	return n
end

-- The session starts the moment the player joins (before their save loads), so even people who leave while it
-- loads are counted.
local function begin(player)
	local s = {
		id = (function()
			local ok, guid = pcall(HttpService.GenerateGUID, HttpService, false)
			return ok and guid or `{player.UserId}-{os.time()}-{math.random(1e6)}`
		end)(),
		userId = player.UserId,
		t0 = now(),
		startedAt = os.time(),
		counts = {},
		last = {},
		taps = {},
		lastActionAt = now(),
		lastMoveAt = now(),
		lastInputAt = now(),
		idleSeconds = 0,
		runs = 0, -- runs finished this session
		nights = 0, -- nights survived this session
		firsts = {}, -- [kind] = true: the first-time funnel events already sent this session
	}
	sessions[player] = s
	upsertSession(s, {
		started_at = iso(s.startedAt),
		username = player.Name,
		display_name = player.DisplayName,
		account_age_days = player.AccountAge,
		premium = player.MembershipType == Enum.MembershipType.Premium,
		locale = player.LocaleId,
		join_source = joinSource(player),
		server_players = #Players:GetPlayers(),
		place_version = game.PlaceVersion,
		job_id = game.JobId ~= "" and game.JobId or nil,
	})
	track(s, "join", { players = #Players:GetPlayers(), phase = runs:Phase(), day = runs:Day() })
	task.spawn(function()
		local ok, country = pcall(function()
			return LocalizationService:GetCountryRegionForPlayerAsync(player)
		end)
		if ok and country and sessions[player] == s then
			upsertSession(s, { country = country })
		end
	end)
	return s
end

local function everyone(fn)
	for player, s in sessions do
		if s.ready then
			fn(player, s)
		end
	end
end

local function inRun(fn)
	for _, player in runs:Active() do
		if sessions[player] then
			fn(player, sessions[player])
		end
	end
end

local function seconds(player)
	local s = sessions[player]
	return s and math.floor(now() - s.t0) or nil
end

-- A first-time event for this session (the funnel): sent once.
local function first(player, kind, extra)
	local s = sessions[player]
	if s and not s.firsts[kind] then
		s.firsts[kind] = true
		extra = extra or {}
		extra.seconds = seconds(player)
		track(player, kind, extra)
	end
end

-- Where a survivor is, for the dashboard: camp | forest | deep | downed | ghost | waiting.
function AnalyticsService:StatusOf(player)
	local status = survivors:Status(player)
	if runs:IsWaiting(player) or status == "waiting" then
		return "waiting"
	end
	if status == "downed" or status == "ghost" then
		return status
	end
	local pos = survivors:Position(player)
	if not pos then
		return nil
	end
	local zone = MapLayout.zoneAt(pos.X, pos.Z)
	if zone == "camp" then
		return "camp"
	end
	return zone == "deep" and "deep" or "forest"
end

function AnalyticsService:Init(registry)
	data = registry.PlayerDataService
	runs = registry.RunService
	survivors = registry.SurvivorService
	camp = registry.CampService
	progress = registry.ProgressService
	local inventory = registry.InventoryService
	local resources = registry.ResourceService
	local craft = registry.CraftService
	local loot = registry.LootService
	local monsters = registry.MonsterService
	local boss = registry.BossService
	local combat = registry.CombatService
	local world = registry.WorldService
	local tutorial = registry.TutorialService
	local join = registry.JoinService
	local pings = registry.PingService
	registry.AntiCheatService.Flagged:Connect(function(player, kind, detail, strikes)
		track(player, "cheat_" .. kind, { detail = detail, strikes = strikes })
	end)
	registry.AntiCheatService.Kicked:Connect(function(player, reason)
		track(player, "cheat_kicked", { reason = reason })
	end)

	Players.PlayerAdded:Connect(begin)
	for _, p in Players:GetPlayers() do
		if not sessions[p] then
			begin(p)
		end
	end
	-- left before the save loaded: end the session here (OnPlayerLeaving never runs for them)
	Players.PlayerRemoving:Connect(function(player)
		local s = sessions[player]
		if s and not s.ready then
			track(s, "left_while_loading", { seconds = math.floor(now() - s.t0) })
			upsertSession(
				s,
				{ ended_at = iso(os.time()), duration_s = math.floor(now() - s.t0), end_reason = "left_loading" }
			)
			sessions[player] = nil
		end
	end)
	data.ClientReady:Connect(function(player)
		local s = sessions[player]
		if s and not s.clientReady then
			s.clientReady = true
			track(s, "ui_ready", { seconds = math.floor((now() - s.t0) * 10) / 10 })
		end
	end)

	-- everything the client asks the server to do (moves are counted, not logged one by one)
	Net.tap(function(player, name, a, b)
		local s = sessions[player]
		if not s then
			return
		end
		s.lastInputAt = now()
		if name == "Analytics" then
			if type(a) ~= "string" then
				return
			end
			local payload = clean(b)
			if a == "client_info" and type(payload) == "table" then
				s.device = payload.device
				upsertSession(s, { device = payload.device, screen = payload.screen })
				track(s, "client_info", payload)
			elseif a == "ui" and type(payload) == "table" then
				for k, v in payload.taps or {} do
					s.taps[k] = (s.taps[k] or 0) + (tonumber(v) or 0)
				end
				track(s, "ui", payload)
			elseif a == "perf" or a == "focus" or a == "settings" then
				track(s, a, payload)
			end
			return
		end
		if name == "Viewed" then
			if type(a) == "string" then
				track(s, "panel", { name = string.sub(a, 1, 30) })
			end
			return
		end
		if name == "Act" then
			s.acts = (s.acts or 0) + 1
			return
		end
		if name == "Dodge" then
			s.dodges = (s.dodges or 0) + 1
			return
		end
		if SKIP_REQUESTS[name] then
			return
		end
		track(player, "req_" .. string.lower(name), { a = clean(a), b = clean(b) })
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local s = sessions[player]
		if s then
			s.lastInputAt = now()
		end
		track(player, "prompt", { name = prompt.Name, action = prompt.ActionText })
	end)

	-- the first five minutes (§4)
	resources.Gathered:Connect(function(player, item, amount, source)
		if item == "wood" then
			first(player, "first_wood", { amount = amount, source = source })
		end
	end)
	camp.Deposited:Connect(function(player, structure, item)
		first(player, "first_build", { key = structure and structure.key, item = item })
	end)
	loot.Looted:Connect(function(player, container, items)
		first(player, "first_crate", { kind = container and container.kind })
		local list = {}
		for i, it in items or {} do
			if i > 6 then
				break
			end
			table.insert(list, type(it) == "table" and (it.key or it[1]) or tostring(it))
		end
		track(
			player,
			"looted",
			{ kind = container and container.kind, zone = container and container.zone, items = list }
		)
	end)
	loot.MimicSprung:Connect(function(player)
		track(player, "mimic", { day = runs:Day() })
	end)
	inventory.SlotSelected:Connect(function(player, slotId, item)
		if item and slotId ~= "h1" then
			first(player, "first_equip", { item = item.key, slot = slotId })
		end
	end)
	monsters.Killed:Connect(function(mob, killer)
		if killer and sessions[killer] then
			first(killer, "first_kill", { kind = mob.kind, night = runs:Night() })
		end
	end)
	monsters.KermyKO:Connect(function(_, killer)
		inRun(function(player)
			track(player, "kermy_ko", { mine = player == killer, night = runs:Night() })
		end)
	end)
	monsters.Sighting:Connect(function()
		inRun(function(player)
			first(player, "kermy_seen", { day = runs:Day() })
		end)
	end)
	survivors.Dodged:Connect(function(player, sourceKind)
		first(player, "first_dodge", { source = sourceKind })
		local s = sessions[player]
		if s then
			s.dodgedHits = (s.dodgedHits or 0) + 1
		end
	end)

	-- the run
	runs.Started:Connect(function(run)
		everyone(function(player)
			track(player, "run_start", { n = run.number, players = #Players:GetPlayers() })
		end)
	end)
	runs.Joined:Connect(function(player, run)
		local entry = run.roster[player.UserId]
		track(player, "joined_run", {
			n = run.number,
			day = run.day,
			phase = run.phase,
			rejoin = entry and (entry.rejoins or 0) > 0 or nil,
			roster = #runs:Active(),
		})
	end)
	runs.Waiting:Connect(function(player, run)
		track(player, "waiting", { phase = run.phase, day = run.day, night = run.night })
	end)
	runs.RosterLocked:Connect(function(run)
		inRun(function(player)
			track(player, "roster_locked", {
				difficulty = run.difficulty,
				roster = #runs:Active(),
				voted = run.votes.difficulty[player.UserId],
			})
		end)
	end)
	runs.NightStarted:Connect(function(n, event)
		inRun(function(player)
			if n == 1 then
				first(player, "first_night", { status = survivors:Status(player) })
			end
			track(player, "night_start", { n = n, event = event, status = AnalyticsService:StatusOf(player) })
		end)
	end)
	runs.NightSurvived:Connect(function(n)
		inRun(function(player, s)
			s.nights += 1
			if n == 1 then
				first(player, "survived_night_1", { status = survivors:Status(player) })
			end
			track(player, "night_survived", { n = n, status = survivors:Status(player) })
		end)
	end)
	runs.BossStarted:Connect(function()
		inRun(function(player)
			track(player, "boss_start", { players = #runs:Active(), camp = camp:Tier() })
		end)
	end)
	runs.Voted:Connect(function(player, kind, value)
		track(player, "vote", { kind = kind, value = value })
	end)
	progress.Rewarded:Connect(function(player, result, you)
		local s = sessions[player]
		if s then
			s.runs += 1
		end
		track(player, "run_end", {
			won = result.won,
			reason = result.reason,
			nights = result.nights,
			seconds = result.seconds,
			difficulty = result.difficulty,
			players = result.players,
			kills = you.kills,
			revives = you.revives,
			downs = you.downs,
			found = you.found,
			built = you.built,
			xp = you.xp,
			level = you.level,
			n = s and s.runs or nil,
		})
		first(player, "finished_run", { won = result.won, nights = result.nights })
	end)

	-- the survivor
	survivors.Downed:Connect(function(player, source)
		track(player, "downed", {
			by = type(source) == "table" and source.kind or tostring(source),
			night = runs:Night(),
			phase = runs:Phase(),
			status = AnalyticsService:StatusOf(player),
		})
	end)
	survivors.Revived:Connect(function(player, by, how)
		track(player, "revived", { how = how, by_teammate = by ~= nil and by ~= player })
		if by and by ~= player then
			track(by, "revive", { how = how })
		end
	end)
	survivors.Ghosted:Connect(function(player)
		track(player, "ghost", { night = runs:Night(), phase = runs:Phase() })
	end)
	survivors.Respawned:Connect(function(player)
		track(player, "respawned", { day = runs:Day() })
	end)

	-- the camp
	camp.Built:Connect(function(structure, contributors)
		for p in contributors or {} do
			if sessions[p] then
				track(p, "built", { key = structure.key })
			end
		end
	end)
	camp.Upgraded:Connect(function(structure, contributors)
		for p in contributors or {} do
			if sessions[p] then
				track(p, "upgraded", { key = structure.key })
			end
		end
	end)
	camp.TierUp:Connect(function(tier, by)
		inRun(function(player)
			track(player, "tier_up", { tier = tier, mine = player == by, day = runs:Day() })
		end)
	end)
	camp.Repaired:Connect(function(player, structure)
		track(player, "repaired", { key = structure and structure.key })
	end)
	camp.Fueled:Connect(function(player, wood)
		local s = sessions[player]
		if s then
			s.fuel = (s.fuel or 0) + (wood or 0)
		end
	end)

	-- items
	craft.Crafted:Connect(function(player, recipe)
		track(player, "craft", { id = type(recipe) == "table" and recipe.id or recipe })
	end)
	combat.Used:Connect(function(player, item)
		track(player, "use", { item = type(item) == "table" and item.key or item })
	end)
	combat.Thrown:Connect(function(player, item)
		track(player, "throw", { item = type(item) == "table" and item.key or item })
	end)
	combat.Placed:Connect(function(player, item)
		track(player, "trap", { item = type(item) == "table" and item.key or item })
	end)
	combat.Special:Connect(function(player, class)
		first(player, "first_special", { class = class })
	end)
	world.Discovered:Connect(function(player, finding)
		track(player, "finding", { key = finding and finding.key, zone = finding and finding.zone })
	end)
	world.PageRead:Connect(function(player, index)
		track(player, "page", { index = index })
	end)
	world.Blessed:Connect(function(player, key)
		track(player, "blessing", { key = key })
	end)
	boss.Grabbed:Connect(function(player)
		track(player, "grabbed")
	end)
	boss.Defeated:Connect(function(_, killer)
		inRun(function(player)
			track(player, "boss_down", { mine = player == killer })
		end)
	end)

	-- progress
	progress.LeveledUp:Connect(function(player, level)
		track(player, "level_up", { level = level })
	end)
	progress.MasteryUp:Connect(function(player, class, level)
		track(player, "mastery_up", { class = class, level = level })
	end)
	progress.Achieved:Connect(function(player, key)
		track(player, "achievement", { key = key })
	end)
	progress.Discovered:Connect(function(player, kind, key, isFirst)
		if isFirst then
			track(player, "discovery", { kind = kind, key = key })
		end
	end)
	progress.Trophy:Connect(function(player, key)
		track(player, "trophy", { key = key })
	end)
	pings.Pinged:Connect(function(player, key)
		track(player, "ping", { key = key })
	end)

	-- friends
	join.Attempted:Connect(function(player, kind)
		track(player, "friend_" .. kind)
	end)
	join.Result:Connect(function(player, kind, fields)
		track(player, "friend_result", { kind = kind, tries = fields and fields.tries })
	end)

	-- the guide
	tutorial.StepShown:Connect(function(player, step, total, key)
		track(player, "tutorial_step", { step = step, total = total, key = key })
	end)
	tutorial.StepDone:Connect(function(player, step, key, secs)
		track(player, "tutorial_step_done", { step = step, key = key, seconds = math.floor(secs) })
	end)
	tutorial.Finished:Connect(function(player, skipped)
		track(player, skipped and "tutorial_skipped" or "tutorial_done")
	end)

	-- the last batch goes out before the server closes
	pcall(function()
		game:BindToClose(function()
			for player, s in sessions do
				local profile = data:Get(player)
				if profile then
					AnalyticsService:_end(player, profile, "shutdown")
				else
					upsertSession(s, { ended_at = iso(os.time()), end_reason = "shutdown" })
				end
			end
			AnalyticsService.flush()
		end)
	end)
end

-- Every second: is each player moving? (idle = no moving and no input for a while)
function AnalyticsService:_watch()
	for player, s in sessions do
		local pos = survivors:Position(player)
		if pos then
			if s.lastPos and (pos - s.lastPos).Magnitude > 1 then
				s.lastMoveAt = now()
			end
			s.lastPos = pos
		end
		local active = math.max(s.lastMoveAt, s.lastInputAt)
		local idle = now() - active >= Constants.ANALYTICS_IDLE_SECONDS
		if idle then
			s.idleSeconds += 1
		end
		if idle ~= (s.idle == true) then
			s.idle = idle
			track(player, idle and "went_idle" or "came_back_from_idle")
		end
	end
end

function AnalyticsService:Live(player)
	local s = sessions[player]
	local profile = data:Get(player)
	if not s or not profile then
		return nil
	end
	local r = progress:RunStats(player)
	local st = survivors:State(player)
	local inRunNow = runs:InRun(player)
	local d = Constants.DIFFICULTIES[runs:Difficulty()]
	local live = {
		phase = runs:Phase(),
		day = runs:Day() > 0 and runs:Day() or nil,
		night = runs:Night() > 0 and runs:Night() or nil,
		status = self:StatusOf(player),
		hp = st and st.status ~= "waiting" and math.floor(st.hp or 0) or nil,
		camp = camp:Tier(),
		kills = inRunNow and r.kills or nil,
		loot = inRunNow and r.loot or nil,
		revives = inRunNow and survivors:Stats(player).revives or nil,
		difficulty = d and d.key or "normal",
		level = (Formulas.level(profile.xp)),
		idle = s.idle == true,
		server_players = #Players:GetPlayers(),
		tutorial_step = profile.tutorial.done and nil or profile.tutorial.step,
	}
	pcall(function()
		live.ping_ms = math.floor(player:GetNetworkPing() * 1000)
	end)
	return live
end

function AnalyticsService:_snapshot(player)
	local s = sessions[player]
	local live = self:Live(player)
	if not s or not live then
		return
	end
	track(player, "snapshot", live)
	upsertSession(s, { live = live }) -- the team's live dashboard reads this
end

function AnalyticsService:Start()
	local acc, snapAcc = 0, 0
	while true do
		task.wait(1)
		self:_watch()
		acc += 1
		snapAcc += 1
		if snapAcc >= Constants.ANALYTICS_SNAPSHOT_SECONDS then
			snapAcc = 0
			for player, s in sessions do
				if s.ready then
					self:_snapshot(player)
				end
			end
		end
		if acc >= Constants.ANALYTICS_FLUSH_SECONDS then
			acc = 0
			AnalyticsService.flush()
		end
	end
end

function AnalyticsService:OnPlayerReady(player, profile)
	local s = sessions[player] or begin(player)
	s.ready = true
	local meta = profile.meta
	local previous = meta.lastSeen
	meta.sessions = (meta.sessions or 0) + 1
	s.start = progressOf(profile)
	upsertSession(s, {
		is_new = profile._isNew == true,
		session_no = meta.sessions,
		days_since_last = (not profile._isNew and previous) and math.floor((os.time() - previous) / 864) / 100 or nil,
		start = s.start,
	})
	track(player, "loaded", {
		seconds = math.floor((now() - s.t0) * 10) / 10,
		new = profile._isNew == true,
		phase = runs:Phase(),
		day = runs:Day(),
	})
	task.delay(3, function()
		if sessions[player] == s then
			self:_snapshot(player) -- on the live dashboard right away
		end
	end)
	task.spawn(function()
		local n = friendsInServer(player)
		if sessions[player] == s then
			upsertSession(s, { friends_in_server = n })
		end
	end)
end

-- The end of a session: what they did, and what things looked like when they left.
function AnalyticsService:_end(player, profile, reason)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	local duration = math.floor(now() - s.t0)
	local summary = progressOf(profile)
	local start = s.start or summary
	summary.phase = runs:Phase()
	summary.day = runs:Day()
	summary.status = self:StatusOf(player)
	summary.in_run = runs:InRun(player)
	summary.idle_at_leave = s.idle == true
	summary.idle_seconds = s.idleSeconds
	summary.seconds_since_action = math.floor(now() - s.lastActionAt)
	summary.runs_session = s.runs
	summary.nights_session = s.nights
	summary.acts = s.acts or 0
	summary.dodges = s.dodges or 0
	summary.dodged_hits = s.dodgedHits or 0
	summary.fuel = s.fuel or 0
	for _, k in { "xp", "runs", "wins", "nights", "monsters", "rescues", "wood", "crafted", "built", "looted" } do
		summary[k .. "_gained"] = (summary[k] or 0) - (start[k] or 0)
	end
	if duration <= 60 then
		track(s, "left_first_minute", { phase = summary.phase, status = summary.status })
	end
	summary.counts = s.counts
	summary.taps = s.taps
	summary.last_actions = s.last
	track(s, "leave", {
		reason = reason,
		last = s.last,
		phase = summary.phase,
		day = summary.day,
		status = summary.status,
		idle = summary.idle_at_leave,
	})
	upsertSession(s, {
		ended_at = iso(os.time()),
		duration_s = duration,
		end_reason = reason,
		summary = summary,
	})
end

function AnalyticsService:OnPlayerLeaving(player, profile)
	self:_end(player, profile, "left")
end

-- (tests)
function AnalyticsService:Session(player)
	return sessions[player]
end

return AnalyticsService
