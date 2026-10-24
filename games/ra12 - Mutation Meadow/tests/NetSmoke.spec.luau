local Assert = require("./mock/Assert")
local Cases = require("./mock/NetCases")
local NetHelp = require("./mock/NetHelp")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local GAP = 0.21 -- between calls: under the rate limits and the abuse line (285 drops a minute)

test("Remotes holds exactly 29 objects with the right classes", function()
	local engine, _, NetSchema = NetHelp.setup()
	local folder = engine.game.ReplicatedStorage:FindFirstChild("Remotes")
	Assert.truthy(folder and folder.ClassName == "Folder", "Remotes folder")
	local children = folder:GetChildren()
	eq(#children, 29)
	local classes = {}
	for _, child in children do
		Assert.truthy(classes[child.Name] == nil, "duplicate name " .. child.Name)
		classes[child.Name] = child.ClassName
	end
	for _, name in NetSchema.CLIENT_EVENTS do
		eq(classes[name], "RemoteEvent", name)
	end
	for _, name in NetSchema.SERVER_EVENTS do
		eq(classes[name], "RemoteEvent", name)
	end
	eq(classes.Snapshot, "RemoteFunction")
	eq({ #NetSchema.CLIENT_EVENTS, #NetSchema.SERVER_EVENTS }, { 18, 10 })
	local actions = 0
	for _, list in NetSchema.ACTIONS do
		for _ in list do
			actions += 1
		end
	end
	eq(actions, 32, "every row of the payload table")
end)

test("every row: the valid cases run the handler with the payload; the invalid ones never do", function()
	local engine, _, NetSchema, player, calls = NetHelp.setup({ studio = true }) -- Studio: DevCommand is allowed
	for remote, actions in NetSchema.ACTIONS do
		for action in actions do
			local valid = Cases.valid[remote] and Cases.valid[remote][action]
			local invalid = Cases.invalid[remote] and Cases.invalid[remote][action]
			Assert.truthy(valid and #valid > 0, `{remote}.{action} has a valid case`)
			Assert.truthy(invalid and #invalid > 0, `{remote}.{action} has an invalid case`)
			for _, payload in valid do
				local before = #calls
				engine:fireServer(player, remote, action, Server.deepCopy(payload))
				engine:advance(GAP, GAP)
				eq(#calls, before + 1, `{remote}.{action} valid`)
				eq(calls[#calls].body, payload)
			end
			for i, payload in invalid do
				local before = #calls
				engine:fireServer(player, remote, action, payload)
				engine:advance(GAP, GAP)
				eq(#calls, before, `{remote}.{action} invalid case {i} ran`)
			end
		end
	end
	eq(engine.errors, {})
end)

test("a refused action answers Result { ok = false, code }; Snapshot and State", function()
	local engine = Server.boot()
	local NetService = engine:require(engine:module("Server/Services/NetService"))
	local player = Server.join(engine, 3)
	engine:fireServer(player, "Lounge", "enter", { reqId = 5 })
	eq(engine:clientEvents("Result", 3), { table.pack({ reqId = 5, ok = false, code = "not_vip" }) })
	engine:fireServer(player, "Shop", "close", {}) -- no reqId, no Result
	eq(#engine:clientEvents("Result", 3), 1)

	local snap = engine:invokeServer(player, "Snapshot")
	local base = snap.seq -- the join already sent a few deltas (Patch's first tip)
	eq(base, #engine:clientEvents("State", 3))
	eq(snap.profile.coins, 50)
	eq(
		{ snap.profile.lock, snap.profile.receipts, snap.profile.giftsIn },
		{ nil, nil, nil },
		"private fields stay home"
	)
	NetService.change(player, { "coins" }, 60)
	NetService.change(player, { "seeds", "carrot" }, 2)
	engine:advance(0.2)
	local states = engine:clientEvents("State", 3)
	eq(
		states[#states],
		table.pack({
			seq = base + 1,
			changes = { { path = { "coins" }, value = 60 }, { path = { "seeds", "carrot" }, value = 2 } },
		})
	)
	NetService.change(player, { "coins" }, 61)
	engine:advance(0.2)
	states = engine:clientEvents("State", 3)
	eq(states[#states][1].seq, base + 2)
	eq(engine:invokeServer(player, "Snapshot").seq, base + 2)
end)

local BAD = { 0 / 0, math.huge, -math.huge, string.rep("x", 2048), "\255bad", print }
-- fields an action may leave out (removing them is still valid)
local OPTIONAL = {
	["Plot.harvest.onFull"] = true,
	["Plot.water.ownerId"] = true,
	["Cosmetic.equip.key"] = true,
	["Purchase.prompt.tile"] = true,
	["Purchase.prompt.friendId"] = true,
}

local function pick(rng, list)
	return list[rng:NextInteger(1, #list)]
end

local function keysOf(t)
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	table.sort(out)
	return out
end

-- a payload that is invalid by construction, built from a valid one
local function mutate(engine, rng, remote, action, base)
	local p = Server.deepCopy(base)
	local keys = keysOf(p)
	local kind = rng:NextInteger(1, 9)
	local sendAction = action
	if kind == 1 and #keys > 0 then
		local bad = { table.unpack(BAD) }
		table.insert(bad, { deep = { deep = { 1 } } })
		table.insert(bad, engine.Instance.new("Part"))
		table.insert(bad, setmetatable({ 1 }, {}))
		p[pick(rng, keys)] = pick(rng, bad)
	elseif kind == 2 then
		p["zz" .. rng:NextInteger(1, 99)] = pick(rng, { 1, true, "x", {} })
	elseif kind == 3 then
		local required = {}
		for _, k in keys do
			if not OPTIONAL[`{remote}.{action}.{k}`] then
				table.insert(required, k)
			end
		end
		if #required > 0 then
			p[pick(rng, required)] = nil
		else
			p.zz = 1
		end
	elseif kind == 4 then
		p = pick(rng, { "str", 5, true, 0 / 0, engine.Instance.new("Part"), false })
	elseif kind == 5 then
		p.reqId = pick(rng, { 0, -1, 1.5, 2 ^ 31 + 1, "1", 0 / 0, math.huge })
	elseif kind == 6 then
		for i = 1, 17 do
			p["k" .. i] = i
		end
	elseif kind == 7 then
		sendAction = pick(rng, { "x", 5, false, {}, string.rep("a", 5000), action .. "!" })
	elseif kind == 8 then
		p = pick(rng, { { p }, { payload = p }, { a = { b = { c = p } } } })
		if type(p[1]) == "table" and next(p[1]) == nil then
			p = { { zz = 1 } }
		end
	else
		p = nil
	end
	return sendAction, p
end

test("fuzz: 500 invalid payloads per action never reach a handler and raise no errors", function()
	local engine, NetService, NetSchema, player, calls = NetHelp.setup()
	local rng = engine.Random.new(12345)
	local sent = 0
	for remote, actions in NetSchema.ACTIONS do
		for action in actions do
			local bases = Cases.valid[remote][action]
			for _ = 1, 500 do
				local sendAction, payload = mutate(engine, rng, remote, action, pick(rng, bases))
				engine:fireServer(player, remote, sendAction, payload)
				engine:advance(GAP, GAP)
				sent += 1
			end
		end
	end
	eq(#calls, 0, "handler calls on invalid input")
	eq(engine.errors, {})
	eq(#Server.kicksFor(engine, 10), 0)
	local stats = NetService.dropStats()
	eq((stats.byReason.schema or 0) + (stats.byReason.unknown_action or 0), sent, "every call dropped as schema/action")
	for _, line in engine.output do
		Assert.truthy(not line:find("failed for"), line)
	end
end)

test("foreign GUIDs pass the schema (ownership is the handlers' job)", function()
	local engine, _, _, player, calls = NetHelp.setup()
	local http = engine.game:GetService("HttpService")
	for _ = 1, 20 do
		engine:fireServer(player, "Inventory", "sellItem", { id = http:GenerateGUID(false) })
		engine:advance(GAP, GAP)
	end
	eq(#calls, 20)
end)
