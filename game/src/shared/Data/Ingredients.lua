-- Basic ingredients used by the MVP recipes (GDD §7). Basic ingredients are unlimited: their cost is
-- netted from the sale when the dish is served [C9]. `grill` / `fry` are T_ready seconds at Lv1 (§6 recipe steps).
-- `color` is the greybox colour of the carried piece until real food models exist.
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Ingredients = {
	ING_BUN = { name = "Squishy Sesame Bun", cost = 0.5, color = rgb(222, 170, 92) },
	ING_BEEF_PATTY = { name = "Beefy Puck Patty", cost = 1.0, color = rgb(214, 108, 108), grill = 8 },
	ING_CHEESE = { name = "Melty Cheese Square", cost = 0.5, color = rgb(255, 205, 64) },
	ING_LETTUCE = { name = "Crunchy Lettuce Leaf", cost = 0.5, color = rgb(108, 196, 84), chop = true },
	ING_TOMATO = { name = "Round Tomato", cost = 0.5, color = rgb(232, 72, 60), chop = true },
	ING_ONION = { name = "Tear-Jerk Onion", cost = 0.5, color = rgb(226, 206, 232), chop = true, fry = 6 },
	ING_PICKLE = { name = "Pickle Spear", cost = 0.5, color = rgb(92, 150, 60), chop = true },
	ING_KETCHUP = { name = "Ketchup Squirt", cost = 0.5, color = rgb(200, 30, 30) },
	ING_MUSTARD = { name = "Mustard Zigzag", cost = 0.5, color = rgb(240, 200, 30) },
	ING_RANCH = { name = "Ranch Drizzle", cost = 0.5, color = rgb(246, 242, 228) },
	ING_POTATO = { name = "Lumpy Potato", cost = 0.6, color = rgb(196, 160, 104), fry = 7 },
	ING_BREAD_SLICE = { name = "Square Bread Slice", cost = 0.5, color = rgb(238, 214, 160), grill = 6 },
	ING_HAM = { name = "Pink Ham Slab", cost = 0.7, color = rgb(244, 150, 170), chop = true },
	ING_HOTDOG_BUN = { name = "Long Boi Bun", cost = 0.5, color = rgb(214, 160, 90) },
	ING_HOTDOG = { name = "Snappy Hot Dog", cost = 0.7, color = rgb(196, 84, 64), grill = 6 },
	ING_CUCUMBER = { name = "Cool Cucumber", cost = 0.5, color = rgb(70, 160, 90), chop = true },
}

for id, row in Ingredients do
	row.id = id
end

return table.freeze(Ingredients)
