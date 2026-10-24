local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Store = require("./mock/Store")

local test, eq = Assert.test, Assert.eq

local function equip(ctx, p, slot, key)
	return { Farm.call(ctx, p, "Cosmetic", "equip", { slot = slot, key = key }) }
end

local function rejoin(ctx, p)
	ctx.engine:removePlayer(p)
	ctx.engine:advance(7)
	local again = Farm.join(ctx, p.UserId)
	ctx.engine:advance(15)
	return again
end

test("equipping an unowned key is refused; the slot must match the key", function()
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	eq(equip(ctx, p, "trail", "trail_leaf"), { false, "not_owned" })
	ctx.Data.get(p).cosmetics.owned.trail_leaf = true
	eq(equip(ctx, p, "tag", "trail_leaf"), { false, "wrong_slot" })
	eq(equip(ctx, p, "trail", "trail_leaf"), { true })
	eq(equip(ctx, p, "tag", "tag_vip"), { false, "not_owned" }, "a VIP perk needs VIP")
	ctx.Data.get(p).passes.vip = true
	eq(equip(ctx, p, "tag", "tag_vip"), { true })
	ctx.Data.get(p).cosmetics.owned.title_master = true
	eq(equip(ctx, p, "tag", "title_master"), { true }, "titles go in the tag slot")
end)

test("equip and unequip persist across a rejoin, and draw for everyone", function()
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	local owned = ctx.Data.get(p).cosmetics.owned
	owned.trail_firefly, owned.tag_star, owned.theme_starry, owned.can_crystal = true, true, true, true
	eq(equip(ctx, p, "trail", "trail_firefly"), { true })
	eq(equip(ctx, p, "tag", "tag_star"), { true })
	eq(equip(ctx, p, "theme", "theme_starry"), { true })
	eq(equip(ctx, p, "can", "can_crystal"), { true })
	local root = p.Character.HumanoidRootPart
	eq(root.CosmeticTrail:GetAttribute("Key"), "trail_firefly")
	eq(root.CosmeticTag.Text.Text, "Star Farmer")
	eq(ctx.Plot.plotOf(p):GetAttribute("Theme"), "theme_starry")
	eq(p.Character:GetAttribute("CanSkin"), "can_crystal")
	p = rejoin(ctx, p)
	eq(
		ctx.Data.get(p).cosmetics.equipped,
		{ trail = "trail_firefly", tag = "tag_star", theme = "theme_starry", can = "can_crystal" }
	)
	eq(equip(ctx, p, "trail", nil), { true })
	p = rejoin(ctx, p)
	eq(ctx.Data.get(p).cosmetics.equipped.trail, nil)
	eq(ctx.Data.get(p).cosmetics.equipped.tag, "tag_star")
end)

test("the lantern stands by the sign while owned", function()
	local ctx = Store.setup()
	local p = Farm.join(ctx, 1)
	eq(ctx.Plot.plotOf(p):FindFirstChild("Lantern"), nil)
	ctx.Data.get(p).cosmetics.owned.deco_lantern = true
	ctx.engine:run(function()
		ctx.Cosmetics.render(p)
	end)
	Assert.truthy(ctx.Plot.plotOf(p):FindFirstChild("Lantern"), "placed")
end)
