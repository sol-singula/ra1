-- The 12 MVP recipes (GDD §34.4) with prices and ingredient costs from §36.2.
-- `parts` lists { ingredientId, count, requiredState }. `core` ingredients can never be left out.
-- `drink = true` recipes are poured whole at the Drink Dispenser.
--
-- MVP build simplifications (kept deliberately small, see other/ra1/README.md):
--   * one pantry grab is one portion, so French Fries use 1 potato (canon 3), Onion Rings 1 onion with the
--     batter folded in (canon 2 onions + flour + egg) and Grilled Cheese 2 grilled bread slices + 1 cheese
--     (canon adds grilled cheese ×3 and butter);
--   * drinks skip the chop/mix prep steps and are poured in one go.
local Recipes = {
	RCP_BRG_001 = {
		name = "Basic Burger",
		unlock = 1,
		difficulty = 1,
		price = 9,
		cost = 3,
		prep = 20,
		course = "main",
		parts = {
			{ "ING_BUN", 1, "RAW" },
			{ "ING_BEEF_PATTY", 1, "GRILLED" },
			{ "ING_PICKLE", 1, "CHOPPED" },
			{ "ING_LETTUCE", 1, "CHOPPED" },
			{ "ING_KETCHUP", 1, "RAW" },
		},
		core = { "ING_BUN", "ING_BEEF_PATTY" },
	},
	RCP_BRG_002 = {
		name = "Cheeseburger",
		unlock = 1,
		difficulty = 1,
		price = 10,
		cost = 3.5,
		prep = 22,
		course = "main",
		parts = {
			{ "ING_BUN", 1, "RAW" },
			{ "ING_BEEF_PATTY", 1, "GRILLED" },
			{ "ING_CHEESE", 1, "RAW" },
			{ "ING_TOMATO", 1, "CHOPPED" },
			{ "ING_LETTUCE", 1, "CHOPPED" },
			{ "ING_KETCHUP", 1, "RAW" },
		},
		core = { "ING_BUN", "ING_BEEF_PATTY" },
	},
	RCP_BRG_003 = {
		name = "Double Cheeseburger",
		unlock = 4,
		difficulty = 2,
		price = 12,
		cost = 4.5,
		prep = 30,
		course = "main",
		parts = {
			{ "ING_BUN", 1, "RAW" },
			{ "ING_BEEF_PATTY", 2, "GRILLED" },
			{ "ING_CHEESE", 2, "RAW" },
			{ "ING_LETTUCE", 1, "CHOPPED" },
			{ "ING_KETCHUP", 1, "RAW" },
		},
		core = { "ING_BUN", "ING_BEEF_PATTY" },
	},
	RCP_BRG_006 = {
		name = "Pickle Mountain Burger",
		unlock = 5,
		difficulty = 2,
		price = 12,
		cost = 4.5,
		prep = 32,
		course = "main",
		parts = {
			{ "ING_BUN", 1, "RAW" },
			{ "ING_BEEF_PATTY", 1, "GRILLED" },
			{ "ING_PICKLE", 4, "CHOPPED" },
			{ "ING_CHEESE", 1, "RAW" },
			{ "ING_MUSTARD", 1, "RAW" },
		},
		core = { "ING_BUN", "ING_BEEF_PATTY", "ING_PICKLE" },
	},
	RCP_FRI_001 = {
		name = "French Fries",
		unlock = 1,
		difficulty = 1,
		price = 6,
		cost = 2.3,
		prep = 14,
		course = "side",
		parts = { { "ING_POTATO", 1, "FRIED" }, { "ING_KETCHUP", 1, "RAW" } },
		core = { "ING_POTATO" },
	},
	RCP_FRI_002 = {
		name = "Onion Rings",
		unlock = 4,
		difficulty = 1,
		price = 7,
		cost = 2.5,
		prep = 16,
		course = "side",
		parts = { { "ING_ONION", 1, "FRIED" }, { "ING_MUSTARD", 1, "RAW" } },
		core = { "ING_ONION" },
	},
	RCP_DRK_001 = {
		name = "Fizzy Soda",
		unlock = 1,
		difficulty = 1,
		price = 6,
		cost = 2,
		prep = 6,
		course = "drink",
		drink = true,
		color = Color3.fromRGB(150, 70, 40),
	},
	RCP_DRK_002 = {
		name = "Lemonade",
		unlock = 2,
		difficulty = 1,
		price = 7,
		cost = 2.5,
		prep = 10,
		course = "drink",
		drink = true,
		color = Color3.fromRGB(250, 230, 110),
	},
	RCP_SAN_001 = {
		name = "Grilled Cheese",
		unlock = 2,
		difficulty = 1,
		price = 8,
		cost = 3,
		prep = 18,
		course = "main",
		parts = { { "ING_BREAD_SLICE", 2, "GRILLED" }, { "ING_CHEESE", 1, "RAW" } },
		core = { "ING_BREAD_SLICE", "ING_CHEESE" },
	},
	RCP_SAN_002 = {
		name = "Ham & Cheese Sandwich",
		unlock = 4,
		difficulty = 1,
		price = 9,
		cost = 3.4,
		prep = 20,
		course = "main",
		parts = {
			{ "ING_BREAD_SLICE", 2, "RAW" },
			{ "ING_HAM", 2, "CHOPPED" },
			{ "ING_CHEESE", 1, "RAW" },
			{ "ING_MUSTARD", 1, "RAW" },
		},
		core = { "ING_BREAD_SLICE", "ING_HAM" },
	},
	RCP_SAN_003 = {
		name = "Hot Dog Classic",
		unlock = 3,
		difficulty = 1,
		price = 9,
		cost = 3.2,
		prep = 18,
		course = "main",
		parts = {
			{ "ING_HOTDOG_BUN", 1, "RAW" },
			{ "ING_HOTDOG", 1, "GRILLED" },
			{ "ING_KETCHUP", 1, "RAW" },
			{ "ING_MUSTARD", 1, "RAW" },
			{ "ING_ONION", 1, "CHOPPED" },
			{ "ING_PICKLE", 1, "CHOPPED" },
		},
		core = { "ING_HOTDOG_BUN", "ING_HOTDOG" },
	},
	RCP_SAL_001 = {
		name = "Garden Salad",
		unlock = 3,
		difficulty = 1,
		price = 7,
		cost = 2.5,
		prep = 16,
		course = "main",
		parts = {
			{ "ING_LETTUCE", 2, "CHOPPED" },
			{ "ING_TOMATO", 1, "CHOPPED" },
			{ "ING_CUCUMBER", 1, "CHOPPED" },
			{ "ING_RANCH", 1, "RAW" },
		},
		core = { "ING_LETTUCE" },
	},
}

-- Display order for menus and the pantry.
local ORDER = {
	"RCP_BRG_001",
	"RCP_BRG_002",
	"RCP_FRI_001",
	"RCP_DRK_001",
	"RCP_DRK_002",
	"RCP_SAN_001",
	"RCP_SAN_003",
	"RCP_SAL_001",
	"RCP_BRG_003",
	"RCP_FRI_002",
	"RCP_SAN_002",
	"RCP_BRG_006",
}

for i, id in ORDER do
	local r = Recipes[id]
	r.id = id
	r.sort = i
	r.parts = r.parts or {}
	r.core = r.core or {}
end

return table.freeze({
	byId = Recipes,
	order = ORDER,
	-- [34.4] "The four L1 recipes fill TIER_01's 4 menu slots."
	defaultMenu = { "RCP_BRG_001", "RCP_BRG_002", "RCP_FRI_001", "RCP_DRK_001" },
})
