--[[
Purchases with real ids: every pass, product, cosmetic and gift gets a made-up id (the shipped Catalog has 0s).

  local ctx = Store.setup(opts?, setup?)    Farm.setup with the ids patched in; ctx.Purchase, ctx.Bundle,
                                           ctx.PurchaseService, ctx.Cosmetics, ctx.Policy, ctx.Lounge, ctx.Config
  Store.id(ctx, key)                       the id given to a key
  Store.buy(ctx, player, key, purchaseId?) -> decision   runs ProcessReceipt (a fixed purchaseId re-sends one)
  Store.buyPass(ctx, player, key)          live ownership + PromptGamePassPurchaseFinished(true)
]]
local Farm = require("./Farm")
local Server = require("./Server")

local Store = {}

local function patch(Config)
	local n = 0
	local ids = {}
	for _, groupName in { "passes", "products", "cosmetics", "gifts" } do
		local keys = {}
		for key in Config.Catalog[groupName] do
			table.insert(keys, key)
		end
		table.sort(keys)
		for _, key in keys do
			n += 1
			local id = 9000 + n
			Config.Catalog[groupName][key].id = id
			ids[key] = id
		end
	end
	Config.Catalog.byProductId = {}
	for groupName, group in
		{ products = Config.Catalog.products, cosmetics = Config.Catalog.cosmetics, gifts = Config.Catalog.gifts }
	do
		for key, item in group do
			Config.Catalog.byProductId[item.id] = { group = groupName, key = key }
		end
	end
	return ids
end

function Store.setup(opts, setup)
	local ids
	local ctx = Farm.setup(opts, function(engine)
		Server.patchConfig(engine, function(Config)
			ids = patch(Config)
		end)
		if setup then
			setup(engine)
		end
	end)
	local function mod(path)
		return ctx.engine:require(ctx.engine:module(path))
	end
	ctx.ids = ids
	ctx.Config = mod("Shared/Config")
	ctx.Purchase = mod("Server/Purchase")
	ctx.Bundle = mod("Server/Purchase/Bundle")
	ctx.Cosmetics = mod("Server/Purchase/Cosmetics")
	ctx.PurchaseService = mod("Server/Services/PurchaseService")
	ctx.Policy = mod("Server/Services/PolicyGate")
	ctx.Lounge = mod("Server/Services/LoungeService")
	ctx.Telemetry = mod("Server/Telemetry")
	return ctx
end

function Store.id(ctx, key)
	return ctx.ids[key]
end

function Store.buy(ctx, player, key, purchaseId)
	local market = ctx.engine.game.MarketplaceService
	local out
	ctx.engine:run(function()
		out = market.ProcessReceipt({
			PlayerId = player.UserId,
			ProductId = ctx.ids[key],
			PurchaseId = purchaseId or ("P-" .. key .. "-" .. ctx.engine.now),
			CurrencySpent = 0,
			PlaceIdWherePurchased = 0,
		})
	end)
	ctx.engine:advance(10)
	return out
end

function Store.buyPass(ctx, player, key)
	ctx.engine.passes[player.UserId .. ":" .. ctx.ids[key]] = true
	ctx.engine.game.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, ctx.ids[key], true)
	ctx.engine:advance(0.2)
end

-- the telemetry events with this name, for one player
function Store.events(ctx, name, userId)
	local out = {}
	for _, e in ctx.Telemetry.events do
		if e.name == name and (userId == nil or e.userId == userId) then
			table.insert(out, e.data)
		end
	end
	return out
end

return Store
