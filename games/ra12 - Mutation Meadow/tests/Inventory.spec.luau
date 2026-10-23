local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local function fillBackpack(ctx, player, n)
	local ItemModel = ctx.engine:require(ctx.engine:module("Server/Items/ItemModel"))
	local profile = ctx.Data.get(player)
	for _ = 1, n do
		ItemModel.mint(profile, player.UserId, "carrot", { wet = true })
	end
end

test("a mutated harvest becomes an item; the crop regrows clean", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local tile = Farm.crop(ctx, p, "1", "strawberry", true)
	tile.muts.golden = true
	eq(Farm.call(ctx, p, "Plot", "harvest", { tile = "1" }), true)
	eq({ tile.harvestsLeft, tile.grown < 1 }, { 4, true })
	eq(tile.muts, {})
	local guid, item = next(profile.items)
	Assert.truthy(guid, "minted")
	eq({ item.seed, item.owner, item.foundBy, item.locked }, { "strawberry", 1, 1, false })
	eq(item.muts, { golden = true })
	eq(profile.basket, {}, "not in the basket")
end)

test("the 61st item at level 1 is backpack_full; sell and leave", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	fillBackpack(ctx, p, 60)
	local tile = Farm.crop(ctx, p, "1", "pumpkin", true)
	tile.muts.golden = true
	eq({ Farm.call(ctx, p, "Plot", "harvest", { tile = "1" }) }, { false, "backpack_full" })
	eq({ Farm.call(ctx, p, "Plot", "harvest", { tile = "1", onFull = "leave" }) }, { true, "left" })
	eq(profile.tiles["1"], tile, "left ripe and untouched")
	eq(tile.muts, { golden = true })
	eq(Farm.call(ctx, p, "Plot", "harvest", { tile = "1", onFull = "sell" }), true)
	eq(profile.coins, 50 + 87000)
	eq(profile.tiles["1"], nil, "a pumpkin harvests once")
	local n = 0
	for _ in profile.items do
		n += 1
	end
	eq(n, 60)
	profile.plotLevel = 3
	eq(ctx.Inv.backpackCap(profile), 90)
end)

test("prices: Golden Pumpkin 87,000, Wet + Golden 174,000, x2 with 2x Sell Cash", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	eq(ctx.Inv.itemPrice(p, { seed = "pumpkin", muts = { golden = true } }), 87000)
	eq(ctx.Inv.itemPrice(p, { seed = "pumpkin", muts = { golden = true, wet = true } }), 174000)
	eq(ctx.Inv.itemPrice(p, { seed = "carrot", muts = { wet = true } }), 20)
	ctx.Data.get(p).passes.doubleCash = true
	eq(ctx.Inv.itemPrice(p, { seed = "pumpkin", muts = { golden = true } }), 174000)
end)

test("selling an item; a displayed item can't be sold", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local ItemModel = ctx.engine:require(ctx.engine:module("Server/Items/ItemModel"))
	local a = ItemModel.mint(profile, 1, "pumpkin", { golden = true })
	local b = ItemModel.mint(profile, 1, "corn", { wet = true })
	local sold = {}
	ctx.Inv.ItemSold:Connect(function(_, item, coins)
		table.insert(sold, { item.seed, coins })
	end)
	eq(Farm.call(ctx, p, "Inventory", "display", { id = a, pedestal = 1 }), true)
	eq(profile.items[a].locked, true)
	eq({ Farm.call(ctx, p, "Inventory", "sellItem", { id = a }) }, { false, "locked" })
	eq(Farm.call(ctx, p, "Inventory", "sellItem", { id = b }), true)
	eq(sold, { { "corn", 660 } })
	eq(profile.items[b], nil)
	eq(profile.coins, 50 + 300 + 660, "Starter 4 (display 1 item) paid 300")
	eq({ Farm.call(ctx, p, "Inventory", "sellItem", { id = b }) }, { false, "ownership" })
	eq(Farm.call(ctx, p, "Inventory", "undisplay", { pedestal = 1 }), true)
	eq(profile.items[a].locked, false)
	eq(Farm.call(ctx, p, "Inventory", "sellItem", { id = a }), true)
end)

test("pedestals: 2, 3, 4, 5, 6 by level, 7 with 18 finds; slots lock; the label names the finder", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local counts = {}
	for level = 1, 5 do
		profile.plotLevel = level
		counts[level] = ctx.Inv.pedestalCount(profile)
	end
	eq(counts, { 2, 3, 4, 5, 6 })
	for i = 1, 18 do
		profile.collection.found["k" .. i] = { at = 1, n = 1 }
	end
	eq(ctx.Inv.pedestalCount(profile), 7)
	profile.plotLevel = 1
	eq(ctx.Inv.pedestalCount(profile), 3)
	table.clear(profile.collection.found)
	local ItemModel = ctx.engine:require(ctx.engine:module("Server/Items/ItemModel"))
	local a = ItemModel.mint(profile, 1, "pumpkin", { golden = true, wet = true })
	local b = ItemModel.mint(profile, 1, "corn", { wet = true })
	eq({ Farm.call(ctx, p, "Inventory", "display", { id = a, pedestal = 3 }) }, { false, "pedestal_locked" })
	eq(Farm.call(ctx, p, "Inventory", "display", { id = a, pedestal = 2 }), true)
	eq({ Farm.call(ctx, p, "Inventory", "display", { id = b, pedestal = 2 }) }, { false, "pedestal_taken" })
	eq(
		{ Farm.call(ctx, p, "Inventory", "display", { id = a, pedestal = 1 }) },
		{ false, "locked" },
		"one pedestal at a time"
	)
	local part = ctx.Plot.pedestalPart(p, 2)
	eq(part:GetAttribute("ItemSeed"), "pumpkin")
	eq(part:GetAttribute("ItemMuts"), "wetgolden")
	eq(part:GetAttribute("ItemLabel"), "Wet + Golden Pumpkin\nfound by Player1")
	eq(
		{ ctx.Plot.pedestalPart(p, 2):GetAttribute("Unlocked"), ctx.Plot.pedestalPart(p, 3):GetAttribute("Unlocked") },
		{ true, false }
	)
	eq(Farm.call(ctx, p, "Inventory", "undisplay", { pedestal = 2 }), true)
	eq(part:GetAttribute("ItemSeed"), nil)
	eq({ Farm.call(ctx, p, "Inventory", "undisplay", { pedestal = 2 }) }, { false, "empty" })
end)

test("a name lookup that fails doesn't break the pedestal label", function()
	local ctx = Farm.setup()
	ctx.engine.nameLookupFails = true
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local ItemModel = ctx.engine:require(ctx.engine:module("Server/Items/ItemModel"))
	local a = ItemModel.mint(profile, 1, "corn", { wet = true })
	eq(Farm.call(ctx, p, "Inventory", "display", { id = a, pedestal = 1 }), true)
	eq(ctx.Plot.pedestalPart(p, 1):GetAttribute("ItemLabel"), "Wet Corn\nfound by a farmer")
end)
