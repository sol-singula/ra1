--[[
What the camp's stations make (master plan §3 "collect & craft", §7). Materials come from your own backpack first,
then from the camp's shared storage chest, so stocking the chest helps everyone.

  station   workbench (tier 1) | anvil (tier 3) | cookpot (tier 3) | campfire
  tier      the camp tier the recipe needs (more recipes open as the camp grows)
  count     how many you get
]]
local Recipes = {}

Recipes.STATIONS = {
	workbench = { name = "Workbench", icon = "🛠️" },
	anvil = { name = "Anvil", icon = "⚒️" },
	cookpot = { name = "Cookpot", icon = "🍲" },
	campfire = { name = "Campfire", icon = "🔥" },
}

Recipes.list = {
	-- Workbench: the basics (day 1)
	{ item = "stone_axe", station = "workbench", tier = 1, cost = { wood = 4, stone = 3 } },
	{ item = "branch_club", station = "workbench", tier = 1, cost = { wood = 6 } },
	{ item = "stone_spear", station = "workbench", tier = 1, cost = { wood = 5, stone = 2, fiber = 1 } },
	{ item = "torch", station = "workbench", tier = 1, cost = { wood = 2, fiber = 1 } },
	{ item = "bandage", station = "workbench", tier = 1, cost = { fiber = 3 } },
	{ item = "snare", station = "workbench", tier = 1, cost = { fiber = 4, wood = 2 } },
	{ item = "arrows", count = 10, station = "workbench", tier = 1, cost = { wood = 3, stone = 1 } },
	-- Workbench: the Outpost
	{ item = "short_bow", station = "workbench", tier = 2, cost = { wood = 6, fiber = 4 } },
	{ item = "spiked_club", station = "workbench", tier = 2, cost = { wood = 6, scrap = 3 } },
	{ item = "bark_armor", station = "workbench", tier = 2, cost = { wood = 12, fiber = 6 } },
	{ item = "small_pack", station = "workbench", tier = 2, cost = { fiber = 10, scrap = 2 } },
	{ item = "lantern", station = "workbench", tier = 2, cost = { scrap = 4, glowcap = 1 } },
	{ item = "flare", station = "workbench", tier = 2, cost = { scrap = 1, fiber = 2 } },
	{ item = "firecracker", station = "workbench", tier = 2, cost = { scrap = 1, fiber = 1, wood = 1 } },
	-- Anvil: the Fort
	{ item = "iron_axe", station = "anvil", tier = 3, cost = { scrap = 6, wood = 4 } },
	{ item = "iron_spear", station = "anvil", tier = 3, cost = { scrap = 6, wood = 5 } },
	{ item = "iron_hammer", station = "anvil", tier = 3, cost = { scrap = 8, wood = 4, stone = 4 } },
	{ item = "bear_trap", station = "anvil", tier = 3, cost = { scrap = 5 } },
	{ item = "hunter_bow", station = "anvil", tier = 3, cost = { scrap = 3, wood = 8, fiber = 6 } },
	{ item = "big_pack", station = "anvil", tier = 3, cost = { fiber = 16, scrap = 6 } },
	-- Anvil: the Stronghold
	{ item = "steel_axe", station = "anvil", tier = 4, cost = { scrap = 12, glowcap = 2, wood = 4 } },
	{ item = "iron_plate", station = "anvil", tier = 4, cost = { scrap = 14, fiber = 4 } },
	{ item = "crossbow", station = "anvil", tier = 4, cost = { scrap = 10, wood = 10, glowcap = 1 } },
	-- Cookpot
	{ item = "stew", station = "cookpot", tier = 3, cost = { berries = 3, cooked_meat = 1, herb = 1 } },
	{ item = "medkit", station = "cookpot", tier = 3, cost = { herb = 3, fiber = 2, glowcap = 1 } },
	{ item = "speed_brew", station = "cookpot", tier = 3, cost = { herb = 2, berries = 2, glowcap = 1 } },
	{ item = "shield_brew", station = "cookpot", tier = 3, cost = { herb = 3, stone = 2, glowcap = 1 } },
	-- Campfire
	{ item = "cooked_meat", station = "campfire", tier = 1, cost = { raw_meat = 1 } },
}

Recipes.byItem = {}
Recipes.byStation = {}
for i, r in Recipes.list do
	r.id = i
	r.count = r.count or 1
	Recipes.byItem[r.item] = r
	Recipes.byStation[r.station] = Recipes.byStation[r.station] or {}
	table.insert(Recipes.byStation[r.station], r)
end

function Recipes.get(id)
	return Recipes.list[id]
end

return Recipes
