local Assert = require("./mock/Assert")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local function boot()
	local engine, DataService = Server.boot(nil, function(e)
		Server.patchConfig(e, function(cfg)
			cfg.Catalog.byProductId = {
				[111] = { group = "products", key = "instantGrow" },
				[222] = { group = "products", key = "growAll" },
			}
		end)
	end)
	local Receipts = engine:require(engine:module("Server/Save/Receipts"))
	local handlers = {
		instantGrow = function(_, profile)
			profile.coins += 10
		end,
		growAll = function(_, profile)
			profile.coins += 1000
			error("boom")
		end,
	}
	local function process(userId, purchaseId, productId)
		local out
		engine:run(function()
			out = Receipts.process(
				{ PlayerId = userId, PurchaseId = purchaseId, ProductId = productId or 111, CurrencySpent = 19 },
				handlers
			)
		end)
		engine:advance(20)
		return out
	end
	local D = engine.Enum.ProductPurchaseDecision
	return engine, DataService, process, D.PurchaseGranted, D.NotProcessedYet
end

test("two purchases grant twice; the same PurchaseId grants once", function()
	local engine, DataService, process, GRANTED = boot()
	local player = Server.join(engine, 1)
	eq(process(1, "P1"), GRANTED)
	eq(process(1, "P2"), GRANTED)
	eq(DataService.get(player).coins, 70)
	eq(process(1, "P1"), GRANTED)
	eq(DataService.get(player).coins, 70)
	eq(DataService.get(player).receipts, { "P1", "P2" })
	eq(Server.raw(engine, 1).receipts, { "P1", "P2" }, "saved")
end)

test("a throwing handler leaves coins unchanged", function()
	local engine, DataService, process, _, NOT_YET = boot()
	local player = Server.join(engine, 1)
	eq(process(1, "P3", 222), NOT_YET)
	eq(DataService.get(player).coins, 50)
	eq(DataService.get(player).receipts, {})
end)

test("a failed save rolls back", function()
	local engine, DataService, process, _, NOT_YET = boot()
	local player = Server.join(engine, 1)
	engine:advance(10)
	engine.dataStores._failNext("MM_Profiles_v1", "UpdateAsync", "500: down", 4)
	eq(process(1, "P4"), NOT_YET)
	local profile = DataService.get(player)
	eq(profile.coins, 50)
	eq(profile.receipts, {})
end)

test("a purchase by a player who left grants on rejoin", function()
	local engine, DataService, process, GRANTED, NOT_YET = boot()
	eq(process(99, "P5"), NOT_YET)
	local player = Server.join(engine, 99)
	eq(process(99, "P5"), GRANTED)
	eq(DataService.get(player).coins, 60)
end)

test("an unknown product is not processed; receipts keep the last 50", function()
	local engine, DataService, process, GRANTED, NOT_YET = boot()
	local player = Server.join(engine, 1)
	eq(process(1, "P6", 999), NOT_YET)
	local receipts = DataService.get(player).receipts
	for i = 1, 50 do
		receipts[i] = "old" .. i
	end
	eq(process(1, "P7"), GRANTED)
	eq(#receipts, 50)
	eq(receipts[1], "old2")
	eq(receipts[50], "P7")
end)
