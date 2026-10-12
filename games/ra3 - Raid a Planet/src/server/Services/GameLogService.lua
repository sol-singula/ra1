-- Game log: everything worth knowing goes to the team's private Discord logs channel:
--   joins, and leaves with how the session went (time played, bugs, bosses, raids, blasters forged, Robux...)
--   the chat
--   Robux purchases, raids (won or lost, the MVPs), trades on the Plaza, booths, Legend+ pets, ULTRA blasters,
--   rebirths, daily prize wins, script errors, and the server starting and shutting down.
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
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Planets = require(ReplicatedStorage.Shared.Data.Planets)

local GameLogService = {
	Name = "GameLogService",
	Dependencies = {
		"PlayerDataService",
		"PlanetService",
		"BlasterService",
		"ShopService",
		"RaidService",
		"TradeService",
		"BoothService",
		"PetService",
		"RebirthService",
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

local planetService
local sessions = {} -- [player] = { start, earned, bugs, bosses, raids, forged, robux, items }
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

local function blasterText(rec)
	return `{Formulas.blasterName(rec)} {Formulas.rollStars(rec)} ({rec.rarity}) · {Format.num(
		Formulas.blasterDamage(rec)
	)} dmg`
end

-- The best blaster in a profile: "Frost Cannon ✨ (Epic) · 1.2K dmg".
local function bestBlaster(profile)
	local best, bestRec = 0, nil
	for _, rec in profile.blasters do
		local d = Formulas.blasterDamage(rec)
		if d > best then
			best, bestRec = d, rec
		end
	end
	return bestRec and blasterText(bestRec) or "none"
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
	planetService = registry.PlanetService
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
	registry.RaidService.Ended:Connect(function(won, ranking, squad)
		local mvp = {}
		for i = 1, math.min(3, #ranking) do
			table.insert(mvp, `{ranking[i].player.DisplayName} ({Format.num(ranking[i].damage)})`)
		end
		GameLogService.log({
			emoji = won and "☄️" or "💨",
			title = (squad and "Squad raid " or "Raid ") .. (won and "won: the Star Eater fell" or "lost: it got away"),
			color = COLORS.event,
			fields = {
				{ name = "Raiders", value = #ranking },
				{ name = "MVP", value = #mvp > 0 and table.concat(mvp, ", ") or "nobody" },
			},
		})
	end)
	registry.TradeService.Sold:Connect(function(seller, buyer, rec, gems, tax)
		GameLogService.log({
			emoji = "🏪",
			title = `{who(buyer)} bought {who(seller)}'s {Formulas.blasterName(rec)} for {gems} gems`,
			color = COLORS.trade,
			url = profileUrl(buyer),
			fields = { { name = "Tax", value = `{tax} gems` }, { name = "Blaster", value = blasterText(rec) } },
		})
	end)
	registry.BoothService.Shown:Connect(function(player, assetId, name)
		GameLogService.log({
			emoji = "👕",
			title = `{who(player)} put {name} on a booth`,
			color = COLORS.trade,
			url = "https://www.roblox.com/catalog/" .. assetId,
		})
	end)
	registry.BoothService.Prompted:Connect(function(buyer, owner, assetId)
		GameLogService.log({
			emoji = "🛒",
			title = `{who(buyer)} was shown {who(owner)}'s booth item`,
			color = COLORS.trade,
			url = "https://www.roblox.com/catalog/" .. assetId,
		})
	end)
	registry.PetService.Hatched:Connect(function(player, pet, how)
		if pet.rarity == "Legend" or pet.rarity == "Secret" then
			GameLogService.log({
				emoji = "🥚",
				title = `{who(player)} hatched {pet.name} ({pet.rarity}) from {how}`,
				color = COLORS.rare,
				url = profileUrl(player),
			})
		end
	end)
	registry.BlasterService.Gained:Connect(function(player, rec, how)
		if rec.rarity == "Ultra" or rec.rarity == "Secret" then
			GameLogService.log({
				emoji = "⭐",
				title = `{who(player)} got {blasterText(rec)} ({how})`,
				color = COLORS.rare,
				url = profileUrl(player),
			})
		end
	end)
	registry.RebirthService.Reborn:Connect(function(player, stars)
		GameLogService.log({
			emoji = "🌟",
			title = `{who(player)} rebirthed: {stars} star{stars == 1 and "" or "s"}`,
			color = COLORS.event,
			url = profileUrl(player),
		})
	end)
	registry.LeaderboardService.PrizeWon:Connect(function(player)
		GameLogService.log({
			emoji = "👑",
			title = `{who(player)} won the daily TOP RAIDER prize (an ULTRA blaster)`,
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
		bugs = profile.stats.bugs,
		bosses = profile.stats.bosses,
		raids = profile.stats.raids,
		forged = profile.stats.forged,
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
			{ name = "Coins", value = Format.num(profile.coins) },
			{ name = "Gems", value = Format.num(profile.gems) },
			{ name = "Blasters", value = #profile.blasters },
			{ name = "Best blaster", value = bestBlaster(profile) },
			{ name = "Stars", value = profile.rebirths or 0 },
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
	local top = Planets.list[planetService:Unlocked(player)]
	return {
		{ name = "Time played", value = Format.time(os.time() - s.start) },
		{ name = "Coins earned", value = Format.num(profile.earned - s.earned) },
		{ name = "Coins now", value = Format.num(profile.coins) },
		{ name = "Gems now", value = Format.num(profile.gems) },
		{ name = "Bugs blasted", value = profile.stats.bugs - s.bugs },
		{ name = "Bosses beaten", value = profile.stats.bosses - s.bosses },
		{ name = "Raids joined", value = profile.stats.raids - s.raids },
		{ name = "Blasters forged", value = profile.stats.forged - s.forged },
		{ name = "Blasters owned", value = #profile.blasters },
		{ name = "Best blaster", value = bestBlaster(profile) },
		{ name = "Top planet", value = top and top.name or "?" },
		{ name = "Stars", value = profile.rebirths or 0 },
		{ name = "Robux spent", value = s.robux > 0 and `R$ {s.robux} ({table.concat(s.items, ", ")})` or "0" },
	}
end

function GameLogService:OnPlayerLeaving(player, profile)
	local stats = profile and self:SessionStats(player, profile)
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
