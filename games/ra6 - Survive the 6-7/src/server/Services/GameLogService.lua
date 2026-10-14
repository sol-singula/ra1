--[[
The game log: everything worth knowing goes to the team's private Discord logs channel, same pipeline as the
studio's other games (the roblox-game-log Supabase function, the "discord_log" secret, batched every few seconds):
  joins (new or returning, level, runs, wins, best difficulty) and leaves with how the session went (time played,
  runs, nights survived, monsters, Kermy knocked out, wood, things built and crafted, crates opened, levels)
  the chat
  runs: each one that ends (won or lost and how, nights, difficulty, time, players, the stars of the run), Mega
  Kermy rising on night 7, the camp growing into an Outpost, a Fort or a Stronghold, a new difficulty unlocked
  anti-cheat flags and kicks, script errors, the server starting and shutting down
Without the secret (and in Studio) nothing is sent.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Camp = require(ReplicatedStorage.Shared.Data.Camp)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)

local GameLogService = {
	Name = "GameLogService",
	Dependencies = {
		"PlayerDataService",
		"RunService",
		"SurvivorService",
		"CampService",
		"BossService",
		"ProgressService",
		"AntiCheatService",
	},
}

local COLORS = {
	join = 0x10b981,
	leave = 0xe11d48,
	record = 0xf5c518,
	run = 0x38bdf8,
	event = 0xa855f7,
	error = 0xef4444,
	server = 0x94a3b8,
}

local sessions = {} -- [player] = { start, stats = copy, records = copy, xp, tutorialDone }
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

local function difficultyName(n)
	local d = Constants.DIFFICULTIES[n or 1]
	return d and d.name or "Normal"
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

local HOW = {
	boss = "Mega Kermy went down",
	wipe = "everyone fell",
	dawn = "night 7 ran out: Mega Kermy got away",
}

function GameLogService:Init(registry)
	local runs = registry.RunService
	local survivors = registry.SurvivorService
	local camp = registry.CampService
	local boss = registry.BossService
	local progress = registry.ProgressService
	local data = registry.PlayerDataService
	runs.Ended:Connect(function(result)
		if result.reason == "empty" then
			return
		end
		local team = {}
		for _, p in runs:Active() do
			local s = survivors:Stats(p)
			local r = progress:RunStats(p)
			table.insert(team, `{p.DisplayName}: ⚔️ {r.kills} · 🤝 {s.revives} · 💀 {s.downs}`)
		end
		local rosterSize = 0
		for _ in result.roster do
			rosterSize += 1
		end
		GameLogService.log({
			emoji = result.won and "🏆" or "💀",
			title = result.won and `Run #{result.number}: SURVIVED THE 6-7 on {difficultyName(result.difficulty)}!`
				or `Run #{result.number}: lost on night {math.max(1, result.night)} ({difficultyName(result.difficulty)})`,
			color = result.won and COLORS.record or COLORS.run,
			fields = {
				{ name = "How", value = HOW[result.reason] or tostring(result.reason) },
				{ name = "Nights survived", value = `{result.nights} / 7` },
				{ name = "Run time", value = Formulas.clock(result.seconds) },
				{ name = "Camp", value = (Camp.TIERS[camp:Tier()] or Camp.TIERS[1]).name },
				{ name = "Players", value = `{result.players} at the end · {rosterSize} in the roster` },
				{ name = "Team", value = #team > 0 and table.concat(team, "\n") or "-" },
			},
		})
	end)
	runs.BossStarted:Connect(function(run)
		GameLogService.log({
			emoji = "👹",
			title = `Run #{run.number}: night 7, Mega Kermy rises ({#runs:Active()} survivors, {difficultyName(
				run.difficulty
			)})`,
			color = COLORS.event,
		})
	end)
	boss.Defeated:Connect(function(_, killer)
		local run = runs:Get()
		GameLogService.log({
			emoji = "🐸",
			title = `Run #{run and run.number or "?"}: Mega Kermy is down{killer and (", last hit by " .. killer.DisplayName) or ""}`,
			color = COLORS.record,
		})
	end)
	camp.TierUp:Connect(function(tier, player)
		if tier <= 1 then
			return
		end
		local run = runs:Get()
		GameLogService.log({
			emoji = tier >= 4 and "🏰" or "🏕️",
			title = `Run #{run and run.number or "?"}: the camp is now {Camp.TIERS[tier].name} (day {runs:Day()}{player and (", " .. player.DisplayName) or ""})`,
			color = COLORS.event,
		})
	end)
	progress.Rewarded:Connect(function(player, result)
		local profile = data:Get(player)
		if result.won and profile and profile.unlocked > result.difficulty then
			local s = sessions[player]
			if s and (s.unlocked or 1) < profile.unlocked then
				s.unlocked = profile.unlocked
				GameLogService.log({
					emoji = "💀",
					title = `{who(player)} unlocked {difficultyName(profile.unlocked)}`,
					color = COLORS.record,
					url = profileUrl(player),
				})
			end
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
		records = table.clone(profile.records),
		xp = profile.xp,
		unlocked = profile.unlocked,
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
			{ name = "Level", value = (Formulas.level(profile.xp)) },
			{ name = "Runs", value = `{profile.stats.runs} ({profile.stats.wins} won)` },
			{
				name = "Best",
				value = profile.records.bestDifficulty > 0 and ("won on " .. difficultyName(
					profile.records.bestDifficulty
				)) or `night {profile.records.bestNight}`,
			},
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
	local function record(k)
		return (profile.records[k] or 0) - (s.records[k] or 0)
	end
	local levelNow, levelThen = Formulas.level(profile.xp), Formulas.level(s.xp)
	local stats = {
		{ name = "Time played", value = Format.time(os.time() - s.start) },
		{ name = "Runs", value = `{gained("runs")} ({gained("wins")} won)` },
		{ name = "Nights survived", value = record("nights") },
		{ name = "Monsters", value = record("monsters") },
		{ name = "Kermy knocked out", value = gained("kermyKO") },
		{ name = "Wood", value = gained("wood") },
		{ name = "Built / crafted", value = `{gained("built")} / {gained("crafted")}` },
		{ name = "Crates opened", value = gained("looted") },
		{ name = "Level", value = levelNow > levelThen and `{levelThen} → {levelNow}` or tostring(levelNow) },
	}
	if not s.tutorialDone and profile.tutorial.done then
		table.insert(stats, { name = "Guide", value = "✅ finished this session" })
	end
	return stats
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
