--[[
A menu panel (the calendar, the street, friends, the franchise, the shop): a big card in the middle of the screen
with a coloured header and a close button. One is open at a time: Bus.Panel(name) opens that one and closes the
rest, Bus.Panel(nil) closes them all (MenuController's buttons fire it).

  local panel = Panel.new("calendar", "CALENDAR", color, Vector2.new(620, 400))
  panel.body      the frame under the header to fill
  panel.onOpen    fn() called each time it opens (ask the server for fresh numbers)
  Panel.current() the open one's name, or nil
]]
local Players = game:GetService("Players")

local Bus = require(script.Parent.Bus)
local Layout = require(script.Parent.Layout)
local Theme = require(script.Parent.Theme)

local Panel = {}
Panel.__index = Panel

local current
local panels = {}

function Panel.current()
	return current
end

function Panel.new(name, title, color, size)
	local self = setmetatable({ name = name }, Panel)
	local gui = Theme.screen("Panel_" .. name, 20, Players.LocalPlayer:WaitForChild("PlayerGui"))
	self.gui = gui
	size = size or Vector2.new(620, 400)
	self.card = Theme.card({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size.X, size.Y),
		Visible = false,
		Parent = gui,
	})
	local _, head = Theme.cardHeader(self.card, title, 46, color)
	self.title = head
	Theme.closeButton(self.card, function()
		Bus.Panel:Fire(nil)
	end, { Position = UDim2.new(1, -42, 0, 5) })
	self.body = Theme.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 54),
		Size = UDim2.new(1, -24, 1, -64),
		Parent = self.card,
	})
	Layout.modal("panel_" .. name, self.card)
	panels[name] = self
	return self
end

function Panel:isOpen()
	return self.card.Visible
end

local function show(name)
	current = name
	for key, p in panels do
		local on = key == name
		if on and not p.card.Visible then
			p.card.Visible = true
			Theme.pop(p.card)
			if p.onOpen then
				task.spawn(p.onOpen)
			end
		elseif not on then
			p.card.Visible = false
		end
	end
	Layout.setPanel(name ~= nil)
end

Bus.Panel:Connect(function(name)
	if name ~= nil and current == name then
		name = nil -- (its button again: close it)
	end
	show(name)
end)

return Panel
