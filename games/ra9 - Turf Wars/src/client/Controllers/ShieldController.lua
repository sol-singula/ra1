--[[
The comeback shield, from your side of the screen (the server makes the bubble everyone sees round the body and
decides everything: CombatService:GiveShield, Net "Shield"):

  yours goes up    "COMEBACK SHIELD" pops in the middle for a moment, with "BLOCKS 1 HIT" under it
  yours breaks     a big "SHIELD!" pop and the shield's sound: that hit would have knocked you out
  someone else's   a "SHIELD!" pops where they stand (the shooter sees why their arrow didn't count), and the sound
                   plays there

  ShieldController.pop()      the centre pop on screen (TextLabel) or nil
  ShieldController.lastWorld() the last "SHIELD!" popped in the world (BillboardGui) or nil
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)
local AudioController = require(script.Parent.AudioController)

local ShieldController = { Name = "ShieldController", Order = 59 }

local player = Players.LocalPlayer
local CYAN = Color3.fromRGB(90, 215, 255)
local INK = Color3.fromRGB(30, 30, 34)

local gui, current, world

local function screen()
	if gui and gui.Parent then
		return gui
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "ShieldPop"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

-- A word popping in over the middle (above the crosshair), gone after `seconds`
local function centre(text, sub, seconds)
	if current then
		current:Destroy()
	end
	local l = Instance.new("TextLabel")
	l.Name = "Pop"
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5, 0.32)
	l.Size = UDim2.fromScale(0.5, 0.11)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Theme.Display
	l.TextScaled = true
	l.TextColor3 = CYAN
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = 0
	if sub then
		local s = Instance.new("TextLabel")
		s.Name = "Sub"
		s.AnchorPoint = Vector2.new(0.5, 0)
		s.Position = UDim2.fromScale(0.5, 1)
		s.Size = UDim2.fromScale(0.6, 0.45)
		s.BackgroundTransparency = 1
		s.Text = sub
		s.Font = Theme.Display
		s.TextScaled = true
		s.TextColor3 = Color3.fromRGB(255, 255, 255)
		s.TextStrokeColor3 = INK
		s.TextStrokeTransparency = 0
		s.Parent = l
	end
	l.Parent = screen()
	Theme.pop(l)
	current = l
	task.delay(seconds, function()
		if current == l then
			current = nil
		end
		l:Destroy()
	end)
	return l
end

-- "SHIELD!" where someone's shield broke
local function inWorld(pos)
	local part = Instance.new("Part")
	part.Name = "ShieldPopAt"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
	local tag = Instance.new("BillboardGui")
	tag.Name = "ShieldPop"
	tag.Size = UDim2.fromOffset(150, 46)
	tag.AlwaysOnTop = true
	tag.Adornee = part
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "SHIELD!"
	l.Font = Theme.Display
	l.TextScaled = true
	l.TextColor3 = CYAN
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = 0
	l.Parent = tag
	tag.Parent = part
	part.Parent = workspace
	world = tag
	Theme.tween(tag, 0.9, { StudsOffset = Vector3.new(0, 2, 0) })
	Theme.tween(
		l,
		0.9,
		{ TextTransparency = 1, TextStrokeTransparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(1, function()
		part:Destroy()
	end)
	return tag
end

function ShieldController.pop()
	return current and current.Parent and current or nil
end

function ShieldController.lastWorld()
	return world and world.Parent and world or nil
end

function ShieldController.onShield(s)
	if type(s) ~= "table" then
		return
	end
	local mine = s.by == player.UserId
	if s.kind == "on" and mine then
		centre("COMEBACK SHIELD", "BLOCKS 1 HIT", 2)
	elseif s.kind == "break" then
		if mine then
			centre("SHIELD!", nil, 1.1)
			AudioController.play("shield")
		elseif typeof(s.pos) == "Vector3" then
			inWorld(s.pos)
			AudioController.playAt("shield", s.pos)
		end
	end
end

function ShieldController:init()
	Net.listen("Shield", ShieldController.onShield)
end

return ShieldController
