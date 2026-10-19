--[[
Analytics (master plan §18): every play session and what players do in it, so the funnel can be read: planted,
harvested, sold, bought, the store bottleneck, automation, the shop, the warehouse, the session's end, purchases.
The studio's pipeline (the roblox-analytics function, tagged game = "ra11"):

  roblox_sessions  one row a session: new or returning, the session number, days since the last, country, device,
                   progress at the start and the end, how long, why
  roblox_events    one row a thing that happened, with seconds since the session started: join, first_crop_planted,
                   first_crop_harvested, first_sale_completed, first_upgrade_purchased, store_bottleneck_reached,
                   automation_unlocked, first_store_unlocked, warehouse_unlocked, purchase_completed, session_ended,
                   every buy, task, truck, a snapshot every 30 s, the leave
Nothing is sent in Studio (unless Constants.GAME_LOG_IN_STUDIO). Every call is safe to make.

  AnalyticsService.event(player, name, data)
  AnalyticsService.send(payload)               one batch out (tests replace it)
]]
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)

local GameKey = require(script.Parent.Parent.GameKey)

local AnalyticsService = {
	Name = "AnalyticsService",
	Dependencies = { "PlayerDataService" },
}

local data
local sessions = {} -- [player] = { id, t0, userId, firsts, counts, start }
local queue = { sessions = {}, events = {} }
local MAX_EVENTS = 3000

local FIRSTS = { plant = "first_crop_planted", harvest = "first_crop_harvested" }

local function iso(t)
	return os.date("!%Y-%m-%dT%H:%M:%SZ", t)
end

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

local function upsert(s, fields)
	local row = queue.sessions[s.id]
	if not row then
		row = { session_id = s.id, user_id = s.userId }
		queue.sessions[s.id] = row
	end
	for k, v in fields do
		row[k] = v
	end
end

local function progress(profile)
	local n = 0
	for _ in profile.owned or {} do
		n += 1
	end
	return {
		stage = profile.stage,
		cash = math.floor(profile.cash or 0),
		earned = math.floor(profile.stats.earned or 0),
		owned = n,
		task = profile.task and profile.task.step,
		prestige = profile.prestige and profile.prestige.level or 0,
	}
end

local function track(player, kind, extra)
	local s = sessions[player]
	if not s or #queue.events >= MAX_EVENTS then
		return
	end
	table.insert(queue.events, {
		session_id = s.id,
		user_id = s.userId,
		t = math.floor((os.clock() - s.t0) * 10) / 10,
		kind = kind,
		data = clean(extra) or {},
	})
	s.counts[kind] = (s.counts[kind] or 0) + 1
end

function AnalyticsService.event(player, name, payload)
	if typeof(player) ~= "Instance" or type(name) ~= "string" then
		return
	end
	local s = sessions[player]
	if s and FIRSTS[name] and not s.firsts[name] then
		s.firsts[name] = true
		track(player, FIRSTS[name], { seconds = math.floor(os.clock() - s.t0) })
	end
	if name == "plant" or name == "harvest" then
		s = sessions[player]
		if s then
			s.counts[name] = (s.counts[name] or 0) + 1
		end
		return -- (every single one is too many rows: the firsts and the counts are enough)
	end
	track(player, string.sub(name, 1, 40), payload or {})
end

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

local function joinSource(player)
	local source = "direct"
	pcall(function()
		local jd = player:GetJoinData()
		if player.FollowUserId and player.FollowUserId ~= 0 then
			source = "followed_friend"
		elseif jd and jd.ReferredByPlayerId and jd.ReferredByPlayerId ~= 0 then
			source = "invite_link"
		end
	end)
	return source
end

function AnalyticsService:OnPlayerLoaded(player, profile)
	local meta = profile.meta or {}
	local s = {
		id = HttpService:GenerateGUID(false),
		t0 = os.clock(),
		userId = player.UserId,
		firsts = {},
		counts = {},
		start = progress(profile),
	}
	sessions[player] = s
	profile.stats.sessions = (profile.stats.sessions or 0) + 1
	local returning = (profile.stats.sessions or 1) > 1
	upsert(s, {
		started_at = iso(os.time()),
		username = player.Name,
		display_name = player.DisplayName,
		account_age_days = player.AccountAge,
		locale = player.LocaleId,
		join_source = joinSource(player),
		server_players = #Players:GetPlayers(),
		place_version = game.PlaceVersion,
		job_id = game.JobId ~= "" and game.JobId or nil,
		returning = returning,
		session_number = profile.stats.sessions,
		days_since_last = returning and math.floor((os.time() - (meta.lastSeen or os.time())) / 86400) or nil,
		progress_start = s.start,
	})
	track(player, "join", { returning = returning, players = #Players:GetPlayers() })
	task.spawn(function()
		local ok, country = pcall(function()
			return LocalizationService:GetCountryRegionForPlayerAsync(player)
		end)
		if ok and country and sessions[player] == s then
			upsert(s, { country = country })
		end
	end)
end

function AnalyticsService:OnPlayerLeaving(player, profile)
	local s = sessions[player]
	if not s then
		return
	end
	local duration = math.floor(os.clock() - s.t0)
	track(player, "session_ended", { seconds = duration })
	upsert(s, {
		ended_at = iso(os.time()),
		duration_s = duration,
		end_reason = "left",
		summary = {
			progress_end = progress(profile),
			buys = s.counts.buy or 0,
			planted = s.counts.plant or 0,
			harvested = s.counts.harvest or 0,
			trucks = s.counts.truck or 0,
			minutes = math.floor(duration / 6) / 10,
		},
	})
	sessions[player] = nil
	AnalyticsService.flush()
end

function AnalyticsService:Init(registry)
	data = registry.PlayerDataService
	Net.on("Analytics", function(player, kind, payload)
		local s = sessions[player]
		if not s or type(kind) ~= "string" then
			return
		end
		if kind == "device" and type(payload) == "table" then
			upsert(
				s,
				clean({
					platform = payload.platform,
					screen = payload.screen,
					touch = payload.touch,
					gamepad = payload.gamepad,
				})
			)
		end
		track(player, "client_" .. string.sub(kind, 1, 20), payload)
	end)
	game:BindToClose(function()
		AnalyticsService.flush()
	end)
end

function AnalyticsService:Start()
	local snap, acc = 0, 0
	while true do
		task.wait(1)
		snap += 1
		acc += 1
		if snap >= Constants.ANALYTICS_SNAPSHOT_SECONDS then
			snap = 0
			for player in sessions do
				local p = data:Get(player)
				if p then
					track(player, "snapshot", progress(p))
				end
			end
		end
		if acc >= Constants.ANALYTICS_FLUSH_SECONDS then
			acc = 0
			pcall(AnalyticsService.flush)
		end
	end
end

return AnalyticsService
