--[[
The random findings (the map is mostly forest, besides the camp and these). Every run picks a set of findings and
scatters them over the forest's clearings (World/MapLayout.sites), so no two runs have the same map to explore
(master plan §3: discover cabins, caves, resources and loot; take risks for better loot).

  count     { min, max } per run
  zone      inner (near camp) | middle | deep (the best loot, the most danger)
  radius    the clearing it needs (studs)
  loot      containers it holds: { kind, n } (LootService)
  special   what makes it more than loot (WorldService)
]]
local Findings = {}

Findings.list = {
	{
		key = "cabin",
		name = "Abandoned Cabin",
		icon = "🏚️",
		count = { 2, 3 },
		zone = { "inner", "middle", "deep" },
		radius = 18,
		loot = { { "locker", 1 }, { "crate", 2 } },
		mimicChance = 0.35,
		desc = "Somebody left in a hurry. Lockers hold tools and weapons.",
	},
	{
		key = "ranger_tower",
		name = "Old Ranger Tower",
		icon = "🗼",
		count = { 1, 1 },
		zone = { "middle" },
		radius = 16,
		loot = { { "chest", 1 } },
		special = "map",
		desc = "Climb to the top: a chest and the Ranger's Map.",
	},
	{
		key = "ice_cream_truck",
		name = "Crashed Ice Cream Truck",
		icon = "🍦",
		count = { 1, 1 },
		zone = { "inner", "middle" },
		radius = 18,
		loot = { { "cooler", 1 } },
		scrap = 3,
		desc = "How did it get here? Free ice cream and a lot of scrap.",
	},
	{
		key = "bear_cave",
		name = "Bear Cave",
		icon = "🕳️",
		count = { 1, 2 },
		zone = { "middle", "deep" },
		radius = 22,
		loot = { { "chest", 1 } },
		guard = "grinwolf",
		desc = "Dark inside. Something left a chest at the back.",
	},
	{
		key = "witch_hut",
		name = "Witch's Hut",
		icon = "🧙",
		count = { 1, 1 },
		zone = { "middle", "deep" },
		radius = 16,
		loot = { { "cauldron", 1 } },
		desc = "A crooked hut with a bubbling cauldron full of brews.",
	},
	{
		key = "stone_circle",
		name = "Stone Circle",
		icon = "🗿",
		count = { 1, 1 },
		zone = { "middle", "deep" },
		radius = 20,
		special = "blessing",
		desc = "Old standing stones. Offer a Strange Idol for a blessing.",
	},
	{
		key = "lost_camp",
		name = "Lost Campsite",
		icon = "⛺",
		count = { 1, 2 },
		zone = { "inner", "middle" },
		radius = 15,
		loot = { { "backpack", 1 }, { "crate", 1 } },
		desc = "A tent and a dead campfire. Their backpack is still here.",
	},
	{
		key = "mushroom_ring",
		name = "Mushroom Ring",
		icon = "🍄",
		count = { 1, 2 },
		zone = { "middle", "deep" },
		radius = 16,
		glowcaps = 4,
		guard = "snapcap",
		desc = "Giant glowing mushrooms. Glowcaps grow here.",
	},
	{
		key = "hollow_log",
		name = "Giant Hollow Log",
		icon = "🎍",
		count = { 1, 1 },
		zone = { "middle", "deep" },
		radius = 18,
		loot = { { "chest", 1 } },
		desc = "A fallen giant you can walk through. Look inside.",
	},
	{
		key = "hunter_blind",
		name = "Hunter's Blind",
		icon = "🏹",
		count = { 1, 1 },
		zone = { "inner", "middle" },
		radius = 12,
		loot = { { "rack", 1 } },
		desc = "A hide up on stilts. Hunters keep bows here.",
	},
	{
		key = "rusty_car",
		name = "Rusty Car",
		icon = "🚗",
		count = { 1, 2 },
		zone = { "inner", "middle", "deep" },
		radius = 14,
		scrap = 3,
		loot = { { "crate", 1 } },
		desc = "Moss on the seats. Scrap everywhere.",
	},
	{
		key = "beehive_tree",
		name = "Beehive Tree",
		icon = "🐝",
		count = { 1, 1 },
		zone = { "middle", "deep" },
		radius = 12,
		special = "bees",
		desc = "Honey! And bees. Grab it and run.",
	},
	{
		key = "kermy_lair",
		name = "Kermy's Lair",
		icon = "🐸",
		count = { 1, 1 },
		zone = { "deep" },
		radius = 24,
		loot = { { "hoard", 1 } },
		special = "lair",
		desc = "A throne of logs and a pile of stolen loot. Kermy naps here by day. Don't wake him.",
	},
}

Findings.byKey = {}
for i, f in Findings.list do
	f.order = i
	Findings.byKey[f.key] = f
end

-- Kermy's diary: seven pages, one or two hidden at the findings each run. Found pages are yours forever.
Findings.PAGES = {
	"Day 1. Moved into the forest. Nice trees. Nobody plays basketball here.",
	"Day 2. Campers! I waved. I said SIX SEVEN. They ran. Rude.",
	"Day 3. Found a jersey in the lost campsite. It fits. Mostly.",
	"Day 4. The stumps won't talk to me. The wolves just grin. Lonely.",
	"Day 5. Practiced my lunge on a tree. The tree won.",
	"Day 6. I keep eating their sandwiches. They keep leaving them out. Is that a hint?",
	"Day 7. Tonight I get BIG. Nobody can stop the six seven.",
}

function Findings.get(key)
	return Findings.byKey[key]
end

return Findings
