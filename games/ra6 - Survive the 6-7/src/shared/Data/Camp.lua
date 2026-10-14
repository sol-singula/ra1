--[[
The camp's upgrade tree (master plan §7): four tiers, each opened at the Camp Board with the team's materials, each
adding structures that make the camp safer or more capable, not just bigger. Every structure stands on a fixed
slot (World/MapLayout.campSlots), first as a glowing blueprint that anyone can fill by holding its prompt with
materials in their backpack (or in the camp's chest).

  tier      the camp tier that unlocks it
  cost      materials to build it
  hp        for structures monsters attack (walls, gates)
  upgrade   { key, tier, cost, hp }: what it becomes later (wood walls -> stone walls)
  count     how many slots of it the camp has
]]
local Camp = {}

Camp.TIERS = {
	{ n = 1, name = "The Campsite", desc = "A campfire, a chest and a workbench." },
	{
		n = 2,
		name = "The Outpost",
		desc = "Walls and gates, spike traps, a repair bench and watch platforms.",
		cost = { wood = 30, stone = 15 },
		requires = { workbench = 1, storage = 1 },
	},
	{
		n = 3,
		name = "The Fort",
		desc = "Stone walls, the anvil, the cookpot and lantern posts.",
		cost = { wood = 40, stone = 30, scrap = 15 },
		requires = { wall = 8, repair = 1 },
	},
	{
		n = 4,
		name = "The Stronghold",
		desc = "Catapults, fire pits and the Totem of the Seventh Night.",
		cost = { stone = 40, scrap = 30, glowcap = 4 },
		requires = { anvil = 1, stone_wall = 8 },
	},
}

Camp.STRUCTURES = {
	workbench = {
		name = "Workbench",
		icon = "🛠️",
		tier = 1,
		count = 1,
		cost = { wood = 6 }, -- (two of the camp's saplings: built in the first minute)
		station = "workbench",
	},
	storage = { name = "Storage Chest", icon = "🧰", tier = 1, count = 1, cost = { wood = 10 } },
	wall = {
		name = "Wall",
		icon = "🧱",
		tier = 2,
		count = 16,
		cost = { wood = 6 },
		hp = 300,
		upgrade = { key = "stone_wall", name = "Stone Wall", tier = 3, cost = { stone = 8 }, hp = 700 },
	},
	gate = {
		name = "Gate",
		icon = "🚪",
		tier = 2,
		count = 4,
		cost = { wood = 8 },
		hp = 250,
		upgrade = { key = "stone_gate", name = "Stone Gate", tier = 3, cost = { stone = 10 }, hp = 600 },
	},
	spikes = {
		name = "Spike Trap",
		icon = "📌",
		tier = 2,
		count = 6,
		cost = { wood = 4, stone = 2 },
		uses = 30,
		dmg = 15,
		upgrade = { key = "fire_pit", name = "Fire Pit", tier = 4, cost = { scrap = 4, wood = 6 }, dmg = 26, uses = 40 },
	},
	repair = { name = "Repair Bench", icon = "🔧", tier = 2, count = 1, cost = { wood = 10, stone = 6 } },
	platform = { name = "Watch Platform", icon = "🗼", tier = 2, count = 2, cost = { wood = 14 } },
	anvil = {
		name = "Anvil",
		icon = "⚒️",
		tier = 3,
		count = 1,
		cost = { stone = 15, scrap = 10 },
		station = "anvil",
	},
	cookpot = {
		name = "Cookpot",
		icon = "🍲",
		tier = 3,
		count = 1,
		cost = { stone = 10, scrap = 4 },
		station = "cookpot",
	},
	lamppost = { name = "Lantern Post", icon = "🏮", tier = 3, count = 4, cost = { wood = 4, scrap = 2 } },
	catapult = {
		name = "Pinecone Catapult",
		icon = "🎯",
		tier = 4,
		count = 2,
		cost = { scrap = 15, wood = 20 },
		dmg = 30,
		every = 3,
		range = 90,
	},
	totem = {
		name = "Totem of the Seventh Night",
		icon = "🗿",
		tier = 4,
		count = 1,
		cost = { glowcap = 6, stone = 20, scrap = 10 },
		bossCut = 0.15,
	},
}

-- The order structures appear in the objective list and on the Camp Board.
Camp.ORDER = {
	"workbench",
	"storage",
	"wall",
	"gate",
	"spikes",
	"repair",
	"platform",
	"anvil",
	"cookpot",
	"lamppost",
	"catapult",
	"totem",
}

function Camp.tier(n)
	return Camp.TIERS[n]
end

function Camp.structure(key)
	return Camp.STRUCTURES[key]
end

return Camp
