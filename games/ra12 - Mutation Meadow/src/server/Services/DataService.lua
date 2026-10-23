--[[
Loads, locks, autosaves and releases every player's profile (§2 DataService).

  DataService.TEMPLATE               a new profile's defaults (frozen)
  DataService.Loaded(player, profile)    fires once the profile is loaded and locked to this server
  DataService.Leaving(player, profile)   fires as a loaded player leaves, before the final save
  DataService.get(player)            the live profile, or nil until loaded (and after a lost lock)
  DataService.check(player)          true, or false + "not_loaded" (NetService rejects requests with it)
  DataService.save(player, reason)   -> Promise<boolean> through the SaveQueue
  DataService.close()                the BindToClose body: final saves for everyone, at most closeBudgetSec
  DataService.KICK                   the kick messages

Session lock: a profile holds lock = { jobId, at } while a server has it. A load waits out another server's
fresh lock (retrying after each of Config.Save.loadRetrySec, then kicking); a lock older than lockStaleSec is
taken over. Every save refreshes lock.at (the heartbeat) and aborts if another server holds the lock, which kicks
the player and stops every write for them. The final save on leave writes lock = nil.
]]
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Promise = require(ReplicatedStorage.Shared.Promise)
local Signal = require(ReplicatedStorage.Shared.Signal)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)

local Save = script.Parent.Parent.Save
local GiftQueue = require(Save.GiftQueue)
local ItemModel = require(script.Parent.Parent.Items.ItemModel)
local Migrations = require(Save.Migrations)
local SaveQueue = require(Save.SaveQueue)
local Stores = require(Save.Stores)

local DataService = {
	Loaded = Signal.new(),
	Leaving = Signal.new(),
}

DataService.KICK = {
	lockHeld = "Your farm is safe! It's still open on another server. Rejoin in a minute.",
	tooNew = "New update ready! Rejoin to get it. Your farm is saved.",
	lockLost = "Your farm was opened on another server. Your progress is saved.",
	loadFailed = "We couldn't reach your farm. It's safe! Rejoin in a minute.",
}

DataService.TEMPLATE = TableUtil.deepFreeze({
	v = Config.Save.schemaVersion,
	coins = Config.Start.coins,
	lifetimeCoins = 0,
	seeds = TableUtil.deepCopy(Config.Start.seeds),
	plotLevel = 1,
	can = "tin",
	sprinklers = { basic = 0, advanced = 0, placed = {} },
	tiles = {},
	basket = {},
	autoSell = false,
	gnomeOn = true,
	items = {},
	pedestals = {},
	collection = { found = {}, claimed = {}, milestones = {} },
	restock = { slot = 0, bought = {} },
	passes = {},
	cosmetics = { owned = {}, equipped = {} },
	daily = { day = 1, lastClaimDay = 0, streak = 0, cycle = 1 },
	quests = { starter = {}, daily = { day = 0, progress = {}, claimed = {} } },
	playtime = { day = 0, sec = 0, claimed = {} },
	social = { day = 0, helps = 0, itemGifts = 0, liked = {}, likesReceived = 0 },
	weekly = { claimed = {} },
	blockParty = { window = 0, waters = 0, rewarded = false, rewardsTotal = 0 },
	badges = {},
	patchTips = { plant = false, shopHello = false, shower = false, mutation = false, blockParty = false },
	settings = { patchAlerts = true, music = true, sfx = true, reducedFx = false },
	firstSession = {
		done = false,
		playedSec = 0,
		showerDone = false,
		wetGuaranteed = false,
		calendarShown = false,
		extraRowEligible = false,
	},
	receipts = {},
	giftsIn = {},
	outbox = {},
	meta = { created = 0, lastSeen = 0, sessionStart = 0, growCredits = 0 },
})

-- maps whose template holds starting entries: filled only when missing, never merged (spent seeds stay spent)
DataService.RECONCILE_SKIP = { seeds = true }

local sessions = {} -- [player] = { profile, key, loadedAt, nextSave, lockLost, releasing, released, leftFired }
local loading = {} -- [player] = true while loading
local closing = false

-- Studio servers all have JobId "": give each its own so two of them still lock each other out
local jobId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

function DataService.jobId()
	return jobId
end

function DataService.newProfile(now)
	local p = TableUtil.deepCopy(DataService.TEMPLATE)
	p.meta.created = now
	return p
end

-- runs Migrations until p.v reaches the schema version; nil + reason when a step is missing
function DataService.migrate(p)
	p.v = p.v or 0
	while p.v < Config.Save.schemaVersion do
		local from = p.v
		local step = Migrations[from]
		if not step then
			return nil, `no migration from v{from}`
		end
		p = step(p)
		p.v = from + 1
	end
	return p
end

function DataService.get(player)
	local s = sessions[player]
	if s and not s.lockLost then
		return s.profile
	end
	return nil
end

function DataService.check(player)
	if DataService.get(player) then
		return true
	end
	return false, "not_loaded"
end

function DataService.save(player, reason)
	local s = sessions[player]
	if not s or s.lockLost then
		return Promise.resolved(false)
	end
	return SaveQueue.request(s.key, reason)
end

-- the UpdateAsync body of a load; status says why it aborted
local function loadTransform(old, status)
	local now = Clock.now()
	if old and old.lock and old.lock.jobId ~= jobId and now - (old.lock.at or 0) < Config.Save.lockStaleSec then
		status.why = "locked"
		return nil
	end
	local p = old or DataService.newProfile(now)
	if (p.v or 0) > Config.Save.schemaVersion then
		status.why = "tooNew"
		return nil
	end
	local migrated, err = DataService.migrate(p)
	if not migrated then
		status.why, status.err = "error", err
		return nil
	end
	TableUtil.reconcile(migrated, DataService.TEMPLATE, DataService.RECONCILE_SKIP)
	migrated.lock = { jobId = jobId, at = now }
	migrated.meta.lastSeen = now
	migrated.meta.sessionStart = now
	return migrated
end

-- one load attempt: profile, or nil + "locked" | "tooNew" | "error"
local function tryLoad(key)
	local store = Stores.profiles()
	if not store then
		return loadTransform(nil, {}) -- memory-only: always a new farm
	end
	local status = {}
	local ok, result = pcall(function()
		return store:UpdateAsync(key, function(old)
			table.clear(status)
			return loadTransform(old, status)
		end)
	end)
	if not ok then
		return nil, "error", result
	end
	if result == nil then
		return nil, status.why or "error", status.err
	end
	return result
end

local function saveTransform(s, old, copy)
	if old and (old.lock == nil or old.lock.jobId ~= jobId) then
		return nil -- another server has (or had) this farm: abort
	end
	local now = Clock.now()
	copy.meta.lastSeen = now
	copy.lock = if s.releasing then nil else { jobId = jobId, at = now }
	return copy
end

-- the final save (lock = nil), once per session; the promise resolves when it is done
local function release(player, s, reason)
	if s.released then
		return s.released
	end
	s.releasing = true
	local done = Promise.new()
	s.released = done
	SaveQueue.request(s.key, reason):andThen(function(ok)
		SaveQueue.untrack(s.key)
		ItemModel.unregister(s.profile, player.UserId)
		if sessions[player] == s then
			sessions[player] = nil
		end
		done:resolve(ok)
	end)
	return done
end

local function fireLeaving(player, s)
	if not s.leftFired and not s.lockLost then
		s.leftFired = true
		DataService.Leaving:Fire(player, s.profile)
	end
end

local function onLockLost(player, s)
	s.lockLost = true
	warn(`[DataService] lost the lock on {s.key}: no more writes for {player.UserId}`)
	if not s.releasing then
		player:Kick(DataService.KICK.lockLost)
	end
end

local function load(player)
	loading[player] = true
	local key = Stores.key(player.UserId)
	local delays = Config.Save.loadRetrySec
	local profile, why, err
	for attempt = 0, #delays do
		if attempt > 0 then
			task.wait(delays[attempt])
		end
		if player.Parent ~= Players then
			loading[player] = nil
			return
		end
		profile, why, err = tryLoad(key)
		if profile or why == "tooNew" then
			break
		end
		warn(`[DataService] load {key} attempt {attempt + 1}: {why} {err or ""}`)
	end
	loading[player] = nil
	if not profile then
		if why == "tooNew" then
			player:Kick(DataService.KICK.tooNew)
		elseif why == "locked" then
			player:Kick(DataService.KICK.lockHeld)
		else
			player:Kick(DataService.KICK.loadFailed)
		end
		return
	end

	for _, d in ItemModel.validate(profile, player.UserId) do
		warn(`[DataService] {key}: dropped item {d.guid} ({d.reason})`)
	end
	ItemModel.register(profile, player.UserId)

	local now = Clock.now()
	local every = Config.Save.autosaveSec
	local s = {
		profile = profile,
		key = key,
		loadedAt = now,
		nextSave = now + every + player.UserId % every,
		lockLost = false,
		releasing = false,
	}
	sessions[player] = s
	local store = Stores.profiles()
	SaveQueue.track(key, {
		store = store,
		lastWriteAt = store and now or nil, -- the load was a write
		snapshot = function()
			return s.profile
		end,
		transform = function(old, copy)
			return saveTransform(s, old, copy)
		end,
		onLockLost = function()
			onLockLost(player, s)
		end,
		budget = store and Stores.budget or nil,
	})

	if player.Parent ~= Players or closing then
		release(player, s, "left_while_loading") -- gone before the load finished: give the lock back
		return
	end
	DataService.Loaded:Fire(player, profile)
	task.spawn(GiftQueue.drain, player, profile)
end

local function onRemoving(player)
	local s = sessions[player]
	if not s then
		return
	end
	fireLeaving(player, s)
	release(player, s, "leave")
end

function DataService.close()
	closing = true
	local pending = {}
	for player, s in sessions do
		fireLeaving(player, s)
		table.insert(pending, release(player, s, "close"))
	end
	local deadline = Clock.now() + Config.Save.closeBudgetSec
	while true do
		local all = true
		for _, p in pending do
			if not p.done then
				all = false
				break
			end
		end
		if all then
			return true
		end
		if Clock.now() >= deadline then
			warn("[DataService] close: gave up on the remaining saves")
			return false
		end
		task.wait(0.1)
	end
end

local function autosaveLoop()
	while not closing do
		task.wait(1)
		local now = Clock.now()
		for _, s in sessions do
			if not s.lockLost and not s.releasing and now >= s.nextSave then
				s.nextSave += Config.Save.autosaveSec
				SaveQueue.request(s.key, "autosave")
			end
		end
	end
end

function DataService:Init()
	Stores.init()
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(load, player)
	end)
	Players.PlayerRemoving:Connect(onRemoving)
	for _, player in Players:GetPlayers() do
		if not sessions[player] and not loading[player] then
			task.spawn(load, player)
		end
	end
	game:BindToClose(DataService.close)
	task.spawn(autosaveLoop)
end

return DataService
