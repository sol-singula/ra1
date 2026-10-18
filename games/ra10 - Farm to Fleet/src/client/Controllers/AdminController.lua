--[[
The admin panel (AdminService): a red ADMIN button at the top left for an admin (Net "AdminState"), opening a panel
to reset a farmer's progress by name (Net "Admin" "reset"), or give them Cash for a test ("give").

  AdminController.refs   the button and panel's pieces (tests)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Panel = require(script.Parent.Parent.UI.Panel)
local Theme = require(script.Parent.Parent.UI.Theme)

local AdminController = { Name = "AdminController", Order = 64 }

local RED = Color3.fromRGB(220, 60, 60)
local player = Players.LocalPlayer
local refs = {}
AdminController.refs = refs
local armed = false

local function box(parent, name, placeholder, y)
	return Theme.new("TextBox", {
		Name = name,
		Text = "",
		PlaceholderText = placeholder,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Color3.new(1, 1, 1),
		TextColor3 = Color3.fromRGB(30, 34, 44),
		Font = Theme.Display,
		TextSize = 20,
		ClearTextOnFocus = false,
		Parent = parent,
	}, { Theme.corner(10), Theme.stroke(2, RED) })
end

function AdminController:init()
	local gui = Theme.screen("Admin", 9, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	local button = Theme.button({
		Name = "Admin",
		Text = "ADMIN",
		Position = UDim2.fromOffset(12, 330),
		Size = UDim2.fromOffset(96, 40),
		BackgroundColor3 = RED,
		Visible = false,
		Parent = gui,
	})
	refs.button = button
	button.Activated:Connect(function()
		Bus.Panel:Fire("admin")
	end)
	local panel = Panel.new("admin", "ADMIN", RED, Vector2.new(460, 300))
	refs.panel = panel
	local body = panel.body
	Theme.text({
		Name = "Hint",
		Text = "Type a farmer's name (in this server, or not).",
		Size = UDim2.new(1, 0, 0, 24),
		fit = 15,
		Parent = body,
	})
	refs.name = box(body, "Name", "username", 30)
	local reset = Theme.button({
		Name = "Reset",
		Text = "RESET THEIR FARM",
		BackgroundColor3 = RED,
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 48),
		Parent = body,
	})
	refs.reset = reset
	reset.Activated:Connect(function()
		local name = refs.name.Text
		if #name == 0 then
			return
		end
		if not armed then
			armed = true
			reset.Text = `REALLY RESET {string.upper(name)}? TAP AGAIN`
			task.delay(4, function()
				armed = false
				reset.Text = "RESET THEIR FARM"
			end)
			return
		end
		armed = false
		reset.Text = "RESET THEIR FARM"
		Net.send("Admin", "reset", name)
	end)
	refs.amount = box(body, "Amount", "cash to give", 144)
	local give = Theme.button({
		Name = "Give",
		Text = "GIVE CASH",
		BackgroundColor3 = Color3.fromRGB(80, 190, 90),
		Position = UDim2.fromOffset(0, 198),
		Size = UDim2.new(1, 0, 0, 48),
		Parent = body,
	})
	refs.give = give
	give.Activated:Connect(function()
		local n = tonumber(refs.amount.Text)
		if #refs.name.Text > 0 and n then
			Net.send("Admin", "give", refs.name.Text, n)
		end
	end)
	Net.listen("AdminState", function(m)
		button.Visible = type(m) == "table" and m.admin == true
	end)
end

return AdminController
