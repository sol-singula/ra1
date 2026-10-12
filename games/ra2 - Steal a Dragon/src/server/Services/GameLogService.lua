-- Game log: tells the team's Discord logs channel when someone joins, and when they leave, how their session went
-- (time played, coins earned, dragons bought and stolen, Robux spent...). Posts go through the roblox-game-log
-- Supabase function (solbuild.net project), which sends the Discord message.
--
-- Setup: HTTP requests are on in default.project.json, and the key lives in the experience's Roblox Secrets
-- Store under the name "discord_log" (Creator Dashboard -> the experience -> Secrets), because this code is
-- public. Without that secret (and in Studio) nothing is sent.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)

local GameLogService = {
	Name = "GameLogService",
	Dependencies = { "PlayerDataService", "BaseService", "DragonService", "ShopService", "LeaderboardService" },
}

local baseService, dragons, shop
local sessions = {} -- [player] = { start, earned, coins, steals, bought, bonks, locks, robux, items, robbed }
local secret -- the key from the Secrets Store, or false if there isn't one

function GameLogService:Init(registry)
	baseService = registry.BaseService
	dragons = registry.DragonService
	shop = registry.ShopService
	shop.Purchased:Connect(function(player, name, robux)
		local s = sessions[player]
		if s then
			s.robux += robux or 0
			table.insert(s.items, name)
		end
	end)
	dragons.StealStarted:Connect(function(_, victim)
		local s = sessions[victim]
		if s then
			s.robbed += 1
		end
	end)
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
	local d = Dragons.byId[bestRec.id]
	local special = bestRec.sp and (Dragons.Specials[bestRec.sp].name .. " ") or ""
	return `{special}{d.name} ({d.rarity}) · {Format.num(best)}/s`
end

-- Post one event (also the hook tests replace).
function GameLogService.post(payload)
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
	task.spawn(function()
		local ok, res = pcall(HttpService.RequestAsync, HttpService, {
			Url = Constants.GAME_LOG_URL,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json", ["X-Game-Key"] = secret },
			Body = HttpService:JSONEncode(payload),
		})
		if not ok or not res.Success then
			warn("[GameLog] post failed: " .. tostring(ok and res.StatusCode or res))
		end
	end)
	return true
end

local function server()
	return {
		players = #Players:GetPlayers(),
		jobId = game.JobId ~= "" and game.JobId or nil,
		version = game.PlaceVersion,
		studio = RunService:IsStudio(),
	}
end

local function who(player)
	return { name = player.Name, displayName = player.DisplayName, userId = player.UserId }
end

function GameLogService:OnPlayerReady(player, profile)
	sessions[player] = {
		start = os.time(),
		earned = profile.earned,
		steals = profile.steals,
		bought = profile.stats.bought,
		bonks = profile.stats.bonks,
		locks = profile.stats.locks,
		tutorialDone = profile.tutorialDone,
		robux = 0,
		items = {},
		robbed = 0,
	}
	GameLogService.post({
		event = "join",
		player = who(player),
		stats = {
			{ name = "Player", value = profile._isNew and "🆕 New" or "Returning" },
			{ name = "Coins", value = Format.num(profile.coins) },
			{ name = "Dragons", value = #profile.dragons },
			{ name = "Best dragon", value = bestDragon(profile) },
			{ name = "Account age", value = (player.AccountAge or 0) .. " days" },
		},
		server = server(),
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
		local srv = server()
		srv.players = math.max(0, srv.players - 1)
		GameLogService.post({ event = "leave", player = who(player), stats = stats, server = srv })
	end
end

return GameLogService
