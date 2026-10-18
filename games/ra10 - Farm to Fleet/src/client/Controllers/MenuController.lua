--[[
The menu bar: a row of big icon buttons along the top right, each opening its panel (UI/Panel via Bus.Panel):

  CALENDAR   the 7-day calendar and the weekly Big Contract (DailyController); a red dot when the day's reward waits
  STREET     the street's operations, visiting, likes and the Hall of Fame (StreetController)
  FRIENDS    friends' operations across servers, and Join (StreetController)
  FRANCHISE  sell the company for Stars, the perks (FranchiseController); shown once the market hall stands or
             after a first franchise
  SHOP       Gems, passes, the starter pack (ShopController)

  MenuController.dot(name, on)    the red dot on a button
  MenuController.show(name, on)   a button on or off the bar
  MenuController.refs             the buttons (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local MenuController = { Name = "MenuController", Order = 15 }

local player = Players.LocalPlayer
local refs = { buttons = {}, dots = {} }
MenuController.refs = refs

-- stylua: ignore start
MenuController.ITEMS = {
	{ key = "calendar",  icon = "📅", label = "DAILY",     color = Color3.fromRGB(240, 120, 60) },
	{ key = "street",    icon = "🏁", label = "STREET",    color = Color3.fromRGB(70, 150, 230) },
	{ key = "friends",   icon = "👥", label = "FRIENDS",   color = Color3.fromRGB(150, 100, 220) },
	{ key = "franchise", icon = "⭐", label = "FRANCHISE", color = Color3.fromRGB(235, 175, 30) },
	{ key = "shop",      icon = "🛒", label = "SHOP",      color = Color3.fromRGB(60, 185, 90) },
}
-- stylua: ignore end
local SIZE, GAP = 58, 8
local hidden = { franchise = true }

local function layout()
	local x = 0
	for i = #MenuController.ITEMS, 1, -1 do
		local item = MenuController.ITEMS[i]
		local b = refs.buttons[item.key]
		b.Visible = not hidden[item.key]
		if b.Visible then
			b.Position = UDim2.new(1, -12 - x, 0, 8)
			x += SIZE + GAP
		end
	end
end

function MenuController.dot(name, on)
	if refs.dots[name] then
		refs.dots[name].Visible = on == true
	end
end

function MenuController.show(name, on)
	hidden[name] = not on or nil
	if refs.bar then
		layout()
	end
end

function MenuController:init()
	local gui = Theme.screen("Menu", 8, player:WaitForChild("PlayerGui"))
	refs.bar = gui
	for _, item in MenuController.ITEMS do
		local b, dot = Theme.iconButton({
			Name = item.key,
			icon = item.icon,
			label = item.label,
			color = item.color,
			Size = UDim2.fromOffset(SIZE, SIZE),
			AnchorPoint = Vector2.new(1, 0),
			Parent = gui,
		})
		b.Activated:Connect(function()
			Bus.Tap:Fire("menu_" .. item.key)
			Bus.Panel:Fire(item.key)
		end)
		refs.buttons[item.key] = b
		refs.dots[item.key] = dot
	end
	layout()
	-- (the calendar's dot: the day's reward is waiting)
	Store.Changed:Connect(function(partial)
		if partial.daily ~= nil then
			local d = partial.daily
			MenuController.dot("calendar", type(d) == "table" and d.today and d.today.ready == true)
		end
	end)
	-- (the franchise shows up once it can be done, or has been)
	Net.listen("Franchise", function(m)
		if type(m) == "table" then
			MenuController.show("franchise", m.open == true or (m.level or 0) > 0)
			MenuController.dot("franchise", m.ready == true)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			Bus.Panel:Fire(nil)
		end
	end)
end

return MenuController
