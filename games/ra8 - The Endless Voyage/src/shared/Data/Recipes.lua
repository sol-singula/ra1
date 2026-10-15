--[[
What the stations make (master plan §8: a small set of useful choices, each with a clear purpose and a readable
cost). Materials come from your backpack first, then the raft's storage boxes.

  station    workbench | refinery | engineering | research | cookpot | decor (the piece on the raft)
  count      how many you get
  blueprint  true: found first (a supply crate, an island, a wreck, a research milestone)
  unlock     { kind = "color", key } instead of an item: the Decorative Workshop's dyes
]]
local Recipes = {}

Recipes.STATIONS = {
	workbench = { name = "Workbench", icon = "🛠️" },
	refinery = { name = "Refining Station", icon = "🏭" },
	engineering = { name = "Engineering Bench", icon = "⚗️" },
	research = { name = "Research Station", icon = "📚" },
	cookpot = { name = "Cookpot", icon = "🍲" },
	decor = { name = "Decorative Workshop", icon = "🎨" },
}

Recipes.list = {
	-- Workbench: the basics
	{ item = "basic_hook", station = "workbench", cost = { wood = 2, rope = 1 } },
	{ item = "iron_hook", station = "workbench", cost = { metal = 4, rope = 2 } },
	{ item = "fishing_rod", station = "workbench", cost = { wood = 3, rope = 2 } },
	{ item = "hammer", station = "workbench", cost = { wood = 2, metal = 1 } },
	{ item = "axe", station = "workbench", cost = { wood = 3, metal = 2 } },
	{ item = "pickaxe", station = "workbench", cost = { wood = 3, metal = 3 } },
	{ item = "crowbar", station = "workbench", cost = { metal = 4 } },
	{ item = "sharp_stick", station = "workbench", cost = { wood = 2 } },
	{ item = "spear", station = "workbench", cost = { wood = 3, metal = 2 } },
	{ item = "lantern", station = "workbench", cost = { metal = 2, scrap = 2 } },
	-- Refining Station: processed materials (§7.4)
	{ item = "plank", count = 2, station = "refinery", cost = { wood = 3 } },
	{ item = "rope", count = 2, station = "refinery", cost = { fiber = 3 } },
	{ item = "cloth", count = 2, station = "refinery", cost = { palm = 3 } },
	{ item = "metal", count = 2, station = "refinery", cost = { ore = 2 } },
	{ item = "glass", count = 2, station = "refinery", cost = { stone = 4, scrap = 1 } },
	{ item = "gear", station = "refinery", cost = { metal = 4, scrap = 2 } },
	-- Engineering Bench: the good tools (some found first)
	{ item = "deep_rod", station = "engineering", cost = { plank = 2, metal = 4, gear = 1 } },
	{ item = "steel_axe", station = "engineering", cost = { metal = 6, plank = 2 } },
	{ item = "steel_pick", station = "engineering", cost = { metal = 6, plank = 2 } },
	{ item = "steel_spear", station = "engineering", cost = { metal = 6, plank = 2 } },
	{ item = "long_hook", station = "engineering", cost = { metal = 6, rope = 4, gear = 1 }, blueprint = true },
	{ item = "harpoon", station = "engineering", cost = { metal = 8, rope = 4, gear = 1 }, blueprint = true },
	{ item = "salvage_claw", station = "engineering", cost = { metal = 10, gear = 3, old_tech = 1 }, blueprint = true },
	{
		item = "leviathan_harpoon",
		station = "engineering",
		cost = { leviathan_scale = 2, metal = 10, gear = 3 },
		blueprint = true,
	},
	-- Cookpot: food that heals and helps (no hunger meter: §4 "no survival-meter tutorial")
	{ item = "cooked_fish", station = "cookpot", cost = { raw_fish = 1 } },
	{ item = "fish_stew", station = "cookpot", cost = { raw_fish = 2, coconut = 1 } },
	{ item = "coconut_cake", station = "cookpot", cost = { coconut = 2, berries = 1 } },
	{ item = "pearl_tea", station = "cookpot", cost = { pearl = 1, berries = 2 } },
	-- Decorative Workshop: dyes for sails, banners and flags, and the deck's paint
	{
		unlock = { kind = "color", key = "red" },
		name = "Red Dye",
		icon = "🟥",
		station = "decor",
		cost = { coral = 1, cloth = 1 },
	},
	{
		unlock = { kind = "color", key = "blue" },
		name = "Blue Dye",
		icon = "🟦",
		station = "decor",
		cost = { coral = 1, cloth = 1 },
	},
	{
		unlock = { kind = "color", key = "green" },
		name = "Green Dye",
		icon = "🟩",
		station = "decor",
		cost = { fiber = 2, cloth = 1 },
	},
	{
		unlock = { kind = "color", key = "black" },
		name = "Black Dye",
		icon = "⬛",
		station = "decor",
		cost = { scrap = 3, cloth = 1 },
	},
	{
		unlock = { kind = "color", key = "gold" },
		name = "Gold Dye",
		icon = "🟨",
		station = "decor",
		cost = { pearl = 1, cloth = 2 },
	},
	{
		unlock = { kind = "deck", key = "dark" },
		name = "Dark Stain",
		icon = "🟫",
		station = "decor",
		cost = { scrap = 2, plank = 2 },
	},
	{
		unlock = { kind = "deck", key = "white" },
		name = "Whitewash",
		icon = "⬜",
		station = "decor",
		cost = { stone = 2, plank = 2 },
	},
}

Recipes.byStation = {}
Recipes.byId = {}
Recipes.byItem = {}
for i, r in Recipes.list do
	r.id = r.item or (r.unlock.kind .. "_" .. r.unlock.key)
	r.count = r.count or 1
	Recipes.byId[r.id] = r
	if r.item then
		Recipes.byItem[r.item] = r
	end
	Recipes.byStation[r.station] = Recipes.byStation[r.station] or {}
	table.insert(Recipes.byStation[r.station], r)
	_ = i
end

function Recipes.get(id)
	return Recipes.byId[id]
end

return Recipes
