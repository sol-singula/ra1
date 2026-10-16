--[[
Everything you can hold or carry (master plan §7: resource tiers; §8: tools with a clear purpose). Icons are emoji
Roblox draws (nothing newer than 2019).

  kind      resource | tool | weapon | food | chart | blueprint | artifact | fish | pin (a build shortcut)
  rarity    common | uncommon | rare | epic | legendary (loot odds, the glow on the ground, the journal)
  stack     how many fit in one slot
  tool      rod { range, pull, double, salvage, speed, rare } | axe { power } | pick { power } | pry { power } |
            hammer { repair }
  weapon    { dmg, range, arc, cd, class = "spear" | "harpoon", thrown }
  food      { heal, buff = { key, seconds } }
  chart     the destination it reveals (Data/Voyages)
  blueprint the piece or recipe it unlocks (Data/Pieces, Data/Recipes)
  research  research points an artifact is worth at the Research Station
]]
local Items = {}

Items.RARITY = {
	common = { order = 1, name = "Common", color = Color3.fromRGB(205, 205, 200) },
	uncommon = { order = 2, name = "Uncommon", color = Color3.fromRGB(110, 210, 110) },
	rare = { order = 3, name = "Rare", color = Color3.fromRGB(90, 160, 255) },
	epic = { order = 4, name = "Epic", color = Color3.fromRGB(190, 110, 255) },
	legendary = { order = 5, name = "Legendary", color = Color3.fromRGB(255, 200, 60) },
}

Items.list = {
	-- Resources: common (the ocean)
	{
		key = "wood",
		name = "Wood",
		kind = "resource",
		rarity = "common",
		icon = "🟫",
		stack = 40,
		desc = "Planks and driftwood. Everything starts with it.",
	},
	{
		key = "scrap",
		name = "Scrap",
		kind = "resource",
		rarity = "common",
		icon = "♻️",
		stack = 40,
		desc = "Plastic and bits. Oddly useful.",
	},
	{
		key = "rope",
		name = "Rope",
		kind = "resource",
		rarity = "common",
		icon = "🧵",
		stack = 40,
		desc = "Holds things together.",
	},
	{
		key = "cloth",
		name = "Cloth",
		kind = "resource",
		rarity = "common",
		icon = "🧶",
		stack = 40,
		desc = "Sailcloth, torn. Sew it.",
	},
	{
		key = "metal",
		name = "Metal",
		kind = "resource",
		rarity = "uncommon",
		icon = "🔩",
		stack = 40,
		desc = "Fragments of something that sank.",
	},
	-- Resources: islands
	{
		key = "palm",
		name = "Palm Frond",
		kind = "resource",
		rarity = "common",
		icon = "🌴",
		stack = 40,
		desc = "Weaves into cloth and roofs.",
	},
	{
		key = "fiber",
		name = "Fiber",
		kind = "resource",
		rarity = "common",
		icon = "🌿",
		stack = 40,
		desc = "From island plants. Twists into rope.",
	},
	{
		key = "stone",
		name = "Stone",
		kind = "resource",
		rarity = "common",
		icon = "⛰️",
		stack = 40,
		desc = "From rocky shores.",
	},
	{
		key = "ore",
		name = "Ore",
		kind = "resource",
		rarity = "uncommon",
		icon = "🔶",
		stack = 30,
		desc = "Refines into metal.",
	},
	{
		key = "coral",
		name = "Coral",
		kind = "resource",
		rarity = "uncommon",
		icon = "🐚",
		stack = 30,
		desc = "Bright and brittle. Decorators love it.",
	},
	-- Resources: processed (the Refining Station)
	{
		key = "plank",
		name = "Plank",
		kind = "resource",
		rarity = "uncommon",
		icon = "🟫",
		stack = 40,
		desc = "Sawn wood. Sturdier decks.",
	},
	{
		key = "gear",
		name = "Gear",
		kind = "resource",
		rarity = "rare",
		icon = "⚙️",
		stack = 20,
		desc = "Machined metal. Engines want it.",
	},
	{
		key = "glass",
		name = "Glass",
		kind = "resource",
		rarity = "uncommon",
		icon = "🧊",
		stack = 30,
		desc = "Melted sand. Windows and aquariums.",
	},
	-- Resources: rare and advanced (dangerous waters)
	{
		key = "pearl",
		name = "Pearl",
		kind = "resource",
		rarity = "rare",
		icon = "⚪",
		stack = 20,
		desc = "From the deep. Worth keeping.",
	},
	{
		key = "heat_crystal",
		name = "Heat Crystal",
		kind = "resource",
		rarity = "rare",
		icon = "🔥",
		stack = 20,
		desc = "Warm to the touch. Ember Isle.",
	},
	{
		key = "frost_crystal",
		name = "Frost Crystal",
		kind = "resource",
		rarity = "rare",
		icon = "💎",
		stack = 20,
		desc = "Never melts. Frost Shelf.",
	},
	{
		key = "old_tech",
		name = "Old Tech",
		kind = "resource",
		rarity = "epic",
		icon = "🔋",
		stack = 10,
		desc = "Still humming. The ruins are full of it.",
	},
	{
		key = "leviathan_scale",
		name = "Leviathan Scale",
		kind = "resource",
		rarity = "legendary",
		icon = "🐲",
		stack = 10,
		desc = "Proof. Nothing cuts it.",
	},
	-- Tools: collecting (§7.2: the rod does it all: cast at what floats past and reel it in, cast at open water to fish)
	{
		key = "fishing_rod",
		name = "Fishing Rod",
		kind = "tool",
		rarity = "common",
		icon = "🎣",
		stack = 1,
		tool = { rod = { range = 45, pull = 1, speed = 1, rare = 0 } },
		desc = "Cast at what floats past and reel it in. Cast at open water to fish.",
	},
	{
		key = "iron_rod",
		name = "Iron Rod",
		kind = "tool",
		rarity = "uncommon",
		icon = "🎣",
		stack = 1,
		tool = { rod = { range = 55, pull = 1.5, speed = 1.2, rare = 0 } },
		desc = "Casts further, reels faster.",
	},
	{
		key = "deep_rod",
		name = "Deep Rod",
		kind = "tool",
		rarity = "rare",
		icon = "🎣",
		stack = 1,
		tool = { rod = { range = 55, pull = 1.2, speed = 1.6, rare = 0.3 } },
		desc = "Bites faster, finds the rare fish.",
	},
	{
		key = "long_rod",
		name = "Long Rod",
		kind = "tool",
		rarity = "rare",
		icon = "🎣",
		stack = 1,
		tool = { rod = { range = 75, pull = 1.6, double = 0.35, speed = 1.3, rare = 0.1 } },
		desc = "Reaches the far lanes. Sometimes two pieces at once.",
	},
	{
		key = "salvage_rod",
		name = "Salvage Rod",
		kind = "tool",
		rarity = "epic",
		icon = "🎣",
		stack = 1,
		tool = { rod = { range = 90, pull = 2.2, double = 0.6, salvage = 1, speed = 1.4, rare = 0.2 } },
		desc = "A claw on the line. Grabs anything, finds the good stuff.",
	},
	{
		key = "axe",
		name = "Axe",
		kind = "tool",
		rarity = "common",
		icon = "🪓",
		stack = 1,
		tool = { axe = { power = 1 } },
		desc = "Island trees: wood and fronds.",
	},
	{
		key = "steel_axe",
		name = "Steel Axe",
		kind = "tool",
		rarity = "rare",
		icon = "🪓",
		stack = 1,
		tool = { axe = { power = 2.2 } },
		desc = "Two swings a tree.",
	},
	{
		key = "pickaxe",
		name = "Pickaxe",
		kind = "tool",
		rarity = "common",
		icon = "⛏️",
		stack = 1,
		tool = { pick = { power = 1 } },
		desc = "Rocks: stone and ore.",
	},
	{
		key = "steel_pick",
		name = "Steel Pickaxe",
		kind = "tool",
		rarity = "rare",
		icon = "⛏️",
		stack = 1,
		tool = { pick = { power = 2.2 } },
		desc = "Through anything.",
	},
	{
		key = "crowbar",
		name = "Crowbar",
		kind = "tool",
		rarity = "uncommon",
		icon = "🔧",
		stack = 1,
		tool = { pry = { power = 1 } },
		desc = "Wrecks: pry the salvage loose.",
	},
	{
		key = "hammer",
		name = "Hammer",
		kind = "tool",
		rarity = "common",
		icon = "🔨",
		stack = 1,
		tool = { hammer = { repair = 25 } },
		desc = "Hit a damaged tile to repair it (1 wood).",
	},
	{
		key = "lantern",
		name = "Lantern",
		kind = "tool",
		rarity = "uncommon",
		icon = "🏮",
		stack = 1,
		light = { range = 18, brightness = 0.7 },
		desc = "Light for the night and the caves.",
	},
	-- Weapons
	{
		key = "sharp_stick",
		name = "Sharp Stick",
		kind = "weapon",
		rarity = "common",
		icon = "🔱",
		stack = 1,
		weapon = { dmg = 8, range = 7, arc = 100, cd = 0.6, class = "spear" },
		desc = "Better than fists.",
	},
	{
		key = "spear",
		name = "Spear",
		kind = "weapon",
		rarity = "uncommon",
		icon = "🔱",
		stack = 1,
		weapon = { dmg = 16, range = 8, arc = 100, cd = 0.6, class = "spear" },
		desc = "Crabs, lurkers, sharks at the edge.",
	},
	{
		key = "steel_spear",
		name = "Steel Spear",
		kind = "weapon",
		rarity = "rare",
		icon = "🔱",
		stack = 1,
		weapon = { dmg = 28, range = 8.5, arc = 100, cd = 0.55, class = "spear" },
		desc = "A real weapon.",
	},
	{
		key = "harpoon",
		name = "Harpoon",
		kind = "weapon",
		rarity = "rare",
		icon = "🗡️",
		stack = 1,
		weapon = { dmg = 45, range = 60, cd = 1.4, class = "harpoon", thrown = true },
		desc = "Throw it at what's in the water. It comes back.",
	},
	{
		key = "leviathan_harpoon",
		name = "Leviathan Harpoon",
		kind = "weapon",
		rarity = "legendary",
		icon = "🗡️",
		stack = 1,
		weapon = { dmg = 90, range = 70, cd = 1.2, class = "harpoon", thrown = true },
		desc = "Tipped with a scale. For the Trench.",
	},
	-- Food (§8: the Cookpot; no hunger meter, just healing and buffs)
	{
		key = "coconut",
		name = "Coconut",
		kind = "food",
		rarity = "common",
		icon = "🥥",
		stack = 10,
		food = { heal = 20 },
		desc = "Palm Key's finest.",
	},
	{
		key = "berries",
		name = "Berries",
		kind = "food",
		rarity = "common",
		icon = "🍇",
		stack = 10,
		food = { heal = 15 },
		desc = "Sweet. Gulls want them.",
	},
	{
		key = "raw_fish",
		name = "Raw Fish",
		kind = "food",
		rarity = "common",
		icon = "🐟",
		stack = 10,
		food = { heal = 8 },
		desc = "Cook it.",
	},
	{
		key = "cooked_fish",
		name = "Grilled Fish",
		kind = "food",
		rarity = "common",
		icon = "🍣",
		stack = 10,
		food = { heal = 40 },
		desc = "Hot off the pot.",
	},
	{
		key = "fish_stew",
		name = "Fish Stew",
		kind = "food",
		rarity = "uncommon",
		icon = "🍲",
		stack = 10,
		food = { heal = 60, buff = { key = "hearty", seconds = 120 } },
		desc = "Full health and tougher for two minutes.",
	},
	{
		key = "coconut_cake",
		name = "Coconut Cake",
		kind = "food",
		rarity = "uncommon",
		icon = "🍰",
		stack = 10,
		food = { heal = 30, buff = { key = "swift", seconds = 120 } },
		desc = "Faster feet for two minutes.",
	},
	{
		key = "pearl_tea",
		name = "Pearl Tea",
		kind = "food",
		rarity = "rare",
		icon = "🍵",
		stack = 5,
		food = { heal = 50, buff = { key = "lucky", seconds = 180 } },
		desc = "Luckier casts and nets for three minutes.",
	},
	-- Charts and finds (the ocean's secrets)
	{
		key = "chart",
		name = "Sea Chart",
		kind = "chart",
		rarity = "uncommon",
		icon = "🗺️",
		stack = 1,
		desc = "Marks a place on your map.",
	},
	{
		key = "bottle",
		name = "Message in a Bottle",
		kind = "chart",
		rarity = "uncommon",
		icon = "🍾",
		stack = 1,
		desc = "A note and a drawing of somewhere.",
	},
	{
		key = "blueprint",
		name = "Blueprint",
		kind = "blueprint",
		rarity = "rare",
		icon = "📜",
		stack = 1,
		desc = "Teaches you to build something.",
	},
	{
		key = "supply_crate",
		name = "Supply Crate",
		kind = "resource",
		rarity = "uncommon",
		icon = "📦",
		stack = 1,
		desc = "Open it on the raft.",
	},
	-- Artifacts (§7.4: research, collection, prestige)
	{
		key = "old_compass",
		name = "Old Compass",
		kind = "artifact",
		rarity = "uncommon",
		icon = "🧭",
		stack = 5,
		research = "uncommon",
		desc = "Still points somewhere.",
	},
	{
		key = "ship_bell",
		name = "Ship's Bell",
		kind = "artifact",
		rarity = "rare",
		icon = "🔔",
		stack = 5,
		research = "rare",
		desc = "Rings with a name nobody knows.",
	},
	{
		key = "logbook",
		name = "Captain's Logbook",
		kind = "artifact",
		rarity = "rare",
		icon = "📔",
		stack = 5,
		research = "rare",
		desc = "The last pages are about the thing below.",
	},
	{
		key = "idol",
		name = "Carved Idol",
		kind = "artifact",
		rarity = "epic",
		icon = "🗿",
		stack = 5,
		research = "epic",
		desc = "From the ruin. It watches the water.",
	},
	{
		key = "tooth",
		name = "Leviathan Tooth",
		kind = "artifact",
		rarity = "legendary",
		icon = "🦷",
		stack = 5,
		research = "legendary",
		desc = "Taller than you are.",
	},
	{
		key = "relic",
		name = "Sunken Relic",
		kind = "artifact",
		rarity = "uncommon",
		icon = "🏺",
		stack = 5,
		research = "uncommon",
		desc = "Older than the wreck it was in.",
	},
}

-- A build shortcut in the hotbar: holding it shows that piece's ghost, ACT builds it (data = { piece = key }).
table.insert(Items.list, {
	key = "pin",
	name = "Build Shortcut",
	kind = "pin",
	rarity = "common",
	icon = "📌",
	stack = 1,
	desc = "Hold it to build that piece where you look. Tap ACT to place.",
})

Items.byKey = {}
for _, item in Items.list do
	Items.byKey[item.key] = item
	item.stack = item.stack or 1
end

function Items.get(key)
	return Items.byKey[key]
end

function Items.rarityColor(rarity)
	local r = Items.RARITY[rarity]
	return r and r.color or Items.RARITY.common.color
end

-- Tool kinds a held item gives: "rod", "axe", "pick", "pry", "hammer", or nil.
function Items.toolKind(item)
	if not item or not item.tool then
		return nil
	end
	for k in item.tool do
		return k
	end
	return nil
end

return Items
