--[[
Who lives in the ocean and on its islands (master plan §9: creatures with a reason to meet them), and the fish.

  where      island | sea | boss
  hp, dmg    base health and damage (Formulas scale them a little with the voyage's danger)
  speed      studs a second
  size       small | medium | heavy | boss (the XP for one, the rig's scale)
  behaviour  chase (walks at you) | skitter (hit and run) | steal (takes a food item and flies off) |
             pack (comes in threes) | guard (stands by its treasure) | bite (bites raft tiles from the water)
  trophy     the journal entry's name for one beaten
]]
local Creatures = {}

Creatures.list = {
	{
		key = "reef_crab",
		name = "Reef Crab",
		icon = "🦀",
		where = "island",
		hp = 20,
		dmg = 5,
		speed = 9,
		range = 4,
		size = "small",
		behaviour = "skitter",
		desc = "Pinches. Lots of them on the shore.",
		tip = "It sidesteps before it pinches: step back.",
	},
	{
		key = "gull",
		name = "Thief Gull",
		icon = "🐦",
		where = "island",
		hp = 10,
		dmg = 0,
		speed = 18,
		range = 3,
		size = "small",
		behaviour = "steal",
		desc = "Steals the food in your hand and flies off laughing.",
		tip = "Hold a tool, not a coconut, when it circles.",
	},
	{
		key = "mire_lurker",
		name = "Mire Lurker",
		icon = "🐸",
		where = "island",
		hp = 45,
		dmg = 10,
		speed = 12,
		range = 5,
		size = "medium",
		behaviour = "chase",
		desc = "Lives in the reeds and the wrecks. Patient.",
		tip = "It rears up before it lunges. Move.",
	},
	{
		key = "lava_beetle",
		name = "Lava Beetle",
		icon = "🐞",
		where = "island",
		hp = 40,
		dmg = 8,
		speed = 10,
		range = 4,
		size = "medium",
		behaviour = "chase",
		burn = true,
		desc = "Glows. Hot. Leaves a burn.",
		tip = "Fight it on the sand, not the warm rock.",
	},
	{
		key = "frost_wolf",
		name = "Frost Wolf",
		icon = "🐺",
		where = "island",
		hp = 60,
		dmg = 12,
		speed = 20,
		range = 6,
		size = "medium",
		behaviour = "pack",
		desc = "Three at a time, from behind the ice.",
		tip = "Back against a wall so they come one at a time.",
	},
	{
		key = "ruin_guardian",
		name = "Ruin Guardian",
		icon = "🗿",
		where = "island",
		hp = 320,
		dmg = 18,
		speed = 8,
		range = 7,
		size = "heavy",
		behaviour = "guard",
		desc = "Stone that walks. Guards the idol.",
		tip = "Slow. Hit, step away, hit.",
	},
	{
		key = "shark",
		name = "Shark",
		icon = "🦈",
		where = "sea",
		hp = 70,
		dmg = 12,
		speed = 16,
		range = 6,
		size = "medium",
		behaviour = "bite",
		desc = "Bites the raft's edge. Spikes make it think again.",
		tip = "Stand on a spiked tile and spear it when it surfaces.",
	},
	{
		key = "sea_serpent",
		name = "Sea Serpent",
		icon = "🐍",
		where = "sea",
		hp = 220,
		dmg = 20,
		speed = 14,
		range = 8,
		size = "heavy",
		behaviour = "bite",
		desc = "Coils round the raft. Harpoons.",
		tip = "It rises before it strikes: that's when the harpoon lands.",
	},
	{
		key = "leviathan",
		name = "The Leviathan",
		icon = "🐲",
		where = "boss",
		hp = 2400,
		dmg = 35,
		speed = 12,
		range = 14,
		size = "boss",
		behaviour = "boss",
		desc = "The enormous thing. It was always there.",
		tip = "Harpoons when it surfaces; repair between dives; the turret never sleeps.",
	},
}

Creatures.byKey = {}
for _, c in Creatures.list do
	Creatures.byKey[c.key] = c
end

function Creatures.get(key)
	return Creatures.byKey[key]
end

-- Fish (the rod, the aquarium, the journal): rarity sets the odds, `where` the waters (nil: anywhere), `night` the
-- time; junk gives scrap instead of a fish.
Creatures.FISH = {
	{ key = "minnow", name = "Minnow", icon = "🐟", rarity = "common", food = 1 },
	{ key = "mackerel", name = "Mackerel", icon = "🐟", rarity = "common", food = 1 },
	{ key = "old_boot", name = "Old Boot", icon = "👢", rarity = "common", junk = "scrap" },
	{ key = "snapper", name = "Red Snapper", icon = "🐠", rarity = "uncommon", food = 1 },
	{ key = "parrotfish", name = "Parrotfish", icon = "🐠", rarity = "uncommon", where = "tropical", food = 1 },
	{ key = "pufferfish", name = "Pufferfish", icon = "🐡", rarity = "uncommon" },
	{ key = "icefish", name = "Icefish", icon = "🐟", rarity = "rare", where = "frozen", food = 1 },
	{ key = "emberfish", name = "Emberfish", icon = "🐠", rarity = "rare", where = "volcanic" },
	{ key = "glowjelly", name = "Glowjelly", icon = "✨", rarity = "rare", night = true },
	{ key = "swordfish", name = "Swordfish", icon = "🗡️", rarity = "epic", food = 2 },
	{ key = "deep_eel", name = "Trench Eel", icon = "🐍", rarity = "epic", where = "trench" },
	{ key = "golden_koi", name = "Golden Koi", icon = "🐠", rarity = "legendary" },
}
Creatures.fishByKey = {}
for _, f in Creatures.FISH do
	Creatures.fishByKey[f.key] = f
end

return Creatures
