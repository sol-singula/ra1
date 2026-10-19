--[[
The town's market board (master plan §4, §10): three orders a day for each farmer, drawn from the crops they've
unlocked, each paying a bonus over the counter's price. From the shop stage on (a stand has nothing to spare);
the centre gets a fourth, bulk, contract. They complement the loop, never replace it.

  Market.orders(profile, day)   { { id, crop, n, bonus }, ... } the day's orders for this farmer
  Market.day()                  the day number (UTC)
]]
local Business = require(script.Parent.Business)
local Crops = require(script.Parent.Crops)

local Market = {}

Market.SIZES = {
	{ n = 25, bonus = 2.2, name = "Small order" },
	{ n = 80, bonus = 1.9, name = "Order" },
	{ n = 250, bonus = 1.7, name = "Big order" },
	{ n = 1200, bonus = 2.0, name = "Bulk contract" },
}

function Market.day()
	return math.floor(os.time() / 86400)
end

local function unlocked(profile)
	local out = {}
	for _, key in Crops.LIST do
		local c = Crops[key]
		if c.unlock == nil or (profile.owned[c.unlock] or 0) > 0 then
			table.insert(out, key)
		end
	end
	return out
end

function Market.orders(profile, day)
	local stage = Business[profile.stage or "stand"]
	if stage.index < Business.shop.index then
		return {}
	end
	local crops = unlocked(profile)
	local rng = Random.new((day or Market.day()) * 7919 + (profile.meta and profile.meta.createdAt or 0) % 100000)
	local out = {}
	local count = stage.index >= Business.center.index and 4 or 3
	for i = 1, count do
		local size = Market.SIZES[i]
		local crop = crops[rng:NextInteger(math.max(1, #crops - 2), #crops)]
		table.insert(out, {
			id = `{day or Market.day()}:{i}`,
			crop = crop,
			n = size.n,
			bonus = size.bonus,
			name = size.name,
			pays = math.floor(size.n * Crops[crop].value * size.bonus),
		})
	end
	return out
end

return Market
