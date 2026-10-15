--[[
The start menu's choices (MenuController) and the servers behind them:
  MY WORLD   your own reserved server, the same one every time (its access code is kept per player in a
             DataStore), so your raft is always where you left it. Friends come along with INVITE: the invite's
             launch data names your world, and a friend who joins through it is sent straight there.
  ONLINE     the shared ocean: a reserved server everyone is sent to, where one giant ship belongs to everybody
             (RaftService saves it for everyone; servers that run at the same time keep each other in step).
             When one is full, the next one opens; they all build the same ship.
A public server is a hub: the game plays as usual behind the menu (and is where Studio plays), so nothing waits on
a teleport. In Studio, or when a teleport fails, the menu just closes and you play right there.
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
	Chose = Signal.new("ModeService.Chose"), -- (player, "world" | "online", ok)
}

local WORLDS = "EV_Worlds_v1" -- [userId] = { code }
local ONLINE = "EV_Online_v1" -- "servers" = { code, code, ... }
local tries = {} -- [player] = { kind, index } (an online server that was full: try the next)

local function reserved()
	return game.PrivateServerId ~= nil and game.PrivateServerId ~= "" and (game.PrivateServerOwnerId or 0) == 0
end

local function store(name)
	local ok, s = pcall(DataStoreService.GetDataStore, DataStoreService, name)
	return ok and s or nil
end

function ModeService:Mode()
	return workspace:GetAttribute("Mode") or "hub"
end

-- The first arrival's teleport data says what a reserved server is for.
local function fromJoin(player)
	local ok, jd = pcall(player.GetJoinData, player)
	local td = ok and jd and jd.TeleportData
	if reserved() and type(td) == "table" and workspace:GetAttribute("Mode") == nil then
		if td.mode == "online" then
			workspace:SetAttribute("Mode", "online")
		elseif td.mode == "world" then
			workspace:SetAttribute("Mode", "world")
			workspace:SetAttribute("WorldOwner", tonumber(td.owner) or 0)
			workspace:SetAttribute("WorldOwnerName", tostring(td.ownerName or ""))
		end
	end
	return ok and jd or nil
end

local function teleport(player, code, data)
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = code
		options:SetTeleportData(data)
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	return ok, err
end

-- Your world's access code (made the first time).
function ModeService:WorldCode(userId, make)
	local s = store(WORLDS)
	if not s then
		return nil
	end
	local code
	local ok = pcall(function()
		s:UpdateAsync(tostring(userId), function(old)
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
	return ok and code or nil
end

-- The online servers' codes; index past the end opens a new one.
function ModeService:OnlineCode(index)
	local s = store(ONLINE)
	if not s then
		return nil
	end
	local code
	local ok = pcall(function()
		s:UpdateAsync("servers", function(old)
			local list = type(old) == "table" and old or {}
			if list[index] then
				code = list[index]
				return nil
			end
			code = TeleportService:ReserveServer(game.PlaceId)
			table.insert(list, code)
			return list
		end)
	end)
	return ok and code or nil
end

local function playHere(player, why)
	Net.fire(player, "Menu", { close = true, note = why })
end

function ModeService:Choose(player, kind)
	if kind ~= "world" and kind ~= "online" then
		return false
	end
	local mode = self:Mode()
	-- already there
	if
		(kind == "world" and mode == "world" and workspace:GetAttribute("WorldOwner") == player.UserId)
		or (kind == "online" and mode == "online")
	then
		playHere(player)
		return true
	end
	if RunService:IsStudio() then
		playHere(player, "🧪 In Studio you play right here (the real game takes you to your world or online).")
		self.Chose:Fire(player, kind, false)
		return false
	end
	local code, data
	if kind == "world" then
		code = self:WorldCode(player.UserId, true)
		data = { mode = "world", owner = player.UserId, ownerName = player.DisplayName }
	else
		tries[player] = { kind = "online", index = 1 }
		code = self:OnlineCode(1)
		data = { mode = "online" }
	end
	if not code then
		playHere(player, "🌊 Couldn't travel right now, so you're playing right here.")
		self.Chose:Fire(player, kind, false)
		return false
	end
	Net.fire(player, "Menu", { travelling = kind })
	local ok = teleport(player, code, data)
	if not ok then
		playHere(player, "🌊 Couldn't travel right now, so you're playing right here.")
	end
	self.Chose:Fire(player, kind, ok)
	return ok
end

-- A friend's invite: its launch data names a world ("w:<userId>") or the online ocean ("online").
function ModeService:_launch(player, launch)
	if type(launch) ~= "string" or launch == "" or RunService:IsStudio() then
		return false
	end
	if launch == "online" then
		return self:Choose(player, "online")
	end
	local owner = tonumber(string.match(launch, "^w:(%d+)$"))
	if not owner then
		return false
	end
	if self:Mode() == "world" and workspace:GetAttribute("WorldOwner") == owner then
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
		if self:Mode() == "hub" and jd and jd.LaunchData then
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
	TeleportService.TeleportInitFailed:Connect(function(player, result)
		local t = tries[player]
		-- an online server that's full: the next one (made if needed)
		if t and t.kind == "online" and result == Enum.TeleportResult.GameFull and t.index < 20 then
			t.index += 1
			local code = self:OnlineCode(t.index)
			if code and teleport(player, code, { mode = "online" }) then
				return
			end
		end
		tries[player] = nil
		playHere(player, "🌊 Couldn't travel right now, so you're playing right here.")
	end)
	Players.PlayerRemoving:Connect(function(player)
		tries[player] = nil
	end)
end

return ModeService
