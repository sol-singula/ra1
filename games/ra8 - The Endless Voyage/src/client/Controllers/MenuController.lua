--[[
The start menu. On a public server (Mode "hub") it asks how you want to play, over the ocean behind it:
  🏝️ MY WORLD   your own ocean: your raft, friends you invite, and it always saves
  🌍 ONLINE     one giant ship that everyone builds together, any time you like
ModeService does the travelling; in Studio (or if travel fails) the menu closes and you play right where you are.
The same choices sit in ⚙️ MORE later (PanelController). A small badge in the corner says where you are.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Mode = require(ReplicatedStorage.Shared.Mode)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local MenuController = { Name = "MenuController", Order = 5 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui, shade, status, badge
local buttons = {}

local CHOICES = {
	{
		key = "world",
		icon = "🏝️",
		title = "MY WORLD",
		text = "Your own ocean and your own raft. Invite your friends. Everything saves.",
		color = Color3.fromRGB(70, 160, 90),
	},
	{
		key = "online",
		icon = "🌍",
		title = "ONLINE",
		text = "One GIANT ship that everyone builds together. Hop on any time!",
		color = Color3.fromRGB(60, 120, 210),
	},
}

local function setBusy(text)
	status.Text = text or ""
	for _, b in buttons do
		b.Active = text == nil
		b.AutoButtonColor = text == nil
	end
end

function MenuController.open()
	shade.Visible = true
	setBusy(nil)
	Theme.pop(shade:FindFirstChild("Box"))
end

function MenuController.close()
	shade.Visible = false
end

function MenuController.choose(kind)
	if not shade.Visible then
		-- (from ⚙️ MORE)
		shade.Visible = true
	end
	setBusy(kind == "world" and "⛵ Sailing to your world..." or "🌍 Sailing to the giant ship...")
	Bus.Tap:Fire("menu_" .. kind)
	Net.send("Mode", kind)
end

local function updateBadge()
	local mode = Mode.get()
	if mode == "world" then
		local name = workspace:GetAttribute("WorldOwnerName")
		local mine = workspace:GetAttribute("WorldOwner") == player.UserId
		badge.Text = mine and "🏝️ YOUR WORLD" or `🏝️ {name ~= "" and name or "A FRIEND"}'S WORLD`
	elseif mode == "online" then
		local raft = Store.get("raft")
		badge.Text = `🌍 ONLINE · THE GIANT SHIP{raft and raft.crew and ` · {raft.crew} aboard` or ""}`
	else
		badge.Text = "🌊 PUBLIC OCEAN"
	end
end

function MenuController:init()
	gui = Theme.screen("Menu", 30, player:WaitForChild("PlayerGui"))
	badge = Theme.title({
		Name = "Badge",
		Text = "",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.fromOffset(380, 22),
		TextSize = 15,
		outline = 2,
		Parent = gui,
	})
	shade = new("Frame", {
		Name = "Shade",
		BackgroundColor3 = Color3.fromRGB(10, 30, 50),
		BackgroundTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Active = true,
		Visible = false,
		Parent = gui,
	})
	local box = Theme.card({
		Name = "Box",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(640, 380),
		Parent = shade,
	})
	Theme.title({
		Name = "Title",
		Text = "THE ENDLESS VOYAGE",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.new(1, -20, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.mustard,
		TextSize = 34,
		Parent = box,
	})
	Theme.text({
		Name = "Ask",
		Text = "How do you want to play?",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 62),
		Size = UDim2.new(1, -20, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 18,
		Parent = box,
	})
	for i, choice in CHOICES do
		local b = Theme.button({
			Name = "Choice_" .. choice.key,
			Text = "",
			BackgroundColor3 = choice.color,
			Position = UDim2.new((i - 1) * 0.5, 14, 0, 98),
			Size = UDim2.new(0.5, -21, 0, 210),
			Parent = box,
		})
		Theme.text({
			Name = "Icon",
			Text = choice.icon,
			Size = UDim2.new(1, 0, 0, 64),
			Position = UDim2.fromOffset(0, 10),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = b,
		})
		Theme.title({
			Name = "Label",
			Text = choice.title,
			Size = UDim2.new(1, -16, 0, 34),
			Position = UDim2.fromOffset(8, 78),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 26,
			Parent = b,
		})
		Theme.title({
			Name = "Text",
			Text = choice.text,
			Size = UDim2.new(1, -24, 0, 80),
			Position = UDim2.fromOffset(12, 116),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextSize = 16,
			outline = 2,
			Parent = b,
		})
		b.Activated:Connect(function()
			if b.Active then
				MenuController.choose(choice.key)
			end
		end)
		buttons[choice.key] = b
	end
	status = Theme.text({
		Name = "Status",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextColor3 = C.muted,
		Parent = box,
	})
	status.Text = ""
	Net.listen("Menu", function(m)
		if type(m) ~= "table" then
			return
		end
		if m.travelling then
			setBusy(m.travelling == "friend" and "💌 Sailing to your friend's world..." or status.Text)
			shade.Visible = true
		elseif m.close then
			if m.note then
				setBusy(m.note)
				task.delay(2.5, MenuController.close)
			else
				MenuController.close()
			end
		end
	end)
	Bus.Menu:Connect(function(kind)
		if kind then
			MenuController.choose(kind)
		else
			MenuController.open()
		end
	end)
	workspace:GetAttributeChangedSignal("Mode"):Connect(updateBadge)
	Store.Changed:Connect(function(partial)
		if partial.raft then
			updateBadge()
		end
	end)
	updateBadge()
	-- a public server asks how you want to play (a reserved one already knows)
	task.delay(0.5, function()
		updateBadge()
		if Mode.get() == "hub" then
			MenuController.open()
		end
	end)
end

-- (tests)
MenuController.buttons = buttons
function MenuController.isOpen()
	return shade.Visible
end
function MenuController.status()
	return status.Text
end

return MenuController
