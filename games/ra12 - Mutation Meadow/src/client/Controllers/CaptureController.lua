--[[
The client half of the capture set: it follows Workspace.Capture's attributes (set by CaptureService through the
gated DevCommand "capture").

  Scene + not Free   the camera locks to Workspace.Capture.Cams.<scene> (Scriptable, its FieldOfView)
  Free               the normal camera again
  Hud = false        every other ScreenGui (HUD, toasts, Patch's lines) and the player list hide; Hud = true puts
                     each back exactly as it was
  Guides = true      an overlay: the scene's frame (16:9, or square for the icon), a line at the bottom
                     Config.Capture.safeBottom (keep key content above it), and a red warning when the viewport isn't
                     exactly the scene's size (1920x1080; the icon 1024x1024)
  Reveal (counter)   plays the in-game Golden reveal (Visuals.goldenReveal) on the staged HeroCrop
  SizeAsk (counter)  prints workspace.CurrentCamera.ViewportSize and whether it fits the scene ("capture size")

  CaptureController.apply()        re-reads the attributes (tests)
  CaptureController.hidden()       the ScreenGuis it hid
  CaptureController.sizeText()     what "capture size" prints
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Visuals = require(ReplicatedStorage.Shared.Visuals)

local CaptureController = {}

local hiddenGuis -- [ScreenGui] = was enabled
local playerListWas
local guides, frame, aspect, line, warning
local watched
local seen = { Reveal = 0, SizeAsk = 0 } -- the counters already acted on

local GUIDES_NAME = "CaptureGuides"

function CaptureController.hidden()
	return hiddenGuis
end

local function setHud(on)
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	if not on and not hiddenGuis then
		hiddenGuis = {}
		for _, g in gui:GetChildren() do
			if g:IsA("ScreenGui") and g.Name ~= GUIDES_NAME then
				hiddenGuis[g] = g.Enabled
				g.Enabled = false
			end
		end
		local ok, was = pcall(function()
			return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
		end)
		playerListWas = if ok then was else true
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
	elseif on and hiddenGuis then
		for g, was in hiddenGuis do
			g.Enabled = was
		end
		hiddenGuis = nil
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, playerListWas)
		end)
	end
end

local function setCamera(folder)
	local camera = workspace.CurrentCamera
	local scene = folder:GetAttribute("Scene")
	local cam = scene and folder:FindFirstChild("Cams") and folder.Cams:FindFirstChild(scene)
	if folder:GetAttribute("Free") or not cam then
		camera.CameraType = Enum.CameraType.Custom
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cam.CFrame
	camera.FieldOfView = cam:GetAttribute("FieldOfView") or 55
	if aspect then
		aspect.AspectRatio = (cam:GetAttribute("Width") or 16) / (cam:GetAttribute("Height") or 9)
	end
end

-- the size the current scene wants (its camera's Width x Height), or nil with no scene
local function wanted(folder)
	local scene = folder and folder:GetAttribute("Scene")
	local cam = scene and folder:FindFirstChild("Cams") and folder.Cams:FindFirstChild(scene)
	if not cam then
		return nil
	end
	return cam:GetAttribute("Width"), cam:GetAttribute("Height"), scene
end

local function viewport()
	local size = workspace.CurrentCamera.ViewportSize
	return math.floor(size.X + 0.5), math.floor(size.Y + 0.5)
end

function CaptureController.sizeText()
	local w, h = viewport()
	local text = `capture size: {w}x{h}`
	local ww, wh, scene = wanted(workspace:FindFirstChild("Capture"))
	if ww then
		if w == ww and h == wh then
			text ..= ` (fits {scene})`
		else
			text ..= ` (WRONG: {scene} wants {ww}x{wh})`
		end
	end
	return text
end

local function checkSize(folder)
	if not warning then
		return
	end
	local ww, wh = wanted(folder)
	local w, h = viewport()
	local wrong = ww ~= nil and (w ~= ww or h ~= wh)
	warning.Visible = wrong
	if wrong then
		warning.Text = `Viewport {w}x{h}: this scene needs exactly {ww}x{wh}`
	end
end

local function makeGuides()
	local gui = Instance.new("ScreenGui")
	gui.Name = GUIDES_NAME
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 100
	frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 60, 60)
	stroke.Parent = frame
	aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = Config.Capture.thumb[1] / Config.Capture.thumb[2]
	aspect.Parent = frame
	line = Instance.new("Frame")
	line.Name = "SafeLine"
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position = UDim2.fromScale(0, 1 - Config.Capture.safeBottom)
	line.Size = UDim2.new(1, 0, 0, 2)
	line.BackgroundColor3 = Color3.fromRGB(255, 220, 0)
	line.BorderSizePixel = 0
	line.Parent = frame
	frame.Parent = gui
	warning = Instance.new("TextLabel")
	warning.Name = "SizeWarning"
	warning.AnchorPoint = Vector2.new(0.5, 0)
	warning.Position = UDim2.new(0.5, 0, 0, 8)
	warning.Size = UDim2.fromOffset(560, 36)
	warning.BackgroundColor3 = Color3.fromRGB(200, 30, 30)
	warning.TextColor3 = Color3.new(1, 1, 1)
	warning.Font = Enum.Font.GothamBold
	warning.TextScaled = true
	warning.Text = ""
	warning.Visible = false
	warning.Parent = gui
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui", 10)
	return gui
end

function CaptureController.apply()
	local folder = workspace:FindFirstChild("Capture")
	if not folder then
		return
	end
	if folder ~= watched then
		watched = folder
		for _, attr in { "Scene", "Free", "Hud", "Guides", "Reveal", "SizeAsk" } do
			folder:GetAttributeChangedSignal(attr):Connect(CaptureController.apply)
		end
		-- counters already set before we watched are history, not requests
		seen.Reveal = folder:GetAttribute("Reveal") or 0
		seen.SizeAsk = folder:GetAttribute("SizeAsk") or 0
	end
	setCamera(folder)
	setHud(folder:GetAttribute("Hud") ~= false)
	guides.Enabled = folder:GetAttribute("Guides") == true
	checkSize(folder)
	local reveal = folder:GetAttribute("Reveal") or 0
	if reveal > seen.Reveal then
		seen.Reveal = reveal
		local stage = folder:FindFirstChild("Stage")
		local hero = stage and stage:FindFirstChild("HeroCrop")
		if hero then
			Visuals.goldenReveal(hero)
		end
	end
	local ask = folder:GetAttribute("SizeAsk") or 0
	if ask > seen.SizeAsk then
		seen.SizeAsk = ask
		print(CaptureController.sizeText())
	end
end

function CaptureController:Start()
	guides = makeGuides()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		checkSize(workspace:FindFirstChild("Capture"))
	end)
	CaptureController.apply()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 then
			acc = 0
			if workspace:FindFirstChild("Capture") ~= watched then
				CaptureController.apply()
			end
		end
	end)
end

return CaptureController
