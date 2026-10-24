--[[
Patch's Seed Shop: Patch's portrait with his greeting bubble (shopHello / shopAgain), the restock countdown, one card
per seed (tier, price, grow time, sell, harvests, stock left this cycle, the lock reason when gated) with Buy 1 and
Buy 5 (off when fewer than 5 are left), and the Odds button. The server opens it (Restock { open = true }) when you
use Patch's prompt.

  ShopController.open(data?) / close() / isOpen()
  ShopController.setGreeting(text)
  ShopController.state()          the last Restock { slot, endsAt, stock, bought }
  ShopController.lockReason(profile, seed, eventWeek)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Schedule = require(ReplicatedStorage.Shared.Schedule)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)
local Visuals = require(ReplicatedStorage.Shared.Visuals)

local ShopController = {}

local controllers
local modal, greeting, countdown
local restock -- { slot, endsAt, stock, bought }

function ShopController.state()
	return restock
end

function ShopController.lockReason(profile, seed, eventWeek)
	local gate = Config.Seeds[seed].gate
	if gate.lifetimeCoins and profile.lifetimeCoins < gate.lifetimeCoins then
		return `Earn {UI.money(gate.lifetimeCoins)} coins in total`
	elseif gate.plotLevel and profile.plotLevel < gate.plotLevel then
		return `Plot level {gate.plotLevel}`
	elseif gate.eventOnly and not eventWeek then
		return "Event weeks only"
	end
	return nil
end

local function left(seed)
	local stock = restock and restock.stock[seed] or 0
	local bought = restock and restock.bought and restock.bought[seed] or 0
	local p = ClientState.profile
	if p and p.restock and restock and p.restock.slot == restock.slot then
		bought = p.restock.bought[seed] or 0
	end
	return math.max(0, stock - bought)
end

local function buy(seed, qty)
	Net.request("Shop", "buySeed", { seed = seed, qty = qty }):andThen(function(result)
		if not result.ok and controllers.HudController then
			local why = { coins = "Not enough coins", sold_out = "Sold out until the next restock", locked = "Locked" }
			controllers.HudController.toast(why[result.code] or "Can't buy that")
		end
	end)
end

local function card(parent, profile, seed, order, eventWeek)
	local s = Config.Seeds[seed]
	local n = left(seed)
	local lock = ShopController.lockReason(profile, seed, eventWeek)
	local c = UI.frame(parent, { Name = "Card_" .. seed, LayoutOrder = order })
	UI.frame(c, {
		Name = "Icon",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Visuals.SEED[seed],
	})
	UI.label(
		c,
		`{s.name} · tier {s.tier}`,
		{ Name = "Name", Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -64, 0, 22) }
	)
	UI.label(
		c,
		`🪙 {UI.money(s.buy)} · grows {UI.duration(s.growSec)}`,
		{ Name = "Price", Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -64, 0, 18) }
	)
	UI.label(
		c,
		`Sells {UI.money(s.sell)} · {s.harvests} harvest{if s.harvests == 1 then "" else "s"}`,
		{ Name = "Sell", Position = UDim2.fromOffset(8, 56), Size = UDim2.new(1, -16, 0, 18) }
	)
	UI.label(
		c,
		if lock then "🔒 " .. lock else `{n} left this restock`,
		{ Name = "Stock", Position = UDim2.fromOffset(8, 76), Size = UDim2.new(1, -16, 0, 18) }
	)
	local can1 = lock == nil and n >= 1
	local can5 = lock == nil and n >= 5
	UI.button(c, "Buy 1", function()
		if can1 then
			buy(seed, 1)
		end
	end, {
		Name = "Buy1",
		Position = UDim2.new(0, 8, 1, -54),
		Size = UDim2.new(0.5, -12, 0, UI.MIN_TAP),
		Active = can1,
		BackgroundColor3 = if can1 then UI.COLORS.green else UI.COLORS.grey,
	})
	UI.button(c, "Buy 5", function()
		if can5 then
			buy(seed, 5)
		end
	end, {
		Name = "Buy5",
		Position = UDim2.new(0.5, 4, 1, -54),
		Size = UDim2.new(0.5, -12, 0, UI.MIN_TAP),
		Active = can5,
		BackgroundColor3 = if can5 then UI.COLORS.green else UI.COLORS.grey,
	})
	return c
end

function ShopController.fill()
	modal.clear()
	local p = ClientState.profile
	if not p then
		return
	end
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 64)
	header.Parent = modal.body
	UI.frame(
		header,
		{ Name = "Portrait", Size = UDim2.fromOffset(60, 60), BackgroundColor3 = Color3.fromRGB(235, 120, 30) }
	)
	greeting = UI.label(header, greeting and greeting.Text or "", {
		Name = "Greeting",
		Position = UDim2.fromOffset(68, 0),
		Size = UDim2.new(1, -68, 1, 0),
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	countdown = UI.label(modal.body, "", { Name = "Countdown", Size = UDim2.new(1, 0, 0, 24) })
	UI.button(modal.body, "Odds", function()
		controllers.OddsController.open()
	end, { Name = "Odds", Size = UDim2.new(1, 0, 0, UI.MIN_TAP), BackgroundColor3 = UI.COLORS.ink })
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 1, -150)
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = modal.body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(200, 150)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local eventWeek = restock
		and Schedule.isEventWeek(Schedule.currentUpdate(restock.slot * Config.Restock.intervalSec).updateId)
	for i, seed in Config.Restock.order do
		card(grid, p, seed, i, eventWeek)
	end
	ShopController.tick()
end

function ShopController.tick()
	if countdown and restock then
		countdown.Text = "New seeds in " .. UI.duration(restock.endsAt - Clock.now())
	end
end

function ShopController.setGreeting(text)
	if greeting then
		greeting.Text = text
	end
end

function ShopController.open(data)
	if data then
		restock = data
	end
	ShopController.fill()
	modal.open()
end

function ShopController.close()
	if modal.isOpen() then
		Net.send("Shop", "close", {})
	end
	modal.close()
end

function ShopController.isOpen()
	return modal.isOpen()
end

function ShopController:Init(all)
	controllers = all
end

function ShopController:Start()
	modal = UI.modal("SeedShop", "Patch's Seed Shop")
	modal.card.Size = UDim2.fromOffset(460, 640)
	local close = modal.card:FindFirstChild("Close")
	if close then
		close.Activated:Connect(function()
			Net.send("Shop", "close", {})
		end)
	end
	Net.on("Restock", function(data)
		if type(data) ~= "table" then
			return
		end
		restock = data
		if data.open then
			ShopController.open(data)
		elseif modal.isOpen() then
			ShopController.fill()
		end
	end)
	ClientState.Changed:Connect(function(roots)
		if roots == nil and ClientState.extra and ClientState.extra.restock then
			restock = ClientState.extra.restock
		end
		if modal.isOpen() and (roots == nil or roots.restock or roots.coins or roots.seeds) then
			ShopController.fill()
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			ShopController.tick()
		end
	end)
end

return ShopController
