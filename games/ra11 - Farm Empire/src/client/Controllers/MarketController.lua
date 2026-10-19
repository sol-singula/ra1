--[[
The MARKET panel: the day's orders from the town board, what each wants and pays, DELIVER when the stock has it.
Opens from the board's prompt in the square or the MARKET button.

  MarketController.refs   panel, rows (tests)
]]
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crops = require(ReplicatedStorage.Shared.Data.Crops)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Panel = require(script.Parent.Parent.UI.Panel)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local MarketController = { Name = "MarketController", Order = 63 }

local C = Theme.Color
local refs = { rows = {} }
MarketController.refs = refs
local panel

local function row(parent, k)
	local r = Theme.new("Frame", {
		Name = "Row" .. k,
		Size = UDim2.new(1, -8, 0, 64),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Theme.corner(12), Theme.stroke(2, C.grey) })
	Theme.text({
		Name = "Icon",
		Text = "",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(48, 48),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 34,
		Parent = r,
	})
	Theme.text({
		Name = "Title",
		Text = "",
		Position = UDim2.fromOffset(64, 6),
		Size = UDim2.new(1, -240, 0, 26),
		Font = Theme.Display,
		fit = 19,
		Parent = r,
	})
	Theme.text({
		Name = "Desc",
		Text = "",
		Position = UDim2.fromOffset(64, 32),
		Size = UDim2.new(1, -240, 0, 26),
		TextColor3 = C.muted,
		fit = 15,
		Parent = r,
	})
	local b = Theme.button({
		Name = "Deliver",
		Text = "DELIVER",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(160, 46),
		BackgroundColor3 = C.good,
		Parent = r,
	})
	b.Activated:Connect(function()
		local id = r:GetAttribute("Id")
		if id then
			Net.send("Market", "deliver", id)
		end
	end)
	return r
end

local function paint()
	local m = Store.get("market")
	if not m or not panel then
		return
	end
	local list = m.orders or {}
	refs.empty.Visible = #list == 0
	for k, o in list do
		local r = refs.rows[k] or row(refs.list, k)
		refs.rows[k] = r
		local c = Crops[o.crop]
		r.Visible = true
		r.LayoutOrder = k
		r:SetAttribute("Id", o.id)
		r.Icon.Text = c and c.icon or "📦"
		r.Title.Text = `{o.name}: {o.n} {c and c.name or o.crop}`
		r.Desc.Text = `Pays {Format.cash(o.pays)} ({o.bonus}x the counter) · you have {o.have or 0}`
		if o.done then
			r.Deliver.Text = "DONE"
			r.Deliver.BackgroundColor3 = C.grey
		else
			r.Deliver.Text = `DELIVER {Format.cash(o.pays)}`
			r.Deliver.BackgroundColor3 = (o.have or 0) >= o.n and C.good or C.grey
		end
	end
	for k = #list + 1, #refs.rows do
		refs.rows[k].Visible = false
	end
	refs.list.CanvasSize = UDim2.fromOffset(0, #list * 72 + 10)
end

function MarketController:init()
	panel = Panel.new("market", "MARKET ORDERS", Color3.fromRGB(206, 58, 50), Vector2.new(640, 440))
	refs.panel = panel
	refs.empty = Theme.text({
		Name = "Empty",
		Text = "The market buys from shops, not stands. Build the Fruit Shop and the day's orders appear here.",
		Size = UDim2.new(1, 0, 0, 60),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.muted,
		fit = 17,
		Parent = panel.body,
	})
	refs.list = Theme.new("ScrollingFrame", {
		Name = "List",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0),
		Parent = panel.body,
	})
	Theme.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = refs.list,
	})
	panel.onOpen = function()
		Net.send("Market", "open")
		paint()
	end
	Store.Changed:Connect(function(partial)
		if partial.market and panel:isOpen() then
			paint()
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt.Name == "Market" then
			Bus.Panel:Fire("market")
		end
	end)
end

return MarketController
