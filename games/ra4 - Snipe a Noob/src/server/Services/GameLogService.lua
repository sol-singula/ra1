-- Game log: everything worth knowing goes to the team's private Discord logs channel:
--   joins, and leaves with how the session went (time played, pops, headshots, rounds, wins, coins, Robux...)
--   the chat
--   Robux purchases, round results (winner, map, players), Legend+ skins from crates, trades, daily prize wins,
--   rifle buys, level 10/25/50/100, possible cheaters (too many pops, too fast), script errors, server start/stop.
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
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Rifles = require(ReplicatedStorage.Shared.Data.Rifles)

local GameLogService = {
	Name = "GameLogService",
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"ShopService",
		"RoundService",
		"CombatService",
		"CrateService",
		"TradeService",
		"LoadoutService",
		"LeaderboardService",
	},
}

local COLORS = {
	join = 0x10b981,
	leave = 0xe11d48,
	money = 0xf5c518,
	trade = 0xa855f7,
	rare = 0xf59e0b,
	event = 0x38bdf8,
	error = 0xef4444,
	server = 0x94a3b8,
}

local sessions = {} -- [player] = { start, earned, pops, headshots, rounds, wins, robux, items }
local queue, chat = {}, {}
local secret -- the key from the Secrets Store, or false if there isn't one
local startedAt = os.time()
local peakPlayers = 0
local errorsSeen = {} -- [message] = os.clock() it was last logged
local popTimes = {} -- [player] = { os.clock() of recent pops } for the cheat check
local flagged = {} -- [player] = true once reported this session

local function profileUrl(player)
	return "https://www.roblox.com/users/" .. player.UserId .. "/profile"
end

local function who(player)
	if player.DisplayName ~= player.Name then
		return `{player.DisplayName} (@{player.Name})`
	end
	return "@" .. player.Name
end

local function rifleText(profile)
	local r = Rifles.byKey[profile.rifle]
	return r and r.name or profile.rifle
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

-- Send one batch (the tests replace this). Returns true if it went out.
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
	registry.ShopService.Purchased:Connect(function(player, name, robux)
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
	registry.RoundService.RoundEnded:Connect(function(ranking, map)
		local top = {}
		local real = 0
		for _, r in ranking do
			if not r.robot then
				real += 1
				if #top < 3 then
					table.insert(top, `{r.name} ({r.pops})`)
				end
			end
		end
		GameLogService.log({
			emoji = "🏆",
			title = `Round over: {top[1] or "nobody"} won`,
			color = COLORS.event,
			fields = {
				{ name = "Map", value = map and map.name or "?" },
				{ name = "Players", value = real },
				{ name = "Top 3", value = #top > 0 and table.concat(top, ", ") or "-" },
			},
		})
	end)
	registry.CombatService.Popped:Connect(function(killer, victim)
		if not killer or killer.robot or victim.robot then
			return
		end
		-- a cheat check: more than 12 real pops in 20 seconds
		local t = os.clock()
		local list = popTimes[killer] or {}
		table.insert(list, t)
		while #list > 0 and list[1] < t - 20 do
			table.remove(list, 1)
		end
		popTimes[killer] = list
		if #list > 12 and not flagged[killer] then
			flagged[killer] = true
			GameLogService.log({
				emoji = "🚩",
				title = `{who(killer)} popped {#list} players in 20 seconds (check for cheats)`,
				color = COLORS.error,
				url = profileUrl(killer),
			})
		end
	end)
	registry.CrateService.Opened:Connect(function(player, crateKey, skinId)
		local skin = Cosmetics.skinById[skinId]
		if skin and (skin.rarity == "Legend" or skin.rarity == "Secret") then
			GameLogService.log({
				emoji = "🎁",
				title = `{who(player)} opened a {skin.rarity} {skin.name} skin ({crateKey} crate)`,
				color = COLORS.rare,
				url = profileUrl(player),
			})
		end
	end)
	registry.TradeService.Sold:Connect(function(seller, buyer, skinId, coins, tax)
		local skin = Cosmetics.skinById[skinId]
		GameLogService.log({
			emoji = "🏪",
			title = `{who(buyer)} bought {who(seller)}'s {skin and skin.name or skinId} skin for {coins} coins`,
			color = COLORS.trade,
			url = profileUrl(buyer),
			fields = { { name = "Tax", value = `{tax} coins` } },
		})
	end)
	registry.LoadoutService.Bought:Connect(function(player, kind, id, coins)
		if kind == "rifle" then
			GameLogService.log({
				emoji = "🔫",
				title = `{who(player)} bought the {Rifles.byKey[id].name} for {Format.num(coins)} coins`,
				color = COLORS.event,
				url = profileUrl(player),
			})
		end
	end)
	registry.EconomyService.LevelUp:Connect(function(player, level)
		if level == 10 or level == 25 or level == 50 or level == 100 then
			GameLogService.log({
				emoji = "⬆️",
				title = `{who(player)} reached level {level}`,
				color = COLORS.event,
				url = profileUrl(player),
			})
		end
	end)
	registry.LeaderboardService.PrizeWon:Connect(function(player)
		GameLogService.log({
			emoji = "👑",
			title = `{who(player)} won the daily TOP SNIPER prize (Champion skin)`,
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
		pops = profile.stats.pops,
		headshots = profile.stats.headshots,
		rounds = profile.stats.rounds,
		wins = profile.stats.wins,
		robux = 0,
		items = {},
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
			{ name = "Level", value = (Formulas.levelFromXp(profile.xp)) },
			{ name = "Coins", value = Format.num(profile.coins) },
			{ name = "Pops", value = Format.num(profile.stats.pops) },
			{ name = "Rifle", value = rifleText(profile) },
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
	return {
		{ name = "Time played", value = Format.time(os.time() - s.start) },
		{ name = "Pops", value = profile.stats.pops - s.pops },
		{ name = "Headshots", value = profile.stats.headshots - s.headshots },
		{ name = "Rounds", value = profile.stats.rounds - s.rounds },
		{ name = "Wins", value = profile.stats.wins - s.wins },
		{ name = "Coins earned", value = Format.num(profile.earned - s.earned) },
		{ name = "Coins now", value = Format.num(profile.coins) },
		{ name = "Level", value = (Formulas.levelFromXp(profile.xp)) },
		{ name = "Rifle", value = rifleText(profile) },
		{ name = "Skins", value = #profile.skins },
		{ name = "Robux spent", value = s.robux > 0 and `R$ {s.robux} ({table.concat(s.items, ", ")})` or "0" },
	}
end

function GameLogService:OnPlayerLeaving(player, profile)
	local stats = profile and self:SessionStats(player, profile)
	sessions[player] = nil
	popTimes[player] = nil
	flagged[player] = nil
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
