--[[
Every remote, validated and rate-limited (§2 NetService, §5).

The server makes ReplicatedStorage.Remotes: a RemoteEvent per NetSchema.CLIENT_EVENTS (client → server) and
NetSchema.SERVER_EVENTS (server → client), and the Snapshot RemoteFunction. The server never calls InvokeClient.

A client call is (action, payload). It runs only if, in order:
  1. the player's token bucket for that remote has a token (Config.Net.bucket; Plot uses plotBucket)  else "rate"
  2. the action is registered                                                                        "unknown_action"
  3. the payload passes NetSchema's global rules and the action's schema                             "schema"
  4. the player's profile is loaded                                                                  "not_loaded"
  5. for DevCommand, Guards.dev(player)                                                              "dev_gate"
A failed check drops the call silently (no Result). A handler returns ok, code?; when the payload carried a reqId,
the client gets Result { reqId, ok, code }. A handler returning code "ownership" also counts as a drop.
More than Config.Net.abuseDrops drops in abuseWindowSec kicks the player (net_abuse).

  NetService.on(remote, action, schema?, handler)   handler(player, payload, profile) -> ok, code?; schema
                                                    defaults to NetSchema.ACTIONS[remote][action]
  NetService.fire(player, name, data) / fireAll(name, data)   a server → client event
  NetService.change(player, path, value)   queues a profile delta; sent as State { seq, changes } once per Heartbeat
  NetService.snapshotPart(name, fn)  adds fn(player) to what Snapshot returns
  NetService.onDrop(player, remote, action, reason)
  NetService.dropStats()             { byReason, byPlayer = { [userId] = { [reason] = n } }, abuseKicks }
  NetService.ABUSE_KICK              the kick message
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local NetSchema = require(ReplicatedStorage.Shared.NetSchema)
local TableUtil = require(ReplicatedStorage.Shared.TableUtil)

local DataService = require(script.Parent.DataService)
local Guards = require(script.Parent.Parent.Net.Guards)

local NetService = {}

NetService.ABUSE_KICK = "Connection issue. Your farm is saved, please rejoin."
NetService.REASONS = { "rate", "schema", "unknown_action", "not_loaded", "ownership", "dev_gate" }

-- profile fields that never go to the client
local PRIVATE = { lock = true, receipts = true, giftsIn = true }

local folder
local remotes = {} -- [name] = RemoteEvent | RemoteFunction
local handlers = {} -- [remote][action] = { schema, handler }
local buckets = setmetatable({}, { __mode = "k" }) -- [player][remote] = { tokens, at } (kept after leaving)
local dropTimes = setmetatable({}, { __mode = "k" }) -- [player] = { times in the abuse window }
local lastWarn = setmetatable({}, { __mode = "k" }) -- [player][reason] = time (kept after leaving: no warning floods)
local kicked = setmetatable({}, { __mode = "k" }) -- [player] = true once kicked for abuse (kept after they leave)
local seqs = {} -- [player] = last State seq sent
local pending = {} -- [player] = { { path, value } }
local snapshotParts = {} -- [name] = fn(player)
local stats = { byReason = {}, byPlayer = {}, abuseKicks = 0 }

local function stub()
	return false, "not_implemented"
end

function NetService.on(remote, action, schema, handler)
	schema = schema or (NetSchema.ACTIONS[remote] and NetSchema.ACTIONS[remote][action])
	assert(schema, `NetService.on: no schema for {remote}.{action}`)
	handlers[remote] = handlers[remote] or {}
	handlers[remote][action] = { schema = schema, handler = handler }
end

function NetService.fire(player, name, data)
	remotes[name]:FireClient(player, data)
end

function NetService.fireAll(name, data)
	remotes[name]:FireAllClients(data)
end

function NetService.change(player, path, value)
	pending[player] = pending[player] or {}
	table.insert(pending[player], { path = path, value = TableUtil.deepCopy(value) })
end

function NetService.snapshotPart(name, fn)
	snapshotParts[name] = fn
end

function NetService.dropStats()
	return TableUtil.deepCopy(stats)
end

-- the token bucket for one player and remote
local function take(player, remote)
	local cfg = remote == "Plot" and Config.Net.plotBucket or Config.Net.bucket
	local now = Clock.now()
	buckets[player] = buckets[player] or {}
	local b = buckets[player][remote]
	if not b then
		b = { tokens = cfg.burst, at = now }
		buckets[player][remote] = b
	end
	b.tokens = math.min(cfg.burst, b.tokens + (now - b.at) * cfg.perSec)
	b.at = now
	if b.tokens >= 1 then
		b.tokens -= 1
		return true
	end
	return false
end

function NetService.onDrop(player, remote, action, reason)
	local userId = player.UserId
	stats.byReason[reason] = (stats.byReason[reason] or 0) + 1
	stats.byPlayer[userId] = stats.byPlayer[userId] or {}
	stats.byPlayer[userId][reason] = (stats.byPlayer[userId][reason] or 0) + 1

	local now = Clock.now()
	lastWarn[player] = lastWarn[player] or {}
	local last = lastWarn[player][reason]
	if not last or now - last >= Config.Net.warnEverySec then
		lastWarn[player][reason] = now
		warn(`[Net] dropped {reason} from {userId}: {tostring(remote)}.{tostring(action)}`)
	end

	local times = dropTimes[player] or {}
	dropTimes[player] = times
	table.insert(times, now)
	while times[1] and now - times[1] > Config.Net.abuseWindowSec do
		table.remove(times, 1)
	end
	if #times > Config.Net.abuseDrops and not kicked[player] then
		kicked[player] = true
		stats.abuseKicks += 1
		warn(`[Net] net_abuse: kicking {userId} ({#times} drops in {Config.Net.abuseWindowSec}s)`)
		player:Kick(NetService.ABUSE_KICK)
	end
end

local function dispatch(player, remote, action, payload)
	if not take(player, remote) then
		return NetService.onDrop(player, remote, action, "rate")
	end
	local entry = handlers[remote] and type(action) == "string" and handlers[remote][action]
	if not entry then
		return NetService.onDrop(player, remote, action, "unknown_action")
	end
	local ok, body, reqId = NetSchema.validatePayload(entry.schema, payload)
	if not ok then
		return NetService.onDrop(player, remote, action, "schema")
	end
	local profile = DataService.get(player)
	if not profile then
		return NetService.onDrop(player, remote, action, "not_loaded")
	end
	if remote == "DevCommand" and not Guards.dev(player) then
		return NetService.onDrop(player, remote, action, "dev_gate")
	end
	local ran, result, code = pcall(entry.handler, player, body, profile)
	if not ran then
		warn(`[Net] {remote}.{action} failed for {player.UserId}: {result}`)
		result, code = false, "error"
	end
	if code == "ownership" then
		NetService.onDrop(player, remote, action, "ownership")
	end
	if reqId then
		NetService.fire(player, "Result", { reqId = reqId, ok = result == true, code = code })
	end
end

local function snapshot(player)
	if not take(player, "Snapshot") then
		NetService.onDrop(player, "Snapshot", "invoke", "rate")
		return nil
	end
	local profile = DataService.get(player)
	if not profile then
		NetService.onDrop(player, "Snapshot", "invoke", "not_loaded")
		return nil
	end
	local state = {}
	for k, value in profile do
		if not PRIVATE[k] then
			state[k] = TableUtil.deepCopy(value)
		end
	end
	local out = { seq = seqs[player] or 0, profile = state }
	for name, fn in snapshotParts do
		out[name] = fn(player)
	end
	return out
end

local function flush()
	for player, changes in pending do
		pending[player] = nil
		if player.Parent == Players then
			seqs[player] = (seqs[player] or 0) + 1
			NetService.fire(player, "State", { seq = seqs[player], changes = changes })
		end
	end
end

local function forget(player)
	seqs[player], pending[player] = nil, nil
end

function NetService:Init()
	local old = ReplicatedStorage:FindFirstChild("Remotes")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in NetSchema.CLIENT_EVENTS do
		remotes[name] = Instance.new("RemoteEvent")
	end
	for _, name in NetSchema.SERVER_EVENTS do
		remotes[name] = Instance.new("RemoteEvent")
	end
	for _, name in NetSchema.FUNCTIONS do
		remotes[name] = Instance.new("RemoteFunction")
	end
	for name, remote in remotes do
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage

	-- every action answers not_implemented until its milestone registers a real handler
	for remote, actions in NetSchema.ACTIONS do
		for action, schema in actions do
			NetService.on(remote, action, schema, stub)
		end
	end
end

function NetService:Start()
	for _, name in NetSchema.CLIENT_EVENTS do
		remotes[name].OnServerEvent:Connect(function(player, action, payload)
			dispatch(player, name, action, payload)
		end)
	end
	remotes.Snapshot.OnServerInvoke = snapshot
	RunService.Heartbeat:Connect(flush)
	Players.PlayerRemoving:Connect(forget)
end

return NetService
