local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

test("a gift the friend already owns can't be sent", function()
	local engine = Engine.new()
	local Gifting = engine:require(engine:module("Shared/Gifting"))
	local friend = { passes = { vip = true }, cosmetics = { trail_leaf = true } }
	eq({ Gifting.canGift("gift_vip", friend) }, { false, "owned" })
	eq({ Gifting.canGift("gift_trail_leaf", friend) }, { false, "owned" })
	eq(Gifting.canGift("gift_gnome", friend), true)
	eq(Gifting.canGift("gift_tag_star", {}), true)
	eq({ Gifting.canGift("gift_starterBundle", {}) }, { false, "unknown" })
end)
