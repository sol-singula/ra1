--[[
The UPGRADES panel (master plan §15): the five branches as tabs, each upgrade a row with its name, what it does,
its level and a BUY button (grey when you can't afford it, "MAXED" when it's done). The recommended one carries a
gold RECOMMENDED tag and sits first. A locked branch's rows say what stage they need.

  UpgradeController.refs   panel, rows (tests)
  UpgradeController.open()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Business = require(ReplicatedStorage.Shared.Data.Business)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)
local Bus = require(script.Parent.Parent.UI.Bus)
local Panel = require(script.Parent.Parent.UI.Panel)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local UpgradeController = { Name = "UpgradeController", Order = 35 }

local C = Theme.Color
local GOLD = Color3.fromRGB(255, 205, 50)
local refs = { rows = {}, tabs = {} }
UpgradeController.refs = refs
local panel
local branch = "all"

local BRANCHES = {
	{ key = "all", label = "ALL" },
	{ key = "production", label = "FARM" },
	{ key = "animals", label = "ANIMALS" },
	{ key = "machinery", label = "MACHINES" },
	{ key = "retail", label = "STORE" },
	{ key = "logistics", label = "LOGISTICS" },
}
local BRANCH_COLOR = {
	production = Color3.fromRGB(86, 192, 96),
	machinery = Color3.fromRGB(228, 60, 50),
	retail = Color3.fromRGB(60, 150, 240),
	logistics = Color3.fromRGB(255, 146, 36),
	prestige = Color3.fromRGB(160, 100, 235),
	animals = Color3.fromRGB(214, 150, 90),
}

local function row(parent, k)
	local r = Theme.new("Frame", {
		Name = "Row" .. k,
		Size = UDim2.new(1, -8, 0, 62),
		BackgroundColor3 = C.white,
		BorderSizePixel = 0,
		Parent = parent,
	}, { Theme.corner(12), Theme.stroke(2, C.grey) })
	Theme.new("Frame", {
		Name = "Stripe",
		Size = UDim2.new(0, 8, 1, 0),
		BackgroundColor3 = C.good,
		BorderSizePixel = 0,
		Parent = r,
	}, { Theme.corner(12) })
	Theme.text({
		Name = "Title",
		Text = "",
		Position = UDim2.fromOffset(18, 6),
		Size = UDim2.new(1, -200, 0, 24),
		Font = Theme.Display,
		fit = 19,
		Parent = r,
	})
	Theme.text({
		Name = "Desc",
		Text = "",
		Position = UDim2.fromOffset(18, 30),
		Size = UDim2.new(1, -200, 0, 28),
		TextColor3 = C.muted,
		fit = 15,
		Parent = r,
	})
	local buy = Theme.button({
		Name = "Buy",
		Text = "BUY",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(150, 46),
		BackgroundColor3 = C.good,
		Parent = r,
	})
	Theme.text({
		Name = "Gain",
		Text = "",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -168, 0, 34),
		Size = UDim2.fromOffset(130, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Theme.Display,
		TextColor3 = Color3.fromRGB(40, 130, 200),
		fit = 15,
		Parent = r,
	})
	buy.Activated:Connect(function()
		local key = r:GetAttribute("Key")
		if key then
			Net.send("Buy", key)
		end
	end)
	Theme.title({
		Name = "Tag",
		Text = "RECOMMENDED",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -168, 0, 8),
		Size = UDim2.fromOffset(122, 20),
		BackgroundColor3 = GOLD,
		TextColor3 = C.ink,
		TextXAlignment = Enum.TextXAlignment.Center,
		outline = false,
		fit = 13,
		Visible = false,
		Parent = r,
	})
	r.Tag.BackgroundTransparency = 0
	Theme.corner(8).Parent = r.Tag
	return r
end

local function paint()
	local u = Store.get("upgrades")
	if not u or not panel then
		return
	end
	local p = Store.get("profile")
	local cash = p and p.cash or 0
	local list = {}
	for _, e in u.list do
		local def = Upgrades[e.key]
		if def and (branch == "all" or def.branch == branch) then
			table.insert(list, e)
		end
	end
	table.sort(list, function(a, b)
		if (a.key == u.recommended) ~= (b.key == u.recommended) then
			return a.key == u.recommended
		end
		if (a.why == "maxed") ~= (b.why == "maxed") then
			return b.why == "maxed"
		end
		return (a.cost or math.huge) < (b.cost or math.huge)
	end)
	for k, e in list do
		local r = refs.rows[k] or row(refs.list, k)
		refs.rows[k] = r
		local def = Upgrades[e.key]
		r.Visible = true
		r.LayoutOrder = k
		r:SetAttribute("Key", e.key)
		r.Stripe.BackgroundColor3 = BRANCH_COLOR[def.branch] or C.good
		r.Title.Text = def.name .. (def.max > 1 and ` ({e.level}/{def.max})` or "")
		r.Desc.Text = def.desc
		r.Gain.Text = e.gain and e.gain >= 1 and `+{Format.cash(e.gain)}/min` or ""
		local rec = e.key == u.recommended
		r.Tag.Visible = rec
		r.Title.Size = UDim2.new(1, rec and -300 or -180, 0, 24)
		r.Desc.Size = UDim2.new(1, -310, 0, 28)
		local stroke = r:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = rec and GOLD or C.grey
			stroke.Thickness = rec and 4 or 2
		end
		r.BackgroundColor3 = rec and Color3.fromRGB(255, 249, 226) or C.white
		if e.why == "maxed" then
			r.Buy.Text = "MAXED"
			r.Buy.BackgroundColor3 = Color3.fromRGB(150, 140, 130)
		elseif (e.cost or 0) <= cash then
			r.Buy.Text = `BUY {Format.cash(e.cost or 0)}`
			r.Buy.BackgroundColor3 = C.good
		else
			r.Buy.Text = `NEED {Format.cash(e.cost or 0)}`
			r.Buy.BackgroundColor3 = Color3.fromRGB(84, 70, 60)
		end
	end
	for k = #list + 1, #refs.rows do
		refs.rows[k].Visible = false
	end
	refs.list.CanvasSize = UDim2.fromOffset(0, #list * 70 + 10)
	local stage = Business[u.stage or "stand"]
	local nxt = Business.next(u.stage or "stand")
	refs.note.Text = nxt and `Your {stage.name}. More upgrades open with the {nxt.name}.`
		or `Your {stage.name}: every branch is open.`
	for _, b in BRANCHES do
		refs.tabs[b.key].BackgroundColor3 = branch == b.key and C.mustard or C.paper
	end
end

function UpgradeController.open()
	Bus.Panel:Fire("upgrades")
end

function UpgradeController:init()
	panel = Panel.new("upgrades", "UPGRADES", Color3.fromRGB(60, 150, 240), Vector2.new(720, 520))
	refs.panel = panel
	local tabs = Theme.new("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = panel.body,
	})
	Theme.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tabs,
	})
	for k, b in BRANCHES do
		local t = Theme.button({
			Name = b.key,
			Text = b.label,
			Size = UDim2.fromOffset(108, 36),
			LayoutOrder = k,
			BackgroundColor3 = C.paper,
			dark = true,
			Parent = tabs,
		})
		t.Activated:Connect(function()
			branch = b.key
			paint()
		end)
		refs.tabs[b.key] = t
	end
	refs.note = Theme.text({
		Name = "Note",
		Text = "",
		Position = UDim2.fromOffset(4, 44),
		Size = UDim2.new(1, -8, 0, 22),
		TextColor3 = C.muted,
		fit = 15,
		Parent = panel.body,
	})
	refs.list = Theme.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 1, -70),
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
	panel.onOpen = paint
	Store.Changed:Connect(function(partial)
		if (partial.upgrades or partial.profile) and panel:isOpen() then
			paint()
		end
	end)
	_ = Players
end

return UpgradeController
