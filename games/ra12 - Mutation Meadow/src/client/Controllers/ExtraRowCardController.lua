--[[
The Extra Plot Row card: an in-world card beside your plot's Expand sign (a BillboardGui on the Sign). It shows only
when every active main-plot tile is planted, you own neither Extra Plot Row nor the Starter Bundle, the first session
is past 10:00 (firstSession.extraRowEligible or done) and you haven't closed it this session. It hides again when a
tile frees up. It carries the Extra Plot Row icon, "+8 tiles in a bed in front of your plot", an "Extra Row 199 R$"
button and Close, and never opens a purchase prompt by itself: only the button does.

  ExtraRowCardController.shouldShow() -> boolean
  ExtraRowCardController.refresh()
  ExtraRowCardController.close()          for the session
  ExtraRowCardController.TEXT
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Tiles = require(ReplicatedStorage.Shared.Tiles)
local ClientState = require(script.Parent.Parent.ClientState)
local UI = require(script.Parent.Parent.UI)

local ExtraRowCardController = {}

ExtraRowCardController.TEXT = "+8 tiles in a bed in front of your plot"

local gui
local closed = false

local function myPlot()
	local street = workspace:FindFirstChild("Street")
	local plots = street and street:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerId") == Players.LocalPlayer.UserId then
			return plot
		end
	end
	return nil
end

local function plotFull(p)
	local any = false
	for row = 1, Tiles.GRID do
		for col = 1, Tiles.GRID do
			local id = Tiles.id(row, col)
			if Tiles.isActive(id, p.plotLevel, false) then
				any = true
				if not p.tiles[id] and not (p.sprinklers and p.sprinklers.placed[id]) then
					return false
				end
			end
		end
	end
	return any
end

function ExtraRowCardController.shouldShow()
	local p = ClientState.profile
	local me = Players.LocalPlayer
	if not p or closed then
		return false
	end
	if me:GetAttribute("Pass_extraRow") or me:GetAttribute("Pass_starterBundle") then
		return false
	end
	local fs = p.firstSession
	if not (fs.extraRowEligible or fs.done) then
		return false
	end
	return plotFull(p)
end

local function build(sign)
	gui = Instance.new("BillboardGui")
	gui.Name = "ExtraRowCard"
	gui.Adornee = sign
	gui.Size = UDim2.fromOffset(260, 170)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local card = UI.frame(gui, { Name = "Card", Size = UDim2.fromScale(1, 1) })
	UI.label(card, "🟫", { Name = "Icon", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(44, 44) })
	UI.label(card, Config.Catalog.passes.extraRow.name, {
		Name = "Title",
		Position = UDim2.fromOffset(58, 8),
		Size = UDim2.new(1, -100, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UI.label(card, ExtraRowCardController.TEXT, {
		Name = "Text",
		Position = UDim2.fromOffset(8, 58),
		Size = UDim2.new(1, -16, 0, 40),
		TextWrapped = true,
	})
	UI.button(card, `Extra Row {Config.Catalog.extraRowCard.robux} R$`, function()
		Net.request("Purchase", "prompt", { key = "extraRow" })
	end, { Name = "Buy", Position = UDim2.fromOffset(8, 106), Size = UDim2.new(1, -16, 0, 52) })
	UI.button(card, "X", ExtraRowCardController.close, {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = UI.COLORS.grey,
	})
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

function ExtraRowCardController.refresh()
	if not gui then
		local plot = myPlot()
		local sign = plot and plot:FindFirstChild("Sign")
		if not sign then
			return
		end
		build(sign)
	end
	gui.Enabled = ExtraRowCardController.shouldShow()
end

function ExtraRowCardController.close()
	closed = Config.Catalog.extraRowCard.closeHidesForSession
	if gui then
		gui.Enabled = false
	end
end

function ExtraRowCardController:Start()
	ClientState.Changed:Connect(ExtraRowCardController.refresh)
	Players.LocalPlayer.AttributeChanged:Connect(ExtraRowCardController.refresh)
	ExtraRowCardController.refresh()
end

return ExtraRowCardController
