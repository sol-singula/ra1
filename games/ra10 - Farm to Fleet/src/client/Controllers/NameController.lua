--[[
Naming your farm (NameService): the NAME button on the menu opens a small panel with a box to type in and SAVE
(Net "Name"). The name goes on the sign by the road and the street board. The profile's farmName is what it is now.

  NameController.refs   the panel's pieces (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Bus = require(script.Parent.Parent.UI.Bus)
local Panel = require(script.Parent.Parent.UI.Panel)
local Theme = require(script.Parent.Parent.UI.Theme)

local NameController = { Name = "NameController", Order = 62 }

local BLUE = Color3.fromRGB(90, 120, 200)
local refs = {}
NameController.refs = refs

function NameController:init()
	local panel = Panel.new("name", "NAME YOUR FARM", BLUE, Vector2.new(460, 230))
	refs.panel = panel
	local body = panel.body
	Theme.text({
		Name = "Hint",
		Text = "Pick a name for your farm. It goes on your sign by the road.\n3 to 24 letters.",
		Size = UDim2.new(1, 0, 0, 44),
		TextYAlignment = Enum.TextYAlignment.Top,
		fit = 15,
		Parent = body,
	})
	local box = Theme.new("TextBox", {
		Name = "Box",
		Text = "",
		PlaceholderText = "Sunny Acres",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Color3.new(1, 1, 1),
		TextColor3 = Color3.fromRGB(30, 34, 44),
		Font = Theme.Display,
		TextSize = 22,
		ClearTextOnFocus = false,
		Parent = body,
	}, { Theme.corner(10), Theme.stroke(2, BLUE) })
	refs.box = box
	local save = Theme.button({
		Name = "Save",
		Text = "SAVE",
		BackgroundColor3 = Color3.fromRGB(80, 190, 90),
		Position = UDim2.fromOffset(0, 116),
		Size = UDim2.new(1, 0, 0, 50),
		Parent = body,
	})
	refs.save = save
	local function send()
		local text = box.Text
		if #text >= 3 then
			Bus.Tap:Fire("name_save")
			Net.send("Name", text)
			Bus.Panel:Fire(nil)
		end
	end
	save.Activated:Connect(send)
	if box.FocusLost then -- (the mock has no keyboard)
		box.FocusLost:Connect(function(enter)
			if enter then
				send()
			end
		end)
	end
	panel.onOpen = function()
		local p = Store.get("profile")
		box.Text = p and p.farmName or ""
	end
end

return NameController
