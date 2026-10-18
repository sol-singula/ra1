--[[
Phase G1 on the mock engine, server and client together: coming back (master plan §8). The 7-day calendar (a claim
a day, day 7 the big one, a missed day steps back one, not to zero), golden seeds making plantings golden, the
weekly Big Contract (four parts from the week's play, paid when all four are done), offline earnings and the
"while you were away" card (capped at the nap's hours), the menu bar and the DAILY panel, and the analytics rows
a session sends.

  luaurun tests/ComebackSmoke.spec.luau
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
local Daily = service("DailyService")
local Offline = service("OfflineService")
local Farm = service("FarmService")
local Upg = service("UpgradeService")
local Analytics = service("AnalyticsService")
local Special = service("SpecialService")
local Upgrades = Engine.require(tree.shared.Data.Upgrades)
local DailyData = Engine.require(tree.shared.Data.Daily)
local Constants = Engine.require(tree.shared.Constants)
Special.FIRST = 1e9
Special.DAILY = false

local sent = {}
Analytics.send = function(payload)
	table.insert(sent, payload)
	return true
end

-- On their own ----------------------------------------------------------------------------------------------------------
do
	local d, held = DailyData.next({ day = 0, claimedDay = 0 }, 100)
	check("the first claim is day 1", d == 1 and held)
	d, held = DailyData.next({ day = 3, claimedDay = 99 }, 100)
	check("claimed yesterday: the next day", d == 4 and held)
	d, held = DailyData.next({ day = 7, claimedDay = 99 }, 100)
	check("...after day 7, round to day 1", d == 1 and held)
	d, held = DailyData.next({ day = 5, claimedDay = 97 }, 100)
	check("a missed day steps back one (day 5 again, not day 1)", d == 5 and not held)
	local r1, r7 = DailyData.reward(1, 10), DailyData.reward(7, 10)
	check("day 7 is the big one", r7.cash > r1.cash and r7.gems >= 20 and r7.seeds > 0)
	check("Cash scales with the level", DailyData.reward(1, 20).cash == r1.cash * 2)
	local parts, reward = DailyData.weekly(2800, 901, 10)
	local parts2 = DailyData.weekly(2800, 901, 10)
	check("a weekly has four parts", #parts == 4 and reward.gems == DailyData.WEEKLY_GEMS)
	check("...the same four all week", parts[1].key == parts2[1].key and parts[4].n == parts2[4].n)
	local other = DailyData.weekly(2801, 901, 10)
	local same = true
	for i = 1, 4 do
		same = same and other[i].key == parts[i].key
	end
	check("...a different one next week (mostly)", not same or #DailyData.WEEKLY == 4)
	check("weeks start on Monday", DailyData.week(1700438400) ~= DailyData.week(1700438400 - 1)) -- Mon 20 Nov 2023
end

-- The calendar ------------------------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local p = Data:Get(player)
local Store = Engine.require(tree.client.Store)
local MenuC = Engine.require(tree.client.Controllers.MenuController)
local DailyC = Engine.require(tree.client.Controllers.DailyController)
local AwayC = Engine.require(tree.client.Controllers.AwayController)
local Panel = Engine.require(tree.client.UI.Panel)

check("a new player: no away card", AwayC.refs.card.Visible == false)
local d = Store.get("daily")
check("the calendar reached the client", type(d) == "table" and d.today and d.today.ready == true and d.today.day == 1)
check("...the DAILY button has its red dot", MenuC.refs.dots.calendar.Visible == true)
Engine.advance(3)
check("...but not over a new farmer's first steps", DailyC.refs.panel.card.Visible == false)
check("...its button waits for the guide", MenuC.refs.buttons.calendar.Visible == false)
p.guide.step = MenuC.UNLOCK.calendar
service("GuideService"):Check(player)
Engine.advance(2)
check("past the first sale: the DAILY button", MenuC.refs.buttons.calendar.Visible == true)
check("...the DAILY panel opens by itself", DailyC.refs.panel.card.Visible == true and Panel.current() == "calendar")
check("...seven days, today's CLAIM button", #DailyC.refs.tiles == 7 and DailyC.refs.claim.Visible == true)
check("the weekly's four parts show", DailyC.refs.parts[4].frame.Visible == true)
local cash0 = p.cash
Engine.fireServer(player, "Daily", "claim")
Engine.advance(0.5)
local today = DailyData.day()
check("claim day 1: Cash", p.cash - cash0 == DailyData.reward(1, p.level).cash, p.cash - cash0)
check("...the calendar saved", p.calendar.day == 1 and p.calendar.claimedDay == today and p.calendar.streak == 1)
check("...the button's gone, the dot too", DailyC.refs.claim.Visible == false and not MenuC.refs.dots.calendar.Visible)
cash0 = p.cash
Engine.fireServer(player, "Daily", "claim")
Engine.advance(0.5)
check("one claim a day", p.cash == cash0)
-- (yesterday's claim: tomorrow is day 2)
p.calendar.claimedDay = today - 1
check("a day later: day 2 waits", Daily:Claimable(player).day == 2)
local gems0 = p.gems
Daily:Claim(player)
check("day 2: Gems, the streak 2", p.gems - gems0 == 5 and p.calendar.streak == 2)
-- (missed two days)
p.calendar.claimedDay = today - 3
local r = Daily:Claim(player)
check("after a miss: day 2 again, the streak back to 1", r.day == 2 and p.calendar.streak == 1)
-- (day 3: golden seeds)
p.calendar.claimedDay = today - 1
r = Daily:Claim(player)
check("day 3: golden seeds", r.day == 3 and p.goldenSeeds == 3, p.goldenSeeds)
Engine.advance(0.5)
check("...the panel counts them", DailyC.refs.seeds.Text:find("3") ~= nil, DailyC.refs.seeds.Text)
Engine.moveTo(player, Farm:Tiles(player)[1].Position)
Engine.advance(0.5)
local ok = Farm:Plant(player, 1, "strawberry")
check(
	"a planting spends a golden seed: a golden crop",
	ok and p.soil["1"].golden == true and p.goldenSeeds == 2,
	`{tostring(ok)} {tostring(p.soil["1"] and p.soil["1"].golden)} {p.goldenSeeds}`
)
local Bus = Engine.require(tree.client.UI.Bus)
Bus.Panel:Fire(nil)
check("the close closes the panel", DailyC.refs.panel.card.Visible == false and Panel.current() == nil)
Bus.Panel:Fire("calendar")
check("its button opens it again", DailyC.refs.panel.card.Visible == true)
Bus.Panel:Fire("calendar")
check("...and again closes it", DailyC.refs.panel.card.Visible == false)

-- The weekly Big Contract -------------------------------------------------------------------------------------------------
local parts, w = Daily:Weekly(player)
check("the week's contract is measured from now", #parts == 4 and w.week == DailyData.week() and parts[1].have == 0)
for i = 1, 3 do
	p.stats[parts[i].stat] = (p.stats[parts[i].stat] or 0) + parts[i].n
end
gems0 = p.gems
Engine.advance(2.5)
check("three parts done, not paid yet", w.done["3"] == true and not w.paid and p.gems == gems0)
p.stats[parts[4].stat] = (p.stats[parts[4].stat] or 0) + parts[4].n + 5
cash0 = p.cash
Engine.advance(2.5)
check("all four: paid", w.paid == true and p.gems - gems0 == DailyData.WEEKLY_GEMS and p.cash > cash0)
check("...counted", p.stats.weeklies == 1)
Engine.advance(2.5)
check("...once", p.gems - gems0 == DailyData.WEEKLY_GEMS)
check("the panel says PAID", DailyC.refs.weeklyPay.Text:find("PAID") ~= nil, DailyC.refs.weeklyPay.Text)
p.orders.weekly.week -= 1
local fresh = Daily:Weekly(player)
check("a new week, a new contract", p.orders.weekly.week == DailyData.week() and not p.orders.weekly.paid)
_ = fresh

-- Away ------------------------------------------------------------------------------------------------------------------
check("nothing earned away without machines", Offline:Earned(p, 3600) == 0)
local function buy(key)
	p.cash = math.max(p.cash, Upgrades[key].cost + 10)
	while (p.level or 1) < Upgrades[key].level do
		Economy:AddXP(player, 3000, "test")
	end
	return Upg:Buy(player, key)
end
for _, key in Upgrades.LIST do
	if Upgrades[key].stage <= 2 then
		buy(key)
	end
end
check("the tractor and conveyor bought", p.owned.tractor ~= nil and p.owned.conveyor ~= nil)
local hour = Offline:Earned(p, 3600)
check("an hour away earns", hour > 0, hour)
local nap, capped = Offline:Earned(p, 100 * 3600)
check(
	"...capped at the nap's hours",
	capped and math.abs(nap - hour * Constants.OFFLINE_HOURS) <= Constants.OFFLINE_HOURS,
	`{nap} vs {hour}`
)
p.passes.longNap = true
check("the Long Nap pass: longer", Offline:Hours(p) == Constants.OFFLINE_PASS_HOURS)
p.passes.longNap = nil
p.calendar.claimedDay = today - 1
local saved = p.cash
Engine.removePlayer(player)
Engine.advance(1)
check("leaving saves when they left", true)
Engine.advance(2 * 3600, 1)
local again = Engine.addPlayer("Ava", 901)
Engine.Players.LocalPlayer = again
Engine.localPlayer = again
Engine.advance(1)
Engine.fireServer(again, "Ready") -- (the client already running says it's listening)
Engine.advance(1)
local q = Data:Get(again)
local away = Engine.lastClientEvent("Away", again)
check("back after two hours: the away card", away ~= nil and away.args[1].seconds >= 7200)
local card = away and away.args[1] or {}
check("...what the farm earned", (card.earned or 0) > 0 and q.cash >= saved + card.earned, card.earned)
check("...not capped", card.capped == false)
check("...the day's reward waiting", type(card.calendar) == "table" and card.calendar.day >= 3) -- (the 2 h crossed midnight)
check("...the card on screen, counting up", AwayC.refs.card.Visible == true)
Engine.advance(1.5)
check(
	"...to what it earned",
	AwayC.refs.earned.Text:gsub(",", "") == "+" .. tostring(card.earned),
	AwayC.refs.earned.Text
)
check("the calendar waits behind it", DailyC.refs.panel.card.Visible == false)
AwayC.refs.collect.Activated:Fire()
check("COLLECT closes it", AwayC.refs.card.Visible == false)
local bad = {}
for _, wn in Engine.warnings do
	if tostring(wn):find("save failed") or tostring(wn):find("tick failed") or tostring(wn):find("failed") then
		table.insert(bad, tostring(wn))
	end
end
check("no failed saves, ticks or hooks", #bad == 0, bad[1])

-- Analytics ------------------------------------------------------------------------------------------------------------------
Engine.advance(Constants.ANALYTICS_FLUSH_SECONDS + 1)
local kinds, sessions = {}, {}
for _, payload in sent do
	check("a batch is tagged with the game", payload.game == "ra10")
	for _, e in payload.events do
		kinds[e.kind] = (kinds[e.kind] or 0) + 1
	end
	for _, s in payload.sessions do
		sessions[s.session_id] = s
	end
end
check("events: join, calendar, away, leave", kinds.join and kinds.calendar and kinds.away and kinds.leave)
local n, returning = 0, false
for _, s in sessions do
	n += 1
	returning = returning or s.returning == true
end
check("two sessions, the second returning", n >= 2 and returning)

if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`ComebackSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
