--[[
Your world (MenuController's start menu) and the servers behind it:
  PLAY           your own world: a reserved server, the same one every time (its access code is kept per player in
                 a DataStore). A public server is only the doorway: PLAY sends you on to your world. In Studio, or
                 when a teleport fails, the menu closes and you play right where you are.
  INVITE         friends come to YOUR world: the invite's launch data names it, and a friend who joins through it
                 is sent straight there. When a friend arrives you both get a supply crate (once a day per friend).
                 The game nudges you to invite when there's something to show (a bigger raft, a first voyage).
  RESET          start your world over: the raft back to the driftwood platform and an empty bag with the rod (your
                 level, journal, blueprints and achievements stay). Only while you're at your spot, not on a trip.
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
	Dependencies = { "PlayerDataService", "RaftService", "InventoryService", "VoyageService" },
	Chose = Signal.new("ModeService.Chose"), -- (player, "world", ok)
	Reset = Signal.new("ModeService.Reset"), -- (player) a world started over
	FriendCame = Signal.new("ModeService.FriendCame"), -- (owner, friend) a friend came to see your world
}

local WORLDS = "EV_Worlds_v1" -- [userId] = { code }
local NUDGE_MAX = 1 -- "bring a friend?" cards a session
-- The moments that are better with a friend, each asked about once ever (profile.nudged): not every bigger raft or
-- every trip, so the card means something when it comes.
local MOMENTS = {
	first_trip = "🏝️ Your first trip! Islands are more fun with a friend. Bring one on the next voyage?",
	mist = "🌫️ Your raft can reach Mist Hollow now. Something hides in the reeds: bring a friend to watch your back?",
	trench = "🐋 Your raft can face the Trench now. The Leviathan is easier with a friend on the harpoons!",
}
local registry
local nudges = {} -- [player] = cards this session
local friendHere = {} -- [player] = true once a friend of theirs is in this server
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
	if kind ~= "world" then
		return false
	end
	if self:Mode() == "world" then
		playHere(player) -- already in a world (yours, or the friend's you came to see)
		return true
	end
	if RunService:IsStudio() then
		playHere(player, "🧪 In Studio you play right here (the real game takes you there).")
		self.Chose:Fire(player, kind, false)
		return false
	end
	local ok
	local code = self:WorldCode(player.UserId, true)
	if code then
		Net.fire(player, "Menu", { travelling = kind })
		ok = teleport(player, code, { mode = "world", owner = player.UserId, ownerName = player.DisplayName })
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
	local code = self:WorldCode(owner, true)
	if not code then
		return false
	end
	Net.fire(player, "Menu", { travelling = "friend" })
	return teleport(player, code, { mode = "world", owner = owner })
end

-- RESET MY WORLD: the raft and the bag start over (not on a trip).
function ModeService:ResetWorld(player)
	local rafts, inventory, voyages = registry.RaftService, registry.InventoryService, registry.VoyageService
	local raft = rafts:RaftOf(player)
	if not raft then
		return false
	end
	if voyages:State(raft.plot) ~= "docked" then
		Net.fire(player, "Toast", "⛵ Finish your trip first, then you can start over.", "bad")
		return false
	end
	rafts:Reset(player)
	inventory:Reset(player)
	Net.fire(player, "Alert", "🌊 A FRESH START", Color3.fromRGB(140, 220, 255), 3)
	Net.fire(
		player,
		"Toast",
		"Your raft is a little driftwood platform again. Cast your rod at what floats by! 🎣",
		"good"
	)
	self.Reset:Fire(player)
	return true
end

-- "Bring a friend?" at one of the MOMENTS: once ever per moment, one card a session, and never when a friend is
-- already here with you (in your world, or in the same ocean).
function ModeService:Nudge(player, moment)
	local text = MOMENTS[moment]
	local profile = registry.PlayerDataService:Get(player)
	if not text or not profile then
		return false
	end
	profile.nudged = profile.nudged or {}
	if profile.nudged[moment] or (nudges[player] or 0) >= NUDGE_MAX or friendHere[player] then
		return false
	end
	if self:Mode() == "world" and workspace:GetAttribute("WorldOwner") ~= player.UserId then
		return false -- (you came to a friend's world: they're right here)
	end
	profile.nudged[moment] = os.time()
	nudges[player] = (nudges[player] or 0) + 1
	Net.fire(player, "Nudge", { kind = "invite", text = text, moment = moment })
	return true
end

-- (tests) a fresh session: no cards shown yet, no friend seen yet
function ModeService._resetNudges(player)
	nudges[player] = nil
	friendHere[player] = nil
end

-- Friends in the same server (so nobody is asked to invite someone who's already here).
local function noteFriends(player)
	task.spawn(function()
		for _, other in Players:GetPlayers() do
			if other ~= player then
				local ok, yes = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and yes then
					friendHere[player] = true
					friendHere[other] = true
				end
			end
		end
	end)
end

-- A friend came to your world: a crate for both of you (once a day per friend).
function ModeService:OnPlayerReady(player)
	if self:Mode() ~= "world" then
		return
	end
	local ownerId = workspace:GetAttribute("WorldOwner")
	if not ownerId or ownerId == player.UserId then
		return
	end
	local owner = Players:GetPlayerByUserId(ownerId)
	local data = registry.PlayerDataService
	local profile = owner and data:Get(owner)
	if not owner or not profile then
		return
	end
	profile.friendVisits = profile.friendVisits or {}
	local day = os.date("!%Y-%m-%d")
	local key = tostring(player.UserId)
	if profile.friendVisits[key] == day then
		return
	end
	profile.friendVisits[key] = day
	data:WhenClientReady(player, function()
		registry.InventoryService:Give(owner, "supply_crate", 1, "friend", { data = { danger = 1 } })
		registry.InventoryService:Give(player, "supply_crate", 1, "friend", { data = { danger = 1 } })
		Net.fire(
			owner,
			"Callout",
			`🎁 {player.DisplayName} came to see your raft! You both got a supply crate.`,
			"good"
		)
		Net.fire(player, "Callout", `🎁 Welcome to {owner.DisplayName}'s world! You both got a supply crate.`, "good")
		self.FriendCame:Fire(owner, player)
	end)
end

function ModeService:Init(reg)
	registry = reg
	Net.on("ResetWorld", function(player)
		self:ResetWorld(player)
	end)
	-- the moments that are better with a friend (MOMENTS)
	reg.RaftService.TierChanged:Connect(function(player, _, tier, old)
		if player and tier > (old or 0) then
			if tier >= 5 then
				self:Nudge(player, "trench")
			elseif tier >= 3 then
				self:Nudge(player, "mist")
			end
		end
	end)
	reg.VoyageService.Ended:Connect(function(_, _, aboard)
		for _, player in aboard or {} do
			self:Nudge(player, "first_trip")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		nudges[player] = nil
		friendHere[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		noteFriends(player)
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
