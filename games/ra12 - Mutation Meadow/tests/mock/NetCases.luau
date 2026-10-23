-- One or more valid and invalid payloads for every remote action (NetSmoke, Rate, Guard)
local G = "0123ABCD-0000-0000-0000-000000000001"

local Cases = { GUID = G }

-- stylua: ignore start
Cases.valid = {
	Plot = {
		plant = { { tile = "1", seed = "carrot" } },
		harvest = { { tile = "12", onFull = "sell" }, { tile = "2" } },
		harvestAll = { {} },
		water = { { tile = "extra3", ownerId = 55 }, { tile = "64" } },
		sprinkler = { { kind = "basic", tile = "5" } },
		pickup = { { tile = "64" } },
	},
	Shop = { buySeed = { { seed = "corn", qty = 5 } }, close = { {} } },
	Upgrade = { buy = { { kind = "sprinklerAdvanced" } } },
	Basket = { sellAll = { {} }, setAutoSell = { { on = true } } },
	Inventory = {
		sellItem = { { id = G } },
		display = { { id = G, pedestal = 7 } },
		undisplay = { { pedestal = 1 } },
	},
	Gift = {
		offer = { { targetId = 55, item = G }, { targetId = -1, crop = "tomato", qty = 200 } },
		respond = { { giftId = "g1", accept = false } },
		cancel = { { giftId = string.rep("x", 40) } },
	},
	Collection = { claim = { { entry = "pumpkin:wetgolden" }, { milestone = 18 } } },
	BlockParty = { water = { {} } },
	Daily = { claim = { {} } },
	Quest = { claim = { { questId = "sunflower5" }, { questId = "keepMut" } } },
	Playtime = { claim = { { index = 3 } } },
	Weekly = { claim = { { updateId = "2026-10-24" } } },
	Lounge = { enter = { {} } },
	Cosmetic = { equip = { { slot = "trail", key = "trail_leaf" }, { slot = "tag" } } },
	Purchase = { prompt = { { key = "gift_vip", friendId = 55 }, { key = "instantGrow", tile = "3" }, { key = "extraRow" } } },
	Settings = {
		set = { { key = "gnomeOn", value = false } },
		gardenName = { { name = "Mason's Meadow 🌻" } },
		patchAck = { { id = "shower", how = "tap" } },
	},
	Social = { like = { { ownerId = 55 } }, visit = { { friendId = 55 } } },
	DevCommand = { run = { { cmd = "grow", args = { "all", 3 } }, { cmd = "reset", args = {} } } },
}

Cases.invalid = {
	Plot = {
		plant = { { tile = "0", seed = "carrot" }, { tile = "1", seed = "banana" } },
		harvest = { { tile = "12", onFull = "burn" } },
		harvestAll = { { x = 1 } },
		water = { { tile = "1", ownerId = 1.5 } },
		sprinkler = { { kind = "mega", tile = "5" } },
		pickup = { { tile = "extra9" } },
	},
	Shop = { buySeed = { { seed = "corn", qty = 2 } }, close = { { a = 1 } } },
	Upgrade = { buy = { { kind = "house" } } },
	Basket = { sellAll = { { 1 } }, setAutoSell = { { on = "true" } } },
	Inventory = {
		sellItem = { { id = "abc" } },
		display = { { id = G, pedestal = 8 } },
		undisplay = { { pedestal = 0 } },
	},
	Gift = {
		offer = { { targetId = 55, crop = "carrot", qty = 201 }, { targetId = 55, item = G, crop = "carrot", qty = 1 } },
		respond = { { giftId = string.rep("x", 41), accept = true } },
		cancel = { {} },
	},
	Collection = { claim = { { entry = "carrot:shiny" }, { milestone = 6 } } },
	BlockParty = { water = { { x = true } } },
	Daily = { claim = { { day = 1 } } },
	Quest = { claim = { { questId = "harvest6" } } },
	Playtime = { claim = { { index = 4 } } },
	Weekly = { claim = { { updateId = "2026-1-24" } } },
	Lounge = { enter = { { now = 1 } } },
	Cosmetic = { equip = { { slot = "trail", key = string.rep("k", 33) }, { slot = "hat" } } },
	Purchase = { prompt = { { key = "gift_starterBundle" }, { key = "vip", tile = "65" } } },
	Settings = {
		set = { { key = "volume", value = true } },
		gardenName = { { name = string.rep("n", 21) } },
		patchAck = { { id = "shower", how = "swipe" } },
	},
	Social = { like = { { ownerId = "55" } }, visit = { { friendId = 0 / 0 } } },
	DevCommand = { run = { { cmd = "grow", args = { 1, 2, 3, 4, 5, 6, 7, 8, 9 } }, { cmd = "grow" } } },
}
-- stylua: ignore end

return Cases
