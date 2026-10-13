-- Analytics: every play session and everything players do in it, so we can see whether people understand the
-- game, come back, and build the habit (their cabin, the crew's journey). Same pipeline as Steal a Dragon: rows go
-- to Supabase through the roblox-analytics function, tagged game = "ra5".
--   roblox_sessions  one row per session: new or returning, session number, days since the last one, country,
--                    device, how they joined, friends in the server, progress at the start; at the end what they
--                    did, how long they stayed, where they were, idle or not, what happened last
--   roblox_events    one row per thing that happened, with seconds since the session started:
--                      loading (joined, loaded, UI ready, left while loading)
--                      every request the client sends, every proximity prompt used
--                      the core loop: stepped_out (left the train at a stop), collect, bag_full, bank,
--                      made_it_back (outside at this stop and aboard when the doors shut), stranded, recovery steps,
--                      recovered, bag_lost
--                      the cabin: color, built (first time) / restyled, salvage
--                      the crew: deposit, train_upgrade, milestone, stop_reached (with how many this session),
--                      expedition_start / expedition_end, record
--                      friends: friend_friend / friend_retry / friend_new / friend_rejoin attempts and their results
--                      tutorial steps shown and finished, done or skipped
--                      button taps (batched), frame rate and window focus (from the client)
--                      a snapshot every 30 s (and the live row the team dashboard reads): zone, phase, bag, cabin,
--                      distance, stops, idle
--                      the leave
-- The first-session funnel (plan section 22): tutorial_step 1 shown -> color -> stepped_out -> collect ->
-- made_it_back / bank -> built -> deposit -> stop_reached n=2 -> friend_*.
-- Uses the same "discord_log" secret as the game log. Nothing is sent in Studio (unless GAME_LOG_IN_STUDIO).
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)

local AnalyticsService = {
	Name = "AnalyticsService",
	Dependencies = {
		"PlayerDataService",
		"ExpeditionService",
		"TrainService",
		"CabinService",
		"ResourceService",
		"RecoveryService",
		"RecordService",
		"JoinService",
		"TutorialService",
		"AntiCheatService",
	},
}

local data, expedition, cabins, resources, recovery, tutorial, records
local sessions = {} -- [player] = session
local queue = { sessions = {}, events = {} }
local secret -- the key from the Secrets Store, or false if there isn't one
local MAX_EVENTS = 3000

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

-- Where a player is right now: station, train, cabin (their own), outside (at a stop), stranded, recovery (signal
-- sent, waiting for the trolley) or none.
function AnalyticsService.zoneOf(player)
	if recovery:IsStranded(player) then
		local st = recovery:State(player)
		return st and st.step == "waiting" and "recovery" or "stranded"
	end
	local pos = expedition:Position(player)
	if not pos then
		return "none"
	end
	if Layout.inTrain(pos) then
		local i = cabins:IndexOf(player)
		local cabin = i and Layout.cabins[i]
		if cabin and math.abs(pos.X - cabin.center.X) <= Layout.CABIN_LEN / 2 and pos.Z > Layout.CORRIDOR_Z then
			return "cabin"
		end
		return "train"
	end
	if expedition:Phase() == "lobby" then
		return "station"
	end
	return "outside"
end
local zoneOf = AnalyticsService.zoneOf

local function progress(profile)
	local st = profile.stats
	local plans = 0
	for _, n in profile.blueprints do
		plans += n
	end
	return {
		storage = table.clone(profile.storage),
		blueprints = plans,
		cabin = Formulas.cabinCount(profile.cabin.built),
		color = profile.cabin.color,
		best_km = profile.best or 0,
		expeditions = st.expeditions,
		stops = st.stops,
		collected = st.collected,
		banked = st.banked,
		lost = st.lost,
		stranded = st.stranded,
		recovered = st.recovered,
		deposited = st.deposited,
		fuel = st.fuel,
		builds = st.builds,
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
		stops = 0, -- stops reached this session
		kmStart = nil,
		outAt = nil, -- the stop number they stepped out at (for made_it_back)
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
	track(s, "join", { players = #Players:GetPlayers(), phase = expedition:Phase() })
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

function AnalyticsService:Init(registry)
	data = registry.PlayerDataService
	expedition = registry.ExpeditionService
	cabins = registry.CabinService
	resources = registry.ResourceService
	recovery = registry.RecoveryService
	tutorial = registry.TutorialService
	records = registry.RecordService
	local train = registry.TrainService
	local join = registry.JoinService
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
			upsertSession(s, { ended_at = iso(os.time()), duration_s = math.floor(now() - s.t0), end_reason = "left_loading" })
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

	-- everything the client asks the server to do
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
		if name == "Ready" or name == "Friends" then
			return
		end
		track(player, "req_" .. string.lower(name), { a = clean(a), b = clean(b) })
	end)

	-- proximity prompts: piles, building, the door sign, the train board, fuses...
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local s = sessions[player]
		if s then
			s.lastInputAt = now()
		end
		track(player, "prompt", { name = prompt.Name, action = prompt.ActionText, object = prompt.ObjectText, zone = zoneOf(player) })
	end)

	-- the core loop
	resources.Collected:Connect(function(player, kind, amount, far)
		local s = sessions[player]
		if s then
			s.collected = (s.collected or 0) + amount
		end
		local stop = expedition:State() and expedition:State().stop
		track(player, "collect", { kind = kind, amount = amount, far = far, stop = stop and stop.key, bag = resources:BagCount(player) })
	end)
	resources.BagFull:Connect(function(player)
		track(player, "bag_full", { cap = resources:Capacity(player) })
	end)
	resources.Banked:Connect(function(player, items, plans)
		track(player, "bank", { items = clean(items), plans = clean(plans) })
	end)
	resources.Lost:Connect(function(player, n)
		track(player, "bag_lost", { n = n })
	end)
	recovery.Stranded:Connect(function(player, lost)
		local stop = expedition:State() and expedition:State().stop
		track(player, "stranded", { lost = lost, stop = stop and stop.key })
	end)
	recovery.Step:Connect(function(player, step)
		track(player, "recovery_step", { step = step })
	end)
	recovery.Recovered:Connect(function(player, seconds)
		track(player, "recovered", { seconds = math.floor(seconds) })
	end)

	-- the cabin
	cabins.ColorSet:Connect(function(player, key, first)
		track(player, "color", { key = key, first = first == true })
	end)
	cabins.Built:Connect(function(player, key, variant, firstTime)
		local profile = data:Get(player)
		track(player, firstTime and "built" or "restyled", {
			key = key,
			variant = variant,
			cabin = profile and Formulas.cabinCount(profile.cabin.built) or nil,
		})
	end)
	cabins.Salvaged:Connect(function(player)
		track(player, "salvage")
	end)

	-- the crew and the journey
	train.Deposited:Connect(function(player, key, resource, amount)
		track(player, "deposit", { key = key, resource = resource, amount = amount })
	end)
	train.Upgraded:Connect(function(key, stage, by)
		everyone(function(player)
			track(player, "train_upgrade", { key = key, stage = stage, mine = by == player })
		end)
	end)
	expedition.Started:Connect(function(exp)
		everyone(function(player)
			track(player, "expedition_start", { n = exp.number })
		end)
	end)
	expedition.Arrived:Connect(function(stop)
		everyone(function(player, s)
			if not recovery:IsStranded(player) then
				s.stops += 1
				track(player, "stop_reached", { stop = stop.key, n = s.stops, km = expedition:State().distance })
			end
		end)
	end)
	expedition.DoorsShut:Connect(function(atStop)
		if not atStop then
			return
		end
		everyone(function(player, s)
			if s.outAt and s.outAt == expedition:State().stops and not recovery:IsStranded(player) then
				track(player, "made_it_back", { bag = resources:BagCount(player) })
			end
			s.outAt = nil
		end)
	end)
	expedition.Milestone:Connect(function(km)
		everyone(function(player)
			track(player, "milestone", { km = km })
		end)
	end)
	expedition.Ended:Connect(function(exp)
		everyone(function(player)
			track(player, "expedition_end", { km = exp.distance, stops = exp.stops, reason = exp.reason })
		end)
	end)
	records.Saved:Connect(function(record, final)
		if not final then
			return
		end
		for _, m in record.crew do
			local p = Players:GetPlayerByUserId(m.userId)
			if p then
				track(p, "record", { km = record.km, stops = record.stops, crew = #record.crew })
			end
		end
	end)

	-- friends
	join.Attempted:Connect(function(player, kind)
		track(player, "friend_" .. kind)
	end)
	join.Result:Connect(function(player, kind, fields)
		track(player, "friend_result", { kind = kind, tries = fields and fields.tries })
	end)

	-- the tutorial
	tutorial.StepShown:Connect(function(player, step, total, key)
		track(player, "tutorial_step", { step = step, total = total, key = key })
	end)
	tutorial.StepDone:Connect(function(player, step, key, seconds)
		track(player, "tutorial_step_done", { step = step, key = key, seconds = math.floor(seconds) })
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

-- Every second: is each player moving? (idle = no moving and no input for a while). And did they step out?
function AnalyticsService:_watch()
	for player, s in sessions do
		local pos = expedition:Position(player)
		if pos then
			local zone = zoneOf(player)
			s.zone = zone -- remembered: the character is often gone by the time they leave
			if s.lastPos and (pos - s.lastPos).Magnitude > 1 then
				s.lastMoveAt = now()
			end
			s.lastPos = pos
			if s.ready and zone == "outside" and expedition:IsAtStop() then
				local n = expedition:State().stops
				if s.outAt ~= n then
					s.outAt = n
					local stop = expedition:State().stop
					track(player, "stepped_out", { stop = stop and stop.key, phase = expedition:Phase() })
				end
			end
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
	local exp = expedition:State()
	local live = {
		zone = zoneOf(player),
		phase = expedition:Phase(),
		bag = resources:BagCount(player),
		cabin = Formulas.cabinCount(profile.cabin.built),
		distance = Formulas.round1(expedition:Distance()),
		stops = exp and exp.stops or 0,
		idle = s.idle == true,
		best_km = profile.best or 0,
		fuel = expedition:Fuel(),
		tutorial_step = tutorial:Step(player),
		server_players = #Players:GetPlayers(),
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
	s.kmStart = expedition:Distance()
	s.expStart = expedition:State() and expedition:State().id
	upsertSession(s, {
		is_new = profile._isNew == true,
		session_no = meta.sessions,
		days_since_last = (not profile._isNew and previous) and math.floor((os.time() - previous) / 864) / 100 or nil,
		start = s.start,
	})
	track(player, "loaded", { seconds = math.floor((now() - s.t0) * 10) / 10, new = profile._isNew == true, phase = expedition:Phase() })
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
	local zoneNow = zoneOf(player)
	summary.zone = zoneNow ~= "none" and zoneNow or s.zone
	summary.phase = expedition:Phase()
	summary.idle_at_leave = s.idle == true
	summary.idle_seconds = s.idleSeconds
	summary.seconds_since_action = math.floor(now() - s.lastActionAt)
	summary.bag_at_leave = resources:BagCount(player)
	summary.stranded_at_leave = recovery:IsStranded(player)
	summary.stops_session = s.stops
	summary.collected_gained = summary.collected - (start.collected or 0)
	summary.banked_gained = summary.banked - (start.banked or 0)
	summary.lost_gained = summary.lost - (start.lost or 0)
	summary.builds_gained = summary.builds - (start.builds or 0)
	summary.deposited_gained = summary.deposited - (start.deposited or 0)
	summary.stranded_gained = summary.stranded - (start.stranded or 0)
	summary.cabin_gained = summary.cabin - (start.cabin or 0)
	-- the distance this train went while they were aboard (same expedition only)
	local exp = expedition:State()
	if exp and exp.id == s.expStart then
		summary.km_session = Formulas.round1(expedition:Distance() - (s.kmStart or 0))
	end
	summary.counts = s.counts
	summary.taps = s.taps
	summary.last_actions = s.last
	track(s, "leave", { reason = reason, last = s.last, zone = summary.zone, idle = summary.idle_at_leave, phase = summary.phase })
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
