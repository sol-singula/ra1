--[[
The Odds panel: every row comes from Config at runtime (Shared.Odds), never typed by hand. Opens from the Seed Shop
and from Settings.

  OddsController.open() / close() / isOpen() / rows()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Odds = require(ReplicatedStorage.Shared.Odds)
local UI = require(script.Parent.Parent.UI)

local OddsController = {}

local modal

function OddsController.rows()
	return Odds.rows(Config)
end

function OddsController.fill()
	modal.clear()
	local list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 1, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = modal.body
	UI.list(list, 4)
	local section
	for i, row in OddsController.rows() do
		if row.section ~= section then
			section = row.section
			UI.label(list, section, {
				Name = "Section_" .. section,
				LayoutOrder = i * 2 - 1,
				Size = UDim2.new(1, 0, 0, 28),
				TextColor3 = UI.COLORS.green,
			})
		end
		UI.label(list, row.text, {
			Name = "Row" .. i,
			LayoutOrder = i * 2,
			Size = UDim2.new(1, 0, 0, 24),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end
end

function OddsController.open()
	OddsController.fill()
	modal.open()
end

function OddsController.close()
	modal.close()
end

function OddsController.isOpen()
	return modal.isOpen()
end

function OddsController:Start()
	modal = UI.modal("Odds", "Odds")
	modal.card.Size = UDim2.fromOffset(480, 600)
	modal.gui.DisplayOrder = 30
end

return OddsController
