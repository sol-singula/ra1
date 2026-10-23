--[[
Who can be sent what. The Gift tab (M9) hides, or disables, a gift the friend already owns.

  Gifting.canGift(giftKey, friend) -> true | false, reason
      giftKey   a Config.Catalog.gifts key ("gift_vip")
      friend    { passes = { [key] = true }, cosmetics = { [key] = true } }: what the friend owns (passes from
                live game-pass ownership plus gifted ones, cosmetics from their profile)
      reason    "unknown" | "owned"
]]
local Config = require(script.Parent.Config)

local Gifting = {}

function Gifting.canGift(giftKey, friend)
	local gift = Config.Catalog.gifts[giftKey]
	if not gift then
		return false, "unknown"
	end
	if (friend.passes and friend.passes[gift.of]) or (friend.cosmetics and friend.cosmetics[gift.of]) then
		return false, "owned"
	end
	return true
end

return Gifting
