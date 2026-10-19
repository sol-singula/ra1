--[[
The HUD (master plan §7): cash big at the top left with the income a minute (from sales) under it; across the
top the chain GROW > HARVEST > STOCK > SELL with the bottleneck in red and a line saying what to do about it; the
toasts. Uncluttered: the recommended upgrade is TaskController's card, and the "+$n" pops float up at the stand.

  HudController.refs    cash, income, chips, line, toast (tests)
  HudController.toast(text, kind)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Business = require(ReplicatedStorage.Shared.Data.Business)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local HudController = { Name = "HudController", Order = 10 }

local C = Theme.Color
local CASH = Color3.fromRGB(120, 230, 110)
local player = Players.LocalPlayer
local refs = {}
HudController.refs = refs
local toastToken

local function toast(text, kind)
	local t = refs.toast
	if not t then
		return
	end
	t.Text = text
	t.TextColor3 = kind == "bad" and C.red or (kind == "good" and C.good or C.white)
	t.Visible = true
	local token = {}
	toastToken = token
	task.delay(3.2, function()
		if toastToken == token then
			t.Visible = false
		end
	end)
end
HudController.toast = toast

local function paint()
	local p = Store.get("profile")
	if p then
		refs.cash.Text = "$" .. Theme.commas(p.cash or 0)
		refs.income.Text = `{Format.cash(p.income or 0)} / min`
		refs.stage.Text = Business[p.stage or "stand"].short
	end
	local b = Store.get("business")
	if b and refs.chips then
		-- the chain: what the field grows, what's harvested, the stock, what's sold; the bottleneck in red
		local hand = (b.harvest or 0) == 0
		local selling = (b.sell or b.service or 0) + (b.dispatch or 0)
		local vals = {
			grow = `{Format.num(b.perMinute or 0)}/min`,
			harvest = hand and "BY HAND" or `{Format.num(b.harvest)}/min`,
			stock = `{Format.num(b.stock or 0)}/{Format.num(b.storage or 0)}`,
			sell = `{Format.num(selling)}/min`,
		}
		local worst = ({ production = "grow", harvest = "harvest", service = "sell", dispatch = "sell" })[b.bottleneck or ""]
		if b.full then
			worst = "stock"
		end
		for key, chip in refs.chips do
			chip.Value.Text = vals[key]
			local bad = key == worst
			chip.BackgroundColor3 = bad and C.red or C.slate
			chip:SetAttribute("Bottleneck", bad)
		end
		local NOTE = {
			grow = "🌱 BOTTLENECK: the field. Grow more: more tiles, new crops, chickens",
			harvest = "🚜 BOTTLENECK: harvesting. Ripe crops are waiting: get a machine",
			stock = "📦 STOCK FULL: the harvesters have stopped. Sell faster: a bigger counter, cows, a bigger shop",
			sell = "🛒 BOTTLENECK: selling. Your stock waits for the counter: a bigger counter, cows, a bigger shop",
		}
		local onboarding = Store.get("task") and Store.get("task").onboarding
		local text = not onboarding and worst and NOTE[worst] or nil
		if b.full then
			text = NOTE.stock
		end
		refs.line.Visible = text ~= nil
		refs.line.Text = text or ""
		refs.line.TextColor3 = b.full and Color3.fromRGB(255, 150, 140) or C.white
	end
end

function HudController:init()
	local gui = Theme.screen("Hud", 5, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	local slab = Theme.slab({
		Name = "Cash",
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.fromOffset(300, 74),
		Parent = gui,
	})
	refs.slab = slab
	refs.cash = Theme.title({
		Name = "CashText",
		Text = "$0",
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(1, -28, 0, 40),
		TextColor3 = CASH,
		fit = 34,
		Parent = slab,
	})
	refs.income = Theme.text({
		Name = "Income",
		Text = "$0 / min",
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -110, 0, 24),
		TextColor3 = C.white,
		fit = 18,
		Parent = slab,
	})
	refs.stage = Theme.text({
		Name = "Stage",
		Text = "STAND",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 46),
		Size = UDim2.fromOffset(110, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.mustard,
		Font = Theme.Display,
		fit = 16,
		Parent = slab,
	})
	-- the business line and the toasts: dark pills sized to their words
	local function pill(name, y, size)
		local l = Theme.text({
			Name = name,
			Text = "",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.fromOffset(0, size + 14),
			TextSize = size,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Theme.Display,
			BackgroundColor3 = C.slate,
			Visible = false,
			Parent = gui,
		})
		l.BackgroundTransparency = 0.2
		l.TextWrapped = false
		l.AutomaticSize = Enum.AutomaticSize.X
		Theme.corner("round").Parent = l
		Theme.stroke(2, C.ink).Parent = l
		Theme.new("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			Parent = l,
		})
		Theme.compact(l, 0.8)
		return l
	end
	-- the chain across the top: GROW > HARVEST > STOCK > SELL
	local chain = Theme.new("Frame", {
		Name = "Chain",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(4 * 118 + 3 * 18, 46),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	refs.chain = chain
	refs.chips = {}
	for k, spec in
		{
			{ "grow", "🌱 GROW" },
			{ "harvest", "🚜 HARVEST" },
			{ "stock", "📦 STOCK" },
			{ "sell", "🛒 SELL" },
		}
	do
		local chip = Theme.slab({
			Name = spec[1],
			Position = UDim2.fromOffset((k - 1) * 136, 0),
			Size = UDim2.fromOffset(118, 46),
			Parent = chain,
		})
		Theme.text({
			Name = "Label",
			Text = spec[2],
			Position = UDim2.fromOffset(6, 3),
			Size = UDim2.new(1, -12, 0, 17),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.mustard,
			Font = Theme.Display,
			fit = 14,
			Parent = chip,
		})
		Theme.text({
			Name = "Value",
			Text = "",
			Position = UDim2.fromOffset(6, 21),
			Size = UDim2.new(1, -12, 0, 21),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.white,
			Font = Theme.Display,
			fit = 18,
			Parent = chip,
		})
		if k < 4 then
			Theme.text({
				Name = "Arrow",
				Text = "›",
				Position = UDim2.fromOffset(k * 136 - 18, 6),
				Size = UDim2.fromOffset(18, 34),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = C.white,
				Font = Theme.Display,
				outline = 2,
				fit = 30,
				Parent = chain,
			})
		end
		refs.chips[spec[1]] = chip
	end
	Theme.compact(chain, 0.7)
	refs.line = pill("Line", 64, 16)
	refs.toast = pill("Toast", 100, 19)

	paint()
	Store.Changed:Connect(function(partial)
		if partial.profile or partial.business or partial.task then
			paint()
		end
	end)
	Net.listen("Toast", toast)
	-- the device, once, for the analytics
	task.delay(2, function()
		pcall(function()
			local cam = workspace.CurrentCamera
			Net.send("Analytics", "device", {
				platform = UserInputService.TouchEnabled and "touch" or "desktop",
				screen = cam and `{math.floor(cam.ViewportSize.X)}x{math.floor(cam.ViewportSize.Y)}` or "?",
				touch = UserInputService.TouchEnabled,
				gamepad = UserInputService.GamepadEnabled,
			})
		end)
	end)
end

return HudController
