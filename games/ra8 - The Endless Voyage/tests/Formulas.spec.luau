-- Unit tests for src/shared/Formulas.lua and the data tables (the game's maths and its content), the ocean's
-- layout and the remote list.
--   luaurun tests/Formulas.spec.luau      (from the game folder)
local Engine = loadModule("tests/mock/Engine.luau")
local tree = Engine.mountProject(".")
local Formulas = Engine.require(tree.shared.Formulas)
local Constants = Engine.require(tree.shared.Constants)
local Items = Engine.require(tree.shared.Data.Items)
local Pieces = Engine.require(tree.shared.Data.Pieces)
local Recipes = Engine.require(tree.shared.Data.Recipes)
local Voyages = Engine.require(tree.shared.Data.Voyages)
local Creatures = Engine.require(tree.shared.Data.Creatures)
local Progression = Engine.require(tree.shared.Data.Progression)
local OceanLayout = Engine.require(tree.shared.World.OceanLayout)
local IslandBuilder = Engine.require(tree.shared.World.IslandBuilder)
local Net = Engine.require(tree.shared.Net)
local Random = Engine.globals.Random

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end
local function near(a, b, eps)
	return math.abs(a - b) < (eps or 1e-6)
end

-- Levels ----------------------------------------------------------------------------------------------------------------
check("level 1 at 0 XP", Formulas.level(0) == 1)
check("level 2 at LEVEL_XP", Formulas.level(Constants.LEVEL_XP) == 2)
local lv, into, need = Formulas.level(Constants.LEVEL_XP + 10)
check(
	"XP into the level and the next's need",
	lv == 2 and into == 10 and need == Constants.LEVEL_XP + Constants.LEVEL_XP_GROWTH
)
check("xpForLevel inverts level", Formulas.level(Formulas.xpForLevel(12)) == 12)
check(
	"the guide's firsts reach level 2 by the first voyage home",
	(function()
		local total = 0
		for _, xp in Constants.XP.guide do
			total += xp
		end
		return total + Constants.XP.voyage + Constants.XP.discovery >= Constants.LEVEL_XP
	end)()
)

-- Tiers (§5.4) -----------------------------------------------------------------------------------------------------------
local function raft(list)
	return Formulas.raftSummary(list)
end
local start = {}
for _, t in Constants.START_TILES do
	table.insert(start, { key = "floor", gx = t[1], gz = t[2], level = 1 })
end
check("the driftwood platform is tier 1", Formulas.raftTier(raft(start)) == 1)
local function tiles(n, extra)
	local list = {}
	for i = 1, n do
		table.insert(list, { key = "floor", gx = i % 14, gz = i // 14, level = 1 })
	end
	for _, e in extra or {} do
		table.insert(list, { key = e, gx = 0, gz = 0, level = 1 })
	end
	return list
end
check(
	"9 tiles with a workbench, a box and an anchor is tier 2",
	Formulas.raftTier(raft(tiles(9, { "workbench", "storage", "anchor" }))) == 2
)
check("9 tiles without the workbench stays tier 1", Formulas.raftTier(raft(tiles(9, { "storage" }))) == 1)
check(
	"tier 3 needs a sail or an engine",
	Formulas.raftTier(raft(tiles(16, { "workbench", "storage", "anchor", "nav_table", "refinery" }))) == 2
)
check(
	"tier 3 with a sail",
	Formulas.raftTier(raft(tiles(16, { "workbench", "storage", "anchor", "nav_table", "refinery", "sail" }))) == 3
)
local t4 = tiles(
	28,
	{ "workbench", "storage", "nav_table", "refinery", "sail", "engine", "engineering", "research", "anchor" }
)
for i = 1, 4 do
	table.insert(t4, { key = "floor", gx = i, gz = 0, level = 2 })
end
check("tier 4 needs four tiles on the second deck", Formulas.raftTier(raft(t4)) == 4)
local t6 = tiles(60, {
	"workbench",
	"storage",
	"storage",
	"nav_table",
	"refinery",
	"sail",
	"engine",
	"engineering",
	"research",
	"anchor",
	"harpoon_turret",
	"crow_nest",
	"cookpot",
	"aquarium",
	"trophy_stand",
})
for i = 1, 16 do
	table.insert(t6, { key = "floor", gx = i % 14, gz = i // 14, level = 2 })
end
check("tier 6 waits for the Leviathan's tooth", Formulas.raftTier(raft(t6)) == 5)
check("tier 6 with the tooth", Formulas.raftTier(raft(t6), { tooth = true }) == 6)
check(
	"tiers can't be skipped",
	Formulas.raftTier(raft(tiles(60, { "harpoon_turret", "crow_nest", "cookpot", "storage", "storage" }))) == 1
)
local needs = Formulas.tierNeeds(raft(start), 1)
check("the next tier's needs are listed with have/need", needs and #needs == 4 and needs[1].have ~= nil)
check("no needs at the top", Formulas.tierNeeds(raft(t6), 6) == nil)
check(
	"every tier's needs are real pieces",
	(function()
		for _, t in Pieces.TIERS do
			for key in t.needs or {} do
				if not Pieces.get(key) then
					return false
				end
			end
			for key in t.any or {} do
				if not Pieces.get(key) then
					return false
				end
			end
		end
		return true
	end)()
)
check(
	"the tile caps grow with the tiers",
	(function()
		for i = 2, 6 do
			if Constants.MAX_TILES_BY_TIER[i] <= Constants.MAX_TILES_BY_TIER[i - 1] then
				return false
			end
		end
		return Constants.MAX_TILES_BY_TIER[6] <= Constants.GRID * Constants.GRID
	end)()
)
check(
	"each tier's tile need fits the previous tier's cap",
	(function()
		for _, t in Pieces.TIERS do
			if t.tiles and t.tiles > Constants.MAX_TILES_BY_TIER[t.n - 1] then
				return false, t.name
			end
		end
		return true
	end)()
)

-- Speed, voyages, cargo, storms -------------------------------------------------------------------------------------------
check(
	"paddling is speed 1, a sail 2, an engine 3, both 4",
	Formulas.raftSpeed(raft(start)) == 1
		and Formulas.raftSpeed(raft(tiles(1, { "sail" }))) == 2
		and Formulas.raftSpeed(raft(tiles(1, { "engine" }))) == 3
		and Formulas.raftSpeed(raft(tiles(1, { "sail", "engine" }))) == 4
)
check(
	"a first trip at paddle speed is about half a minute",
	Formulas.voyageSeconds(1, 1) >= 25 and Formulas.voyageSeconds(1, 1) <= 40
)
check(
	"the Trench with an engine is under two minutes",
	Formulas.voyageSeconds(7, 3) < 120,
	Formulas.voyageSeconds(7, 3)
)
check("voyages never go below the minimum", Formulas.voyageSeconds(1, 4) == Constants.VOYAGE_MIN_SECONDS)
check(
	"cargo grows with tiers and boxes",
	Formulas.cargo(1, raft(start)) == 16
		and Formulas.cargo(2, raft(tiles(1, { "storage" }))) == Constants.CARGO_BY_TIER[2] + 8
)
check(
	"railings and an anchor soften storms",
	Formulas.stormDamage(22, 0, 0) == 22
		and Formulas.stormDamage(22, 4, 0) < 22
		and Formulas.stormDamage(22, 4, 1) < Formulas.stormDamage(22, 4, 0)
)
check("storm damage never drops below 4", Formulas.stormDamage(22, 40, 3) == 4)

-- Creatures, loot, fish ---------------------------------------------------------------------------------------------------
check(
	"creatures get tougher in dangerous waters",
	Formulas.creatureHp(100, 5) > Formulas.creatureHp(100, 1) and Formulas.creatureDamage(10, 1) == 10
)
local rng = Random.new(3)
local counts = {}
for _ = 1, 4000 do
	local r = Formulas.pickRarity(rng, 1, 0)
	counts[r] = (counts[r] or 0) + 1
end
check(
	"loot is mostly common, rarely legendary",
	counts.common > counts.rare and counts.rare > (counts.legendary or 0) and (counts.legendary or 0) > 0,
	counts.legendary
)
local lucky = {}
for _ = 1, 4000 do
	local r = Formulas.pickRarity(rng, 3, 1)
	lucky[r] = (lucky[r] or 0) + 1
end
check(
	"danger and luck shift the odds up",
	(lucky.rare or 0) + (lucky.epic or 0) + (lucky.legendary or 0)
		> (counts.rare or 0) + (counts.epic or 0) + (counts.legendary or 0)
)
local fishCounts = {}
for _ = 1, 3000 do
	local f = Formulas.pickFish(rng, Creatures.FISH, "home", false, 0)
	fishCounts[f.key] = (fishCounts[f.key] or 0) + 1
end
check(
	"home waters by day: minnows, never icefish or glowjelly",
	fishCounts.minnow > 0 and fishCounts.icefish == nil and fishCounts.glowjelly == nil
)
local frozen = {}
for _ = 1, 3000 do
	local f = Formulas.pickFish(rng, Creatures.FISH, "frozen", true, 0.5)
	frozen[f.key] = (frozen[f.key] or 0) + 1
end
check(
	"frozen waters at night: icefish and glowjelly turn up",
	(frozen.icefish or 0) > 0 and (frozen.glowjelly or 0) > 0
)
check("the golden koi is rare", (fishCounts.golden_koi or 0) < 80, fishCounts.golden_koi)

-- The clock and the grid --------------------------------------------------------------------------------------------------
check(
	"the day runs 6 to 18",
	near(Formulas.clockTime("day", 0), 6) and near(Formulas.clockTime("day", Constants.DAY_SECONDS), 18)
)
check(
	"the night runs 18 to 6",
	near(Formulas.clockTime("night", 0), 18) and near(Formulas.clockTime("night", Constants.NIGHT_SECONDS), 6)
)
local center = Engine.Vector3.new(300, 0, 0)
local pos = Formulas.tilePosition(center, 6, 6, 1)
local gx, gz, level = Formulas.tileAt(center, pos)
check("tilePosition and tileAt invert", gx == 6 and gz == 6 and level == 1)
local up = Formulas.tilePosition(center, 7, 7, 2)
check("the second deck is a level up", up.Y > pos.Y and select(3, Formulas.tileAt(center, up)) == 2)
check(
	"the grid's middle is the start",
	(function()
		for _, t in Constants.START_TILES do
			if t[1] < 6 or t[1] > 7 or t[2] < 6 or t[2] > 7 then
				return false
			end
		end
		return true
	end)()
)

-- Items, pieces, recipes: every reference is real ------------------------------------------------------------------------
check(
	"every piece's cost names real items",
	(function()
		for _, p in Pieces.list do
			for k in p.cost do
				if not Items.get(k) then
					return false, p.key .. " " .. k
				end
			end
		end
		return true
	end)()
)
check(
	"every recipe's cost and product are real",
	(function()
		for _, r in Recipes.list do
			if r.item and not Items.get(r.item) then
				return false, r.id
			end
			for k in r.cost do
				if not Items.get(k) then
					return false, r.id .. " " .. k
				end
			end
			if not Recipes.STATIONS[r.station] then
				return false, r.station
			end
		end
		return true
	end)()
)
check(
	"every station piece's station has recipes",
	(function()
		for _, p in Pieces.list do
			if p.station and p.station ~= "research" and not Recipes.byStation[p.station] then
				return false, p.station
			end
		end
		return true
	end)()
)
check(
	"every tool and weapon can be made or found",
	(function()
		local found = { fishing_rod = true }
		for _, r in Recipes.list do
			if r.item then
				found[r.item] = true
			end
		end
		for _, it in Items.list do
			if (it.kind == "tool" or it.kind == "weapon") and not found[it.key] then
				return false, it.key
			end
		end
		return true
	end)()
)
check(
	"every blueprint piece and recipe has a research milestone or a danger",
	(function()
		local milestones = {}
		for _, m in Progression.RESEARCH do
			milestones[m.unlock.key] = true
		end
		for _, p in Pieces.list do
			if p.blueprint and not milestones[p.key] then
				return false, p.key
			end
		end
		for _, r in Recipes.list do
			if r.blueprint and not milestones[r.id] then
				return false, r.id
			end
		end
		return true
	end)()
)
check(
	"research milestones unlock real things",
	(function()
		for _, m in Progression.RESEARCH do
			local ok = (m.unlock.kind == "piece" and Pieces.get(m.unlock.key))
				or (m.unlock.kind == "recipe" and Recipes.get(m.unlock.key))
			if not ok then
				return false, m.unlock.key
			end
		end
		return true
	end)()
)
check(
	"the first-voyage economy adds up: 5 pieces of debris pay for the first tile",
	(function()
		-- the cheapest piece gives 2 wood: 5 x 2 = 10 >= a floor tile (4) and leaves some for the workbench
		return Pieces.get("floor").cost.wood <= 5 * 2 and Pieces.get("workbench").cost.wood <= 12
	end)()
)
check(
	"every destination's finds and resources are real items",
	(function()
		for _, d in Voyages.list do
			for _, r in d.resources do
				if not Items.get(r) then
					return false, d.key .. " " .. r
				end
			end
			for _, f in d.finds do
				if f ~= "blueprint" and f ~= "chart" and not Items.get(f) then
					return false, d.key .. " " .. f
				end
			end
			for _, c in d.creatures do
				if not Creatures.get(c) then
					return false, d.key .. " " .. c
				end
			end
			if not IslandBuilder.TEMPLATES[d.template] then
				return false, d.template
			end
		end
		return true
	end)()
)
check(
	"every destination's danger is reachable by some tier",
	(function()
		for _, d in Voyages.list do
			if not Formulas.tierForDanger(d.danger) then
				return false, d.key
			end
		end
		return true
	end)()
)
check(
	"one destination is known from the start and the rest are found",
	(function()
		local known = 0
		for _, d in Voyages.list do
			if d.known then
				known += 1
			elseif not d.found then
				return false, d.key
			end
		end
		return known == 1
	end)()
)
check(
	"achievements count real stats",
	(function()
		local stats = {
			debris = 1,
			tiles = 1,
			tier = 1,
			voyages = 1,
			wrecks = 1,
			fish = 1,
			crafted = 1,
			storms = 1,
			sharks = 1,
			serpents = 1,
			guardians = 1,
			leviathans = 1,
			puzzles = 1,
			research = 1,
			visitors = 1,
			journal = 1,
		}
		for _, a in Progression.ACHIEVEMENTS do
			if a.stat and not stats[a.stat] then
				return false, a.key
			end
		end
		return true
	end)()
)
check(
	"boards compare real records",
	(function()
		local records = { tier = 1, tiles = 1, voyages = 1, discoveries = 1, leviathans = 1, fish = 1 }
		for _, b in Progression.BOARDS do
			if not records[b.record] then
				return false, b.key
			end
		end
		return #Progression.BOARDS == 6
	end)()
)
check(
	"every icon is an emoji Roblox draws (nothing newer than 2019)",
	(function()
		-- the ones that came after Emoji 12.0 (2019): wood, rock, feather, blueberries, jar, trap, hut, bucket...
		local banned = {
			"🪵",
			"🪨",
			"🪶",
			"🫐",
			"🫙",
			"🪤",
			"🛖",
			"🪣",
			"🪸",
			"🪝",
			"🫧",
			"🪹",
			"🪺",
			"🪼",
			"🪽",
			"🛟",
			"🪩",
			"🪷",
			"🪻",
			"🫠",
			"🫡",
			"🪜",
			"🪚",
			"🪛",
			"🪃",
			"🪡",
			"🪢",
			"🪴",
			"🪵",
		}
		local function clean(s)
			for _, b in banned do
				if type(s) == "string" and string.find(s, b, 1, true) then
					return false
				end
			end
			return true
		end
		for _, it in Items.list do
			if not clean(it.icon) then
				return false, it.key
			end
		end
		for _, p in Pieces.list do
			if not clean(p.icon) then
				return false, p.key
			end
		end
		for _, d in Voyages.list do
			if not clean(d.icon) then
				return false, d.key
			end
		end
		for _, c in Creatures.list do
			if not clean(c.icon) then
				return false, c.key
			end
		end
		for _, f in Creatures.FISH do
			if not clean(f.icon) then
				return false, f.key
			end
		end
		for _, a in Progression.ACHIEVEMENTS do
			if not clean(a.icon) then
				return false, a.key
			end
		end
		for _, r in Constants.DISLIKE_REASONS do
			if not clean(r.text) then
				return false, r.key
			end
		end
		return true
	end)()
)

-- The ocean ---------------------------------------------------------------------------------------------------------------
check(
	"twenty plots, each with an island zone further out",
	#OceanLayout.plots == 20 and (OceanLayout.plots[1].islandCenter - OceanLayout.plots[1].center).Magnitude > 100
)
check(
	"plots don't overlap their neighbours' island zones",
	(function()
		for i, a in OceanLayout.plots do
			for j, b in OceanLayout.plots do
				if
					i ~= j
					and (a.islandCenter - b.center).Magnitude
						< Constants.ISLAND_RADIUS + Constants.PLOT_RADIUS * 0.5
				then
					return false, i .. " " .. j
				end
			end
		end
		return true
	end)()
)
check(
	"rafts never meet: two of the biggest rafts a grid allows never overlap, on any two plots",
	(function()
		-- (the plot's centre is tile 6.5, halfway between GRID_MIN and GRID_MAX)
		local half = ((Constants.GRID_MAX - Constants.GRID_MIN) / 2 + 0.5) * Constants.TILE
		for i, a in OceanLayout.plots do
			for j, b in OceanLayout.plots do
				local d = a.center - b.center
				if i ~= j and math.max(math.abs(d.X), math.abs(d.Z)) <= half * 2 then
					return false, `{i} {j}`
				end
			end
		end
		return true
	end)()
)
check("plotAt finds the plot at a raft's centre", OceanLayout.plotAt(OceanLayout.plots[3].center).index == 3)
check("plotAt finds the plot at its island", OceanLayout.plotAt(OceanLayout.plots[5].islandCenter).index == 5)
check("the current runs across the plot", math.abs(OceanLayout.plots[1].current:Dot(OceanLayout.plots[1].out)) < 1e-6)
check(
	"the islands fit inside the ocean",
	(function()
		for _, p in OceanLayout.plots do
			if p.islandCenter.Magnitude + Constants.ISLAND_RADIUS > Constants.OCEAN_SIZE / 2 then
				return false
			end
		end
		return true
	end)()
)

-- Remotes -----------------------------------------------------------------------------------------------------------------
check(
	"every client event has a rate",
	(function()
		for name, rate in Net.ClientEvents do
			if type(rate) ~= "number" or rate <= 0 then
				return false, name
			end
		end
		return true
	end)()
)
check(
	"the server events are unique",
	(function()
		local seen = {}
		for _, n in Net.ServerEvents do
			if seen[n] then
				return false, n
			end
			seen[n] = true
		end
		return true
	end)()
)

-- Everything builds: every piece, debris, prop, rig, held item and island template (the renderers and the
-- services share these builders, so a bad colour or a typo shows up here first).
do
	local RaftModels = Engine.require(tree.shared.World.RaftModels)
	local OceanModels = Engine.require(tree.shared.World.OceanModels)
	local ItemModels = Engine.require(tree.shared.World.ItemModels)
	local Rigs = Engine.require(tree.shared.World.Rigs)
	local CFrame = Engine.CFrame
	local Vector3 = Engine.Vector3
	local folder = Engine.Instance.new("Folder", Engine.workspace)
	local bad = {}
	for _, p in Pieces.list do
		local ok, err = pcall(
			RaftModels.build,
			p.key,
			CFrame.new(0, 2, 0),
			{ colours = { sail = "red", banner = "blue", flag = "gold", deck = "dark" }, edge = p.edge and 1 or nil },
			folder
		)
		if not ok then
			table.insert(bad, p.key .. ": " .. tostring(err))
		end
	end
	for _, kind in { "wood", "scrap", "rope", "cloth", "metal", "supply_crate", "bottle", "lost_bag" } do
		local ok, err = pcall(OceanModels.debris, kind, CFrame.new(0, 0.3, 0), folder)
		if not ok then
			table.insert(bad, kind .. ": " .. tostring(err))
		end
	end
	for _, kind in
		{
			"palm",
			"rock",
			"ore_rock",
			"crystal_rock",
			"plant",
			"container",
			"locker",
			"salvage",
			"campfire",
			"hut",
			"totem",
			"lantern_post",
			"ruin_wall",
			"old_machine",
			"wreck_hull",
			"ice_block",
			"lava_pool",
			"seat_rock",
		}
	do
		local ok, err = pcall(OceanModels.prop, kind, Vector3.new(0, 1, 0), Random.new(1), folder)
		if not ok then
			table.insert(bad, kind .. ": " .. tostring(err))
		end
	end
	for _, c in Creatures.list do
		local ok, err = pcall(Rigs.build, c.key, folder)
		if not ok then
			table.insert(bad, c.key .. ": " .. tostring(err))
		end
	end
	for _, it in Items.list do
		local ok, err = pcall(ItemModels.held, it, folder)
		if not ok then
			table.insert(bad, it.key .. ": " .. tostring(err))
		end
	end
	for key in IslandBuilder.TEMPLATES do
		local ok, err = pcall(IslandBuilder.build, key, Vector3.new(300, 0, 450), Random.new(2), folder)
		if not ok then
			table.insert(bad, key .. ": " .. tostring(err))
		end
	end
	check("every piece, debris, prop, rig, item and island builds", #bad == 0, table.concat(bad, " | "))
end

-- the helm has a little sail; every piece of debris floats in a ring of foam
do
	local RM = Engine.require(tree.shared.World.RaftModels)
	local OM = Engine.require(tree.shared.World.OceanModels)
	local helm = RM.build("helm", Engine.CFrame.new(), {}, Engine.workspace)
	check(
		"the helm has a mast and a sail",
		helm:FindFirstChild("Mast", true) ~= nil and helm:FindFirstChild("Canvas1", true) ~= nil
	)
	helm:Destroy()
	local all = true
	for _, kind in { "wood", "scrap", "rope", "cloth", "metal", "supply_crate", "bottle", "lost_bag" } do
		local m = OM.debris(kind, Engine.CFrame.new(), Engine.workspace)
		if not m:FindFirstChild("Foam") or #m:GetChildren() < 4 then
			all = false
		end
		m:Destroy()
	end
	check("every piece of debris is detailed and sits in foam", all)
end

-- explained like you're 3
do
	local needs = Formulas.tierNeeds({ tiles = 12, deck2 = 0, pieces = {} }, 1)
	local full = Formulas.fullText({ tier = 1, needs = needs, nextTier = "Survival Raft" })
	check(
		"a full raft says exactly what to build",
		full:find("Workbench") ~= nil and full:find("Storage Box") ~= nil and full:find("24") ~= nil,
		full
	)
	check("no word 'tier' in what the player reads", not full:lower():find("tier"))
	local locked = Formulas.lockedText(Pieces.get("refinery"), { tier = 1, needs = needs, nextTier = "Survival Raft" })
	check(
		"a locked piece says what to do, not a tier number",
		locked:find("Not yet") ~= nil and not locked:lower():find("tier"),
		locked
	)
end

-- QUICK only offers what the bag can pay for
do
	local view = { recommend = { { key = "workbench", why = "x" }, { key = "floor", why = "y" } } }
	check(
		"QUICK skips what you can't pay for",
		Formulas.recommended(view, { slots = { b1 = { key = "wood", n = 4 } } }).key == "floor"
	)
	local short = Formulas.recommended(view, { slots = {} })
	check(
		"QUICK names the first need (short) when you can pay for nothing",
		short and short.key == "workbench" and short.short == true
	)
	local filler =
		{ recommend = { { key = "workbench", why = "x" }, { key = "floor", why = "more room", filler = true } } }
	check(
		"QUICK never lays filler floor while something is needed",
		Formulas.recommended(filler, { slots = { b1 = { key = "wood", n = 4 } } }).key == "workbench"
	)
	check(
		"filler floor only when nothing else is wanted",
		Formulas.recommended(
			{ recommend = { { key = "floor", why = "more room", filler = true } } },
			{ slots = { b1 = { key = "wood", n = 4 } } }
		).key == "floor"
	)
end

print(`\n{passed} passed, {failed} failed`)
if failed > 0 then
	error("Formulas: " .. failed .. " failures")
end
