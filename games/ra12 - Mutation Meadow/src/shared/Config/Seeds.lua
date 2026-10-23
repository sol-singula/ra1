--[[
The nine seeds, keyed by seed key. growSec is also the regrow time between harvests. gate says when the shop
starts offering the seed: { start = true }, { lifetimeCoins = n }, { plotLevel = n } (eventOnly: only in event
restocks).
]]
-- stylua: ignore start
return {
	carrot      = { key = "carrot",      name = "Carrot",       tier = 1, buy = 5,      growSec = 30,    sell = 10,    harvests = 1,  gate = { start = true } },
	strawberry  = { key = "strawberry",  name = "Strawberry",   tier = 2, buy = 25,     growSec = 45,    sell = 14,    harvests = 5,  gate = { start = true } },
	blueberry   = { key = "blueberry",   name = "Blueberry",    tier = 3, buy = 80,     growSec = 90,    sell = 36,    harvests = 5,  gate = { lifetimeCoins = 300 } },
	tomato      = { key = "tomato",      name = "Tomato",       tier = 4, buy = 300,    growSec = 180,   sell = 110,   harvests = 5,  gate = { plotLevel = 2 } },
	corn        = { key = "corn",        name = "Corn",         tier = 5, buy = 1000,   growSec = 360,   sell = 330,   harvests = 5,  gate = { plotLevel = 2 } },
	pumpkin     = { key = "pumpkin",     name = "Pumpkin",      tier = 6, buy = 4000,   growSec = 720,   sell = 4350,  harvests = 1,  gate = { plotLevel = 3 } },
	watermelon  = { key = "watermelon",  name = "Watermelon",   tier = 7, buy = 12000,  growSec = 1800,  sell = 3250,  harvests = 6,  gate = { plotLevel = 3 } },
	dragonfruit = { key = "dragonfruit", name = "Dragon Fruit", tier = 8, buy = 50000,  growSec = 3600,  sell = 9750,  harvests = 8,  gate = { plotLevel = 4 } },
	moonmelon   = { key = "moonmelon",   name = "Moon Melon",   tier = 9, buy = 200000, growSec = 10800, sell = 35000, harvests = 10, gate = { plotLevel = 4, eventOnly = true } },
}
-- stylua: ignore end
