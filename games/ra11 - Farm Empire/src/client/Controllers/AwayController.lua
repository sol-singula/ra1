--[[
The welcome-back card (master plan §10, Day 2): how long you were away, what grew, what the farm earned, and the
next useful upgrade (the task card under it says it). One button: COLLECT.

  AwayController.refs   card (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Layout = require(script.Parent.Parent.UI.Layout)
local Theme = require(script.Parent.Parent.UI.Theme)

local AwayController = { Name = "AwayController", Order = 62 }

local C = Theme.Color
local refs = {}
AwayController.refs = refs

function AwayController:init()
	local gui = Theme.screen("Away", 25, Players.LocalPlayer:WaitForChild("PlayerGui"))
	local card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(460, 250),
		Visible = false,
		Parent = gui,
	})
	refs.card = card
	Theme.cardHeader(card, "WELCOME BACK", 46, C.slate)
	refs.text = Theme.text({
		Name = "Text",
		Text = "",
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 0, 110),
		TextXAlignment = Enum.TextXAlignment.Center,
		fit = 20,
		Parent = card,
	})
	refs.ok = Theme.button({
		Name = "Collect",
		Text = "COLLECT",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.fromOffset(200, 50),
		BackgroundColor3 = C.good,
		Parent = card,
	})
	refs.ok.Activated:Connect(function()
		card.Visible = false
	end)
	Layout.modal("away", card)
	Theme.compact(card, 0.8)
	Net.listen("Away", function(a)
		if type(a) ~= "table" then
			return
		end
		local lines = { `You were away {Format.time(a.seconds or 0)}.` }
		if (a.ripe or 0) > 0 then
			table.insert(lines, `{a.ripe} tiles are ripe and waiting.`)
		end
		if (a.earned or 0) > 0 then
			table.insert(
				lines,
				`Your machines kept selling: +{Format.cash(a.earned)}`
					.. (a.capped and ` (the first {a.hours} hours count)` or "")
			)
		elseif (a.ripe or 0) > 0 then
			table.insert(lines, "Buy the Auto-Harvester and the farm earns while you're away.")
		end
		refs.text.Text = table.concat(lines, "\n")
		card.Visible = true
		Theme.pop(card)
	end)
end

return AwayController
