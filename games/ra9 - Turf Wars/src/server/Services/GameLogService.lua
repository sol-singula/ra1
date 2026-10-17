--[[
The game log: what we want to read goes to the team's private Discord logs channel, same pipeline as the studio's
other games (the roblox-game-log Supabase function, the "discord_log" secret, batched every few seconds), one short
line each, every one starting "ra9 · ":
  the server starting and shutting down
  joins and leaves ("ra9 · 🟢 Ava (@ava) joined · new", "ra9 · 🔴 Ava (@ava) left after 12:03 · 3 matches, 2 won")
  the chat
  a match starting ("ra9 · 🗺️ Match 4 on Castle Clash · 6 players") and won ("ra9 · 🏆 RED won Castle Clash ·
    kills 14–9 · MVP Ava · 6:32")
  Robux purchases, anti-cheat flags and kicks, script errors
  admin actions ("ra9 · 🛡️ xthirtysix used end match (red)"), when an AdminService with a Used signal is there
Everything else players do is stored by AnalyticsService in roblox_events, not posted.
Without the secret (and in Studio) nothing is sent; why not is said in the server's log (GameKey).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Shop = require(ReplicatedStorage.Shared.Data.Shop)
local GameKey = require(script.Parent.Parent.GameKey)

local GameLogService = {
	Name = "GameLogService",
	Dependencies = { "PlayerDataService", "AntiCheatService", "MatchService", "ShopService", "TeamService" },
}

local COLORS = {
	error = 0xef4444,
	server = 0x94a3b8,
	match = 0x64748b,
	red = 0xeb282d,
	blue = 0x236ef5,
	money = 0x22c55e,
	admin = 0xf59e0b,
}

local registryRef, teams
local sessions = {} -- [player] = { start, matches, wins }
local queue, chat = {}, {}
local startedAt = os.time()
local peakPlayers = 0
local errorsSeen = {}
local matchStartedAt

local function profileUrl(player)
	return "https://www.roblox.com/users/" .. player.UserId .. "/profile"
end

local function who(player)
	if player.DisplayName ~= player.Name then
		return `{player.DisplayName} (@{player.Name})`
	end
	return "@" .. player.Name
end

local function real(player)
	return typeof(player) == "Instance" -- (BotService's stand-ins are tables)
end

local function mapName(key)
	local m = key and Maps.get(key)
	return m and m.name or tostring(key or "?")
end

-- Each event carries the server's player count at the moment it happened (the footer shows it), not when its batch
-- goes out: three joins in one batch read 9, 10, 11, not 11, 11, 11.
function GameLogService.log(event)
	if #queue < 60 then
		event.players = event.players or #Players:GetPlayers()
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
	return GameKey.post(Constants.GAME_LOG_URL, payload, "Discord log")
end

-- Everything goes to the studio's shared game-logs channel, so every entry starts with the game's short name
-- ("ra9 · 🟢 @ava joined"), the emoji after it. The chat goes as entries too (so it starts with it as well),
-- escaped: it's text, never markdown or a ping.
local function tagged(e)
	local t = table.clone(e)
	t.title = `{Constants.GAME} · {e.emoji and (e.emoji .. " ") or ""}{e.title}`
	t.emoji = nil
	return t
end
local function plain(text)
	text = string.gsub(tostring(text), "[`*_~|>\\]", "\\%0")
	return (string.gsub(text, "@", "@" .. utf8.char(0x200B)))
end
GameLogService.tagged, GameLogService.plain = tagged, plain

function GameLogService.flush()
	if #queue == 0 and #chat == 0 then
		return
	end
	local events = {}
	for _, e in queue do
		table.insert(events, tagged(e))
	end
	local lines = ""
	local function chatEntry()
		if lines ~= "" then
			table.insert(events, { title = `{Constants.GAME} · 💬 Chat`, color = 0x5865f2, description = lines })
			lines = ""
		end
	end
	for _, c in chat do
		local line = `**{plain(string.sub(c.name, 1, 40))}:** {plain(string.sub(c.text, 1, 300))}`
		if #lines + #line > 1900 then
			chatEntry()
		end
		lines = lines == "" and line or (lines .. "\n" .. line)
	end
	chatEntry()
	queue, chat = {}, {}
	GameLogService.send({ events = events, server = server() })
end

-- "end_match" -> "end match"
local function words(s)
	return (string.gsub(string.sub(tostring(s), 1, 60), "_", " "))
end

-- An admin used a tool (AdminService.Used, when there is one): "🛡️ xthirtysix used end match (red)".
function GameLogService.admin(admin, action, detail)
	local name = typeof(admin) == "Instance" and admin.Name or tostring(admin or "?")
	local extra = detail ~= nil and detail ~= "" and ` ({plain(string.sub(tostring(detail), 1, 120))})` or ""
	GameLogService.log({
		emoji = "🛡️",
		title = `{plain(name)} used {plain(words(action))}{extra}`,
		color = COLORS.admin,
		line = true,
	})
end

local function onMatchStarted(key, id)
	matchStartedAt = os.clock()
	if #Players:GetPlayers() == 0 then
		return -- (an empty server cycling maps: nothing to read)
	end
	GameLogService.log({
		emoji = "🗺️",
		title = `Match {id} on {mapName(key)} · {#Players:GetPlayers()} player{#Players:GetPlayers() == 1 and "" or "s"}`,
		color = COLORS.match,
		line = true,
	})
end

local function onMatchEnded(winner, results)
	local kills = { red = 0, blue = 0 }
	for _, row in results.rows or {} do
		if row.team and kills[row.team] then
			kills[row.team] += row.kills or 0
		end
	end
	for player, s in sessions do
		local team = teams:Team(player)
		if team then
			s.matches += 1
			if team == winner then
				s.wins += 1
			end
		end
	end
	if #Players:GetPlayers() == 0 then
		return
	end
	local loser = winner == "red" and "blue" or "red"
	local mvp = results.mvpPlayer
	local took = matchStartedAt and (" · " .. Format.time(os.clock() - matchStartedAt)) or ""
	GameLogService.log({
		emoji = "🏆",
		title = `{Constants.TEAM_NAME[winner] or tostring(winner)} won {mapName(workspace:GetAttribute("MapKey"))}`
			.. ` · kills {kills[winner] or 0}–{kills[loser] or 0}`
			.. (mvp and ` · MVP {plain(mvp.DisplayName)}` or "")
			.. took,
		color = COLORS[winner] or COLORS.match,
		line = true,
	})
end

local function onBought(player, what, _, robux)
	if not robux or not real(player) then
		return -- (Shards buys are stored by AnalyticsService, not posted)
	end
	local product = Shop.products[what]
	local name = what == "starter" and Shop.STARTER.name or (product and product.name) or tostring(what)
	GameLogService.log({
		emoji = "💸",
		title = `{who(player)} bought {name} · R$ {robux}`,
		color = COLORS.money,
		url = profileUrl(player),
		line = true,
	})
end

function GameLogService:Init(registry)
	registryRef = registry
	teams = registry.TeamService
	registry.AntiCheatService.Flagged:Connect(function(player, kind, detail, strikes)
		if strikes >= 3 or kind == "aim" then
			GameLogService.log({
				emoji = "🚩",
				title = `Anti-cheat: {who(player)} ({kind})`,
				color = COLORS.error,
				url = profileUrl(player),
				fields = { { name = "Detail", value = detail }, { name = "Strikes", value = strikes } },
			})
		end
	end)
	registry.AntiCheatService.Kicked:Connect(function(player, reason)
		GameLogService.log({
			emoji = "⛔",
			title = `Kicked {who(player)}: {reason}`,
			color = COLORS.error,
			url = profileUrl(player),
		})
	end)
	registry.MatchService.Started:Connect(onMatchStarted)
	registry.MatchService.Ended:Connect(onMatchEnded)
	registry.ShopService.Bought:Connect(onBought)
	pcall(function()
		ScriptContext.Error:Connect(function(message, trace)
			local key = string.sub(message, 1, 120)
			if errorsSeen[key] then
				return
			end
			errorsSeen[key] = true
			GameLogService.log({
				emoji = "💥",
				title = "Script error",
				color = COLORS.error,
				fields = {
					{ name = "Error", value = key },
					{ name = "Trace", value = string.sub(trace or "", 1, 300) },
				},
			})
		end)
	end)
	pcall(function()
		game:BindToClose(function()
			GameLogService.log({
				emoji = "🟥",
				title = "Server shutting down",
				color = COLORS.server,
				fields = {
					{ name = "Uptime", value = Format.time(os.time() - startedAt) },
					{ name = "Peak players", value = peakPlayers },
				},
			})
			GameLogService.flush()
		end)
	end)
end

function GameLogService:Start()
	-- (AdminService is optional and may load after us: looked up now, never a dependency)
	local admin = registryRef and registryRef.AdminService
	if type(admin) == "table" and type(admin.Used) == "table" and admin.Used.Connect then
		admin.Used:Connect(GameLogService.admin)
	end
	GameLogService.log({ emoji = "🟦", title = "Server started", color = COLORS.server })
	while true do
		task.wait(Constants.GAME_LOG_FLUSH_SECONDS)
		GameLogService.flush()
	end
end

function GameLogService:OnPlayerReady(player, profile)
	peakPlayers = math.max(peakPlayers, #Players:GetPlayers())
	sessions[player] = { start = os.time(), matches = 0, wins = 0 }
	player.Chatted:Connect(function(message)
		GameLogService.chat(player, message)
	end)
	local wins = profile.wins or 0
	GameLogService.log({
		emoji = "🟢",
		title = `{who(player)} joined · {profile._isNew and "new" or ("returning · " .. wins .. " win" .. (wins == 1 and "" or "s"))}`,
		line = true,
	})
end

function GameLogService:OnPlayerLeaving(player)
	local s = sessions[player]
	sessions[player] = nil
	if s then
		local played = s.matches > 0 and ` · {s.matches} match{s.matches == 1 and "" or "es"}, {s.wins} won` or ""
		GameLogService.log({
			emoji = "🔴",
			title = `{who(player)} left after {Format.time(os.time() - s.start)}{played}`,
			line = true,
			-- (they're still in the list while leaving: the count is the server without them)
			players = #Players:GetPlayers() - (player.Parent and 1 or 0),
		})
	end
end

return GameLogService
