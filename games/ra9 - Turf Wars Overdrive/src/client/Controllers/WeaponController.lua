--[[
Your bow (master plan §5, §6): the viewmodel in your hands, the draw and the shot.

  * Hold the mouse (or the touch FIRE button, or the gamepad's right trigger) to draw; let go to shoot. The bow's
    string comes back as the charge builds, the view tightens a little, and a ring round the crosshair fills
    (Bus.Charge). The crossbow fires on each press, six bolts, then R (or the RELOAD button) to reload.
  * Let go and the arrow is drawn at once (ArrowController.predict) while the shot goes to the server (Shoot:
    from your eye, the way you're looking). The server times the draw itself, so a held mouse can't cheat a charge.
  * 1 / 2 / 3 pick the Standard Bow, the Rapid Crossbow, the Heavy Bow (in the fight; in the build phase the
    digits pick structures), and the mouse wheel steps through them. Only in the fight, alive.
  * No drawing or shooting while a menu is open (the shop, a card, the results): the mouse is the menu's then.

The viewmodel (this client only): your arms in the team's sleeves holding the bow, its limbs, a string in two halves
that bends to your hand, and the arrow. It moves on springs: up from below when you equip, a walking bob and
breathing, lagging a little behind your view as you look round, dropped and turned across you as you sprint,
tilted in a slide, steadier crouched, toward the middle as you draw (the limbs bend, the string comes back, and at
full draw it shakes with the tension, more for the Heavy Bow), a snap and a kick on release with the string
overshooting, the next arrow sliding in, a dip when you land; the crossbow lies flat, kicks per bolt and tips down
to reload.
]]
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Bus = require(script.Parent.Parent.UI.Bus)
local Device = require(script.Parent.Parent.UI.Device)
local Store = require(script.Parent.Parent.Store)
local ArrowController = require(script.Parent.ArrowController)
local CameraController = require(script.Parent.CameraController)

local WeaponController = { Name = "WeaponController", Order = 30 }

local drawing = false
local drawStart = 0
local shotId = 0
local lastShot = 0
local view -- the viewmodel's parts (buildView)
-- the viewmodel is modelled at a comfortable size and drawn at this scale (its offsets scale with it): a bow a
-- little under half the view's height at full draw
local VM_SCALE = 0.55
local viewKey
-- the motion's state: springs { p, v } and timers (equipAt, shotAt, reloadAt), and the movement it reads
local anim = {
	swayX = { p = 0, v = 0 },
	swayY = { p = 0, v = 0 },
	run = { p = 0, v = 0 },
	tilt = { p = 0, v = 0 },
	crouchK = { p = 0, v = 0 },
	aim = { p = 0, v = 0 },
	kick = { p = 0, v = 0 },
	pull = { p = 0, v = 0 },
	land = { p = 0, v = 0 },
}

local function weapon()
	local me = Store.get("me")
	return Weapons.get(me and me.weapon or Weapons.DEFAULT) or Weapons.get(Weapons.DEFAULT)
end

-- Aim help on a touch screen only (a thumb can't aim like a mouse): a shot let go within ASSIST_DEGREES of an
-- enemy's body bends that way by ASSIST_PULL of the gap. Small, only close to the line, never through walls (the
-- server flies the arrow as always).
local ASSIST_DEGREES, ASSIST_RANGE, ASSIST_PULL = 4, 140, 0.6
function WeaponController.assist(origin, dir)
	if not Device.isTouch() then
		return dir
	end
	local Players = game:GetService("Players")
	local me = Players.LocalPlayer
	local myTeam = me:GetAttribute("Team")
	local best, bestAngle
	local bodies = {}
	for _, p in Players:GetPlayers() do
		if p ~= me and p:GetAttribute("Team") ~= myTeam then
			table.insert(bodies, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots") -- (the stand-ins when you play alone: BotService)
	for _, c in bots and bots:GetChildren() or {} do
		if c:GetAttribute("Team") ~= myTeam then
			table.insert(bodies, c)
		end
	end
	for _, c in bodies do
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if root then
			local to = root.Position + Vector3.new(0, 0.6, 0) - origin
			local dist = to.Magnitude
			if dist > 1 and dist <= ASSIST_RANGE then
				local angle = math.deg(math.acos(math.clamp(to.Unit:Dot(dir), -1, 1)))
				if angle <= ASSIST_DEGREES and (not bestAngle or angle < bestAngle) then
					best, bestAngle = to.Unit, angle
				end
			end
		end
	end
	if not best then
		return dir
	end
	return dir:Lerp(best, ASSIST_PULL).Unit
end

local function canShoot()
	local me = Store.get("me")
	return Store.phase() == "fight" and me and me.alive == true and not CameraController.mouseFree()
end

function WeaponController.drawing()
	return drawing
end

function WeaponController.charge()
	if not drawing then
		return nil
	end
	return Formulas.charge(weapon(), os.clock() - drawStart)
end

-- The viewmodel ----------------------------------------------------------------------------------------------------
local function buildView()
	if view then
		view.model:Destroy()
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local team = Store.team() or "red"
	local color = Constants.TEAM_COLOR[team]
	local model = Instance.new("Model")
	model.Name = "Viewmodel"
	local function piece(size, c, name, material)
		local p = Instance.new("Part")
		p.Name = name or "Piece"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size * VM_SCALE
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local w = weapon()
	local big = w.key == "heavy"
	local cross = w.key == "crossbow"
	-- the bow's finish (Data/Cosmetics skins): the grip and limbs' colours and material
	local skinKey = ((Store.get("profile") or {}).equipped or {}).skin
	local skin = Cosmetics.get(skinKey)
	local look = skin and skin.kind == "skin" and skin.look or nil
	local gripColor = look and Cosmetics.color(look.grip, team) or color
	local limbColor = look and Cosmetics.color(look.limbs, team) or Constants.WHITE
	local material
	if look then
		local ok, m = pcall(function()
			return Enum.Material[look.material]
		end)
		material = ok and m or nil
	end
	local limbLen = cross and 1.0 or (big and 1.9 or 1.5)
	local ink = Color3.fromRGB(30, 30, 34)
	local v = { model = model, big = big, cross = cross, limbLen = limbLen }
	v.grip = piece(Vector3.new(0.22, 0.6, 0.24), gripColor, "Grip", material)
	v.upper = piece(Vector3.new(0.24, limbLen, 0.13), limbColor, "Upper", material)
	v.lower = piece(Vector3.new(0.24, limbLen, 0.13), limbColor, "Lower", material)
	v.tipU = piece(Vector3.new(0.2, 0.18, 0.2), gripColor, "TipU", material)
	v.tipL = piece(Vector3.new(0.2, 0.18, 0.2), gripColor, "TipL", material)
	-- the string in two halves: straight at rest, a V to your hand as you draw
	v.strU = piece(Vector3.new(0.03, 1, 0.03), ink, "String")
	v.strL = piece(Vector3.new(0.03, 1, 0.03), ink, "StringL")
	if cross then
		v.stock = piece(Vector3.new(0.22, 0.22, 1.7), limbColor, "Stock", material)
		v.trigger = piece(Vector3.new(0.08, 0.22, 0.1), ink, "Trigger")
	end
	-- the arrow: a white shaft, a team-coloured head and fletching
	v.shaft = piece(Vector3.new(0.07, 0.07, cross and 1.2 or 1.9), Constants.WHITE, "Nocked")
	v.head = piece(Vector3.new(0.13, 0.13, 0.22), color, "Head", Enum.Material.Neon)
	v.fletch = piece(Vector3.new(0.02, 0.18, 0.32), color, "Fletch")
	-- your arms: the team's sleeves, white hands
	v.armL = piece(Vector3.new(0.22, 0.22, 1), color, "ArmL")
	v.handL = piece(Vector3.new(0.3, 0.34, 0.3), Constants.WHITE, "HandL")
	v.armR = piece(Vector3.new(0.22, 0.22, 1), color, "ArmR")
	v.handR = piece(Vector3.new(0.24, 0.26, 0.26), Constants.WHITE, "HandR")
	model.Parent = cam
	view = v
	anim.equipAt = os.clock()
end

-- The springs and timers behind the motion ---------------------------------------------------------------------
local function spring(s, target, dt, k, d)
	s.v += (target - s.p) * k * dt - s.v * d * dt
	s.p += s.v * dt
	return s.p
end

local function ease(f)
	f = math.clamp(f, 0, 1)
	local c = 1.7
	return 1 + (c + 1) * (f - 1) ^ 3 + c * (f - 1) ^ 2 -- (ease out with a little overshoot)
end

function WeaponController.anim()
	return anim
end

-- an offset in the viewmodel's own units
local function L(x, y, z)
	return CFrame.new(x * VM_SCALE, y * VM_SCALE, z * VM_SCALE)
end

local function placeView(dt)
	local cam = workspace.CurrentCamera
	if not view or not cam or not view.model.Parent then
		return
	end
	local me = Store.get("me")
	local show = me and me.alive and Store.phase() ~= "build" and Store.phase() ~= "loading"
	for _, p in view.model:GetChildren() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = show and 0 or 1
			p.Transparency = show and 0 or 1
		end
	end
	if not show then
		anim.lastCam = cam.CFrame
		return
	end
	dt = math.clamp(dt or 1 / 60, 1 / 240, 1 / 15)
	local t = os.clock()
	local w = weapon()
	local c = WeaponController.charge() or 0
	local Players = game:GetService("Players")
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local vel = root and root.AssemblyLinearVelocity or Vector3.zero
	local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local crouched = anim.crouch and anim.crouch() or false
	local sprinting = anim.sprint and anim.sprint() or false
	local sliding = anim.sliding and anim.sliding() or false
	local steady = crouched and 0.5 or 1 -- (crouched: the bow sits steadier)

	-- equip: up from below with a little overshoot
	local e = ease((t - (anim.equipAt or 0)) / 0.38)
	local equipOff = CFrame.new(0, -1.1 * (1 - e), 0.3 * (1 - e)) * CFrame.Angles(math.rad(-50 * (1 - e)), 0, 0)
	-- walking bob and breathing
	local k = math.clamp(speed / Constants.WALK_SPEED, 0, 1.5) * (drawing and 0.35 or 1) * steady
	if hum and hum.FloorMaterial == Enum.Material.Air then
		k = 0
	end
	anim.bobPhase = (anim.bobPhase or 0) + dt * (6 + speed * 0.32)
	local bob = Vector3.new(math.sin(anim.bobPhase) * 0.045 * k, math.abs(math.cos(anim.bobPhase)) * 0.055 * k, 0)
	local breathe = math.sin(t * 1.6) * 0.012 * steady
	-- looking around: the bow lags behind the view and catches up
	local last = anim.lastCam or cam.CFrame
	local delta = last:ToObjectSpace(cam.CFrame)
	local dx, dy = delta:ToEulerAnglesYXZ()
	anim.lastCam = cam.CFrame
	local swayX = spring(anim.swayX, math.clamp(-dy * 2.2, -0.25, 0.25) * steady, dt, 140, 14)
	local swayY = spring(anim.swayY, math.clamp(dx * 2.2, -0.25, 0.25) * steady, dt, 140, 14)
	-- sprinting: the bow drops and turns across you; sliding: a tilt
	local run = spring(anim.run, (sprinting and speed > 8 and not drawing) and 1 or 0, dt, 90, 16)
	local tilt = spring(anim.tilt, sliding and 1 or 0, dt, 120, 14)
	local crouchK = spring(anim.crouchK, crouched and 1 or 0, dt, 110, 16)
	-- the draw: toward the middle, more upright, the limbs bend, the string comes back to your hand; held at full
	-- it starts to shake with the tension
	local aim = spring(anim.aim, drawing and 1 or 0, dt, 160, 18)
	local held = drawing and math.max(0, t - drawStart - w.draw) or 0
	local tremble = held > 0 and math.min(1, held / 2) * (view.big and 0.018 or 0.01) * steady or 0
	local shake = Vector3.new(math.sin(t * 47) * tremble, math.cos(t * 53) * tremble, 0)
	-- the shot: a snap forward, a kick up; the string overshoots past rest and settles
	local kickP = spring(anim.kick, 0, dt, 220, 16)
	local pullS = spring(anim.pull, drawing and c or 0, dt, drawing and 400 or 900, drawing and 40 or 22)
	local landP = spring(anim.land, 0, dt, 160, 14)
	-- the crossbow's reload: tipped down, the bolt pushed in, cocked
	local reloadK = 0
	if anim.reloadAt and w.reload then
		local f = (t - anim.reloadAt) / w.reload
		if f >= 1 then
			anim.reloadAt = nil
		else
			reloadK = math.sin(math.min(1, f) * math.pi)
		end
	end
	local cross = view.cross
	-- where the bow sits in front of you (camera space, studs): low on the right at rest; drawn, up just left of
	-- the crosshair and nearly upright, the arrow along your aim. The crossbow is held level, a little right.
	local restP = cross and Vector3.new(0.42, -0.5, -1.55) or Vector3.new(0.55, -0.55, -1.8)
	local aimP = Vector3.new(-0.1, -0.08, -1.8)
	local pos = restP:Lerp(aimP, aim)
		+ Vector3.new(
			swayX * 0.35 - run * 0.1,
			breathe - swayY * 0.35 - run * 0.2 - crouchK * 0.05 - landP,
			kickP * 0.25
		)
	local base = cam.CFrame
		* CFrame.new(bob + shake)
		* CFrame.new(pos)
		* equipOff
		* CFrame.Angles(
			math.rad(kickP * 9 - run * 25 - reloadK * 35 + swayY * 20),
			math.rad((cross and -4 or -12) + aim * 14 + run * 30 + swayX * 25),
			math.rad((cross and -6 or -35) + aim * 25 - tilt * 16 - reloadK * 20 + swayX * 15)
		)
	local half = view.limbLen / 2 -- (model units; L scales them)
	local bend = 0.15 + pullS * 0.3
	local function at(cf, part)
		part.CFrame = cf
		return cf
	end
	-- an arm: a sleeve from the hand out to a shoulder past the edge of the screen (camera space)
	local function arm(part, from, shoulder)
		local to = cam.CFrame * shoulder
		part.Size = Vector3.new(part.Size.X, part.Size.Y, math.max(0.1, (to - from).Magnitude))
		part.CFrame = CFrame.lookAt((from + to) / 2, to)
	end
	-- (the shoulders are just off the screen's edges, in front of you: the sleeves come in from the corners)
	local shoulderR = Vector3.new(0.95, -1.0, -0.55)
	if cross then
		-- the crossbow lies flat: the stock along your view, the limbs across, the string drawn back to the latch
		at(base * L(0, -0.1, 0.35), view.stock)
		at(base * L(0, -0.3, 0.6), view.trigger)
		at(base * L(0, -0.15, 1.05), view.grip)
		local ends = {}
		for i, sgn in { 1, -1 } do
			local limb = i == 1 and view.upper or view.lower
			local cf = base
				* L(sgn * (half + 0.05), 0, -0.25)
				* CFrame.Angles(0, math.rad(sgn * (8 + pullS * 6)), math.rad(90))
			at(cf, limb)
			ends[i] = (base * L(sgn * (half * 2 + 0.05), 0, -0.25 + bend * 0.6)).Position
			at(CFrame.new(ends[i]) * (base - base.Position), i == 1 and view.tipU or view.tipL)
		end
		local latch = (base * L(0, 0.05, -0.1 + (1 - reloadK) * 0.4)).Position
		for i, part in { view.strU, view.strL } do
			local a, b = ends[i], latch
			part.Size = Vector3.new(0.03 * VM_SCALE, 0.03 * VM_SCALE, (b - a).Magnitude)
			part.CFrame = CFrame.lookAt((a + b) / 2, b)
		end
		local loaded = (me.ammo or 0) > 0 and reloadK < 0.6
		local boltCf = base * L(0, 0.12, -0.35 + reloadK * 0.6)
		at(boltCf, view.shaft)
		at(boltCf * L(0, 0, -0.65), view.head)
		at(boltCf * L(0, 0, 0.5), view.fletch)
		for _, q in { view.shaft, view.head, view.fletch } do
			q.Transparency = loaded and 0 or 1
		end
		-- hands: the left under the front, the right on the grip
		local hl = at(base * L(0, -0.32, -0.2), view.handL)
		local hr = at(base * L(0, -0.3, 1.2), view.handR)
		arm(view.armL, hl.Position, Vector3.new(-0.5, -1.1, -0.6))
		arm(view.armR, hr.Position, shoulderR)
		return
	end
	-- a bow: held upright in the left hand, the limbs bending back as you draw
	at(base, view.grip)
	at(base * L(0, half + 0.25, bend * 0.5) * CFrame.Angles(math.rad(-18 - pullS * 16), 0, 0), view.upper)
	at(base * L(0, -half - 0.25, bend * 0.5) * CFrame.Angles(math.rad(18 + pullS * 16), 0, 0), view.lower)
	local tipU = (base * L(0, half * 2 + 0.2, bend + pullS * 0.25)).Position
	local tipL = (base * L(0, -half * 2 - 0.2, bend + pullS * 0.25)).Position
	at(CFrame.new(tipU) * (base - base.Position), view.tipU)
	at(CFrame.new(tipL) * (base - base.Position), view.tipL)
	-- the string: from each tip to the nock point; the nock point comes back with the draw (and overshoots forward
	-- on release, the spring)
	local nockZ = bend + 0.15 + pullS * 1.15
	local nock = (base * L(0, 0, nockZ)).Position
	for i, part in { view.strU, view.strL } do
		local a = i == 1 and tipU or tipL
		part.Size = Vector3.new(0.03 * VM_SCALE, 0.03 * VM_SCALE, math.max(0.05, (nock - a).Magnitude))
		part.CFrame = CFrame.lookAt((a + nock) / 2, nock)
	end
	-- the arrow: on the string while drawing, back in place a moment after a shot
	local renock = math.clamp((t - (anim.shotAt or -10)) / math.max(0.15, w.cooldown), 0, 1)
	local visible = drawing or renock >= 1
	local slideIn = drawing and 0 or (1 - ease(renock)) * 0.6
	local arrowLen = view.shaft.Size.Z / VM_SCALE
	local arrowCf = base * L(0.07, -0.02 - slideIn, nockZ - arrowLen / 2)
	at(arrowCf, view.shaft)
	at(arrowCf * L(0, 0, -arrowLen / 2 - 0.1), view.head)
	at(arrowCf * L(0, 0, arrowLen / 2 - 0.2), view.fletch)
	for _, q in { view.shaft, view.head, view.fletch } do
		q.Transparency = visible and 0 or 1
	end
	-- hands: the left round the grip, the right pinching the string at the nock (a little under it, so the
	-- crosshair stays clear), each arm out past the screen's edge
	local hl = at(base * L(0.02, 0, 0.02), view.handL)
	local hr = at(CFrame.new(nock) * (base - base.Position) * L(0.05, -0.16, 0.08), view.handR)
	arm(view.armL, hl.Position, Vector3.new(0.3, -1.15, -0.7):Lerp(Vector3.new(-0.95, -1.0, -0.7), aim))
	arm(view.armR, hr.Position, shoulderR)
end

-- Draw and shoot ---------------------------------------------------------------------------------------------------
function WeaponController.startDraw()
	if not canShoot() or drawing then
		return false
	end
	local w = weapon()
	if w.key == "crossbow" then
		WeaponController.release(true)
		return true
	end
	if os.clock() - lastShot < w.cooldown then
		return false
	end
	drawing = true
	drawStart = os.clock()
	Net.send("Draw", true)
	return true
end

function WeaponController.release(instant)
	local w = weapon()
	if not instant and not drawing then
		return false
	end
	if not canShoot() then
		drawing = false
		Bus.Charge:Fire(nil)
		return false
	end
	local me = Store.get("me")
	if w.mag and (me.ammo or 0) <= 0 then
		drawing = false
		return false
	end
	if instant and os.clock() - lastShot < w.cooldown then
		return false
	end
	local charge = instant and 1 or Formulas.charge(w, os.clock() - drawStart)
	drawing = false
	Bus.Charge:Fire(nil)
	local cam = workspace.CurrentCamera
	local origin = cam and cam.CFrame.Position or Vector3.zero
	local dir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	dir = WeaponController.assist(origin, dir)
	shotId += 1
	lastShot = os.clock()
	local shot = Formulas.shot(w, charge)
	-- (start it a stud ahead, so it never begins inside your own head)
	local start = origin + dir * 1
	ArrowController.predict(start, dir * shot.speed, Store.team() or "red", shotId)
	Net.send("Shoot", start, dir, shotId)
	if w.mag then
		Store.merge("me", { ammo = math.max(0, (me.ammo or 0) - 1) })
	end
	anim.kick.v += 6 + charge * 6 -- (the snap: a push into the kick spring)
	anim.pull.p = charge -- (the string springs forward from where it was)
	anim.shotAt = os.clock()
	if w.mag and (me.ammo or 0) <= 1 then
		anim.reloadAt = os.clock() + w.cooldown -- (the last bolt: straight into the reload)
	end
	CameraController.shake(0.08 + charge * 0.12, 0.12)
	Bus.Fired:Fire(w.key, charge)
	return true
end

function WeaponController.equip(key)
	if not Weapons.get(key) or Store.phase() == "build" then
		return false
	end
	drawing = false
	Store.merge("me", { weapon = key, ammo = Weapons.get(key).mag })
	Net.send("Equip", key)
	buildView()
	return true
end

-- The mouse wheel: the next (step 1) or the one before (step -1) bow, round the end
function WeaponController.cycle(step)
	local n = #Weapons.list
	local at = weapon().order or 1
	return WeaponController.equip(Weapons.list[(at - 1 + step) % n + 1].key)
end

function WeaponController.reload()
	local w = weapon()
	if w.mag then
		Net.send("Reload")
		anim.reloadAt = anim.reloadAt or os.clock()
		Bus.Tap:Fire("reload")
	end
end

-- What the motion reads from the legs (MoveController hands these over, so neither requires the other)
function WeaponController.bindMovement(sprint, crouch, sliding)
	anim.sprint, anim.crouch, anim.sliding = sprint, crouch, sliding
end

-- A landing: the bow dips and comes back
function WeaponController.landed(hard)
	anim.land.v -= hard and 2.2 or 1.2
end

function WeaponController:init()
	buildView()
	ContextActionService:BindAction("TW_Fire", function(_, state)
		if state == Enum.UserInputState.Begin then
			WeaponController.startDraw()
		elseif state == Enum.UserInputState.End then
			WeaponController.release(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction("TW_Reload", function(_, state)
		if state == Enum.UserInputState.Begin then
			WeaponController.reload()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or Store.phase() == "build" then
			return
		end
		local map = { [Enum.KeyCode.One] = "bow", [Enum.KeyCode.Two] = "crossbow", [Enum.KeyCode.Three] = "heavy" }
		local key = map[input.KeyCode]
		if key then
			WeaponController.equip(key)
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if
			processed
			or input.UserInputType ~= Enum.UserInputType.MouseWheel
			or Store.phase() ~= "fight"
			or CameraController.mouseFree()
		then
			return
		end
		local z = input.Position and input.Position.Z or 0
		if z ~= 0 then
			WeaponController.cycle(z < 0 and 1 or -1) -- (wheel down: the next bow)
		end
	end)
	Bus.Fire:Connect(function(down)
		if down then
			WeaponController.startDraw()
		else
			WeaponController.release(false)
		end
	end)
	Bus.Weapon:Connect(function(key)
		WeaponController.equip(key)
	end)
	Bus.Reload:Connect(function()
		WeaponController.reload()
	end)
	Store.Changed:Connect(function(partial)
		local me = partial.me
		local prof = partial.profile or Store.get("profile") or {}
		local skinKey = tostring((prof.equipped or {}).skin)
		local key = (me or partial.profile)
			and (
				tostring((me and me.team) or Store.team())
				.. ":"
				.. tostring(me and me.weapon or (Store.get("me") or {}).weapon)
				.. ":"
				.. skinKey
			)
		if key and key ~= viewKey then
			viewKey = key
			buildView()
		end
		if partial.match and partial.match.phase ~= "fight" and drawing then
			drawing = false
			Bus.Charge:Fire(nil)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		placeView(dt)
		if drawing then
			local c = WeaponController.charge()
			Bus.Charge:Fire(c)
			CameraController.setFov("draw", -(c or 0) * 10)
		else
			CameraController.setFov("draw", nil)
		end
	end)
end

return WeaponController
