--[[
The HUD (master plan §7): cash big at the top left with the income a minute beside it; the business line (demand
against service, stock against storage) only when it says something (a line forming, storage nearly full); the
toasts; a "+$n" when cash comes in. Uncluttered: the recommended upgrade is TaskController's card.

  HudController.refs    cash, income, line, toast, earned (tests)
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
	if b then
		local full = b.storage > 0 and b.stock / b.storage
		local text, color
		if full and full >= 0.9 then
			text = `📦 STORAGE {b.stock}/{b.storage}: FULL`
			color = C.red
		elseif (b.queue or 0) >= 4 then
			text = `🛒 LINE OF {b.queue}: the counter serves {b.service}/min, {b.demand}/min come`
			color = C.mustard
		elseif
			b.stock == 0
			and (b.soldPerMin or 0) == 0
			and (b.demand or 0) > 0
			and not (Store.get("task") and Store.get("task").onboarding)
		then
			text = "🛒 SHELVES EMPTY: customers are waiting for crops"
			color = C.mustard
		elseif (b.demand or 0) > 0 then
			text = `🛒 {b.demand}/min come · counter {b.service}/min · stock {b.stock}/{b.storage}`
			color = C.white
		end
		refs.line.Visible = text ~= nil
		refs.line.Text = text or ""
		refs.line.TextColor3 = color or C.white
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
	refs.line = Theme.text({
		Name = "Line",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(640, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Display,
		outline = 2,
		fit = 19,
		Visible = false,
		Parent = gui,
	})
	Theme.compact(refs.line, 0.8)
	refs.toast = Theme.text({
		Name = "Toast",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 50),
		Size = UDim2.fromOffset(600, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Display,
		outline = 2,
		fit = 20,
		Visible = false,
		Parent = gui,
	})
	Theme.compact(refs.toast, 0.75)
	refs.earned = Theme.text({
		Name = "Earned",
		Text = "",
		Position = UDim2.fromOffset(324, 20),
		Size = UDim2.fromOffset(160, 30),
		Font = Theme.Display,
		TextColor3 = CASH,
		outline = 2,
		fit = 24,
		Visible = false,
		Parent = gui,
	})

	paint()
	Store.Changed:Connect(function(partial)
		if partial.profile or partial.business or partial.task then
			paint()
		end
	end)
	Net.listen("Toast", toast)
	local earnedToken, acc = nil, 0
	Net.listen("Earned", function(e)
		if type(e) ~= "table" then
			return
		end
		acc += e.amount or 0
		refs.earned.Text = `+{Format.cash(acc)}`
		refs.earned.Visible = true
		local token = {}
		earnedToken = token
		task.delay(1.4, function()
			if earnedToken == token then
				refs.earned.Visible = false
				acc = 0
			end
		end)
	end)
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
