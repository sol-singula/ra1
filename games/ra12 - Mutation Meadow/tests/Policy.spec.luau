local fs = require("@lune/fs")

local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Store = require("./mock/Store")
local roblox = require("@lune/roblox")

local test, eq = Assert.test, Assert.eq

-- every field a Catalog entry may have: none of them is coins, seeds, weather, restock or odds
local ALLOWED = {
	name = true,
	robux = true,
	id = true,
	tiles = true,
	radius = true,
	everySec = true,
	mult = true,
	grants = true,
	valueRobux = true,
	hideIfOwns = true,
	giftable = true,
	substitutes = true,
	slot = true,
	desc = true,
	of = true,
	friendsOnly = true,
}

local function eachPaid(Catalog, fn)
	for _, groupName in { "passes", "products", "cosmetics", "gifts" } do
		for key, item in Catalog[groupName] do
			fn(groupName, key, item)
		end
	end
end

test("a PolicyService failure gives the most restrictive policy; a good read is cached", function()
	local ctx = Store.setup()
	ctx.engine.policyFails = true
	local p = Farm.join(ctx, 1)
	local policy = ctx.Policy.get(p)
	eq(policy.ArePaidRandomItemsRestricted, true)
	eq(policy.IsPaidItemTradingAllowed, false)
	eq(policy.AllowedExternalLinkReferences, {})
	ctx.engine.policyFails = false
	local q = Farm.join(ctx, 2)
	eq(ctx.Policy.get(q).IsPaidItemTradingAllowed, true)
	local logged = Store.events(ctx, "policy")
	eq(#logged, 2)
	eq({ logged[1].paidRandomRestricted, logged[1].failed }, { true, true })
end)

test("hasSubscription is false on any error and true only when the check says so", function()
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	eq(ctx.Policy.hasSubscription(p), false, "the unverified property errors in the mock")
	local real = ctx.Policy.subscriptionCheck
	ctx.Policy.subscriptionCheck = function()
		return true
	end
	eq(ctx.Policy.hasSubscription(p), true)
	eq(ctx.Cosmetics.canEquip(p, ctx.Data.get(p), "can_brass"), true, "the subscriber can")
	ctx.Policy.subscriptionCheck = real
end)

test("no paid luck: no Catalog product grants coins, seeds, weather, restock or odds", function()
	local ctx = Store.setup()
	local C = ctx.Config.Catalog
	eachPaid(C, function(groupName, key, item)
		for field in item do
			Assert.truthy(ALLOWED[field], `{groupName}.{key}.{field}`)
		end
	end)
	for _, key in C.passes.starterBundle.grants do
		Assert.truthy(C.passes[key] or C.cosmetics[key], key)
	end
	for _, key in C.passes.starterBundle.substitutes do
		Assert.truthy(C.cosmetics[key], key)
	end
	for _, gift in C.gifts do
		Assert.truthy(C.passes[gift.of] or C.cosmetics[gift.of], gift.of)
	end
end)

test("no purchase code reads the Mutations, Weather or Restock config, or calls the luck services", function()
	local files = {
		"src/server/Services/PurchaseService.lua",
		"src/server/Purchase/init.lua",
		"src/server/Purchase/Bundle.lua",
		"src/server/Purchase/Cosmetics.lua",
		"src/server/Save/Receipts.lua",
		"src/server/Save/GiftQueue.lua",
	}
	for _, path in files do
		local src = fs.readFile(path)
		for _, banned in
			{
				"Config%.Mutations",
				"Config%.Weather",
				"Config%.Restock",
				"MutationService",
				"WeatherService",
				"ShopService",
				"MutationMath",
				"Odds",
			}
		do
			-- comments may name them; code may not
			local code = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
			Assert.truthy(not code:find(banned), `{path} uses {banned}`)
		end
	end
end)

test("every paid key and name passes the golden / rainbow / moon check", function()
	local ctx = Store.setup()
	eachPaid(ctx.Config.Catalog, function(groupName, key, item)
		for _, word in { "golden", "gold", "rainbow", "moon" } do
			Assert.truthy(not key:lower():find(word), `{groupName}.{key}`)
			Assert.truthy(not item.name:lower():find(word), `{groupName}.{key}: {item.name}`)
		end
	end)
end)

test(
	"the satin brass VIP pieces (#B08D57) are never gold-coloured; the gate is SmoothPlastic, no light or particles",
	function()
		local ctx = Store.setup()
		local brass = ctx.Cosmetics.BRASS
		eq(brass, roblox.Color3.fromHex("#B08D57"))
		local r, g, b = brass.R * 255, brass.G * 255, brass.B * 255
		-- gold sits near #FFC300 (255, 195, 0): fully saturated and bright; satin brass is muted
		local max, min = math.max(r, g, b), math.min(r, g, b)
		Assert.truthy((max - min) / max < 0.6, "muted, not saturated")
		Assert.truthy(max < 200, "not bright like gold")
		for _, key in { "tag_vip", "trail_vip_sparkle", "can_brass" } do
			eq(ctx.Cosmetics.LOOK[key][2], brass)
		end
		local gate = ctx.engine.workspace.Street.Lounge.Gate
		eq({ gate.Color, gate.Material, gate.Reflectance }, { brass, ctx.engine.Enum.Material.SmoothPlastic, 0.05 })
		for _, d in ctx.engine.workspace.Street.Lounge:GetDescendants() do
			Assert.truthy(not d:IsA("Light") and d.ClassName ~= "ParticleEmitter", d.Name .. ": no light or particles")
		end
	end
)
