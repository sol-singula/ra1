-- The rifle in your hands, in first person:
--   * in a fight zone (arena, duel, range) the camera locks to first person and you see your own rifle (a view
--     model that follows the camera); in the lobby it's the normal third-person camera
--   * the crosshair in the middle (your Style crosshair), wide and wobbly from the hip, a steady dot when scoped
--   * scope: right mouse (hold), the SCOPE button on phones (tap), L2 on a gamepad
--   * fire: left click, the FIRE button on phones, R2 on a gamepad. One shot, then the bolt (a ring fills up)
--   * light aim help on phones and gamepads while scoped: a shot that just misses a target bends onto it
-- The client sends where it fired from and which way; the server decides every pop.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local RifleModel = require(ReplicatedStorage.Shared.RifleModel)
local Rifles = require(ReplicatedStorage.Shared.Data.Rifles)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local C = Theme.Color
local new = Theme.new
local player = Players.LocalPlayer

local RifleController = { Name = "RifleController", Order = 20 }

local FIGHT_ZONES = { arena = true, duel = true, range = true }

local gui, crosshair, scopeOverlay, boltRing, boltFill, hitMarker, fireButton, scopeButton, swapButton
local viewModel, viewKey
local scoped, scopedAt = false, 0
local lastFire, clipShots = -math.huge, 0
local rng = Random.new()
local recoil = 0

RifleController.fired = 0 -- shots sent (tests read it)

local function camera()
	return workspace.CurrentCamera
end

local function inFight()
	return FIGHT_ZONES[player:GetAttribute("Zone") or ""] == true and not player:GetAttribute("Popped")
end
RifleController.inFight = inFight

local function rifle()
	local lo = Store.state.loadout
	return Rifles.byKey[lo and lo.rifle or "BOLT"] or Rifles.list[1]
end

local function rifleTool()
	local c = player.Character
	return c and c:FindFirstChild("Rifle")
end

-- Crosshair -------------------------------------------------------------------------------------------------------
local function crosshairStyle()
	local lo = Store.state.loadout
	return Cosmetics.crosshairById[lo and lo.crosshair or "DOT"] or Cosmetics.Crosshairs[1]
end

local function buildCrosshair()
	if crosshair then
		crosshair:Destroy()
	end
	local style = crosshairStyle()
	crosshair = new("Frame", {
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(60, 60),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	crosshair:SetAttribute("Style", style.id)
	local col = style.color
	new("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(style.shape == "dot" and 7 or 4, style.shape == "dot" and 7 or 4),
		BackgroundColor3 = col,
		BorderSizePixel = 0,
		Parent = crosshair,
	}, { Theme.corner("round"), Theme.stroke(1.5, C.ink) })
	-- four ticks that spread out when the shot is wild (hip fire, settling scope)
	for i, d in { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) } do
		local horizontal = d.Y == 0
		new("Frame", {
			Name = "Tick" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, d.X * 14, 0.5, d.Y * 14),
			Size = horizontal and UDim2.fromOffset(10, 3) or UDim2.fromOffset(3, 10),
			BackgroundColor3 = col,
			BorderSizePixel = 0,
			Visible = style.shape ~= "dot",
			Parent = crosshair,
		}, { Theme.stroke(1, C.ink) })
	end
	if style.shape == "ring" then
		new("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(26, 26),
			BackgroundTransparency = 1,
			Parent = crosshair,
		}, { Theme.corner("round"), Theme.stroke(2, col) })
	end
	-- the bolt ring under the crosshair
	boltRing = new("Frame", {
		Name = "Bolt",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 26),
		Size = UDim2.fromOffset(46, 6),
		BackgroundColor3 = C.slate,
		BorderSizePixel = 0,
		Visible = false,
		Parent = crosshair,
	}, { Theme.corner("round"), Theme.stroke(1.5, C.ink) })
	boltFill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.mustard,
		BorderSizePixel = 0,
		Parent = boltRing,
	}, { Theme.corner("round") })
end

local function spreadNow()
	if scoped then
		return os.clock() - scopedAt >= Constants.SCOPE_SETTLE and 0 or Constants.SCOPE_SPREAD
	end
	return Constants.HIP_SPREAD
end

-- Scope -------------------------------------------------------------------------------------------------------------
function RifleController.setScope(on)
	if on and not inFight() then
		on = false
	end
	if scoped == on then
		return
	end
	scoped = on
	scopedAt = os.clock()
	local cam = camera()
	if cam then
		Theme.tween(cam, 0.12, { FieldOfView = on and rifle().fov or Constants.HIP_FOV })
	end
	scopeOverlay.Visible = on
	if scopeButton then
		scopeButton.Text = on and "UNSCOPE" or "SCOPE"
	end
	if on and RifleController.playSound then
		RifleController.playSound("scope")
	end
end

function RifleController.isScoped()
	return scoped
end

-- Firing ------------------------------------------------------------------------------------------------------------
local function boltLeft()
	local r = rifle()
	local cd = Rifles.cooldown(r, clipShots)
	return math.max(0, cd - (os.clock() - lastFire)), cd
end

-- Light aim help: if the shot passes close to a visible target, bend it onto that target's body.
local function assist(origin, dir)
	local kind = Theme.inputKind()
	if not scoped or kind == "keyboard" then
		return dir
	end
	local best, bestAngle
	local function consider(rootPos)
		local aim = (rootPos + Vector3.new(0, 0.3, 0) - origin)
		if aim.Magnitude < 2 or aim.Magnitude > Constants.MAX_RANGE then
			return
		end
		local a = Formulas.angle(dir, aim.Unit)
		if a <= Constants.AIM_ASSIST_DEGREES and (not bestAngle or a < bestAngle) then
			best, bestAngle = aim.Unit, a
		end
	end
	for _, p in Players:GetPlayers() do
		local c = p ~= player and p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and p:GetAttribute("Zone") == player:GetAttribute("Zone") and not p:GetAttribute("Popped") then
			consider(r.Position)
		end
	end
	local robots = workspace:FindFirstChild("Robots")
	for _, m in robots and robots:GetChildren() or {} do
		local r = m:FindFirstChild("Root")
		if r and m:GetAttribute("Zone") == player:GetAttribute("Zone") then
			consider(r.Position + Vector3.new(0, 3, 0))
		end
	end
	return best or dir
end

local function muzzleWorld()
	if viewModel and viewModel.PrimaryPart then
		local m = viewModel.PrimaryPart:FindFirstChild("Muzzle")
		if m then
			return viewModel.PrimaryPart.CFrame * m.Position
		end
	end
	local cam = camera()
	return cam and cam.CFrame.Position or Vector3.zero
end

function RifleController.fire()
	if not inFight() then
		return false
	end
	local left = boltLeft()
	if left > 0 then
		return false
	end
	local cam = camera()
	if not cam or not cam.CFrame then
		return false
	end
	local r = rifle()
	local now = os.clock()
	clipShots = (clipShots < r.shots and now - lastFire < r.bolt) and clipShots + 1 or 1
	lastFire = now
	local origin = cam.CFrame.Position
	local dir = Formulas.spread(cam.CFrame.LookVector, spreadNow(), rng:NextNumber(), rng:NextNumber())
	dir = assist(origin, dir)
	Net.send("Fire", origin, dir, workspace:GetServerTimeNow())
	RifleController.fired += 1
	recoil = 1
	-- my own tracer straight away (the server's echo of my shot is skipped)
	if RifleController.onLocalShot then
		RifleController.onLocalShot(muzzleWorld(), origin + dir * 300, r.tracer)
	end
	if RifleController.playSound then
		RifleController.playSound("shot")
		task.delay(0.35, function()
			RifleController.playSound("bolt")
		end)
	end
	-- the bolt kicks you out of the scope, like a real bolt rifle (not between Twin's two shots)
	if scoped and clipShots >= r.shots then
		RifleController.setScope(false)
	end
	return true
end

-- View model --------------------------------------------------------------------------------------------------------
local function rebuildViewModel()
	local lo = Store.state.loadout
	local key = lo and lo.rifle or "BOLT"
	local skin = lo
		and lo.rifles
		and (function()
			for _, r in lo.rifles do
				if r.key == key then
					return r.skin, r.tier
				end
			end
			return nil
		end)()
	local tier = 0
	if lo and lo.rifles then
		for _, r in lo.rifles do
			if r.key == key then
				tier = r.tier
			end
		end
	end
	local id = key .. "|" .. tostring(skin) .. "|" .. tostring(tier)
	if viewModel and viewKey == id then
		return
	end
	if viewModel then
		viewModel:Destroy()
	end
	viewKey = id
	viewModel = RifleModel.build(key, skin, tier)
	viewModel.Name = "ViewModel"
	for _, p in viewModel:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	viewModel.Parent = camera()
end

local function updateViewModel(dt)
	local cam = camera()
	if not viewModel or not cam or not cam.CFrame then
		return
	end
	local show = inFight() and not scoped
	recoil = math.max(0, recoil - dt * 6)
	local sway = math.sin(os.clock() * 1.6) * 0.03
	local offset = CFrame.new(1.25, -1.3 + sway + recoil * 0.12, -3.0 + recoil * 0.4)
		* CFrame.Angles(recoil * 0.12, 0, 0)
	viewModel:PivotTo(show and (cam.CFrame * offset) or CFrame.new(0, -1000, 0))
	-- hide my third-person rifle from myself while I'm in first person
	local tool = rifleTool()
	if tool then
		for _, p in tool:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = inFight() and 1 or 0
			end
		end
	end
end

-- Buttons (phones) and input ----------------------------------------------------------------------------------------
local function buildButtons()
	fireButton = Theme.button({
		Name = "FireButton",
		Text = "FIRE",
		BackgroundColor3 = C.red,
		round = true,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(120, 120),
		Position = UDim2.new(1, -24, 1, -40),
		Visible = false,
		Parent = gui,
	})
	fireButton.MouseButton1Down:Connect(function()
		RifleController.fire()
	end)
	scopeButton = Theme.button({
		Name = "ScopeButton",
		Text = "SCOPE",
		BackgroundColor3 = C.sky,
		round = true,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(86, 86),
		Position = UDim2.new(1, -160, 1, -70),
		Visible = false,
		Parent = gui,
	})
	scopeButton.Activated:Connect(function()
		RifleController.setScope(not scoped)
	end)
	swapButton = Theme.button({
		Name = "SwapButton",
		Text = "🔁 SWAP",
		BackgroundColor3 = C.purple,
		AnchorPoint = Vector2.new(1, 1),
		Size = UDim2.fromOffset(96, 44),
		Position = UDim2.new(1, -24, 1, -172),
		Visible = false,
		Parent = gui,
	})
	swapButton.Activated:Connect(function()
		Net.send("SwapRifle")
	end)
	Theme.keyHint(swapButton, "Q", "Y")
end

local function bindInput()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			RifleController.fire()
		elseif t == Enum.UserInputType.MouseButton2 then
			RifleController.setScope(true)
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			RifleController.setScope(not scoped)
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY then
			Net.send("SwapRifle")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			RifleController.setScope(false)
		end
	end)
	_ = ContextActionService
end

-- Hit marker -------------------------------------------------------------------------------------------------------
local function showHit(headshot)
	hitMarker.Text = headshot and "🎯" or "✖"
	hitMarker.TextColor3 = headshot and C.mustard or C.white
	hitMarker.Visible = true
	Theme.pop(hitMarker)
	local mine = os.clock()
	hitMarker:SetAttribute("At", mine)
	task.delay(0.35, function()
		if hitMarker:GetAttribute("At") == mine then
			hitMarker.Visible = false
		end
	end)
end

-- Camera mode ---------------------------------------------------------------------------------------------------
local function applyCamera()
	local fight = inFight()
	if fight then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = Constants.CAMERA_MAX_ZOOM
		if scoped then
			RifleController.setScope(false)
		end
	end
	crosshair.Visible = fight
	local touch = Theme.inputKind() == "touch"
	fireButton.Visible = fight and touch
	scopeButton.Visible = fight and touch
	local passes = Store.state.passes or {}
	local lo = Store.state.loadout
	swapButton.Visible = fight and passes.LOADOUT == true and lo ~= nil and lo.rifle2 ~= nil
end

function RifleController:init()
	gui = Theme.screen("Rifle", 5, player:WaitForChild("PlayerGui"))
	scopeOverlay = new("Frame", {
		Name = "Scope",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 0,
		Parent = gui,
	})
	-- the scope: dark edges around a round window
	for _, spec in
		{
			{ UDim2.new(0.5, -250, 1, 0), UDim2.fromScale(0, 0) },
			{ UDim2.new(0.5, -250, 1, 0), UDim2.new(0.5, 250, 0, 0) },
		}
	do
		new("Frame", {
			Name = "Edge",
			Size = spec[1],
			Position = spec[2],
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Parent = scopeOverlay,
		})
	end
	new("Frame", {
		Name = "Lens",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(500, 500),
		BackgroundTransparency = 1,
		Parent = scopeOverlay,
	}, { Theme.corner("round"), Theme.stroke(40, Color3.fromRGB(0, 0, 0)) })
	for _, s in { UDim2.fromOffset(500, 2), UDim2.fromOffset(2, 500) } do
		new("Frame", {
			Name = "Hair",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = s,
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Parent = scopeOverlay,
		})
	end
	hitMarker = Theme.title({
		Name = "HitMarker",
		Text = "✖",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	buildCrosshair()
	buildButtons()
	bindInput()
	Net.listen("Hit", function(headshot)
		showHit(headshot)
	end)
	Store.Changed:Connect(function(partial)
		if partial.loadout then
			if crosshair:GetAttribute("Style") ~= crosshairStyle().id then
				buildCrosshair()
			end
			rebuildViewModel()
		end
		applyCamera()
	end)
	player:GetAttributeChangedSignal("Zone"):Connect(applyCamera)
	player:GetAttributeChangedSignal("Popped"):Connect(applyCamera)
	RunService.RenderStepped:Connect(function(dt)
		updateViewModel(dt)
		if crosshair.Visible then
			local s = spreadNow()
			local gap = 8 + s * 4
			for i, d in { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) } do
				local tick = crosshair:FindFirstChild("Tick" .. i)
				if tick then
					tick.Position = UDim2.new(0.5, d.X * gap, 0.5, d.Y * gap)
				end
			end
			local left, cd = boltLeft()
			boltRing.Visible = left > 0
			boltFill.Size = UDim2.fromScale(cd > 0 and 1 - left / cd or 1, 1)
		end
	end)
	rebuildViewModel()
	applyCamera()
end

return RifleController
