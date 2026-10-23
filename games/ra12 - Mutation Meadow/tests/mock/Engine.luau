--[[
A small fake Roblox engine for running src/ under lune.

  local engine = Engine.new({ studio = false, seed = 1, now = 1_760_000_000 })
  engine.game, engine.workspace          the instance tree built from default.project.json
  engine:require(instance)               requires a ModuleScript (each engine has its own module cache)
  engine:stub(instance, value)           makes require(instance) return value (set before the first require)
  engine:module("Shared/Config")         the instance at a path under ReplicatedStorage / ServerScriptService /
                                         StarterPlayerScripts ("Shared", "Server", "Client" roots)
  engine:runScript(instance)             runs a Script or LocalScript
  engine:run(fn, ...)                    runs fn in a scheduled thread (so it may yield); returns ok, result
  engine:advance(dt)                     moves the virtual clock, running tasks as they come due
  engine:addPlayer(userId, name)         a fake player (fires Players.PlayerAdded)
  engine.output / engine.errors          everything printed / every error raised in a task
  engine.analytics / engine.prompts / engine.badgesAwarded    recorded service calls
  engine.kicks                           { userId, reason } for every player:Kick
  engine:fireServer(player, name, ...)   a client FireServer arriving at the server (Remotes[name])
  engine:invokeServer(player, name, ...) a client InvokeServer arriving at the server
  engine:clientEvents(name, userId)      what that client received on a remote (argument packs)
  engine.remoteLog                       every remote call, both directions
  engine.dataStores                      the DataStoreService fake, with test controls:
      _failNext(store, method, msg, n)   the next n matching calls error
      _hang(store)                       every call to that store yields forever
      _put(store, key, value)            a fixture write (no cooldown, no log)
      _raw(store, kind?)                 the stored data table (edit it to play another server)
      _calls(store, key?, method?)       how many calls were made (failed ones included)
      _writes(store, key?)               the writes that landed, in order ({ at, method, ... })

Options: studio, client, seed, now, jobId, echo, dataBudget, dataStoresOff (GetDataStore errors, like an
unpublished place), shareDataWith (another engine whose stored data this one sees: a second server), localPlayer
(a userId: Players.LocalPlayer for a client engine). Workspace.CurrentCamera.ViewportSize starts at 1920 x 1080.

Faked services: Players, RunService, HttpService (GenerateGUID, JSONEncode/Decode), MarketplaceService,
BadgeService, PolicyService, AnalyticsService, DataStoreService (6 s same-key write cooldown, injectable errors,
UpdateAsync semantics, OrderedDataStore, GetRequestBudgetForRequestType), plus a deterministic Random and a
virtual clock behind workspace:GetServerTimeNow(), os.time, os.clock, tick, task.wait and task.delay.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Engine = {}
Engine.__index = Engine

local WRITE_COOLDOWN = 6

---------------------------------------------------------------------------------------------------------------
-- a tiny signal for the fake services (independent of the game's Signal)

local function newSignal(engine)
	local listeners = {}
	local signal = {}
	function signal:Connect(fn)
		local c = { Connected = true }
		function c.Disconnect()
			c.Connected = false
			local i = table.find(listeners, c)
			if i then
				table.remove(listeners, i)
			end
		end
		c.fn = fn
		table.insert(listeners, c)
		return c
	end
	function signal:Once(fn)
		local c
		c = signal:Connect(function(...)
			c.Disconnect()
			fn(...)
		end)
		return c
	end
	function signal:Wait()
		local thread = coroutine.running()
		signal:Once(function(...)
			engine.task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end
	function signal:Fire(...)
		for _, c in table.clone(listeners) do
			if c.Connected then
				engine.task.spawn(c.fn, ...)
			end
		end
	end
	function signal:count()
		return #listeners
	end
	return signal
end

---------------------------------------------------------------------------------------------------------------
-- instances

local CLASS_IS = {
	ModuleScript = { "LuaSourceContainer", "Instance" },
	Script = { "BaseScript", "LuaSourceContainer", "Instance" },
	LocalScript = { "Script", "BaseScript", "LuaSourceContainer", "Instance" },
	Folder = { "Instance" },
	Player = { "Instance" },
}

local function newInstance(engine, className, name, extra)
	local props = { ClassName = className, Name = name or className, Parent = nil }
	local children = {}
	local attributes = {}
	local methods = {}
	local propSignals = {}
	local attrSignals = {}
	local inst = setmetatable({}, {
		__index = function(_, key)
			if methods[key] ~= nil then
				return methods[key]
			end
			if props[key] ~= nil then
				return props[key]
			end
			if extra and extra[key] ~= nil then
				return extra[key]
			end
			for _, child in children do
				if child.Name == key then
					return child
				end
			end
			error(`{key} is not a valid member of {props.ClassName} "{props.Name}"`, 2)
		end,
		__newindex = function(self, key, value)
			if key == "Parent" then
				local old = props.Parent
				if old then
					old:_removeChild(self)
				end
				props.Parent = value
				if value then
					value:_addChild(self)
				end
			elseif extra and extra[key] ~= nil and props[key] == nil then
				extra[key] = value
			else
				props[key] = value
			end
			if propSignals[key] then
				propSignals[key]:Fire()
			end
		end,
		__tostring = function()
			return props.Name
		end,
	})
	function methods._addChild(_, child)
		table.insert(children, child)
	end
	function methods._removeChild(_, child)
		local i = table.find(children, child)
		if i then
			table.remove(children, i)
		end
	end
	function methods.GetChildren()
		return table.clone(children)
	end
	function methods.GetDescendants()
		local out = {}
		local function walk(list)
			for _, c in list do
				table.insert(out, c)
				walk(c:GetChildren())
			end
		end
		walk(children)
		return out
	end
	function methods.FindFirstChild(_, childName)
		for _, child in children do
			if child.Name == childName then
				return child
			end
		end
		return nil
	end
	function methods.WaitForChild(self, childName)
		local child = self:FindFirstChild(childName)
		if not child then
			error(`WaitForChild: {childName} never appears under {props.Name} in the mock`, 2)
		end
		return child
	end
	function methods.FindFirstChildOfClass(_, cls)
		for _, child in children do
			if child.ClassName == cls then
				return child
			end
		end
		return nil
	end
	function methods.IsA(_, cls)
		if props.ClassName == cls then
			return true
		end
		local bases = CLASS_IS[props.ClassName]
		return bases ~= nil and table.find(bases, cls) ~= nil or cls == "Instance"
	end
	function methods.GetAttribute(_, key)
		return attributes[key]
	end
	function methods.SetAttribute(_, key, value)
		local old = attributes[key]
		attributes[key] = value
		if old ~= value and attrSignals[key] then
			attrSignals[key]:Fire()
		end
	end
	function methods.GetPropertyChangedSignal(_, key)
		propSignals[key] = propSignals[key] or newSignal(engine)
		return propSignals[key]
	end
	function methods.GetAttributeChangedSignal(_, key)
		attrSignals[key] = attrSignals[key] or newSignal(engine)
		return attrSignals[key]
	end
	function methods.IsDescendantOf(self, ancestor)
		local p = props.Parent
		while p do
			if p == ancestor then
				return true
			end
			p = p.Parent
		end
		local _ = self
		return false
	end
	function methods.FindFirstAncestorOfClass(_, cls)
		local p = props.Parent
		while p do
			if p.ClassName == cls then
				return p
			end
			p = p.Parent
		end
		return nil
	end
	function methods.ClearAllChildren()
		for _, c in table.clone(children) do
			c.Parent = nil
		end
	end
	function methods.GetAttributes()
		return table.clone(attributes)
	end
	function methods.Destroy(self)
		self.Parent = nil
	end
	function methods.GetFullName(self)
		local parent = props.Parent
		if parent and parent ~= engine.game then
			return parent:GetFullName() .. "." .. props.Name
		end
		return props.Name
	end
	return inst
end

---------------------------------------------------------------------------------------------------------------
-- deterministic Random (xorshift-free LCG, good enough for tests)

local function makeRandom(engine)
	local Random = {}
	Random.__index = Random
	function Random.new(seed)
		local s = seed or engine.seed
		engine.seed = (engine.seed * 1103515245 + 12345) % 2147483648
		return setmetatable({ _s = math.floor(s) % 2147483648 }, Random)
	end
	function Random:_step()
		self._s = (self._s * 1103515245 + 12345) % 2147483648
		return self._s / 2147483648
	end
	function Random:NextNumber(min, max)
		min = min or 0
		max = max or 1
		return min + (max - min) * self:_step()
	end
	function Random:NextInteger(min, max)
		return min + math.floor(self:_step() * (max - min + 1))
	end
	function Random:Clone()
		return setmetatable({ _s = self._s }, Random)
	end
	return Random
end

---------------------------------------------------------------------------------------------------------------
-- the virtual scheduler

local function makeTask(engine)
	local queue = {} -- { at, seq, thread, args }
	local seq = 0
	local cancelled = setmetatable({}, { __mode = "k" })

	local function resume(thread, ...)
		if cancelled[thread] or coroutine.status(thread) == "dead" then
			return
		end
		local ok, err = coroutine.resume(thread, ...)
		if not ok then
			local trace = debug.traceback(thread, tostring(err))
			table.insert(engine.errors, trace)
			if engine.echo then
				print("[task error] " .. trace)
			end
		end
	end

	local function schedule(at, thread, ...)
		seq += 1
		table.insert(queue, { at = at, seq = seq, thread = thread, args = table.pack(...) })
	end

	local task = {}
	function task.spawn(fnOrThread, ...)
		local thread = type(fnOrThread) == "thread" and fnOrThread or coroutine.create(fnOrThread)
		resume(thread, ...)
		return thread
	end
	function task.defer(fnOrThread, ...)
		local thread = type(fnOrThread) == "thread" and fnOrThread or coroutine.create(fnOrThread)
		schedule(engine.now, thread, ...)
		return thread
	end
	function task.delay(dt, fnOrThread, ...)
		local thread = type(fnOrThread) == "thread" and fnOrThread or coroutine.create(fnOrThread)
		schedule(engine.now + (dt or 0), thread, ...)
		return thread
	end
	function task.wait(dt)
		local thread = coroutine.running()
		local start = engine.now
		schedule(engine.now + math.max(dt or 0, 1 / 60), thread, "__wait", start)
		local tag, began = coroutine.yield()
		if tag == "__wait" then
			return engine.now - began
		end
		return engine.now - start
	end
	function task.cancel(thread)
		cancelled[thread] = true
	end

	-- run everything due at or before t, in time order
	function engine:_runUntil(t)
		while true do
			local best, bi = nil, nil
			for i, item in queue do
				if item.at <= t and (not best or item.at < best.at or (item.at == best.at and item.seq < best.seq)) then
					best, bi = item, i
				end
			end
			if not best then
				break
			end
			table.remove(queue, bi)
			if best.at > engine.now then
				engine.now = best.at
			end
			resume(best.thread, table.unpack(best.args, 1, best.args.n))
		end
		engine.now = math.max(engine.now, t)
	end

	function engine:pending()
		return #queue
	end

	return task
end

---------------------------------------------------------------------------------------------------------------
-- deep copy that only lets DataStore-legal values through

local function storable(value, path)
	local kind = type(value)
	if kind == "table" then
		local out = {}
		for k, v in value do
			if type(k) ~= "string" and type(k) ~= "number" then
				error(`DataStore: key of type {type(k)} at {path}`, 0)
			end
			out[k] = storable(v, path .. "." .. tostring(k))
		end
		return out
	elseif kind == "function" or kind == "userdata" or kind == "thread" then
		error(`DataStore: cannot store {kind} at {path}`, 0)
	end
	return value
end

local function makeDataStoreService(engine, shared)
	-- the stored data lives in `states`; an engine made with { shareDataWith = other } sees the same data (a second
	-- server, or the same farm after a crash) but keeps its own clock, budget and injected failures
	local states = shared or {} -- [kind .. "|" .. name .. "|" .. scope] = { data, writes, versions }
	local apis = {}
	local failures = {} -- { store, method, message, count }
	local hangs = {} -- [storeName] = true: every call yields forever
	local budget = {}

	local function call(storeName, key, method)
		table.insert(engine.dataCalls, { store = storeName, key = key, method = method, at = engine.now })
		if hangs[storeName] then
			coroutine.yield() -- never resumed: a hung request
		end
		for i, f in failures do
			if (f.store == nil or f.store == storeName) and (f.method == nil or f.method == method) then
				f.count -= 1
				if f.count <= 0 then
					table.remove(failures, i)
				end
				error(f.message, 0)
			end
		end
	end

	local function spend(kind)
		local name = kind.Name or tostring(kind)
		budget[name] = (budget[name] or engine.dataBudget) - 1
	end

	-- the same-key write limit: a write within WRITE_COOLDOWN of the last real write to that key is an error
	local function checkCooldown(state, storeName, key)
		local last = state.writes[key]
		if last and engine.now - last < WRITE_COOLDOWN then
			error(`DataStore: {storeName}/{key} write cooldown ({WRITE_COOLDOWN}s same-key limit)`, 0)
		end
	end

	local function wrote(state, storeName, key, method)
		state.writes[key] = engine.now
		state.versions[key] = (state.versions[key] or 0) + 1
		table.insert(engine.dataLog, { store = storeName, key = key, method = method, at = engine.now })
	end

	local function newStore(kind, name, scope)
		if engine.dataStoresOff then
			error("You must publish this place to the web to access DataStore.", 0)
		end
		local id = kind .. "|" .. name .. "|" .. (scope or "global")
		if apis[id] then
			return apis[id]
		end
		states[id] = states[id] or { data = {}, writes = {}, versions = {} }
		local state = states[id]
		local api = {}
		apis[id] = api
		local E = engine.Enum.DataStoreRequestType

		function api.GetAsync(_, key)
			call(name, key, "GetAsync")
			spend(E.GetAsync)
			local v = state.data[key]
			local info = v ~= nil and { Version = tostring(state.versions[key] or 0), UpdatedTime = engine.now } or nil
			return v ~= nil and storable(v, key) or nil, info
		end
		function api.SetAsync(_, key, value)
			call(name, key, "SetAsync")
			checkCooldown(state, name, key)
			spend(E.SetIncrementAsync)
			state.data[key] = storable(value, key)
			wrote(state, name, key, "SetAsync")
			return tostring(state.versions[key])
		end
		function api.UpdateAsync(_, key, transform)
			call(name, key, "UpdateAsync")
			checkCooldown(state, name, key)
			spend(E.UpdateAsync)
			local old = state.data[key]
			local info = old ~= nil and { Version = tostring(state.versions[key] or 0), UpdatedTime = engine.now }
				or nil
			local new = transform(old ~= nil and storable(old, key) or nil, info)
			if new == nil then
				return nil -- cancelled: nothing written, and it does not count as a write
			end
			state.data[key] = storable(new, key)
			wrote(state, name, key, "UpdateAsync")
			return storable(new, key), { Version = tostring(state.versions[key]), UpdatedTime = engine.now }
		end
		function api.IncrementAsync(_, key, delta)
			call(name, key, "IncrementAsync")
			checkCooldown(state, name, key)
			spend(E.SetIncrementAsync)
			state.data[key] = (state.data[key] or 0) + (delta or 1)
			wrote(state, name, key, "IncrementAsync")
			return state.data[key]
		end
		function api.RemoveAsync(_, key)
			call(name, key, "RemoveAsync")
			checkCooldown(state, name, key)
			spend(E.SetIncrementAsync)
			local old = state.data[key]
			state.data[key] = nil
			wrote(state, name, key, "RemoveAsync")
			return old
		end
		if kind == "ordered" then
			function api.GetSortedAsync(_, ascending, pageSize, minValue, maxValue)
				call(name, nil, "GetSortedAsync")
				spend(E.GetSortedAsync)
				local rows = {}
				for k, v in state.data do
					if (minValue == nil or v >= minValue) and (maxValue == nil or v <= maxValue) then
						table.insert(rows, { key = k, value = v })
					end
				end
				table.sort(rows, function(a, b)
					if a.value == b.value then
						return a.key < b.key
					end
					if ascending then
						return a.value < b.value
					end
					return a.value > b.value
				end)
				local size = math.clamp(pageSize or 50, 1, 100)
				local page = 1
				local pages = { IsFinished = #rows <= size }
				function pages.GetCurrentPage()
					local out = {}
					for i = (page - 1) * size + 1, math.min(#rows, page * size) do
						table.insert(out, rows[i])
					end
					return out
				end
				function pages.AdvanceToNextPageAsync()
					page += 1
					pages.IsFinished = #rows <= page * size
				end
				return pages
			end
		end
		api._state = state
		return api
	end

	local service = {}
	function service.GetDataStore(_, name, scope)
		return newStore("plain", name, scope)
	end
	function service.GetOrderedDataStore(_, name, scope)
		return newStore("ordered", name, scope)
	end
	function service.GetRequestBudgetForRequestType(_, kind)
		local key = kind.Name or tostring(kind)
		return math.max(0, budget[key] or engine.dataBudget)
	end
	-- test controls
	function service._failNext(storeName, method, message, count)
		table.insert(
			failures,
			{ store = storeName, method = method, message = message or "502: mock failure", count = count or 1 }
		)
	end
	function service._clearFailures()
		table.clear(failures)
	end
	function service._hang(storeName, on)
		hangs[storeName] = on ~= false or nil
	end
	function service._setBudget(kindName, n)
		budget[kindName] = n
	end
	function service._raw(storeName, kind)
		local entry = states[(kind or "plain") .. "|" .. storeName .. "|global"]
		return entry and entry.data or nil
	end
	-- a fixture write that skips the cooldown, the logs and the budget
	function service._put(storeName, key, value, kind)
		local id = (kind or "plain") .. "|" .. storeName .. "|global"
		states[id] = states[id] or { data = {}, writes = {}, versions = {} }
		states[id].data[key] = storable(value, key)
	end
	-- count the calls made to a store (optionally one key and one method)
	function service._calls(storeName, key, method)
		local n = 0
		for _, c in engine.dataCalls do
			if c.store == storeName and (key == nil or c.key == key) and (method == nil or c.method == method) then
				n += 1
			end
		end
		return n
	end
	-- the writes that landed on one key, in order
	function service._writes(storeName, key)
		local out = {}
		for _, w in engine.dataLog do
			if w.store == storeName and (key == nil or w.key == key) then
				table.insert(out, w)
			end
		end
		return out
	end
	service._states = states
	return service
end

---------------------------------------------------------------------------------------------------------------
-- Instance.new and remotes. Every remote call is logged in engine.remoteLog as
-- { remote, dir = "toClient" | "toServer" | "toAll", userId?, args }

local function makeInstanceLib(engine)
	local Instance = {}
	function Instance.new(className, parent)
		local extra
		if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
			extra = { OnServerEvent = newSignal(engine), OnClientEvent = newSignal(engine) }
		elseif className == "RemoteFunction" then
			extra = { OnServerInvoke = false, OnClientInvoke = false }
		elseif className == "TextButton" or className == "ImageButton" then
			extra = { Activated = newSignal(engine), MouseButton1Click = newSignal(engine) }
		elseif className == "ClickDetector" then
			extra = { MouseClick = newSignal(engine) }
		elseif className == "ProximityPrompt" then
			extra = { Triggered = newSignal(engine) }
		end
		local inst = newInstance(engine, className, className, extra)
		if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
			function inst.FireClient(self, player, ...)
				table.insert(
					engine.remoteLog,
					{ remote = self.Name, dir = "toClient", userId = player.UserId, args = table.pack(...) }
				)
			end
			function inst.FireAllClients(self, ...)
				table.insert(engine.remoteLog, { remote = self.Name, dir = "toAll", args = table.pack(...) })
			end
			function inst.FireServer(self, ...)
				table.insert(engine.remoteLog, { remote = self.Name, dir = "toServer", args = table.pack(...) })
			end
		elseif className == "RemoteFunction" then
			function inst.InvokeServer(self, ...)
				table.insert(engine.remoteLog, { remote = self.Name, dir = "toServer", args = table.pack(...) })
				return nil
			end
			function inst.InvokeClient()
				error("mock: the server must never call InvokeClient", 2)
			end
		end
		if parent then
			inst.Parent = parent
		end
		return inst
	end
	return Instance
end

-- a client call arriving at the server: Remotes[name].OnServerEvent fires with (player, ...)
function Engine:fireServer(player, name, ...)
	local remote = self.game.ReplicatedStorage.Remotes:FindFirstChild(name)
	assert(remote, `mock: no remote {name}`)
	remote.OnServerEvent:Fire(player, ...)
end

-- a client InvokeServer arriving at the server
function Engine:invokeServer(player, name, ...)
	local remote = self.game.ReplicatedStorage.Remotes:FindFirstChild(name)
	assert(remote and remote.OnServerInvoke, `mock: no RemoteFunction handler for {name}`)
	return remote.OnServerInvoke(player, ...)
end

-- what a player's client received on a remote: a list of argument packs
function Engine:clientEvents(name, userId)
	local out = {}
	for _, e in self.remoteLog do
		if e.remote == name and (e.dir == "toAll" or (e.dir == "toClient" and e.userId == userId)) then
			table.insert(out, e.args)
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------------------

local function makeEnum()
	local cache = {}
	return setmetatable({}, {
		__index = function(_, enumType)
			if not cache[enumType] then
				local items = {}
				cache[enumType] = setmetatable({}, {
					__index = function(_, itemName)
						if not items[itemName] then
							items[itemName] = setmetatable({ Name = itemName, EnumType = enumType }, {
								__tostring = function()
									return `Enum.{enumType}.{itemName}`
								end,
							})
						end
						return items[itemName]
					end,
				})
			end
			return cache[enumType]
		end,
	})
end

local function makeServices(engine)
	local game = engine.game
	local function service(name, extra)
		local s = newInstance(engine, name, name, extra)
		s.Parent = game
		return s
	end

	-- Players
	local players = service("Players", {
		MaxPlayers = 0,
		LocalPlayer = false,
		PlayerAdded = newSignal(engine),
		PlayerRemoving = newSignal(engine),
	})
	rawset(engine, "_players", {})
	function engine:addPlayer(userId, name)
		local p = newInstance(engine, "Player", name or ("Player" .. userId), {
			UserId = userId,
			DisplayName = name or ("Player" .. userId),
			AccountAge = 30,
			Character = false,
			MembershipType = engine.Enum.MembershipType.None,
		})
		local gui = newInstance(engine, "PlayerGui", "PlayerGui")
		gui.Parent = p
		function p.Kick(_, reason)
			table.insert(engine.kicks, { userId = userId, reason = reason })
			engine:removePlayer(p)
		end
		function p.IsFriendsWith(_, otherId)
			return engine.friends[userId .. ":" .. otherId] == true or engine.friends[otherId .. ":" .. userId] == true
		end
		p.Parent = players
		players.PlayerAdded:Fire(p)
		return p
	end
	function engine:removePlayer(p)
		if p.Parent == players then
			players.PlayerRemoving:Fire(p)
			p.Parent = nil
		end
	end
	function players.GetPlayers(self)
		return self:GetChildren()
	end
	function players.GetPlayerByUserId(self, id)
		for _, p in self:GetChildren() do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end

	-- RunService
	local run = service("RunService", {
		Heartbeat = newSignal(engine),
		Stepped = newSignal(engine),
		RenderStepped = newSignal(engine),
	})
	function run.IsStudio()
		return engine.studio
	end
	function run.IsServer()
		return not engine.client
	end
	function run.IsClient()
		return engine.client
	end
	function run.IsRunning()
		return true
	end
	function run.BindToRenderStep() end
	function run.UnbindFromRenderStep() end

	-- HttpService
	local http = service("HttpService")
	local guid = 0
	function http.GenerateGUID(_, wrap)
		guid += 1
		local hex = string.format("%032x", guid)
		local s = (`{hex:sub(1, 8)}-{hex:sub(9, 12)}-{hex:sub(13, 16)}-{hex:sub(17, 20)}-{hex:sub(21, 32)}`):upper()
		return wrap == false and s or "{" .. s .. "}"
	end
	function http.JSONEncode(_, value)
		return serde.encode("json", value)
	end
	function http.JSONDecode(_, text)
		return serde.decode("json", text)
	end

	-- MarketplaceService
	local market = service("MarketplaceService", {
		ProcessReceipt = false,
		PromptGamePassPurchaseFinished = newSignal(engine),
		PromptProductPurchaseFinished = newSignal(engine),
		PromptPurchaseFinished = newSignal(engine),
	})
	function market.UserOwnsGamePassAsync(_, userId, passId)
		return engine.passes[userId .. ":" .. passId] == true
	end
	function market.PromptGamePassPurchase(_, player, passId)
		table.insert(engine.prompts, { kind = "pass", userId = player.UserId, id = passId })
	end
	function market.PromptProductPurchase(_, player, productId)
		table.insert(engine.prompts, { kind = "product", userId = player.UserId, id = productId })
	end
	function market.PromptPremiumPurchase(_, player)
		table.insert(engine.prompts, { kind = "premium", userId = player.UserId })
	end
	function market.GetProductInfo(_, id, infoType)
		return { ProductId = id, PriceInRobux = 0, Name = "Mock " .. tostring(id), InfoType = infoType }
	end
	-- a test drives a purchase through ProcessReceipt; returns the decision
	function engine:buyProduct(player, productId)
		local handler = market.ProcessReceipt
		assert(handler, "no ProcessReceipt set")
		guid += 1
		return handler({
			PlayerId = player.UserId,
			ProductId = productId,
			PurchaseId = "P" .. guid,
			CurrencySpent = 0,
			PlaceIdWherePurchased = 0,
		})
	end

	-- BadgeService
	local badges = service("BadgeService")
	function badges.AwardBadge(_, userId, badgeId)
		table.insert(engine.badgesAwarded, { userId = userId, id = badgeId })
		engine.badgesOwned[userId .. ":" .. badgeId] = true
		return true
	end
	function badges.UserHasBadgeAsync(_, userId, badgeId)
		return engine.badgesOwned[userId .. ":" .. badgeId] == true
	end
	function badges.GetBadgeInfoAsync(_, badgeId)
		return { Name = "Badge " .. badgeId, IsEnabled = true }
	end

	-- PolicyService
	local policy = service("PolicyService")
	function policy.GetPolicyInfoForPlayerAsync(_, player)
		return engine.policies[player.UserId]
			or {
				ArePaidRandomItemsRestricted = false,
				IsPaidItemTradingAllowed = true,
				IsSubjectToChinaPolicies = false,
				AllowedExternalLinkReferences = {},
			}
	end

	-- AnalyticsService: every call is recorded as { method, args }
	local analytics = service("AnalyticsService")
	for _, m in
		{
			"LogEconomyEvent",
			"LogCustomEvent",
			"LogFunnelStepEvent",
			"LogOnboardingFunnelStepEvent",
			"LogProgressionEvent",
			"LogProgressionStartEvent",
			"LogProgressionCompleteEvent",
			"LogProgressionFailEvent",
		}
	do
		analytics[m] = function(_, ...)
			table.insert(engine.analytics, { method = m, args = table.pack(...) })
		end
	end

	-- DataStoreService
	local ds = service("DataStoreService")
	local api = makeDataStoreService(engine, engine.sharedData)
	for k, v in api do
		ds[k] = v
	end
	engine.dataStores = api

	-- containers the project fills
	service("ReplicatedStorage")
	service("ServerScriptService")
	service("ServerStorage")
	service("StarterGui")
	service("Lighting")
	service("SoundService")
	local starterPlayer = service("StarterPlayer")
	newInstance(engine, "StarterPlayerScripts", "StarterPlayerScripts").Parent = starterPlayer
	newInstance(engine, "StarterCharacterScripts", "StarterCharacterScripts").Parent = starterPlayer

	service("ProximityPromptService", { PromptTriggered = newSignal(engine) })
	service("UserInputService", { TouchEnabled = false, KeyboardEnabled = true, GamepadEnabled = false })
	service("TweenService")
	service("GuiService")

	local workspace = service("Workspace", { StreamingEnabled = true, Gravity = 196.2 })
	local camera = newInstance(engine, "Camera", "Camera", { ViewportSize = roblox.Vector2.new(1920, 1080) })
	camera.Parent = workspace
	workspace.CurrentCamera = camera
	function workspace.GetServerTimeNow()
		return engine.now
	end
	engine.workspace = workspace

	function game.GetService(self, name)
		local s = self:FindFirstChild(name)
		if not s then
			error(`mock: service {name} is not faked`, 2)
		end
		return s
	end
	function game.BindToClose(_, fn)
		table.insert(engine.closeHandlers, fn)
	end
end

---------------------------------------------------------------------------------------------------------------
-- building the tree from default.project.json

local function scriptClass(fileName)
	if fileName:match("%.server%.luau?$") then
		return "Script", fileName:gsub("%.server%.luau?$", "")
	elseif fileName:match("%.client%.luau?$") then
		return "LocalScript", fileName:gsub("%.client%.luau?$", "")
	elseif fileName:match("%.luau?$") then
		return "ModuleScript", fileName:gsub("%.luau?$", "")
	end
	return nil
end

local function mapPath(engine, path, name)
	if fs.isFile(path) then
		local cls, base = scriptClass(path:match("[^/]+$"))
		local inst = newInstance(engine, cls, name or base)
		engine.sources[inst] = { path = path, text = fs.readFile(path) }
		return inst
	end
	local inst
	for _, initName in
		{ "init.lua", "init.luau", "init.server.lua", "init.server.luau", "init.client.lua", "init.client.luau" }
	do
		if fs.isFile(path .. "/" .. initName) then
			local cls = scriptClass(initName)
			inst = newInstance(engine, cls, name)
			engine.sources[inst] = { path = path .. "/" .. initName, text = fs.readFile(path .. "/" .. initName) }
			break
		end
	end
	inst = inst or newInstance(engine, "Folder", name)
	local entries = fs.readDir(path)
	table.sort(entries)
	for _, entry in entries do
		if entry:sub(1, 1) ~= "." and not entry:match("^init%.") then
			local full = path .. "/" .. entry
			if fs.isDir(full) then
				mapPath(engine, full, entry).Parent = inst
			elseif scriptClass(entry) then
				mapPath(engine, full).Parent = inst
			end
		end
	end
	return inst
end

local function applyNode(engine, inst, node)
	for key, value in node do
		if key == "$properties" then
			for prop, v in value do
				inst[prop] = v
			end
		elseif key:sub(1, 1) ~= "$" then
			local child = inst:FindFirstChild(key)
			if not child then
				if value["$path"] then
					child = mapPath(engine, engine.root .. "/" .. value["$path"], key)
				else
					child = newInstance(engine, value["$className"] or "Folder", key)
				end
				child.Parent = inst
			end
			applyNode(engine, child, value)
		end
	end
end

---------------------------------------------------------------------------------------------------------------

local BUILTINS = {
	"assert",
	"bit32",
	"buffer",
	"coroutine",
	"debug",
	"error",
	"gcinfo",
	"getmetatable",
	"ipairs",
	"math",
	"newproxy",
	"next",
	"pairs",
	"pcall",
	"rawequal",
	"rawget",
	"rawlen",
	"rawset",
	"select",
	"setmetatable",
	"string",
	"table",
	"tonumber",
	"tostring",
	"type",
	"unpack",
	"utf8",
	"vector",
	"xpcall",
}

function Engine.new(opts)
	opts = opts or {}
	local engine = setmetatable({
		root = opts.root or ".",
		studio = opts.studio == true,
		client = opts.client == true,
		seed = opts.seed or 1,
		now = opts.now or 1_760_000_000,
		echo = opts.echo == true,
		dataBudget = opts.dataBudget or 100,
		sources = setmetatable({}, { __mode = "k" }),
		cache = {},
		loading = {},
		output = {},
		errors = {},
		analytics = {},
		prompts = {},
		badgesAwarded = {},
		badgesOwned = {},
		passes = {},
		policies = {},
		friends = {},
		kicks = {},
		dataLog = {},
		dataCalls = {},
		remoteLog = {},
		dataStoresOff = opts.dataStoresOff == true,
		sharedData = opts.shareDataWith and opts.shareDataWith.dataStores._states or nil,
		closeHandlers = {},
	}, Engine)
	engine.Enum = makeEnum()
	engine.task = makeTask(engine)
	engine.Random = makeRandom(engine)
	engine.Instance = makeInstanceLib(engine)
	engine.game = newInstance(engine, "DataModel", "Game")
	engine.game.JobId = opts.jobId or "job-1"
	engine.game.PlaceId = opts.placeId or 0
	makeServices(engine)

	if opts.localPlayer then
		local p = engine:addPlayer(opts.localPlayer)
		engine.game.Players.LocalPlayer = p
	end

	local project = serde.decode("json", fs.readFile(engine.root .. "/default.project.json"))
	applyNode(engine, engine.game, project.tree)

	local os_ = table.clone(os)
	os_.time = function(t)
		if t then
			return os.time(t)
		end
		return math.floor(engine.now)
	end
	os_.clock = function()
		return engine.now
	end
	engine.os = os_
	return engine
end

function Engine:env(scriptInstance)
	local env = {}
	for _, name in BUILTINS do
		env[name] = (getfenv() :: any)[name]
	end
	env.script = scriptInstance
	env.game = self.game
	env.workspace = self.workspace
	env.task = self.task
	env.Enum = self.Enum
	env.Random = self.Random
	env.Instance = self.Instance
	env.Vector3 = roblox.Vector3
	env.CFrame = roblox.CFrame
	env.Color3 = roblox.Color3
	env.Vector2 = roblox.Vector2
	env.UDim = roblox.UDim
	env.UDim2 = roblox.UDim2
	env.os = self.os
	env.tick = function()
		return self.now
	end
	env.time = function()
		return self.now
	end
	env.typeof = function(v)
		if type(v) == "table" and getmetatable(v) and rawget(v, "ClassName") == nil then
			local ok, cls = pcall(function()
				return v.ClassName
			end)
			if ok and cls then
				return "Instance"
			end
		end
		return typeof(v)
	end
	env.print = function(...)
		local parts = table.pack(...)
		for i = 1, parts.n do
			parts[i] = tostring(parts[i])
		end
		local line = table.concat(parts, " ", 1, parts.n)
		table.insert(self.output, line)
		if self.echo then
			print(line)
		end
	end
	env.warn = function(...)
		env.print("[warn]", ...)
	end
	env.require = function(target)
		return self:require(target)
	end
	return env
end

function Engine:load(inst)
	-- sources are read up front: lune's fs calls yield, which would break the virtual scheduler's threads
	local source = self.sources[inst]
	assert(source, `mock: {inst} has no source file`)
	local fn = luau.load(source.text, {
		debugName = source.path,
		environment = self:env(inst),
		injectGlobals = false,
	})
	return fn
end

function Engine:require(inst)
	assert(type(inst) == "table", "mock require expects a ModuleScript instance")
	if self.cache[inst] ~= nil then
		return self.cache[inst].value
	end
	assert(inst.ClassName == "ModuleScript", `mock: require of a {inst.ClassName}`)
	if self.loading[inst] then
		error(`mock: cyclic require of {inst:GetFullName()}`, 2)
	end
	self.loading[inst] = true
	local value = self:load(inst)()
	self.loading[inst] = nil
	self.cache[inst] = { value = value }
	return value
end

function Engine:stub(inst, value)
	self.cache[inst] = { value = value }
end

local ROOTS = {
	Shared = { "ReplicatedStorage", "Shared" },
	Server = { "ServerScriptService", "Server" },
	Client = { "StarterPlayer", "StarterPlayerScripts", "Client" },
}

function Engine:module(path)
	local parts = path:split("/")
	local root = ROOTS[parts[1]]
	assert(root, `mock: unknown root {parts[1]}`)
	local inst = self.game
	for _, name in root do
		inst = inst:FindFirstChild(name) or error(`mock: no {name} on the way to {path}`)
	end
	for i = 2, #parts do
		inst = inst:FindFirstChild(parts[i]) or error(`mock: no {parts[i]} on the way to {path}`)
	end
	return inst
end

function Engine:run(fn, ...)
	local result = table.pack(false, "did not finish")
	local thread = coroutine.create(function(...)
		result = table.pack(pcall(fn, ...))
	end)
	self.task.spawn(thread, ...)
	return table.unpack(result, 1, result.n)
end

function Engine:runScript(inst)
	assert(inst.ClassName == "Script" or inst.ClassName == "LocalScript", "mock: runScript expects a Script")
	local fn = self:load(inst)
	return self:run(fn)
end

function Engine:advance(dt, step)
	local target = self.now + dt
	step = step or math.max(0.1, dt / 500) -- long jumps take bigger Heartbeat steps; timers still fire on time
	local heartbeat = self.game.RunService.Heartbeat
	while self.now < target do
		local nextT = math.min(target, self.now + step)
		local before = self.now
		self:_runUntil(nextT)
		if heartbeat:count() > 0 then
			heartbeat:Fire(self.now - before)
		end
	end
	self:_runUntil(target)
end

return Engine
