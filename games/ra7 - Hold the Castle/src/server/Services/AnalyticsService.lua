-- Analytics: every play session and everything players do in it, so we can see whether people understand the
-- game in the first five minutes, finish matches, and come back (master plan §12 "What we count", §26). Same
-- pipeline as Steal a Dragon: rows go to Supabase through the roblox-analytics function, tagged game = "ra7".
--   roblox_sessions  one row per session: new or returning, session number, days since the last one, country,
--                    device, how they joined, friends in the server, progress at the start; at the end what they
--                    did, how long they stayed, which team and phase they were in, idle or not, what happened last
--   roblox_events    one row per thing that happened, with seconds since the session started:
--                      loading (joined, loaded, UI ready, left while loading)
--                      the first five minutes: first_rock, first_build, first_wall, first_fight, the guide's steps
--                      and the first choice, left_first_minute
--                      the match: match_start, plague (turned or not), turned, died, job, shrine_fell, stage,
--                      match_end (winner, held, team, won, stats), finished_match
--                      the castle: placed, built, upgraded, broke; crafting: craft, use
--                      progress: level_up, task_done, gift, title, bought, equipped
--                      friends: friend_friend / friend_retry / friend_private / friend_rejoin and their results
--                      requests the client sends (not the moves themselves: too many), prompts, pings
--                      button taps (batched), frame rate and window focus (from the client)
--                      a snapshot every 30 s (and the live row the team dashboard reads): team, job, phase, shrine,
--                      built, beaten, hp, idle
--                      the leave
-- Uses the same "discord_log" secret as the game log. Nothing is sent in Studio (unless GAME_LOG_IN_STUDIO).
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)

local AnalyticsService = {
	Name = "AnalyticsService",
	Dependencies = {
		"PlayerDataService",
		"MatchService",
		"TeamService",
		"ResourceService",
		"BuildService",
		"HordeService",
		"ShrineService",
		"CombatService",
		"CraftService",
		"ProgressService",
		"JoinService",
		"TutorialService",
		"PingService",
		"AntiCheatService",
	},
}

local data, match, teams
local sessions = {} -- [player] = session
local queue = { sessions = {}, events = {} }
local secret -- the key from the Secrets Store, or false if there isn't one
local MAX_EVENTS = 3000
-- requests that are moves or bookkeeping, not decisions (tracked another way, or not at all)
local SKIP_REQUESTS = { Act = true, Ready = true, Friends = true, Analytics = true }

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

local function progress(profile)
	local st = profile.stats
	return {
		coins = profile.coins,
		level = (Formulas.accountLevel(profile.xp)),
		xp = profile.xp,
		matches = st.matches,
		dwarf_wins = st.dwarfWins,
		monster_wins = st.monsterWins,
		built = st.built,
		beaten = st.beaten,
		dwarves_beaten = st.dwarvesBeaten,
		broken = st.broken,
		mined = st.mined,
		best_hold = st.bestHold,
		dwarf_job = profile.dwarfJob,
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
			source = "teleport:" .. string.sub(td.from, 1, 20) -- "friend", "new", "rejoin" (JoinService)
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
		matches = 0, -- matches finished this session
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
	track(s, "join", { players = #Players:GetPlayers(), phase = match:Phase() })
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

-- A first-time event for this session (the funnel): sent once.
local function first(player, kind, extra)
	local s = sessions[player]
	if s and not s.firsts[kind] then
		s.firsts[kind] = true
		track(player, kind, extra)
	end
end

function AnalyticsService:Init(registry)
	data = registry.PlayerDataService
	match = registry.MatchService
	teams = registry.TeamService
	local resources = registry.ResourceService
	local build = registry.BuildService
	local shrines = registry.ShrineService
	local combat = registry.CombatService
	local craft = registry.CraftService
	local progressSvc = registry.ProgressService
	local join = registry.JoinService
	local tutorial = registry.TutorialService
	local pings = registry.PingService
	local horde = registry.HordeService
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
			elseif a == "perf" or a == "focus" or a == "panel" then
				track(s, a, payload)
			end
			return
		end
		if name == "Act" then
			s.acts = (s.acts or 0) + 1
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

	-- the first five minutes (§12)
	resources.Mined:Connect(function(player, kind, _amount, _, gem)
		first(player, "first_rock", { kind = kind, seconds = math.floor(now() - sessions[player].t0) })
		if gem then
			track(player, "gem")
		end
	end)
	resources.BagFull:Connect(function(player)
		track(player, "bag_full", { cap = resources:Capacity(player) })
	end)
	build.Helped:Connect(function(piece, player, kind)
		if kind == "deposit" or kind == "work" then
			first(player, "first_build", { key = piece.key, seconds = math.floor(now() - sessions[player].t0) })
		end
	end)
	build.Placed:Connect(function(piece, player)
		if player then
			track(player, "placed", { key = piece.key, shrine = piece.shrine })
		end
	end)
	build.Built:Connect(function(piece, contributors)
		for p in contributors do
			if sessions[p] then
				first(p, "first_wall", { key = piece.key, seconds = math.floor(now() - sessions[p].t0) })
				track(p, piece.upgraded and "upgraded" or "built", { key = piece.key })
			end
		end
	end)
	build.Destroyed:Connect(function(piece, by)
		if by then
			track(by, "broke", { key = piece.key })
		end
	end)
	build.StageChanged:Connect(function(shrine, stage)
		if match:InMatch() then
			everyone(function(player)
				track(player, "stage", { shrine = shrine, stage = stage })
			end)
		end
	end)
	combat.Hit:Connect(function(by, victim)
		if by and (victim.npc or victim.player) then
			first(by, "first_fight", { team = teams:Team(by), seconds = math.floor(now() - sessions[by].t0) })
		end
	end)
	combat.Acted:Connect(function(player, slot, move)
		if slot == "special" then
			local s = sessions[player]
			if s then
				s.specials = (s.specials or 0) + 1
			end
			first(player, "first_special", { move = move })
		end
	end)
	craft.Crafted:Connect(function(player, item, tier)
		track(player, "craft", { item = item, tier = tier })
	end)
	craft.Used:Connect(function(player, item)
		track(player, "use", { item = item })
	end)

	-- the match
	match.Started:Connect(function(m)
		everyone(function(player)
			track(player, "match_start", { n = m.number, players = #Players:GetPlayers(), build = m.buildSeconds })
		end)
	end)
	match.Plague:Connect(function()
		task.defer(function()
			everyone(function(player)
				track(player, "plague", { turned = teams:Team(player) == "monster", players = #Players:GetPlayers() })
			end)
		end)
	end)
	teams.TeamChanged:Connect(function(player, team, why)
		if team == "monster" then
			track(player, "turned", { why = why, fight_s = math.floor(match:FightSeconds()) })
		end
	end)
	teams.JobChanged:Connect(function(player, key)
		track(player, "job", { key = key, team = teams:Team(player) })
	end)
	teams.Died:Connect(function(player, killer, team, npc)
		track(player, "died", {
			team = team,
			by = killer and "player" or (npc and "npc" or "other"),
			phase = match:Phase(),
			fight_s = math.floor(match:FightSeconds()),
		})
	end)
	teams.LevelUp:Connect(function(player, level)
		track(player, "monster_level", { level = level })
	end)
	shrines.Fell:Connect(function(index)
		everyone(function(player)
			track(
				player,
				"shrine_fell",
				{ index = index, fight_s = math.floor(match:FightSeconds()), team = teams:Team(player) }
			)
		end)
	end)
	progressSvc.Rewarded:Connect(function(player, you, result)
		local s = sessions[player]
		if s then
			s.matches += 1
		end
		track(player, "match_end", {
			winner = result.winner,
			reason = result.reason,
			held = result.held,
			fallen = result.fallen,
			team = you.team,
			won = you.won,
			coins = you.coins,
			built = you.built,
			beaten = you.beaten,
			dwarves_beaten = you.dwarvesBeaten,
			broken = you.broken,
			held_s = you.heldSeconds,
			n = s and s.matches or nil,
		})
		first(player, "finished_match", { won = you.won, team = you.team })
	end)
	progressSvc.LeveledUp:Connect(function(player, level)
		track(player, "level_up", { level = level })
	end)
	progressSvc.TaskDone:Connect(function(player, key, coins)
		track(player, "task_done", { key = key, coins = coins })
	end)
	progressSvc.GiftClaimed:Connect(function(player, coins, streak)
		track(player, "gift", { coins = coins, streak = streak })
	end)
	progressSvc.TitleEarned:Connect(function(player, key)
		track(player, "title", { key = key })
	end)
	progressSvc.Bought:Connect(function(player, key, price)
		track(player, "bought", { key = key, price = price })
	end)
	progressSvc.Equipped:Connect(function(player, slot, key)
		track(player, "equipped", { slot = slot, key = key })
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
	tutorial.StepDone:Connect(function(player, step, key, seconds)
		track(player, "tutorial_step_done", { step = step, key = key, seconds = math.floor(seconds) })
	end)
	tutorial.Chosen:Connect(function(player, choice)
		track(player, "first_choice", { choice = choice })
	end)
	tutorial.Finished:Connect(function(player, skipped)
		track(player, skipped and "tutorial_skipped" or "tutorial_done")
	end)
	_ = horde

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

-- Every second: is each player moving? (idle = no moving and no input for a while). And the first minute.
function AnalyticsService:_watch()
	for player, s in sessions do
		local pos = teams:Position(player)
		if pos then
			if s.lastPos and (pos - s.lastPos).Magnitude > 1 then
				s.lastMoveAt = now()
			end
			s.lastPos = pos
		end
		s.team = teams:Team(player) or s.team
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
	local st = teams:State(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local live = {
		team = st and st.team or nil,
		job = st and st.team and st.job or nil,
		phase = match:Phase(),
		shrine = match:ActiveShrine(),
		built = st and st.stats.built or 0,
		beaten = st and (st.stats.beaten + st.stats.dwarvesBeaten) or 0,
		hp = hum and math.floor(hum.Health) or nil,
		idle = s.idle == true,
		level = (Formulas.accountLevel(profile.xp)),
		coins = profile.coins,
		monster_level = st and st.team == "monster" and st.monsterLevel or nil,
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
	s.start = progress(profile)
	upsertSession(s, {
		is_new = profile._isNew == true,
		session_no = meta.sessions,
		days_since_last = (not profile._isNew and previous) and math.floor((os.time() - previous) / 864) / 100 or nil,
		start = s.start,
	})
	track(
		player,
		"loaded",
		{ seconds = math.floor((now() - s.t0) * 10) / 10, new = profile._isNew == true, phase = match:Phase() }
	)
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
	local summary = progress(profile)
	local start = s.start or summary
	summary.team = teams:Team(player) or s.team
	summary.phase = match:Phase()
	summary.idle_at_leave = s.idle == true
	summary.idle_seconds = s.idleSeconds
	summary.seconds_since_action = math.floor(now() - s.lastActionAt)
	summary.matches_session = s.matches
	summary.acts = s.acts or 0
	summary.specials = s.specials or 0
	for _, k in { "coins", "built", "beaten", "dwarves_beaten", "broken", "mined", "matches" } do
		summary[k .. "_gained"] = (summary[k] or 0) - (start[k] or 0)
	end
	if duration <= 60 then
		track(s, "left_first_minute", { phase = summary.phase, team = summary.team })
	end
	summary.counts = s.counts
	summary.taps = s.taps
	summary.last_actions = s.last
	track(
		s,
		"leave",
		{ reason = reason, last = s.last, team = summary.team, idle = summary.idle_at_leave, phase = summary.phase }
	)
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
