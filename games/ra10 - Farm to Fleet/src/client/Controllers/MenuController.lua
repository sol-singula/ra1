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
  MenuController.UNLOCK           the guide step each button waits for (a new farmer's screen stays clear)
  MenuController.unlocked(name)
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
	{ key = "name",      icon = "✏️", label = "NAME",      color = Color3.fromRGB(90, 120, 200) },
}
-- stylua: ignore end
local SIZE, GAP = 58, 8
local hidden = { franchise = true }
-- (a new farmer sees only what the guide has reached: the guide step that unlocks each button)
MenuController.UNLOCK = { calendar = 6, shop = 6, street = 21, friends = 21, name = 6 }
local locked = { calendar = true, shop = true, street = true, friends = true, name = true }

local function layout()
	local x = 0
	for i = #MenuController.ITEMS, 1, -1 do
		local item = MenuController.ITEMS[i]
		local b = refs.buttons[item.key]
		b.Visible = not hidden[item.key] and not locked[item.key]
		if b.Visible then
			b.Position = UDim2.new(1, -12 - x, 0, 8)
			x += SIZE + GAP
		end
	end
end

function MenuController.unlocked(name)
	return not locked[name]
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
	-- (the guide pointing at a menu button: it pulses)
	local pulse
	Net.listen("Guide", function(m)
		pulse = type(m) == "table" and m.menu or nil
		if type(m) == "table" then
			local changed = false
			for key, at in MenuController.UNLOCK do
				local open = m.generated == true or (m.step or 0) >= at
				if open == (locked[key] == true) then
					locked[key] = not open or nil
					changed = true
				end
			end
			if changed then
				layout()
			end
		end
	end)
	game:GetService("RunService").Heartbeat:Connect(function()
		for key, b in refs.buttons do
			local scale = b:FindFirstChild("Press")
			if key == pulse and scale then
				scale.Scale = 1 + 0.08 * math.abs(math.sin(os.clock() * 4))
			elseif scale and scale:GetAttribute("Pulsed") then
				scale.Scale = 1
			end
			if scale then
				scale:SetAttribute("Pulsed", key == pulse or nil)
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then
			Bus.Panel:Fire(nil)
		end
	end)
end

return MenuController
