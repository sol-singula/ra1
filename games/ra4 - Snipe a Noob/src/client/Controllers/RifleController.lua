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
local recoil = 0 -- 1 right after a shot, springs back to 0
local camKick = 0 -- degrees the view is kicked up by recoil (springs back)
local vmOffset = CFrame.new(0, -2, -1) -- the view model's smoothed place in front of the camera
local lastLook -- last frame's camera look, for sway
local swayX, swayY = 0, 0
local bobT = 0
local equipT = 0 -- 0 when the rifle comes up, 1 when it's ready
local vmParts = {} -- the bolt and mag parts and their places on the rifle, for the bolt and reload moves

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
		Size = UDim2.fromOffset(70, 70),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	crosshair:SetAttribute("Style", style.id)
	local col = style.color
	local plus = style.shape == "plus"
	local dotSize = style.shape == "dot" and 6 or 4
	new("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(dotSize, dotSize),
		BackgroundColor3 = col,
		BorderSizePixel = 0,
		Parent = crosshair,
	}, { Theme.corner("round"), Theme.stroke(1.5, C.ink) })
	-- four lines around the dot (every style): they spread out when the shot is wild (hip fire, settling scope)
	local long, thick = plus and 16 or 11, plus and 4 or 3
	for i, d in { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) } do
		local horizontal = d.Y == 0
		new("Frame", {
			Name = "Tick" .. i,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, d.X * 14, 0.5, d.Y * 14),
			Size = horizontal and UDim2.fromOffset(long, thick) or UDim2.fromOffset(thick, long),
			BackgroundColor3 = col,
			BorderSizePixel = 0,
			Parent = crosshair,
		}, { Theme.stroke(1.5, C.ink) })
	end
	if style.shape == "ring" then
		new("Frame", {
			Name = "Ring",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(30, 30),
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
	RifleController.applySensitivity()
	if scopeButton then
		scopeButton.Text = on and "UNSCOPE" or "SCOPE"
	end
	if on and RifleController.playSound then
		RifleController.playSound("scope")
	end
end

-- Mouse speed: a bit slower in first person, and slower again while scoped (more zoom = slower).
function RifleController.applySensitivity()
	local speed = 1
	if inFight() then
		speed = Constants.MOUSE_SENSITIVITY
		if scoped then
			speed *= Constants.SCOPE_SENSITIVITY * (rifle().fov / Constants.HIP_FOV) / 0.6
		end
	end
	pcall(function()
		UserInputService.MouseDeltaSensitivity = math.clamp(speed, 0.1, 1)
	end)
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
	local maxAngle = kind == "keyboard" and Constants.AIM_ASSIST_MOUSE or Constants.AIM_ASSIST_DEGREES
	if not scoped then
		maxAngle *= Constants.AIM_ASSIST_HIP
	end
	local best, bestAngle
	local function consider(rootPos)
		local aim = (rootPos + Vector3.new(0, 0.3, 0) - origin)
		if aim.Magnitude < 2 or aim.Magnitude > Constants.MAX_RANGE then
			return
		end
		local a = Formulas.angle(dir, aim.Unit)
		if a <= maxAngle and (not bestAngle or a < bestAngle) then
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
	camKick += scoped and 1.4 or 2.6
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
local function armColor()
	local c = player.Character
	local arm = c and (c:FindFirstChild("RightLowerArm") or c:FindFirstChild("Right Arm"))
	return arm and arm.Color or Color3.fromRGB(255, 205, 60)
end

local function sleeveColor()
	local c = player.Character
	local arm = c and (c:FindFirstChild("RightUpperArm") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso"))
	return arm and arm.Color or Color3.fromRGB(40, 120, 220)
end

-- Two blocky arms holding the rifle: the right hand on the grip, the left hand under the handguard.
local function addArms(model)
	local handle = model.PrimaryPart
	local function arm(name, size, cf, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = handle.CFrame * cf
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = model
		return p
	end
	local skin, sleeve = armColor(), sleeveColor()
	-- right: hand on the grip, forearm going back and down toward the camera
	arm("RightHand", Vector3.new(0.5, 0.5, 0.55), CFrame.new(0, -0.05, 0.05), skin)
	arm(
		"RightArm",
		Vector3.new(0.55, 0.55, 1.8),
		CFrame.new(0.15, -0.35, 1.05) * CFrame.Angles(math.rad(18), 0, 0),
		skin
	)
	arm(
		"RightSleeve",
		Vector3.new(0.62, 0.62, 1.2),
		CFrame.new(0.25, -0.75, 2.3) * CFrame.Angles(math.rad(18), 0, 0),
		sleeve
	)
	-- left: hand under the handguard, arm reaching back to the left
	local hg = model:FindFirstChild("Handguard")
	local hgCF = hg and handle.CFrame:ToObjectSpace(hg.CFrame) or CFrame.new(0, 0.4, -2)
	arm("LeftHand", Vector3.new(0.5, 0.45, 0.6), hgCF * CFrame.new(0, -0.4, 0.2), skin)
	arm(
		"LeftArm",
		Vector3.new(0.55, 0.55, 2.2),
		hgCF * CFrame.new(-0.55, -0.75, 1.2) * CFrame.Angles(math.rad(12), math.rad(-25), 0),
		skin
	)
	arm(
		"LeftSleeve",
		Vector3.new(0.62, 0.62, 1.4),
		hgCF * CFrame.new(-1.15, -1.05, 2.6) * CFrame.Angles(math.rad(12), math.rad(-25), 0),
		sleeve
	)
end

local function rebuildViewModel()
	local lo = Store.state.loadout
	local key = lo and lo.rifle or "BOLT"
	local skin, tier = nil, 0
	if lo and lo.rifles then
		for _, r in lo.rifles do
			if r.key == key then
				skin, tier = r.skin, r.tier
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
	addArms(viewModel)
	table.clear(vmParts)
	local handle = viewModel.PrimaryPart
	for _, p in viewModel:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
			if p.Name == "BoltKnob" or p.Name == "BoltStem" or p.Name == "Mag" or p.Name == "RightHand" then
				vmParts[p] = handle.CFrame:ToObjectSpace(p.CFrame)
			end
		end
	end
	viewModel.Parent = camera()
	equipT = 0
end

local function ease(t)
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 to 1 inside a window of t, as a smooth bump (up then down)
local function bump(t, a, b)
	if t <= a or t >= b then
		return 0
	end
	return math.sin((t - a) / (b - a) * math.pi)
end

local function updateViewModel(dt)
	local cam = camera()
	if not viewModel or not cam or not cam.CFrame then
		return
	end
	local fight = inFight()
	local show = fight and not scoped
	-- springs: recoil and the camera kick ease back
	recoil = math.max(0, recoil - dt * 5)
	camKick = camKick * math.exp(-dt * 9)
	equipT = math.min(1, equipT + dt / 0.35)
	-- sway: the rifle lags a little behind where you turn
	local look = cam.CFrame.LookVector
	if lastLook then
		local right = cam.CFrame.RightVector
		local d = look - lastLook
		swayX = math.clamp(swayX - d:Dot(right) * 2.5, -0.35, 0.35)
		swayY = math.clamp(swayY - d.Y * 2.5, -0.25, 0.25)
	end
	lastLook = look
	swayX *= math.exp(-dt * 8)
	swayY *= math.exp(-dt * 8)
	-- walking bob
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local md = hum and hum.MoveDirection
	local moving = md ~= nil and md.Magnitude > 0.1
	bobT += dt * (moving and 9 or 1.6)
	local bobAmt = moving and 0.07 or 0.02
	local bob = CFrame.new(math.cos(bobT) * bobAmt, math.abs(math.sin(bobT)) * bobAmt, 0)
	-- the bolt (or Twin's reload) after a shot
	local left, cd = boltLeft()
	local r = rifle()
	local t = cd > 0 and left > 0 and (1 - left / cd) or 1
	local reloading = left > 0 and r.shots > 1 and clipShots >= r.shots
	local work = left > 0 and r.shots == 1
	local roll, lift, dip, pull, magDrop = 0, 0, 0, 0, 0
	if work then
		roll = bump(t, 0.12, 0.9) * 0.45 -- tip the rifle to work the bolt
		lift = bump(t, 0.12, 0.9) * 0.15
		pull = bump(t, 0.3, 0.8) * 0.55 -- bolt back, then forward
	elseif reloading then
		dip = bump(t, 0.05, 0.95) * 0.7 -- rifle down
		roll = bump(t, 0.05, 0.95) * 0.3
		magDrop = bump(t, 0.2, 0.75) * 1.4 -- old mag out, new mag in
	end
	local base = CFrame.new(1.25, -1.3, -3.0)
	local target = base
		* bob
		* CFrame.new(swayX, swayY + lift - dip - (1 - ease(equipT)) * 1.5, recoil * 0.45)
		* CFrame.Angles(recoil * 0.18 - dip * 0.35, swayX * 0.4, roll)
	-- smoothing: ease toward the target every frame
	vmOffset = vmOffset:Lerp(target, 1 - math.exp(-dt * 20))
	-- place the rifle's own frame (not its tilted grip), turned a touch inward so the barrel meets the crosshair
	local aimIn = CFrame.Angles(math.rad(0.6), math.rad(1.6), 0)
	local where = show and (cam.CFrame * vmOffset * aimIn * RifleModel.HANDLE_OFFSET) or CFrame.new(0, -1000, 0)
	viewModel:PivotTo(where)
	-- move the bolt and the mag on top of the pivot
	local handle = viewModel.PrimaryPart
	for p, rel in vmParts do
		if p.Parent then
			if p.Name == "BoltKnob" or p.Name == "BoltStem" or p.Name == "RightHand" then
				p.CFrame = handle.CFrame * CFrame.new(0, 0, pull) * rel
			elseif p.Name == "Mag" then
				p.CFrame = handle.CFrame * CFrame.new(0, -magDrop, 0) * rel
				p.Transparency = magDrop > 1.1 and 1 or 0
			end
		end
	end
	-- hide my third-person rifle from myself while I'm in first person
	local tool = rifleTool()
	if tool then
		for _, p in tool:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = fight and 1 or 0
			end
		end
	end
end

-- The camera kick from recoil: added after Roblox's camera each frame, so it springs back to where you aimed.
local function kickCamera()
	local cam = camera()
	if cam and camKick > 0.01 and inFight() then
		cam.CFrame = cam.CFrame * CFrame.Angles(math.rad(camKick), 0, 0)
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

-- Mouse and gamepad go through ContextActionService at a high priority, so the left and right mouse buttons always
-- reach the rifle in a fight zone (nothing else can eat the click), and pass through untouched everywhere else.
local function bindInput()
	local PRIORITY = Enum.ContextActionPriority.High.Value + 10
	ContextActionService:BindActionAtPriority("RifleFire", function(_, state)
		if not inFight() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			RifleController.fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindActionAtPriority("RifleScope", function(_, state, input)
		if not inFight() then
			if scoped then
				RifleController.setScope(false)
			end
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.ButtonL2 then
			if state == Enum.UserInputState.Begin then
				RifleController.setScope(not scoped)
			end
		elseif state == Enum.UserInputState.Begin then
			RifleController.setScope(true) -- hold right mouse to scope
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			RifleController.setScope(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, PRIORITY, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.ButtonY then
			Net.send("SwapRifle")
		end
	end)
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
		if RifleController._wasFight then
			-- pull the camera back out of first person (Classic alone keeps you zoomed in with the mouse locked)
			player.CameraMinZoomDistance = 12
			task.delay(0.1, function()
				player.CameraMinZoomDistance = 0.5
			end)
		end
		if scoped then
			RifleController.setScope(false)
		end
	end
	crosshair.Visible = fight
	RifleController.applySensitivity()
	if fight and not RifleController._wasFight then
		equipT = 0 -- bring the rifle up
	end
	RifleController._wasFight = fight
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
	pcall(function()
		RunService:BindToRenderStep("RifleKick", Enum.RenderPriority.Camera.Value + 1, kickCamera)
	end)
	RunService.RenderStepped:Connect(function(dt)
		updateViewModel(dt)
		if crosshair.Visible then
			local s = spreadNow()
			local gap = 10 + s * 4 + recoil * 10 -- the lines jump out when you fire
			for i, d in { Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) } do
				local tick = crosshair:FindFirstChild("Tick" .. i)
				if tick then
					tick.Position = UDim2.new(0.5, d.X * gap, 0.5, d.Y * gap)
					tick.Visible = not scoped -- the scope has its own lines
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
