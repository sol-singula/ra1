--[[
Payload validation for every client → server remote call (§5). Shared, so the client can check before sending.

Validators are tables { check = function(value) -> ok, why?, optional = bool? }:
  S.int(min, max)    an integer in [min, max]; NaN, ±inf and fractions fail
  S.num(min?, max?)  a finite number
  S.bool             true or false
  S.str(max)         valid UTF-8, at most max characters
  S.pattern(p)       a valid UTF-8 string matching the Lua pattern p
  S.enum(list)       one of the values in list
  S.guid             an item GUID (S.GUID_PATTERN)
  S.tileId           "1".."64" or "extra1".."extra8"
  S.opt(v)           nil, or passes v
  S.struct(fields)   a table with only these string keys, each passing its validator (strict)
  S.array(v, max)    a sequence 1..n (n <= max) of values passing v
  S.oneOf(a, b)      passes a or b

  S.checkGlobal(payload)   the rules for every payload: a plain table (no metatables, no Instances, only strings,
                           numbers, booleans and tables), at most Config.Net.maxKeys keys in all, maxDepth levels,
                           and maxBytes once JSON-encoded
  S.validate(remote, action, payload) -> true, body (the payload without reqId), reqId
                                       | false, "unknown_action" | "schema", why
  S.ACTIONS[remote][action]   the schema of every action
  S.REQ_ID                    the optional reqId every payload may carry (an integer 1..2^31)
]]
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Config)

local S = {}

S.GUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

local function v(name, check)
	return { name = name, check = check }
end

local function isFinite(x)
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function S.int(min, max)
	return v("int", function(x)
		if not isFinite(x) or x % 1 ~= 0 then
			return false, "not an integer"
		end
		if x < min or x > max then
			return false, "out of range"
		end
		return true
	end)
end

function S.num(min, max)
	return v("num", function(x)
		if not isFinite(x) then
			return false, "not a finite number"
		end
		if (min and x < min) or (max and x > max) then
			return false, "out of range"
		end
		return true
	end)
end

S.bool = v("bool", function(x)
	return type(x) == "boolean", "not a boolean"
end)

local function validString(x, max)
	if type(x) ~= "string" then
		return false, "not a string"
	end
	local n = utf8.len(x)
	if not n then
		return false, "invalid UTF-8"
	end
	if max and n > max then
		return false, "too long"
	end
	return true
end

function S.str(max)
	return v("str", function(x)
		return validString(x, max)
	end)
end

function S.pattern(p)
	return v("pattern", function(x)
		local ok, why = validString(x)
		if not ok then
			return false, why
		end
		return x:match(p) ~= nil, "no match"
	end)
end

function S.enum(list)
	local set = {}
	for _, value in list do
		set[value] = true
	end
	return v("enum", function(x)
		if (type(x) == "string" or isFinite(x)) and set[x] then
			return true
		end
		return false, "not allowed"
	end)
end

S.guid = S.pattern(S.GUID_PATTERN)
S.guid.name = "guid"

S.tileId = v("tileId", function(x)
	if type(x) ~= "string" then
		return false, "not a string"
	end
	local n = x:match("^([1-9]%d?)$")
	if n and tonumber(n) <= 64 then
		return true
	end
	if x:match("^extra[1-8]$") then
		return true
	end
	return false, "not a tile"
end)

function S.opt(inner)
	return {
		name = "opt",
		optional = true,
		check = function(x)
			if x == nil then
				return true
			end
			return inner.check(x)
		end,
	}
end

function S.struct(fields)
	return v("struct", function(x)
		if type(x) ~= "table" then
			return false, "not a table"
		end
		for k in x do
			if type(k) ~= "string" or fields[k] == nil then
				return false, `unknown key {tostring(k)}`
			end
		end
		for k, field in fields do
			local ok, why = field.check(x[k])
			if not ok then
				return false, `{k}: {why}`
			end
		end
		return true
	end)
end

function S.array(inner, max)
	return v("array", function(x)
		if type(x) ~= "table" then
			return false, "not a table"
		end
		local n = 0
		for _ in x do
			n += 1
		end
		if n > max then
			return false, "too many"
		end
		for i = 1, n do
			if x[i] == nil then
				return false, "not a sequence"
			end
			local ok, why = inner.check(x[i])
			if not ok then
				return false, `[{i}]: {why}`
			end
		end
		return true
	end)
end

function S.oneOf(a, b)
	return v("oneOf", function(x)
		if a.check(x) or b.check(x) then
			return true
		end
		return false, "matches neither"
	end)
end

-- the global rules: one walk over the payload
local function walk(t, depth, count)
	if depth > Config.Net.maxDepth then
		return false, "too deep"
	end
	if getmetatable(t) ~= nil then
		return false, "metatable"
	end
	for k, value in t do
		count.n += 1
		if count.n > Config.Net.maxKeys then
			return false, "too many keys"
		end
		local kt = type(k)
		if kt ~= "string" and kt ~= "number" then
			return false, "bad key"
		end
		local vt = typeof(value)
		if vt == "table" then
			local ok, why = walk(value, depth + 1, count)
			if not ok then
				return false, why
			end
		elseif vt ~= "string" and vt ~= "number" and vt ~= "boolean" then
			return false, `bad value {vt}`
		end
	end
	return true
end

function S.checkGlobal(payload)
	if typeof(payload) ~= "table" then
		return false, "not a table"
	end
	local ok, why = walk(payload, 1, { n = 0 })
	if not ok then
		return false, why
	end
	local encoded, json = pcall(function()
		return HttpService:JSONEncode(payload)
	end)
	if not encoded or type(json) ~= "string" then
		return false, "not encodable"
	end
	if #json > Config.Net.maxBytes then
		return false, "too big"
	end
	return true
end

S.REQ_ID = S.opt(S.int(1, 2 ^ 31))

---------------------------------------------------------------------------------------------------------------
-- the enums, built from Config

local function keys(t)
	local out = {}
	for k in t do
		table.insert(out, k)
	end
	table.sort(out, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return out
end

local seedKeys = keys(Config.Seeds)
local Seed = S.enum(seedKeys)

local catalogKeys = {}
for _, group in { Config.Catalog.passes, Config.Catalog.products, Config.Catalog.cosmetics, Config.Catalog.gifts } do
	for k in group do
		table.insert(catalogKeys, k)
	end
end
local CatalogKey = S.enum(catalogKeys)

local entries = {}
for _, seed in seedKeys do
	for _, mut in { "wet", "golden", "wetgolden" } do
		table.insert(entries, seed .. ":" .. mut)
	end
end

local questIds = {}
for _, group in { Config.Quests.starter, Config.Quests.daily } do
	for _, q in group do
		table.insert(questIds, q.key)
	end
end

local UserId = S.int(-(2 ^ 53), 2 ^ 53) -- Studio test players have negative ids
local Pedestal = S.int(1, Config.Inventory.pedestalMax)
local GiftId = S.str(40)
local struct, opt = S.struct, S.opt

S.ACTIONS = {
	Plot = {
		plant = struct({ tile = S.tileId, seed = Seed }),
		harvest = struct({ tile = S.tileId, onFull = opt(S.enum({ "sell", "leave" })) }),
		harvestAll = struct({}),
		water = struct({ tile = S.tileId, ownerId = opt(UserId) }),
		sprinkler = struct({ kind = S.enum({ "basic", "advanced" }), tile = S.tileId }),
		pickup = struct({ tile = S.tileId }),
	},
	Shop = {
		buySeed = struct({ seed = Seed, qty = S.enum({ 1, 5 }) }),
		close = struct({}),
	},
	Upgrade = {
		buy = struct({ kind = S.enum({ "plot", "can", "sprinklerBasic", "sprinklerAdvanced" }) }),
	},
	Basket = {
		sellAll = struct({}),
		setAutoSell = struct({ on = S.bool }),
	},
	Inventory = {
		sellItem = struct({ id = S.guid }),
		display = struct({ id = S.guid, pedestal = Pedestal }),
		undisplay = struct({ pedestal = Pedestal }),
	},
	Gift = {
		offer = S.oneOf(
			struct({ targetId = UserId, item = S.guid }),
			struct({ targetId = UserId, crop = Seed, qty = S.int(1, Config.Inventory.basketCap) })
		),
		respond = struct({ giftId = GiftId, accept = S.bool }),
		cancel = struct({ giftId = GiftId }),
	},
	Collection = {
		claim = S.oneOf(
			struct({ entry = S.enum(entries) }),
			struct({ milestone = S.enum(keys(Config.Collection.milestones)) })
		),
	},
	BlockParty = {
		water = struct({}),
	},
	Daily = {
		claim = struct({}),
	},
	Quest = {
		claim = struct({ questId = S.enum(questIds) }),
	},
	Playtime = {
		claim = struct({ index = S.int(1, #Config.Playtime) }),
	},
	Weekly = {
		claim = struct({ updateId = S.pattern("^%d%d%d%d%-%d%d%-%d%d$") }),
	},
	Lounge = {
		enter = struct({}),
	},
	Cosmetic = {
		equip = struct({ slot = S.enum({ "theme", "trail", "tag", "can" }), key = opt(S.str(32)) }),
	},
	Purchase = {
		prompt = struct({ key = CatalogKey, tile = opt(S.tileId), friendId = opt(UserId) }),
	},
	Settings = {
		set = struct({ key = S.enum({ "patchAlerts", "music", "sfx", "reducedFx", "gnomeOn" }), value = S.bool }),
		gardenName = struct({ name = S.str(Config.Net.gardenNameMax) }),
		patchAck = struct({ id = S.enum(Config.Patch.order), how = S.enum({ "tap", "timeout", "action" }) }),
	},
	Social = {
		like = struct({ ownerId = UserId }),
		visit = struct({ friendId = UserId }),
	},
	DevCommand = {
		run = struct({ cmd = S.str(32), args = S.array(S.oneOf(S.str(64), S.num()), 8) }),
	},
}

-- the client → server RemoteEvents, in §5 order plus ours
S.CLIENT_EVENTS = {
	"Plot",
	"Shop",
	"Upgrade",
	"Basket",
	"Inventory",
	"Gift",
	"Collection",
	"BlockParty",
	"Daily",
	"Quest",
	"Playtime",
	"Weekly",
	"Lounge",
	"Cosmetic",
	"Purchase",
	"Settings",
	"Social",
	"DevCommand",
}

-- server → client RemoteEvents. BlockParty and Weekly also exist client → server, so these two get a State suffix.
S.SERVER_EVENTS = {
	"State",
	"Restock",
	"BlockPartyState",
	"Weather",
	"Mutation",
	"Toast",
	"WeeklyState",
	"PatchLine",
	"Result",
	"GiftOffer",
}

S.FUNCTIONS = { "Snapshot" }

-- a payload against one schema, after the global rules and the optional reqId
function S.validatePayload(schema, payload)
	local ok, why = S.checkGlobal(payload)
	if not ok then
		return false, "schema", why
	end
	local reqId = payload.reqId
	if not S.REQ_ID.check(reqId) then
		return false, "schema", "reqId"
	end
	local body = payload
	if reqId ~= nil then
		body = table.clone(payload)
		body.reqId = nil
	end
	ok, why = schema.check(body)
	if not ok then
		return false, "schema", why
	end
	return true, body, reqId
end

function S.validate(remote, action, payload)
	local actions = S.ACTIONS[remote]
	local schema = actions and type(action) == "string" and actions[action]
	if not schema then
		return false, "unknown_action"
	end
	return S.validatePayload(schema, payload)
end

return S
