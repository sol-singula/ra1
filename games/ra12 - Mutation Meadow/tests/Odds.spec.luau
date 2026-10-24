local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local engine = Engine.new()
local Odds = engine:require(engine:module("Shared/Odds"))
local Config = engine:require(engine:module("Shared/Config"))

local function texts(config)
	local out = {}
	for _, row in Odds.rows(config) do
		table.insert(out, row.text)
	end
	return out
end

test("the rows come from Config", function()
	local t = texts(Config)
	for _, want in
		{
			"New seeds every 5 minutes",
			"Carrot: 100% each restock, 20 in stock",
			"Dragon Fruit: 4% each restock, 1 in stock",
			"Moon Melon: 5% each restock, 1 in stock (event weeks only)",
			"When the sunflower blooms: Rain 80%, Golden Hour 20%",
			"Wet: 25% per crop in Rain, 25% in the Welcome Shower",
			"Golden: 8% per crop in Golden Hour",
			"Value: Wet x2, Golden x20, Wet + Golden x40",
			"Each mutation happens at most once per crop; a Wet crop can still turn Golden",
			"1 guaranteed Wet crop 10s into your first shower",
			"Goal: max(20, 10 x players) waters, set when it opens",
			"The sunflower always blooms by :10, goal or not",
			"One roll per tile each Block Party, regrown crops included",
			"Private servers: max(2, 1 x players), 1+ waters for the reward",
		}
	do
		Assert.truthy(table.find(t, want), want)
	end
	eq(#t, 1 + 9 + 1 + 5 + 1 + 4)
end)

test("change a Config copy and the rows change to match", function()
	local copy = Server.deepCopy(Config)
	copy.Restock.stock.corn.chance = 0.55
	copy.Restock.stock.corn.qty = 7
	copy.Weather.pick = { rain = 0.7, goldenHour = 0.3 }
	copy.Mutations.golden.chance.goldenHour = 0.125
	copy.Mutations.stackMult = 50
	copy.BlockParty.goalMin = 25
	copy.BlockParty.windowSec = 900
	copy.Seeds.corn.name = "Sweet Corn"
	local t = texts(copy)
	for _, want in
		{
			"Sweet Corn: 55% each restock, 7 in stock",
			"When the sunflower blooms: Rain 70%, Golden Hour 30%",
			"Golden: 12.5% per crop in Golden Hour",
			"Value: Wet x2, Golden x20, Wet + Golden x50",
			"Goal: max(25, 10 x players) waters, set when it opens",
			"The sunflower always blooms by :15, goal or not",
		}
	do
		Assert.truthy(table.find(t, want), want)
	end
	Assert.truthy(not table.find(t, "Corn: 40% each restock, 5 in stock"), "the old row is gone")
end)
