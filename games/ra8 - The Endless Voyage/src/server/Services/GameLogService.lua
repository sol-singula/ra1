--[[
The game log: what we want to read goes to the team's private Discord logs channel, same pipeline as the studio's
other games (the roblox-game-log Supabase function, the "discord_log" secret, batched every few seconds):
  joins and leaves, one line each ("ra8 · 🟢 Ava (@ava) joined · new", "ra8 · 🔴 Ava (@ava) left after 12m")
  the chat
  anti-cheat flags and kicks, script errors, the server starting and shutting down
Everything else players do (every event, raft tiers, voyages, the Leviathan, achievements) is stored by
AnalyticsService in roblox_events, not posted. GAME_LOG_ACTIVITY = true would post every event as a line again
("ra8 · 📜 Activity" entries every GAME_LOG_ACTIVITY_SECONDS).
Without the secret (and in Studio) nothing is sent; why not is said in the server's log (GameKey).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ScriptContext = game:GetService("ScriptContext")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local GameKey = require(script.Parent.Parent.GameKey)

local GameLogService = {
	Name = "GameLogService",
	Dependencies = { "PlayerDataService", "AntiCheatService" },
}

local COLORS = {
	error = 0xef4444,
	server = 0x94a3b8,
}

local sessions = {} -- [player] = { start }
local queue, chat = {}, {}
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
-- ("ra8 · 🟢 @ava joined"), the emoji after it. The chat goes as entries too (so it starts with it as well),
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

-- The activity feed: a line per event, sent every GAME_LOG_ACTIVITY_SECONDS in as few entries as fit (Discord rate
-- limits the shared channel), the backlog carried over (at most MAX_LINES, the oldest dropped).
local activity = {}
local flushes = 0
local MAX_LINES = 400
local SKIP = { perf = true, focus = true }
local function clock(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
local function brief(data)
	local parts = {}
	for k, v in data or {} do
		local t = type(v)
		if k ~= "ctx" and (t == "string" or t == "number" or t == "boolean") then
			table.insert(parts, `{k}={v}`)
		end
	end
	table.sort(parts)
	local text = table.concat(parts, " ")
	return #text > 80 and (string.sub(text, 1, 79) .. "…") or text
end
function GameLogService.activity(name, seconds, kind, data)
	if not Constants.GAME_LOG_ACTIVITY or SKIP[kind] then
		return
	end
	local ctx = type(data) == "table" and type(data.ctx) == "table" and data.ctx or {}
	local where = {}
	if ctx.step then
		table.insert(where, "step " .. tostring(ctx.step))
	end
	if ctx.tiles then
		table.insert(where, `raft {ctx.tiles} tiles T{ctx.tier or 1}`)
	end
	if ctx.where then
		local v = ctx.voyage and ctx.voyage ~= "docked" and ("/" .. tostring(ctx.voyage)) or ""
		table.insert(where, tostring(ctx.where) .. v)
	end
	if ctx.doing and ctx.doing ~= kind then
		table.insert(where, "was " .. tostring(ctx.doing))
	end
	local details = brief(data)
	if kind == "snapshot" and type(data) == "table" then
		-- (every 30 s: where they are, short)
		local d = data
		details = `{d.where or "?"}{d.voyage and d.voyage ~= "docked" and ("/" .. tostring(d.voyage)) or ""}`
			.. ` · raft {d.tiles or "?"} tiles T{d.tier or 1} · lvl {d.level or "?"} · hp {d.hp or "?"}`
			.. (d.tutorial_step and ` · step {d.tutorial_step}` or "")
			.. (d.idle and " · idle" or "")
			.. (d.ping_ms and ` · {d.ping_ms} ms` or "")
	end
	local line = `\`{clock(seconds)}\` **{plain(string.sub(tostring(name), 1, 30))}** {plain(kind)}`
		.. (details ~= "" and (" " .. plain(details)) or "")
		.. (#where > 0 and (" · " .. plain(table.concat(where, " · "))) or "")
	table.insert(activity, line)
	if #activity > MAX_LINES then
		table.remove(activity, 1)
	end
end

-- (force: send the activity feed now, whatever the time)
function GameLogService.flush(force)
	flushes += 1
	local every = math.max(1, math.floor(Constants.GAME_LOG_ACTIVITY_SECONDS / Constants.GAME_LOG_FLUSH_SECONDS + 0.5))
	local activityDue = #activity > 0 and (force or flushes % every == 0)
	if #queue == 0 and #chat == 0 and not activityDue then
		return
	end
	local events = {}
	for _, e in queue do
		table.insert(events, tagged(e))
	end
	-- the activity feed, every GAME_LOG_ACTIVITY_SECONDS: up to 6 entries of lines, the rest next time
	if activityDue then
		local entries = 0
		while #activity > 0 and entries < 6 do
			local text = ""
			while #activity > 0 and #text + #activity[1] + 1 <= 1900 do
				text = text == "" and table.remove(activity, 1) or (text .. "\n" .. table.remove(activity, 1))
			end
			if text == "" then
				text = string.sub(table.remove(activity, 1), 1, 1900)
			end
			entries += 1
			table.insert(events, { title = `{Constants.GAME} · 📜 Activity`, color = 0x64748b, description = text })
		end
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

function GameLogService:Init(registry)
	registry.AntiCheatService.Flagged:Connect(function(player, kind, detail, strikes)
		if strikes >= 3 then
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
	GameLogService.log({ emoji = "🟦", title = "Server started", color = COLORS.server })
	while true do
		task.wait(Constants.GAME_LOG_FLUSH_SECONDS)
		GameLogService.flush()
	end
end

function GameLogService:OnPlayerReady(player, profile)
	peakPlayers = math.max(peakPlayers, #Players:GetPlayers())
	sessions[player] = { start = os.time() }
	player.Chatted:Connect(function(message)
		GameLogService.chat(player, message)
	end)
	GameLogService.log({
		emoji = "🟢",
		title = `{who(player)} joined · {profile._isNew and "new" or "returning"}`,
		line = true,
	})
end

function GameLogService:OnPlayerLeaving(player)
	local s = sessions[player]
	sessions[player] = nil
	if s then
		GameLogService.log({
			emoji = "🔴",
			title = `{who(player)} left after {Format.time(os.time() - s.start)}`,
			line = true,
			-- (they're still in the list while leaving: the count is the server without them)
			players = #Players:GetPlayers() - (player.Parent and 1 or 0),
		})
	end
end

return GameLogService
