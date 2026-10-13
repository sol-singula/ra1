-- The personal cabin's upgrade chain (CabinService builds, World/CabinBuilder draws). Each item sits in its own slot
-- of the compartment, so building it makes something appear right away. The first six are a chain (each needs the
-- one before); after the workbench, the rest can be built in any order. The build board always recommends the
-- lowest-numbered item you can build next.
--   kind     functional | storage | cosmetic | display (shown on the board)
--   cost     materials from your storage
--   plans    a blueprint it uses up (Data/Resources.BLUEPRINTS)
--   needs    an item that must be built first
--   variants choices (the interior finish, the specialist path); `variant` is saved with the item
local CabinItems = {}

CabinItems.list = {
	{
		key = "bunk",
		name = "Repair the bunk",
		short = "Bunk",
		kind = "functional",
		cost = { scrap = 4, cloth = 2 },
		benefit = "A real bed. You wake up here: respawns and pickups bring you to your cabin.",
	},
	{
		key = "lamp",
		name = "Fit a wall lamp",
		short = "Wall lamp",
		kind = "cosmetic",
		cost = { scrap = 3, parts = 1 },
		needs = "bunk",
		benefit = "A warm light over the bed.",
	},
	{
		key = "crate",
		name = "Build a storage crate",
		short = "Crate",
		kind = "storage",
		cost = { wood = 5 },
		needs = "lamp",
		benefit = "+2 room in your field bag.",
	},
	{
		key = "bench",
		name = "Make a bench",
		short = "Bench",
		kind = "cosmetic",
		cost = { wood = 6, cloth = 2 },
		needs = "crate",
		benefit = "A place to sit, with a cushion.",
	},
	{
		key = "worksurface",
		name = "Add a work surface",
		short = "Work surface",
		kind = "functional",
		cost = { wood = 4, scrap = 3 },
		needs = "bench",
		benefit = "Unlocks the workbench.",
	},
	{
		key = "workbench",
		name = "Build a workbench",
		short = "Workbench",
		kind = "functional",
		cost = { scrap = 8, parts = 2 },
		needs = "worksurface",
		benefit = "Salvage: turn 3 scrap into 1 part. Unlocks everything else.",
	},
	{
		key = "insulation",
		name = "Install wall insulation",
		short = "Insulation",
		kind = "cosmetic",
		cost = { cloth = 5, scrap = 3 },
		needs = "workbench",
		benefit = "Quilted walls: warm and quiet.",
	},
	{
		key = "shelf",
		name = "Add a display shelf",
		short = "Shelf",
		kind = "display",
		cost = { wood = 6, parts = 1 },
		needs = "workbench",
		benefit = "Shows the souvenirs you bring back from stops.",
	},
	{
		key = "ceiling",
		name = "Improve the overhead light",
		short = "Ceiling light",
		kind = "cosmetic",
		cost = { parts = 4, scrap = 2 },
		needs = "workbench",
		benefit = "A brass lamp that lights the whole cabin.",
	},
	{
		key = "finish",
		name = "Choose an interior finish",
		short = "Finish",
		kind = "cosmetic",
		cost = { wood = 8 },
		needs = "workbench",
		variants = {
			{ key = "oak", name = "Warm Oak" },
			{ key = "forest", name = "Forest Green" },
			{ key = "midnight", name = "Midnight Blue" },
			{ key = "rose", name = "Dusty Rose" },
		},
		benefit = "New walls and floor. Change the look any time after.",
	},
	{
		key = "mapboard",
		name = "Put up a map board",
		short = "Map board",
		kind = "display",
		cost = { wood = 4, cloth = 3 },
		plans = "map",
		needs = "workbench",
		benefit = "Shows the stops you've seen and your best distance.",
	},
	{
		key = "toolrack",
		name = "Build a tool rack",
		short = "Tool rack",
		kind = "functional",
		cost = { scrap = 5, parts = 2 },
		needs = "workbench",
		benefit = "Collect piles faster (shorter hold).",
	},
	{
		key = "locker",
		name = "Add a personal locker",
		short = "Locker",
		kind = "storage",
		cost = { scrap = 8, parts = 2 },
		needs = "workbench",
		benefit = "+2 more room in your field bag.",
	},
	{
		key = "comfort",
		name = "Add a rug and a plant",
		short = "Rug & plant",
		kind = "cosmetic",
		cost = { cloth = 4, wood = 3 },
		needs = "workbench",
		benefit = "A soft rug and something green.",
	},
	{
		key = "specialist",
		name = "Install a specialist station",
		short = "Specialist",
		kind = "functional",
		cost = { parts = 6, scrap = 4 },
		plans = "specialist",
		needs = "workbench",
		variants = {
			{ key = "mechanic", name = "Mechanic", text = "Scrap piles give 1 extra part sometimes." },
			{ key = "explorer", name = "Explorer", text = "A compass beam points at the stop's blueprint." },
			{ key = "botanist", name = "Botanist", text = "Wood and cloth piles give 1 extra sometimes." },
		},
		benefit = "Pick a path: Mechanic, Explorer or Botanist.",
	},
}

-- Cabin colours (free, the first thing you change): door sign, blanket, curtains, cushion.
CabinItems.COLORS = {
	{ key = "amber", name = "Amber", color = Color3.fromRGB(214, 142, 46) },
	{ key = "crimson", name = "Crimson", color = Color3.fromRGB(170, 44, 52) },
	{ key = "teal", name = "Teal", color = Color3.fromRGB(34, 140, 140) },
	{ key = "plum", name = "Plum", color = Color3.fromRGB(122, 64, 140) },
	{ key = "moss", name = "Moss", color = Color3.fromRGB(96, 130, 60) },
	{ key = "navy", name = "Navy", color = Color3.fromRGB(42, 66, 130) },
}

CabinItems.byKey = {}
CabinItems.colorByKey = {}
for i, item in CabinItems.list do
	item.step = i
	CabinItems.byKey[item.key] = item
end
for _, c in CabinItems.COLORS do
	CabinItems.colorByKey[c.key] = c
end

function CabinItems.variant(item, key)
	for _, v in item.variants or {} do
		if v.key == key then
			return v
		end
	end
	return nil
end

return CabinItems
