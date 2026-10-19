--[[
The camera (master plan §8): teaches, celebrates and reveals, then gives control back with the next task in view.

  the opening   a brand-new player's first 3.5 s: an elevated view of the farm, a glide to the stand as a
                customer buys, then it settles behind the player with the first tile lit; SKIP any time; never
                again on a later login
  reveals       Net "Camera": "reveal" pulls back to show the new building (4 s); "machine" follows the harvester
                for 4 s; "crop" a close-up of the first tile (2 s). All skippable with a tap; none while a
                purchase prompt is up.

  CameraController.playing()   true while a move runs (tests)
  CameraController.skip()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Layout = require(ReplicatedStorage.Shared.World.Layout)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local CameraController = { Name = "CameraController", Order = 50 }

local player = Players.LocalPlayer
local refs = {}
CameraController.refs = refs
local move -- { t0, seconds, keys = { {t, pos, look} ... } }
local opened = false

function CameraController.playing()
	return move ~= nil
end

local function territoryIndex()
	local t = Store.get("territory")
	return t and t.index
end

local function finish()
	move = nil
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
	end
	refs.skip.Visible = false
	refs.bars.Visible = false
end

function CameraController.skip()
	if move then
		finish()
	end
end

local function play(keys, seconds)
	local cam = workspace.CurrentCamera
	if not cam or Theme.reducedMotion() then
		return
	end
	move = { t0 = os.clock(), seconds = seconds, keys = keys }
	cam.CameraType = Enum.CameraType.Scriptable
	refs.skip.Visible = true
	refs.bars.Visible = true
end

local function at(x, z, y)
	return Layout.toWorld(territoryIndex(), x, z, y)
end

local function opening()
	if opened or not territoryIndex() then
		return
	end
	opened = true
	local s = Layout.SPOTS.stand
	local f = Layout.FIELDS.field1
	local tile = at(f.x, f.z, 1)
	play({
		{ t = 0, pos = at(0, -110, 45), look = at(0, -20, 0) },
		{ t = 1.5, pos = at(s.x + 10, s.z - 18, 9), look = at(s.x, s.z, 3) },
		{ t = 2.5, pos = at(f.x - 6, f.z - 14, 9), look = tile },
		{ t = 3.5, pos = at(f.x - 6, f.z - 14, 9), look = tile },
	}, 3.5)
	pcall(Net.send, "Analytics", "opening", { seen = true })
end

local function reveal(c)
	local i = territoryIndex()
	if not i then
		return
	end
	if c.kind == "reveal" then
		local w = Layout.SPOTS.warehouse
		local s = Layout.SPOTS.stand
		if c.key == "shop" then
			play({
				{ t = 0, pos = at(s.x + 24, s.z - 30, 14), look = at(s.x, s.z, 4) },
				{ t = 4, pos = at(s.x - 24, s.z - 34, 18), look = at(s.x, s.z, 4) },
			}, 4)
		else
			play({
				{ t = 0, pos = at(w.x + 60, w.z - 50, 40), look = at(w.x, w.z, 6) },
				{ t = 4.5, pos = at(w.x - 20, w.z - 70, 50), look = at(w.x, w.z, 6) },
			}, 4.5)
		end
	elseif c.kind == "machine" then
		local sh = Layout.SPOTS.shed
		play({
			{ t = 0, pos = at(sh.x + 14, sh.z - 16, 10), look = at(sh.x, sh.z, 2) },
			{ t = 4, pos = at(sh.x - 30, sh.z - 30, 16), look = at(0, -10, 2) },
		}, 4)
	elseif c.kind == "crop" then
		local f = Layout.FIELDS.field1
		play({
			{ t = 0, pos = at(f.x - 5, f.z - 8, 5), look = at(f.x, f.z, 1) },
			{ t = 2, pos = at(f.x - 8, f.z - 12, 8), look = at(f.x, f.z, 1) },
		}, 2)
	end
end

function CameraController:init()
	local gui = Theme.screen("Camera", 30, player:WaitForChild("PlayerGui"))
	refs.gui = gui
	refs.bars = Theme.new(
		"Frame",
		{ Name = "Bars", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = gui }
	)
	for _, y in { 0, 1 } do
		Theme.new("Frame", {
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 56),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			Parent = refs.bars,
		})
	end
	refs.skip = Theme.button({
		Name = "Skip",
		Text = "SKIP",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -70),
		Size = UDim2.fromOffset(120, 44),
		BackgroundColor3 = Theme.Color.slate,
		Visible = false,
		Parent = gui,
	})
	refs.skip.Activated:Connect(CameraController.skip)
	UserInputService.InputBegan:Connect(function(input, processed)
		if
			move
			and not processed
			and (input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.Touch)
		then
			CameraController.skip()
		end
	end)
	Net.listen("Camera", function(c)
		if type(c) == "table" then
			if c.kind == "opening" then
				opening()
			else
				reveal(c)
			end
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not move then
			return
		end
		local cam = workspace.CurrentCamera
		local t = os.clock() - move.t0
		if t >= move.seconds then
			finish()
			return
		end
		local keys = move.keys
		local a, b = keys[1], keys[#keys]
		for k = 1, #keys - 1 do
			if t >= keys[k].t and t <= keys[k + 1].t then
				a, b = keys[k], keys[k + 1]
				break
			end
		end
		local span = math.max(0.001, b.t - a.t)
		local k = math.clamp((t - a.t) / span, 0, 1)
		k = k * k * (3 - 2 * k)
		cam.CFrame = CFrame.lookAt(a.pos:Lerp(b.pos, k), a.look:Lerp(b.look, k))
	end)
end

return CameraController
