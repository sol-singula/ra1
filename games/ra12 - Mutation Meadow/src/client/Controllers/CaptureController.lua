--[[
The client half of the capture set: it follows Workspace.Capture's attributes (set by CaptureService through the
gated DevCommand "capture").

  Scene + not Free   the camera locks to Workspace.Capture.Cams.<scene> (Scriptable, its FieldOfView)
  Free               the normal camera again
  Hud = false        every other ScreenGui (HUD, toasts, Patch's lines) and the player list hide; Hud = true puts
                     each back exactly as it was
  Guides = true      an overlay: the scene's frame (16:9, or square for the icon) and a line at the bottom
                     Config.Capture.safeBottom (keep key content above it)

  CaptureController.apply()        re-reads the attributes (tests)
  CaptureController.hidden()       the ScreenGuis it hid
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)

local CaptureController = {}

local hiddenGuis -- [ScreenGui] = was enabled
local playerListWas
local guides, frame, aspect, line
local watched

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
		for _, attr in { "Scene", "Free", "Hud", "Guides" } do
			folder:GetAttributeChangedSignal(attr):Connect(CaptureController.apply)
		end
	end
	setCamera(folder)
	setHud(folder:GetAttribute("Hud") ~= false)
	guides.Enabled = folder:GetAttribute("Guides") == true
end

function CaptureController:Start()
	guides = makeGuides()
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
