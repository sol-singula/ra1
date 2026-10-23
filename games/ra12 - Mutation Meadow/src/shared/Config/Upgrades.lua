--[[
Plot levels (cost and { width, depth } in tiles per level), watering cans and sprinklers. A can's growSpeedBonus is
the share of a crop's remaining grow time one watering skips; sprinklers multiply growth on the area x area tiles
around them (the best one wins). Offline, crops grow at rate 1 for at most offlineCapSec; away welcomeBackSec or more
shows the Welcome-back card. Growth ticks every growTickSec on the server.
]]
return {
	plotCost = { 0, 100, 4000, 50000, 500000 },
	plotSize = { { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 8 }, { 8, 8 } },
	cans = {
		tin = { cost = 0, growSpeedBonus = 0.05 },
		copper = { cost = 1000, growSpeedBonus = 0.10 },
		silver = { cost = 12000, growSpeedBonus = 0.15 },
	},
	canOrder = { "tin", "copper", "silver" },
	sprinklers = {
		basic = { cost = 1500, growthMult = 1.25 },
		advanced = { cost = 15000, growthMult = 1.5 },
		area = 3,
		maxEach = 4,
	},
	offlineCapSec = 28800,
	welcomeBackSec = 1800,
	growTickSec = 1,
}
