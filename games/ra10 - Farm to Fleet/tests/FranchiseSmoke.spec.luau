--[[
Phase H on the mock engine, server and client together: prestige (master plan §13.5). A whole hub built (the plot
rebuilt in place from the profile: PlayerDataService.Rebuild), the FRANCHISE panel opening with the Market Hall,
selling the company for Stars from this run's Cash, the reset (what goes, what stays), the same plot built again as
a stage-1 farm in the next region (its meadow, trees and sign), the farm working again at once, perks bought with
Stars (growth, baskets, the head start, the fleet, an extra order, the nap), the region and the Stars lifting
everything shipped, and all of it saved across a rejoin.

  luaurun tests/FranchiseSmoke.spec.luau
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
local Fr = service("FranchiseService")
local Farm = service("FarmService")
local Plots = service("PlotService")
local Upg = service("UpgradeService")
local Offline = service("OfflineService")
local Special = service("SpecialService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local Franchise = Engine.require(tree.shared.Data.Franchise)
local Flow = Engine.require(tree.shared.Data.Flow)
local Constants = Engine.require(tree.shared.Constants)
Special.FIRST = 1e9
Special.DAILY = false

-- On their own ----------------------------------------------------------------------------------------------------------
check("a small run: one Star", Franchise.stars(0) == 1 and Franchise.stars(3e6) == 1)
check("100M: ten Stars", Franchise.stars(1e8) == 10)
check(
	"the regions pay more and more",
	Franchise.REGIONS[2].mult > 1 and Franchise.REGIONS[4].mult > Franchise.REGIONS[3].mult
)
check("...and stop at the last", Franchise.region(9).key == "port")
check("perks cost more each level", Franchise.cost("growth", 2) > Franchise.cost("growth", 0))
local fleet = { franchise = { level = 0, perks = { fleet = 2 }, total = 0 } }
check("Quick Fleet: shorter truck trips", Flow.trip({ loadingDock = 1 }, fleet) < Flow.trip({ loadingDock = 1 }) * 0.9)

-- A whole hub -------------------------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local p = Data:Get(player)
local plot = Plots:Plot(player)
local index = plot.index
local MenuC = Engine.require(tree.client.Controllers.MenuController)
local FrC = Engine.require(tree.client.Controllers.FranchiseController)
local Bus = Engine.require(tree.client.UI.Bus)
check("no FRANCHISE button on a new farm", MenuC.refs.buttons.franchise.Visible == false)
check("...and no selling", not Fr:Sell(player))
for _, key in Upgrades.LIST do
	local u = Upgrades[key]
	if u.stage <= 5 and not u.track and key ~= "semi1" and key ~= "semi2" then
		p.owned[key] = 1
	end
end
for _, key in Upgrades.LIST do
	local u = Upgrades[key]
	if type(u.replaces) == "string" then
		p.owned[u.replaces] = nil
	elseif type(u.replaces) == "table" then
		for _, r in u.replaces do
			p.owned[r] = nil
		end
	end
end
p.stage = 5
p.level = 32
p.xp = 1e7
p.stats.earned = 4e8 -- (this run: 20 Stars)
check("the plot rebuilds in place", Data.Rebuild(player) and Plots:Plot(player).index == index)
Engine.advance(1)
check(
	"...a hub on it now",
	plot.items:FindFirstChild("warehouse") ~= nil and plot.items:FindFirstChild("marketHall") ~= nil
)
Economy:Add(player, 1, "test")
Engine.advance(0.5)
check("the Market Hall: the FRANCHISE button", MenuC.refs.buttons.franchise.Visible == true)
Bus.Panel:Fire("franchise")
Engine.advance(0.5)
check("...the panel: twenty Stars for this run", FrC.refs.earn.Text:find("20") ~= nil, FrC.refs.earn.Text)
check("...the six perks", FrC.refs.perks[6].frame.Visible)

-- Selling ------------------------------------------------------------------------------------------------------------------
local gems, level, seeds = p.gems, p.level, 0
p.goldenSeeds = 4
p.animals.chicken = { level = 6, n = 2, fedAt = 0 }
p.street = { day = 0, likes = 7, liked = {} }
p.guide.step = 30
FrC.refs.sell.Activated:Fire()
Engine.advance(0.2)
check("FRANCHISE asks first", p.franchise.level == 0 and FrC.refs.sell.Text:find("SURE") ~= nil)
FrC.refs.sell.Activated:Fire()
Engine.advance(1)
local f = p.franchise
check("sold: Franchise 1, twenty Stars", f.level == 1 and f.stars == 20 and f.total == 20)
check("...the next run counts from now", f.runStart == p.stats.earned)
check("GOES: the buildings, the stage", next(p.owned) == nil and p.stage == 1)
check("...the Cash (back to the start)", p.cash < 1000, p.cash)
check("...the warehouse and the orders", p.flow == nil or (p.flow.racked or 0) == 0)
check("STAYS: Gems, the level, golden seeds", p.gems == gems and p.level == level and p.goldenSeeds == 4)
check("...the animals' levels, the likes", p.animals.chicken.level == 6 and p.street.likes == 7)
check(
	"...the guide starts again (and remembers what it paid)",
	p.guide.step < 30 and (p.guide.paid or 0) >= 29,
	p.guide.step
)
check("the same plot", Plots:Plot(player) and Plots:Plot(player).index == index)
check(
	"...no hub on it",
	plot.items:FindFirstChild("warehouse") == nil and plot.items:FindFirstChild("marketHall") == nil
)
check("...a stage-1 farm again: the shack's soil", #Farm:Tiles(player) == Upgrades.START_SOIL, #Farm:Tiles(player))
local region = plot.items:FindFirstChild("Region")
check(
	"Tropical Coast: palms along the back",
	region and region:GetAttribute("Region") == "tropical" and region:FindFirstChild("Frond") ~= nil
)
check("...the meadow's colour", plot.folder.Meadow.Color == Franchise.REGIONS[2].ground)
check("...the sign", plot.sign.Words.Line.Text:find("TROPICAL") ~= nil, plot.sign.Words.Line.Text)
check("the street hears about it", Engine.lastClientEvent("Toast", "all").args[1]:find("franchised") ~= nil)
check("the panel closed", not FrC.refs.panel.card.Visible)

-- The new farm works ----------------------------------------------------------------------------------------------------------
Engine.moveTo(player, Farm:Tiles(player)[1].Position)
Engine.advance(0.5)
check("plant on the new farm", Farm:Plant(player, 1, "strawberry"))
p.cash = 100
check("buy its first upgrade", Upg:Buy(player, Upgrades.LIST[1]))
local cash0 = p.cash
Economy:Add(player, 1000, "order")
local mult = Franchise.REGIONS[2].mult * (1 + Franchise.STAR_BONUS * 20)
check("everything shipped pays more", p.cash - cash0 == math.floor(1000 * mult + 0.5), p.cash - cash0)
cash0 = p.cash
Economy:Add(player, 1000, "guide")
check("...not gifts", p.cash - cash0 == 1000)

-- Perks ---------------------------------------------------------------------------------------------------------------------
local carry0 = Farm:Carry(player)
check("buy Big Baskets", Fr:Perk(player, "carry") and f.perks.carry == 1 and f.stars == 20 - Franchise.cost("carry", 0))
check("...a bigger basket", Farm:Carry(player) == carry0 + Franchise.PERKS.carry.step)
check("buy the nap", Fr:Perk(player, "nap") and Offline:Hours(p) == Constants.OFFLINE_HOURS + 2)
check("buy Head Start", Fr:Perk(player, "headStart") and f.perks.headStart == 1)
check("buy the Extra Order", Fr:Perk(player, "orderSlot"))
check("...once (max 1)", not Fr:Perk(player, "orderSlot"))
local stars = f.stars
check(
	"not enough Stars: no perk",
	(function()
		f.stars = 0
		local ok = Fr:Perk(player, "growth")
		f.stars = stars
		return not ok
	end)()
)
Engine.advance(0.5)
check("the panel shows the levels", FrC.refs.perks[2].name.Text:find("1/5") ~= nil, FrC.refs.perks[2].name.Text)

-- A second franchise, and saved -------------------------------------------------------------------------------------------------
p.owned.marketHall = 1
p.stats.earned += 1e6
Fr:Sell(player)
Engine.advance(1)
check("Franchise 2: Northern Dairy, the Head Start's Cash", f.level == 2 and p.cash >= Franchise.HEAD_START[2])
check("...pines", plot.items.Region:GetAttribute("Region") == "dairy")
Engine.removePlayer(player)
Engine.advance(1)
check("the meadow goes back when they leave", plot.folder.Meadow.Color ~= Franchise.REGIONS[3].ground)
local again = Engine.addPlayer("Ava", 901)
Engine.advance(2)
local q = Data:Get(again)
check("saved: the franchise and its perks", q.franchise.level == 2 and q.franchise.perks.carry == 1)
local plot2 = Plots:Plot(again)
check(
	"...the region dressed again",
	plot2.items:FindFirstChild("Region") and plot2.items.Region:GetAttribute("Region") == "dairy"
)

local bad = {}
for _, w in Engine.warnings do
	if tostring(w):find("failed") then
		table.insert(bad, tostring(w))
	end
end
check("no failed saves, ticks or rebuilds", #bad == 0, bad[1])
_ = seeds
if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`FranchiseSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
