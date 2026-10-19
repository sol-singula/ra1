--[[
The business (master plan §6): a fruit stand, then a fruit shop, a warehouse and a distribution centre. Each
stage has its own look and its own capacity problem. The numbers here are the stage's base; the retail and
logistics upgrades add to them (Data/Upgrades).

  demand    customers a minute who come (units they want to buy)
  service   units a minute the counters can sell
  storage   units the stock area holds
  dispatch  units a minute the docks can send out in bulk (warehouse and up)
  bulkPrice the price multiplier on bulk dispatches (trucks pay more than the counter)
]]
local Business = {}

Business.LIST = { "stand", "shop", "warehouse", "center" }

Business.stand = {
	name = "Fruit Stand",
	short = "STAND",
	cost = 0,
	demand = 18,
	service = 14,
	storage = 40,
	dispatch = 0,
	workers = 0,
	preview = "A real shop: shelves, a stockroom, workers and a proper line.",
}
Business.shop = {
	name = "Fruit Shop",
	short = "SHOP",
	cost = 15000,
	demand = 60,
	service = 50,
	storage = 400,
	dispatch = 0,
	workers = 2,
	preview = "A warehouse: pallets, a forklift and trucks that buy in bulk.",
}
Business.warehouse = {
	name = "Warehouse",
	short = "WAREHOUSE",
	cost = 5000000,
	demand = 90,
	service = 80,
	storage = 2000,
	dispatch = 60,
	bulkPrice = 1.4,
	workers = 4,
	preview = "A distribution centre: six docks, bulk contracts, a fleet of trucks.",
}
Business.center = {
	name = "Distribution Centre",
	short = "DIST. CENTRE",
	cost = 1500000000,
	demand = 140,
	service = 120,
	storage = 8000,
	dispatch = 400,
	bulkPrice = 1.6,
	workers = 8,
	preview = "A new region (prestige): keep your empire, start a bigger one.",
}

for i, key in Business.LIST do
	Business[key].key = key
	Business[key].index = i
end

function Business.next(key)
	local b = Business[key]
	return b and Business.LIST[b.index + 1] and Business[Business.LIST[b.index + 1]] or nil
end

return Business
