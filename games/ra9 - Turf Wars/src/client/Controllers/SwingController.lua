--[[
How a blade slash looks and feels (the server decides the hit; this is only the show, and your own lunge):

  * Your own slash (WeaponController.swing): it turns onto the nearest enemy in front of you (a soft lock-on,
    Constants.BLADE_LOCK_*: wider on a touch screen, where a thumb can't aim a sword) and lunges you at them
    (BLADE_LUNGE studs over BLADE_LUNGE_TIME, stopping just short; a slash at no one is only a step). Your client
    owns your body, so the lunge is here: the server's reach already counts it.
  * Everyone else's slash (Net "Swing"): their right arm winds up and sweeps across in a fast arc (the R15
    RightShoulder joint, set after the animations each frame), and a white streak in their team's colour cuts the
    air in front of them.
  * Your own slash (Bus.Fired with the blade): a streak across your view, in front of the blade.
  * A hit with the blade (Net "Hit" with melee): a burst of sparks where it landed, a sharp camera jolt and a short
    zoom punch, so you feel it connect; on a knockout the slash freezes for an instant (BLADE_HITSTOP: the streaks,
    the arms and your blade hold still) under a white flash, and your lunge stops dead on them.
  * A whiff (Net "Swing" { whiff } for you: it reached no one): a puff of air where you slashed (AudioController
    plays the empty swish).
  * A clash (Net "Hit" { clash }: two blades met): sparks between you and you're thrown back.

  SwingController.aim(look)                 the way to slash (turned onto the nearest enemy in front), and their root
  SwingController.lunge(dir, target)        lunge your body that way (toward target, stopping short)
  SwingController.lunging()                 still lunging?
  SwingController.clock()                   os.clock() less the hit-stops (the slash animations run on it)
  SwingController.slashOf(character, dir)   play another player's slash (tests call it)
  SwingController.streaks()                 how many streak pieces are on screen
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local SwordSkins = require(ReplicatedStorage.Shared.SwordSkins)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Device = require(script.Parent.Parent.UI.Device)
local Theme = require(script.Parent.Parent.UI.Theme)
local Store = require(script.Parent.Parent.Store)
local CameraController = require(script.Parent.CameraController)

local SwingController = { Name = "SwingController", Order = 47 }

local SWING_SECONDS = 0.32
local player = Players.LocalPlayer
local folder
local pieces = {} -- { part, born, life, size }
local arms = {} -- [motor] = { start, base }
local lunge -- { dir, speed, untilT, target } your own lunge
local stalled = 0 -- seconds of hit-stop so far (SwingController.clock)
local frozenUntil = 0
local flash -- the white flash on a knockout (a Frame)

local function bodyOf(userId)
	local p = Players:GetPlayerByUserId(userId)
	if p then
		return p.Character
	end
	local bots = workspace:FindFirstChild("Bots")
	for _, m in bots and bots:GetChildren() or {} do
		if m:GetAttribute("BotId") == userId then
			return m
		end
	end
	return nil
end

local function myRoot()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function flatUnit(v)
	local f = Vector3.new(v.X, 0, v.Z)
	return f.Magnitude > 0.01 and f.Unit or nil
end

function SwingController.clock()
	return os.clock() - stalled
end

-- The enemies' bodies (other players on the other team, and the bots)
local function enemies()
	local mine = player:GetAttribute("Team")
	local out = {}
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character and p:GetAttribute("Team") ~= mine then
			table.insert(out, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	for _, c in bots and bots:GetChildren() or {} do
		if c:GetAttribute("Team") ~= mine then
			table.insert(out, c)
		end
	end
	return out
end

-- The soft lock-on: the nearest living enemy within BLADE_LOCK_RANGE and BLADE_LOCK_ARC of where you look (wider
-- on a touch screen). Returns the flat way to them (or the flat look) and their root (or nil).
function SwingController.aim(look)
	local r = myRoot()
	local flat = flatUnit(look) or (r and flatUnit(r.CFrame.LookVector)) or Vector3.new(0, 0, -1)
	if not r then
		return flat, nil
	end
	local arc = Constants.BLADE_LOCK_ARC + (Device.kind() == "touch" and 15 or 0)
	local best, bestScore
	for _, c in enemies() do
		local er = c:FindFirstChild("HumanoidRootPart")
		local hum = c:FindFirstChildOfClass("Humanoid")
		if er and (not hum or hum.Health > 0) then
			local to = er.Position - r.Position
			local d = Vector3.new(to.X, 0, to.Z).Magnitude
			local dir = flatUnit(to)
			if dir and d <= Constants.BLADE_LOCK_RANGE and math.abs(to.Y) < 5 then
				local angle = math.deg(math.acos(math.clamp(dir:Dot(flat), -1, 1)))
				-- (nearest wins, but one right ahead beats one a little nearer off to the side)
				local score = d + angle * 0.08
				if angle <= arc and (not bestScore or score < bestScore) then
					best, bestScore = er, score
				end
			end
		end
	end
	if not best then
		return flat, nil
	end
	return flatUnit(best.Position - r.Position) or flat, best
end

-- Lunge your own body: toward target (stopping STOP studs short of them), else a short step along dir
local STOP = 3
function SwingController.lunge(dir, target)
	local r = myRoot()
	dir = dir and flatUnit(dir)
	if not r or not dir then
		return false
	end
	local dist = Constants.BLADE_STEP
	if target then
		local gap = Vector3.new(target.Position.X - r.Position.X, 0, target.Position.Z - r.Position.Z).Magnitude
		dist = math.clamp(gap - STOP, 0, Constants.BLADE_LUNGE)
	end
	-- (face the way you slash, so everyone sees you swing at them)
	r.CFrame = CFrame.lookAt(r.Position, r.Position + dir)
	if dist < 0.1 then
		lunge = nil
		return false
	end
	lunge = {
		dir = dir,
		speed = dist / Constants.BLADE_LUNGE_TIME,
		untilT = os.clock() + Constants.BLADE_LUNGE_TIME,
		target = target,
	}
	return true
end

function SwingController.lunging()
	return lunge ~= nil
end

local function piece(cf, size, color, life)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Transparency = 0.15
	p.Parent = folder
	table.insert(pieces, { part = p, born = os.clock(), life = life or 0.22, size = size })
	return p
end

-- A curved streak: thin glowing segments along an arc, from up right to down left, centred at `at`, facing `dir`
local function streak(at, dir, color, radius)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
	local frame = CFrame.lookAt(at, at + flat)
	local n = 7
	for i = 0, n - 1 do
		local a = math.rad(-60 + 120 * (i / (n - 1)))
		local local0 = Vector3.new(math.cos(a) * radius, math.sin(a) * radius * 0.55, 0)
		local a2 = math.rad(-60 + 120 * ((i + 1) / (n - 1)))
		local local1 = Vector3.new(math.cos(a2) * radius, math.sin(a2) * radius * 0.55, 0)
		local p0, p1 = frame * local0, frame * local1
		local len = math.max(0.1, (p1 - p0).Magnitude)
		local w = 0.08 + 0.12 * math.sin(math.pi * i / (n - 1)) -- (thick in the middle, thin at the ends)
		piece(CFrame.lookAt((p0 + p1) / 2, p1), Vector3.new(w, w, len), color, 0.16 + i * 0.012)
	end
end

function SwingController.streaks()
	return #pieces
end

-- The streak's colour: a sword skin's own (its trail token: lava, ice, a rainbow...), else `default`
local function streakColor(swordKey, team, default)
	local token = SwordSkins.trailToken(SwordSkins.lookOf(swordKey))
	if not token then
		return default
	end
	return Cosmetics.color(token, team):Lerp(Color3.new(1, 1, 1), 0.2)
end
SwingController.streakColor = streakColor

function SwingController.slashOf(character, dir)
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local team = character:GetAttribute("Team")
	local color = (Constants.TEAM_COLOR[team or ""] or Color3.new(1, 1, 1)):Lerp(Color3.new(1, 1, 1), 0.45)
	local owner = Players:GetPlayerFromCharacter(character)
	color = streakColor(owner and owner:GetAttribute("LookSword"), team, color)
	local look = typeof(dir) == "Vector3" and dir or root.CFrame.LookVector
	streak(root.Position + Vector3.new(0, 1.2, 0) + look * 2.4, look, color, 2.2)
	local arm = character:FindFirstChild("RightUpperArm")
	local motor = arm and arm:FindFirstChild("RightShoulder")
	if motor and motor:IsA("Motor6D") then
		arms[motor] = { start = os.clock() }
	end
	return true
end

local function sparks(pos, strong)
	local n = strong and 14 or 8
	for _ = 1, n do
		local d = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
		d = d.Magnitude > 0.01 and d.Unit or Vector3.yAxis
		local len = 0.6 + math.random() * 0.9
		local at = pos + Vector3.new(0, 1, 0) + d * (0.4 + math.random() * 0.8)
		piece(CFrame.lookAt(at, at + d), Vector3.new(0.08, 0.08, len), Color3.fromRGB(255, 255, 255), 0.18)
	end
end

-- A puff of air where a slash cut nothing (a few faint grey wisps along it)
local function puff(at, dir)
	for i = 1, 4 do
		local side = Vector3.new(-dir.Z, 0, dir.X) * (math.random() - 0.5) * 1.6
		local p = at + dir * (1 + i * 0.5) + side + Vector3.new(0, math.random() * 0.6 - 0.3, 0)
		local part = piece(CFrame.lookAt(p, p + dir), Vector3.new(0.05, 0.05, 0.7), Color3.fromRGB(220, 224, 230), 0.2)
		part.Transparency = 0.5
	end
end

local function flashOnce()
	if Theme.reducedMotion() then
		return
	end
	if not flash then
		local pg = player:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return
		end
		local gui = Theme.screen("SlashFlash", 11, pg)
		gui.IgnoreGuiInset = true
		flash = Theme.new("Frame", {
			Name = "Flash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = gui,
		})
	end
	flash.BackgroundTransparency = 0.6
end

local function step(dt)
	local t = os.clock()
	dt = dt or 0
	-- the hit-stop: everything in a slash holds still for a moment (their clocks wait)
	local frozen = t < frozenUntil
	if frozen then
		stalled += dt
	end
	if flash and flash.BackgroundTransparency < 1 then
		flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 3.5)
	end
	-- your lunge: carried along (the physics keeps you out of walls), until it's run, or you're on them
	if lunge then
		local r = myRoot()
		local tr = lunge.target
		local close = r
			and tr
			and tr.Parent
			and Vector3.new(tr.Position.X - r.Position.X, 0, tr.Position.Z - r.Position.Z).Magnitude <= STOP
		if not r or t >= lunge.untilT or close or frozen then
			if r then
				local v = r.AssemblyLinearVelocity
				r.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, v.Y, v.Z * 0.3) -- (stop, don't skid on)
			end
			lunge = nil
		else
			local v = r.AssemblyLinearVelocity
			r.AssemblyLinearVelocity = Vector3.new(lunge.dir.X * lunge.speed, v.Y, lunge.dir.Z * lunge.speed)
		end
	end
	for i = #pieces, 1, -1 do
		local s = pieces[i]
		if frozen then
			s.born += dt
		end
		local k = (t - s.born) / s.life
		if k >= 1 then
			s.part:Destroy()
			table.remove(pieces, i)
		else
			s.part.Transparency = 0.15 + 0.85 * k * k
			s.part.Size = Vector3.new(s.size.X * (1 - k * 0.6), s.size.Y * (1 - k * 0.6), s.size.Z)
		end
	end
	-- arms mid-slash: wind up, a fast sweep across, and back (set after the animations, so it wins this frame)
	for motor, a in arms do
		if frozen then
			a.start += dt
		end
		local f = (t - a.start) / SWING_SECONDS
		if f >= 1 or not motor.Parent then
			arms[motor] = nil
			pcall(function()
				motor.Transform = CFrame.new()
			end)
		else
			local sweep = f < 0.25 and -(f / 0.25)
				or (f < 0.6 and -1 + 2.4 * ((f - 0.25) / 0.35) or 1.4 * (1 - (f - 0.6) / 0.4))
			pcall(function()
				motor.Transform = CFrame.Angles(math.rad(70 + 30 * sweep), math.rad(-40 * sweep), math.rad(25 * sweep))
			end)
		end
	end
end

function SwingController:init()
	folder = Instance.new("Folder")
	folder.Name = "Slashes"
	folder.Parent = workspace
	Net.listen("Swing", function(s)
		if type(s) ~= "table" then
			return
		end
		if s.by == player.UserId then
			-- (your own: drawn as you clicked; the server only says when it cut nothing)
			local r = s.whiff and myRoot()
			if r then
				puff(r.Position + Vector3.new(0, 1.2, 0), flatUnit(r.CFrame.LookVector) or Vector3.new(0, 0, -1))
			end
			return
		end
		SwingController.slashOf(bodyOf(s.by), s.dir)
	end)
	Bus.Fired:Connect(function(key)
		if key ~= "blade" then
			return
		end
		local cam = workspace.CurrentCamera
		if cam then
			local look = cam.CFrame.LookVector
			local mine = ((Store.get("profile") or {}).equipped or {}).sword
			local color = streakColor(mine, Store.team(), Color3.fromRGB(255, 255, 255))
			streak(cam.CFrame.Position + look * 2.6 - Vector3.new(0, 0.35, 0), look, color, 1.5)
		end
	end)
	Net.listen("Hit", function(h)
		if type(h) ~= "table" or not h.melee then
			return
		end
		if h.clash then
			-- steel on steel: sparks between you, and you're thrown back (your client owns your body)
			if typeof(h.pos) == "Vector3" then
				sparks(h.pos - Vector3.new(0, 1, 0), true)
			end
			lunge = nil
			local r = myRoot()
			if r and typeof(h.knock) == "Vector3" then
				r.AssemblyLinearVelocity += h.knock
			end
			CameraController.shake(Theme.reducedMotion() and 0.05 or 0.25, 0.14)
			return
		end
		if typeof(h.pos) == "Vector3" then
			sparks(h.pos, h.kill or h.head)
		end
		local strong = h.kill or h.head
		if h.kill then
			-- the impact: the slash holds for an instant, a white flash, and your lunge stops on them
			frozenUntil = os.clock() + (Theme.reducedMotion() and 0 or Constants.BLADE_HITSTOP)
			flashOnce()
		end
		CameraController.shake(Theme.reducedMotion() and 0.05 or (strong and 0.32 or 0.2), 0.14)
		CameraController.setFov("slash", strong and -9 or -6)
		task.delay(0.09, function()
			CameraController.setFov("slash", nil)
		end)
	end)
	RunService.RenderStepped:Connect(step)
end

return SwingController
