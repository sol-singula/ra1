--[[
Castle Tycoon (the "tycoon" place; TycoonService, TycoonController, World/TycoonBuilder): everyone gets a plot of
their own and raises a castle on it, one buy-pad at a time. Gold Mines fill the plot's vault with Gold every second;
standing on the COLLECT pad takes it; standing on a buy-pad spends it. Every pad bought builds its piece and adds to
the income, so there is always a next thing to save for; the castle grows tier by tier (CAMP, FORT, KEEP, CASTLE,
CITADEL), and each tier finished pays Shards (the shop's money, the same as every other mode). With everything
built, REBIRTH: the castle starts over, the income keeps +REBIRTH_INCOME for every rebirth, the prices go up by
REBIRTH_COST, and a rebirth pays Shards too. Raiders come for the vault now and then: the towers shoot them, and
anyone standing close can hit them (the HIT button); a raider that reaches the vault takes a share of what's in it.

The pacing (tests/TycoonSmoke checks it): the first castle takes about 18 minutes of playing, a pad every 10 s at
first and about every minute and a half at the end; a tier every three or four minutes.

  Tycoon.ITEMS        { { key, name, tier, cost, income, mult?, kind } } in the order they come up
  Tycoon.TIERS        { { name, shards } } the five tiers
  Tycoon.byKey[key]   the item
  Tycoon.cost(item, rebirths)          the price on this run
  Tycoon.income(bought, rebirths)      Gold a second from what's built
  Tycoon.mult(bought, rebirths)        the multiplier on the mines (the upgrades and the rebirths)
  Tycoon.next(bought, n)               the next n items not built yet, in order (the buy-pads show these)
  Tycoon.tier(bought)                  the tier being built (1..5; 6 when everything is), and how far: done, of
  Tycoon.complete(bought)              everything built (the REBIRTH pad)
  Tycoon.rebirthShards(rebirths)       what the next rebirth pays
]]
local Tycoon = {}

Tycoon.PLOTS = 6 -- plots in a server (the place's MaxPlayers matches)
Tycoon.PLOT_SIZE = 64 -- studs a side
Tycoon.PADS = 3 -- buy-pads showing at once (the next three)
Tycoon.START_CASH = 0
Tycoon.REBIRTH_INCOME = 0.5 -- +50% income for every rebirth
Tycoon.REBIRTH_COST = 0.75 -- +75% on every price for every rebirth (so each castle takes a little longer)
Tycoon.REBIRTH_SHARDS = 150 -- the first rebirth's Shards; each one after pays REBIRTH_SHARDS_STEP more
Tycoon.REBIRTH_SHARDS_STEP = 50

-- Raids (TycoonService): once the first tower stands
Tycoon.RAID_FIRST = 25 -- seconds after the first tower to the first raid (it teaches the HIT button)
Tycoon.RAID_EVERY = 150 -- then one this often
Tycoon.RAID_BASE = 2 -- raiders: this many, plus the tier
Tycoon.RAIDER_HITS = 2 -- hits to knock one down, plus the tier
Tycoon.RAIDER_SPEED = 4 -- studs a second
Tycoon.RAIDER_GAP = 1.5 -- seconds between raiders coming out
Tycoon.RAID_STEAL = 0.2 -- a raider at the vault takes this share of what's in it (never what's been collected)
Tycoon.RAIDER_GOLD = 4 -- a raider down pays this many seconds of income (at least RAIDER_GOLD_MIN)
Tycoon.RAIDER_GOLD_MIN = 10
Tycoon.RAID_BONUS = 10 -- a raid beaten without losing any Gold: this many seconds of income more
Tycoon.TOWER_RANGE = 48
Tycoon.TOWER_EVERY = 1.2 -- seconds between a tower's shots
Tycoon.TOWER_DAMAGE = { towerFL = 1, towerFR = 1, towerBL = 2, towerBR = 2 } -- (the mage towers hit harder)
Tycoon.HIT_RANGE = 14 -- studs from a raider that a HIT reaches
Tycoon.HIT_EVERY = 0.3 -- seconds between a player's hits

Tycoon.TIERS = {
	{ name = "CAMP", shards = 20 },
	{ name = "FORT", shards = 30 },
	{ name = "KEEP", shards = 45 },
	{ name = "CASTLE", shards = 70 },
	{ name = "CITADEL", shards = 100 },
}

-- kind: "mine" (Gold every second; a gold cube drops from it into the vault), "wall", "tower" (shoots raiders),
-- "gate", "keep", "upgrade" (a multiplier on everything), "decor"
-- stylua: ignore start
Tycoon.ITEMS = {
	{ key = "mine1",   name = "Gold Mine",         tier = 1, cost = 0,      income = 2,   kind = "mine" },
	{ key = "mine2",   name = "Gold Mine II",      tier = 1, cost = 16,     income = 3,   kind = "mine" },
	{ key = "wallFL",  name = "Front Wall",        tier = 1, cost = 44,     income = 2,   kind = "wall" },
	{ key = "wallFR",  name = "Front Wall",        tier = 1, cost = 69,     income = 2,   kind = "wall" },
	{ key = "mine3",   name = "Gold Mine III",     tier = 1, cost = 97,     income = 5,   kind = "mine" },
	{ key = "gate",    name = "Gatehouse",         tier = 1, cost = 170,    income = 4,   kind = "gate" },
	{ key = "towerFL", name = "Archer Tower",      tier = 2, cost = 240,    income = 6,   kind = "tower" },
	{ key = "towerFR", name = "Archer Tower",      tier = 2, cost = 350,    income = 6,   kind = "tower" },
	{ key = "mine4",   name = "Deep Mine",         tier = 2, cost = 490,    income = 12,  kind = "mine" },
	{ key = "wallL",   name = "West Wall",         tier = 2, cost = 750,    income = 8,   kind = "wall" },
	{ key = "wallR",   name = "East Wall",         tier = 2, cost = 990,    income = 8,   kind = "wall" },
	{ key = "forge",   name = "Gold Forge (x1.5)", tier = 2, cost = 1300,   income = 0,   mult = 1.5, kind = "upgrade" },
	{ key = "mine5",   name = "Crystal Mine",      tier = 3, cost = 2100,   income = 25,  kind = "mine" },
	{ key = "keep1",   name = "The Keep",          tier = 3, cost = 3300,   income = 20,  kind = "keep" },
	{ key = "mine6",   name = "Crystal Mine II",   tier = 3, cost = 4600,   income = 35,  kind = "mine" },
	{ key = "towerBL", name = "Mage Tower",        tier = 3, cost = 6800,   income = 25,  kind = "tower" },
	{ key = "towerBR", name = "Mage Tower",        tier = 3, cost = 8900,   income = 25,  kind = "tower" },
	{ key = "wallB",   name = "Back Wall",         tier = 3, cost = 11000,  income = 30,  kind = "wall" },
	{ key = "hall",    name = "Great Hall",        tier = 4, cost = 15000,  income = 60,  kind = "keep" },
	{ key = "mine7",   name = "Diamond Mine",      tier = 4, cost = 20000,  income = 80,  kind = "mine" },
	{ key = "vault",   name = "Royal Vault (x1.5)", tier = 4, cost = 29000, income = 0,   mult = 1.5, kind = "upgrade" },
	{ key = "mine8",   name = "Diamond Mine II",   tier = 4, cost = 48000,  income = 120, kind = "mine" },
	{ key = "walks",   name = "Wall Walks",        tier = 4, cost = 71000,  income = 90,  kind = "decor" },
	{ key = "spire",   name = "The Spire",         tier = 4, cost = 94000,  income = 150, kind = "keep" },
	{ key = "statue",  name = "Hero Statue",       tier = 5, cost = 130000, income = 150, kind = "decor" },
	{ key = "banners", name = "Royal Banners",     tier = 5, cost = 180000, income = 200, kind = "decor" },
	{ key = "crown",   name = "Golden Crown (x2)", tier = 5, cost = 240000, income = 0,   mult = 2, kind = "upgrade" },
	{ key = "throne",  name = "Throne Room",       tier = 5, cost = 530000, income = 400, kind = "keep" },
}
-- stylua: ignore end

Tycoon.byKey = {}
for i, it in Tycoon.ITEMS do
	it.index = i
	Tycoon.byKey[it.key] = it
end

function Tycoon.cost(item, rebirths)
	return math.floor(item.cost * (1 + Tycoon.REBIRTH_COST * (rebirths or 0)) + 0.5)
end

function Tycoon.mult(bought, rebirths)
	local m = 1 + Tycoon.REBIRTH_INCOME * (rebirths or 0)
	for _, it in Tycoon.ITEMS do
		if it.mult and bought[it.key] then
			m *= it.mult
		end
	end
	return m
end

function Tycoon.income(bought, rebirths)
	local base = 0
	for _, it in Tycoon.ITEMS do
		if bought[it.key] then
			base += it.income
		end
	end
	return base * Tycoon.mult(bought, rebirths)
end

function Tycoon.next(bought, n)
	local out = {}
	for _, it in Tycoon.ITEMS do
		if not bought[it.key] then
			table.insert(out, it)
			if #out >= (n or Tycoon.PADS) then
				break
			end
		end
	end
	return out
end

function Tycoon.tier(bought)
	for t = 1, #Tycoon.TIERS do
		local done, of = 0, 0
		for _, it in Tycoon.ITEMS do
			if it.tier == t then
				of += 1
				if bought[it.key] then
					done += 1
				end
			end
		end
		if done < of then
			return t, done, of
		end
	end
	return #Tycoon.TIERS + 1, 0, 0
end

-- The items of a tier, all built?
function Tycoon.tierDone(bought, t)
	for _, it in Tycoon.ITEMS do
		if it.tier == t and not bought[it.key] then
			return false
		end
	end
	return true
end

function Tycoon.complete(bought)
	for _, it in Tycoon.ITEMS do
		if not bought[it.key] then
			return false
		end
	end
	return true
end

function Tycoon.rebirthShards(rebirths)
	return Tycoon.REBIRTH_SHARDS + Tycoon.REBIRTH_SHARDS_STEP * (rebirths or 0)
end

-- The plots' accent colours (the trims, the banners, the mines' caps): one each, never brown
Tycoon.COLORS = {
	Color3.fromRGB(235, 40, 45),
	Color3.fromRGB(35, 110, 245),
	Color3.fromRGB(46, 170, 90),
	Color3.fromRGB(150, 90, 240),
	Color3.fromRGB(255, 140, 30),
	Color3.fromRGB(30, 200, 185),
}

return Tycoon
