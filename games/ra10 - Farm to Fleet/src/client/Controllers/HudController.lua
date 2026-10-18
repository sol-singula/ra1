--[[
The always-on screen (phone first: big, high-contrast, in the farm's colours).

  top left     your Cash (a green coin) and Gems, the basket under them (carried / how much you can carry)
  top centre   FARM LEVEL n and its XP bar
  centre       the toasts (Net "Toast"), a "+N" when Cash comes in (Net "Earned")

  HudController.refs   the pieces (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local HudController = { Name = "HudController", Order = 10 }

local C = Theme.Color
local P = Constants.PALETTE
local CASH = Color3.fromRGB(70, 200, 90)
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
		refs.cash.Text = Theme.commas(p.cash or 0)
		refs.gems.Text = Theme.commas(p.gems or 0)
		refs.levelText.Text = `FARM LEVEL {p.level or 1}`
		local k = (p.need or 0) > 0 and (p.into or 0) / p.need or 0
		refs.levelFill.Size = UDim2.fromScale(math.clamp(k, 0.03, 1), 1)
		refs.xp.Text = `{p.into or 0} / {p.need or 0} XP`
	end
	local f = Store.get("farm")
	if f then
		refs.basket.Text = `🧺 {f.carried or 0} / {f.carry or 0}`
		refs.basket.TextColor3 = (f.carried or 0) >= (f.carry or 1) and C.mustard or C.white
	end
end

function HudController:init()
	local gui = Theme.screen("Hud", 5, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	local money = Theme.slab({
		Name = "Cash",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(170, 46),
		Parent = gui,
	})
	Theme.new("Frame", {
		Name = "Coin",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = CASH,
		BorderSizePixel = 0,
		Parent = money,
	}, { Theme.corner("round"), Theme.stroke(2) })
	refs.cash = Theme.text({
		Name = "Amount",
		Text = "0",
		Position = UDim2.fromOffset(44, 5),
		Size = UDim2.new(1, -52, 1, -10),
		Font = Theme.Display,
		TextColor3 = CASH,
		fit = 26,
		Parent = money,
	})
	local gems = Theme.slab({
		Name = "Gems",
		Position = UDim2.fromOffset(190, 12),
		Size = UDim2.fromOffset(110, 46),
		Parent = gui,
	})
	Theme.gem(gems, 22, { Name = "Gem", Position = UDim2.fromOffset(10, 12) })
	refs.gems = Theme.text({
		Name = "Amount",
		Text = "0",
		Position = UDim2.fromOffset(40, 5),
		Size = UDim2.new(1, -48, 1, -10),
		Font = Theme.Display,
		TextColor3 = C.white,
		fit = 24,
		Parent = gems,
	})
	refs.basket = Theme.text({
		Name = "Basket",
		Text = "🧺 0 / 20",
		Position = UDim2.fromOffset(14, 62),
		Size = UDim2.fromOffset(170, 26),
		Font = Theme.Display,
		TextColor3 = C.white,
		outline = 2,
		fit = 20,
		Parent = gui,
	})

	local bar, fill = Theme.bar({
		Name = "Level",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(300, 30),
		Parent = gui,
	}, P.sunflower)
	refs.levelBar, refs.levelFill = bar, fill
	refs.levelText = Theme.text({
		Name = "Words",
		Text = "FARM LEVEL 1",
		Position = UDim2.fromOffset(10, 2),
		Size = UDim2.new(0.6, -10, 1, -4),
		Font = Theme.Display,
		TextColor3 = C.white,
		outline = 2,
		fit = 18,
		ZIndex = 3,
		Parent = bar,
	})
	refs.xp = Theme.text({
		Name = "XP",
		Text = "",
		Position = UDim2.new(0.6, 0, 0, 2),
		Size = UDim2.new(0.4, -10, 1, -4),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = C.white,
		outline = 2,
		fit = 14,
		ZIndex = 3,
		Parent = bar,
	})

	refs.toast = Theme.text({
		Name = "Toast",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 132),
		Size = UDim2.fromOffset(560, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Display,
		outline = 2,
		fit = 20,
		Visible = false,
		Parent = gui,
	})
	refs.earned = Theme.text({
		Name = "Earned",
		Text = "",
		Position = UDim2.fromOffset(190, 62),
		Size = UDim2.fromOffset(160, 26),
		Font = Theme.Display,
		TextColor3 = CASH,
		outline = 2,
		fit = 22,
		Visible = false,
		Parent = gui,
	})

	paint()
	Store.Changed:Connect(function(partial)
		if partial.profile or partial.farm then
			paint()
		end
	end)
	Net.listen("Toast", toast)
	local earnedToken
	Net.listen("Earned", function(e)
		if type(e) ~= "table" or e.currency ~= "cash" then
			return
		end
		refs.earned.Text = `+{Format.num(e.amount or 0)}`
		refs.earned.Visible = true
		local token = {}
		earnedToken = token
		task.delay(1.6, function()
			if earnedToken == token then
				refs.earned.Visible = false
			end
		end)
	end)
end

return HudController
