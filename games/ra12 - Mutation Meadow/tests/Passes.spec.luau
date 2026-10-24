local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")
local Store = require("./mock/Store")

local test, eq = Assert.test, Assert.eq

local roblox = require("@lune/roblox")

local function setup(edit)
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	if edit then
		edit(profile)
	end
	return ctx, p, profile
end

local function prompt(ctx, p, payload)
	return { Farm.call(ctx, p, "Purchase", "prompt", payload) }
end

test("with nothing owned the bundle is Extra Plot Row + Pumpkin Watering Can + Sprout Buddy, worth 327", function()
	local ctx, p = setup()
	eq(ctx.Bundle.resolve(p), { grants = { "extraRow", "can_pumpkin", "tag_sprout" }, value = 327 })
	eq(prompt(ctx, p, { key = "starterBundle" }), { true })
	eq(ctx.engine.prompts[#ctx.engine.prompts], { kind = "pass", userId = 1, id = Store.id(ctx, "starterBundle") })
end)

test("owning Sprout Buddy still shows the bundle; the grant swaps in Leaf Swirl", function()
	local ctx, p, profile = setup(function(profile)
		profile.cosmetics.owned.tag_sprout = true
	end)
	eq(ctx.Bundle.resolve(p), { grants = { "extraRow", "can_pumpkin", "trail_leaf" }, value = 357 })
	Store.buyPass(ctx, p, "starterBundle")
	eq(profile.meta.bundleGrants, { "extraRow", "can_pumpkin", "trail_leaf" })
	eq({ profile.cosmetics.owned.can_pumpkin, profile.cosmetics.owned.trail_leaf }, { true, true })
	eq(ctx.Purchase.owns(p, "extraRow"), true, "the bundle's row")
	eq(ctx.Plot.plotOf(p).ExtraRow.extra1:GetAttribute("Active"), true, "the bed shows at once")
	eq(p:GetAttribute("BundleOffer"), nil, "hidden once bought")
end)

test("owning the can swaps in Leaf Swirl; owning both gives Leaf Swirl and Star Farmer", function()
	local ctx, p, profile = setup(function(profile)
		profile.cosmetics.owned.can_pumpkin = true
	end)
	eq(ctx.Bundle.resolve(p).grants, { "extraRow", "trail_leaf", "tag_sprout" })
	profile.cosmetics.owned.tag_sprout = true
	eq(ctx.Bundle.resolve(p), { grants = { "extraRow", "trail_leaf", "tag_star" }, value = 377 })
end)

test("owning Extra Plot Row hides the bundle and refuses its prompt", function()
	local ctx = Store.setup()
	ctx.engine.passes["1:" .. Store.id(ctx, "extraRow")] = true
	local p = Farm.join(ctx, 1)
	eq(ctx.Purchase.owns(p, "extraRow"), true)
	eq(ctx.Bundle.resolve(p), nil)
	eq(p:GetAttribute("BundleOffer"), nil)
	local before = #ctx.engine.prompts
	eq(prompt(ctx, p, { key = "starterBundle" }), { false, "hidden" })
	eq(#ctx.engine.prompts, before, "no prompt")
end)

test("every combination of owned cosmetics: no dupes, nothing owned, worth >= 327, or hidden", function()
	local ctx = Store.setup()
	local keys = {}
	for key in ctx.Config.Catalog.cosmetics do
		table.insert(keys, key)
	end
	table.sort(keys)
	eq(#keys, 9)
	local hidden, shown = 0, 0
	for mask = 0, 2 ^ #keys - 1 do
		local owned = {}
		for i, key in keys do
			if bit32.btest(mask, 2 ^ (i - 1)) then
				owned[key] = true
			end
		end
		local r = ctx.Bundle.resolveWith(function(key)
			return owned[key] == true
		end)
		if r == nil then
			hidden += 1
		else
			shown += 1
			eq(#r.grants, 3, `mask {mask}`)
			local seen, value = {}, 0
			for _, key in r.grants do
				Assert.truthy(not seen[key], `dupe {key} at mask {mask}`)
				Assert.truthy(not owned[key], `owned {key} at mask {mask}`)
				seen[key] = true
				value += ctx.Bundle.valueOf(key)
			end
			eq(r.value, value)
			Assert.truthy(value >= 327, `worth {value} at mask {mask}`)
			eq(r.grants[1], "extraRow")
		end
	end
	eq(hidden + shown, 512)
	Assert.truthy(hidden > 0 and shown > 0, `{hidden} hidden, {shown} shown`)
end)

test("a rejoin re-grants the same saved bundleGrants", function()
	local ctx, p, profile = setup(function(profile)
		profile.cosmetics.owned.tag_sprout = true
	end)
	Store.buyPass(ctx, p, "starterBundle")
	local grants = table.clone(profile.meta.bundleGrants)
	ctx.engine:removePlayer(p)
	ctx.engine:advance(7)
	-- the stored copy loses the can (and owns Leaf Swirl's neighbour now): the saved list still decides
	local raw = Server.raw(ctx.engine, 1)
	raw.cosmetics.owned.can_pumpkin = nil
	raw.cosmetics.owned.tag_star = true
	local again = Farm.join(ctx, 1)
	ctx.engine:advance(15)
	local after = ctx.Data.get(again)
	eq(after.meta.bundleGrants, grants)
	eq(after.cosmetics.owned.can_pumpkin, true, "re-granted")
	eq(ctx.Purchase.owns(again, "extraRow"), true)
end)

test("the bundle has no gift product, and gift products cover every other pass and cosmetic", function()
	local ctx = Store.setup()
	local C = ctx.Config.Catalog
	eq(C.gifts.gift_starterBundle, nil)
	local n = 0
	for _ in C.gifts do
		n += 1
	end
	eq(n, 13)
end)

test("the gnome harvests ripe normal crops within 12 studs; never a Wet one, never 13 studs away", function()
	local ctx, p, profile = setup(function(profile)
		profile.passes.gnome = true
	end)
	local t1 = ctx.Plot.tilePart(p, "1")
	Farm.standAt(ctx, p, t1.Position - roblox.Vector3.new(1, 0, 0))
	Farm.crop(ctx, p, "2", "carrot", true).muts = { wet = true }
	Farm.crop(ctx, p, "3", "carrot", true)
	Farm.crop(ctx, p, "4", "carrot", true) -- 13 studs from the player
	eq(
		math.floor((ctx.Plot.tilePart(p, "4").Position - (t1.Position - roblox.Vector3.new(1, 0, 0))).Magnitude + 0.5),
		13
	)
	local n
	ctx.engine:run(function()
		n = ctx.FarmS.gnomeTick(p)
	end)
	eq(n, 1)
	eq(profile.tiles["3"], nil, "harvested")
	Assert.truthy(profile.tiles["2"] and profile.tiles["4"], "the Wet crop and the far one stay")
	eq(profile.basket.carrot, 1)
	profile.gnomeOn = false
	Farm.crop(ctx, p, "3", "carrot", true)
	ctx.engine:run(function()
		n = ctx.FarmS.gnomeTick(p)
	end)
	eq(n, 0, "off")
	profile.gnomeOn = true
	profile.passes.gnome = nil
	ctx.engine:run(function()
		n = ctx.FarmS.gnomeTick(p)
	end)
	eq(n, 0, "not owned")
end)

test("the gnome runs on its own every 2s", function()
	local ctx, p, profile = setup(function(profile)
		profile.passes.gnome = true
	end)
	Farm.crop(ctx, p, "1", "carrot", true)
	ctx.engine:advance(2.5)
	eq(profile.tiles["1"], nil)
end)

test("2x Sell Cash doubles a 10-coin carrot but not a 100-coin daily", function()
	local ctx, p, profile = setup(function(profile)
		profile.passes.doubleCash = true
		profile.autoSell = true
	end)
	Farm.crop(ctx, p, "1", "carrot", true)
	local coins = profile.coins
	eq(Farm.call(ctx, p, "Plot", "harvest", { tile = "1" }), true)
	eq(profile.coins, coins + 20)
	coins = profile.coins
	eq(Farm.call(ctx, p, "Daily", "claim", {}), true)
	eq(profile.coins, coins + 100)
end)

test("ownership: live passes are read on join with retries; a gift counts; a failed read is not owned", function()
	local ctx = Store.setup()
	ctx.engine.passes["1:" .. Store.id(ctx, "vip")] = true
	local p = Farm.join(ctx, 1)
	eq({ ctx.Purchase.owns(p, "vip"), ctx.Purchase.owns(p, "gnome") }, { true, false })
	eq(p:GetAttribute("Pass_vip"), true)
	ctx.Data.get(p).passes.gnome = true
	eq(ctx.Purchase.owns(p, "gnome"), true, "gifted")
	ctx.engine.passCheckFails = true
	local q = Farm.join(ctx, 2)
	ctx.engine.passes["2:" .. Store.id(ctx, "vip")] = true
	eq(ctx.Purchase.owns(q, "vip"), false)
end)
