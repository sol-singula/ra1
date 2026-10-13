-- Analytics: every play session and everything players do in it, so we can see why people leave and what keeps the
-- ones who stay. Rows go to two Supabase tables through the roblox-analytics function:
--   roblox_sessions  one row per session: new or returning, session number, days since the last one, country,
--                    device, how they joined, friends in the server, progress at the start, and at the end what
--                    they did, how long they stayed, whether they were idle and what happened last
--   roblox_events    one row per thing that happened, with seconds since the session started:
--                      loading (joined, profile loaded, UI ready, left while loading)
--                      every request the client sends (lock, bonk, buy speed, buy weapon, daily, purchase...)
--                      every proximity prompt used (buy, steal, sell, level up, grab...)
--                      game events (bought a dragon, stole, got robbed, bonked, bonk received, hatched, castle grew,
--                      gift, fever, NPC raid, daily prize, combine...)
--                      tutorial goals shown and finished or skipped
--                      purchase prompts opened, and bought or closed
--                      button taps (batched), frame rate and window focus (from the client)
--                      a snapshot every minute: coins, income, dragons, castle, where they are, idle or not, ping
--                      the leave
-- Reports (views): roblox_retention, roblox_tutorial_funnel, roblox_last_actions, roblox_first_session_drivers,
-- roblox_session_lengths, roblox_ui_taps.
--
-- Uses the same "discord_log" secret as the game log. Nothing is sent in Studio (unless GAME_LOG_IN_STUDIO).
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)

local AnalyticsService = {
	Name = "AnalyticsService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"BaseService",
		"DragonService",
		"ShopService",
		"RoadService",
		"RewardService",
		"CombatService",
		"TutorialService",
		"PlaytimeService",
		"LeaderboardService",
		"NpcService",
		"ToolService",
		"ServerFillService",
	},
}

local data, economy, baseService, dragons, tutorial, fill
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

local function dragonInfo(id, special)
	local d = Dragons.byId[id]
	return { id = id, rarity = d and d.rarity or nil, special = special }
end

-- Session row fields (merged into the next batch; the function upserts by session_id).
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
	local t = now() - s.t0
	table.insert(queue.events, {
		session_id = s.id,
		user_id = s.userId,
		t = math.floor(t * 10) / 10,
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

-- Where a player is right now.
local function zoneOf(player)
	local pos = baseService:Position(player)
	if not pos then
		return "none"
	end
	local base = baseService:BaseAt(pos)
	if base then
		return base == baseService:Get(player) and "own_base" or "other_base"
	end
	if math.abs(pos.Z) < 26 then
		return "road"
	end
	return "open"
end

local function progress(player, profile)
	local base = baseService:Get(player)
	local income = 0
	pcall(function()
		income = baseService:Income(player)
	end)
	local best = 0
	local t = os.time()
	for _, rec in profile.dragons do
		best = math.max(best, Formulas.dragonIncome(rec, t))
	end
	return {
		coins = math.floor(profile.coins),
		earned = math.floor(profile.earned),
		income = math.floor(income),
		dragons = #profile.dragons,
		best_cps = math.floor(best),
		nests = profile.nestsBought,
		castle = base and base.world and base.world.castleLevel or nil,
		steals = profile.steals,
		speed = profile.speedLevel,
		weapon = profile.weaponLevel,
		potions = profile.potions,
		skins = (function()
			local n = 0
			for _ in profile.skins or {} do
				n += 1
			end
			return n
		end)(),
		tutorial_done = profile.tutorialDone,
		egg = profile.egg ~= nil,
		daily_streak = profile.daily and profile.daily.streak or 0,
		passes = (function()
			-- every pass Roblox says they own (bought in game, on the website Store tab, or the game's creator)
			local list, seen = {}, {}
			local owned = economy and economy:Passes(player) or {}
			for _, set in { profile.passes or {}, owned } do
				for k, v in set do
					if v and not seen[k] then
						seen[k] = true
						table.insert(list, k)
					end
				end
			end
			return list
		end)(),
	}
end

local function joinSource(player)
	local source = "direct"
	pcall(function()
		local jd = player:GetJoinData()
		if player.FollowUserId and player.FollowUserId ~= 0 then
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
		prompts = {},
		lastActionAt = now(),
		lastMoveAt = now(),
		lastInputAt = now(),
		idleSeconds = 0,
		robbedAt = nil,
	}
	sessions[player] = s
	upsertSession(s, {
		started_at = iso(s.startedAt),
		username = player.Name,
		display_name = player.DisplayName,
		server_no = fill and fill.number or nil,
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

function AnalyticsService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	baseService = registry.BaseService
	dragons = registry.DragonService
	tutorial = registry.TutorialService
	fill = registry.ServerFillService
	local shop = registry.ShopService
	local combat = registry.CombatService

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
			local moved = player:GetAttribute("FillMove")
			if moved then
				track(s, "moved_server", { to = moved })
			else
				track(s, "left_while_loading", { seconds = math.floor(now() - s.t0) })
			end
			upsertSession(s, {
				ended_at = iso(os.time()),
				duration_s = math.floor(now() - s.t0),
				end_reason = moved and "moved_to_fuller_server" or "left_loading",
			})
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
		if name == "Analytics" then
			local s = sessions[player]
			if not s or type(a) ~= "string" then
				return
			end
			s.lastInputAt = now()
			local payload = clean(b)
			if a == "client_info" and type(payload) == "table" then
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
		if name == "Ready" then
			return
		end
		local s = sessions[player]
		if s then
			s.lastInputAt = now()
		end
		track(player, "req_" .. string.lower(name), { a = clean(a), b = clean(b) })
	end)

	-- proximity prompts: buying, stealing, selling, levelling up, grabbing...
	local promptSignal = ProximityPromptService.PromptTriggered
	promptSignal:Connect(function(prompt, player)
		local s = sessions[player]
		if s then
			s.lastInputAt = now()
		end
		track(player, "prompt", {
			name = prompt.Name,
			action = prompt.ActionText,
			object = prompt.ObjectText,
			zone = zoneOf(player),
		})
	end)

	-- the game's own events
	registry.RoadService.Bought:Connect(function(player, id, price, special)
		local info = dragonInfo(id, special)
		info.price = price
		local profile = data:Get(player)
		info.coins_left = profile and math.floor(profile.coins) or nil
		track(player, "buy_dragon", info)
	end)
	pcall(function()
		registry.RoadService.BuyNowRequested:Connect(function(player, roadId)
			track(player, "buy_now_offer", { road = roadId })
		end)
	end)
	dragons.Placed:Connect(function(player, rec, kind, from)
		local info = dragonInfo(rec.id, rec.sp)
		info.how = kind
		info.from_player = from and from ~= player and from.UserId or nil
		track(player, "placed_" .. tostring(kind), info)
		if kind == "stolen" and from and from ~= player and sessions[from] then
			sessions[from].robbedAt = now()
			track(from, "got_robbed", { by = player.UserId, dragon = rec.id })
		end
	end)
	dragons.StealStarted:Connect(function(thief, victim, rec)
		track(thief, "steal_start", { victim = victim and victim.UserId, dragon = rec and rec.id })
		if victim and sessions[victim] then
			track(victim, "being_robbed", { by = thief.UserId, dragon = rec and rec.id })
		end
	end)
	pcall(function()
		dragons.GrowRequested:Connect(function(player)
			track(player, "grow_offer")
		end)
	end)
	combat.Bonked:Connect(function(attacker, victim, wasCarrying)
		if typeof(attacker) == "Instance" then
			track(
				attacker,
				"bonk_hit",
				{ victim = typeof(victim) == "Instance" and victim.UserId or "npc", carrying = wasCarrying }
			)
		end
		if typeof(victim) == "Instance" then
			track(victim, "got_bonked", {
				by = typeof(attacker) == "Instance" and attacker.UserId or "npc",
				was_carrying = wasCarrying,
			})
		end
	end)
	combat.WeaponChanged:Connect(function(player)
		local profile = data:Get(player)
		track(player, "weapon_up", { level = profile and profile.weaponLevel })
	end)
	baseService.Locked:Connect(function(player)
		track(player, "lock")
	end)
	baseService.Collected:Connect(function(player, amount)
		local s = sessions[player]
		if s then
			s.collected = (s.collected or 0) + (amount or 0)
			s.collects = (s.collects or 0) + 1
		end
	end)
	baseService.PlateStepped:Connect(function(player, which)
		track(player, "plate", { which = which })
	end)
	baseService.CastleGrew:Connect(function(player, level)
		track(player, "castle_up", { level = level })
	end)
	baseService.FeverStarted:Connect(function(player)
		track(player, "fever")
	end)
	registry.RewardService.Hatched:Connect(function(player, id, special)
		track(player, "egg_hatched", dragonInfo(id, special))
	end)
	pcall(function()
		registry.RewardService.HatchNowRequested:Connect(function(player)
			track(player, "hatch_now_offer")
		end)
	end)
	registry.PlaytimeService.GiftGiven:Connect(function(player, n, gift)
		track(player, "playtime_gift", { n = n, gift = clean(gift) })
	end)
	registry.LeaderboardService.PrizeWon:Connect(function(player)
		track(player, "daily_prize")
	end)
	registry.NpcService.Raided:Connect(function(_, owner, rec)
		if typeof(owner) == "Instance" then
			track(owner, "npc_raided", { dragon = rec and rec.id })
		end
	end)
	registry.NpcService.Escaped:Connect(function(_, owner, rec)
		if typeof(owner) == "Instance" then
			track(owner, "npc_escaped", { dragon = rec and rec.id })
		end
	end)
	registry.ToolService.PotionsRequested:Connect(function(player)
		track(player, "potions_offer")
	end)
	tutorial.StepShown:Connect(function(player, step, total, text)
		track(player, "tutorial_step", { step = step, total = total, text = text })
	end)
	tutorial.Finished:Connect(function(player, skipped)
		track(player, skipped and "tutorial_skipped" or "tutorial_done")
	end)

	-- purchases: the prompt, then bought or closed
	shop.Prompted:Connect(function(player, kind, key)
		local s = sessions[player]
		if s then
			s.prompts[kind .. ":" .. tostring(key)] = now()
		end
		track(player, "purchase_prompt", { kind = kind, key = key })
	end)
	if shop.CardShown then
		shop.CardShown:Connect(function(player, key, why)
			track(player, "offer_card", { key = key, why = why })
		end)
	end
	shop.Purchased:Connect(function(player, name, robux)
		track(player, "purchase", { name = name, robux = robux })
	end)
	pcall(function()
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
			local player = Players:GetPlayerByUserId(userId)
			local product = Shop.productById and Shop.productById[productId]
			track(player, "purchase_result", {
				kind = "product",
				key = product and product.key or productId,
				bought = purchased == true,
			})
		end)
	end)
	pcall(function()
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
			local pass = Shop.passById and Shop.passById[passId]
			track(player, "purchase_result", {
				kind = "pass",
				key = pass and pass.key or passId,
				bought = purchased == true,
			})
		end)
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
		local pos = baseService:Position(player)
		if pos then
			s.zone = zoneOf(player) -- remembered: the character is often gone by the time they leave
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

function AnalyticsService:_snapshot(player)
	local s = sessions[player]
	local profile = data:Get(player)
	if not s or not profile then
		return
	end
	local snap = progress(player, profile)
	snap.zone = zoneOf(player)
	snap.idle = s.idle == true
	snap.carrying = dragons:Carrying(player) ~= nil
	snap.server_players = #Players:GetPlayers()
	snap.tutorial_step = tutorial:Step(player)
	snap.collected = math.floor(s.collected or 0)
	pcall(function()
		snap.ping_ms = math.floor(player:GetNetworkPing() * 1000)
	end)
	track(player, "snapshot", snap)
	-- the live row (the team's live dashboard reads it; a refresh every snapshot keeps the session "on")
	upsertSession(s, { live = snap, server_no = fill and fill.number or nil })
end

function AnalyticsService:Start()
	task.spawn(function()
		local acc, snapAcc = 0, 0
		while true do
			task.wait(1)
			self:_watch()
			acc += 1
			snapAcc += 1
			if snapAcc >= Constants.ANALYTICS_SNAPSHOT_SECONDS then
				snapAcc = 0
				for player in sessions do
					self:_snapshot(player)
				end
			end
			if acc >= Constants.ANALYTICS_FLUSH_SECONDS then
				acc = 0
				AnalyticsService.flush()
			end
		end
	end)
end

function AnalyticsService:OnPlayerReady(player, profile)
	local s = sessions[player] or begin(player)
	s.ready = true
	local meta = profile.meta
	local previous = meta.lastSeen
	meta.sessions = (meta.sessions or 0) + 1
	s.start = progress(player, profile)
	s.startCoins, s.startEarned = profile.coins, profile.earned
	s.startBought, s.startSteals, s.startBonks = profile.stats.bought, profile.steals, profile.stats.bonks
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
	local summary = progress(player, profile)
	local zoneNow = zoneOf(player)
	summary.zone = zoneNow ~= "none" and zoneNow or s.zone
	summary.idle_at_leave = s.idle == true
	summary.idle_seconds = s.idleSeconds
	summary.seconds_since_action = math.floor(now() - s.lastActionAt)
	summary.robbed_last_minute = s.robbedAt ~= nil and now() - s.robbedAt < 60
	summary.carrying = dragons:Carrying(player) ~= nil
	summary.tutorial_step = tutorial:Step(player)
	summary.coins_gained = math.floor(profile.coins - (s.startCoins or profile.coins))
	summary.earned_gained = math.floor(profile.earned - (s.startEarned or profile.earned))
	summary.bought = profile.stats.bought - (s.startBought or profile.stats.bought)
	summary.stole = profile.steals - (s.startSteals or profile.steals)
	summary.bonks = profile.stats.bonks - (s.startBonks or profile.stats.bonks)
	summary.collected = math.floor(s.collected or 0)
	summary.collects = s.collects or 0
	summary.counts = s.counts
	summary.taps = s.taps
	summary.last_actions = s.last
	local open = {}
	for key, at in s.prompts do
		if now() - at < 20 then
			table.insert(open, key) -- left within 20 s of a purchase prompt
		end
	end
	summary.left_after_prompt = #open > 0 and open or nil
	track(s, "leave", { reason = reason, last = s.last, zone = summary.zone, idle = summary.idle_at_leave })
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
