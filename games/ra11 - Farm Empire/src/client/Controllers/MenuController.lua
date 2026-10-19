--[[
The menu rail: big icon buttons down the right, each opening its panel (UI/Panel via Bus.Panel):

  UPGRADES   the tree (UpgradeController); pulses when the task wants you in it
  SHOP       Robux: boosts, cash, passes (ShopController)
  BOOST      the town's shared boost meter (BoostController)
  TOWN/HOME  teleport to the square, or home from anywhere else

  MenuController.refs   the buttons (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Theme = require(script.Parent.Parent.UI.Theme)

local MenuController = { Name = "MenuController", Order = 15 }

local player = Players.LocalPlayer
local refs = { buttons = {} }
MenuController.refs = refs

-- stylua: ignore start
MenuController.ITEMS = {
	{ key = "upgrades", icon = "⬆️", label = "UPGRADES", color = Color3.fromRGB(60, 150, 240) },
	{ key = "shop",     icon = "🛒", label = "SHOP",     color = Color3.fromRGB(60, 185, 90) },
	{ key = "boost",    icon = "⚡", label = "BOOST",    color = Color3.fromRGB(255, 170, 40) },
	{ key = "town",     icon = "🏘️", label = "TOWN",     color = Color3.fromRGB(150, 100, 220) },
}
-- stylua: ignore end

local pulsing

function MenuController:init()
	local gui = Theme.screen("Menu", 8, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	local rail = Theme.new("Frame", {
		Name = "Rail",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(74, 320),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Parent = rail,
	})
	for k, item in MenuController.ITEMS do
		local b = Theme.iconButton({
			Name = item.key,
			icon = item.icon,
			label = item.label,
			color = item.color,
			Size = UDim2.fromOffset(70, 70),
			Parent = rail,
		})
		b.LayoutOrder = k
		local ring = Theme.new("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 14, 1, 14),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = b,
		}, { Theme.corner(24), Theme.stroke(5, Color3.fromRGB(255, 205, 40)) })
		b.Activated:Connect(function()
			if item.key == "town" then
				Net.send("Visit", b.Label.Text == "HOME" and "home" or "town")
				b.Label.Text = b.Label.Text == "HOME" and "TOWN" or "HOME"
				b.Icon.Text = b.Label.Text == "HOME" and "🏡" or "🏘️"
			else
				Bus.Panel:Fire(item.key)
			end
		end)
		refs.buttons[item.key] = b
		refs["ring_" .. item.key] = ring
	end
	Theme.compact(rail, 0.85)
	Bus.Highlight:Connect(function(name)
		pulsing = name
	end)
	RunService.Heartbeat:Connect(function()
		for key, b in refs.buttons do
			local ring = refs["ring_" .. key]
			local on = pulsing == key
			ring.Visible = on and (math.sin(os.clock() * 6) > -0.3)
			_ = b
		end
	end)
end

return MenuController
