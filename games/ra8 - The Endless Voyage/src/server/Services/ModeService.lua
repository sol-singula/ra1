--[[
The start menu's choices (MenuController) and the servers behind them:
  MY WORLD       your own reserved server, the same one every time (its access code is kept per player in a
                 DataStore). Friends come along with INVITE: the invite's launch data names your world, and a friend
                 who joins through it is sent straight there.
  PUBLIC OCEAN   an ordinary public server: other players' rafts nearby, each their own (you look at each other's
                 rafts from VISIT, you never sail up to them). Your raft is saved to you, so it comes along.
A public server is the hub: the game plays as usual behind the menu, so picking PUBLIC OCEAN there just closes it.
In Studio, or when a teleport fails, the menu closes and you play right where you are.
]]
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ModeService = {
	Name = "ModeService",
	Dependencies = {},
	Chose = Signal.new("ModeService.Chose"), -- (player, "world" | "public", ok)
}

local WORLDS = "EV_Worlds_v1" -- [userId] = { code }
local NOPE = "🌊 Couldn't travel right now, so you're playing right here."

local function reserved()
	return game.PrivateServerId ~= nil and game.PrivateServerId ~= "" and (game.PrivateServerOwnerId or 0) == 0
end

function ModeService:Mode()
	return workspace:GetAttribute("Mode") or "hub"
end

-- The first arrival's teleport data says whose world a reserved server is.
local function fromJoin(player)
	local ok, jd = pcall(player.GetJoinData, player)
	local td = ok and jd and jd.TeleportData
	if reserved() and type(td) == "table" and td.mode == "world" and workspace:GetAttribute("Mode") == nil then
		workspace:SetAttribute("Mode", "world")
		workspace:SetAttribute("WorldOwner", tonumber(td.owner) or 0)
		workspace:SetAttribute("WorldOwnerName", tostring(td.ownerName or ""))
	end
	return ok and jd or nil
end

local function teleport(player, code, data)
	return pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData(data)
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
end

-- Your world's access code (made the first time when `make`).
function ModeService:WorldCode(userId, make)
	local ok, st = pcall(DataStoreService.GetDataStore, DataStoreService, WORLDS)
	if not ok or not st then
		return nil
	end
	local code
	local done = pcall(function()
		st:UpdateAsync(tostring(userId), function(old)
			if type(old) == "table" and type(old.code) == "string" then
				code = old.code
				return nil
			end
			if not make then
				return nil
			end
			code = TeleportService:ReserveServer(game.PlaceId)
			return { code = code }
		end)
	end)
	return done and code or nil
end

local function playHere(player, why)
	Net.fire(player, "Menu", { close = true, note = why })
end

function ModeService:Choose(player, kind)
	if kind ~= "world" and kind ~= "public" then
		return false
	end
	local mode = self:Mode()
	local mine = mode == "world" and workspace:GetAttribute("WorldOwner") == player.UserId
	if (kind == "world" and mine) or (kind == "public" and mode == "hub") then
		playHere(player) -- already there
		return true
	end
	if RunService:IsStudio() then
		playHere(player, "🧪 In Studio you play right here (the real game takes you there).")
		self.Chose:Fire(player, kind, false)
		return false
	end
	local ok
	if kind == "public" then
		Net.fire(player, "Menu", { travelling = kind })
		ok = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player })
	else
		local code = self:WorldCode(player.UserId, true)
		if code then
			Net.fire(player, "Menu", { travelling = kind })
			ok = teleport(player, code, { mode = "world", owner = player.UserId, ownerName = player.DisplayName })
		end
	end
	if not ok then
		playHere(player, NOPE)
	end
	self.Chose:Fire(player, kind, ok == true)
	return ok == true
end

-- A friend's invite: its launch data names a world ("w:<userId>").
function ModeService:_launch(player, launch)
	if type(launch) ~= "string" or RunService:IsStudio() then
		return false
	end
	local owner = tonumber(string.match(launch, "^w:(%d+)$"))
	if not owner or (self:Mode() == "world" and workspace:GetAttribute("WorldOwner") == owner) then
		return false
	end
	local code = self:WorldCode(owner, false)
	if not code then
		return false
	end
	Net.fire(player, "Menu", { travelling = "friend" })
	return teleport(player, code, { mode = "world", owner = owner })
end

function ModeService:Init()
	Players.PlayerAdded:Connect(function(player)
		local jd = fromJoin(player)
		if self:Mode() == "hub" and jd and jd.LaunchData and jd.LaunchData ~= "" then
			task.defer(function()
				self:_launch(player, jd.LaunchData)
			end)
		end
	end)
	for _, player in Players:GetPlayers() do
		fromJoin(player)
	end
	Net.on("Mode", function(player, kind)
		self:Choose(player, kind)
	end)
	TeleportService.TeleportInitFailed:Connect(function(player)
		playHere(player, NOPE)
	end)
end

return ModeService
