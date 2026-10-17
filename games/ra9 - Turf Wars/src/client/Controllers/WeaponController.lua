--[[
Your weapons (master plan §5, §6): the viewmodel in your hands, the draw, the shot and the throw.

  * Hold the mouse (or the touch FIRE button, or the gamepad's right trigger) to draw; let go to shoot. The bow's
    string comes back as the charge builds, the view tightens a little, and a ring round the crosshair fills
    (Bus.Charge).
  * Let go and the arrow is drawn at once (ArrowController.predict) while the shot goes to the server (Shoot:
    from your eye, the way you're looking). The server times the draw itself, so a held mouse can't cheat a charge.
  * The TNT: hold to wind up (the ring fills: the charge is how far it goes), let go to lob it. It's drawn flying at
    once (ExplosionController.predict) and the server throws the real one (Shoot again: it knows it's the TNT). Then a
    cooldown (Weapons tnt.cooldown) before the next bundle comes up into your hand.
  * 1 / 2 / 3 pick the bow, the TNT and the blade (Data/Weapons' order; in the build phase the digits pick
    structures), and the mouse wheel (or the touch SWAP button) steps through them. Only in the fight, alive.
  * The Blade: click (or FIRE) to slash. The slash shows at once; the server finds who it reaches (Swing).
  * No drawing or shooting while a menu is open (the shop, a card, the results): the mouse is the menu's then.

The viewmodel (this client only): your arms in the team's sleeves holding the bow, its limbs, a string in two halves
that bends to your hand, and the arrow. It moves on springs: up from below when you equip, a walking bob and
breathing, lagging a little behind your view as you look round, dropped and turned across you as you sprint,
tilted in a slide, steadier crouched, toward the middle as you draw (the limbs bend, the string comes back, and at
full draw it shakes with the tension), a snap and a kick on release with the string overshooting, the next arrow
sliding in, a dip when you land. The TNT: a bundle of red sticks in your right hand with a fuse that sparks while you
wind up, drawn back over your shoulder as the charge builds, thrown forward on release, your hand down and empty
through the cooldown and a fresh bundle up from below at its end.
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
local Flair = require(script.Parent.Parent.FX.Flair)
local Device = require(script.Parent.Parent.UI.Device)
local Store = require(script.Parent.Parent.Store)
local ArrowController = require(script.Parent.ArrowController)
local CameraController = require(script.Parent.CameraController)
local ExplosionController = require(script.Parent.ExplosionController)
local SwingController = require(script.Parent.SwingController)

local WeaponController = { Name = "WeaponController", Order = 30 }

local drawing = false
local drawStart = 0
local shotId = 0
local lastShot = {} -- [weapon key] = os.clock() of its last shot (each has its own cooldown)
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

-- Aim help by how you play, the same numbers the server uses (Constants.AIM_ASSIST_DEVICE: a thumb a fair bit, a
-- stick a little; a mouse none): a shot let go within the cone of an enemy's body turns that way by the pull share
-- of the gap, never more than max degrees. Only close to the line and never through walls (the server flies the
-- arrow, with the same help, so what you see is what flies). Still waiting for your first knockout ("Novice"), the
-- server helps a lot more and the arrow is redrawn from its copy.
local ASSIST_RANGE = 140
function WeaponController.assist(origin, dir)
	local how = Constants.AIM_ASSIST_DEVICE[Device.kind()]
	if not how then
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
				if angle <= how.cone and (not bestAngle or angle < bestAngle) then
					best, bestAngle = to.Unit, angle
				end
			end
		end
	end
	if not best or bestAngle < 0.01 then
		return dir
	end
	local turn = math.min(bestAngle * how.pull, how.max)
	return dir:Lerp(best, turn / bestAngle).Unit
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
-- Your hands: your avatar's own skin colour (its HumanoidDescription; in a match everyone's body is painted in the
-- team's colour, so it's asked for once from your avatar), a neutral light tone until then
local SKIN = Color3.fromRGB(236, 196, 162)
local skinTone

local function skinColor()
	return skinTone or SKIN
end

-- A hand closed round a bar (a grip, a hilt, the stock; with a thin bar, the string: a hook): built in its own frame,
-- the bar along Y through the middle (radius r), the index finger toward +Y, the forearm going off toward +Z, and the
-- palm against the bar from +X (the back of the hand out at +X). The left hand is the right one in a mirror (X
-- flipped). Model units, like every viewmodel offset. Each part is { part, where in the hand's frame }.
local function handShape(piece, name, mirror, r)
	local sx = mirror and -1 or 1
	local list = {}
	local color = skinColor()
	local function at(x, y, z)
		return Vector3.new(x * sx, y, z) * VM_SCALE
	end
	-- a rounded piece from a to b (a finger's bone, the thumb): a cylinder, its axis along the line
	local function bone(a, b, d, partName)
		local p = piece(Vector3.new(1, d, d), color, partName)
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new((b - a).Magnitude + d * 0.6 * VM_SCALE, d * VM_SCALE, d * VM_SCALE)
		local mid = (a + b) / 2
		local up = math.abs((b - a).Unit.Y) > 0.95 and Vector3.xAxis or Vector3.yAxis
		table.insert(list, { p, CFrame.lookAt(mid, b, up) * CFrame.Angles(0, math.rad(90), 0) })
		return p
	end
	-- the palm and the back of the hand, a rounded ridge along the knuckles
	local palm = piece(Vector3.new(0.16, 0.42, 0.36), color, name)
	table.insert(list, { palm, CFrame.new(at(r + 0.08, -0.02, 0.14)) })
	local ridge = piece(Vector3.new(0.42, 0.15, 0.15), color, name .. "Knuckles")
	ridge.Shape = Enum.PartType.Cylinder
	table.insert(list, { ridge, CFrame.new(at(r + 0.07, -0.02, -0.03)) * CFrame.Angles(0, 0, math.rad(90)) })
	-- four fingers wrapped round the front of the bar to its far side, the little finger a bit thinner
	for i, y in { 0.15, 0.05, -0.05, -0.15 } do
		local d = i == 4 and 0.085 or 0.1
		local knuckle = at(r + 0.06, y, -0.05)
		local front = at(r * 0.25, y, -(r + 0.06))
		local far = at(-(r + 0.05), y, -r * 0.2)
		bone(knuckle, front, d, name .. "Finger")
		bone(front, far, d * 0.92, name .. "Finger")
	end
	-- the thumb, round the other way to meet them
	local base = at(r + 0.03, 0.16, 0.2)
	local mid = at(r * 0.2 - 0.02, 0.22, r + 0.07)
	local tip = at(-(r * 0.8), 0.2, r * 0.25 + 0.02)
	bone(base, mid, 0.115, name .. "Thumb")
	bone(mid, tip, 0.1, name .. "Thumb")
	return { list = list, palm = palm, mirror = mirror, r = r }
end

-- An arm: a short bare wrist out of the palm, a cuff, then the sleeve in the team's colour, a little wider toward
-- the elbow, out past the edge of the screen. Named for the side (ArmL / ArmR is the sleeve)
local function armShape(piece, side, color)
	local function tube(d, c, partName)
		local p = piece(Vector3.new(1, d, d), c, partName)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	return {
		wrist = tube(0.22, skinColor(), "Wrist" .. side),
		cuff = tube(0.33, color:Lerp(Color3.new(0, 0, 0), 0.25), "Cuff" .. side),
		sleeve = tube(0.3, color, "Arm" .. side),
		upper = tube(0.34, color, "Arm" .. side .. "Upper"),
	}
end

local function newLimb(piece, side, r, color)
	local h = handShape(piece, "Hand" .. side, side == "L", r)
	h.arm = armShape(piece, side, color)
	return h
end

-- Put a hand where its frame is (cf: the bar's middle, the hand's own axes) and its arm from the wrist out to a
-- shoulder (camera space, off the screen's edge)
local function placeLimb(limb, cf, shoulder)
	for _, e in limb.list do
		e[1].CFrame = cf * e[2]
	end
	local sx = limb.mirror and -1 or 1
	local cam = workspace.CurrentCamera
	local from = cf * (Vector3.new((limb.r + 0.08) * sx, -0.02, 0.22) * VM_SCALE)
	local wristEnd = cf * (Vector3.new((limb.r + 0.07) * sx, -0.02, 0.5) * VM_SCALE)
	local to = cam.CFrame * shoulder
	-- the forearm leaves the hand along the hand's own +Z, then heads for the shoulder
	local function tube(p, a, b)
		local len = math.max(0.05, (b - a).Magnitude)
		p.Size = Vector3.new(len, p.Size.Y, p.Size.Z)
		p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
	end
	local dir = (to - wristEnd).Magnitude > 0.01 and (to - wristEnd).Unit or Vector3.zAxis
	local cuffA = wristEnd - dir * 0.02 * VM_SCALE
	local cuffB = cuffA + dir * 0.12 * VM_SCALE
	local mid = cuffB:Lerp(to, 0.45)
	tube(limb.arm.wrist, from, wristEnd + dir * 0.04 * VM_SCALE)
	tube(limb.arm.cuff, cuffA, cuffB)
	tube(limb.arm.sleeve, cuffB - dir * 0.02 * VM_SCALE, mid)
	tube(limb.arm.upper, mid - dir * 0.04 * VM_SCALE, to)
end

-- Your avatar's skin, asked for once (a web call: it can be slow, or fail, and then the neutral tone stays)
local function fetchSkin()
	task.spawn(function()
		local Players = game:GetService("Players")
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(Players.LocalPlayer.UserId)
		end)
		local c = ok and desc and (desc.LeftArmColor or desc.RightArmColor)
		if typeof(c) == "Color3" then
			skinTone = c
			if view then
				for _, limb in { view.left, view.right } do
					for _, e in limb and limb.list or {} do
						e[1].Color = c
					end
					if limb then
						limb.arm.wrist.Color = c
					end
				end
			end
		end
	end)
end

local function buildView()
	if view then
		if view.flair then
			view.flair:destroy()
		end
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
		p.Massless = true
		p.Size = size * VM_SCALE
		p.Color = c
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local w = weapon()
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
	local limbLen = 1.5
	local ink = Color3.fromRGB(30, 30, 34)
	local v = { model = model, limbLen = limbLen }
	if w.throw then
		-- the TNT: three red sticks bundled upright (dark bands round them), a fuse out of the top with its spark,
		-- held in the right hand; the left a loose fist
		v.tnt = true
		v.sticks = {}
		for i = 1, 3 do
			local stick = piece(Vector3.new(1.05, 0.3, 0.3), Constants.TNT_RED, "Stick")
			stick.Shape = Enum.PartType.Cylinder
			v.sticks[i] = stick
		end
		-- (a dark tape ring round each stick, near the top and the bottom)
		v.rings = {}
		for i = 1, 6 do
			local ring = piece(Vector3.new(0.09, 0.33, 0.33), ink, "Band")
			ring.Shape = Enum.PartType.Cylinder
			v.rings[i] = ring
		end
		v.fuse = piece(Vector3.new(0.04, 0.32, 0.04), ink, "Fuse")
		v.spark = piece(Vector3.new(0.13, 0.13, 0.13), Color3.fromRGB(255, 196, 60), "Spark", Enum.Material.Neon)
		v.spark.Shape = Enum.PartType.Ball
		v.right = newLimb(piece, "R", 0.27, color)
		v.left = newLimb(piece, "L", 0.05, color)
		model.Parent = cam
		view = v
		anim.equipAt = os.clock()
		return
	end
	if w.melee then
		-- the blade: solid steel, whatever bow skin is worn (a Glass, Neon or Hologram skin is for bows: on a sword
		-- it looked like a hologram). Painted steel, not Metal: the matte lighting has almost no reflections to
		-- show, so Metal came out near black. A bright edge with a white bevel, a darker fuller down the middle, a
		-- grey guard with a gem in the team's colour, a leather grip in the team's colour
		v.blade = true
		local steel, bevel, fuller =
			Color3.fromRGB(214, 218, 225), Color3.fromRGB(250, 251, 253), Color3.fromRGB(150, 155, 164)
		local guardSteel = Color3.fromRGB(118, 122, 132)
		local smooth, leather = Enum.Material.SmoothPlastic, Enum.Material.Fabric
		v.grip = piece(Vector3.new(0.2, 0.2, 0.75), color, "Grip", leather)
		v.pommel = piece(Vector3.new(0.28, 0.28, 0.2), guardSteel, "Pommel", smooth)
		v.guard = piece(Vector3.new(0.85, 0.16, 0.2), guardSteel, "Guard", smooth)
		v.gem = piece(Vector3.new(0.16, 0.16, 0.3), color, "Gem", Enum.Material.Neon)
		v.edge = piece(Vector3.new(0.07, 0.28, 1.6), steel, "Edge", smooth)
		v.bevel = piece(Vector3.new(0.075, 0.05, 1.55), bevel, "Bevel", smooth)
		v.spine = piece(Vector3.new(0.08, 0.06, 1.25), fuller, "Spine", smooth)
		v.tip = piece(Vector3.new(0.08, 0.2, 0.3), steel, "Tip", smooth)
		-- the right hand round the grip, the left a loose fist
		v.right = newLimb(piece, "R", 0.11, color)
		v.left = newLimb(piece, "L", 0.05, color)
		model.Parent = cam
		view = v
		anim.equipAt = os.clock()
		return
	end
	v.grip = piece(Vector3.new(0.22, 0.6, 0.24), gripColor, "Grip", material)
	v.upper = piece(Vector3.new(0.24, limbLen, 0.13), limbColor, "Upper", material)
	v.lower = piece(Vector3.new(0.24, limbLen, 0.13), limbColor, "Lower", material)
	v.tipU = piece(Vector3.new(0.2, 0.18, 0.2), gripColor, "TipU", material)
	v.tipL = piece(Vector3.new(0.2, 0.18, 0.2), gripColor, "TipL", material)
	-- the string in two halves: straight at rest, a V to your hand as you draw
	v.strU = piece(Vector3.new(0.03, 1, 0.03), ink, "String")
	v.strL = piece(Vector3.new(0.03, 1, 0.03), ink, "StringL")
	-- the arrow: a white shaft, a team-coloured head and fletching
	v.shaft = piece(Vector3.new(0.07, 0.07, 1.9), Constants.WHITE, "Nocked")
	v.head = piece(Vector3.new(0.13, 0.13, 0.22), color, "Head", Enum.Material.Neon)
	v.fletch = piece(Vector3.new(0.02, 0.18, 0.32), color, "Fletch")
	-- your arms in the team's sleeves: a bow's grip in the left hand and the string hooked in the right
	v.left = newLimb(piece, "L", 0.12, color)
	v.right = newLimb(piece, "R", 0.035, color)
	-- the skin brought to life (FX/Flair: a rainbow, stripes, embers, sparks, wings...)
	if look and (look.anim or look.particles or look.wings or Flair.moving(look.grip) or Flair.moving(look.limbs)) then
		v.flair = Flair.bow({
			grip = v.grip,
			limbs = { v.upper, v.lower },
			tips = { v.tipU, v.tipL },
			holder = model,
			scale = VM_SCALE,
		}, look, team)
	end
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
	local show = me
		and me.alive
		and Store.phase() ~= "build"
		and Store.phase() ~= "loading"
		and not CameraController.takenOver() -- (a cinematic has the camera: no bow floating in it)
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
	local tremble = held > 0 and math.min(1, held / 2) * 0.01 * steady or 0
	local shake = Vector3.new(math.sin(t * 47) * tremble, math.cos(t * 53) * tremble, 0)
	-- the shot: a snap forward, a kick up; the string overshoots past rest and settles
	local kickP = spring(anim.kick, 0, dt, 220, 16)
	local pullS = spring(anim.pull, drawing and c or 0, dt, drawing and 400 or 900, drawing and 40 or 22)
	local landP = spring(anim.land, 0, dt, 160, 14)
	-- a magazine's reload (no weapon has one now): tipped down and back
	local reloadK = 0
	if anim.reloadAt and w.reload then
		local f = (t - anim.reloadAt) / w.reload
		if f >= 1 then
			anim.reloadAt = nil
		else
			reloadK = math.sin(math.min(1, f) * math.pi)
		end
	end
	if view.blade then
		-- the blade: held in the right hand, edge up and forward; a slash sweeps it from up right to down left
		-- across the view, with a little lunge, then it comes back
		local f = math.clamp((SwingController.clock() - (anim.swingAt or -10)) / 0.32, 0, 1) -- (holds in a hit-stop)
		local sw = f < 1 and math.sin(f * math.pi) or 0 -- (out and back)
		local arc = f < 1 and (f < 0.45 and ease(f / 0.45) or 1 - ease((f - 0.45) / 0.55) * 0.999) or 0
		local pos = Vector3.new(0.6, -0.62, -1.5):Lerp(Vector3.new(-0.25, -0.4, -1.75), arc)
			+ Vector3.new(
				swayX * 0.35 - run * 0.1,
				breathe - swayY * 0.35 - run * 0.15 - crouchK * 0.05 - landP,
				-sw * 0.2
			)
		local bcf = cam.CFrame
			* CFrame.new(bob)
			* CFrame.new(pos)
			* equipOff
			* CFrame.Angles(
				math.rad(35 - arc * 70 - run * 20 + swayY * 20),
				math.rad(-15 + arc * 50 + run * 25 + swayX * 25),
				math.rad(-25 + arc * 85 - tilt * 16 + swayX * 15)
			)
		-- (the blade points up and forward from the hand: along the grip's -Z, tipped up)
		local up = bcf * CFrame.Angles(math.rad(60), 0, 0)
		view.grip.CFrame = up
		view.pommel.CFrame = up * L(0, 0, 0.45)
		view.guard.CFrame = up * L(0, 0, -0.45)
		view.edge.CFrame = up * L(0, 0, -1.35)
		view.spine.CFrame = up * L(0, 0.03, -1.3)
		view.bevel.CFrame = up * L(0, -0.12, -1.35)
		view.gem.CFrame = up * L(0, 0, -0.45)
		view.tip.CFrame = up * L(0, 0, -2.25) * CFrame.Angles(math.rad(45), 0, 0)
		-- the right hand round the grip: the bar along the grip (index finger toward the guard), the back of the
		-- hand out to the right, the wrist under the grip
		local gripCf = up * L(0, 0, 0.08)
		local handCf = CFrame.fromMatrix(gripCf.Position, gripCf.RightVector, gripCf.LookVector, gripCf.UpVector)
		placeLimb(view.right, handCf * CFrame.Angles(0, math.rad(-20), 0), Vector3.new(0.95, -1.0, -0.45))
		-- the left a loose fist low and out of the way, swinging back a little as you slash
		local leftCf = cam.CFrame
			* CFrame.new(-0.62 - sw * 0.1, -0.72 + bob.Y, -1.15)
			* equipOff
			* CFrame.Angles(math.rad(-70), math.rad(-25), math.rad(10))
		placeLimb(view.left, leftCf, Vector3.new(-0.95, -1.1, -0.4))
		return
	end
	if view.tnt then
		-- the TNT, low on the right; winding up draws it back and up over your shoulder (out to the right, clear of
		-- the crosshair), the throw snaps it forward and down, then the hand drops out of sight, empty, until the
		-- cooldown's last moments bring a fresh bundle up from below
		local since = t - (anim.thrownAt or -10)
		local restP = Vector3.new(0.58, -0.64, -1.4)
		local windP = Vector3.new(0.8, -0.36, -1.12)
		local throwP = Vector3.new(0.5, -0.86, -1.8)
		local downP = Vector3.new(0.62, -1.5, -1.3)
		local wind = pullS
		local pos, pitch
		local holding = true
		local THROW, DROP = 0.3, 0.3
		if since < THROW then
			local f = ease(since / THROW)
			pos = (anim.throwFrom or windP):Lerp(throwP, f)
			pitch = (anim.throwPitch or 40) + (-60 - (anim.throwPitch or 40)) * f
			holding = since < 0.06
		elseif since < w.cooldown then
			local f = math.clamp((since - THROW) / DROP, 0, 1)
			local up = math.clamp((since - (w.cooldown - 0.45)) / 0.45, 0, 1)
			pos = throwP:Lerp(downP, f):Lerp(restP, up * up * (3 - 2 * up)) -- (no overshoot: it settles at rest)
			pitch = -60 + (10 + 60) * up
			holding = up > 0
		else
			pos = restP:Lerp(windP, wind)
			pitch = 10 + wind * 22
		end
		pos += Vector3.new(swayX * 0.35 - run * 0.1, breathe - swayY * 0.35 - run * 0.15 - crouchK * 0.05 - landP, 0) + shake
		local bcf = cam.CFrame
			* CFrame.new(bob)
			* CFrame.new(pos)
			* equipOff
			* CFrame.Angles(
				math.rad(pitch - run * 20 + swayY * 20),
				math.rad(-12 + wind * 10 + run * 25 + swayX * 25),
				math.rad(-12 - wind * 18 - tilt * 16 + swayX * 15)
			)
		if since >= THROW and since < w.cooldown then
			anim.throwFrom, anim.throwPitch = nil, nil
		elseif since >= w.cooldown then
			anim.lastTnt, anim.lastPitch = pos, pitch -- (where a throw starts from)
		end
		-- the bundle: three sticks upright round the frame's Y, bands, the fuse and its spark (lit while winding up)
		local spots = { Vector3.new(-0.15, 0, 0.07), Vector3.new(0.15, 0, 0.07), Vector3.new(0, 0, -0.19) }
		for i, stick in view.sticks do
			stick.CFrame = bcf * L(spots[i].X, 0, spots[i].Z) * CFrame.Angles(0, 0, math.rad(90))
		end
		for i, ring in view.rings do
			local spot = spots[(i - 1) % 3 + 1]
			ring.CFrame = bcf * L(spot.X, i <= 3 and 0.3 or -0.32, spot.Z) * CFrame.Angles(0, 0, math.rad(90))
		end
		view.fuse.CFrame = bcf * L(0.02, 0.66, 0.02) * CFrame.Angles(0, 0, math.rad(-12))
		local lit = drawing or since < THROW
		local flick = 1 + math.sin(t * 61) * 0.35 + math.sin(t * 37) * 0.2
		view.spark.Size = Vector3.new(0.085, 0.085, 0.085) * VM_SCALE * (lit and flick or 0.8)
		view.spark.CFrame = bcf * L(0.06, 0.84, 0.02)
		for _, q in view.model:GetChildren() do
			if q.Name == "Stick" or q.Name == "Band" or q == view.fuse or q == view.spark then
				q.Transparency = holding and 0 or 1
			end
		end
		-- (unlit: just the fuse's dark tip; lit: a flickering yellow spark)
		view.spark.Color = lit and Color3.fromRGB(255, 196, 60) or Color3.fromRGB(60, 52, 44)
		view.spark.Material = lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
		-- the right hand round the bundle's middle (the back of the hand out to the right), the left a loose fist low
		-- on the left, coming forward a little as you wind up
		placeLimb(view.right, bcf * L(0, -0.02, 0), Vector3.new(0.95, -1.25, -0.4))
		local leftCf = cam.CFrame
			* CFrame.new(-0.62 + wind * 0.08, -0.74 + bob.Y + wind * 0.06, -1.15 - wind * 0.15)
			* equipOff
			* CFrame.Angles(math.rad(-70), math.rad(-25), math.rad(10))
		placeLimb(view.left, leftCf, Vector3.new(-0.95, -1.1, -0.4))
		return
	end
	-- where the bow sits in front of you (camera space, studs): low on the right at rest; drawn, across to the low
	-- left, the top limb leaning out to the left and the arrow turned a touch outward, so nothing of the bow, the
	-- arrow or your hands crosses the middle of the screen (the crosshair) at any point of the draw
	local restP = Vector3.new(0.5, -0.58, -1.5)
	local aimP = Vector3.new(-0.74, -0.5, -1.65)
	-- (on the way across it swings low, under the crosshair: up from below as you draw, back down after the shot)
	local dip = 4 * aim * (1 - aim)
	local pos = restP:Lerp(aimP, aim)
		- Vector3.new(0, dip, 0)
		+ Vector3.new(reloadK * 0.12, -reloadK * 0.3, 0) -- (a reload drops it away, under the crosshair)
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
			math.rad(kickP * 9 - aim * 6 - run * 25 - reloadK * 35 + swayY * 20),
			math.rad(-12 + aim * 32 + run * 30 + swayX * 25),
			math.rad(-35 + aim * 50 - tilt * 16 - reloadK * 20 + swayX * 15)
		)
	local half = view.limbLen / 2 -- (model units; L scales them)
	local bend = 0.15 + pullS * 0.3
	local function at(cf, part)
		part.CFrame = cf
		return cf
	end
	-- (the shoulders are just off the screen's edges, in front of you: the sleeves come in from the corners)
	local shoulderR = Vector3.new(0.9, -1.25, -0.5)
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
	-- (the left hand's knuckles turned out to the left a little; the right hand's index finger just under the
	-- arrow, its fingers hooked round the string)
	placeLimb(
		view.left,
		base * CFrame.Angles(0, math.rad(-30), 0),
		Vector3.new(-0.35, -1.35, -0.45):Lerp(Vector3.new(-0.95, -1.15, -0.6), aim)
	)
	placeLimb(view.right, CFrame.new(nock) * (base - base.Position) * L(0, -0.22, 0), shoulderR)
end

-- Draw and shoot ---------------------------------------------------------------------------------------------------
function WeaponController.startDraw()
	if not canShoot() or drawing then
		return false
	end
	local w = weapon()
	if w.melee then
		return WeaponController.swing()
	end
	if w.draw <= 0 then
		WeaponController.release(true) -- (a weapon with no draw shoots on each press)
		return true
	end
	if os.clock() - (lastShot[w.key] or 0) < w.cooldown then
		return false
	end
	drawing = true
	drawStart = os.clock()
	Net.send("Draw", true)
	return true
end

function WeaponController.release(instant)
	local w = weapon()
	if w.melee then
		return false
	end
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
	if instant and os.clock() - (lastShot[w.key] or 0) < w.cooldown then
		return false
	end
	local charge = instant and 1 or Formulas.charge(w, os.clock() - drawStart)
	drawing = false
	Bus.Charge:Fire(nil)
	local cam = workspace.CurrentCamera
	local origin = cam and cam.CFrame.Position or Vector3.zero
	local dir = cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1)
	if not w.throw then
		dir = WeaponController.assist(origin, dir) -- (a lob isn't a straight line: no help for the TNT)
	end
	shotId += 1
	lastShot[w.key] = os.clock()
	local shot = Formulas.shot(w, charge)
	-- (start it a stud ahead, so it never begins inside your own head)
	local start = origin + dir * 1
	if w.throw then
		-- the TNT: drawn flying at once in the same lob the server throws, the cooldown on the hotbar
		ExplosionController.predict(start, Formulas.lobVelocity(dir, shot.speed), Store.team() or "red", shotId)
		Net.send("Shoot", start, dir, shotId)
		Store.merge("me", { readyAt = os.clock() + w.cooldown })
		anim.thrownAt = os.clock()
		anim.throwFrom, anim.throwPitch = anim.lastTnt, anim.lastPitch
		CameraController.shake(0.05 + charge * 0.06, 0.12)
		Bus.Fired:Fire(w.key, charge)
		return true
	end
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

-- A slash with the blade: it swings at once, turned onto the nearest enemy in front and lunging you at them
-- (SwingController); the server decides who it reaches
function WeaponController.swing()
	local w = weapon()
	if not w.melee or not canShoot() or os.clock() - (lastShot[w.key] or 0) < w.cooldown then
		return false
	end
	lastShot[w.key] = os.clock()
	local cam = workspace.CurrentCamera
	local dir, lock = SwingController.aim(cam and cam.CFrame.LookVector or Vector3.new(0, 0, -1))
	Net.send("Swing", dir)
	SwingController.lunge(dir, lock)
	anim.swingAt = SwingController.clock()
	CameraController.shake(0.06, 0.1)
	Bus.Fired:Fire(w.key, 1)
	return true
end

-- The blade only comes out in the CHARGE (the fight's last seconds: workspace "Charge"); bows the rest of the time
function WeaponController.allowed(key)
	local w = Weapons.get(key)
	return w ~= nil and (not w.melee or workspace:GetAttribute("Charge") == true)
end

function WeaponController.equip(key)
	if Weapons.locked(key, game:GetService("Players").LocalPlayer) then
		-- (not bought yet: the server opens the purchase; until then the bow stays in hand)
		Net.send("Equip", key)
		return false
	end
	if not WeaponController.allowed(key) or Store.phase() == "build" then
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
	for i = 1, n do
		local key = Weapons.list[(at - 1 + step * i) % n + 1].key
		if WeaponController.allowed(key) and not Weapons.locked(key, game:GetService("Players").LocalPlayer) then
			return WeaponController.equip(key)
		end
	end
	return false
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
	fetchSkin()
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
		-- (the digits in Data/Weapons' order: 1 the bow, 2 the TNT, 3 the blade)
		local digits = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five }
		local i = table.find(digits, input.KeyCode)
		local key = i and Weapons.list[i] and Weapons.list[i].key
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
	Bus.Cycle:Connect(function(step)
		if Store.phase() == "fight" then
			WeaponController.cycle(step or 1)
		end
	end)
	-- the CHARGE is over: the blade goes away, the bow comes back out
	workspace:GetAttributeChangedSignal("Charge"):Connect(function()
		local w = weapon()
		if workspace:GetAttribute("Charge") ~= true and w and w.melee then
			drawing = false
			Store.merge("me", { weapon = Weapons.DEFAULT, ammo = Weapons.get(Weapons.DEFAULT).mag })
			buildView()
		end
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
		if view and view.flair then
			view.flair:update(os.clock())
		end
		if drawing then
			local c = WeaponController.charge()
			Bus.Charge:Fire(c)
			-- (a phone's wider view zooms in further, to the same tight aim as a monitor's)
			local zoom = weapon().throw and 3 or (Device.isPhone() and 10 + CameraController.PHONE_FOV or 10)
			CameraController.setFov("draw", -(c or 0) * zoom)
		else
			CameraController.setFov("draw", nil)
		end
	end)
end

return WeaponController
