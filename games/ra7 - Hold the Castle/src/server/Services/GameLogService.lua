-- Game log: everything worth knowing goes to the team's private Discord logs channel, same pipeline as Steal a
-- Dragon (the roblox-game-log Supabase function, the "discord_log" secret, batched every few seconds):
--   joins (new or returning, level, coins) and leaves with how the session went (time played, matches, pieces
--   built, monsters and dwarves beaten, pieces broken, materials mined, coins earned)
--   the chat
--   matches: each one that ends (who won, how long the dwarves held, shrines taken, players), each shrine that
--   falls, a castle growing into a Town or a Castle, the last dwarf standing
--   anti-cheat flags and kicks, script errors, the server starting and shutting down
-- Without the secret (and in Studio) nothing is sent.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)

local GameLogService = {
	Name = "GameLogService",
	Dependencies = {
		"PlayerDataService",
		"MatchService",
		"TeamService",
		"BuildService",
		"ShrineService",
		"AntiCheatService",
	},
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

local sessions = {} -- [player] = { start, stats = copy, coins }
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

function GameLogService:Init(registry)
	local match = registry.MatchService
	local teams = registry.TeamService
	local build = registry.BuildService
	local shrines = registry.ShrineService
	match.Ended:Connect(function(result)
		if result.reason == "empty" then
			return
		end
		local dwarves, monsters = 0, 0
		for _, p in Players:GetPlayers() do
			local t = teams:Team(p)
			if t == "dwarf" then
				dwarves += 1
			elseif t == "monster" then
				monsters += 1
			end
		end
		GameLogService.log({
			emoji = result.winner == "dwarf" and "🏰" or "👹",
			title = result.winner == "dwarf" and `Match #{result.number}: the dwarves HELD!`
				or `Match #{result.number}: the monsters won`,
			color = result.winner == "dwarf" and COLORS.record or COLORS.journey,
			fields = {
				{ name = "Held for", value = Formulas.clock(result.held) },
				{ name = "Shrines taken", value = `{result.fallen} / 3` },
				{
					name = "How",
					value = result.reason == "held" and "held until the clock ran out"
						or result.reason == "shrines" and "the last shrine fell"
						or result.reason == "wiped" and "every dwarf fell"
						or tostring(result.reason),
				},
				{ name = "Players", value = `{dwarves} dwarves · {monsters} monsters at the end` },
				{ name = "Build time", value = Formulas.clock(result.buildSeconds or 0) },
			},
		})
	end)
	shrines.Fell:Connect(function(index)
		GameLogService.log({
			emoji = "💥",
			title = `Match #{match:State().number}: Shrine {index} fell after {Formulas.clock(match:FightSeconds())} of fighting`,
			color = COLORS.event,
		})
	end)
	build.StageChanged:Connect(function(shrine, stage)
		if stage ~= "camp" and match:InMatch() then
			GameLogService.log({
				emoji = stage == "castle" and "🏰" or "🏘️",
				title = `Match #{match:State().number}: the castle at Shrine {shrine} is a {string.upper(stage)}`,
				color = COLORS.event,
			})
		end
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
		GameLogService.log({
			emoji = "⛔",
			title = `Anti-cheat KICKED {who(player)}: {reason}`,
			color = COLORS.leave,
			url = profileUrl(player),
		})
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
		coins = profile.coins,
		tutorialDone = profile.tutorial.done == true,
	}
	player.Chatted:Connect(function(message)
		GameLogService.chat(player, message)
	end)
	local level = Formulas.accountLevel(profile.xp)
	GameLogService.log({
		emoji = "🟢",
		title = who(player) .. " joined",
		color = COLORS.join,
		url = profileUrl(player),
		fields = {
			{ name = "Player", value = profile._isNew and "🆕 New" or "Returning" },
			{ name = "Level", value = level },
			{ name = "Matches", value = profile.stats.matches },
			{ name = "Coins", value = profile.coins },
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
		{ name = "Matches", value = gained("matches") },
		{ name = "Built", value = gained("built") },
		{ name = "Monsters beaten", value = gained("beaten") },
		{ name = "Dwarves beaten", value = gained("dwarvesBeaten") },
		{ name = "Pieces broken", value = gained("broken") },
		{ name = "Mined", value = gained("mined") },
		{ name = "Coins earned", value = math.max(0, profile.coins - s.coins) },
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
