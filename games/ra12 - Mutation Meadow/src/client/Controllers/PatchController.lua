--[[
Patch's lines on the client: one at a time, the rest queued Config.Patch.queueGapSec apart. A line hides when tapped,
after its hideSec, or on its hideOn action (you planted, harvested, watered); then the client tells the server
Settings:patchAck {id, how}. Bubble lines (bubble, shopBubble, and the bubble half of toast+board) show over Patch
(shopBubble also in the shop header); toast lines show at the top with Patch's portrait. Nothing here blocks input
or the camera: only the line itself takes a tap.

  PatchController.push(line)      queue a PatchLine
  PatchController.showing()       the line on screen (or nil)
  PatchController.history()       { { id, shownAt, hiddenAt, how } } (tests)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local UI = require(script.Parent.Parent.UI)

local PatchController = {}

local controllers
local queue = {}
local current, currentEntry
local history = {}
local bubble, toast
local busy = false
local token = 0

local HIDE_ACTION = { plant = { "Plot", "plant" }, harvest = { "Plot", "harvest" }, water = { "BlockParty", "water" } }

function PatchController.showing()
	return current
end

function PatchController.history()
	return history
end

local function isToast(line)
	return line.display == "toast" or line.display == "toast+board"
end

local pump

local function hide(how)
	if not current then
		return
	end
	local line = current
	current = nil
	token += 1
	bubble.Visible = false
	toast.Visible = false
	currentEntry.hiddenAt = Clock.now()
	currentEntry.how = how
	Net.send("Settings", "patchAck", { id = line.id, how = how })
	task.delay(Config.Patch.queueGapSec, function()
		busy = false
		pump()
	end)
end

local function show(line)
	current = line
	busy = true
	token += 1
	local mine = token
	currentEntry = { id = line.id, shownAt = Clock.now() }
	table.insert(history, currentEntry)
	if isToast(line) then
		toast.Line.Text = line.text
		toast.Visible = true
	else
		bubble.Line.Text = line.text
		bubble.Visible = true
	end
	if line.display == "shopBubble" and controllers.ShopController then
		controllers.ShopController.setGreeting(line.text)
	end
	task.delay(line.hideSec or 3, function()
		if token == mine and current == line then
			hide("timeout")
		end
	end)
end

function pump()
	if busy or current or #queue == 0 then
		return
	end
	show(table.remove(queue, 1))
end

function PatchController.push(line)
	if type(line) ~= "table" or type(line.text) ~= "string" then
		return
	end
	table.insert(queue, line)
	pump()
end

local function tapTarget(name, anchor, pos, size)
	local gui = UI.screen("Patch" .. name)
	gui.DisplayOrder = 20
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.Text = ""
	b.AnchorPoint = anchor
	b.Position = pos
	b.Size = size
	b.BackgroundColor3 = UI.COLORS.card
	b.Visible = false
	b.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = b
	UI.label(
		b,
		"",
		{ Name = "Line", Position = UDim2.fromOffset(70, 6), Size = UDim2.new(1, -80, 1, -12), TextWrapped = true }
	)
	UI.frame(b, {
		Name = "Portrait",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.fromOffset(54, 54),
		BackgroundColor3 = Color3.fromRGB(235, 120, 30),
	})
	b.Activated:Connect(function()
		if Config.Patch.tapToHide then
			hide("tap")
		end
	end)
	return b
end

function PatchController:Init(all)
	controllers = all
end

function PatchController:Start()
	bubble = tapTarget("Bubble", Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -140), UDim2.fromOffset(420, 70))
	toast = tapTarget("Toast", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12), UDim2.fromOffset(460, 70))
	Net.on("PatchLine", PatchController.push)
	Net.Sent:Connect(function(remote, action)
		local on = current and current.hideOn and HIDE_ACTION[current.hideOn]
		if on and on[1] == remote and on[2] == action then
			hide("action")
		end
	end)
end

return PatchController
