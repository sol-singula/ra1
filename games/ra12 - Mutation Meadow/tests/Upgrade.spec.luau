local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

test("plot: costs 100, 4000, 50000, 500000; level 2 makes 20 tiles active; unlocks and the badge", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	local badges = {}
	ctx.FarmS.BadgeEarned:Connect(function(_, key)
		table.insert(badges, key)
	end)
	profile.coins = 99
	eq({ Farm.call(ctx, player, "Upgrade", "buy", { kind = "plot" }) }, { false, "coins" })
	profile.coins = 100
	eq(Farm.call(ctx, player, "Upgrade", "buy", { kind = "plot" }), true)
	eq({ profile.plotLevel, profile.coins }, { 2, 0 })
	local active = 0
	for _, tile in ctx.Plot.plotOf(player).Tiles:GetChildren() do
		if tile:GetAttribute("Active") then
			active += 1
		end
	end
	eq(active, 20)
	local texts = Farm.toastTexts(ctx, player)
	Assert.truthy(table.find(texts, "Tomato unlocked!") and table.find(texts, "Corn unlocked!"), "level 2 unlocks")
	for _, cost in { 4000, 50000, 500000 } do
		profile.coins = cost
		eq(Farm.call(ctx, player, "Upgrade", "buy", { kind = "plot" }), true)
		eq(profile.coins, 0)
	end
	eq(profile.plotLevel, 5)
	eq(badges, { "full_meadow" })
	Assert.truthy(table.find(Farm.toastTexts(ctx, player), "Dragon Fruit unlocked!"), "level 4")
	Assert.truthy(not table.find(Farm.toastTexts(ctx, player), "Moon Melon unlocked!"), "event only")
	profile.coins = 10 ^ 9
	eq({ Farm.call(ctx, player, "Upgrade", "buy", { kind = "plot" }) }, { false, "max" })
end)

test("can: tin -> copper (1000) -> silver (12000)", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	profile.coins = 13000
	eq(Farm.call(ctx, player, "Upgrade", "buy", { kind = "can" }), true)
	eq({ profile.can, profile.coins }, { "copper", 12000 })
	eq(Farm.call(ctx, player, "Upgrade", "buy", { kind = "can" }), true)
	eq({ profile.can, profile.coins }, { "silver", 0 })
	eq({ Farm.call(ctx, player, "Upgrade", "buy", { kind = "can" }) }, { false, "max" })
end)

test("sprinklers: 1500 / 15000, at most 4 of each", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	profile.coins = 6000 + 15000
	for _ = 1, 4 do
		eq(Farm.call(ctx, player, "Upgrade", "buy", { kind = "sprinklerBasic" }), true)
	end
	eq(profile.coins, 15000)
	eq({ Farm.call(ctx, player, "Upgrade", "buy", { kind = "sprinklerBasic" }) }, { false, "max" }, "a 5th basic")
	eq(Farm.call(ctx, player, "Upgrade", "buy", { kind = "sprinklerAdvanced" }), true)
	eq(profile.coins, 0)
	eq({ profile.sprinklers.basic, profile.sprinklers.advanced }, { 4, 1 })
end)

test("placing a sprinkler covers 3x3; its tile can't be planted; pickup returns it", function()
	local ctx = Farm.setup()
	local player = Farm.join(ctx, 1)
	local profile = ctx.Data.get(player)
	profile.sprinklers.basic = 1
	profile.seeds.carrot = 9
	Farm.standAtTile(ctx, player, player, "10")
	eq(Farm.call(ctx, player, "Plot", "plant", { tile = "1", seed = "carrot" }), true)
	eq(Farm.call(ctx, player, "Plot", "plant", { tile = "25", seed = "carrot" }), true)
	eq({ Farm.call(ctx, player, "Plot", "sprinkler", { kind = "basic", tile = "1" }) }, { false, "occupied" })
	eq(Farm.call(ctx, player, "Plot", "sprinkler", { kind = "basic", tile = "10" }), true)
	eq({ Farm.call(ctx, player, "Plot", "sprinkler", { kind = "basic", tile = "11" }) }, { false, "none_left" })
	eq({ Farm.call(ctx, player, "Plot", "sprinkler", { kind = "advanced", tile = "11" }) }, { false, "none_left" })
	eq({ Farm.call(ctx, player, "Plot", "plant", { tile = "10", seed = "carrot" }) }, { false, "occupied" })
	local rate = function(id)
		return ctx.FarmS.rateFor(player, profile, id)
	end
	for _, id in { "1", "2", "3", "9", "11", "17", "18", "19" } do
		eq(rate(id), 1.25, "covers " .. id)
	end
	for _, id in { "4", "12", "25", "26", "20" } do
		eq(rate(id), 1, "outside " .. id)
	end
	eq(ctx.Plot.tilePart(player, "1"):GetAttribute("Rate"), 1.25, "the crop on 1 shows the boost")
	eq(ctx.Plot.tilePart(player, "25"):GetAttribute("Rate"), 1)
	eq(Farm.call(ctx, player, "Plot", "pickup", { tile = "10" }), true)
	eq(profile.sprinklers.placed, {})
	eq(ctx.Plot.tilePart(player, "1"):GetAttribute("Rate"), 1)
	eq({ Farm.call(ctx, player, "Plot", "pickup", { tile = "10" }) }, { false, "empty" })
end)
