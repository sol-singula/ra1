-- MVP order modifications: the OMIT rows from §6.18 that the starter stations can satisfy.
-- `omit` is a list of ingredient ids (any one present in the recipe makes the mod applicable);
-- `chance` is the §6.18 frequency per eligible item. A mod never removes a recipe's core ingredient.
local Modifications = {
	{ id = "MOD_001", text = "Hold the pickles. Hold them far, far away.", omit = { "ING_PICKLE" }, chance = 0.05 },
	{ id = "MOD_002", text = "No cheese. I know what I said.", omit = { "ING_CHEESE" }, chance = 0.05 },
	{ id = "MOD_003", text = "No onions. They make all nine of my eyes cry.", omit = { "ING_ONION" }, chance = 0.05 },
	{ id = "MOD_004", text = "No lettuce. Leaves are for trees.", omit = { "ING_LETTUCE" }, chance = 0.05 },
	{ id = "MOD_005", text = "No tomato. It looked at me funny.", omit = { "ING_TOMATO" }, chance = 0.05 },
	{
		id = "MOD_006",
		text = "No sauce. Sauce is too loud.",
		omit = { "ING_KETCHUP", "ING_MUSTARD", "ING_RANCH" },
		chance = 0.06,
	},
}

local byId = {}
for _, row in Modifications do
	byId[row.id] = row
end

return table.freeze({ list = Modifications, byId = byId })
