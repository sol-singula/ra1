-- Game log: everything worth knowing goes to the team's private Discord logs channel (#external-logs):
--   joins, and leaves with how the session went (time played, coins earned, dragons bought and stolen, Robux...)
--   the chat
--   Robux purchases, completed steals, Legend+ dragons bought, egg hatches, castle levels 3+, daily prize wins,
--   DISCO FEVER, script errors, and the server starting and shutting down.
-- Events and chat are queued and sent together every few seconds (one Discord message holds up to 10 embeds),
-- through the roblox-game-log Supabase function (solbuild.net project), so Discord's rate limits never bite.
--
-- Setup: HTTP requests are on in default.project.json, and the key lives in the experience's Roblox Secrets
-- Store under the name "discord_log" (Creator Dashboard -> the experience -> Secrets), because this code is
-- public. Without that secret (and in Studio) nothing is sent.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)

local GameLogService = {
	Name = "GameLogService",
	Dependencies = {
		"PlayerDataService",
		"BaseService",
		"DragonService",
		"ShopService",
		"LeaderboardService",
		"RewardService",
		"RoadService",
	},
}

local COLORS = {
	join = 0x10b981,
	leave = 0xe11d48,
	money = 0xf5c518,
	steal = 0xa855f7,
	rare = 0xf59e0b,
	event = 0x38bdf8,
	error = 0xef4444,
	server = 0x94a3b8,
}

local baseService, dragons
local sessions = {} -- [player] = { start, earned, steals, bought, bonks, robux, items, robbed, tutorialDone }
local queue, chat = {}, {}
local secret -- the key from the Secrets Store, or false if there isn't one
local startedAt = os.time()
local peakPlayers = 0
local errorsSeen = {} -- [message] = os.clock() it was last logged

local function profileUrl(player)
	return "https://www.roblox.com/users/" .. player.UserId .. "/profile"
end

local function who(player)
	if player.DisplayName ~= player.Name then
		return `{player.DisplayName} (@{player.Name})`
	end
	return "@" .. player.Name
end

local function dragonName(id, special)
	local d = Dragons.byId[id]
	return (special and Dragons.Specials[special] and (Dragons.Specials[special].name .. " ") or "")
		.. (d and d.name or id)
		.. (d and ` ({d.rarity})` or "")
end

-- The best dragon in a profile: "Name (Rarity) · 1.2K/s".
local function bestDragon(profile)
	local best, bestRec = 0, nil
	local now = os.time()
	for _, rec in profile.dragons do
		local cps = Formulas.dragonIncome(rec, now)
		if cps > best then
			best, bestRec = cps, rec
		end
	end
	if not bestRec then
		return "none"
	end
	return `{dragonName(bestRec.id, bestRec.sp)} · {Format.num(best)}/s`
end

-- Queue an event: { emoji, title, color, url?, description?, fields = { { name, value } } }.
function GameLogService.log(event)
	if #queue < 60 then
		table.insert(queue, event)
	end
end

-- Queue a chat line.
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
	}
end

-- Send one batch (also the hook tests replace). Returns true if it went out.
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
		-- (not warn: a failed log post shouldn't itself become a logged error)
		print("[GameLog] post failed: " .. tostring(ok and res.StatusCode or res))
		return false
	end
	return true
end

-- Send everything queued so far.
function GameLogService.flush()
	if #queue == 0 and #chat == 0 then
		return
	end
	local payload = { events = queue, chat = chat, server = server() }
	queue, chat = {}, {}
	GameLogService.send(payload)
end

function GameLogService:Init(registry)
	baseService = registry.BaseService
	dragons = registry.DragonService
	local shop = registry.ShopService
	shop.Purchased:Connect(function(player, name, robux)
		local s = sessions[player]
		if s then
			s.robux += robux or 0
			table.insert(s.items, name)
		end
		GameLogService.log({
			emoji = "💰",
			title = `{who(player)} bought {name}`,
			color = COLORS.money,
			url = profileUrl(player),
			fields = { { name = "Robux", value = "R$ " .. tostring(robux or "?") } },
		})
	end)
	dragons.StealStarted:Connect(function(_, victim)
		local s = sessions[victim]
		if s then
			s.robbed += 1
		end
	end)
	dragons.Placed:Connect(function(player, rec, kind, from)
		if kind == "stolen" and from and from ~= player then
			GameLogService.log({
				emoji = "😈",
				title = `{who(player)} stole {dragonName(rec.id, rec.sp)} from {who(from)}`,
				color = COLORS.steal,
				url = profileUrl(player),
			})
		end
	end)
	registry.RoadService.Bought:Connect(function(player, id)
		local d = Dragons.byId[id]
		if d and Dragons.RarityRank[d.rarity] >= Dragons.RarityRank.Legend then
			GameLogService.log({
				emoji = "⭐",
				title = `{who(player)} bought {dragonName(id)} on the road`,
				color = COLORS.rare,
				url = profileUrl(player),
			})
		end
	end)
	registry.RewardService.Hatched:Connect(function(player, id, special)
		GameLogService.log({
			emoji = "🐣",
			title = `{who(player)}'s egg hatched {dragonName(id, special)}`,
			color = COLORS.rare,
			url = profileUrl(player),
		})
	end)
	baseService.CastleGrew:Connect(function(player, level)
		if level >= 3 then
			GameLogService.log({
				emoji = "🏰",
				title = `{who(player)}'s castle reached level {level}`,
				color = COLORS.event,
				url = profileUrl(player),
			})
		end
	end)
	baseService.FeverStarted:Connect(function(player)
		GameLogService.log({ emoji = "🪩", title = `{who(player)} started DISCO FEVER`, color = COLORS.event })
	end)
	registry.LeaderboardService.PrizeWon:Connect(function(player)
		GameLogService.log({
			emoji = "👑",
			title = `{who(player)} won the daily TOP EARNER prize (Omni Prism)`,
			color = COLORS.money,
			url = profileUrl(player),
		})
	end)
	-- script errors on the server (each distinct message at most once every 10 minutes)
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
	-- the last batch goes out before the server closes
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
		earned = profile.earned,
		steals = profile.steals,
		bought = profile.stats.bought,
		bonks = profile.stats.bonks,
		tutorialDone = profile.tutorialDone,
		robux = 0,
		items = {},
		robbed = 0,
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
			{ name = "Coins", value = Format.num(profile.coins) },
			{ name = "Dragons", value = #profile.dragons },
			{ name = "Best dragon", value = bestDragon(profile) },
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
	local base = baseService:Get(player)
	local stats = {
		{ name = "Time played", value = Format.time(os.time() - s.start) },
		{ name = "Coins earned", value = Format.num(profile.earned - s.earned) },
		{ name = "Coins now", value = Format.num(profile.coins) },
		{ name = "Dragons bought", value = profile.stats.bought - s.bought },
		{ name = "Dragons stolen", value = profile.steals - s.steals },
		{ name = "Times robbed", value = s.robbed },
		{ name = "Bonks", value = profile.stats.bonks - s.bonks },
		{ name = "Dragons owned", value = #profile.dragons },
		{ name = "Best dragon", value = bestDragon(profile) },
		{ name = "Castle level", value = base and base.world.castleLevel or "?" },
		{ name = "Robux spent", value = s.robux > 0 and `R$ {s.robux} ({table.concat(s.items, ", ")})` or "0" },
	}
	if not s.tutorialDone and profile.tutorialDone then
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
