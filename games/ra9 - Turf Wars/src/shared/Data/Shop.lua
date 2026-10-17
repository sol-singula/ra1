--[[
Shards (◆) and what they buy. Cosmetic only: nothing for sale changes a fight, and VIP, MVP and the goals' rewards
are never for sale (Data/Achievements).

Where the money comes back from (recurring, by design):
  * the Turf Pass, a new one every 4 weeks (Data/Season), with +1 TIER for the impatient
  * the shop rotates: 4 items a day and a 3-item bundle a week, so there's always something new and each one is
    gone again soon (it comes back some day; season items never do)
  * Shards in packs (developer products: buy as often as you like), earned in play too, so free players get there
  * once: the Starter Pack (a game pass)
  * optional: the Shard Club (a Roblox subscription, monthly), when its id is set

IDs: 0 until they're made on the Creator Dashboard; in Studio an id of 0 is granted for free so it can be tried.

  Shop.price(item)              Shards
  Shop.daily(day, roll?)        the day's 4 items (keys), the same on every server (roll: an admin's reset)
  Shop.weekly(week)             { keys, price } the week's bundle
  Shop.inRotation(key, t, roll?)   true if it's in today's items
  Shop.shardsFor(info, firstWinToday)   Shards for a match
]]
local Cosmetics = require(script.Parent.Cosmetics)

local Shop = {}

Shop.PRICE = { common = 150, rare = 350, epic = 700, legendary = 1200 }
Shop.BUNDLE_OFF = 0.3 -- the weekly bundle: 30% off its three items
Shop.DAILY_SLOTS = 4

-- Robux (developer products, repeatable)
Shop.PACKS = {
	{ key = "shards_s", name = "Pocket of Shards", shards = 300, robux = 49, id = 3719115678 },
	{ key = "shards_m", name = "Pile of Shards", shards = 800, robux = 119, id = 3719115682, tag = "+9%" },
	{ key = "shards_l", name = "Crate of Shards", shards = 1800, robux = 249, id = 3719115684, tag = "+18%" },
	{ key = "shards_xl", name = "Vault of Shards", shards = 4000, robux = 499, id = 3719115687, tag = "BEST VALUE" },
}
Shop.PASS = { key = "pass", name = "Turf Pass", robux = 349, id = 3719115689 } -- per season
Shop.TIER = { key = "tier", name = "+1 Pass Tier", robux = 39, id = 3719115693 }
-- Robux (a game pass, once)
Shop.STARTER = {
	key = "starter",
	name = "Starter Pack",
	robux = 99,
	id = 2038113079, -- (a game pass)
	shards = 600,
	cosmetic = "starter_founder",
	desc = "600 Shards and the Founder banner",
}
-- A Roblox subscription (monthly); nil turns it off (nothing shows)
Shop.CLUB =
	{ key = "club", name = "Shard Club", subscriptionId = nil, monthlyShards = 600, desc = "600 Shards every month" }

Shop.products = {} -- [key] = product
for _, p in Shop.PACKS do
	Shop.products[p.key] = p
end
Shop.products.pass = Shop.PASS
Shop.products.tier = Shop.TIER

function Shop.productById(id)
	if id == 0 then
		return nil
	end
	for _, p in Shop.products do
		if p.id == id then
			return p
		end
	end
	return nil
end

-- Earning in play
Shop.EARN = { match = 8, win = 20, perKill = 1, killCap = 15, mvp = 10, firstWin = 40 }

function Shop.shardsFor(info, firstWinToday)
	if (info.seconds or 0) < 60 then
		return 0
	end
	local e = Shop.EARN
	local n = e.match + math.min(e.killCap, (info.kills or 0) * e.perKill)
	if info.won and info.qualified ~= false then
		n += e.win + (firstWinToday and e.firstWin or 0)
	end
	if info.mvp then
		n += e.mvp
	end
	return n
end

-- The rotation --------------------------------------------------------------------------------------------------
Shop.pool = {}
for _, it in Cosmetics.list do
	if it.source == "shop" then
		table.insert(Shop.pool, it.key)
	end
end

function Shop.price(it)
	return Shop.PRICE[it.rarity] or Shop.PRICE.common
end

-- A small seeded shuffle (the same everywhere: no math.random)
local function pick(seed, n, exclude)
	local list = {}
	for _, k in Shop.pool do
		if not (exclude and exclude[k]) then
			table.insert(list, k)
		end
	end
	local x = (seed * 2654435761) % 2147483646 + 1 -- (MINSTD: small enough to stay exact in a double)
	for i = #list, 2, -1 do
		x = (x * 48271) % 2147483647
		local j = x % i + 1
		list[i], list[j] = list[j], list[i]
	end
	local out = {}
	for i = 1, math.min(n, #list) do
		out[i] = list[i]
	end
	return out
end

function Shop.dayOf(t)
	return t // 86400
end

function Shop.weekOf(t)
	return (t // 86400 + 3) // 7 -- (weeks start on Monday)
end

function Shop.weekly(week)
	local keys = pick(week * 31 + 7, 3)
	local sum = 0
	for _, k in keys do
		sum += Shop.price(Cosmetics.get(k))
	end
	return { keys = keys, price = math.floor(sum * (1 - Shop.BUNDLE_OFF) / 10 + 0.5) * 10 }
end

-- roll: 0 (or nil) is everyone's shop; an admin's RESET SHOP gives one player a new roll (their "ShopRoll"
-- attribute, for the rest of their visit), so they get 4 other items for the day.
function Shop.daily(day, roll)
	local week = (day + 3) // 7
	local skip = {}
	for _, k in Shop.weekly(week).keys do
		skip[k] = true
	end
	return pick(day * 17 + 3 + (tonumber(roll) or 0) * 7919, Shop.DAILY_SLOTS, skip)
end

function Shop.inRotation(key, t, roll)
	for _, k in Shop.daily(Shop.dayOf(t), roll) do
		if k == key then
			return true
		end
	end
	return false
end

return Shop
