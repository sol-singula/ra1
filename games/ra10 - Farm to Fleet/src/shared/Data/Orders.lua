--[[
Orders and daily contracts (master plan §3, §7, §8). Orders open with the packing shed (stage 3). Customers on the
order board ask for crops, and the board holds Upgrades.stat(owned, "orders", 0) of them at a time. Each order pays
MULT times what the stand would, has a time limit, and is packed at the shed's table (or by the box line). A packed
order leaves by road: the buyer's pickup comes for it (PICKUP_TRIP seconds) until the plot has vans, which make the
trip in Upgrades.stat "van" seconds (two at once with a second van). The order pays when the vehicle gets back.
Now and then a BIG order asks for BIG_SIZE times as much, pays BIG_PAY times as much, and adds Gems.

Daily contracts: three a day (a UTC day), picked from DAILY by the day and the player, measured from the stats they
had when the day began. Each pays Cash and a Gem, and all three add ALL_GEMS more.

  Orders.make(level, rng, products?) -> { who, items = { [crop] = n }, value (at the stand), big? }
  Orders.reward(order, bonus)        -> Cash, XP   (bonus: the extra share the sorter, the wrapper and the goats add)
  Orders.daily(day, userId, level)   -> { { key, stat, n, text, cash } x 3 }
  Orders.day(t?)                     the UTC day number for os.time() (or t)
]]
local Crops = require(script.Parent.Crops)

local Orders = {}

Orders.MULT = 3 -- an order pays this many times the stand
Orders.TIME = 10 * 60 -- seconds to fill an order (a big one gets twice as long)
Orders.REFRESH = 30 -- seconds before an empty slot gets its next customer
Orders.PICKUP_TRIP = 40 -- the buyer's pickup: seconds there and back
Orders.BIG_CHANCE = 1 / 6
Orders.BIG_SIZE = 2
Orders.BIG_PAY = 2.5
Orders.BIG_GEMS = 2
Orders.MAX_GROW = 300 -- orders only ask for crops that grow in this many seconds or less
Orders.ALL_GEMS = 3
Orders.MAX_PRODUCTS = 24 -- an order asks for at most this many of an animal's product (a pen makes them slowly)

Orders.CUSTOMERS = {
	"Corner Shop",
	"Rosie's Diner",
	"School Lunch",
	"Farmers Market",
	"Village Bakery",
	"Juice Bar",
	"Grand Hotel",
	"Green Grocer",
	"Pizza Place",
	"Smoothie Stand",
	"Food Bank",
	"Ice Cream Parlour",
}

-- What an order is worth at the stand, before MULT: it grows with the level, as fields and machines do
function Orders.target(level)
	return math.floor(60 * level ^ 1.3 + 0.5)
end

function Orders.make(level, rng, products)
	rng = rng or Random.new()
	rng:NextNumber() -- (a generator seeded with a small number draws a small number first: skip it)
	local pool = {}
	for _, key in Crops.unlocked(level) do
		if Crops[key].grow <= Orders.MAX_GROW then
			table.insert(pool, key)
		end
	end
	local big = rng:NextNumber() < Orders.BIG_CHANCE
	if not big then
		-- (a BIG order is all crops: a pen can't make that many of anything)
		for _, key in products or {} do
			table.insert(pool, key)
		end
	end
	-- (the newest few come up most: the order board shows off what they've just unlocked)
	local count = math.min(#pool, rng:NextInteger(1, 3))
	local items, picked = {}, {}
	local target = Orders.target(level) * (big and Orders.BIG_SIZE or 1)
	local value = 0
	for _ = 1, count do
		local i = math.max(1, #pool - rng:NextInteger(0, math.min(#pool - 1, 4)))
		local guard = 0
		while picked[pool[i]] and guard < 10 do
			i = rng:NextInteger(1, #pool)
			guard += 1
		end
		local key = pool[i]
		if not picked[key] then
			picked[key] = true
			local each = Crops[key] and Crops[key].value or Orders.productValue(key)
			local most = Crops[key] and 120 or Orders.MAX_PRODUCTS
			local n = math.clamp(math.floor(target / count / each + 0.5), 4, most)
			items[key] = n
			value += each * n
		end
	end
	return {
		who = Orders.CUSTOMERS[rng:NextInteger(1, #Orders.CUSTOMERS)],
		items = items,
		value = value,
		big = big or nil,
	}
end

-- (the animals' products, by key: kept here so Orders needs no Animals require cycle)
local PRODUCTS = { egg = 10, truffle = 30, wool = 60, milk = 110, cheese = 220 }
Orders.PRODUCT_NAMES = { egg = "Eggs", truffle = "Truffles", wool = "Wool", milk = "Milk", cheese = "Cheese" }
function Orders.productValue(key)
	return PRODUCTS[key] or 0
end

-- What an order calls an item: a crop's name or a product's
function Orders.itemName(key)
	return Crops[key] and Crops[key].name or Orders.PRODUCT_NAMES[key] or key
end

function Orders.reward(order, bonus)
	local cash = order.value * Orders.MULT * (order.big and Orders.BIG_PAY / Orders.BIG_SIZE or 1) * (1 + (bonus or 0))
	cash = math.floor(cash + 0.5)
	return cash, math.max(5, math.floor(cash / 40))
end

-- Daily contracts --------------------------------------------------------------------------------------------------
-- stylua: ignore start
Orders.DAILY = {
	{ key = "ship",    stat = "shipments",  n = 3,   text = "Ship %d orders" },
	{ key = "harvest", stat = "harvested",  n = 150, text = "Harvest %d crops" },
	{ key = "sell",    stat = "sold",       n = 100, text = "Sell %d things at the stand" },
	{ key = "plant",   stat = "planted",    n = 120, text = "Plant %d crops" },
	{ key = "feed",    stat = "fed",        n = 3,   text = "Feed your animals %d times" },
	{ key = "pack",    stat = "packed",     n = 80,  text = "Pack %d crops into boxes" },
	{ key = "eggs",    stat = "eggs",       n = 20,  text = "Collect %d eggs" },
	{ key = "big",     stat = "bigOrders",  n = 1,   text = "Ship %d BIG order" },
}
-- stylua: ignore end

function Orders.day(t)
	return math.floor((t or os.time()) / 86400)
end

function Orders.daily(day, userId, level)
	local rng = Random.new(day * 7919 + (userId or 0) % 100003)
	local keys = {}
	for i = 1, #Orders.DAILY do
		keys[i] = i
	end
	-- (a shuffle seeded by the day: everyone gets three, not the same three)
	for i = #keys, 2, -1 do
		local j = rng:NextInteger(1, i)
		keys[i], keys[j] = keys[j], keys[i]
	end
	local out = {}
	local scale = 1 + math.max(0, (level or 1) - 11) * 0.08
	for i = 1, 3 do
		local d = Orders.DAILY[keys[i]]
		local n = d.n
		if n >= 10 then
			n = math.floor(n * scale / 5 + 0.5) * 5
		end
		table.insert(out, {
			key = d.key,
			stat = d.stat,
			n = n,
			text = string.format(d.text, n),
			cash = math.floor(150 * (level or 1) / 10 + 0.5) * 10,
		})
	end
	return out
end

return Orders
