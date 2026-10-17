--[[
The kill cam: when you're knocked out by someone, a short cinematic plays inside the respawn wait (about 3 s), then
the camera comes back to you as you respawn.

  an arrow   the letterbox slides in and the view cuts to the killer, a slow push in on their bow; then the arrow is
             replayed from the bow to you in slow motion (the same arc the server flew, Net "Kill" cam), the camera
             riding beside it and swinging round it on an eased path with a slight roll, slowing as it closes in
             (and a depth of field on high graphics); a freeze frame on the impact with a white flash, a stand-in of
             you (Effects.mannequin) shattering in slow motion; then the camera drifts round the spot as a card slides
             in: ELIMINATED BY <name>, their weapon (UI/Icons) and the distance; a fade to white and back to you
  a blade, a TNT, anything else: a quick orbit round the killer (or the blast) with the card, then the fade

Space, a click or a tap skips it once it's been up half a second. It never starts while another cinematic has the
camera (the tutorial's: TutorialController.cinematic, CameraController.takenOver) or while an admin spectates, and it
stops at once if either begins. It borrows the camera through CameraController (takeover / release), so first person
and the mouse lock come back the way CameraController keeps them. The arena sounds go muffled and roomy while it plays
(AudioController.muffle).

  KillCamController.play(k)     start it for a Kill message (tests call it too) -> true if it started
  KillCamController.skip()      the same as Space / click / tap
  KillCamController.active()    true while it plays (the fade back included)
  KillCamController.stage()     "intro" | "flight" | "freeze" | "card" | "orbit" | "fade" | nil (tests)
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)
local Effects = require(script.Parent.Parent.FX.Effects)
local Device = require(script.Parent.Parent.UI.Device)
local Icons = require(script.Parent.Parent.UI.Icons)
local Layout = require(script.Parent.Parent.UI.Layout)
local Theme = require(script.Parent.Parent.UI.Theme)
local ArrowController = require(script.Parent.ArrowController)
local AudioController = require(script.Parent.AudioController)
local CameraController = require(script.Parent.CameraController)
local GraphicsController = require(script.Parent.GraphicsController)
local SpectateController = require(script.Parent.SpectateController)

local KillCamController = { Name = "KillCamController", Order = 54 }

local C = Theme.Color
local player = Players.LocalPlayer
local UP = Vector3.yAxis
local refs = {}
KillCamController.refs = refs

-- seconds of each part (the flight's own length follows the real one, slowed, within these bounds)
local INTRO, FLIGHT_MIN, FLIGHT_MAX, FREEZE, CARD, FADE = 0.45, 0.8, 1.15, 0.32, 0.7, 0.3
local ORBIT = 1.5 -- a blade's or a blast's whole orbit
local SKIP_AFTER = 0.5
local OUTRO = 0.35 -- the fade from white back to you, after the camera's given back

local cam -- the running kill cam: { k, t0, stages, ... }
local outroAt -- os.clock() the camera was given back (the white fades off)
local trails = {} -- [userId] = the trail their last arrow wore (the replay draws it)

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function smoother(x)
	x = clamp01(x)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

-- Who else wants the camera: the tutorial's cinematics, an admin spectating
local function blocked()
	if SpectateController.active() or player:GetAttribute("Spectating") == true then
		return true
	end
	if CameraController.takenOver() then
		return true
	end
	local ok, tut = pcall(require, script.Parent.TutorialController)
	if ok and type(tut) == "table" and type(tut.cinematic) == "function" then
		local ok2, on = pcall(tut.cinematic)
		if ok2 and on then
			return true
		end
	end
	return false
end

-- The overlay ----------------------------------------------------------------------------------------------------
local function build()
	local gui = Theme.screen("KillCam", 30, player:WaitForChild("PlayerGui"))
	gui.IgnoreGuiInset = true
	gui.Enabled = false
	refs.gui = gui
	local function bar(name, y)
		return Theme.new("Frame", {
			Name = name,
			AnchorPoint = Vector2.new(0, y),
			Position = UDim2.fromScale(0, y),
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(8, 8, 10),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = gui,
		})
	end
	refs.barTop = bar("BarTop", 0)
	refs.barBottom = bar("BarBottom", 1)
	-- the tag in the top bar: KILL CAM with a red light
	refs.tag = Theme.new("Frame", {
		Name = "Tag",
		Position = UDim2.new(0, 28, 0, 18),
		Size = UDim2.fromOffset(150, 26),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = gui,
	})
	refs.dot = Theme.new("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = refs.tag,
	}, { Theme.corner("round") })
	Theme.text({
		Name = "Label",
		Text = "KILL CAM",
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -18, 1, 0),
		Font = Theme.Display,
		TextColor3 = C.white,
		fit = 18,
		ZIndex = 3,
		Parent = refs.tag,
	})
	-- the card: ELIMINATED BY, the name, the weapon, the distance
	local card = Theme.new("Frame", {
		Name = "Card",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, -520, 0.86, 0),
		Size = UDim2.fromOffset(440, 104),
		BackgroundColor3 = C.paper,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = gui,
	}, { Theme.corner(6), Theme.stroke(2, C.ink) })
	refs.card = card
	refs.stripe = Theme.new("Frame", {
		Name = "Stripe",
		Size = UDim2.new(0, 12, 1, 0),
		BackgroundColor3 = C.red,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = card,
	}, { Theme.corner(6) })
	refs.by = Theme.text({
		Name = "By",
		Text = "ELIMINATED BY",
		Position = UDim2.fromOffset(28, 12),
		Size = UDim2.fromOffset(260, 20),
		Font = Theme.Display,
		TextColor3 = C.muted,
		fit = 16,
		ZIndex = 5,
		Parent = card,
	})
	refs.name = Theme.text({
		Name = "Killer",
		Text = "",
		Position = UDim2.fromOffset(28, 32),
		Size = UDim2.fromOffset(290, 42),
		Font = Theme.Display,
		TextColor3 = C.ink,
		fit = 38,
		ZIndex = 5,
		Parent = card,
	})
	refs.info = Theme.text({
		Name = "Info",
		Text = "",
		Position = UDim2.fromOffset(28, 74),
		Size = UDim2.fromOffset(290, 20),
		Font = Theme.Display,
		TextColor3 = C.ink,
		fit = 16,
		ZIndex = 5,
		Parent = card,
	})
	refs.iconSlot = Theme.new("Frame", {
		Name = "IconSlot",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(104, 80),
		BackgroundColor3 = C.slate,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = card,
	}, { Theme.corner(6) })
	refs.skip = Theme.text({
		Name = "Skip",
		Text = "",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -28, 1, -16),
		Size = UDim2.fromOffset(240, 22),
		Font = Theme.Display,
		TextColor3 = C.white,
		TextXAlignment = Enum.TextXAlignment.Right,
		fit = 16,
		ZIndex = 3,
		Visible = false,
		Parent = gui,
	})
	refs.flash = Theme.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1, -- (the impact's flash: under the bars)
		Parent = gui,
	})
	refs.fade = Theme.new("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 8, -- (the fade home: over everything)
		Parent = gui,
	})
end

local function setCard(k)
	local team = k.killerTeam
	local color = Constants.TEAM_COLOR[team or ""] or C.red
	refs.stripe.BackgroundColor3 = color
	refs.name.Text = string.upper(k.killerName or "?")
	refs.name.TextColor3 = color
	local w = Weapons.get(k.weapon or "")
	local bits = { string.upper(w and w.name or "?") }
	if k.dist then
		table.insert(bits, `{k.dist} STUDS`)
	end
	if k.head then
		table.insert(bits, "HEADSHOT")
	end
	refs.info.Text = table.concat(bits, "  ·  ")
	for _, c in refs.iconSlot:GetChildren() do
		if c.Name == "Icon" then
			c:Destroy()
		end
	end
	pcall(function()
		Icons.weapon(k.weapon or "bow", team, {
			Size = UDim2.new(1, -8, 1, -8),
			Position = UDim2.fromOffset(4, 4),
			ZIndex = 6,
			Parent = refs.iconSlot,
		})
	end)
	refs.skip.Text = Device.isTouch() and "TAP TO SKIP" or "SPACE / CLICK TO SKIP"
end

-- The look while it plays: a little graded, a shallow focus on high graphics
local function grade(on, focus)
	pcall(function()
		local cc = Lighting:FindFirstChild("TW_KillCamGrade")
		local dof = Lighting:FindFirstChild("TW_KillCamDof")
		if not on then
			if cc then
				cc:Destroy()
			end
			if dof then
				dof:Destroy()
			end
			return
		end
		if not cc then
			cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "TW_KillCamGrade"
			cc.Parent = Lighting
		end
		cc.Contrast, cc.Saturation = 0.12, on == "freeze" and -0.55 or -0.12
		if GraphicsController.tier() == "high" and not Device.isTouch() then
			if not dof then
				dof = Instance.new("DepthOfFieldEffect")
				dof.Name = "TW_KillCamDof"
				dof.NearIntensity = 0.3
				dof.FarIntensity = 0.4
				dof.Parent = Lighting
			end
			dof.FocusDistance = focus or 10
			dof.InFocusRadius = math.max(4, (focus or 10) * 0.6)
		end
	end)
end

-- The shots -------------------------------------------------------------------------------------------------------
-- where the camera can be: from what it looks at out toward pos, stopping short of a wall in between (the effects,
-- the arrows and the bodies don't count)
local function clear(from, pos)
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip = {}
		for _, name in { "Effects", "Arrows", "Looks", "BlastFx", "Bots" } do
			local f = workspace:FindFirstChild(name)
			if f then
				table.insert(skip, f)
			end
		end
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(skip, p.Character)
			end
		end
		params.FilterDescendantsInstances = skip
		return workspace:Raycast(from, pos - from, params)
	end)
	if ok and hit then
		local back = (pos - from).Unit
		return hit.Position - back * 0.8
	end
	return pos
end

local function frame(camera, pos, look, fov, roll)
	if (look - pos).Magnitude < 0.01 then
		look = pos + Vector3.new(0, 0, -1)
	end
	camera.CFrame = CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, roll or 0)
	camera.FieldOfView = fov
	cam.lastPos, cam.lastLook = pos, look
end

-- the arrow's replay: the bow at O, the arc (velocity V) up to t = T where it struck at I
local function arrowShot(camera, t)
	local c = cam
	local O, V, T, I = c.origin, c.velocity, c.flight, c.impact
	local side = c.side
	if t < INTRO then
		-- cut to the killer: in front of them and off to the side, pushing in on the bow
		local u = smoother(t / INTRO)
		local pos = O + c.dir * lerp(11, 8.5, u) + side * lerp(4.5, 3.6, u) + UP * 1.2
		frame(camera, clear(O, pos), O - UP * 0.9, lerp(50, 44, u), math.rad(-4))
		c.stage = "intro"
		return
	end
	t -= INTRO
	if t < c.dur then
		local u = t / c.dur
		if not c.arrow then
			c.arrow = ArrowController.replay(O, V, c.team, c.trail)
			AudioController.play("release", 0.8)
		end
		-- slow motion that slows further as it closes in
		local s = 1 - (1 - u) ^ 2.2
		local at = s * T
		ArrowController.at(c.arrow, at)
		local P = Formulas.arrowAt(O, V, at)
		local v = Formulas.arrowVelocity(V, at)
		local fwd = v.Magnitude > 0.01 and v.Unit or c.dir
		local right = fwd:Cross(UP)
		right = right.Magnitude > 0.01 and right.Unit or side
		local up = right:Cross(fwd).Unit
		-- riding beside it, swinging round it from one side over the top, closing in
		local a = math.rad(lerp(-25, 55, smoother(u)))
		local r = lerp(3.6, 5.5, u)
		local pos = P + (right * math.cos(a) + up * math.sin(a) * 0.7) * r - fwd * lerp(2.2, 4.5, u)
		local look = P + fwd * lerp(4, 7, u)
		if u > 0.55 then
			-- (closing in: the camera settles beside you, the arrow flies into the frame)
			local k = smoother((u - 0.55) / 0.45)
			pos = pos:Lerp(c.closePos, k)
			look = look:Lerp(I, k * 0.85)
		end
		-- (out of the intro's shot smoothly)
		local b = smoother(t / 0.28)
		if b < 1 and c.lastPos then
			pos = c.introPos:Lerp(pos, b)
			look = c.introLook:Lerp(look, b)
		end
		frame(camera, pos, look, lerp(58, 50, u), math.sin(u * math.pi) * math.rad(7))
		grade(true, (P - pos).Magnitude)
		c.stage = "flight"
		return
	end
	t -= c.dur
	if not c.struck then
		c.struck = true
		-- the impact: you shatter, everything freezes for a beat in a white flash
		ArrowController.stop(c.arrow, nil) -- (no burst of its own: you shattering is the impact)
		Effects.timeScale = 0.04
		local parts = c.mannequin and c.mannequin:GetChildren() or {}
		local dir = (Formulas.arrowVelocity(V, T)).Unit
		local burst = { pos = c.stand, dir = dir, team = c.myTeam, parts = parts, power = 1.2, scale = 1.3 }
		burst.quiet = true -- (the screen's own flash does the glow; in slow motion a ball of light would hang there)
		Effects.shatter(burst)
		if c.mannequin then
			c.mannequin:Destroy()
			c.mannequin = nil
		end
		CameraController.shake(0.35, 0.25)
		AudioController.play(c.k.head and "headshot" or "kill", 0.82)
		-- (a hard cut to the side: the whole burst in frame)
		local look = c.stand + UP * 0.3
		c.freezeFrom = clear(look, c.stand + c.side * 9.5 - c.dir * 3.5 + UP * 2)
		c.freezeLook = look
	end
	if t < FREEZE then
		local u = t / FREEZE
		refs.flash.BackgroundTransparency = 0.7 + 0.3 * smoother(u * 1.6)
		local pos = c.freezeFrom + (c.freezeLook - c.freezeFrom).Unit * 0.5 * u
		frame(camera, pos, c.freezeLook, 46 - 2 * u, 0)
		grade("freeze", (c.freezeLook - pos).Magnitude)
		c.stage = "freeze"
		return
	end
	t -= FREEZE
	-- the drift round the spot as the card comes in; the shards pick up into slow motion
	local u = clamp01(t / (CARD + FADE))
	Effects.timeScale = lerp(0.04, 0.45, smoother(t / CARD))
	local from = c.freezeFrom - c.stand
	local flat = Vector3.new(from.X, 0, from.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or c.dir
	local angle = math.rad(35) * smoother(u)
	local rot = CFrame.fromAxisAngle(UP, angle)
	local dist = lerp(math.max(6, from.Magnitude), 11, smoother(u))
	local pos = c.stand + rot * flat * dist + UP * lerp(math.max(1, from.Y), 3.5, smoother(u))
	frame(camera, clear(c.stand, pos), c.stand + UP * 0.5, lerp(44, 50, u), math.rad(-3) * u)
	grade(true, dist)
	c.stage = t < CARD and "card" or "fade"
	c.cardAt = c.cardAt or os.clock()
end

-- a blade's, a blast's, anything else's: an orbit round the killer (or the blast)
local function orbitShot(camera, t)
	local c = cam
	local u = clamp01(t / ORBIT)
	local e = smoother(u)
	local center = c.center
	local a = c.yaw + math.rad(lerp(-40, 40, e))
	local flat = Vector3.new(math.cos(a), 0, math.sin(a))
	local pos = center + flat * lerp(9, 6.5, e) + UP * lerp(3, 1.4, e)
	frame(camera, clear(center, pos), center + UP * 0.3, lerp(52, 44, e), math.rad(lerp(-5, 3, e)))
	grade(true, (center - pos).Magnitude)
	c.stage = t < ORBIT - FADE and "orbit" or "fade"
	if t >= 0.45 then
		c.cardAt = c.cardAt or os.clock()
	end
end

local function finish()
	local c = cam
	if not c then
		return
	end
	cam = nil
	if c.arrow then
		ArrowController.stop(c.arrow, nil)
	end
	if c.mannequin then
		c.mannequin:Destroy()
	end
	Effects.timeScale = 1
	grade(false)
	AudioController.muffle(false)
	Layout.cinema(false)
	refs.skip.Visible = false
	refs.flash.BackgroundTransparency = 1
	if c.aborted then
		-- (someone else has the camera now: hand nothing back, just clear the screen)
		refs.gui.Enabled = false
		outroAt = nil
		return
	end
	CameraController.release()
	outroAt = os.clock()
	refs.fade.BackgroundTransparency = 0
end

function KillCamController.skip()
	local c = cam
	if not c or os.clock() - c.t0 < SKIP_AFTER then
		return false
	end
	if not c.skipped then
		c.skipped = true
		c.endAt = math.min(c.endAt, os.clock() + 0.18)
		c.fadeFrom = os.clock()
	end
	return true
end

function KillCamController.play(k)
	if cam or type(k) ~= "table" or not k.killer or k.killer == player.UserId or blocked() then
		return false
	end
	local now = os.clock()
	local c = {
		k = k,
		t0 = now,
		team = k.killerTeam,
		myTeam = k.victimTeam or player:GetAttribute("Team"),
		stand = typeof(k.pos) == "Vector3" and k.pos or nil,
	}
	local info = type(k.cam) == "table" and k.cam or {}
	local arrow = typeof(info.origin) == "Vector3" and typeof(info.velocity) == "Vector3" and c.stand ~= nil
	if arrow then
		c.kind = "arrow"
		c.origin, c.velocity = info.origin, info.velocity
		c.flight = math.max(0.05, tonumber(info.t) or 0.3)
		c.impact = typeof(info.impact) == "Vector3" and info.impact or Formulas.arrowAt(c.origin, c.velocity, c.flight)
		c.dur = math.clamp(c.flight * 3.5, FLIGHT_MIN, FLIGHT_MAX)
		local d = c.impact - c.origin
		d = Vector3.new(d.X, 0, d.Z)
		c.dir = d.Magnitude > 0.01 and d.Unit or Vector3.new(1, 0, 0)
		c.side = c.dir:Cross(UP).Unit
		c.total = INTRO + c.dur + FREEZE + CARD + FADE
		-- a stand-in of you where you stood, facing the bow
		local face = Vector3.new(c.origin.X, c.stand.Y, c.origin.Z)
		if (face - c.stand).Magnitude < 0.1 then
			face = c.stand - c.dir
		end
		c.mannequin = Effects.mannequin(CFrame.lookAt(c.stand, face), c.myTeam)
		-- (where the flight's camera settles: beside and a little behind you, the arrow coming in)
		c.closePos = clear(c.stand, c.stand + c.side * 8.5 - c.dir * 7 + UP * 2.2)
		c.introPos = c.origin + c.dir * 8.5 + c.side * 3.6 + UP * 1.2
		c.introLook = c.origin - UP * 0.9
		c.trail = trails[k.killer] -- (what they wear: their arrows said)
	else
		local center = typeof(k.killerPos) == "Vector3" and k.killerPos
			or (typeof(info.impact) == "Vector3" and info.impact)
			or c.stand
		if not center then
			return false
		end
		c.kind = "orbit"
		c.center = center + UP * 1.2
		local from = c.stand and (c.stand - center) or Vector3.new(1, 0, 0)
		c.yaw = math.atan2(from.Z, from.X)
		c.total = ORBIT
	end
	c.endAt = now + c.total
	cam = c
	outroAt = nil
	setCard(k)
	refs.card.Position = UDim2.new(0, -520, 0.86, 0)
	refs.flash.BackgroundTransparency = 1
	refs.fade.BackgroundTransparency = 1
	refs.gui.Enabled = true
	Layout.cinema(true)
	AudioController.muffle(true)
	AudioController.duck(0.35, c.total)
	CameraController.takeover(function(camera)
		if cam ~= c then
			return
		end
		c.driven = os.clock()
		local t = os.clock() - c.t0
		if c.kind == "arrow" then
			arrowShot(camera, t)
		else
			orbitShot(camera, t)
		end
	end)
	return true
end

function KillCamController.active()
	return cam ~= nil or outroAt ~= nil
end

function KillCamController.stage()
	return cam and cam.stage or nil
end

-- the overlay each frame: the bars, the card, the fades; and the checks that end it
local function step()
	local t = os.clock()
	local c = cam
	if c then
		-- an admin started spectating, or another cinematic took the camera: stop at once
		if SpectateController.active() or (c.driven and t - c.driven > 0.3) then
			c.aborted = true
			finish()
			return
		end
		local age = t - c.t0
		local bars = smoother(age / 0.35) * 0.12
		refs.barTop.Size = UDim2.new(1, 0, bars, 0)
		refs.barBottom.Size = UDim2.new(1, 0, bars, 0)
		refs.dot.BackgroundTransparency = (math.floor(age * 2.5) % 2 == 0) and 0 or 0.7
		refs.skip.Visible = age >= SKIP_AFTER
		-- (the cut to the killer: a quick white pop as it starts)
		if age < 0.18 and not c.struck then
			refs.flash.BackgroundTransparency = 0.4 + 0.6 * smoother(age / 0.18)
		end
		if c.cardAt then
			local k = smoother((t - c.cardAt) / 0.32)
			-- (in from the left with a little overshoot)
			local x = -520 + (548 + 14 * math.sin(k * math.pi)) * k
			refs.card.Position = UDim2.new(0, x, 0.86, 0)
		end
		-- the fade to white, then the camera comes home
		local fadeStart = c.skipped and c.fadeFrom or (c.endAt - FADE)
		if t >= fadeStart then
			local span = math.max(0.05, c.endAt - fadeStart)
			refs.fade.BackgroundTransparency = 1 - smoother((t - fadeStart) / span)
		end
		if t >= c.endAt then
			finish()
		end
		return
	end
	if outroAt then
		local k = (t - outroAt) / OUTRO
		local e = smoother(k)
		refs.fade.BackgroundTransparency = e
		refs.barTop.Size = UDim2.new(1, 0, 0.12 * (1 - e), 0)
		refs.barBottom.Size = UDim2.new(1, 0, 0.12 * (1 - e), 0)
		refs.card.Position = UDim2.new(0, 28 - 560 * e, 0.86, 0)
		if k >= 1 then
			outroAt = nil
			refs.gui.Enabled = false
		end
	end
end

function KillCamController:init()
	build()
	Net.listen("Arrow", function(a)
		if type(a) == "table" and a.by then
			trails[a.by] = a.trail
		end
	end)
	Net.listen("Kill", function(k)
		if type(k) == "table" and k.victim == player.UserId then
			KillCamController.play(k)
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if not cam then
			return
		end
		local kc, it = input.KeyCode, input.UserInputType
		if kc == Enum.KeyCode.Space or it == Enum.UserInputType.MouseButton1 or it == Enum.UserInputType.Touch then
			KillCamController.skip()
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return KillCamController
