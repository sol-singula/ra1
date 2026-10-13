-- Game log: everything worth knowing goes to the team's private Discord logs channel, same pipeline as Steal a
-- Dragon (the roblox-game-log Supabase function, the "discord_log" secret, batched every few seconds):
--   joins (new or returning, cabin, best distance) and leaves with how the session went (time played, stops,
--   collected, banked, lost, left behind, cabin upgrades, materials given to the train)
--   the chat
--   expeditions: each one that ends (distance, stops, crew, why it ended) and each new Hall of Records entry
--   train upgrades finished, 20 km+ milestones, script errors, the server starting and shutting down
-- Without the secret (and in Studio) nothing is sent.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local TrainUpgrades = require(ReplicatedStorage.Shared.Data.TrainUpgrades)

local GameLogService = {
	Name = "GameLogService",
	Dependencies = { "PlayerDataService", "ExpeditionService", "TrainService", "RecordService", "RecoveryService", "AntiCheatService" },
}

local COLORS = {
	join = 0x10b981,
	leave = 0xe11d48,
	record = 0xf5c518,
	journey = 0x38bdf8,
	event = 0xa855f7,
	error = 0xef4444,
	server = 0x94a3b8,
}

local sessions = {} -- [player] = { start, stats = copy, cabin }
local queue, chat = {}, {}
local secret
local startedAt = os.time()
local peakPlayers = 0
local errorsSeen = {}

local function profileUrl(player)
	return "https://www.roblox.com/users/" .. player.UserId .. "/profile"
end

local function who(player)
	if player.DisplayName ~= player.Name then
		return `{player.DisplayName} (@{player.Name})`
	end
	return "@" .. player.Name
end

function GameLogService.log(event)
	if #queue < 60 then
		table.insert(queue, event)
	end
end

function GameLogService.chat(player, text)
	if #chat < 80 then
		table.insert(chat, { name = player.DisplayName, text = text })
	end
end

local function server()
	return {
		players = #Players:GetPlayers(),
		jobId = game.JobId ~= "" and game.JobId or nil,
		version = game.PlaceVersion,
		studio = RunService:IsStudio(),
		game = Constants.GAME,
	}
end

function GameLogService.send(payload)
	if RunService:IsStudio() and not Constants.GAME_LOG_IN_STUDIO then
		return false
	end
	if secret == nil then
		local ok, value = pcall(HttpService.GetSecret, HttpService, "discord_log")
		secret = ok and value or false
		if not secret then
			warn("[GameLog] no 'discord_log' secret in the Secrets Store: game logs are off")
		end
	end
	if not secret then
		return false
	end
	local ok, res = pcall(HttpService.RequestAsync, HttpService, {
		Url = Constants.GAME_LOG_URL,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json", ["X-Game-Key"] = secret },
		Body = HttpService:JSONEncode(payload),
	})
	if not ok or not res.Success then
		print("[GameLog] post failed: " .. tostring(ok and res.StatusCode or res))
		return false
	end
	return true
end

function GameLogService.flush()
	if #queue == 0 and #chat == 0 then
		return
	end
	local payload = { events = queue, chat = chat, server = server() }
	queue, chat = {}, {}
	GameLogService.send(payload)
end

local function crewNames(record, max)
	local list = {}
	for i, m in record.crew or {} do
		if i > max then
			table.insert(list, `+{#record.crew - max}`)
			break
		end
		table.insert(list, tostring(m.display or m.name))
	end
	return #list > 0 and table.concat(list, ", ") or "—"
end

function GameLogService:Init(registry)
	local expedition = registry.ExpeditionService
	local train = registry.TrainService
	local records = registry.RecordService
	expedition.Ended:Connect(function(exp)
		local crew = 0
		for _, c in exp.crew do
			if c.present then
				crew += 1
			end
		end
		GameLogService.log({
			emoji = "🚂",
			title = `Expedition #{exp.code} ended at {exp.distance} km`,
			color = COLORS.journey,
			fields = {
				{ name = "Stops", value = exp.stops },
				{ name = "Crew aboard", value = crew },
				{ name = "Why", value = exp.reason == "fuel" and "out of fuel" or exp.reason == "empty" and "everyone left" or tostring(exp.reason) },
				{ name = "Time", value = exp.startedAt and Format.time(os.time() - exp.startedAt) or "—" },
			},
		})
	end)
	expedition.Milestone:Connect(function(km)
		if km >= 20 then
			local exp = expedition:State()
			GameLogService.log({ emoji = "🏁", title = `Expedition #{exp and exp.code or "?"} passed {km} km`, color = COLORS.journey })
		end
	end)
	train.Upgraded:Connect(function(key, stage, by)
		local u = TrainUpgrades.byKey[key]
		local s = u and u.stages[stage]
		GameLogService.log({
			emoji = u and u.icon or "⚙️",
			title = `{s and s.name or key} finished{by and (" by " .. who(by)) or ""}`,
			color = COLORS.event,
		})
	end)
	records.NewTop:Connect(function(record, rank)
		GameLogService.log({
			emoji = "🏆",
			title = `Hall of Records #{rank}: expedition #{record.code}, {record.km} km`,
			color = COLORS.record,
			fields = {
				{ name = "Stops", value = record.stops },
				{ name = "Crew", value = crewNames(record, 8) },
			},
		})
	end)
	-- the anti-cheat: each kind of flag at most once a minute per player, and every kick
	local lastFlag = {}
	registry.AntiCheatService.Flagged:Connect(function(player, kind, detail, strikes)
		local key = player.UserId .. kind
		if (lastFlag[key] or -99) > os.clock() - 60 then
			return
		end
		lastFlag[key] = os.clock()
		GameLogService.log({
			emoji = "🚨",
			title = `Anti-cheat: {who(player)} flagged for {kind}`,
			color = COLORS.leave,
			url = profileUrl(player),
			fields = {
				{ name = "What", value = tostring(detail) },
				{ name = "Strikes", value = `{strikes} / {Constants.AC_KICK_STRIKES}` },
			},
		})
	end)
	registry.AntiCheatService.Kicked:Connect(function(player, reason)
		GameLogService.log({ emoji = "⛔", title = `Anti-cheat KICKED {who(player)}: {reason}`, color = COLORS.leave, url = profileUrl(player) })
	end)
	pcall(function()
		ScriptContext.Error:Connect(function(message, trace)
			local last = errorsSeen[message]
			if last and os.clock() - last < 600 then
				return
			end
			errorsSeen[message] = os.clock()
			GameLogService.log({
				emoji = "⚠️",
				title = "Server error",
				color = COLORS.error,
				description = "```" .. string.sub(tostring(message) .. "\n" .. tostring(trace or ""), 1, 1500) .. "```",
			})
		end)
	end)
	pcall(function()
		game:BindToClose(function()
			GameLogService.log({
				emoji = "🛑",
				title = "Server shutting down",
				color = COLORS.server,
				fields = {
					{ name = "Up for", value = Format.time(os.time() - startedAt) },
					{ name = "Most players", value = peakPlayers },
				},
			})
			GameLogService.flush()
		end)
	end)
end

function GameLogService:Start()
	GameLogService.log({ emoji = "🟦", title = "Server started", color = COLORS.server })
	while true do
		task.wait(Constants.GAME_LOG_FLUSH_SECONDS)
		GameLogService.flush()
	end
end

function GameLogService:OnPlayerReady(player, profile)
	peakPlayers = math.max(peakPlayers, #Players:GetPlayers())
	sessions[player] = {
		start = os.time(),
		stats = table.clone(profile.stats),
		cabin = Formulas.cabinCount(profile.cabin.built),
		tutorialDone = profile.tutorial.done == true,
	}
	player.Chatted:Connect(function(message)
		GameLogService.chat(player, message)
	end)
	GameLogService.log({
		emoji = "🟢",
		title = who(player) .. " joined",
		color = COLORS.join,
		url = profileUrl(player),
		fields = {
			{ name = "Player", value = profile._isNew and "🆕 New" or "Returning" },
			{ name = "Cabin", value = `{Formulas.cabinCount(profile.cabin.built)}/15 upgrades` },
			{ name = "Best distance", value = `{profile.best or 0} km` },
			{ name = "Account age", value = (player.AccountAge or 0) .. " days" },
		},
	})
end

-- The leave message's stats for a session (exposed for tests).
function GameLogService:SessionStats(player, profile)
	local s = sessions[player]
	if not s then
		return nil
	end
	local st, old = profile.stats, s.stats
	local function gained(k)
		return (st[k] or 0) - (old[k] or 0)
	end
	local stats = {
		{ name = "Time played", value = Format.time(os.time() - s.start) },
		{ name = "Stops", value = gained("stops") },
		{ name = "Collected", value = gained("collected") },
		{ name = "Banked", value = gained("banked") },
		{ name = "Lost (left behind)", value = `{gained("lost")} ({gained("stranded")}x left behind)` },
		{ name = "Cabin upgrades", value = `+{Formulas.cabinCount(profile.cabin.built) - s.cabin} (now {Formulas.cabinCount(profile.cabin.built)}/15)` },
		{ name = "Given to the train", value = gained("deposited") + gained("fuel") },
		{ name = "Best distance", value = `{profile.best or 0} km` },
	}
	if not s.tutorialDone and profile.tutorial.done then
		table.insert(stats, { name = "Tutorial", value = "✅ finished this session" })
	end
	return stats
end

function GameLogService:OnPlayerLeaving(player, profile)
	local stats = self:SessionStats(player, profile)
	sessions[player] = nil
	if stats then
		GameLogService.log({
			emoji = "🔴",
			title = who(player) .. " left",
			color = COLORS.leave,
			url = profileUrl(player),
			fields = stats,
		})
	end
end

return GameLogService
