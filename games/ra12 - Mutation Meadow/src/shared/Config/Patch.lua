--[[
Patch the shopkeeper's lines. kind: bubble (over Patch), shopBubble (when the shop opens), toast, toast+board.
flag: shown once per profile (a string names the profile field that records it). hideOn: the action that
dismisses it.
]]
-- stylua: ignore start
local lines = {
	plant      = { text = "Plant here!",                                  kind = "bubble",      seconds = 5, flag = true, hideOn = "plant" },
	shopHello  = { text = "Hi, I'm Patch! New seeds every 5 minutes.",    kind = "shopBubble",  seconds = 5, flag = true },
	shopAgain  = { text = "Hi again! Pick some seeds.",                   kind = "shopBubble",  seconds = 3 },
	restock    = { text = "Fresh seeds are in!",                          kind = "bubble",      seconds = 3, rangeStuds = 40 },
	rare       = { text = "%s in stock! Come see!",                       kind = "toast",       seconds = 4, minTier = 7, setting = "patchAlerts" },
	shower     = { text = "Rain's coming! Wet crops sell for 2x.",        kind = "toast",       seconds = 5, flag = true },
	mutation   = { text = "Ooh, a %s crop! Tap it to keep it.",           kind = "toast",       seconds = 5, flag = true, hideOn = "harvest" },
	blockParty = { text = "Tap the sunflower to help it bloom!",          kind = "toast",       seconds = 5, flag = true, hideOn = "water" },
	update     = { text = "New update! Grab your free gift.",             kind = "toast+board", seconds = 5, flag = "weekly.lineSeen" },
}
-- stylua: ignore end

return {
	lines = lines,
	order = { "plant", "shopHello", "shopAgain", "restock", "rare", "shower", "mutation", "blockParty", "update" },
	queueGapSec = 2,
	maxChars = 60,
	tapToHide = true,
	prompt = { actionText = "Shop", objectText = "Patch's Seed Shop", maxDistance = 10, hold = 0 },
	serverRange = 12,
}
