--[[
The Lune soak (§11.4): 8 players over SOAK_HOURS virtual hours (default 48) of random valid play, purchases,
gifts, rejoins and failed writes, with a forced server close every 6 hours (a new server picks the data up).
Invariants: coins >= 0, no GUID in 2 profiles, items conserved across gifts, receipts <= 50, no lost purchase,
every lock released at a close, the DataStore budget never below 0, an autosave every 90 s per player, Block Party
running every hour, and no errors.

  SOAK_HOURS=2 tools/run_tests.sh Soak     a shorter run
]]
local process = require("@lune/process")

local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")
local Store = require("./mock/Store")

local test, eq = Assert.test, Assert.eq

local roblox = require("@lune/roblox")

local HOURS = tonumber(process.env.SOAK_HOURS) or 48
local PLAYERS = 8
local OFFLINE = { 9, 10 } -- friends who only drop in at each restart: their Robux gifts go through the gift queue
local TICK = 60 -- each player acts about once a virtual minute
local CLOSE_EVERY = 6 * 3600
local START = 1_760_000_000

-- a small deterministic generator
local seed = 20261024
local function rand(n)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % n + 1
end
local function pick(list)
	return list[rand(#list)]
end

local COSMETICS = {
	"tag_sprout",
	"trail_leaf",
	"can_pumpkin",
	"tag_star",
	"can_crystal",
	"trail_firefly",
	"theme_cherry",
	"theme_candy",
	"theme_starry",
}

local stats =
	{ actions = 0, purchases = 0, gifts = 0, itemGifts = 0, rejoins = 0, closes = 0, failedWrites = 0, blooms = 0 }
local bought = {} -- [userId] = { [cosmetic] = true }: purchases that were granted
local giftsSent = {} -- [recipientId] = { [cosmetic] = true }

local server -- the current ctx
local online = {} -- [userId] = player
local joinedAt = {} -- [userId] = when the current session loaded
local serverN = 0

local function boot(prev)
	serverN += 1
	local ctx = Store.setup({
		budgetRefill = true,
		now = if prev then prev.engine.now else START,
		jobId = "job-" .. serverN,
		shareDataWith = prev and prev.engine or nil,
	}, function(engine)
		for a = 1, PLAYERS + #OFFLINE do
			for b = a + 1, PLAYERS + #OFFLINE do
				engine.friends[a .. ":" .. b] = true
			end
		end
	end)
	ctx.BP.Bloomed:Connect(function()
		stats.blooms += 1
	end)
	return ctx
end

local function join(id)
	local p = Farm.join(server, id)
	server.engine:advance(20) -- past a rejoin's load retry
	if server.Data.get(p) then
		online[id] = p
		joinedAt[id] = server.engine.now
		server.Data.get(p).firstSession.done = true
	else
		print(
			`[soak] {id} failed to load at {server.engine.now - START}: {table.concat(
				Server.kicksFor(server.engine, id),
				"; "
			)}`
		)
	end
	return p
end

local function raw(id)
	return server.engine.dataStores._raw("MM_Profiles_v1")["u_" .. id]
end

local function call(p, remote, action, payload, wait)
	stats.actions += 1
	return Farm.call(server, p, remote, action, payload, wait)
end

local function activeTiles(profile)
	local Tiles = server.engine:require(server.engine:module("Shared/Tiles"))
	return Tiles.activeTiles(profile.plotLevel, false)
end

local function countItems(profile)
	local n = 0
	for _ in profile.items do
		n += 1
	end
	return n
end

local ACTIONS = {}

function ACTIONS.plant(p, profile)
	for _, id in activeTiles(profile) do
		if not profile.tiles[id] and not profile.sprinklers.placed[id] then
			local seedKey = nil
			for s, n in profile.seeds do
				if n > 0 then
					seedKey = s
				end
			end
			if not seedKey then
				Farm.openShop(server, p)
				call(p, "Shop", "buySeed", { seed = "carrot", qty = 5 })
				call(p, "Shop", "close", {})
				return
			end
			Farm.standAtTile(server, p, p, id)
			call(p, "Plot", "plant", { tile = id, seed = seedKey })
			return
		end
	end
end

function ACTIONS.harvest(p, profile)
	for id in profile.tiles do
		local part = server.Plot.tilePart(p, id)
		if part and part:GetAttribute("Ripe") then
			Farm.standAtTile(server, p, p, id)
			call(p, "Plot", "harvest", { tile = id, onFull = "sell" })
		end
	end
end

function ACTIONS.sell(p)
	Farm.standAtStand(server, p)
	call(p, "Basket", "sellAll", {})
end

function ACTIONS.water(p, profile)
	local id = next(profile.tiles)
	if id then
		Farm.standAtTile(server, p, p, id)
		call(p, "Plot", "water", { tile = id })
	end
end

function ACTIONS.help(p)
	local other = online[rand(PLAYERS)]
	local op = other and other ~= p and server.Data.get(other)
	local id = op and next(op.tiles)
	if id then
		Farm.standAtTile(server, p, other, id)
		call(p, "Plot", "water", { tile = id, ownerId = other.UserId })
	end
end

function ACTIONS.upgrade(p)
	call(p, "Upgrade", "buy", { kind = pick({ "plot", "can", "sprinklerBasic" }) })
end

function ACTIONS.rewards(p)
	call(p, "Daily", "claim", {})
	call(p, "Playtime", "claim", { index = rand(3) })
end

function ACTIONS.buy(p, profile)
	stats.purchases += 1
	local key = pick({ "instantGrow", "growAll", pick(COSMETICS) })
	local D = server.engine.Enum.ProductPurchaseDecision
	local before = #profile.receipts
	local decision = Store.buy(server, p, key, `S{serverN}-{p.UserId}-{server.engine.now}`)
	if decision == D.PurchaseGranted and server.Config.Catalog.cosmetics[key] then
		bought[p.UserId] = bought[p.UserId] or {}
		bought[p.UserId][key] = true
	end
	Assert.truthy(#profile.receipts <= 50, "receipts <= 50")
	local _ = before
end

function ACTIONS.giftProduct(p)
	local to = if rand(3) == 1 then rand(PLAYERS) else pick(OFFLINE)
	if to == p.UserId then
		return
	end
	local key = pick(COSMETICS)
	local ok = call(p, "Purchase", "prompt", { key = "gift_" .. key, friendId = to }, 8)
	if ok then
		stats.gifts += 1
		local D = server.engine.Enum.ProductPurchaseDecision
		if Store.buy(server, p, "gift_" .. key, `G{serverN}-{p.UserId}-{server.engine.now}`) == D.PurchaseGranted then
			giftsSent[to] = giftsSent[to] or {}
			giftsSent[to][key] = true
		end
	end
end

function ACTIONS.itemGift(p, profile)
	local guid = nil
	for g, item in profile.items do
		if not item.locked then
			guid = g
		end
	end
	local other = online[rand(PLAYERS)]
	if not guid or not other or other == p or not server.Data.get(other) then
		return
	end
	local op = server.Data.get(other)
	local before = countItems(profile) + countItems(op)
	if call(p, "Gift", "offer", { targetId = other.UserId, item = guid }, 8) then
		local offers = server.engine:clientEvents("GiftOffer", other.UserId)
		local giftId = offers[#offers][1].giftId
		call(other, "Gift", "respond", { giftId = giftId, accept = rand(4) > 1 }, 8)
		stats.itemGifts += 1
		eq(countItems(profile) + countItems(op), before, "items conserved across a gift")
	end
end

function ACTIONS.keepFixture(p, profile)
	-- a kept mutated crop now and then, so there are items to gift and display
	local ItemModel = server.engine:require(server.engine:module("Server/Items/ItemModel"))
	if countItems(profile) < 20 then
		ItemModel.mint(profile, p.UserId, pick({ "carrot", "corn", "tomato" }), { wet = true })
	end
end

function ACTIONS.rejoin(p)
	stats.rejoins += 1
	local id = p.UserId
	online[id] = nil
	server.engine:removePlayer(p)
	server.engine:advance(8)
	join(id)
end

function ACTIONS.failWrite()
	stats.failedWrites += 1
	server.engine.dataStores._failNext("MM_Profiles_v1", "UpdateAsync", "502: soak", 1)
end

local WEIGHTED = {
	"plant",
	"plant",
	"plant",
	"harvest",
	"harvest",
	"harvest",
	"sell",
	"sell",
	"water",
	"help",
	"upgrade",
	"rewards",
	"buy",
	"giftProduct",
	"itemGift",
	"keepFixture",
	"keepFixture",
	"rejoin",
	"failWrite",
}

-- the offline friends drop in: the gift queue drains, and every gift granted for them is owned
local function visitOffline(where)
	for _, id in OFFLINE do
		local p = Farm.join(server, id)
		server.engine:advance(25)
		local profile = server.Data.get(p)
		Assert.truthy(profile, `{where}: {id} loaded`)
		for key in giftsSent[id] or {} do
			Assert.truthy(profile.cosmetics.owned[key], `{where}: {id} received {key}`)
		end
		server.engine:removePlayer(p)
		server.engine:advance(8)
	end
end

-- every profile, loaded or stored
local function checkInvariants(where)
	local owners = {}
	for id = 1, PLAYERS do
		local p = online[id]
		local profile = (p and server.Data.get(p)) or raw(id)
		if profile then
			Assert.truthy(profile.coins >= 0, `{where}: coins >= 0 for {id}`)
			Assert.truthy(#profile.receipts <= 50, `{where}: receipts <= 50 for {id}`)
			for guid in profile.items or {} do
				Assert.truthy(owners[guid] == nil, `{where}: {guid} in {owners[guid]} and {id}`)
				owners[guid] = id
			end
		end
	end
	Assert.truthy(server.engine.dataBudgetMin >= 0, `{where}: DataStore budget {server.engine.dataBudgetMin}`)
	eq(server.engine.errors, {}, where .. ": no errors")
end

-- autosaves: while a player stays in one session, profile writes land at most ~90 s apart (cooldowns, a failed
-- write's backoff and a purchase's extra save allowed for)
local function checkAutosave(engine, sessions)
	for _, s in sessions do
		local last = s.from
		for _, w in engine.dataStores._writes("MM_Profiles_v1", "u_" .. s.id) do
			if w.at > s.from and w.at <= s.to then
				Assert.truthy(w.at - last <= 90 + 6 + 12, `u_{s.id}: {w.at - last}s between saves`)
				last = w.at
			end
		end
	end
end

test(`soak: {PLAYERS} players over {HOURS} virtual hours`, function()
	server = boot(nil)
	for id = 1, PLAYERS do
		join(id)
	end
	local endAt = START + HOURS * 3600
	local nextClose = START + CLOSE_EVERY
	local nextCheck = START + 3600
	local started = os.clock()
	while server.engine.now < endAt do
		local tickEnd = server.engine.now + TICK
		for id = 1, PLAYERS do
			local p = online[id]
			local profile = p and server.Data.get(p)
			if profile then
				ACTIONS[pick(WEIGHTED)](p, profile)
			elseif not p then
				join(id)
			end
		end
		if server.engine.now < tickEnd then
			server.engine:advance(tickEnd - server.engine.now)
		end
		if server.engine.now >= nextCheck then
			nextCheck += 3600
			checkInvariants(`hour {math.floor((server.engine.now - START) / 3600)}`)
		end
		if server.engine.now >= nextClose then
			nextClose += CLOSE_EVERY
			stats.closes += 1
			local old = server
			local ok
			old.engine:run(function()
				ok = old.engine.closeHandlers[1]()
			end)
			old.engine:advance(30)
			Assert.truthy(ok, "the close flushed")
			for id = 1, PLAYERS do
				local stored = old.engine.dataStores._raw("MM_Profiles_v1")["u_" .. id]
				Assert.truthy(stored and stored.lock == nil, `u_{id}'s lock released at the close`)
				for key in bought[id] or {} do
					Assert.truthy(stored.cosmetics.owned[key], `u_{id} kept the {key} they bought`)
				end
			end
			for id in online do
				online[id] = nil
			end
			server = boot(old)
			visitOffline(`close {stats.closes}`)
			for id = 1, PLAYERS do
				join(id)
			end
		end
	end
	checkInvariants("the end")
	visitOffline("the end")
	-- no lost purchase: every bought cosmetic and every gift received is owned by the end
	for id = 1, PLAYERS do
		local p = online[id]
		local profile = p and server.Data.get(p)
		Assert.truthy(profile, `{id} online at the end`)
		for key in bought[id] or {} do
			Assert.truthy(profile.cosmetics.owned[key], `{id} owns {key}`)
		end
		for key in giftsSent[id] or {} do
			Assert.truthy(profile.cosmetics.owned[key], `{id} received {key}`)
		end
	end
	-- the last server's sessions: autosave cadence
	local sessions = {}
	for id = 1, PLAYERS do
		table.insert(sessions, { id = id, from = joinedAt[id], to = server.engine.now })
	end
	checkAutosave(server.engine, sessions)
	Assert.truthy(stats.blooms >= HOURS - 2, `Block Party bloomed {stats.blooms} times in {HOURS} h`)
	print(
		`[soak] {HOURS} h in {math.floor(os.clock() - started)} s: {stats.actions} actions, {stats.purchases} purchases, `
			.. `{stats.gifts} gift products, {stats.itemGifts} item gifts, {stats.rejoins} rejoins, {stats.closes} closes, `
			.. `{stats.failedWrites} failed writes, {stats.blooms} blooms, budget low {server.engine.dataBudgetMin}`
	)
	local _ = roblox
	local __ = Server
end)
