--[[
The client side of the remotes (the server half is NetService). Client only.

  Net.send(remote, action, payload?)            fire and forget
  Net.request(remote, action, payload?)         -> Promise<{ ok, code? }>: adds a reqId and resolves on the
                                                server's Result, or { ok = false, code = "timeout" } after
                                                Config.Net.resultTimeoutSec; a payload that fails NetSchema here
                                                resolves { ok = false, code = "schema" } without sending
  Net.on(name, fn)                              a server → client event (State, Restock, Toast, ...)
  Net.snapshot()                                the full public state ({ seq, profile, ... }), via Snapshot
  Net.onState(fn)                               fn(changes) for each State in order; on a seq gap it fetches a
                                                Snapshot and calls fn(nil, snapshot) instead
  Net.Sent(remote, action, payload)             fires for every call the client sends (Patch hides lines on it)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local NetSchema = require(script.Parent.NetSchema)
local Promise = require(script.Parent.Promise)
local Signal = require(script.Parent.Signal)

local Net = {
	Sent = Signal.new(),
}

local MAX_REQ = 2 ^ 31

local folder
local nextReq = 0
local waiting = {} -- [reqId] = Promise
local listening = false

local function remote(name)
	folder = folder or ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name)
end

local function listenResults()
	if listening then
		return
	end
	listening = true
	remote("Result").OnClientEvent:Connect(function(result)
		local p = type(result) == "table" and waiting[result.reqId]
		if p then
			waiting[result.reqId] = nil
			p:resolve({ ok = result.ok == true, code = result.code })
		end
	end)
end

function Net.send(name, action, payload)
	remote(name):FireServer(action, payload or {})
	Net.Sent:Fire(name, action, payload)
end

function Net.request(name, action, payload)
	payload = table.clone(payload or {})
	local p = Promise.new()
	local ok = NetSchema.validate(name, action, payload)
	if not ok then
		p:resolve({ ok = false, code = "schema" })
		return p
	end
	listenResults()
	nextReq = nextReq % MAX_REQ + 1
	local reqId = nextReq
	payload.reqId = reqId
	waiting[reqId] = p
	task.delay(Config.Net.resultTimeoutSec, function()
		if waiting[reqId] == p then
			waiting[reqId] = nil
			p:resolve({ ok = false, code = "timeout" })
		end
	end)
	remote(name):FireServer(action, payload)
	Net.Sent:Fire(name, action, payload)
	return p
end

function Net.on(name, fn)
	return remote(name).OnClientEvent:Connect(fn)
end

function Net.snapshot()
	return remote("Snapshot"):InvokeServer()
end

function Net.onState(fn)
	local lastSeq
	local function resync()
		local snap = Net.snapshot()
		if snap then
			lastSeq = snap.seq
			fn(nil, snap)
		end
	end
	local connection = Net.on("State", function(state)
		if lastSeq ~= nil and state.seq == lastSeq + 1 then
			lastSeq = state.seq
			fn(state.changes)
		elseif lastSeq == nil or state.seq > lastSeq + 1 then
			resync()
		end
	end)
	task.spawn(resync)
	return connection
end

return Net
