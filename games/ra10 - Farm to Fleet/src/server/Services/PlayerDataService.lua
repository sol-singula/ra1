-- Loads and saves player profiles (the farm, its money, animals, orders, the guide, the calendar) with a session lock.
-- In Studio without API access the DataStore calls fail; the player then gets an unsaved in-memory profile
-- and a warning toast, so the game still runs.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local STORE_NAME = Constants.PROFILE_STORE
local SCHEMA_VERSION = 1
local LOCK_STALE_SECONDS = 300 -- a live server refreshes its lock at every autosave (120 s)
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
		cash = Constants.START_CASH, -- the farm's money (EconomyService)
		gems = Constants.START_GEMS, -- skips, golden seeds, cosmetics
		goldenSeeds = 0, -- each makes the next planting golden (the calendar, the shop)
		passes = {}, -- [passKey] = true: the game passes owned (ShopService)
		xp = 0, -- farm XP: the level gates unlocks (Data/Levels)
		level = 1,
		stage = 1, -- 1 shack, 2 farm, 3 packing shed, 4 warehouse, 5 distribution hub (master plan §4)
		owned = {}, -- [upgradeKey] = level: every buy-pad and machine bought (UpgradeService)
		soil = {}, -- [tileIndex] = { crop, plantedAt } what's growing (FarmService; timers run while away)
		storage = {}, -- [cropKey] = n harvested and not sold yet
		animals = {}, -- [penKey] = { level, fedAt, n } (AnimalService)
		orders = { done = 0, daily = { day = 0, done = {} }, weekly = { week = 0, parts = {} } }, -- (OrderService)
		guide = { chapter = 1, step = 1, done = false }, -- the guide's place (GuideService): 100% of the game
		calendar = { day = 0, streak = 0, claimedDay = 0 }, -- the 7-day calendar (DailyService)
		away = { at = 0 }, -- when they last left: offline earnings (OfflineService)
		stats = {
			harvested = 0,
			sold = 0,
			earned = 0, -- Cash earned, all time (the NET WORTH board reads more than this)
			shipments = 0, -- orders filled
			minutes = 0,
		},
		settings = { music = true, sounds = true },
		receipts = {}, -- the Robux receipts already granted (never twice)
		starter = false, -- the Starter Pack given
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
	-- and one level down in every table (a new stat, a new record, a new setting)
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
					return nil -- another server still owns this profile; do not write
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
				break -- (Studio with API access off: fall back below at once)
			end
			if attempt < LOAD_ATTEMPTS then
				task.wait(locked and 4 or 2 * attempt) -- (live, a busy DataStore: try again, a little later each time)
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
			-- (never play on a blank profile that can't save: it looks like a wipe, and a purchase would be lost)
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
		-- (gone while it loaded: let go of the lock this load just took, or their next server waits for it)
		if not profile._noSave then
			profiles[player] = profile
			self:Save(player, true)
			profiles[player] = nil
		end
		return nil
	end
	profile._joinedAt = os.time()
	profile._isNew = (profile.meta.createdAt or 0) >= os.time() - 5 and (profile.stats.harvested or 0) == 0
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
				return nil -- lost the lock (another server stole a stale session); never overwrite it
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
