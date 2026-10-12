--[[
Server smoke test: boots the real server scripts on the mock engine and plays the solo loop with two players:
join, blast bugs on Dust, get ore and coins, forge a blaster (odds, timers, Finish Now, take out), hold, power up
and sell blasters, beat the Dust King, unlock Ice, travel by pads, goals, playtime gifts, the new-player boost,
passes and products, and leaving. Fails on any script error or broken expectation.

  luaurun tests/ServerSmoke.spec.luau                 (from the game folder)
  luaurun tests/ServerSmoke.spec.luau nodatastore     (Studio-without-API-access fallback)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local noDataStore = ARGS[1] == "nodatastore"
Engine.dataStoreFails = noDataStore

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
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Economy = service("EconomyService")
local Planet = service("PlanetService")
local Blaster = service("BlasterService")
local Mob = service("MobService")
local Boss = service("BossService")
local Combat = service("CombatService")
local Forge = service("ForgeService")
local Goal = service("GoalService")
local Playtime = service("PlaytimeService")
local Raid = service("RaidService")
local Leaderboard = service("LeaderboardService")
-- game log posts are captured here instead of going to Discord
local GameLog = service("GameLogService")
local gameLogs = {} -- every event sent, flattened
GameLog.send = function(payload)
	for _, e in payload.events do
		table.insert(gameLogs, e)
	end
	return true
end
local function logged(text)
	for _, e in gameLogs do
		if tostring(e.title):find(text, 1, true) then
			return e
		end
	end
	return nil
end
local ShopData = Engine.require(tree.shared.Data.Shop)
local Formulas = Engine.require(tree.shared.Formulas)
local Constants = Engine.require(tree.shared.Constants)
local Planets = Engine.require(tree.shared.Data.Planets)
local World = Engine.require(tree.server.World.WorldBuilder)
local layout = World.layout
local MarketplaceService = Engine.game:GetService("MarketplaceService")
_ = ShopData

check(
	"world built: hub, 8 planets, mobs folder",
	layout.hub ~= nil and #layout.planets == 8 and Engine.workspace:FindFirstChild("Mobs") ~= nil
)
check(
	"every planet has a boss waiting",
	(function()
		for i = 1, 8 do
			if not Boss.bosses[i] then
				return false
			end
		end
		return true
	end)()
)

local function join(name, id)
	local p = Engine.addPlayer(name, id)
	Engine.makeCharacter(p)
	Engine.advance(0.2)
	Engine.fireServer(p, "Ready")
	Engine.advance(0.3)
	return p
end
local function go(p, pos)
	Engine.moveTo(p, pos + Vector3.new(0, 3, 0))
	Engine.advance(0.25)
end
local function face(p, target)
	Engine.moveTo(p, p.Character.HumanoidRootPart.Position, target + Vector3.new(0, 3, 0))
end

-- Join ------------------------------------------------------------------------------------------------------
local a = join("Ava", 1001)
local pa = Data:Get(a)
check("profile loaded", pa ~= nil)
check("unsaved only without DataStore", (pa._noSave == true) == noDataStore)
check("starts with one Dust Zapper in hand", #pa.blasters == 1 and pa.equipped == pa.blasters[1].uid)
check(
	"blaster tool in the character",
	a.Character:FindFirstChildOfClass("Tool") ~= nil
		and a.Character:FindFirstChildOfClass("Tool"):GetAttribute("Kind") == "blaster"
)
check("new players get the 2x boost", pa.newBoostLeft == Constants.NEW_PLAYER_BOOST_SECONDS)
check("in the hub", Planet:Where(a) == "HUB")
check("only Dust is open", Planet:Unlocked(a) == 1)
check("goal 1 is blast 5 bugs", Goal:View(a).index == 1 and Goal:View(a).text:find("Blast 5"))
check("a raid countdown is running", Raid:NextAt() > Engine.workspace:GetServerTimeNow())
check("leaderstats", a:FindFirstChild("leaderstats") ~= nil)

-- GO pad to Dust ----------------------------------------------------------------------------------------------
local dust = layout.planets[1]
go(a, layout.hub.goPads[1].center)
Engine.advance(0.3)
check(
	"the Dust GO pad takes you to Dust",
	Planet:Where(a) == "DUST" and World.planetAt(a.Character.HumanoidRootPart.Position) == dust
)
check("the Ice GO pad is locked", not Planet:Travel(a, "ICE") and Planet:Where(a) == "DUST")
Engine.advance(2.5)
local bugs = 0
for _, e in Mob.targets do
	if not e.boss and e.island == dust then
		bugs += 1
	end
end
check("bugs appear on Dust", bugs == Constants.BUGS_PER_PLANET, bugs)

-- Blast -------------------------------------------------------------------------------------------------------
local function nearestBug(p)
	local pos = p.Character.HumanoidRootPart.Position
	local best, bestD
	for _, e in Mob.targets do
		if not e.boss and e.model.Parent then
			local d = (e.pos - pos).Magnitude
			if not bestD or d < bestD then
				best, bestD = e, d
			end
		end
	end
	return best
end
local bug = nearestBug(a)
go(a, bug.pos + Vector3.new(6, 0, 0))
face(a, bug.pos)
local hp0 = bug.hp
Engine.fireServer(a, "Blast", bug.id)
Engine.advance(0.1)
check("a blast hurts the bug", bug.hp < hp0, bug.hp - hp0)
check("everyone sees the beam", Engine.lastClientEvent("Beam") ~= nil)
check("damage popup", Engine.lastClientEvent("Popup", a) ~= nil)
Engine.fireServer(a, "Blast", bug.id)
check("the cooldown blocks a second shot right away", bug.hp == hp0 - Formulas.blasterDamage(pa.blasters[1]))
-- walk right at bugs and blast them until 5 are down
local coins0, ore0 = pa.coins, pa.ore.DUST
local shots = 0
while pa.stats.bugs < 5 and shots < 400 do
	local b = nearestBug(a)
	if b then
		go(a, b.pos + Vector3.new(5, 0, 0))
		face(a, b.pos)
		Engine.fireServer(a, "Blast", b.id)
	end
	Engine.advance(Constants.BLAST_COOLDOWN + 0.05)
	shots += 1
end
check("5 bugs blasted", pa.stats.bugs >= 5, pa.stats.bugs)
check("bugs drop ore", pa.ore.DUST > ore0, pa.ore.DUST)
check(
	"bugs drop coins, doubled by the new-player boost",
	pa.coins >= coins0 + 5 * Planets.list[1].bugCoins * 2,
	pa.coins
)
check(
	"bugs come back",
	(function()
		Engine.advance(Constants.BUG_RESPAWN_SECONDS + 1.5)
		local n = 0
		for _, e in Mob.targets do
			if not e.boss and e.island == dust then
				n += 1
			end
		end
		return n == Constants.BUGS_PER_PLANET
	end)()
)
Engine.advance(1.1)
check("goal 1 done: coins paid, goal 2 is the forge", pa.goal == 2 and Goal:View(a).text:find("Forge"))

-- Forge -------------------------------------------------------------------------------------------------------
go(a, layout.spawn.Position)
Engine.fireServer(a, "Travel", "HUB")
Engine.advance(0.2)
check("Travel HUB", Planet:Where(a) == "HUB")
pa.ore.DUST = 0
Engine.fireServer(a, "Forge", "small", "DUST")
Engine.advance(0.1)
check("no forge without ore", pa.forge[1] == nil)
pa.ore.DUST = 60
Economy:PushAll(a)
Engine.fireServer(a, "Forge", "small", "DUST")
Engine.advance(0.1)
check("a small forge starts and eats 10 ore", pa.forge[1] ~= nil and pa.ore.DUST == 50)
check("the roll is made at the start", pa.forge[1].rec ~= nil and pa.forge[1].rec.rarity ~= nil)
Engine.fireServer(a, "Forge", "small", "DUST")
Engine.advance(0.1)
check("one slot without Triple Forge", pa.forge[2] == nil)
Engine.fireServer(a, "ClaimForge", 1)
Engine.advance(0.1)
check("can't take it out early", #pa.blasters == 1)
local view = Forge:View(a)
check("the view shows the timer and odds", view.slots[1].left > 0 and #view.tiers == 3 and #view.tiers[1].odds == 4)
check(
	"odds add to 100",
	(function()
		for _, tier in Constants.FORGE_TIERS do
			local sum = 0
			for _, row in Constants.FORGE_ODDS[tier.key] do
				sum += row[2]
			end
			if math.abs(sum - 100) > 0.001 then
				return false
			end
		end
		return true
	end)()
)
-- Finish Now: the product is free in Studio
Engine.fireServer(a, "FinishNow", 1)
Engine.advance(0.1)
check("Finish Now (Studio, free) finishes the slot", Forge:View(a).slots[1].ready == true)
Engine.fireServer(a, "ClaimForge", 1)
Engine.advance(0.1)
check("took the blaster out", #pa.blasters == 2 and pa.forge[1] == nil and pa.stats.forged == 1)
check("the reveal was sent", Engine.lastClientEvent("Forged", a) ~= nil)
-- a timed forge really finishes
Engine.fireServer(a, "Forge", "small", "DUST")
Engine.advance(Constants.FORGE_TIERS[1].seconds + 1.5)
check("the forge finishes on its own", Forge:View(a).slots[1].ready == true)
Engine.fireServer(a, "ClaimForge", 1)
Engine.advance(0.2)
check("goal 2 done", pa.goal >= 3)

-- Bag: hold, power up, sell ----------------------------------------------------------------------------------------
local other
for _, rec in pa.blasters do
	if rec.uid ~= pa.equipped then
		other = rec
	end
end
Engine.fireServer(a, "Equip", other.uid)
Engine.advance(0.1)
check(
	"HOLD swaps the blaster in hand",
	pa.equipped == other.uid and a.Character:FindFirstChildOfClass("Tool"):GetAttribute("Uid") == other.uid
)
local cost = Formulas.powerUpCost(other)
pa.coins = cost
Engine.fireServer(a, "PowerUp", other.uid)
Engine.advance(0.1)
check("Power Up costs coins and adds a level", other.lv == 1 and pa.coins == 0 and pa.stats.powerUps == 1)
local dmgBefore = Formulas.blasterDamage(other)
check(
	"Power Up raises damage",
	dmgBefore > Formulas.blasterDamage({ rarity = other.rarity, planet = other.planet, roll = other.roll, lv = 0 })
)
local n = #pa.blasters
Engine.fireServer(a, "Sell", other.uid)
Engine.advance(0.1)
check("Sell pays coins and swaps to the best", #pa.blasters == n - 1 and pa.coins > 0 and pa.equipped ~= other.uid)
Engine.fireServer(a, "Sell", pa.equipped)
Engine.advance(0.1)
check("can't sell your last blaster", #pa.blasters == 1)

-- Boss ---------------------------------------------------------------------------------------------------------
Planet:Travel(a, "DUST")
local boss = Boss.bosses[1]
check(
	"the Dust King waits in the yard",
	boss ~= nil and boss.state == "waiting" and boss.hp == Formulas.bossHealth(Planets.list[1], 1)
)
go(a, dust.yardCenter)
Engine.advance(0.5)
check("walking into the yard wakes the boss", boss.state == "fighting")
-- a big blaster, so the fight is short
pa.blasters[1].lv = Constants.POWER_UP_LEVELS
Blaster:Push(a)
local coinsB, oreB, gemsB = pa.coins, pa.ore.DUST, pa.gems
local shotsB = 0
while Boss.bosses[1] == boss and shotsB < 2000 do
	go(a, boss.pos + Vector3.new(10, 0, 0))
	face(a, boss.pos)
	Engine.fireServer(a, "Blast", boss.id)
	Engine.advance(Constants.BLAST_COOLDOWN + 0.05)
	shotsB += 1
end
check("the Dust King falls", Boss.bosses[1] ~= boss, shotsB)
check(
	"boss loot: ore, coins, a gem",
	pa.ore.DUST > oreB + 5 and pa.coins > coinsB and pa.gems == gemsB + Constants.BOSS_GEMS
)
check("Ice opens", Planet:Unlocked(a) == 2 and pa.beaten.DUST == 1)
check("bosses counted", pa.stats.bosses == 1 and a.leaderstats.Bosses.Value == 1)
check("the server hears about it", Engine.lastClientEvent("Announce") ~= nil)
Engine.advance(1.1)
check("goal 3 (beat the Dust King) done", pa.goal >= 4)
Engine.advance(13)
check("the boss comes back", Boss.bosses[1] ~= nil and Boss.bosses[1] ~= boss)
-- rage: a boss below half health fires balls that knock you down
local boss2 = Boss.bosses[1]
go(a, dust.yardCenter)
Engine.advance(0.3)
boss2.hp = math.floor(boss2.maxHp * 0.3)
boss2.lastBall = 0
Engine.moveTo(a, boss2.pos + Vector3.new(8, 3, 0))
Engine.advance(0.15)
check("a raging boss fires balls", Engine.workspace.Fx:FindFirstChild("BossBall") ~= nil)
-- stand in the ball's path
Engine.advance(1)
check(
	"a ball knocks you down (no damage, no death)",
	Boss:IsDown(a) and a.Character.Humanoid.WalkSpeed == 0 and a.Character.Humanoid.Health == 100
)
Engine.fireServer(a, "Travel", "HUB") -- out of the yard, so no more balls come
Engine.advance(Constants.BOSS_DOWN_SECONDS + 0.5)
check("you get up again", not Boss:IsDown(a) and a.Character.Humanoid.WalkSpeed > 0)
-- leaving the yard resets the boss
Engine.advance(Constants.BOSS_RESET_SECONDS + 1)
check("a left-alone boss heals up", boss2.state == "waiting" and boss2.hp == boss2.maxHp)

-- Ice: harder bugs, and the Ice GO pad works now --------------------------------------------------------------------
check("Travel ICE works now", Planet:Travel(a, "ICE") and Planet:Where(a) == "ICE")
Engine.advance(2)
local iceBug = nearestBug(a)
check("Ice bugs have Ice health", iceBug ~= nil and iceBug.maxHp == Formulas.bugHealth(Planets.list[2], 1))
Engine.fireServer(a, "Forge", "small", "SUN")
Engine.advance(0.1)
check("can't forge with a locked planet's ore", pa.forge[1] == nil)

-- Two players: health scales with the crowd ----------------------------------------------------------------------
local b = join("Ben", 1002)
local pb = Data:Get(b)
Planet:Travel(b, "DUST")
Planet:Travel(a, "DUST")
Engine.advance(1)
local shared = nearestBug(a)
go(b, shared.pos + Vector3.new(-5, 0, 0))
go(a, shared.pos + Vector3.new(5, 0, 0))
Engine.advance(0.5)
check("two players near: bug health scales", shared.maxHp == Formulas.bugHealth(Planets.list[1], 2), shared.maxHp)
face(a, shared.pos)
face(b, shared.pos)
local c0 = pb.coins
shared.hp = 1
Engine.fireServer(b, "Blast", shared.id)
Engine.advance(0.1)
check("Ben's kill pays Ben", pb.coins > c0 and pb.stats.bugs == 1)

-- Falling off is safe ----------------------------------------------------------------------------------------------
Engine.moveTo(a, Vector3.new(80, -60, 80))
Engine.advance(0.4)
check("falling into space sends you home", Planet:Where(a) == "HUB" and a.Character.HumanoidRootPart.Position.Y > 0)

-- Passes and products -----------------------------------------------------------------------------------------------
Engine.fireServer(a, "Purchase", "pass", "TRIPLE")
Engine.advance(0.1)
check("Triple Forge (free in Studio) gives 3 slots", pa.passes.TRIPLE == true and Forge:Slots(a) == 3)
Engine.advance(1)
Engine.fireServer(a, "Purchase", "product", "GEMS_S")
Engine.advance(0.1)
check("a gem pack adds gems", pa.gems >= 50)
Engine.advance(1)
Engine.fireServer(a, "Purchase", "product", "LUCK")
Engine.advance(0.1)
check("Luck Elixir runs 15 minutes", Forge:Luck(a) > 1 and Forge:View(a).luck == true)
Engine.advance(1)
Engine.fireServer(a, "Purchase", "pass", "AUTO")
Engine.advance(0.1)
Planet:Travel(a, "DUST")
Engine.advance(2)
local bugsBefore = pa.stats.bugs
local target = nearestBug(a)
go(a, target.pos + Vector3.new(4, 0, 0))
Engine.advance(4)
check("Auto Blast fires by itself", pa.stats.bugs > bugsBefore, pa.stats.bugs - bugsBefore)
MarketplaceService.ProcessReceipt({ PlayerId = a.UserId, ProductId = 0, PurchaseId = "R1" })
check("a receipt is remembered", table.find(pa.receipts, "R1") ~= nil)
local gemsNow = pa.gems
MarketplaceService.ProcessReceipt({ PlayerId = a.UserId, ProductId = 0, PurchaseId = "R1" })
check("same receipt never pays twice", pa.gems == gemsNow)

-- Playtime gifts and the boost ---------------------------------------------------------------------------------------
pa.playtime = { day = Formulas.day(Engine.globals.os.time()), seconds = 58, given = 0 }
local coinsG = pa.coins
Engine.advance(3)
check("1 minute gift: coins", pa.playtime.given == 1 and pa.coins > coinsG)
pa.playtime.seconds = 298
local nB = #pa.blasters
Engine.advance(3)
check("5 minute gift: a blaster", pa.playtime.given == 3 and #pa.blasters == nB + 1)
pa.newBoostLeft = 2
Engine.advance(3)
check("the boost runs out", pa.newBoostLeft == 0 and Economy:CoinMult(a) == 1)

-- The raid --------------------------------------------------------------------------------------------------------
do
	local hubPad = layout.hub.raidPad
	check("the portal is shut between raids", hubPad.Transparency == 1 and Raid.state == "waiting")
	check("can't jump in while it's shut", not Raid:Join(a))
	-- open it now
	Raid.state = "waiting"
	local RaidC = Engine.require(tree.server.Services.RaidService)
	_ = RaidC
	Planet:Travel(a, "HUB")
	Planet:Travel(b, "HUB")
	Engine.advance(0.2)
	-- (force the clock)
	local nowT = Engine.workspace:GetServerTimeNow()
	for _ = 1, 3 do
		Engine.advance(0.1)
	end
	Raid.Start_(Raid)
	Engine.advance(0.2)
	check(
		"the raid opens: beam, pad, boss, event",
		hubPad.Transparency < 1 and Raid.state == "fighting" and Engine.lastClientEvent("Event") ~= nil
	)
	check("everyone is told", Engine.lastClientEvent("Alert", b) ~= nil)
	check("robots fill a quiet raid", Engine.workspace.Map.Hub.Arena:FindFirstChild("Robot_1") ~= nil)
	-- step on the RAID pad
	go(a, Vector3.new(0, 7, 0))
	Engine.advance(0.3)
	check(
		"the RAID pad takes you to the arena",
		Planet:Where(a) == "RAID" and World.inArena(a.Character.HumanoidRootPart.Position)
	)
	check("joining counts", pa.stats.raids == 1)
	Engine.fireServer(b, "Travel", "RAID")
	Engine.advance(0.3)
	check("Travel RAID works too", Planet:Where(b) == "RAID")
	local star
	for _, e in Mob.targets do
		if e.raid then
			star = e
		end
	end
	check("the Star Eater is there with a health bar", star ~= nil and star.fill ~= nil)
	local hpStart = star.hp
	-- phase 1: blast
	go(a, star.pos + Vector3.new(16, 0, 0))
	face(a, star.pos)
	Engine.advance(Constants.BLAST_COOLDOWN + 0.1)
	Engine.fireServer(a, "Blast", star.id)
	Engine.advance(0.1)
	check("blasting the Star Eater hurts it and counts your damage", star.hp < hpStart and (star.damage[a] or 0) > 0)
	-- phase 2: shields
	star.hp = math.floor(star.maxHp * 0.6)
	Engine.advance(0.3)
	check(
		"below 66%: shields up, plates lit",
		star.shielded == true and layout.arena.plates[1].lines[2].Text == "STAND HERE!"
	)
	local hpS = star.hp
	Engine.advance(Constants.BLAST_COOLDOWN + 0.1)
	Engine.fireServer(a, "Blast", star.id)
	Engine.advance(0.1)
	check("a shielded boss takes no damage", star.hp == hpS)
	-- the robots walk to the plates and hold them; a second later the shield breaks
	Engine.advance(8)
	check("robots on the plates break the shield", star.shielded == false and star.shieldDone == true)
	-- phase 3: rage
	star.hp = math.floor(star.maxHp * 0.3)
	star.lastBall = 0
	go(a, star.pos + Vector3.new(14, 0, 0))
	Engine.advance(0.3)
	check("below 33%: balls", Engine.workspace.Fx:FindFirstChild("RaidBall") ~= nil)
	check("too late to join at half health", not Raid:IsOpen())
	-- finish it
	star.hp = 1
	local gemsR, nR = pa.gems, #pa.blasters
	Engine.advance(Constants.BLAST_COOLDOWN + 0.1)
	face(a, star.pos)
	Engine.fireServer(a, "Blast", star.id)
	Engine.advance(0.3)
	check("the Star Eater falls", Raid.state == "waiting")
	check("raid loot: gems and a top-5 blaster", pa.gems > gemsR and #pa.blasters == nR + 1)
	check("the sky board goes up", layout.hub.skyBoardPost:FindFirstChild("SkyBoard") ~= nil)
	check("the server hears about the MVP", Engine.lastClientEvent("Announce") ~= nil)
	check("the portal shuts", hubPad.Transparency == 1 and Raid:NextAt() > Engine.workspace:GetServerTimeNow())
	Engine.advance(4.5)
	check("players are sent home after", Planet:Where(a) == "HUB")
	-- the timeout path: it flies away with half loot
	Raid.Start_(Raid)
	Engine.advance(0.2)
	Engine.fireServer(a, "Travel", "RAID")
	Engine.advance(0.3)
	for _, e in Mob.targets do
		if e.raid then
			star = e
		end
	end
	go(a, star.pos + Vector3.new(16, 0, 0))
	face(a, star.pos)
	Engine.advance(Constants.BLAST_COOLDOWN + 0.1)
	Engine.fireServer(a, "Blast", star.id)
	Engine.advance(0.1)
	local gemsT = pa.gems
	-- (pull the clock forward)
	Engine.advance(Constants.RAID_SECONDS + 1)
	check("the clock runs out: it flies away, half loot", Raid.state == "waiting" and pa.gems >= gemsT + 1)
	_ = nowT
end

-- Rebirth and Nightmare -------------------------------------------------------------------------------------------
local Rebirth = service("RebirthService")
do
	check("no rebirth before all 8 bosses", not Rebirth:CanRebirth(a))
	Engine.fireServer(a, "Rebirth")
	Engine.advance(0.1)
	check("the pad says no", pa.rebirths == 0)
	for _, p in Planets.list do
		pa.beaten[p.key] = 1
	end
	check("all 8 beaten: rebirth is open", Rebirth:CanRebirth(a) and Planet:Unlocked(a) == 8)
	local nB = #pa.blasters
	local plain = {
		rarity = "Common",
		planet = "DUST",
		roll = { dmg = "plain", spd = "plain", luck = "plain", gem = "plain" },
		lv = 0,
	}
	local dmg0 = Combat:Damage(a, plain)
	Engine.advance(1.1) -- (the Rebirth event allows one a second)
	Engine.fireServer(a, "Rebirth")
	Engine.advance(0.2)
	check(
		"reborn: a star, planets locked again, blasters kept",
		pa.rebirths == 1 and Planet:Unlocked(a) == 1 and #pa.blasters == nB
	)
	check("a star means more damage", Combat:Damage(a, plain) > dmg0 * 1.2)
	check("stars over your head", a.Character.Head:FindFirstChild("StarTag") ~= nil)
	check("everyone hears", Engine.lastClientEvent("Announce") ~= nil)
	Engine.advance(1)
	Engine.fireServer(a, "Nightmare")
	Engine.advance(0.1)
	check("Nightmare on: damage divided by 10", Rebirth:IsNightmare(a) and Combat:Damage(a, plain) < dmg0 * 0.2)
	check("Nightmare: better forge luck", Forge:Luck(a) >= Constants.NIGHTMARE_LUCK)
	Engine.advance(1)
	Engine.fireServer(a, "Nightmare")
	Engine.advance(0.1)
	check("Nightmare off again", not Rebirth:IsNightmare(a))
end

-- Daily quests, the daily gift, rerolls ----------------------------------------------------------------------------
local Quest = service("QuestService")
do
	local view = Quest:View(a)
	check("three daily quests", #view == 3 and view[1].gems > 0)
	check(
		"the same three in every server",
		Quest.todays(123)[1].text == Quest.todays(123)[1].text and #Quest.todays(123) == 3
	)
	-- finish one by hand: find a bugs quest, or make the first one done
	local gemsQ = pa.gems
	local q = pa.quests
	local first = Quest.todays(q.day)[1]
	pa.stats[first.kind] = (q.start[first.kind] or 0) + first.target
	Engine.advance(2.5)
	check("a finished quest pays gems", pa.gems == gemsQ + first.gems and Quest:View(a)[1].done == true)
	-- the daily gift
	local dv = Quest:DailyView(a)
	check("the daily gift is waiting on day 1", dv.canClaim and dv.nextDay == 1 and #dv.gifts == 7)
	local coinsD = pa.coins
	Engine.fireServer(a, "ClaimDaily")
	Engine.advance(0.1)
	check("day 1 gift: coins", pa.daily.streak == 1 and pa.coins > coinsD)
	Engine.advance(1.1)
	Engine.fireServer(a, "ClaimDaily")
	Engine.advance(0.1)
	check("only one gift a day", pa.daily.streak == 1)
	-- reroll a stat
	local rec = pa.blasters[1]
	pa.gems = Constants.REROLL_GEMS
	Economy:PushAll(a)
	Engine.fireServer(a, "Reroll", rec.uid, "dmg")
	Engine.advance(0.1)
	check("a reroll costs gems and sets a grade", pa.gems == 0 and Constants.ROLL_MULT[rec.roll.dmg] ~= nil)
	Engine.advance(1)
	Engine.fireServer(a, "Reroll", rec.uid, "dmg")
	Engine.advance(0.1)
	check("no reroll without gems", pa.gems == 0)
end

-- The Trade Plaza -----------------------------------------------------------------------------------------------------
local Trade = service("TradeService")
do
	-- Ben is back with a blaster to sell
	Engine.removePlayer(b)
	Engine.advance(0.5)
	b = join("Ben", 1002)
	pb = Data:Get(b)
	Engine.advance(0.5)
	local extra = Blaster:Grant(b, {
		rarity = "Rare",
		planet = "DUST",
		roll = { dmg = "shiny", spd = "plain", luck = "plain", gem = "plain" },
		lv = 0,
	}, "test")
	local nBen = #pb.blasters
	Engine.fireServer(b, "ListStall", 3, extra.uid, 25)
	Engine.advance(0.1)
	check(
		"a blaster goes on the stall and out of the bag",
		Trade.stalls[3] ~= nil and Trade.stalls[3].seller == b and #pb.blasters == nBen - 1
	)
	check("the stall sign shows it", layout.stalls[3].lines[2].Text:find("25 gems", 1, true) ~= nil)
	check("everyone sees the stalls", Trade:View()[3].price == 25 and Trade:View()[3].seller == "Ben")
	Engine.fireServer(b, "ListStall", 4, pb.blasters[1].uid, 25)
	Engine.advance(0.1)
	check("one stall per player", Trade.stalls[4] == nil)
	-- Ava buys it
	pa.gems = 10
	Economy:PushAll(a)
	Engine.fireServer(a, "BuyStall", 3)
	Engine.advance(0.1)
	check("no gems, no sale", Trade.stalls[3] ~= nil and pa.gems == 10)
	pa.gems = 30
	Economy:PushAll(a)
	local gemsBen, nAva = pb.gems, #pa.blasters
	Engine.advance(1)
	Engine.fireServer(a, "BuyStall", 3)
	Engine.advance(0.1)
	check("the sale: buyer pays, blaster moves", Trade.stalls[3] == nil and pa.gems == 5 and #pa.blasters == nAva + 1)
	check(
		"the seller gets 90%, the Plaza keeps 10%",
		pb.gems == gemsBen + 22 or pb.gems == gemsBen + 23,
		pb.gems - gemsBen
	)
	check("everyone hears about the sale", Engine.lastClientEvent("Announce") ~= nil)
	-- take back
	local extra2 = Blaster:Grant(b, {
		rarity = "Common",
		planet = "DUST",
		roll = { dmg = "plain", spd = "plain", luck = "plain", gem = "plain" },
		lv = 0,
	}, "test")
	Engine.advance(1)
	Engine.fireServer(b, "ListStall", 5, extra2.uid, 5)
	Engine.advance(0.1)
	local nB2 = #pb.blasters
	Engine.advance(1)
	Engine.fireServer(b, "Unlist", 5)
	Engine.advance(0.1)
	check("take it back", Trade.stalls[5] == nil and #pb.blasters == nB2 + 1)
	-- policy: a player who may not trade can't list
	Engine.policy = { IsPaidItemTradingAllowed = false }
	local cPlayer = join("Cat", 1003)
	Engine.advance(0.5)
	local pc = Data:Get(cPlayer)
	Engine.fireServer(cPlayer, "ListStall", 6, pc.blasters[1].uid, 5)
	Engine.advance(0.1)
	check("no trading for players whose policy says no", Trade.stalls[6] == nil and not Trade:CanTrade(cPlayer))
	Engine.policy = { IsPaidItemTradingAllowed = true }
	-- a listed blaster comes home when the seller leaves
	Engine.advance(1)
	Engine.fireServer(b, "ListStall", 7, extra2.uid, 5)
	Engine.advance(0.1)
	local keep = #pb.blasters
	Engine.removePlayer(b)
	Engine.advance(0.3)
	check("leaving returns the listed blaster to the bag", Trade.stalls[7] == nil and #pb.blasters == keep + 1)
	Engine.removePlayer(cPlayer)
	Engine.advance(0.3)
end

-- Booth Street ----------------------------------------------------------------------------------------------------------
local Booth = service("BoothService")
do
	b = join("Ben", 1002)
	pb = Data:Get(b)
	Engine.advance(0.5)
	Engine.fireServer(b, "ClaimBooth", 2)
	Engine.advance(0.1)
	check("front booths need Booth Rank", Booth.booths[2] == nil)
	Engine.advance(1)
	Engine.fireServer(b, "ClaimBooth", 9)
	Engine.advance(0.1)
	check("claim a booth", Booth.booths[9] ~= nil and Booth.booths[9].owner == b)
	Engine.assets[777001] = { Name = "Cool Shirt", AssetTypeId = 11, PriceInRobux = 5, Creator = { Id = 1002 } }
	Engine.assets[777002] = { Name = "Someone else's hat", AssetTypeId = 8, PriceInRobux = 50, Creator = { Id = 999 } }
	Engine.assets[777003] = { Name = "A gamepass", AssetTypeId = 34, PriceInRobux = 50, Creator = { Id = 1002 } }
	Engine.fireServer(b, "SetBooth", 9, 777002, "hi")
	Engine.advance(0.1)
	check("only your own items", Booth.booths[9].assetId == nil)
	Engine.advance(1.1)
	Engine.fireServer(b, "SetBooth", 9, 777003, "hi")
	Engine.advance(0.1)
	check("only clothes and accessories", Booth.booths[9].assetId == nil)
	Engine.advance(1.1)
	Engine.fireServer(b, "SetBooth", 9, 777001, "buy my badword shirt")
	Engine.advance(0.1)
	check(
		"the booth shows your shirt, message filtered",
		Booth.booths[9].assetId == 777001
			and Booth.booths[9].message == "buy my #### shirt"
			and layout.booths[9].lines[1].Text == "Cool Shirt"
	)
	Engine.fireServer(a, "BuyBooth", 9)
	Engine.advance(0.1)
	local last = Engine.prompted[#Engine.prompted]
	check(
		"buying opens Roblox's purchase prompt for the item",
		last and last.kind == "asset" and last.id == 777001 and last.player == a
	)
	Engine.fireServer(b, "BuyBooth", 9)
	Engine.advance(0.1)
	check("you can't buy from your own booth", Engine.prompted[#Engine.prompted] == last)
	Engine.removePlayer(b)
	Engine.advance(0.3)
	check("leaving frees the booth", Booth.booths[9] == nil and layout.booths[9].lines[1].Text == "EMPTY BOOTH")
end

-- Pets and eggs ------------------------------------------------------------------------------------------------------
local Pet = service("PetService")
do
	local PetsData = Engine.require(tree.shared.Data.Pets)
	for _, e in PetsData.Eggs do
		local sum = 0
		for _, row in e.odds do
			sum += row[2]
		end
		check(`{e.name} odds add to 100`, math.abs(sum - 100) < 1e-6)
	end
	pa.gems = 0
	Economy:PushAll(a)
	Engine.fireServer(a, "BuyEgg", "STAR")
	Engine.advance(0.1)
	check("no egg without gems", #pa.pets == 0)
	pa.gems = 25
	Economy:PushAll(a)
	Engine.advance(1)
	local plain = {
		rarity = "Common",
		planet = "DUST",
		roll = { dmg = "plain", spd = "plain", luck = "plain", gem = "plain" },
		lv = 0,
	}
	local dmgNoPet = Combat:Damage(a, plain)
	Engine.fireServer(a, "BuyEgg", "STAR")
	Engine.advance(0.3)
	check("an egg hatches a pet, out at once", #pa.pets == 1 and #pa.petsOut == 1 and pa.gems == 0)
	check("the pet floats in the world", Engine.workspace.Pets:FindFirstChildOfClass("Model") ~= nil)
	check("a pet adds damage", Combat:Damage(a, plain) > dmgNoPet)
	Engine.fireServer(a, "EquipPet", pa.pets[1].uid, false)
	Engine.advance(0.1)
	check("put away", #pa.petsOut == 0 and Engine.workspace.Pets:FindFirstChildOfClass("Model") == nil)
	Engine.fireServer(a, "EquipPet", pa.pets[1].uid, true)
	Engine.advance(0.1)
	Pet:Grant(a, PetsData.byId.SUNFOX, "test")
	check("one slot: the newest pet waits in the bag", #pa.petsOut == 1)
	Engine.advance(1)
	Engine.fireServer(a, "Purchase", "pass", "PETSLOT")
	Engine.advance(0.2)
	Engine.fireServer(a, "EquipPet", pa.pets[2].uid, true)
	Engine.advance(0.1)
	check("Pet Slot pass: two out", #pa.petsOut == 2)
	Engine.policy = { IsPaidItemTradingAllowed = true, ArePaidRandomItemsRestricted = true }
	local d = join("Dan", 1004)
	Engine.advance(0.5)
	check("restricted players see no eggs", Pet:View(d).canRandom == false)
	Engine.policy = { IsPaidItemTradingAllowed = true, ArePaidRandomItemsRestricted = false }
	Engine.removePlayer(d)
end

-- Squad twists ----------------------------------------------------------------------------------------------------
local Team = service("TeamService")
do
	-- the Void Eye (Shadow boss): half damage alone, full damage when two players TAG TEAM it
	local eye = Boss:_spawn(7)
	check("the Void Eye spawns", eye ~= nil and eye.planet.key == "SHADOW")
	local hp0 = eye.hp
	Mob:Hit(a, eye.id, 100)
	check("the Void Eye only takes half damage alone", eye.hp == hp0 - 50, hp0 - eye.hp)
	-- a friend joins (friends before Ben's profile loads, so TeamService sees it)
	Engine.makeFriends(a, { UserId = 1002 })
	b = join("Ben", 1002)
	pb = Data:Get(b)
	check("friends are a team", Team:AreTeam(a, b) and Team:DamageMult(a) > 1, Team:DamageMult(a))
	hp0 = eye.hp
	Mob:Hit(a, eye.id, 100)
	Mob:Hit(b, eye.id, 100)
	check("TAG TEAM: the second hit opens full damage", eye.hp == hp0 - 150, hp0 - eye.hp)
	Mob:Hit(a, eye.id, 100)
	check("...and it stays open for a bit", eye.hp == hp0 - 250, hp0 - eye.hp)
	Mob:Unregister(eye)
	Boss.bosses[7] = nil

	-- lend a blaster to a friend for one raid
	local best = Blaster:Best(a)
	local nB = #pb.blasters
	Engine.fireServer(a, "Lend", best.uid, 1002)
	Engine.advance(0.2)
	local lent
	for _, r in pb.blasters do
		lent = lent or (r.lentBy == 1001 and r)
	end
	check("lent a blaster to a friend", #pb.blasters == nB + 1 and lent ~= nil, #pb.blasters - nB)
	check("the friend holds it", pb.equipped == lent.uid)
	check("you keep yours", Blaster:Best(a).uid == best.uid)
	check("a lent blaster can't be sold", not Blaster:Sell(b, lent.uid) and #pb.blasters == nB + 1)
	check("...or put on a stall", not Trade:List(b, 1, lent.uid, Constants.STALL_PRICES[1]) and #pb.blasters == nB + 1)
	local cat = join("Cat", 1003)
	check("can't lend to a stranger", not Blaster:Lend(a, best.uid, cat, Team:AreTeam(a, cat)))

	-- a squad raid: you and your friends in the Hub, once an hour
	Planet:Travel(a, "HUB")
	Planet:Travel(b, "HUB")
	Planet:Travel(cat, "HUB")
	Engine.advance(0.3)
	check("no friends here: no squad raid", not Raid:SquadRaid(cat) and Raid.state == "waiting")
	local publicAt = Raid:NextAt()
	Engine.fireServer(a, "SquadRaid")
	Engine.advance(0.3)
	check(
		"SQUAD RAID: a private raid starts and pulls the friends in",
		Raid.state == "fighting" and Raid:IsSquad() and Planet:Where(a) == "RAID" and Planet:Where(b) == "RAID"
	)
	check("a stranger can't join it", not Raid:Join(cat) and Planet:Where(cat) == "HUB")
	check("the public raid clock keeps running", Raid:NextAt() == publicAt)
	local star
	for _, e in Mob.targets do
		if e.raid then
			star = e
		end
	end
	star.hp = 1
	local gemsA = pa.gems
	Mob:Hit(b, star.id, 5)
	Engine.advance(0.3)
	check("the squad raid ends", Raid.state == "waiting" and not Raid:IsSquad())
	check("the lender gets a share of the borrower's raid gems", pa.gems > gemsA, pa.gems - gemsA)
	local stillLent = false
	for _, r in pb.blasters do
		stillLent = stillLent or r.lentBy ~= nil
	end
	check("the lent blaster goes back after the raid (the raid prize stays)", not stillLent and #pb.blasters == nB + 1)
	local board = layout.hub.skyBoardPost:FindFirstChild("SkyBoard")
	local title = false
	for _, d in board and board:GetDescendants() or {} do
		if d:IsA("TextLabel") and d.Text:find("SQUAD RAID WON") then
			title = true
		end
	end
	check("the sky board says SQUAD RAID WON", title)
	check("squad raids are once an hour", not Raid:SquadRaid(a) and Raid.state == "waiting")
	Engine.removePlayer(cat)
	Engine.removePlayer(b)
	Engine.advance(0.3)
end

-- Leaderboards and the game log ------------------------------------------------------------------------------
do
	local boards = layout.hub.boards
	Leaderboard:Write(a)
	Leaderboard:Refresh()
	check("the boards fill", boards.damage.rows[1].name.Text ~= "", boards.damage.rows[1].name.Text)
	check(
		"BEST BLASTERS names the blaster",
		boards.damage.rows[1].name.Text:find("Ava · ", 1, true) ~= nil,
		boards.damage.rows[1].name.Text
	)
	check(
		"TOP RAIDERS counts today's raid damage",
		boards.raid.rows[1].value.Text ~= "",
		boards.raid.rows[1].value.Text
	)
	check("the prize timer runs", boards.raid.timer.Text:find("ULTRA", 1, true) ~= nil)
	-- MOST STARS: Ava rebirthed earlier
	check("MOST STARS shows Ava", boards.stars.rows[1].name.Text == "Ava", boards.stars.rows[1].name.Text)
	-- BEST BLASTERS is live: a stronger blaster shows at once
	local b2 = join("Ben", 1002)
	local pb2 = Data:Get(b2)
	Blaster:Grant(b2, {
		rarity = "Secret",
		planet = "SUN",
		roll = { dmg = "god", spd = "plain", luck = "plain", gem = "plain" },
		lv = 0,
	}, "test")
	Leaderboard:Redraw()
	check(
		"a stronger blaster takes #1 live",
		boards.damage.rows[1].name.Text:find("Ben", 1, true) ~= nil,
		boards.damage.rows[1].name.Text
	)
	local note = Engine.lastClientEvent("Announce", a)
	check(
		"a banner when someone takes #1",
		note and tostring(note.args[1]):find("Ben is now #1 on BEST BLASTERS", 1, true) ~= nil,
		note and note.args[1]
	)
	pb2.blasters = { pb2.blasters[1] }
	Leaderboard:Redraw()
	check("sell it and lose the spot", boards.damage.rows[1].name.Text:find("Ava", 1, true) ~= nil)
	Engine.removePlayer(b2)
	Engine.advance(0.3)
	-- the daily prize: #1 when the period ends wins an ULTRA blaster
	local period = Leaderboard:Period()
	pa.dailyRaid = { period = period, damage = 1e9 }
	Leaderboard:Redraw()
	local n = #pa.blasters
	Leaderboard:_rollover(period)
	check(
		"the daily TOP RAIDER wins an ULTRA blaster",
		#pa.blasters == n + 1 and pa.blasters[#pa.blasters].rarity == "Ultra" and pa.prizes[tostring(period)] == true,
		#pa.blasters - n
	)
	check("only once per day", not Leaderboard:GivePrize(a, period))
	-- the game log
	GameLog.flush()
	check("the log saw the server start", logged("Server started") ~= nil)
	check("the log saw Ava join", logged("Ava joined") ~= nil or logged("@Ava joined") ~= nil)
	check("the log saw the raid", logged("Raid won") ~= nil, gameLogs[#gameLogs] and gameLogs[#gameLogs].title)
	check("the log saw the squad raid", logged("Squad raid won") ~= nil)
	check("the log saw the trade", logged("bought @Ava's") ~= nil or logged("bought @Ben's") ~= nil)
	check("the log saw the prize", logged("TOP RAIDER prize") ~= nil)
	check("the log saw Ben leave with stats", logged("@Ben left") ~= nil and #logged("@Ben left").fields >= 10)
	local stats = GameLog:SessionStats(a, pa)
	check("session stats", stats ~= nil and stats[1].name == "Time played" and stats[7].name == "Raids joined")
end

-- Leaving --------------------------------------------------------------------------------------------------------------
b = join("Ben", 1002)
Planet:Travel(a, "DUST")
Planet:Travel(b, "DUST")
Engine.advance(1.5)
Engine.removePlayer(b)
Engine.advance(0.5)
check("Ben's bugs stay for Ava", nearestBug(a) ~= nil)
Engine.removePlayer(a)
Engine.advance(3)
local left = 0
for _, e in Mob.targets do
	if not e.boss then
		left += 1
	end
end
check("bugs leave empty planets", left == 0, left)

-- Shutdown --------------------------------------------------------------------------------------------------------
for _, fn in Engine.closeHandlers do
	fn()
end
Engine.advance(1)

check("no script errors", #Engine.errors == 0, Engine.errors[1])
local warnings = {}
for _, w in Engine.warnings do
	if not w:find("DataStore unavailable") then
		table.insert(warnings, w)
	end
end
check("no warnings", #warnings == 0, warnings[1])
print(`{passed} passed, {failed} failed, {#Engine.errors} script errors, {#Engine.warnings} warnings`)
if failed > 0 or #Engine.errors > 0 then
	error("server smoke test failed")
end
