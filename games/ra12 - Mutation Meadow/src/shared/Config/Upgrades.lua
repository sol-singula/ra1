--[[
Plot levels (cost and { cols, rows } per level), watering cans and sprinklers. A can's bonus is its second
number from the design table; sprinklers multiply growth for the tiles within area of them.
]]
return {
	plotCost = { 0, 100, 4000, 50000, 500000 },
	plotSize = { { 3, 4 }, { 4, 5 }, { 5, 6 }, { 6, 8 }, { 8, 8 } },
	cans = {
		tin = { cost = 0, bonus = 0.05 },
		copper = { cost = 1000, bonus = 0.10 },
		silver = { cost = 12000, bonus = 0.15 },
	},
	sprinklers = {
		basic = { cost = 1500, growthMult = 1.25 },
		advanced = { cost = 15000, growthMult = 1.5 },
		area = 3,
		maxEach = 4,
	},
	offlineCapSec = 28800,
}
