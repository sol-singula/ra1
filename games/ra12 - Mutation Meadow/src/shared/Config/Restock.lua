-- Patch's shop restock: every intervalSec each seed rolls its chance; a hit stocks qty
-- stylua: ignore start
local stock = {
	carrot      = { chance = 1,    qty = 20 },
	strawberry  = { chance = 1,    qty = 15 },
	blueberry   = { chance = 0.8,  qty = 8 },
	tomato      = { chance = 0.6,  qty = 6 },
	corn        = { chance = 0.4,  qty = 5 },
	pumpkin     = { chance = 0.2,  qty = 3 },
	watermelon  = { chance = 0.1,  qty = 2 },
	dragonfruit = { chance = 0.04, qty = 1 },
	moonmelon   = { chance = 0.05, qty = 1, eventOnly = true },
}
-- stylua: ignore end

return {
	intervalSec = 300,
	order = {
		"carrot",
		"strawberry",
		"blueberry",
		"tomato",
		"corn",
		"pumpkin",
		"watermelon",
		"dragonfruit",
		"moonmelon",
	},
	stock = stock,
}
