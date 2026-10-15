--[[
Looking at someone's raft (VisitService sends a copy: "Visiting"). This client builds the copy on its own patch of
sea far from everyone (with its own water), swings the camera round it (drag to turn, scroll or pinch to zoom, it
turns slowly by itself), and puts a bar on top: whose raft, how big, and BACK. Your character stays home and can't
move meanwhile; nothing of the copy exists for the server, so nothing in it can be taken, built or broken.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local RaftModels = require(ReplicatedStorage.Shared.World.RaftModels)
local Bus = require(script.Parent.Parent.UI.Bus)
local Theme = require(script.Parent.Parent.UI.Theme)

local VisitController = { Name = "VisitController", Order = 40 }

local player = Players.LocalPlayer
local C = Theme.Color
local SHOWROOM = Vector3.new(0, Constants.WATER_LEVEL, Constants.OCEAN_SIZE / 2 + 2500) -- far past the ocean's edge
local gui, bar, title, sub
local current -- { snap, folder, center, radius, yaw, pitch, dist }
local dragging, lastPos

local function setControls(on)
	pcall(function()
		local module = require(player:WaitForChild("PlayerScripts", 2):WaitForChild("PlayerModule", 2))
		local controls = module:GetControls()
		if on then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

function VisitController.leave()
	if not current then
		return
	end
	current.folder:Destroy()
	current = nil
	bar.Visible = false
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			cam.CameraSubject = hum
		end
	end
	setControls(true)
end

function VisitController.show(snap)
	if type(snap) ~= "table" or type(snap.pieces) ~= "table" then
		return
	end
	VisitController.leave()
	Bus.Close:Fire()
	local folder = Instance.new("Folder")
	folder.Name = "Showroom"
	folder.Parent = workspace
	-- its own bit of sea
	local water = Instance.new("Part")
	water.Name = "Sea"
	water.Anchored = true
	water.CanCollide = false
	water.CanQuery = false
	water.Size = Vector3.new(900, 1, 900)
	water.CFrame = CFrame.new(SHOWROOM - Vector3.new(0, 0.6, 0))
	water.Color = Color3.fromRGB(52, 140, 190)
	water.Material = Enum.Material.SmoothPlastic
	water.Reflectance = 0.15
	water.Transparency = 0.1
	water.Parent = folder
	-- the raft, the way RaftService builds it
	local far = 0
	local opts = { colours = snap.colours or {} }
	for _, p in snap.pieces do
		local def = Pieces.get(p.key)
		if def then
			local pos = Formulas.tilePosition(SHOWROOM, p.gx, p.gz, p.level or 1)
			local cf = def.edge and CFrame.new(pos)
				or CFrame.new(pos) * CFrame.Angles(0, -(p.rot or 0) * math.pi / 2, 0)
			local ok, m =
				pcall(RaftModels.build, p.key, cf, { colours = opts.colours, edge = def.edge and p.rot or nil }, folder)
			if ok and m then
				for _, d in m:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanTouch = false
					elseif d:IsA("ProximityPrompt") then
						d:Destroy()
					end
				end
			end
			far = math.max(far, (Vector3.new(pos.X - SHOWROOM.X, 0, pos.Z - SHOWROOM.Z)).Magnitude)
		end
	end
	local radius = math.max(12, far + Constants.TILE)
	current = {
		snap = snap,
		folder = folder,
		center = SHOWROOM + Vector3.new(0, 3, 0),
		radius = radius,
		yaw = math.rad(35),
		pitch = math.rad(28),
		dist = radius * 2.2,
	}
	title.Text = `👀 {string.upper(snap.name or "?")}'S RAFT`
	sub.Text = `{snap.tierName or ""} · {snap.tiles or 0} floors · just looking, nothing here can be touched`
	bar.Visible = true
	setControls(false)
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
	end
end

local function step(dt)
	if not current then
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if not dragging then
		current.yaw += dt * 0.12
	end
	local c = current.center
	local d = current.dist
	local offset = Vector3.new(
		math.cos(current.yaw) * math.cos(current.pitch),
		math.sin(current.pitch),
		math.sin(current.yaw) * math.cos(current.pitch)
	) * d
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(c + offset, c)
end

function VisitController:init()
	gui = Theme.screen("Visit", 26, player:WaitForChild("PlayerGui"))
	bar = Theme.slab({
		Name = "VisitBar",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(620, 64),
		BackgroundColor3 = Color3.fromRGB(40, 90, 150),
		Visible = false,
		Parent = gui,
	})
	title = Theme.title({
		Name = "Title",
		Text = "",
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(1, -150, 0, 30),
		TextSize = 20,
		Parent = bar,
	})
	sub = Theme.title({
		Name = "Sub",
		Text = "",
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -150, 0, 24),
		TextSize = 13,
		outline = 2,
		Parent = bar,
	})
	local back = Theme.button({
		Name = "Back",
		Text = "⬅ BACK",
		BackgroundColor3 = C.good,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(120, 46),
		Parent = bar,
	})
	back.Activated:Connect(function()
		VisitController.leave()
		Bus.Tap:Fire("visit_back")
	end)
	Net.listen("Visiting", VisitController.show)
	-- drag to turn, wheel / pinch to zoom
	UserInputService.InputBegan:Connect(function(input, processed)
		if not current or processed then
			return
		end
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = true
			lastPos = input.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = false
		end
	end)
	local changed = UserInputService.InputChanged
	if not changed then
		return RunService.RenderStepped:Connect(step)
	end
	changed:Connect(function(input)
		if not current then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			current.dist = math.clamp(current.dist * (input.Position.Z > 0 and 0.88 or 1.12), 10, current.radius * 5)
		elseif
			dragging
			and lastPos
			and (
				input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
			)
		then
			local delta = input.Position - lastPos
			lastPos = input.Position
			current.yaw += delta.X * 0.008
			current.pitch = math.clamp(current.pitch + delta.Y * 0.006, math.rad(8), math.rad(80))
		end
	end)
	pcall(function()
		UserInputService.TouchPinch:Connect(function(_, scale)
			if current then
				current.dist = math.clamp(current.dist / scale, 10, current.radius * 5)
			end
		end)
	end)
	RunService.RenderStepped:Connect(step)
end

-- (tests)
function VisitController.current()
	return current
end

return VisitController
