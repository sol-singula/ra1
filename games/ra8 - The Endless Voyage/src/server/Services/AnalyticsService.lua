--[[
Analytics: every play session and everything players do in it, so we can see whether people get the game in the
first five minutes, build, sail, and come back (master plan §4, §6). Same pipeline as the studio's other games:
rows go to Supabase through the roblox-analytics function, tagged game = "ra8".
  roblox_sessions  one row per session: new or returning, session number, days since the last one, country,
                   device, how they joined, friends in the server, progress at the start; at the end what they did,
                   how long they stayed, where they were when they left, idle or not, what happened last
  roblox_events    one row per thing that happened, with seconds since the session started:
                     loading (join, loaded, ui_ready, left_while_loading)
                     the first five minutes (§4): first_cast, first_build, first_bench, first_craft, first_crate,
                       first_net, first_sail, first_island, first_home, the guide's steps, left_first_minute
                     the raft: built, demolished, painted, tier_up, broken, repaired
                     the ocean: fish, fish_away; voyages: sail, event, land, home; islands: gather, search, look,
                       puzzle; creatures: kill, hurt, down, lost_bag, bag_back; crafting: craft, research,
                       milestone; progress: level_up, achievement, blueprint, chart, discovery; visits; friends;
                       requests the client sends (not the acts themselves: too many), prompts, panels opened
                     button taps (batched), frame rate and window focus (from the client)
                     a snapshot every 30 s (and the live row the team dashboard reads): where, voyage, tier,
                       tiles, level, voyages, found, hp, idle
                     the leave
Every event but the snapshots carries ctx: where the player was in the game when it happened (the guide's step, what
they were doing, where they stood, the voyage, the raft's tiles and tier, their level), so any event, and the last one
above all, says where we lost someone. Every event also goes to the Discord log as a line (GameLogService.activity).
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
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local GameKey = require(script.Parent.Parent.GameKey)

local AnalyticsService = {
	Name = "AnalyticsService",
	Dependencies = {
		"PlayerDataService",
		"RaftService",
		"InventoryService",
		"PlayerService",
		"OceanService",
		"CraftService",
		"IslandService",
		"VoyageService",
		"CreatureService",
		"WeatherService",
		"TutorialService",
		"ProgressService",
		"VisitService",
		"JoinService",
		"AntiCheatService",
	},
}

local data, rafts, players, voyages, weather, progress, ocean, inventoryRef, tutorialRef, registryRef
local sessions = {} -- [player] = session
local queue = { sessions = {}, events = {} }
local MAX_EVENTS = 3000
-- requests that are moves or bookkeeping, not decisions (counted another way, or not at all)
local SKIP_REQUESTS = {
	Act = true,
	Reel = true,
	Ready = true,
	Friends = true,
	Analytics = true,
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

-- Where a player is in the game right now: { step, doing, where, voyage, tiles, tier, level }.
local function context(s)
	local player = s.player
	if not player or not player.Parent or not players then
		return nil
	end
	local profile = data and data:Get(player)
	local raft = rafts and rafts:RaftOf(player)
	local plot = players:Here(player)
	return {
		step = tutorialRef and tutorialRef:StepName(player) or nil,
		doing = s.doing,
		where = players:IsAlive(player) and players:Where(player) or "down",
		voyage = plot and voyages and voyages:State(plot) or nil,
		tiles = raft and raft.summary.tiles or nil,
		tier = raft and raft.tier or nil,
		level = profile and (Formulas.level(profile.xp)) or nil,
	}
end
AnalyticsService.context = context

-- What a player is doing now, from an event (the next event's ctx.doing).
local function doingOf(kind, extra)
	if kind == "request" then
		return string.lower(tostring(extra.name or "request"))
	elseif kind == "panel" then
		return "panel " .. tostring(extra.panel or "?")
	end
	return kind
end

-- Log one event for a player (or a session table).
function AnalyticsService.track(player, kind, extra)
	local s = typeof(player) == "table" and player or sessions[player]
	if not s or #queue.events >= MAX_EVENTS then
		return
	end
	if type(extra) ~= "table" then
		extra = extra ~= nil and { value = extra } or {}
	else
		extra = table.clone(extra)
	end
	if kind ~= "snapshot" and kind ~= "perf" and kind ~= "focus" then
		extra.ctx = context(s)
	end
	local t = math.floor((now() - s.t0) * 10) / 10
	table.insert(queue.events, {
		session_id = s.id,
		user_id = s.userId,
		t = t,
		kind = kind,
		data = extra,
	})
	local log = registryRef and registryRef.GameLogService
	if log and log.activity and s.player then
		log.activity(s.player.DisplayName, t, kind, extra)
	end
	if kind ~= "snapshot" and kind ~= "ui" and kind ~= "perf" and kind ~= "focus" and kind ~= "leave" then
		s.doing = doingOf(kind, extra)
	end
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

local function progressOf(profile)
	local st, rec = profile.stats, profile.records
	local blueprints, known = 0, 0
	for _ in profile.blueprints do
		blueprints += 1
	end
	for _ in profile.known do
		known += 1
	end
	return {
		level = (Formulas.level(profile.xp)),
		xp = profile.xp,
		tier = rec.tier,
		tiles = rec.tiles,
		voyages = st.voyages,
		discoveries = rec.discoveries,
		fish = st.fish,
		debris = st.debris,
		built = st.built,
		crafted = st.crafted,
		research = st.research,
		leviathans = st.leviathans,
		deaths = st.deaths,
		blueprints = blueprints,
		charts = known,
		achievements = rec.achievementCount,
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
		lastActionAt = now(),
		lastMoveAt = now(),
		lastInputAt = now(),
		idleSeconds = 0,
		hooked = 0,
		firsts = {},
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

-- Where a player is, for the dashboard: raft | water | island | visiting | down.
function AnalyticsService:WhereOf(player)
	if not players:IsAlive(player) then
		return "down"
	end
	return players:Where(player)
end

function AnalyticsService:Init(registry)
	registryRef = registry
	tutorialRef = registry.TutorialService
	data = registry.PlayerDataService
	rafts = registry.RaftService
	players = registry.PlayerService
	voyages = registry.VoyageService
	weather = registry.WeatherService
	progress = registry.ProgressService
	ocean = registry.OceanService
	local inventory = registry.InventoryService
	inventoryRef = inventory
	local craft = registry.CraftService
	local island = registry.IslandService
	local creatures = registry.CreatureService
	local tutorial = registry.TutorialService
	local visits = registry.VisitService
	local join = registry.JoinService
	registry.AntiCheatService.Flagged:Connect(function(player, kind, detail, strikes)
		track(player, "anticheat", { what = kind, detail = detail, strikes = strikes })
	end)
	registry.AntiCheatService.Kicked:Connect(function(player, reason)
		track(player, "kicked", { reason = reason })
	end)
	-- the funnel and the raft
	ocean.Hooked:Connect(function(player, d, items)
		local s = sessions[player]
		if s then
			s.hooked += 1
			s.lastMoveAt = now()
		end
		first(player, "first_cast", { kind = d.kind })
		if d.special then
			track(player, "hooked_special", { kind = d.special })
		end
		_ = items
	end)
	rafts.Built:Connect(function(player, piece, raft)
		track(player, "built", { piece = piece.key, tiles = raft.summary.tiles, tier = raft.tier })
		first(player, "first_build", { piece = piece.key })
		if piece.key == "workbench" then
			first(player, "first_bench")
		elseif piece.key == "net" then
			first(player, "first_net")
		elseif piece.key == "helm" then
			first(player, "first_helm")
		end
	end)
	rafts.Demolished:Connect(function(player, piece)
		track(player, "demolished", { piece = piece.key })
	end)
	rafts.Painted:Connect(function(player, kind, key)
		track(player, "painted", { what = kind, colour = key })
	end)
	rafts.TierChanged:Connect(function(player, raft, tier, old)
		if player and sessions[player] and tier > old then
			track(player, "tier_up", { tier = tier, tiles = raft.summary.tiles, seconds = seconds(player) })
		end
	end)
	rafts.Broken:Connect(function(raft, piece, source)
		if raft.owner and sessions[raft.owner] then
			track(raft.owner, "broken", { piece = piece.key, by = source and source.kind })
		end
	end)
	rafts.Repaired:Connect(function(player, piece)
		track(player, "repaired", { piece = piece.key })
	end)
	-- the ocean
	ocean.Caught:Connect(function(player, fish)
		track(player, "fish", { fish = fish.key, rarity = fish.rarity })
		first(player, "first_fish", { fish = fish.key })
	end)
	ocean.Missed:Connect(function(player)
		track(player, "fish_away")
	end)
	inventory.Used:Connect(function(player, item, d)
		track(player, "use", { item = item.key, data = clean(d) })
		if item.key == "supply_crate" then
			first(player, "first_crate")
		end
	end)
	-- crafting
	craft.Crafted:Connect(function(player, r)
		track(player, "craft", { recipe = r.id, station = r.station })
		first(player, "first_craft", { recipe = r.id })
	end)
	craft.Researched:Connect(function(player, item, points, total)
		track(player, "research", { artifact = item.key, points = points, total = total })
	end)
	craft.Milestone:Connect(function(player, m)
		track(player, "milestone", { unlock = m.unlock.key, points = m.points })
	end)
	-- voyages
	voyages.Departed:Connect(function(plot, dest, aboard, home)
		for _, player in aboard do
			track(
				player,
				home and "sail_home" or "sail",
				{ dest = dest.key, danger = dest.danger, own = rafts:PlotOf(player) == plot }
			)
			if not home then
				first(player, "first_sail", { dest = dest.key })
			end
		end
	end)
	voyages.Event:Connect(function(_, e, here)
		for _, player in here do
			track(player, "event", { event = e.key })
		end
	end)
	voyages.Arrived:Connect(function(_, dest, here)
		for _, player in here do
			track(player, "land", { dest = dest.key })
			first(player, "first_island", { dest = dest.key })
		end
	end)
	voyages.Ended:Connect(function(_, dest, here, danger)
		for _, player in here do
			local s = sessions[player]
			if s then
				s.voyages = (s.voyages or 0) + 1
			end
			track(player, "home", { dest = dest and dest.key, danger = danger })
			first(player, "first_home")
		end
	end)
	voyages.Revealed:Connect(function(player, key, how)
		track(player, "chart", { dest = key, how = how })
	end)
	-- islands
	island.Gathered:Connect(function(player, node)
		track(player, "gather", { kind = node.kind })
		first(player, "first_gather", { kind = node.kind })
	end)
	island.Searched:Connect(function(player, c, _, isl)
		track(player, "search", { kind = c.kind, dest = isl.dest.key })
	end)
	island.Looked:Connect(function(player, isl, firstLook)
		if firstLook then
			track(player, "look", { dest = isl.dest.key })
		end
	end)
	island.Solved:Connect(function(_, isl, here)
		for _, player in here do
			track(player, "puzzle", { dest = isl.dest.key, kind = isl.puzzle.kind })
		end
	end)
	-- creatures and health
	creatures.Killed:Connect(function(c, killer)
		if killer and sessions[killer] then
			track(killer, "kill", { creature = c.kind, boss = c.boss })
		end
	end)
	players.Damaged:Connect(function(player, amount, source)
		local s = sessions[player]
		if s then
			s.hurt = (s.hurt or 0) + amount
		end
		_ = source
	end)
	players.Died:Connect(function(player, source, lost)
		track(player, "down", { by = source and source.kind, where = players:Where(player), lost = #lost })
		if #lost > 0 then
			track(player, "lost_bag", { items = #lost })
		end
	end)
	inventory.PickedUp:Connect(function(player, d)
		if d.lost then
			track(player, "bag_back", { own = d.owner == player })
		end
	end)
	-- progress
	progress.LeveledUp:Connect(function(player, level)
		track(player, "level_up", { level = level })
	end)
	progress.Achieved:Connect(function(player, key)
		track(player, "achievement", { key = key })
	end)
	progress.Learned:Connect(function(player, kind, key, how)
		track(player, "blueprint", { kind = kind, key = key, how = how })
	end)
	progress.Discovered:Connect(function(player, kind, key, isFirst)
		if isFirst then
			track(player, "discovery", { journal = kind, key = key })
		end
	end)
	-- the guide
	tutorial.StepShown:Connect(function(player, step, total, key)
		track(player, "guide_step", { step = step, total = total, key = key })
	end)
	tutorial.StepDone:Connect(function(player, step, key, took)
		track(player, "guide_done", { step = step, key = key, took = math.floor(took) })
	end)
	tutorial.Finished:Connect(function(player, skipped)
		track(player, skipped and "guide_skipped" or "guide_finished", { seconds = seconds(player) })
	end)
	-- visits and friends
	visits.Visited:Connect(function(player, hostId, host)
		track(player, "visit", { host = hostId })
		if host then
			track(host, "visitor", { who = player.UserId })
		end
	end)
	join.Attempted:Connect(function(player, kind)
		track(player, "friend_" .. kind)
	end)
	join.Result:Connect(function(player, kind, fields)
		track(player, "friend_result", { result = kind, name = fields.name, tries = fields.tries })
	end)
	weather.StormEnded:Connect(function(_, survivors)
		for _, player in survivors do
			track(player, "storm_survived")
		end
	end)
	-- the client's requests, prompts, panels, taps, frame rate, focus
	Net.tap(function(player, name, a)
		local s = sessions[player]
		if not s then
			return
		end
		s.lastInputAt = now()
		if name == "Act" or name == "Reel" then
			s.acts = (s.acts or 0) + 1
			local item
			if inventoryRef then
				_, item = inventoryRef:Selected(player)
			end
			s.doing = name == "Reel" and "reeling" or (item and (Items.toolKind(item) or item.key) or "act")
		elseif not SKIP_REQUESTS[name] then
			track(player, "request", { name = name, arg = clean(a) })
		end
	end)
	Net.on("Viewed", function(player, panel)
		if type(panel) == "string" then
			track(player, "panel", { panel = string.sub(panel, 1, 24) })
			first(player, "first_panel_" .. string.sub(panel, 1, 16))
		end
	end)
	Net.on("Analytics", function(player, kind, payload)
		local s = sessions[player]
		if not s or type(kind) ~= "string" then
			return
		end
		payload = clean(payload) or {}
		if kind == "client_info" or kind == "device" then
			upsertSession(s, {
				device = payload.device,
				platform = payload.platform,
				screen = payload.screen,
				touch = payload.touch,
				gamepad = payload.gamepad,
				vr = payload.vr,
				lite = payload.lite,
			})
			track(player, "ui_ready", payload)
		elseif kind == "taps" then
			for name, n in payload do
				if type(n) == "number" then
					s.taps[name] = (s.taps[name] or 0) + n
				end
			end
			track(player, "ui", payload)
		elseif kind == "perf" then
			track(player, "perf", payload)
		elseif kind == "focus" then
			track(player, "focus", payload)
			if payload.focused == true then
				s.lastInputAt = now()
			end
		end
	end)
	pcall(function()
		ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
			local s = sessions[player]
			if s then
				s.lastInputAt = now()
				track(
					player,
					"prompt",
					{ kind = prompt:GetAttribute("Kind"), text = prompt.ActionText, object = prompt.ObjectText }
				)
			end
		end)
	end)
	Players.PlayerAdded:Connect(function(player)
		if not sessions[player] then
			begin(player)
		end
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
		local pos = players:Position(player)
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
	local raft = rafts:RaftOf(player)
	local plot = players:Here(player)
	local st = players:State(player)
	local finds = 0
	for _, n in inventoryRef:Finds(player) do
		finds += n
	end
	local live = {
		where = self:WhereOf(player),
		voyage = plot and voyages:State(plot) or "docked",
		dest = plot and voyages:Get(plot).dest and voyages:Get(plot).dest.key or nil,
		tier = raft and raft.tier or 1,
		tiles = raft and raft.summary.tiles or 0,
		level = (Formulas.level(profile.xp)),
		voyages = profile.stats.voyages,
		found = finds,
		hp = st and math.floor(st.hp or 0) or nil,
		phase = weather:Phase(),
		storm = plot and weather:StormAt(plot) ~= nil or false,
		idle = s.idle == true,
		server_players = #Players:GetPlayers(),
		tutorial_step = profile.tutorial.done and nil or profile.tutorial.step,
		hooked = s.hooked,
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
	track(player, "loaded", { seconds = math.floor((now() - s.t0) * 10) / 10, new = profile._isNew == true })
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
	local plot = players:Here(player)
	summary.where = self:WhereOf(player)
	summary.voyage = plot and voyages:State(plot) or "docked"
	summary.idle_at_leave = s.idle == true
	summary.idle_seconds = s.idleSeconds
	summary.seconds_since_action = math.floor(now() - s.lastActionAt)
	summary.voyages_session = s.voyages or 0
	summary.hooked_session = s.hooked
	summary.acts = s.acts or 0
	summary.hurt = s.hurt or 0
	for _, k in
		{
			"xp",
			"tier",
			"tiles",
			"voyages",
			"discoveries",
			"fish",
			"debris",
			"built",
			"crafted",
			"research",
			"blueprints",
			"charts",
		}
	do
		summary[k .. "_gained"] = (summary[k] or 0) - (start[k] or 0)
	end
	if duration <= 60 then
		track(s, "left_first_minute", { where = summary.where })
	end
	summary.counts = s.counts
	summary.taps = s.taps
	summary.last_actions = s.last
	local ctx = context(s) or {}
	summary.step = ctx.step
	summary.doing = s.doing
	track(s, "leave", {
		reason = reason,
		last = s.last,
		where = summary.where,
		voyage = summary.voyage,
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
