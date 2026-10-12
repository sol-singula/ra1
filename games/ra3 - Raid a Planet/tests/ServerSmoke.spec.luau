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
	check("the raid opens: beam, pad, boss, event", hubPad.Transparency < 1 and Raid.state == "fighting" and Engine.lastClientEvent("Event") ~= nil)
	check("everyone is told", Engine.lastClientEvent("Alert", b) ~= nil)
	check("robots fill a quiet raid", Engine.workspace.Map.Hub.Arena:FindFirstChild("Robot_1") ~= nil)
	-- step on the RAID pad
	go(a, Vector3.new(0, 7, 0))
	Engine.advance(0.3)
	check("the RAID pad takes you to the arena", Planet:Where(a) == "RAID" and World.inArena(a.Character.HumanoidRootPart.Position))
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
	check("below 66%: shields up, plates lit", star.shielded == true and layout.arena.plates[1].lines[2].Text == "STAND HERE!")
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

-- Leaving --------------------------------------------------------------------------------------------------------------
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
