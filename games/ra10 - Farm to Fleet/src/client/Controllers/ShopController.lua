--[[
The SHOP panel (Net "Shop", ShopService; Data/Shop). Three rows of cards: Robux products (Gem packs, the Starter
Pack, Instant Harvest), the passes (OWNED once bought), and what Gems buy (Ripen Everything, Feed Everyone, golden
seeds, Cash Rush with its time left, a Special Order). A Robux price shows the real Robux symbol; one not on sale
yet says SOON.

  ShopController.refs   the panel's pieces (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Panel = require(script.Parent.Parent.UI.Panel)
local Theme = require(script.Parent.Parent.UI.Theme)

local ShopController = { Name = "ShopController", Order = 51 }

local refs = { products = {}, passes = {}, gems = {} }
ShopController.refs = refs
local GREEN = Color3.fromRGB(60, 185, 90)
local CARD_W, CARD_H = 150, 112

local function card(parent, x, y, kind, i)
	local frame = Theme.card({
		Name = kind .. i,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		Visible = false,
		Parent = parent,
	})
	local row = { frame = frame }
	row.name = Theme.text({
		Name = "Title",
		Text = "",
		Font = Theme.Display,
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 15,
		Parent = frame,
	})
	row.text = Theme.text({
		Name = "Text",
		Text = "",
		Position = UDim2.fromOffset(6, 26),
		Size = UDim2.new(1, -12, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 12,
		Parent = frame,
	})
	row.buy = Theme.button({
		Name = "Buy",
		Text = "",
		BackgroundColor3 = GREEN,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -16, 0, 34),
		Parent = frame,
	})
	row.buy.Activated:Connect(function()
		if row.key and not row.owned then
			Bus.Tap:Fire("shop_" .. row.key)
			Net.send("Shop", row.currency, row.key)
		end
	end)
	return row
end

local function fill(list, items, currency, label)
	for i, row in list do
		local it = items and items[i]
		row.frame.Visible = it ~= nil
		if it then
			row.key, row.currency, row.owned = it.key, currency, it.owned == true
			row.name.Text = it.name
			row.text.Text = it.text
			row.buy.Text = label(it)
			row.buy.BackgroundColor3 = it.owned and Color3.fromRGB(150, 150, 150)
				or (it.soon and Color3.fromRGB(120, 140, 170))
				or (currency == "gems" and Theme.SHARD or GREEN)
		end
	end
end

local function robux(it)
	if it.owned then
		return "OWNED"
	end
	return it.soon and "SOON" or Format.robux(it.robux)
end

function ShopController:init()
	local panel = Panel.new("shop", "SHOP", GREEN, Vector2.new(820, 450))
	refs.panel = panel
	local body = panel.body
	local function heading(text, y)
		Theme.text({
			Name = "Heading",
			Text = text,
			Font = Theme.Display,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 18),
			TextColor3 = Color3.fromRGB(90, 90, 100),
			fit = 14,
			Parent = body,
		})
	end
	heading("GEMS AND BOOSTS", 0)
	for i = 1, 5 do
		refs.products[i] = card(body, (i - 1) * (CARD_W + 8), 20, "Product", i)
	end
	heading("PASSES: FOREVER", 136)
	for i = 1, 4 do
		refs.passes[i] = card(body, (i - 1) * (CARD_W + 8), 156, "Pass", i)
	end
	heading("SPEND GEMS", 274)
	refs.boost = Theme.text({
		Name = "Boost",
		Text = "",
		Font = Theme.Display,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 274),
		Size = UDim2.fromOffset(300, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(200, 120, 20),
		fit = 14,
		Parent = body,
	})
	for i = 1, 5 do
		refs.gems[i] = card(body, (i - 1) * (CARD_W + 8), 294, "Gem", i)
	end
	panel.onOpen = function()
		Net.send("Shop", "open")
	end
	Net.listen("Shop", function(m)
		if type(m) ~= "table" then
			return
		end
		fill(refs.products, m.products, "robux", robux)
		fill(refs.passes, m.passes, "robux", robux)
		fill(refs.gems, m.gems, "gems", function(it)
			return `💎 {it.gems}`
		end)
		refs.boost.Text = (m.boostLeft or 0) > 0 and `CASH RUSH x2: {Format.time(m.boostLeft)} left` or ""
	end)
end

return ShopController
