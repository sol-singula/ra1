--[[
The HUD: coins, plot level, Basket x/200, the Auto-Sell toggle (plot level 2+), the next Block Party in local time,
Upgrades / Sell / Backpack buttons, and the toasts (mutations, and all others but the Welcome-back card).

  HudController.refresh()
  HudController.toast(text)
  HudController.gui
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local MutationMath = require(ReplicatedStorage.Shared.MutationMath)
local Net = require(ReplicatedStorage.Shared.Net)
local Schedule = require(ReplicatedStorage.Shared.Schedule)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local HudController = {}

local controllers
local coins, level, basket, autoSell, toastFrame, party

local TOAST_SEC = 3

local function basketCount(profile)
	local n = 0
	for _, c in profile.basket or {} do
		n += c
	end
	return n
end

function HudController.refresh()
	local p = ClientState.profile
	if not p or not coins then
		return
	end
	coins.Text = "🪙 " .. UI.money(p.coins)
	level.Text = "Plot " .. p.plotLevel
	basket.Text = `🧺 {basketCount(p)}/{Config.Inventory.basketCap}`
	autoSell.Visible = p.plotLevel >= Config.Inventory.autoSellPlotLevel
	autoSell.Text = if p.autoSell then "Auto-Sell: ON" else "Auto-Sell: OFF"
	autoSell.BackgroundColor3 = if p.autoSell then UI.COLORS.green else UI.COLORS.grey
end

-- "3:00 PM" in the player's own time zone
function HudController.localTime(t)
	local d = os.date("*t", t)
	local hour = d.hour % 12
	return string.format("%d:%02d %s", if hour == 0 then 12 else hour, d.min, if d.hour < 12 then "AM" else "PM")
end

-- the next Block Party: "Block Party now!" while it's open, else "Block Party 3:00 PM (in 12m 05s)"
function HudController.partyText(now)
	local bp = controllers and controllers.BlockPartyController and controllers.BlockPartyController.state()
	if bp and bp.phase == "open" then
		return "🌻 Block Party now!"
	end
	local nextAt = Schedule.hourStart(now) + 3600
	return `🌻 Block Party {HudController.localTime(nextAt)} (in {UI.duration(nextAt - now)})`
end

function HudController.mutationText(data)
	local tile = ClientState.get("tiles", data.tile)
	local seed = tile and Config.Seeds[tile.seed] and Config.Seeds[tile.seed].name or "crop"
	local text =
		`✨ {MutationMath.label(tile and tile.muts or { [data.mut] = true })} {seed}! Worth {UI.money(data.value)}`
	if data.newEntry then
		text ..= " · NEW ENTRY"
	end
	return text
end

function HudController.toast(text)
	if not toastFrame then
		return
	end
	local l = UI.label(toastFrame, text, {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 0.15,
		BackgroundColor3 = UI.COLORS.card,
	})
	task.delay(TOAST_SEC, function()
		l:Destroy()
	end)
end

function HudController:Init(all)
	controllers = all
end

function HudController:Start()
	local gui = UI.screen("Hud")
	HudController.gui = gui
	local bar = UI.frame(gui, { Name = "Bar", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(250, 262) })
	UI.list(bar, 6)
	coins = UI.label(bar, "", { Name = "Coins", Size = UDim2.new(1, -16, 0, 40) })
	level = UI.label(bar, "", { Name = "Level", Size = UDim2.new(1, -16, 0, 28) })
	basket = UI.label(bar, "", { Name = "Basket", Size = UDim2.new(1, -16, 0, 28) })
	autoSell = UI.button(bar, "Auto-Sell", function()
		local p = ClientState.profile
		if p then
			Net.request("Basket", "setAutoSell", { on = not p.autoSell })
		end
	end, { Name = "AutoSell", Size = UDim2.new(1, -16, 0, 44) })
	local buttons = UI.frame(gui, {
		Name = "Buttons",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(250, 120),
		BackgroundTransparency = 1,
	})
	UI.list(buttons, 8)
	UI.button(buttons, "Upgrades", function()
		controllers.UpgradeController.open()
	end, { Name = "Upgrades" })
	UI.button(buttons, "Sell", function()
		controllers.SellController.open()
	end, { Name = "Sell", BackgroundColor3 = UI.COLORS.gold })
	UI.button(buttons, "Backpack", function()
		controllers.BackpackController.open()
	end, { Name = "Backpack", BackgroundColor3 = UI.COLORS.ink })
	buttons.Size = UDim2.fromOffset(250, 180)
	party = UI.label(bar, "", { Name = "Party", Size = UDim2.new(1, -16, 0, 24) })
	toastFrame = Instance.new("Frame")
	toastFrame.Name = "Toasts"
	toastFrame.BackgroundTransparency = 1
	toastFrame.AnchorPoint = Vector2.new(0.5, 0)
	toastFrame.Position = UDim2.new(0.5, 0, 0, 12)
	toastFrame.Size = UDim2.fromOffset(420, 200)
	toastFrame.Parent = gui
	UI.list(toastFrame, 4)

	ClientState.Changed:Connect(HudController.refresh)
	Net.on("Toast", function(t)
		if type(t) == "table" and t.kind ~= "welcomeBack" and type(t.text) == "string" then
			HudController.toast(t.text)
		end
	end)
	Net.on("Mutation", function(data)
		if type(data) == "table" then
			HudController.toast(HudController.mutationText(data))
		end
	end)
	HudController.refresh()
	task.spawn(function()
		while true do
			party.Text = HudController.partyText(Clock.now())
			task.wait(1)
		end
	end)
end

return HudController
