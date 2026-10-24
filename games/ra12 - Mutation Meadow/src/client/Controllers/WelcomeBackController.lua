--[[
The Welcome-back card (a Toast of kind "welcomeBack" with { awaySec, ripe }): how long you were away, how many crops
are ripe, and Harvest all ripe (normal crops; mutated ones wait for a tap).

  WelcomeBackController.show(data) / close() / isOpen()
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI)

local WelcomeBackController = {}

local modal

function WelcomeBackController.show(data)
	modal.clear()
	UI.label(modal.body, "You were away " .. UI.duration(data.awaySec or 0), { Name = "Away" })
	local ripe = data.ripe or 0
	UI.label(modal.body, if ripe == 1 then "1 crop is ripe" else `{ripe} crops are ripe`, { Name = "Ripe" })
	if ripe > 0 then
		UI.button(modal.body, "Harvest all ripe", function()
			Net.request("Plot", "harvestAll", {})
			modal.close()
		end, { Name = "HarvestAll" })
	end
	UI.button(modal.body, "Let's farm!", modal.close, { Name = "Ok", BackgroundColor3 = UI.COLORS.green })
	modal.open()
end

function WelcomeBackController.close()
	modal.close()
end

function WelcomeBackController.isOpen()
	return modal.isOpen()
end

function WelcomeBackController:Start()
	modal = UI.modal("WelcomeBack", "Welcome back!")
	modal.card.Size = UDim2.fromOffset(420, 360)
	Net.on("Toast", function(t)
		if type(t) == "table" and t.kind == "welcomeBack" and type(t.data) == "table" then
			WelcomeBackController.show(t.data)
		end
	end)
end

return WelcomeBackController
