--[[
Analytics: every play session and what players do in it, so we can see whether people get the game in their first
matches, build, fight, win and come back. Same pipeline as the studio's other games: rows go to Supabase through
the roblox-analytics function, tagged game = "ra9" (Constants.ANALYTICS_GAME), in the same format ra8 sends.
  roblox_sessions  one row per session: new or returning, session number, days since the last one, country,
                   device, how they joined, friends in the server, progress at the start; at the end what they did,
                   how long they stayed, what they were doing when they left, idle or not, what happened last
  roblox_events    one row per thing that happened, with seconds since the session started:
                     loading: join, loaded, left_while_loading
                     the first matches: first_shot, first_build, first_kill, first_win, left_first_minute
                     matches: match_start (map), match_end (won or lost, kills, deaths, assists, built, MVP)
                     fighting: kill, down, assist; building: build; teams: team
                     the helps: shield_granted (downs), shield_broken (by), shield_expired (why: kill, time,
                       down), new_help (matches, level, device: their first matches' extra help, once a match)
                     progress: ladder (a step of the 100-win ladder), earned (a goal, VIP, an MVP reward)
                     buying: purchase (Robux), shard_buy (Shards)
                     the winners' cards: feedback_asked, feedback (the "liking the game?" answer), like_card
                     the anti-cheat: anticheat, kicked; requests the client sends (not shots or moves)
                     anything another service reports with AnalyticsService.event (the tutorial's steps:
                       tutorial_step, tutorial_done)
                     a snapshot every 30 s (and the live row the team dashboard reads): team, phase, map, kills,
                       deaths, weapon, alive, wins, ladder, tier, shards, device, idle
                     the leave
Every event but the snapshots carries ctx: where the player was in the game when it happened (team, phase, map,
alive, weapon, the match's kills and deaths, what they were doing), so the last event says where we lost someone.
Uses the same "discord_log" secret as the game log (GameKey). Nothing is sent in Studio (unless GAME_LOG_IN_STUDIO).

  AnalyticsService.event(player, name, data)   for other services: one event for a player (ignored for bots)
]]
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Ladder = require(ReplicatedStorage.Shared.Data.Ladder)
local Net = require(ReplicatedStorage.Shared.Net)
local Season = require(ReplicatedStorage.Shared.Data.Season)
local Signal = require(ReplicatedStorage.Shared.Signal)
local GameKey = require(script.Parent.Parent.GameKey)

local AnalyticsService = {
	Name = "AnalyticsService",
	Dependencies = {
		"PlayerDataService",
		"TeamService",
		"MatchService",
		"CombatService",
		"BuildService",
		"ShopService",
		"ProgressService",
		"SeasonService",
		"FeedbackService",
		"AntiCheatService",
		"InviteService",
	},
}

local data, teams, match, combat, season, registryRef
local sessions = {} -- [player] = session
local queue = { sessions = {}, events = {} }
local MAX_EVENTS = 3000
local map, matchId, matchStartedAt
-- requests that are moves, shots or bookkeeping, not decisions (counted another way, or not at all)
local SKIP_REQUESTS = {
	Ready = true,
	Draw = true,
	Shoot = true,
	Swing = true,
	Reload = true,
	Build = true,
	Sprint = true,
	Slide = true,
	Crouch = true,
	Analytics = true,
}
local QUIET = { snapshot = true, ui = true, perf = true, focus = true }

local function now()
	return os.clock()
end

local function iso(t)
	return os.date("!%Y-%m-%dT%H:%M:%SZ", t)
end

local function real(player)
	return typeof(player) == "Instance" -- (BotService's stand-ins are tables)
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

-- Where a player is in the game right now: { team, phase, map, alive, weapon, kills, deaths, doing, step }.
local function context(s)
	local player = s.player
	if not player or not player.Parent then
		return nil
	end
	local profile = data and data:Get(player)
	local tut = profile and type(profile.tutorial) == "table" and profile.tutorial or nil
	return {
		team = teams:Team(player),
		phase = match:Phase(),
		map = map,
		alive = combat:Alive(player),
		weapon = s.weapon,
		kills = s.match.kills,
		deaths = s.match.deaths,
		doing = s.doing,
		step = tut and not tut.done and tut.step or nil,
	}
end
AnalyticsService.context = context

-- Log one event for a player (or a session table).
function AnalyticsService.track(player, kind, extra)
	local s = type(player) == "table" and player.t0 and player or sessions[player]
	if not s or #queue.events >= MAX_EVENTS then
		return
	end
	if type(extra) ~= "table" then
		extra = extra ~= nil and { value = extra } or {}
	else
		extra = table.clone(extra)
	end
	if not QUIET[kind] then
		extra.ctx = context(s)
	end
	table.insert(queue.events, {
		session_id = s.id,
		user_id = s.userId,
		t = math.floor((now() - s.t0) * 10) / 10,
		kind = kind,
		data = extra,
	})
	if not QUIET[kind] then
		if kind ~= "leave" then
			s.doing = kind == "request" and string.lower(tostring(extra.name or "request")) or kind
		end
		s.counts[kind] = (s.counts[kind] or 0) + 1
		table.insert(s.last, kind)
		if #s.last > 12 then
			table.remove(s.last, 1)
		end
		s.lastActionAt = now()
	end
end
local track = AnalyticsService.track

-- For other services (the tutorial, the admin tools...): one event for a player. Bots and unknown players are
-- ignored; data is kept small and plain.
function AnalyticsService.event(player, name, payload)
	if not real(player) or type(name) ~= "string" or name == "" then
		return
	end
	track(player, string.sub(name, 1, 40), clean(payload) or {})
end

-- Send one batch (tests replace this). Returns true if it went out.
function AnalyticsService.send(payload)
	if RunService:IsStudio() and not Constants.GAME_LOG_IN_STUDIO then
		return false
	end
	return GameKey.post(Constants.ANALYTICS_URL, payload, "Analytics")
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

local function tierOf(player)
	local st = season:State(player)
	return st and Season.tierOf(st.xp) or 0
end

local function progressOf(player, profile)
	local st = profile.stats
	local tut = type(profile.tutorial) == "table" and profile.tutorial or nil
	return {
		wins = profile.wins,
		streak = profile.streak,
		best = profile.best,
		ladder = math.min(profile.wins, #Ladder.steps),
		tier = tierOf(player),
		shards = profile.shards or 0,
		vip = profile.vip == true,
		matches = st.matches,
		losses = st.losses,
		kills = st.kills,
		deaths = st.deaths,
		assists = st.assists,
		built = st.built,
		shots = st.shots,
		headshots = st.headshots,
		mvps = st.mvps,
		robux = st.robux or 0,
		tutorial_step = tut and tut.step or nil,
		tutorial_done = tut and tut.done == true or nil,
	}
end

local function joinSource(player)
	local source = "direct"
	pcall(function()
		local jd = player:GetJoinData()
		local td = jd and jd.TeleportData
		if type(td) == "table" and type(td.from) == "string" then
			source = "teleport:" .. string.sub(td.from, 1, 20)
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

local function freshMatch()
	return { kills = 0, deaths = 0, assists = 0, built = 0, shots = 0 }
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
		player = player,
		t0 = now(),
		startedAt = os.time(),
		counts = {},
		last = {},
		taps = {},
		firsts = {},
		match = freshMatch(),
		totals = { kills = 0, deaths = 0, assists = 0, built = 0, shots = 0, matches = 0, wins = 0, losses = 0 },
		lastActionAt = now(),
		lastMoveAt = now(),
		lastInputAt = now(),
		idleSeconds = 0,
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
	track(s, "join", { players = #Players:GetPlayers() })
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

local function add(s, k, n)
	s.match[k] = (s.match[k] or 0) + (n or 1)
	s.totals[k] = (s.totals[k] or 0) + (n or 1)
end

local function setDevice(s, device)
	if type(device) == "string" and device ~= s.device then
		s.device = string.sub(device, 1, 16)
		upsertSession(s, { device = s.device })
	end
end

-- A stand-in for a service that isn't running in this place (the lobby has no match, teams, building, feedback
-- or invite card): its signals never fire, and the methods given answer for it
local function quiet(methods)
	return setmetatable(methods or {}, {
		__index = function(t, k)
			local sig = Signal.new("AnalyticsService.quiet." .. tostring(k))
			rawset(t, k, sig)
			return sig
		end,
	})
end

function AnalyticsService:Init(registry)
	registryRef = registry
	data = registry.PlayerDataService
	teams = registry.TeamService or quiet({ Team = function() end })
	match = registry.MatchService or quiet({
		Phase = function()
			return Constants.MODE
		end,
	})
	combat = registry.CombatService
	season = registry.SeasonService
	local build = registry.BuildService or quiet()
	local shop = registry.ShopService
	local progress = registry.ProgressService
	local feedback = registry.FeedbackService or quiet()
	local anticheat = registry.AntiCheatService
	map = workspace:GetAttribute("MapKey")
	anticheat.Flagged:Connect(function(player, kind, detail, strikes)
		track(player, "anticheat", { what = kind, detail = detail, strikes = strikes })
	end)
	anticheat.Kicked:Connect(function(player, reason)
		track(player, "kicked", { reason = reason })
	end)
	-- matches
	match.Started:Connect(function(key, id)
		map, matchId, matchStartedAt = key, id, now()
		for player, s in sessions do
			s.match = freshMatch()
			if s.ready then
				track(player, "match_start", { map = key, match = id, team = teams:Team(player) })
			end
		end
	end)
	match.Ended:Connect(function(winner, results)
		local rows = {}
		for _, row in results.rows or {} do
			rows[row.userId] = row
		end
		for player, s in sessions do
			local team = teams:Team(player)
			if s.ready and team then
				local won = team == winner
				local row = rows[player.UserId] or {}
				s.totals.matches += 1
				if won then
					s.totals.wins += 1
				else
					s.totals.losses += 1
				end
				track(player, "match_end", {
					won = won,
					winner = winner,
					map = map,
					match = matchId,
					kills = row.kills or s.match.kills,
					deaths = row.deaths or s.match.deaths,
					assists = row.assists or s.match.assists,
					built = row.built or s.match.built,
					mvp = results.mvpPlayer == player,
					match_seconds = matchStartedAt and math.floor(now() - matchStartedAt) or nil,
				})
				if won then
					first(player, "first_win", { map = map, kills = row.kills })
				end
			end
		end
	end)
	-- fighting
	combat.Shot:Connect(function(player, weapon)
		local s = sessions[player]
		if s then
			s.weapon = weapon
			add(s, "shots")
			first(player, "first_shot", { weapon = weapon })
		end
	end)
	combat.Killed:Connect(function(victim, killer, info)
		info = info or {}
		local counted = match:Phase() == "fight"
			and killer ~= nil
			and killer ~= victim
			and teams:Team(killer) ~= nil
			and teams:Team(killer) ~= teams:Team(victim)
		local vs = sessions[victim]
		if vs then
			add(vs, "deaths")
			track(victim, "down", {
				by = killer == nil and (info.kind or "world") or (real(killer) and "player" or "bot"),
				weapon = killer and info.weapon or nil,
				head = info.head == true or nil,
			})
		end
		local ks = killer and sessions[killer]
		if ks and counted then
			add(ks, "kills")
			track(killer, "kill", { weapon = info.weapon, head = info.head == true, bot = not real(victim) })
			first(killer, "first_kill", { weapon = info.weapon })
		end
		if counted then
			for _, a in info.assists or {} do
				local as = sessions[a]
				if as and teams:Team(a) == teams:Team(killer) then
					add(as, "assists")
					track(a, "assist")
				end
			end
		end
	end)
	-- the easier-fight helps: the comeback shield (granted, broken, expired) and the new-player help (once a match)
	combat.Shield:Connect(function(player, what, detail)
		AnalyticsService.event(player, "shield_" .. tostring(what), detail)
	end)
	combat.Helped:Connect(function(player, detail)
		AnalyticsService.event(player, "new_help", detail)
	end)
	-- building
	build.Built:Connect(function(player, structure)
		local s = sessions[player]
		if s then
			add(s, "built")
			track(player, "build", { key = structure.key })
			first(player, "first_build", { key = structure.key })
		end
	end)
	teams.Changed:Connect(function(player, team, old)
		if old ~= nil then
			track(player, "team", { team = team, old = old })
		end
	end)
	-- progress and buying
	progress.Unlocked:Connect(function(player, step)
		track(player, "ladder", { win = step.win, key = step.key, kind = step.kind, big = step.big == true })
	end)
	progress.Earned:Connect(function(player, key)
		track(player, "earned", { key = key })
	end)
	shop.Bought:Connect(function(player, what, shards, robux)
		if robux then
			track(player, "purchase", { product = what, robux = robux })
		else
			track(player, "shard_buy", { item = what, shards = shards })
		end
	end)
	-- the winners' cards
	feedback.Asked:Connect(function(player, kind)
		track(player, "feedback_asked", { kind = kind, minutes = math.floor((seconds(player) or 0) / 6) / 10 })
	end)
	-- the free match-end gifts (GiftService): given, and worn from the locker (did the end screen teach them?)
	local gifts = registry.GiftService
	if gifts then
		gifts.Gifted:Connect(function(player, it, n)
			track(player, "gift", { key = it.key, kind = it.kind, rarity = it.rarity, n = n })
		end)
		gifts.Worn:Connect(function(player, kind, key)
			track(player, "gift_equipped", { key = key, kind = kind })
		end)
	end
	feedback.Answered:Connect(function(player, kind, answer, reasons)
		local s = sessions[player]
		if kind == "enjoy" then
			track(player, "feedback", {
				like = answer == true,
				reasons = reasons,
				minutes = math.floor((seconds(player) or 0) / 6) / 10,
				matches = s and s.totals.matches or nil,
				wins = s and s.totals.wins or nil,
				kills = s and s.totals.kills or nil,
				deaths = s and s.totals.deaths or nil,
				fps = s and s.fps or nil,
				device = s and s.device or nil,
			})
		else
			track(player, "like_card", { answer = answer })
		end
	end)
	-- the invite-a-friend card: shown (and why), sent or put off, and the effect won when a friend came
	local invite = registry.InviteService or quiet()
	invite.PromoShown:Connect(function(player, why)
		track(player, "invite_prompt_shown", { why = why })
	end)
	invite.PromoAnswered:Connect(function(player, what, recipients)
		if what == "sent" then
			track(player, "invite_prompt_sent", { recipients = recipients })
		else
			track(player, "invite_prompt_later")
		end
	end)
	invite.Rewarded:Connect(function(player, key, friendId)
		track(player, "invite_reward", { key = key, friend = friendId })
	end)
	-- the client's requests, device, frame rate, focus
	Net.tap(function(player, name, a, b)
		local s = sessions[player]
		if not s then
			return
		end
		s.lastInputAt = now()
		if name == "Settings" and a == "device" then
			setDevice(s, b)
		elseif name == "Equip" and type(a) == "string" then
			s.weapon = string.sub(a, 1, 24)
			track(player, "request", { name = name, arg = s.weapon })
		elseif not SKIP_REQUESTS[name] then
			track(player, "request", { name = name, arg = clean(a) })
		end
	end)
	Net.on("Analytics", function(player, kind, payload)
		local s = sessions[player]
		if not s or type(kind) ~= "string" then
			return
		end
		payload = clean(payload) or {}
		if kind == "client_info" or kind == "device" then
			setDevice(s, payload.device)
			upsertSession(s, {
				platform = payload.platform,
				screen = payload.screen,
				touch = payload.touch,
				gamepad = payload.gamepad,
				vr = payload.vr,
			})
			track(player, "ui_ready", payload)
		elseif kind == "taps" or kind == "ui" then
			local kinds = 0
			for _ in s.taps do
				kinds += 1
			end
			for k, n in type(payload.taps) == "table" and payload.taps or payload do
				-- (short names and plain counts only, and at most 60 kinds a visit: a client can't flood it)
				if type(k) == "string" and #k <= 32 and type(n) == "number" and n == n and n >= 0 and n <= 1000 then
					if s.taps[k] == nil and kinds < 60 then
						kinds += 1
						s.taps[k] = 0
					end
					if s.taps[k] then
						s.taps[k] += math.floor(n)
					end
				end
			end
			track(player, "ui", payload)
		elseif kind == "perf" then
			-- (the client's frame rate: kept for the snapshots and the session summary, and logged)
			if
				type(payload.fps) == "number"
				and payload.fps == payload.fps
				and payload.fps >= 0
				and payload.fps < 1000
			then
				s.fps = math.floor(payload.fps * 10 + 0.5) / 10
				s.fpsLow = type(payload.low) == "number" and math.floor(payload.low) or nil
				s.fpsSum = (s.fpsSum or 0) + s.fps
				s.fpsN = (s.fpsN or 0) + 1
			end
			track(player, kind, payload)
		elseif kind == "focus" then
			track(player, kind, payload)
		elseif kind == "shop" then
			-- the panel opened (or changed tab): shop_open with the tab, and what opened it (from: "first_match",
			-- "results_strip", "deck_sign"; nil for the buttons and keys)
			track(player, "shop_open", {
				tab = type(payload.tab) == "string" and string.sub(payload.tab, 1, 16) or nil,
				opening = payload.opening == true,
				from = type(payload.from) == "string" and string.sub(payload.from, 1, 16) or nil,
			})
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		if not sessions[player] then
			begin(player)
		end
	end)
	-- every Robux prompt's end: bought or backed out (the funnel's last step)
	pcall(function()
		local Market = game:GetService("MarketplaceService")
		Market.PromptProductPurchaseFinished:Connect(function(userId, productId, bought)
			local player = Players:GetPlayerByUserId(userId)
			if player then
				track(player, "prompt_closed", { product = productId, bought = bought == true, pass = false })
			end
		end)
		Market.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
			track(player, "prompt_closed", { product = passId, bought = bought == true, pass = true })
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local s = sessions[player]
		if s and not s.ready then
			track(s, "left_while_loading", { seconds = math.floor(now() - s.t0) })
			upsertSession(
				s,
				{ ended_at = iso(os.time()), duration_s = math.floor(now() - s.t0), end_reason = "left_while_loading" }
			)
			sessions[player] = nil
		end
	end)
end

function AnalyticsService:_watch()
	for player, s in sessions do
		local c = player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r then
			local pos = r.Position
			if s.lastPos and (pos - s.lastPos).Magnitude > 1 then
				s.lastMoveAt = now()
			end
			s.lastPos = pos
		end
		local idle = now() - math.max(s.lastMoveAt, s.lastInputAt) >= Constants.ANALYTICS_IDLE_SECONDS
		if idle then
			s.idleSeconds += 1
		end
		if idle ~= (s.idle == true) then
			s.idle = idle
			track(player, idle and "went_idle" or "came_back_from_idle")
		end
	end
end

-- The player's live row for the team's dashboard (other/live.html reads these field names).
function AnalyticsService:Live(player)
	local s = sessions[player]
	local profile = data:Get(player)
	if not s or not profile then
		return nil
	end
	local alive = combat:Alive(player)
	if alive then
		s.weapon = combat:Weapon(player) -- (only read while it has a combat state: reading makes one)
	end
	local tut = type(profile.tutorial) == "table" and profile.tutorial or nil
	local live = {
		team = teams:Team(player),
		phase = match:Phase(),
		map = map,
		fps = s.fps,
		fps_low = s.fpsLow,
		kills = s.match.kills,
		deaths = s.match.deaths,
		assists = s.match.assists,
		weapon = s.weapon,
		alive = alive,
		wins = profile.wins,
		streak = profile.streak,
		ladder = math.min(profile.wins, #Ladder.steps),
		tier = tierOf(player),
		shards = profile.shards or 0,
		device = s.device or player:GetAttribute("Device"),
		idle = s.idle == true,
		server_players = #Players:GetPlayers(),
		matches = s.totals.matches,
		session_wins = s.totals.wins,
		tutorial_step = tut and not tut.done and tut.step or nil,
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
	-- (AdminService is optional: looked up now, never a dependency)
	local admin = registryRef and registryRef.AdminService
	if type(admin) == "table" and type(admin.Used) == "table" and admin.Used.Connect then
		admin.Used:Connect(function(player, action, detail)
			AnalyticsService.event(player, "admin", { action = action, detail = detail })
		end)
	end
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
	s.start = progressOf(player, profile)
	setDevice(s, player:GetAttribute("Device"))
	upsertSession(s, {
		is_new = profile._isNew == true,
		session_no = meta.sessions,
		days_since_last = (not profile._isNew and previous) and math.floor((os.time() - previous) / 864) / 100 or nil,
		start = s.start,
	})
	track(player, "loaded", {
		seconds = math.floor((now() - s.t0) * 10) / 10,
		new = profile._isNew == true,
		phase = match:Phase(),
		map = map,
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
	local ctx = context(s) or {}
	sessions[player] = nil
	local duration = math.floor(now() - s.t0)
	local summary = progressOf(player, profile)
	local start = s.start or summary
	summary.team = ctx.team
	summary.phase = ctx.phase
	summary.map = map
	summary.idle_at_leave = s.idle == true
	summary.idle_seconds = s.idleSeconds
	summary.seconds_since_action = math.floor(now() - s.lastActionAt)
	summary.matches_session = s.totals.matches
	summary.wins_session = s.totals.wins
	summary.kills_session = s.totals.kills
	summary.deaths_session = s.totals.deaths
	summary.built_session = s.totals.built
	summary.shots_session = s.totals.shots
	summary.fps_avg = s.fpsN and math.floor(s.fpsSum / s.fpsN * 10 + 0.5) / 10 or nil
	summary.fps_low = s.fpsLow
	for _, k in { "wins", "ladder", "tier", "shards", "kills", "deaths", "built", "matches", "mvps", "robux" } do
		summary[k .. "_gained"] = (summary[k] or 0) - (start[k] or 0)
	end
	if duration <= 60 then
		track(s, "left_first_minute", { phase = ctx.phase })
	end
	summary.counts = s.counts
	summary.taps = s.taps
	summary.last_actions = s.last
	summary.step = ctx.step
	summary.doing = s.doing
	track(s, "leave", {
		reason = reason,
		last = s.last,
		phase = ctx.phase,
		team = ctx.team,
		idle = summary.idle_at_leave,
		step = summary.step,
		doing = summary.doing,
		minutes = math.floor(duration / 6) / 10,
	})
	upsertSession(s, { ended_at = iso(os.time()), duration_s = duration, end_reason = reason, summary = summary })
end

function AnalyticsService:OnPlayerLeaving(player, profile)
	self:_end(player, profile, "left")
end

-- (tests)
function AnalyticsService:Session(player)
	return sessions[player]
end

return AnalyticsService
