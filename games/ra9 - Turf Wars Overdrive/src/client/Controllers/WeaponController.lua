--[[
Your bow (master plan §5, §6): the viewmodel in your hands, the draw and the shot.

  * Hold the mouse (or the touch FIRE button, or the gamepad's right trigger) to draw; let go to shoot. The bow's
    string comes back as the charge builds, the view tightens a little, and a ring round the crosshair fills
    (Bus.Charge). The crossbow fires on each press, six bolts, then R (or the RELOAD button) to reload.
  * Let go and the arrow is drawn at once (ArrowController.predict) while the shot goes to the server (Shoot:
    from your eye, the way you're looking). The server times the draw itself, so a held mouse can't cheat a charge.
  * 1 / 2 / 3 pick the Standard Bow, the Rapid Crossbow, the Heavy Bow (in the fight; in the build phase the
    digits pick structures). Only in the fight, alive.

The viewmodel is a few parts in your team's colour and white, welded to the camera on this client only.
]]
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local ArrowController = require(script.Parent.ArrowController)
local CameraController = require(script.Parent.CameraController)

local WeaponController = { Name = "WeaponController", Order = 30 }

local drawing = false
local drawStart = 0
local shotId = 0
local lastShot = 0
local view -- { model, string, limbs, kick }
local kick = 0
local viewKey

local function weapon()
	local me = Store.get("me")
	return Weapons.get(me and me.weapon or Weapons.DEFAULT) or Weapons.get(Weapons.DEFAULT)
end

local function canShoot()
	local me = Store.get("me")
	return Store.phase() == "fight" and me and me.alive == true
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
	local function piece(size, c, name)
		local p = Instance.new("Part")
		p.Name = name or "Piece"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Size = size
		p.Color = c
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local w = weapon()
	local big = w.key == "heavy"
	local grip = piece(Vector3.new(0.22, 0.6, 0.22), color, "Grip")
	local upper = piece(Vector3.new(0.14, big and 1.9 or 1.5, 0.14), Constants.WHITE, "Upper")
	local lower = piece(Vector3.new(0.14, big and 1.9 or 1.5, 0.14), Constants.WHITE, "Lower")
	local str = piece(Vector3.new(0.03, 1, 0.03), Color3.fromRGB(30, 30, 34), "String")
	local stock
	if w.key == "crossbow" then
		stock = piece(Vector3.new(0.2, 0.2, 1.6), Constants.WHITE, "Stock")
	end
	-- the arrow nocked on the string, in the team's colour
	local nock = piece(Vector3.new(0.08, 0.08, 1.8), color, "Nocked")
	nock.Material = Enum.Material.Neon
	model.Parent = cam
	view = {
		model = model,
		grip = grip,
		upper = upper,
		lower = lower,
		string = str,
		stock = stock,
		nock = nock,
		big = big,
	}
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
		return
	end
	kick = math.max(0, kick - dt * 6)
	local c = WeaponController.charge() or 0
	local base = cam.CFrame
		* CFrame.new(0.9, -0.85, -2.2 + kick * 0.3)
		* CFrame.Angles(math.rad(kick * 8), math.rad(-8), math.rad(-12))
	local half = view.upper.Size.Y / 2
	view.grip.CFrame = base
	view.upper.CFrame = base * CFrame.new(0, half + 0.2, 0.15 + c * 0.25) * CFrame.Angles(math.rad(-18 - c * 14), 0, 0)
	view.lower.CFrame = base * CFrame.new(0, -half - 0.2, 0.15 + c * 0.25) * CFrame.Angles(math.rad(18 + c * 14), 0, 0)
	local pull = 0.35 + c * 0.9
	view.string.Size = Vector3.new(0.03, half * 3.6, 0.03)
	view.string.CFrame = base * CFrame.new(0, 0, pull)
	view.nock.Transparency = (drawing or weapon().key == "crossbow") and 0 or 1
	view.nock.CFrame = base * CFrame.new(0, 0, pull - 0.9)
	if view.stock then
		view.stock.CFrame = base
			* CFrame.new(0, -0.15, 0.4)
			* CFrame.Angles(math.rad(90), 0, 0)
			* CFrame.Angles(math.rad(-90), 0, 0)
	end
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
	kick = 1
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

function WeaponController.reload()
	local w = weapon()
	if w.mag then
		Net.send("Reload")
		Bus.Tap:Fire("reload")
	end
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
	Store.Changed:Connect(function(partial)
		local me = partial.me
		local key = me and (tostring(me.team or Store.team()) .. ":" .. tostring(me.weapon))
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
