-- Loads and saves player profiles (the territory, its money, buildings, tiles, the guidance, stats) with a session
-- lock (master plan §13). In Studio without API access the DataStore calls fail; the player then gets an unsaved
-- in-memory profile and a warning toast, so the game still runs.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local STORE_NAME = Constants.PROFILE_STORE
local SCHEMA_VERSION = 1
local LOCK_STALE_SECONDS = 300
local LOAD_ATTEMPTS = 5

local PlayerDataService = {
	Name = "PlayerDataService",
	Dependencies = {},
	ClientReady = Signal.new("PlayerDataService.ClientReady"), -- (player) the client UI is listening
}

local profiles = {} -- [player] = profile
local ready = {} -- [player] = true once the client sent Ready
local store
local jobId = game.JobId ~= "" and game.JobId or "studio"

local function defaults()
	return {
		schemaVersion = SCHEMA_VERSION,
		cash = Constants.START_CASH,
		stage = "stand", -- "stand" | "shop" | "warehouse" | "center" (Data/Business)
		owned = {}, -- [upgradeKey] = level (Data/Upgrades)
		chosen = "strawberry", -- the crop planted next
		tiles = {}, -- [tileId] = { crop, at } what's growing (CropService; timers run while away)
		stock = {}, -- [cropKey] = units in the stock area / stockroom / warehouse
		animals = {}, -- [animalKey] = { fedAt, pettedAt } (AnimalService; the levels are in owned)
		task = { step = 1, done = false, goals = {}, seen = {} }, -- the guidance (TaskService)
		passes = {}, -- [passKey] = true (ShopService)
		receipts = {}, -- the Robux receipts already granted (never twice)
		cosmetics = { paint = nil, bundle = false },
		prestige = { level = 0 }, -- regions opened (every sale x2 a level, multiplied)
		away = { at = 0, rate = 0 }, -- when they last left and the income a minute then (OfflineService)
		stats = {
			planted = 0,
			harvested = 0,
			sold = 0,
			earned = 0, -- cash earned, all time
			trucks = 0,
			orders = 0,
			fed = 0, -- times an animal pen was fed
			petted = 0,
			golden = 0, -- golden crops tapped
			sessions = 0,
			minutes = 0,
			bottleneck = 0, -- the first time the store fell behind (analytics)
		},
		settings = { music = true, sounds = true },
		opening = false, -- the opening cinematic seen
		meta = { createdAt = os.time(), lastSeen = os.time(), lock = nil },
	}
end

-- Fill fields added after a profile was first saved, so old saves keep loading.
local function reconcile(profile)
	local fresh = defaults()
	for k, v in fresh do
		if profile[k] == nil then
			profile[k] = v
		end
	end
	for key, sub in fresh do
		if type(sub) == "table" and type(profile[key]) == "table" then
			for k, v in sub do
				if profile[key][k] == nil then
					profile[key][k] = v
				end
			end
		end
	end
	profile.schemaVersion = SCHEMA_VERSION
	return profile
end

PlayerDataService.defaults = defaults

local function key(player)
	return "u_" .. player.UserId
end

local function tryLoad(player)
	local result, locked
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			local now = os.time()
			if old and old.meta and old.meta.lock and old.meta.lock.jobId ~= jobId then
				if now - (old.meta.lock.at or 0) < LOCK_STALE_SECONDS then
					locked = true
					return nil
				end
			end
			local profile = reconcile(old or defaults())
			profile.meta.lock = { jobId = jobId, at = now }
			result = profile
			return profile
		end)
	end)
	if not ok then
		return nil, false, err
	end
	return result, locked, nil
end

function PlayerDataService:Init()
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	store = ok and s or nil

	Net.on("Ready", function(player)
		ready[player] = true
		if profiles[player] then
			self.ClientReady:Fire(player)
		end
	end)
	Net.on("Settings", function(player, k, v)
		local p = profiles[player]
		if p and (k == "music" or k == "sounds") and type(v) == "boolean" then
			p.settings[k] = v
		end
	end)
end

function PlayerDataService:Start()
	while true do
		task.wait(Constants.AUTOSAVE_SECONDS)
		for player in profiles do
			task.spawn(self.Save, self, player)
		end
	end
end

-- Yields until the profile is loaded. Returns nil if the player left or the profile is locked elsewhere.
function PlayerDataService:Load(player)
	local profile, failure
	if store then
		for attempt = 1, LOAD_ATTEMPTS do
			local p, locked, err = tryLoad(player)
			if p then
				profile = p
				break
			end
			failure = err
			if not locked and err and RunService:IsStudio() then
				break
			end
			if attempt < LOAD_ATTEMPTS then
				task.wait(locked and 4 or 2 * attempt)
			end
			if not player.Parent then
				return nil
			end
		end
	end
	if not profile then
		if store and not failure then
			player:Kick("Your save is still open on another server. Please rejoin in a minute.")
			return nil
		end
		if store and not RunService:IsStudio() then
			player:Kick("Couldn't load your save (Roblox is busy). Please rejoin.")
			return nil
		end
		profile = defaults()
		profile._noSave = true
		warn(`[PlayerDataService] DataStore unavailable for {player.Name}; progress will not save.`, failure or "")
		if RunService:IsStudio() then
			task.delay(3, function()
				if player.Parent then
					Net.fire(player, "Toast", "Studio: turn on API access in Game Settings to save progress.", "bad")
				end
			end)
		end
	end
	if not player.Parent then
		if not profile._noSave then
			profiles[player] = profile
			self:Save(player, true)
			profiles[player] = nil
		end
		return nil
	end
	profile._joinedAt = os.time()
	profile._isNew = (profile.stats.sessions or 0) == 0 and (profile.stats.planted or 0) == 0
	profiles[player] = profile
	if ready[player] then
		self.ClientReady:Fire(player)
	end
	return profile
end

function PlayerDataService:Get(player)
	return profiles[player]
end

-- Run fn once the player's UI is listening (now, if it already is).
function PlayerDataService:WhenClientReady(player, fn)
	if ready[player] and profiles[player] then
		task.spawn(fn)
		return
	end
	local conn
	conn = self.ClientReady:Connect(function(p)
		if p == player then
			conn:Disconnect()
			fn()
		end
	end)
end

local function serializable(profile)
	local copy = {}
	for k, v in profile do
		if string.sub(k, 1, 1) ~= "_" then
			copy[k] = v
		end
	end
	return copy
end

-- true when it's safely written (Studio without a DataStore counts: test purchases there are fine)
function PlayerDataService:Save(player, releaseLock)
	local profile = profiles[player]
	if not profile then
		return false
	end
	if profile._noSave or not store then
		return RunService:IsStudio()
	end
	profile.meta.lastSeen = os.time()
	profile.meta.lock = not releaseLock and { jobId = jobId, at = os.time() } or nil
	local data = serializable(profile)
	local wrote = false
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			if old and old.meta and old.meta.lock and old.meta.lock.jobId ~= jobId then
				wrote = false
				return nil
			end
			wrote = true
			return data
		end)
	end)
	if not ok then
		warn(`[PlayerDataService] save failed for {player.Name}: {err}`)
	end
	return ok and wrote
end

-- An admin reset: a brand-new profile in place of theirs, saved now
function PlayerDataService:Reset(player)
	if not profiles[player] then
		return false
	end
	local fresh = defaults()
	fresh._noSave = profiles[player]._noSave
	fresh._joinedAt = os.time()
	profiles[player] = fresh
	self:Save(player)
	return true
end

function PlayerDataService:Wipe(userId)
	if not store then
		return false
	end
	local ok = pcall(function()
		store:RemoveAsync("u_" .. userId)
	end)
	return ok
end

function PlayerDataService:Release(player)
	self:Save(player, true)
	profiles[player] = nil
	ready[player] = nil
end

function PlayerDataService:SaveAll()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			self:Save(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.2)
	end
end

-- Send part of the profile view to the client HUD.
function PlayerDataService:Push(player, partial)
	Net.fire(player, "Profile", partial)
end

return PlayerDataService
