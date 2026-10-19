--[[
The SHOP panel (master plan §11): the three shared boosts (lit for everyone), the cash crates, the passes.
Everything says what it does in one line; nothing in it is needed to progress.

  ShopController.refs   panel, rows (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Panel = require(script.Parent.Parent.UI.Panel)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local ShopController = { Name = "ShopController", Order = 60 }

local C = Theme.Color
local refs = { rows = {} }
ShopController.refs = refs
local panel

local function row(parent, k)
	local r = Theme.new("Frame", {
		Name = "Row" .. k,
		Size = UDim2.new(1, -8, 0, 58),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Theme.corner(12), Theme.stroke(2, C.grey) })
	Theme.text({
		Name = "Icon",
		Text = "",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.fromOffset(44, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 30,
		Parent = r,
	})
	Theme.text({
		Name = "Title",
		Text = "",
		Position = UDim2.fromOffset(60, 6),
		Size = UDim2.new(1, -230, 0, 24),
		Font = Theme.Display,
		fit = 18,
		Parent = r,
	})
	Theme.text({
		Name = "Desc",
		Text = "",
		Position = UDim2.fromOffset(60, 30),
		Size = UDim2.new(1, -230, 0, 24),
		TextColor3 = C.muted,
		fit = 14,
		Parent = r,
	})
	local buy = Theme.button({
		Name = "Buy",
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(150, 44),
		BackgroundColor3 = C.good,
		Parent = r,
	})
	buy.Activated:Connect(function()
		local key = r:GetAttribute("Key")
		if key and Theme.busy(buy) then
			Net.send("Shop", "buy", key)
		end
	end)
	return r
end

local function header(parent, text, k)
	return Theme.text({
		Name = "Head" .. k,
		Text = text,
		Size = UDim2.new(1, -8, 0, 26),
		Font = Theme.Display,
		TextColor3 = C.muted,
		fit = 16,
		LayoutOrder = k,
		Parent = parent,
	})
end

local function paint()
	local s = Store.get("shop")
	if not s or not panel then
		return
	end
	for _, c in refs.list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	refs.rows = {}
	local n = 0
	local function section(title, items, owned)
		n += 1
		header(refs.list, title, n)
		for _, e in items do
			n += 1
			local r = row(refs.list, n)
			r.LayoutOrder = n
			r:SetAttribute("Key", e.key)
			r.Icon.Text = e.icon or ""
			r.Title.Text = e.name
			r.Desc.Text = e.desc
			if owned and owned[e.key] then
				r.Buy.Text = "OWNED"
				r.Buy.BackgroundColor3 = C.grey
			elseif e.soon then
				r.Buy.Text = "SOON"
				r.Buy.BackgroundColor3 = C.grey
			else
				r.Buy.Text = Format.robux(e.robux)
				r.Buy.BackgroundColor3 = C.good
			end
			table.insert(refs.rows, r)
		end
	end
	section("SERVER BOOSTS · 10 minutes for everyone", s.boosts)
	section("CASH · sized by your own income", s.products)
	section("PASSES", s.passes, s.owned)
	refs.list.CanvasSize = UDim2.fromOffset(0, n * 64 + 20)
end

function ShopController:init()
	panel = Panel.new("shop", "SHOP", Color3.fromRGB(60, 185, 90), Vector2.new(660, 520))
	refs.panel = panel
	refs.list = Theme.new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0),
		Parent = panel.body,
	})
	Theme.new(
		"UIListLayout",
		{
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Parent = refs.list,
		}
	)
	panel.onOpen = function()
		Net.send("Shop", "open")
		paint()
	end
	Store.Changed:Connect(function(partial)
		if partial.shop and panel:isOpen() then
			paint()
		end
	end)
end

return ShopController
