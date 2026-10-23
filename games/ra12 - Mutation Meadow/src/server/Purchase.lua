--[[
What a player owns from the Catalog. M9 (PurchaseService) adds live game-pass ownership; until then only passes
granted through a gift (profile.passes) count, so with no gifts every check is false.

  Purchase.owns(player, key) -> boolean
]]
local DataService = require(script.Parent.Services.DataService)

local Purchase = {}

function Purchase.owns(player, key)
	local profile = DataService.get(player)
	return profile ~= nil and profile.passes[key] == true
end

return Purchase
