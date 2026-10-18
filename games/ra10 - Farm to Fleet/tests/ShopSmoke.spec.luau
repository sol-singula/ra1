--[[
Phase I on the mock engine, server and client together: the shop (Data/Shop). The SHOP panel's three rows; in
Studio a product or pass without an id is given free; the Starter Pack once; Gem packs; Instant Harvest; a Robux
receipt granted once only (and saved); a pass bought in game or owned already from the website; what each pass does
(2x Cash, VIP's +10% and daily Gems, the extra order, the long nap); what Gems buy (ripen, feed, golden seeds, Cash
Rush, a Special Order), never with too few Gems.

  luaurun tests/ShopSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector2 = Engine.globals.Vector2

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

local tree = Engine.mountProject(".")
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1240, 560)
Engine.runScript(tree.server.Main)
Engine.advance(0.5)

local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local ShopS = service("ShopService")
local Farm = service("FarmService")
local Offline = service("OfflineService")
local Daily = service("DailyService")
local Order = service("OrderService")
local Special = service("SpecialService")
local Shop = Engine.require(tree.shared.Data.Shop)
local Constants = Engine.require(tree.shared.Constants)
local Enum = Engine.Enum
Special.FIRST = 1e9
Special.DAILY = false

local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local p = Data:Get(player)
local ShopC = Engine.require(tree.client.Controllers.ShopController)
local Bus = Engine.require(tree.client.UI.Bus)

-- The panel ------------------------------------------------------------------------------------------------------------
Bus.Panel:Fire("shop")
Engine.advance(0.5)
check(
	"the SHOP panel: five products",
	ShopC.refs.products[5].frame.Visible and ShopC.refs.products[1].name.Text == "Starter Pack"
)
check("...four passes", ShopC.refs.passes[4].frame.Visible)
check("...five Gem buys", ShopC.refs.gems[5].frame.Visible and ShopC.refs.gems[1].buy.Text:find("5") ~= nil)
check("...not on sale yet: SOON", ShopC.refs.passes[1].buy.Text == "SOON")

-- Studio: given free ---------------------------------------------------------------------------------------------------
local gems0, cash0 = p.gems, p.cash
ShopC.refs.products[1].buy.Activated:Fire()
Engine.advance(0.5)
local s = Shop.starter(p.level)
check("the Starter Pack (free in Studio)", p.starter and p.gems - gems0 == s.gems and p.cash - cash0 == s.cash)
check("...golden seeds", p.goldenSeeds == s.seeds)
check("...once only: gone from the shop", ShopC.refs.products[1].name.Text ~= "Starter Pack")
check("...and can't be bought again", not ShopS:PromptRobux(player, "starter"))
gems0 = p.gems
Engine.fireServer(player, "Shop", "robux", "gems550")
Engine.advance(0.2)
check("a Chest of Gems", p.gems - gems0 == 550)
Engine.moveTo(player, Farm:Tiles(player)[1].Position)
Engine.advance(0.5)
Farm:Plant(player, 1, "strawberry")
Farm:Plant(player, 2, "strawberry")
check(
	"Instant Harvest: everything ripe",
	ShopS:Grant(player, "skipGrow") and Farm:Ripe(player, 1) and Farm:Ripe(player, 2)
)

-- Real receipts --------------------------------------------------------------------------------------------------------
Constants.PRODUCTS.gems100 = 111
gems0 = p.gems
local receipt = { PlayerId = 901, ProductId = 111, PurchaseId = "r-1" }
check("a receipt: granted", ShopS:ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.PurchaseGranted)
check("...the Gems", p.gems - gems0 == 100)
check(
	"...the same receipt again: granted, not given twice",
	ShopS:ProcessReceipt(receipt) == Enum.ProductPurchaseDecision.PurchaseGranted and p.gems - gems0 == 100
)
check(
	"a receipt for someone not here: not yet",
	ShopS:ProcessReceipt({ PlayerId = 5, ProductId = 111, PurchaseId = "r-2" })
		== Enum.ProductPurchaseDecision.NotProcessedYet
)
Engine.fireServer(player, "Shop", "robux", "gems100")
Engine.advance(0.2)
check("a real product: the purchase prompt", Engine.prompted[#Engine.prompted].id == 111)

-- Passes ---------------------------------------------------------------------------------------------------------------
p.owned.shed = 1
cash0 = p.cash
Economy:Add(player, 1000, "order")
local one = p.cash - cash0
Constants.PASSES.doubleCash = 222
Engine.fireServer(player, "Shop", "robux", "doubleCash")
Engine.advance(0.2)
check(
	"a real pass: the prompt",
	Engine.prompted[#Engine.prompted].kind == "pass" and Engine.prompted[#Engine.prompted].id == 222
)
Engine.game:GetService("MarketplaceService").PromptGamePassPurchaseFinished:Fire(player, 222, true)
Engine.advance(0.2)
check("...bought: 2x Cash", p.passes.doubleCash == true)
cash0 = p.cash
Economy:Add(player, 1000, "order")
check("...everything shipped pays double", p.cash - cash0 == one * 2, p.cash - cash0)
cash0 = p.cash
Economy:Add(player, 1000, "calendar")
check("...not gifts", p.cash - cash0 == 1000)
check("Extra Order (free in Studio)", ShopS:PromptRobux(player, "extraOrder") and p.passes.extraOrder)
Order:Push(player)
Engine.advance(0.5)
check(
	"...one more order on the board",
	#Order:Slots(player) == Engine.require(tree.shared.Data.Upgrades).shed.value + 1,
	#Order:Slots(player)
)
check("Long Nap: 12 h away", ShopS:PromptRobux(player, "longNap") and Offline:Hours(p) == Constants.OFFLINE_PASS_HOURS)
check("VIP", ShopS:PromptRobux(player, "vip") and player:GetAttribute("VIP") == true)
p.calendar.claimedDay = 0
gems0 = p.gems
local r = Daily:Claim(player)
check(
	"...ten more Gems with the day's reward",
	p.gems - gems0 == (Engine.require(tree.shared.Data.Daily).reward(r.day, p.level).gems + 10)
)
check(
	"...owned passes say OWNED",
	(function()
		Bus.Panel:Fire(nil)
		Bus.Panel:Fire("shop")
		Engine.advance(0.5)
		return ShopC.refs.passes[1].buy.Text == "OWNED"
	end)()
)
check("a pass can't be bought twice", not ShopS:PromptRobux(player, "vip"))

-- Owned on the website ---------------------------------------------------------------------------------------------------
Engine.ownedPasses = { ["902:222"] = true }
local ben = Engine.addPlayer("Ben", 902)
Engine.advance(2)
check("a pass from the website: theirs on join", Data:Get(ben).passes.doubleCash == true)

-- Gems --------------------------------------------------------------------------------------------------------------------
Farm:RipenAll(player)
Farm:Harvest(player, 1)
Farm:Harvest(player, 2)
Farm:Plant(player, 1, "strawberry")
gems0 = p.gems
check(
	"Ripen Everything",
	ShopS:BuyGems(player, "ripen") and Farm:Ripe(player, 1) and gems0 - p.gems == Shop.GEMS.ripen.gems
)
p.animals.chicken = { level = 1, n = 1, fedAt = 0 }
check("Feed Everyone", ShopS:BuyGems(player, "feed") and p.animals.chicken.fedAt > 0)
local seeds = p.goldenSeeds
check("Golden Seeds x10", ShopS:BuyGems(player, "seeds") and p.goldenSeeds == seeds + 10)
check("Cash Rush", ShopS:BuyGems(player, "boost") and Shop.cashMult(p) >= 4)
cash0 = p.cash
Economy:Add(player, 1000, "order")
check(
	"...everything shipped x2 again (and VIP's +10%)",
	p.cash - cash0 == math.floor(one * 4 * 1.1 + 0.5),
	p.cash - cash0
)
check("a Special Order now", ShopS:BuyGems(player, "special") and Special:Current(player) ~= nil)
check("...not while one is on", not ShopS:BuyGems(player, "special"))
p.gems = 3
check("too few Gems: nothing", not ShopS:BuyGems(player, "seeds") and p.gems == 3)
Engine.advance(0.5)
check("the panel shows the Cash Rush's time", ShopC.refs.boost.Text:find("CASH RUSH") ~= nil, ShopC.refs.boost.Text)

local bad = {}
for _, w in Engine.warnings do
	if tostring(w):find("failed") then
		table.insert(bad, tostring(w))
	end
end
check("no failed saves or ticks", #bad == 0, bad[1])
if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`ShopSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
