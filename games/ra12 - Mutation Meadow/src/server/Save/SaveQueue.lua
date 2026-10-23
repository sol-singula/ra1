--[[
Coalesced, rate-limited profile writes, one queue per DataStore key.

  SaveQueue.track(key, cfg)       starts a queue for key. cfg:
      store                       the DataStore (nil = memory-only: every request resolves true, nothing is written)
      snapshot()                  the live profile; deep-copied at write time
      transform(old, copy)        the UpdateAsync body: returns the value to write, or nil to abort (a lost lock)
      onLockLost()                called once when transform aborts
      budget()                    the UpdateAsync budget left (optional)
      lastWriteAt                 when the key was last written (optional: the load's write counts too)
  SaveQueue.untrack(key)
  SaveQueue.request(key, reason)  -> Promise<boolean>: true once a write that started after this request lands

Per key: one write at a time; requests made while one is in flight (or waiting) share the next write. A write
never starts within Config.Save.writeCooldownSec of the last one, waits while the budget is empty, and on an error
retries after each of Config.Save.writeBackoffSec before resolving false. A lost lock never retries: every
waiter resolves false and the queue stops for good.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Promise = require(ReplicatedStorage.Shared.Promise)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)

local SaveQueue = {}

local queues = {} -- [key] = { cfg, inFlight, scheduled, dirty, lastWriteAt, waiters, stopped, attempts, lastReason }

local function resolveAll(list, value)
	for _, p in list do
		p:resolve(value)
	end
end

local function waitForBudget(q)
	while q.cfg.budget and q.cfg.budget() <= 0 do
		task.wait(1)
	end
end

-- one UpdateAsync: "ok", "lost" or "error"
local function attempt(q, key)
	local copy = TableUtil.deepCopy(q.cfg.snapshot())
	local lost = false
	q.attempts += 1
	local ok, err = pcall(function()
		q.cfg.store:UpdateAsync(key, function(old)
			local new = q.cfg.transform(old, copy)
			lost = new == nil
			return new
		end)
	end)
	if not ok then
		warn(`[SaveQueue] {key} write failed ({q.lastReason}): {err}`)
		return "error"
	end
	return lost and "lost" or "ok"
end

local schedule

local function run(q, key)
	local wait = q.lastWriteAt + Config.Save.writeCooldownSec - Clock.now()
	if wait > 0 then
		task.wait(wait)
	end
	waitForBudget(q)
	if q.stopped then
		return
	end
	local batch = q.waiters
	q.waiters = {}
	q.dirty = false
	q.scheduled = false
	q.inFlight = true

	local result = attempt(q, key)
	for _, backoff in Config.Save.writeBackoffSec do
		if result ~= "error" or q.stopped then
			break
		end
		task.wait(backoff)
		waitForBudget(q)
		result = attempt(q, key)
	end
	q.inFlight = false

	if result == "lost" then
		q.stopped = true
		resolveAll(batch, false)
		resolveAll(q.waiters, false)
		q.waiters = {}
		if q.cfg.onLockLost then
			task.spawn(q.cfg.onLockLost)
		end
		return
	end
	if result == "ok" then
		q.lastWriteAt = Clock.now()
	end
	resolveAll(batch, result == "ok")
	if #q.waiters > 0 and queues[key] == q and not q.stopped then
		schedule(q, key)
	end
end

function schedule(q, key)
	q.scheduled = true
	task.spawn(run, q, key)
end

function SaveQueue.track(key, cfg)
	queues[key] = {
		cfg = cfg,
		inFlight = false,
		scheduled = false,
		dirty = false,
		lastWriteAt = cfg.lastWriteAt or -math.huge,
		waiters = {},
		stopped = false,
		attempts = 0,
	}
end

function SaveQueue.untrack(key)
	local q = queues[key]
	queues[key] = nil
	if q then
		q.stopped = true
		resolveAll(q.waiters, false)
		q.waiters = {}
	end
end

function SaveQueue.request(key, reason)
	local q = queues[key]
	local p = Promise.new()
	if not q or q.stopped then
		p:resolve(false)
		return p
	end
	if not q.cfg.store then
		p:resolve(true) -- memory-only
		return p
	end
	q.lastReason = reason
	table.insert(q.waiters, p)
	if q.inFlight then
		q.dirty = true
	elseif not q.scheduled then
		schedule(q, key)
	end
	return p
end

-- the queue's state, for tests and debugging
function SaveQueue.state(key)
	return queues[key]
end

return SaveQueue
