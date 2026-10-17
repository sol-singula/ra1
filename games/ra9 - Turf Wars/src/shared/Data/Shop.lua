--[[
Shards (◆) and what they buy. Cosmetic, but for one thing: the TNT (Shop.TNT, a game pass). VIP, MVP and the goals'
rewards are never for sale (Data/Achievements).

Where the money comes back from (recurring, by design):
  * the Turf Pass, a new one every 4 weeks (Data/Season), with +1 TIER for the impatient
  * the shop rotates: 4 items a day and a 3-item bundle a week, so there's always something new and each one is
    gone again soon (it comes back some day; season items never do)
  * Shards in packs (developer products: buy as often as you like), earned in play too, so free players get there
  * once: the Starter Pack (a game pass), and the TNT (a game pass: locked on the hotbar until it's bought)
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
	robux = 49,
	was = 99, -- (its old price, shown struck beside it)
	id = 2038113079, -- (a game pass)
	shards = 600,
	cosmetic = "starter_founder",
	desc = "600 Shards and the Founder banner",
}
-- Robux (a game pass, once): TNT for good. Without it the TNT still sits on the hotbar, locked with its price (80%
-- off its old price), and a tap on the locked slot opens the purchase. No free throws: they see the bots' TNT and
-- want it. (Bots always have it: it's how everyone sees what it does.)
Shop.TNT = {
	key = "tnt",
	name = "TNT",
	robux = 30, -- (80% off: the tag and the old price show beside it)
	was = 149,
	id = 2036241176, -- (a game pass; 0 would mean not on sale, free in Studio)
	desc = "PERMANENT: yours forever. Throw one every 3s: it blows up walls and knocks out anyone close",
}
-- The lobby's Crate (Data/Crate: the odds and the pool): one spin for Shards, or for Robux (a developer product,
-- repeatable; 0 until it's made)
Shop.CRATE = { key = "crate", name = "Crate Spin", shards = 250, robux = 99, id = 0, crate = true }
-- A Roblox subscription (monthly); nil turns it off (nothing shows)
Shop.CLUB =
	{ key = "club", name = "Shard Club", subscriptionId = nil, monthlyShards = 600, desc = "600 Shards every month" }

-- Robux only, yours for good (Data/Cosmetics source "robux"): a developer product each, the price on the item.
-- Always in the shop's PREMIUM row (never rotated); a product's key is the cosmetic's.
Shop.PREMIUM_IDS = {
	rbx_lightning = 3719155231,
	rbx_doge = 3719155265,
	rbx_web = 3719155268,
	rbx_oof = 3719155271,
	rbx_bonk = 3719155272,
	rbx_dance = 3719155275,
	rbx_blackhole = 3719155280,
	rbx_heaven = 3719155284,
	rbx_storm = 3719155290,
	rbx_dragon = 3719155291,
	rbx_thunder = 3719155297,
	rbx_lightningbanner = 3719155299,
	rbx_dogebanner = 3719155301,
	rbx_crown = 3719155306,
	-- the sword skins (0: not made yet; free in Studio, "not on sale yet" live)
	rbx_lightningfang = 0,
	rbx_dogeblade = 0,
	rbx_scythe = 0,
}
Shop.PREMIUM = {}
for _, it in Cosmetics.list do
	if it.source == "robux" then
		table.insert(Shop.PREMIUM, {
			key = it.key,
			name = it.name,
			robux = it.robux,
			id = Shop.PREMIUM_IDS[it.key] or 0,
			cosmetic = it.key,
		})
	end
end

-- The daily deal: every UTC day each player gets one Robux-only item they don't have at Shop.DEAL.off, for
-- Shop.DEAL.seconds from when they first see it that day (ShopService: the "Deal" and "DealEnds" attributes). The
-- hour is real: once it's over the price goes back up until tomorrow's deal. Each deal price is its own developer
-- product (Shop.DEAL_IDS, "deal_<key>"); an id of 0 leaves that item out of the deals.
Shop.DEAL = { off = 0.7, seconds = 3600 }
Shop.DEAL_IDS = {
	rbx_lightning = 3719253873,
	rbx_doge = 3719253882,
	rbx_web = 3719253893,
	rbx_oof = 3719253897,
	rbx_bonk = 3719253908,
	rbx_dance = 3719253917,
	rbx_blackhole = 3719253920,
	rbx_heaven = 3719253924,
	rbx_storm = 3719253928,
	rbx_dragon = 3719253935,
	rbx_thunder = 3719253942,
	rbx_lightningbanner = 3719253947,
	rbx_dogebanner = 3719253957,
	rbx_crown = 3719253965,
}
Shop.DEALS = {}
for _, prem in Shop.PREMIUM do
	local d = {
		key = "deal_" .. prem.key,
		name = prem.name,
		robux = math.max(1, math.floor(prem.robux * (1 - Shop.DEAL.off) + 0.5)),
		was = prem.robux,
		id = Shop.DEAL_IDS[prem.key] or 0,
		cosmetic = prem.cosmetic,
		deal = true,
	}
	table.insert(Shop.DEALS, d)
end

-- The day's deal for a player: a Robux-only item they don't own (owns(key) -> bool), the same all day on every
-- server; nil when they own them all. inStudio: deals whose id is still 0 count too (given free there).
function Shop.dealFor(userId, day, owns, inStudio)
	local list = {}
	for _, d in Shop.DEALS do
		if (d.id ~= 0 or inStudio) and not (owns and owns(d.cosmetic)) then
			table.insert(list, d)
		end
	end
	if #list == 0 then
		return nil
	end
	local x = ((tonumber(userId) or 0) % 1000003 * 7919 + day * 104729) % 2147483647
	return list[x % #list + 1]
end

Shop.products = {} -- [key] = product
for _, p in Shop.PACKS do
	Shop.products[p.key] = p
end
for _, p in Shop.PREMIUM do
	Shop.products[p.key] = p
end
for _, p in Shop.DEALS do
	Shop.products[p.key] = p
end
Shop.products.pass = Shop.PASS
Shop.products.tier = Shop.TIER
Shop.products.crate = Shop.CRATE

-- "80% OFF": the cut from an item's old price (it.was), or nil
function Shop.off(it)
	if not (it and it.was and it.robux and it.was > it.robux) then
		return nil
	end
	return math.floor((1 - it.robux / it.was) * 100 + 0.5)
end

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
-- (kills are paid the moment they happen, MatchService: perKill, +headshot, up to killCap a match; the match's
-- end pays the rest)
Shop.EARN = { match = 10, win = 30, perKill = 5, headshot = 2, killCap = 30, mvp = 15, firstWin = 50 }

-- What a match pays, in parts, each paid (and shown flying to the counter) on its own: { match, win, mvp }.
-- In it at least PAY_SECONDS for any of it (a late joiner who helps win still gets the win); the day's first win
-- bonus only for a win that counts (firstWinToday).
Shop.PAY_SECONDS = 30
function Shop.shardsParts(info, firstWinToday)
	local out = { match = 0, win = 0, mvp = 0 }
	if (info.seconds or 0) < Shop.PAY_SECONDS then
		return out
	end
	local e = Shop.EARN
	out.match = e.match -- (the kills were paid as they happened)
	if info.won then
		out.win = e.win + (firstWinToday and e.firstWin or 0)
	end
	if info.mvp then
		out.mvp = e.mvp
	end
	return out
end

function Shop.shardsFor(info, firstWinToday)
	local parts = Shop.shardsParts(info, firstWinToday)
	return parts.match + parts.win + parts.mvp
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
