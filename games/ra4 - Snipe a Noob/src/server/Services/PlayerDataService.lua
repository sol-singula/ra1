-- Loads and saves player profiles with a session lock.
-- In Studio without API access the DataStore calls fail; the player then gets an unsaved in-memory profile
-- and a warning toast, so the game still runs.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local STORE_NAME = "SAN_Profiles_v1"
local SCHEMA_VERSION = 1
local LOCK_STALE_SECONDS = 300
local LOAD_ATTEMPTS = 5

local PlayerDataService = {
	Name = "PlayerDataService",
	Dependencies = {},
	ClientReady = Signal.new("PlayerDataService.ClientReady"), -- (player) the client UI is listening
}

local profiles = {}
local ready = {}
local store
local jobId = game.JobId ~= "" and game.JobId or "studio"

local function defaults()
	return {
		schemaVersion = SCHEMA_VERSION,
		coins = Constants.START_COINS,
		keys = 0, -- crate keys
		earned = 0, -- lifetime coins earned
		xp = 0, -- lifetime XP (the level comes from it)
		stats = {
			pops = 0,
			deaths = 0,
			headshots = 0,
			wins = 0,
			rounds = 0,
			bestStreak = 0,
			crowns = 0,
			podiums = 0,
			streak5 = 0,
			duelWins = 0,
			friendPlay = 0,
			robots = 0,
		},
		rifles = { BOLT = true }, -- owned rifles
		rifle = "BOLT", -- the one in your hands
		rifle2 = nil, -- the second rifle (Extra Loadout pass)
		mastery = {}, -- [rifleKey] = pops with it
		skins = {}, -- { uid, id }
		nextUid = 1,
		skinOn = {}, -- [rifleKey] = skin uid
		effects = { BRICKS = true },
		effect = "BRICKS",
		emotes = { WAVE = true },
		emote = "WAVE",
		crosshairs = { DOT = true },
		crosshair = "DOT",
		nameColors = { WHITE = true },
		nameColor = "WHITE",
		bought = {}, -- [period] = { [index] = true } Daily Shop buys
		dailyPops = { period = nil, pops = 0 }, -- for TODAY'S TOP SNIPERS
		prizes = {}, -- [period] = true
		season = { n = nil, xp = 0, pass = false, claimed = {} },
		quests = nil, -- { day, start = stats at the start of the day, list = { indices }, done = { [i] = true } }
		callout = nil, -- a bought Round Callout waiting for the next round
		passes = {},
		receipts = {},
		daily = { streak = 0, lastDay = nil },
		playtime = nil, -- { day, seconds, given }
		newBoostLeft = nil, -- seconds of the new-player 2x boost (nil until first join sets it)
		firstRoundDone = false,
		meta = { createdAt = os.time(), lastSeen = os.time(), lock = nil },
	}
end

local function reconcile(profile)
	local fresh = defaults()
	for k, v in fresh do
		if profile[k] == nil then
			profile[k] = v
		end
	end
	for k, v in fresh.stats do
		if profile.stats[k] == nil then
			profile.stats[k] = v
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
end

function PlayerDataService:Start()
	while true do
		task.wait(Constants.AUTOSAVE_SECONDS)
		for player in profiles do
			task.spawn(self.Save, self, player)
		end
	end
end

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
			if not locked and err then
				break
			end
			if attempt < LOAD_ATTEMPTS then
				task.wait(4)
			end
			if not player.Parent then
				return nil
			end
		end
	end
	if not profile then
		if store and not failure then
			player:Kick("Your game is still open on another server. Please rejoin in a minute.")
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
		return nil
	end
	profile._joinedAt = os.time()
	profile._isNew = profile.meta.createdAt >= os.time() - 5 and profile.stats.rounds == 0
	profiles[player] = profile
	if ready[player] then
		self.ClientReady:Fire(player)
	end
	return profile
end

function PlayerDataService:Get(player)
	return profiles[player]
end

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

function PlayerDataService:Save(player, releaseLock)
	local profile = profiles[player]
	if not profile or profile._noSave or not store then
		return
	end
	profile.meta.lastSeen = os.time()
	profile.meta.lock = not releaseLock and { jobId = jobId, at = os.time() } or nil
	local data = serializable(profile)
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function(old)
			if old and old.meta and old.meta.lock and old.meta.lock.jobId ~= jobId then
				return nil
			end
			return data
		end)
	end)
	if not ok then
		warn(`[PlayerDataService] save failed for {player.Name}: {err}`)
	end
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

function PlayerDataService:Push(player, partial)
	Net.fire(player, "Profile", partial)
end

return PlayerDataService
