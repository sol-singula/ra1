--[[
How the forest's monsters look and move (master plan §10: every monster readable at a glance, cool not gross, each
with its own silhouette; §13: a few great animations beat many okay ones). Plain parts, so the same rigs serve:
  * the client (MonsterController draws every monster from the server's snapshot and poses it every frame), and
  * the render tools (the gameplay shots and the store art).

  Rigs.build(kind, opts, parent) -> rig     opts = { elite = bool }
  Rigs.pose(rig, root, p) -> parts, cframes  root: a CFrame on the ground under the feet, facing -Z
      p = { t = clock, walk = phase, stride = 0..1, state = MonsterService state, tell = tell kind,
            f = 0..1 through the state, hit = 0..1 (a flinch), fall = 0..1 (going down) }
  Rigs.place(rig, root, p)                   pose right away (the render tools)
  Rigs.HEIGHT[kind]                          studs to the top of the head (health bars, names, speech)

The cast:
  kermy       six foot seven of swamp-green trouble in a purple 67 jersey that's too small (his belly shows). The
              tell: SIX... SEVEN!, his forearms out, palms up, going up and down. Then the lunge.
  snapcap     a hopping toadstool with far too many teeth
  grinwolf    a blue-grey wolf with a huge silly grin and eyes that flash red before it darts in
  pelter      a squirrel-goblin in a pinecone helmet, a pinecone always in hand
  stumpy      a walking tree stump with angry amber eyes, branch arms and root feet
  mimic       a crate that isn't: teeth round the lid, a tongue, four little legs
  mega_kermy  Kermy the size of a house, spikes on his head, a glowing 67 on his back (his weak spot)
]]
local Kit = require(script.Parent.Kit)

local Rigs = {}

local C, M, rgb = Kit.C, Kit.M, Kit.rgb
local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local rad, sin, cos, abs, clamp = math.rad, math.sin, math.cos, math.abs, math.clamp

local GOLD = rgb(255, 204, 64)
local GOLD_DARK = rgb(214, 150, 34)

Rigs.HEIGHT = { kermy = 7.8, snapcap = 2.9, grinwolf = 3.2, pelter = 3.6, stumpy = 4.8, mimic = 2.5, mega_kermy = 33 }
Rigs.SCALE = { mega_kermy = 4.2 }

-- Building blocks --------------------------------------------------------------------------------------------------------
local function newRig(kind, scale, parent)
	local model = Instance.new("Model")
	model.Name = kind
	return { kind = kind, scale = scale, model = model, bones = {}, parts = {}, parent = parent }
end

-- One part of a rig (sizes in the rig's own units: its scale applies). shape: "Ball" | "Cylinder" | "Ellipsoid" | "Wedge"
local function mk(rig, name, size, color, material, shape, extra)
	local props = {
		Name = name,
		Size = size * rig.scale,
		Color = color,
		Material = material or M.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Parent = rig.model,
	}
	if shape == "Wedge" then
		props.ClassName = "WedgePart"
	end
	for k, v in extra or {} do
		props[k] = v
	end
	local p = Kit.part(props)
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "Ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	return p
end

local function bone(rig, name, size, color, material, shape, extra)
	local p = mk(rig, name, size, color, material, shape, extra)
	rig.bones[name] = p
	return p
end

-- A piece that moves with a bone, at an offset in the bone's frame (rig units).
local function add(rig, boneName, name, offset, size, color, material, shape, extra)
	local p = mk(rig, name, size, color, material, shape, extra)
	local o = CF(offset.Position * rig.scale) * (offset - offset.Position)
	table.insert(rig.parts, { part = p, bone = boneName, offset = o })
	return p
end

-- A pair of pieces mirrored left/right (x and the angles are the right one's).
local function pair(rig, boneName, name, x, y, z, size, color, material, shape, rx, ry, rz)
	rx, ry, rz = rx or 0, ry or 0, rz or 0
	local r = add(rig, boneName, name .. "R", CF(x, y, z) * ANG(rx, ry, rz), size, color, material, shape)
	local l = add(rig, boneName, name .. "L", CF(-x, y, z) * ANG(rx, -ry, -rz), size, color, material, shape)
	return r, l
end

local function glowUp(rig, onBone, color, range)
	local b = rig.bones[onBone]
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 12
	light.Brightness = 1.4
	light.Parent = b
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Rate = 6
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.25)
	e.Color = ColorSequence.new(color)
	e.Parent = b
end

-- Kermy and Mega Kermy -----------------------------------------------------------------------------------------------------
local BUILD, POSE = {}, {}

local function buildKermy(rig, mega)
	local skin, dark = C.kermy, C.kermyDark
	local belly = rgb(200, 230, 128)
	local jersey, trim = C.jersey, C.jerseyTrim
	local shorts = rgb(74, 42, 134)
	local eye, pupil, mouth = rgb(255, 250, 222), C.black, rgb(74, 26, 40)
	-- the skeleton
	bone(rig, "Hips", V3(1.75, 0.95, 1.2), shorts, M.Fabric)
	local torso = bone(rig, "Torso", V3(1.95, 1.95, 1.25), jersey, M.Fabric, nil, { CastShadow = true })
	bone(rig, "Head", V3(2.25, 1.55, 1.95), skin, M.SmoothPlastic, "Ellipsoid", { CastShadow = true })
	for _, side in { "L", "R" } do
		bone(rig, "Upper" .. side, V3(0.56, 1.62, 0.56), skin, nil, "Ellipsoid")
		bone(rig, "Lower" .. side, V3(0.5, 1.6, 0.5), skin, nil, "Ellipsoid")
		bone(rig, "Leg" .. side, V3(0.62, 2.85, 0.62), skin, nil, "Ellipsoid", { CastShadow = true })
	end
	-- the jersey: too small, so his belly shows; gold trim, 67 on the back
	add(rig, "Torso", "Belly", CF(0, -1.12, -0.04), V3(1.7, 0.62, 1.12), belly, nil, "Ellipsoid")
	add(rig, "Torso", "Collar", CF(0, 0.94, -0.08), V3(1.25, 0.16, 1.05), trim, M.Fabric)
	add(rig, "Torso", "Hem", CF(0, -0.9, 0), V3(1.97, 0.16, 1.27), trim, M.Fabric)
	pair(rig, "Torso", "Sleeve", 0.98, 0.55, 0, V3(0.72, 0.6, 1.1), jersey, M.Fabric)
	pair(rig, "Torso", "SleeveTrim", 0.98, 0.26, 0, V3(0.74, 0.13, 1.12), trim, M.Fabric)
	pair(rig, "Torso", "SideStripe", 0.985, -0.3, 0, V3(0.04, 1.1, 0.5), trim, M.Fabric)
	Kit.text(torso, Enum.NormalId.Back, "67", { font = Enum.Font.LuckiestGuy, color = trim, ppu = 30, name = "Back67" })
	Kit.text(
		torso,
		Enum.NormalId.Front,
		"67",
		{ font = Enum.Font.LuckiestGuy, color = trim, ppu = 30, name = "Front67" }
	)
	add(rig, "Hips", "Belt", CF(0, 0.4, 0), V3(1.77, 0.14, 1.22), trim, M.Fabric)
	pair(rig, "Hips", "ShortLeg", 0.45, -0.45, 0, V3(0.8, 0.5, 1.05), shorts, M.Fabric)
	-- the head: a wide frog face, eyes on top, half-closed lids (up to something), a big grin
	pair(rig, "Head", "Eye", 0.52, 0.74, -0.42, V3(0.92, 0.92, 0.92), eye, nil, "Ball")
	pair(rig, "Head", "Lid", 0.52, 0.98, -0.4, V3(1.0, 0.5, 1.0), dark, nil, "Ellipsoid", rad(-14), 0, 0)
	pair(rig, "Head", "Pupil", 0.5, 0.74, -0.84, V3(0.4, 0.4, 0.4), pupil, nil, "Ball")
	pair(rig, "Head", "Shine", 0.42, 0.86, -0.98, V3(0.14, 0.14, 0.14), C.white, M.Neon, "Ball")
	add(rig, "Head", "Grin", CF(0, -0.22, -0.92), V3(1.0, 0.13, 0.12), mouth)
	pair(rig, "Head", "GrinSide", 0.66, -0.1, -0.8, V3(0.52, 0.13, 0.12), mouth, nil, nil, 0, rad(-38), rad(24))
	pair(rig, "Head", "Cheek", 0.78, -0.12, -0.62, V3(0.42, 0.3, 0.3), rgb(150, 210, 84), nil, "Ellipsoid")
	pair(rig, "Head", "Nostril", 0.2, 0.18, -0.95, V3(0.12, 0.12, 0.12), dark, nil, "Ball")
	-- hands: three round fingers; feet: big flippers
	for _, side in { "L", "R" } do
		local x = side == "L" and -1 or 1
		add(rig, "Lower" .. side, "Hand" .. side, CF(0, -0.92, -0.05), V3(0.8, 0.34, 0.9), skin, nil, "Ellipsoid")
		for k = -1, 1 do
			add(
				rig,
				"Lower" .. side,
				"Finger" .. side .. k,
				CF(k * 0.25 * x, -1.05, -0.42),
				V3(0.28, 0.28, 0.28),
				skin,
				nil,
				"Ball"
			)
		end
		add(rig, "Leg" .. side, "Foot" .. side, CF(0, -1.38, -0.48), V3(1.1, 0.34, 1.8), dark, nil, "Ellipsoid")
		for k = -1, 1 do
			add(
				rig,
				"Leg" .. side,
				"Toe" .. side .. k,
				CF(k * 0.36, -1.38, -1.3),
				V3(0.34, 0.3, 0.34),
				dark,
				nil,
				"Ball"
			)
		end
	end
	if mega then
		-- spikes, angry brows, a medal and the glowing 67 (the weak spot)
		for k = -2, 2 do
			add(
				rig,
				"Head",
				"Spike" .. k,
				CF(k * 0.36, 0.95 - abs(k) * 0.12, 0.32) * ANG(rad(-20), 0, rad(-k * 10)),
				V3(0.26, 0.6, 0.5),
				dark,
				nil,
				"Wedge"
			)
		end
		pair(rig, "Head", "Brow", 0.5, 1.2, -0.72, V3(0.7, 0.14, 0.14), dark, nil, nil, 0, 0, rad(-18))
		local plate = add(rig, "Torso", "Weak67", CF(0, 0.05, 0.64), V3(1.45, 1.35, 0.05), GOLD_DARK, M.Neon)
		Kit.text(
			plate,
			Enum.NormalId.Back,
			"67",
			{ font = Enum.Font.LuckiestGuy, color = rgb(120, 40, 20), ppu = 14, name = "Weak" }
		)
		rig.weak = plate
		local medal = add(
			rig,
			"Torso",
			"Medal",
			CF(0, 0.2, -0.66) * ANG(0, rad(90), 0),
			V3(0.12, 0.7, 0.7),
			GOLD,
			M.Metal,
			"Cylinder"
		)
		_ = medal
		add(rig, "Torso", "Chain", CF(0, 0.75, -0.62) * ANG(rad(-10), 0, 0), V3(1.1, 0.1, 0.12), GOLD, M.Metal)
	end
end

BUILD.kermy = function(rig)
	buildKermy(rig, false)
end
BUILD.mega_kermy = function(rig)
	buildKermy(rig, true)
end

-- Joint helpers: a limb hanging down from a joint swings forward with a positive angle; a body part standing up
-- from a joint leans forward with a negative one.
local function limb(joint, swing, roll, half)
	return joint * ANG(swing, 0, roll) * CF(0, -half, 0)
end

local function kermyPose(rig, root, p)
	local s = rig.scale
	local t = p.t or 0
	local st = p.state or "idle"
	local walk, stride = p.walk or 0, p.stride or 0
	local legL, legR = sin(walk) * 0.75 * stride, -sin(walk) * 0.75 * stride
	local bob = abs(cos(walk)) * 0.28 * stride
	local lean = -stride * 0.16 -- forward while running
	local roll = 0
	local headLean, headTurn = 0, 0
	local uL, uR = -legL * 0.8, -legR * 0.8
	local rollL, rollR = rad(-8), rad(8)
	local eL, eR = rad(22), rad(22)
	local body = root
	local sit = false
	local tell = p.tell
	if (st == "tell" and (tell == "sixseven" or tell == nil)) or st == "show" then
		-- SIX... SEVEN!: forearms out in front, palms up, going up and down
		local w = sin(t * 15)
		uL, uR = rad(16), rad(16)
		eL, eR = rad(76) + w * rad(30), rad(76) - w * rad(30)
		rollL, rollR = rad(-14), rad(14)
		bob = abs(sin(t * 7.5)) * 0.2
		headLean = rad(10) + sin(t * 7.5) * 0.06
		legL, legR = rad(6), rad(-6)
		lean = 0
	elseif st == "tell" and tell == "peekback" then
		-- the fake retreat's look back: a grin over the shoulder, hands rubbing
		headTurn = rad(70)
		uL, uR = rad(40), rad(40)
		eL, eR = rad(80) + sin(t * 20) * 0.2, rad(80) - sin(t * 20) * 0.2
		rollL, rollR = rad(20), rad(-20)
		lean = rad(-10)
	elseif st == "tell" then
		-- the big one's wind-ups (Mega Kermy): paw the ground and lean in
		lean = rad(-24)
		uL, uR = rad(-30), rad(-30)
		eL, eR = rad(40), rad(40)
		legL = sin(t * 12) * rad(18)
		headLean = rad(-12)
		if tell == "jump" then
			body = root * CF(0, -0.9 * s, 0)
			legL, legR = rad(55), rad(55)
			lean = rad(-30)
			uL, uR = rad(-60), rad(-60)
		elseif tell == "grab" then
			uR = rad(100)
			rollR = rad(5)
			eR = rad(5)
		elseif tell == "stomp" then
			legR = rad(50)
			body = root * CF(0, 0.4 * s, 0)
		end
	elseif st == "attack" then
		-- the lunge: flat out, arms first
		lean = rad(-58)
		uL, uR = rad(168), rad(168)
		eL, eR = rad(6), rad(6)
		rollL, rollR = rad(-6), rad(6)
		legL, legR = rad(-48), rad(28)
		body = root * CF(0, 0.5 * s, 0)
	elseif st == "charge" then
		lean = rad(-34)
		uL, uR = rad(-55) + legL * 0.3, rad(-55) + legR * 0.3
		eL, eR = rad(30), rad(30)
	elseif st == "faceplant" then
		if rig.kind == "mega_kermy" then
			-- stuck face-first in an Ancient Pine: arms flailing, dizzy
			lean = rad(-18)
			uL = rad(-40) + sin(t * 9) * 0.5
			uR = rad(-40) - sin(t * 9) * 0.5
			rollL, rollR = rad(-55), rad(55)
			headTurn = sin(t * 4) * 0.35
			headLean = rad(-20)
		else
			-- flat on his face, arms out, legs twitching
			body = root * CF(0, 0.62 * s, 0) * ANG(rad(-86), 0, 0) * CF(0, -0.62 * s, 0)
			uL, uR = rad(150), rad(150)
			rollL, rollR = rad(-60), rad(60)
			eL, eR = rad(10), rad(10)
			legL, legR = rad(-20) + sin(t * 10) * 0.12, rad(-10)
			headTurn = sin(t * 3) * 0.2
		end
	elseif st == "sleep" then
		-- on his back, hands on his tummy, snoring
		local breathe = sin(t * 1.6) * 0.04
		body = root * CF(0, 0.62 * s, 0) * ANG(rad(84) + breathe, 0, 0) * CF(0, -0.62 * s, 0)
		uL, uR = rad(35), rad(35)
		eL, eR = rad(100), rad(100)
		rollL, rollR = rad(22), rad(-22)
		legL, legR = rad(14), rad(-6)
		headTurn = rad(25)
	elseif st == "eat" then
		sit = true
		uL, uR = rad(36), rad(36)
		eL, eR = rad(118) + sin(t * 11) * 0.25, rad(118) - sin(t * 11) * 0.25
		rollL, rollR = rad(18), rad(-18)
		headLean = rad(8)
	elseif st == "tired" or st == "ko" then
		-- sitting down, panting (Mega Kermy's breather), or knocked out
		sit = true
		uL, uR = rad(8), rad(8)
		eL, eR = rad(15), rad(15)
		rollL, rollR = rad(-30), rad(30)
		lean = rad(-8) + sin(t * 6) * 0.05
		headLean = st == "ko" and rad(30) or rad(-10) + sin(t * 6) * 0.06
		headTurn = st == "ko" and sin(t * 2) * 0.3 or 0
	elseif st == "gloat" then
		uL, uR = rad(165), rad(165)
		rollL, rollR = rad(-28), rad(28)
		eL, eR = rad(10), rad(10)
		bob = abs(sin(t * 9)) * 0.35
		headLean = rad(18) + sin(t * 9) * 0.1
	elseif st == "flee" then
		uL, uR = rad(150) + sin(t * 18) * 0.4, rad(150) - sin(t * 18) * 0.4
		rollL, rollR = rad(-30), rad(30)
		eL, eR = rad(30), rad(30)
	elseif st == "stagger" or st == "startled" or st == "wake" then
		lean = rad(16) + sin(t * 14) * 0.06
		uL, uR = rad(30), rad(30)
		rollL, rollR = rad(-70), rad(70)
		eL, eR = rad(40), rad(40)
		headLean = rad(14)
	elseif st == "recover" then
		lean = rad(-32)
		uL, uR = rad(28), rad(28)
		eL, eR = rad(20), rad(20)
		headLean = rad(-10)
	elseif st == "peek" then
		roll = rad(-22)
		uR = rad(150)
		rollR = rad(30)
		eR = rad(60) + sin(t * 10) * 0.3
		headTurn = rad(-15)
	elseif st == "smash" then
		local k = sin(t * 9)
		legL, legR = k > 0 and rad(60) * k or 0, k < 0 and rad(-60) * k or 0
		uL, uR = rad(60), rad(60)
		rollL, rollR = rad(-40), rad(40)
		eL, eR = rad(70), rad(70)
	elseif st == "jump" then
		legL, legR = rad(30), rad(-30)
		uL, uR = rad(170), rad(170)
		rollL, rollR = rad(-20), rad(20)
		lean = 0
	elseif st == "grab" then
		uR = rad(95)
		eR = rad(-5)
		lean = rad(-20)
	end
	if sit then
		body = root * CF(0, -2.4 * s, 0)
		legL, legR = rad(84), rad(80)
	end
	local hit = p.hit or 0
	lean += hit * rad(16)
	local fall = p.fall or 0
	if fall > 0 then
		body = body * CF(0, 0.62 * s * fall, 0) * ANG(rad(80) * fall, 0, 0) * CF(0, -0.62 * s * fall, 0)
	end
	body = body * CF(0, bob * s, 0) * ANG(0, 0, roll)
	local out = {}
	local hipY = 2.9 * s
	local hip = body * CF(0, hipY, 0)
	out.LegL = limb(hip * CF(-0.48 * s, 0, 0), legL, rad(-3), 1.4 * s)
	out.LegR = limb(hip * CF(0.48 * s, 0, 0), legR, rad(3), 1.4 * s)
	out.Hips = hip * CF(0, 0.32 * s, 0)
	local waist = hip * CF(0, 0.72 * s, 0) * ANG(lean, 0, 0)
	local torso = waist * CF(0, 0.98 * s, 0)
	out.Torso = torso
	out.Head = torso * CF(0, 0.98 * s, 0) * ANG(headLean, headTurn, 0) * CF(0, 0.8 * s, -0.08 * s)
	local function arm(side, u, r, e)
		local x = side == "L" and -1.2 or 1.2
		local shoulder = torso * CF(x * s, 0.66 * s, 0)
		out["Upper" .. side] = limb(shoulder, u, r, 0.76 * s)
		local elbow = shoulder * ANG(u, 0, r) * CF(0, -1.5 * s, 0)
		out["Lower" .. side] = limb(elbow, e, 0, 0.76 * s)
	end
	arm("L", uL, rollL, eL)
	arm("R", uR, rollR, eR)
	return out
end
POSE.kermy = kermyPose
POSE.mega_kermy = kermyPose

-- Snapcap -------------------------------------------------------------------------------------------------------------------
BUILD.snapcap = function(rig, opts)
	local cap = opts.elite and GOLD or C.mushroom
	local stalk = rgb(246, 234, 210)
	bone(rig, "Stalk", V3(1.55, 1.55, 1.45), stalk, nil, "Ellipsoid", { CastShadow = true })
	bone(rig, "Cap", V3(2.8, 1.5, 2.8), cap, nil, "Ellipsoid", { CastShadow = true })
	bone(rig, "FootL", V3(0.62, 0.36, 0.85), C.mushroomBrown, nil, "Ellipsoid")
	bone(rig, "FootR", V3(0.62, 0.36, 0.85), C.mushroomBrown, nil, "Ellipsoid")
	add(rig, "Cap", "Gills", CF(0, -0.5, 0), V3(2.55, 0.34, 2.55), rgb(236, 210, 176), nil, "Ellipsoid")
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.4
		local cx, cz = cos(a) * 0.86, sin(a) * 0.86
		add(
			rig,
			"Cap",
			"Spot" .. k,
			CF(cx, 0.42, cz) * ANG(-sin(a) * 0.55 * -1, 0, -cos(a) * 0.55),
			V3(0.6, 0.14, 0.6),
			C.white,
			nil,
			"Ellipsoid"
		)
	end
	add(rig, "Cap", "SpotTop", CF(0, 0.74, 0), V3(0.7, 0.12, 0.7), C.white, nil, "Ellipsoid")
	-- a big toothy mouth and beady eyes
	add(rig, "Stalk", "Mouth", CF(0, -0.08, -0.6), V3(1.05, 0.48, 0.3), rgb(96, 22, 34), nil, "Ellipsoid")
	for k = -2, 2 do
		add(
			rig,
			"Stalk",
			"ToothTop" .. k,
			CF(k * 0.19, 0.08, -0.7) * ANG(rad(180), 0, 0),
			V3(0.15, 0.2, 0.08),
			C.white,
			nil,
			"Wedge"
		)
	end
	for k = -1, 1 do
		add(
			rig,
			"Stalk",
			"ToothLow" .. k,
			CF(k * 0.22 + 0.1, -0.24, -0.68),
			V3(0.15, 0.18, 0.08),
			C.white,
			nil,
			"Wedge"
		)
	end
	pair(rig, "Stalk", "Eye", 0.32, 0.42, -0.58, V3(0.3, 0.38, 0.2), C.black, nil, "Ellipsoid")
	pair(rig, "Stalk", "Shine", 0.28, 0.5, -0.66, V3(0.1, 0.1, 0.1), C.white, M.Neon, "Ball")
	pair(rig, "Stalk", "Brow", 0.32, 0.66, -0.55, V3(0.36, 0.08, 0.08), rgb(150, 100, 70), nil, nil, 0, 0, rad(-22))
	if opts.elite then
		glowUp(rig, "Cap", GOLD, 10)
	end
end

POSE.snapcap = function(rig, root, p)
	local s = rig.scale
	local t = p.t or 0
	local st = p.state or "idle"
	local walk, stride = p.walk or 0, p.stride or 0
	local hop = abs(sin(walk * 0.8)) * 0.85 * stride
	local squash = 0
	local tilt = 0
	local feet = sin(walk * 1.6) * 0.25 * stride
	if st == "tell" then
		squash = 0.38 + sin(t * 30) * 0.04 -- crouched, quivering
		tilt = rad(12)
	elseif st == "attack" then
		hop = sin(clamp(p.f or 0.5, 0, 1) * math.pi) * 2.2
		tilt = rad(-30)
	elseif st == "stagger" or st == "rooted" then
		tilt = sin(t * 16) * 0.25
	elseif st == "recover" then
		squash = 0.15
	end
	if hop < 0.05 and stride > 0 then
		squash = math.max(squash, 0.12)
	end
	local fall = p.fall or 0
	local body = root * CF(0, (hop - squash * 0.5) * s, 0)
	if fall > 0 then
		body = body * ANG(0, 0, rad(90) * fall) * CF(0, -0.4 * s * fall, 0)
	end
	body = body * ANG(-tilt + (p.hit or 0) * rad(20), 0, 0)
	local out = {}
	out.Stalk = body * CF(0, (0.95 - squash * 0.5) * s, 0)
	out.Cap = body * CF(0, (1.95 - squash) * s, 0.05 * s) * ANG(tilt * 0.4, 0, 0)
	out.FootL = root * CF(-0.42 * s, 0.18 * s + hop * s * 0.6, (-0.1 + feet) * s)
	out.FootR = root * CF(0.42 * s, 0.18 * s + hop * s * 0.6, (-0.1 - feet) * s)
	return out
end

-- Grinwolf ---------------------------------------------------------------------------------------------------------------------
BUILD.grinwolf = function(rig, opts)
	local fur = opts.elite and GOLD or rgb(122, 130, 156)
	local dark = opts.elite and GOLD_DARK or rgb(78, 84, 110)
	local light = opts.elite and rgb(255, 236, 160) or rgb(206, 210, 224)
	bone(rig, "Body", V3(1.75, 1.6, 3.1), fur, M.Fabric, "Ellipsoid", { CastShadow = true })
	bone(rig, "Head", V3(1.5, 1.3, 1.4), fur, M.Fabric, "Ellipsoid", { CastShadow = true })
	bone(rig, "Tail", V3(0.62, 0.62, 1.9), fur, M.Fabric, "Ellipsoid")
	for _, leg in { "FL", "FR", "BL", "BR" } do
		bone(rig, "Leg" .. leg, V3(0.5, 1.65, 0.55), fur, M.Fabric, "Ellipsoid")
		add(rig, "Leg" .. leg, "Paw" .. leg, CF(0, -0.78, -0.12), V3(0.6, 0.3, 0.75), dark, M.Fabric, "Ellipsoid")
	end
	add(rig, "Body", "Ruff", CF(0, 0.22, -1.08), V3(1.95, 1.75, 1.3), light, M.Fabric, "Ellipsoid")
	add(rig, "Body", "Back", CF(0, 0.55, 0.2), V3(1.2, 0.6, 2.5), dark, M.Fabric, "Ellipsoid")
	add(rig, "Body", "Belly", CF(0, -0.48, 0.1), V3(1.3, 0.75, 2.3), light, M.Fabric, "Ellipsoid")
	add(rig, "Tail", "TailTip", CF(0, 0, 0.82), V3(0.5, 0.5, 0.6), light, M.Fabric, "Ellipsoid")
	-- the face: a long snout, a HUGE grin, glowing eyes (red when it's about to dart)
	add(rig, "Head", "Snout", CF(0, -0.2, -0.86), V3(0.82, 0.62, 1.0), light, M.Fabric, "Ellipsoid")
	add(rig, "Head", "Nose", CF(0, -0.02, -1.33), V3(0.34, 0.28, 0.28), C.black, nil, "Ellipsoid")
	add(rig, "Head", "Grin", CF(0, -0.36, -0.72), V3(1.22, 0.24, 0.66), C.white, nil, "Ellipsoid")
	add(rig, "Head", "Lip", CF(0, -0.27, -0.74), V3(1.26, 0.07, 0.66), rgb(40, 34, 50))
	for k = -2, 2 do
		add(
			rig,
			"Head",
			"Fang" .. k,
			CF(k * 0.2, -0.43, -1.0 + abs(k) * 0.08) * ANG(rad(180), 0, 0),
			V3(0.12, 0.2, 0.08),
			C.white,
			nil,
			"Wedge"
		)
	end
	local eyeR, eyeL =
		pair(rig, "Head", "Eye", 0.34, 0.24, -0.55, V3(0.32, 0.26, 0.2), rgb(255, 218, 70), M.Neon, "Ellipsoid")
	rig.eyes = { eyeR, eyeL }
	pair(rig, "Head", "Slit", 0.34, 0.24, -0.65, V3(0.06, 0.22, 0.04), C.black)
	pair(rig, "Head", "Brow", 0.34, 0.46, -0.52, V3(0.44, 0.1, 0.1), dark, nil, nil, 0, 0, rad(-18))
	pair(rig, "Head", "Ear", 0.42, 0.66, 0.05, V3(0.2, 0.62, 0.5), dark, M.Fabric, "Wedge", 0, rad(180), rad(-12))
	pair(
		rig,
		"Head",
		"EarIn",
		0.42,
		0.62,
		-0.02,
		V3(0.08, 0.42, 0.3),
		rgb(236, 150, 170),
		nil,
		"Wedge",
		0,
		rad(180),
		rad(-12)
	)
	if opts.elite then
		glowUp(rig, "Body", GOLD, 14)
	end
end

POSE.grinwolf = function(rig, root, p)
	local s = rig.scale
	local t = p.t or 0
	local st = p.state or "idle"
	local walk, stride = p.walk or 0, p.stride or 0
	local swing = sin(walk) * 0.7 * stride
	local bob = abs(cos(walk)) * 0.22 * stride
	local crouch, pitch, headUp, tailUp = 0, 0, 0, rad(35)
	local fl, fr, bl, br = swing, -swing, -swing, swing
	local stretch = false
	if st == "tell" then
		local f = p.f or 0.5
		if f < 0.45 then
			headUp = rad(50) -- the howl
			pitch = rad(-8)
		else
			crouch = 0.5 -- low, ready
			headUp = rad(-10)
			tailUp = rad(0)
			fl, fr, bl, br = rad(20), rad(20), rad(-15), rad(-15)
		end
	elseif st == "attack" then
		stretch = true
		fl, fr, bl, br = rad(55), rad(48), rad(-55), rad(-48)
		pitch = rad(-6)
		tailUp = rad(5)
		headUp = rad(10)
	elseif st == "recover" then
		headUp = rad(-12) + sin(t * 10) * 0.05
		tailUp = rad(20)
	elseif st == "stagger" or st == "rooted" then
		pitch = sin(t * 15) * 0.15
		tailUp = rad(-10)
	elseif st == "flee" then
		tailUp = rad(-25)
		headUp = rad(-5)
	elseif st == "circle" then
		headUp = rad(-6)
	end
	local fall = p.fall or 0
	local body = root * CF(0, (bob - crouch) * s, 0)
	if fall > 0 then
		body = body * CF(0, -0.6 * s * fall, 0) * ANG(0, 0, rad(85) * fall)
	end
	body = body * ANG(pitch + (p.hit or 0) * rad(14), 0, 0)
	local out = {}
	local torso = body * CF(0, 1.95 * s, stretch and -0.3 * s or 0)
	out.Body = torso
	out.Head = torso * CF(0, 0.5 * s, -1.65 * s) * ANG(headUp, 0, 0) * CF(0, 0.15 * s, -0.25 * s)
	out.Tail = torso
		* CF(0, 0.45 * s, 1.45 * s)
		* ANG(tailUp + sin(t * 8) * 0.15 * (1 - stride * 0.5), sin(t * 6) * 0.25, 0)
		* CF(0, 0, 0.8 * s)
	local function leg(name, x, z, a)
		local hip = torso * CF(x * s, -0.35 * s, z * s)
		out["Leg" .. name] = limb(hip, a, 0, 0.82 * s)
	end
	leg("FL", -0.5, -0.95, fl)
	leg("FR", 0.5, -0.95, fr)
	leg("BL", -0.5, 0.95, bl)
	leg("BR", 0.5, 0.95, br)
	return out
end

-- Pinecone Pelter -------------------------------------------------------------------------------------------------------------------
BUILD.pelter = function(rig, opts)
	local fur = opts.elite and GOLD or rgb(204, 116, 50)
	local cream = rgb(250, 226, 186)
	local cone = rgb(126, 82, 44)
	local coneDark = rgb(88, 56, 30)
	bone(rig, "Body", V3(1.15, 1.35, 1.05), fur, M.Fabric, "Ellipsoid", { CastShadow = true })
	bone(rig, "Head", V3(1.2, 1.08, 1.1), fur, M.Fabric, "Ellipsoid", { CastShadow = true })
	bone(rig, "Tail", V3(0.8, 1.45, 0.75), fur, M.Fabric, "Ellipsoid")
	bone(rig, "ArmL", V3(0.32, 0.78, 0.32), fur, M.Fabric, "Ellipsoid")
	bone(rig, "ArmR", V3(0.32, 0.78, 0.32), fur, M.Fabric, "Ellipsoid")
	bone(rig, "LegL", V3(0.38, 0.7, 0.5), fur, M.Fabric, "Ellipsoid")
	bone(rig, "LegR", V3(0.38, 0.7, 0.5), fur, M.Fabric, "Ellipsoid")
	add(rig, "Body", "Belly", CF(0, -0.05, -0.32), V3(0.78, 1.0, 0.5), cream, M.Fabric, "Ellipsoid")
	-- the pinecone helmet
	add(rig, "Head", "Cone1", CF(0, 0.42, 0.04), V3(1.3, 0.52, 1.25), cone, M.Wood, "Ellipsoid")
	add(rig, "Head", "Band1", CF(0, 0.3, 0.04), V3(1.34, 0.12, 1.29), coneDark, M.Wood, "Ellipsoid")
	add(rig, "Head", "Cone2", CF(0, 0.76, 0.08), V3(0.98, 0.46, 0.95), cone, M.Wood, "Ellipsoid")
	add(rig, "Head", "Band2", CF(0, 0.64, 0.08), V3(1.0, 0.1, 0.98), coneDark, M.Wood, "Ellipsoid")
	add(rig, "Head", "Cone3", CF(0, 1.04, 0.1), V3(0.64, 0.42, 0.62), cone, M.Wood, "Ellipsoid")
	add(rig, "Head", "ConeTip", CF(0, 1.28, 0.12), V3(0.3, 0.32, 0.3), coneDark, M.Wood, "Ellipsoid")
	-- big eyes, buck teeth, a pink nose, tufted ears
	pair(rig, "Head", "Eye", 0.28, 0.04, -0.47, V3(0.34, 0.42, 0.22), C.black, nil, "Ellipsoid")
	pair(rig, "Head", "Shine", 0.24, 0.13, -0.57, V3(0.12, 0.12, 0.12), C.white, M.Neon, "Ball")
	pair(rig, "Head", "Tooth", 0.075, -0.36, -0.5, V3(0.13, 0.22, 0.06), C.white)
	add(rig, "Head", "Nose", CF(0, -0.14, -0.55), V3(0.18, 0.14, 0.12), rgb(236, 120, 140), nil, "Ellipsoid")
	add(rig, "Head", "Muzzle", CF(0, -0.24, -0.42), V3(0.6, 0.38, 0.32), cream, M.Fabric, "Ellipsoid")
	pair(rig, "Head", "Ear", 0.5, 0.18, 0.05, V3(0.28, 0.36, 0.14), fur, M.Fabric, "Ellipsoid", 0, 0, rad(-30))
	pair(rig, "Head", "Tuft", 0.6, 0.36, 0.05, V3(0.12, 0.24, 0.1), coneDark, M.Fabric, "Wedge", 0, 0, rad(-30))
	-- the bushy tail (curling forward at the top) and a pinecone in hand
	add(rig, "Tail", "Curl", CF(0, 0.75, -0.3), V3(0.95, 0.95, 0.85), fur, M.Fabric, "Ellipsoid")
	add(rig, "Tail", "CurlTip", CF(0, 0.95, -0.62), V3(0.55, 0.5, 0.5), cream, M.Fabric, "Ellipsoid")
	add(rig, "ArmR", "Pinecone", CF(0, -0.5, -0.12), V3(0.42, 0.58, 0.42), cone, M.Wood, "Ellipsoid")
	add(rig, "ArmR", "PineconeBand", CF(0, -0.5, -0.12), V3(0.46, 0.1, 0.46), coneDark, M.Wood, "Ellipsoid")
	add(rig, "LegL", "FootL", CF(0, -0.33, -0.18), V3(0.45, 0.2, 0.68), fur, M.Fabric, "Ellipsoid")
	add(rig, "LegR", "FootR", CF(0, -0.33, -0.18), V3(0.45, 0.2, 0.68), fur, M.Fabric, "Ellipsoid")
	if opts.elite then
		glowUp(rig, "Body", GOLD, 10)
	end
end

POSE.pelter = function(rig, root, p)
	local s = rig.scale
	local t = p.t or 0
	local st = p.state or "idle"
	local walk, stride = p.walk or 0, p.stride or 0
	local hop = abs(sin(walk)) * 0.45 * stride
	local legA = sin(walk * 2) * 0.5 * stride
	local lean, armR, armL, tailSway =
		-stride * 0.2, sin(walk) * 0.5 * stride, -sin(walk) * 0.5 * stride, sin(t * 3) * 0.12
	local crouch = 0
	if st == "tell" then
		armR = rad(-160) -- winding up behind its head
		lean = rad(14)
		armL = rad(40)
	elseif st == "attack" then
		armR = rad(110) -- the throw
		lean = rad(-18)
	elseif st == "guard" or st == "hide" or st == "idle" then
		crouch = 0.15
		tailSway = sin(t * 2) * 0.2
	elseif st == "stagger" or st == "rooted" then
		lean = sin(t * 14) * 0.2
	end
	local fall = p.fall or 0
	local body = root * CF(0, (hop - crouch) * s, 0)
	if fall > 0 then
		body = body * ANG(0, 0, rad(90) * fall) * CF(0, -0.4 * s * fall, 0)
	end
	local out = {}
	local hip = body * CF(0, 0.7 * s, 0)
	out.LegL = limb(hip * CF(-0.32 * s, 0, 0), legA, 0, 0.32 * s)
	out.LegR = limb(hip * CF(0.32 * s, 0, 0), -legA, 0, 0.32 * s)
	local torso = hip * ANG(lean + (p.hit or 0) * rad(18), 0, 0) * CF(0, 0.6 * s, 0)
	out.Body = torso
	out.Head = torso * CF(0, 0.95 * s, -0.05 * s) * ANG(-lean * 0.5, sin(t * 2.2) * 0.15, 0)
	out.ArmL = limb(torso * CF(-0.55 * s, 0.25 * s, -0.15 * s), armL, rad(-14), 0.36 * s)
	out.ArmR = limb(torso * CF(0.55 * s, 0.25 * s, -0.15 * s), armR, rad(14), 0.36 * s)
	out.Tail = torso * CF(0, -0.2 * s, 0.62 * s) * ANG(rad(18), 0, tailSway) * CF(0, 0.7 * s, 0.1 * s)
	return out
end

-- Stumpy ---------------------------------------------------------------------------------------------------------------------------------
BUILD.stumpy = function(rig, opts)
	local bark = opts.elite and GOLD or C.bark
	local barkDark = opts.elite and GOLD_DARK or C.barkDark
	local rings = rgb(220, 178, 120)
	local ringDark = rgb(176, 130, 82)
	local eyes = opts.elite and rgb(255, 255, 200) or rgb(255, 168, 40)
	bone(rig, "Trunk", V3(0.2, 0.2, 0.2), bark, M.Wood, nil, { Transparency = 1 })
	add(rig, "Trunk", "Wood", ANG(0, 0, rad(90)), V3(3.0, 2.95, 2.95), bark, M.Wood, "Cylinder", { CastShadow = true })
	add(rig, "Trunk", "Flare", CF(0, -1.25, 0) * ANG(0, 0, rad(90)), V3(0.6, 3.35, 3.35), barkDark, M.Wood, "Cylinder")
	add(rig, "Trunk", "Top", CF(0, 1.5, 0) * ANG(0, 0, rad(90)), V3(0.1, 2.75, 2.75), rings, M.Wood, "Cylinder")
	add(rig, "Trunk", "Ring2", CF(0, 1.52, 0) * ANG(0, 0, rad(90)), V3(0.1, 1.8, 1.8), ringDark, M.Wood, "Cylinder")
	add(rig, "Trunk", "Ring3", CF(0, 1.54, 0) * ANG(0, 0, rad(90)), V3(0.1, 1.0, 1.0), rings, M.Wood, "Cylinder")
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + 0.2
		add(
			rig,
			"Trunk",
			"Ridge" .. k,
			CF(cos(a) * 1.43, -0.05, sin(a) * 1.43) * ANG(0, -a, 0),
			V3(0.16, 2.7, 0.2),
			barkDark,
			M.Wood
		)
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.9
		add(
			rig,
			"Trunk",
			"Moss" .. k,
			CF(cos(a) * 1.25, 1.42, sin(a) * 1.25),
			V3(1.0, 0.32, 0.8),
			C.moss,
			M.Grass,
			"Ellipsoid"
		)
	end
	-- the sprout on top
	add(rig, "Trunk", "Sprout", CF(0.4, 1.95, 0.3) * ANG(0, 0, rad(-12)), V3(0.14, 0.9, 0.14), C.woodLight, M.Wood)
	add(rig, "Trunk", "Leaf1", CF(0.62, 2.35, 0.3) * ANG(0, 0, rad(-40)), V3(0.5, 0.12, 0.3), C.leaf, nil, "Ellipsoid")
	add(
		rig,
		"Trunk",
		"Leaf2",
		CF(0.28, 2.3, 0.28) * ANG(0, 0, rad(35)),
		V3(0.45, 0.12, 0.28),
		C.leafLight,
		nil,
		"Ellipsoid"
	)
	-- an angry face
	pair(rig, "Trunk", "Socket", 0.52, 0.42, -1.4, V3(0.62, 0.46, 0.3), rgb(40, 26, 18), nil, "Ellipsoid")
	pair(rig, "Trunk", "Eye", 0.52, 0.4, -1.52, V3(0.26, 0.24, 0.12), eyes, M.Neon, "Ellipsoid")
	pair(rig, "Trunk", "Brow", 0.52, 0.78, -1.48, V3(0.72, 0.18, 0.2), barkDark, M.Wood, nil, 0, 0, rad(-22))
	add(rig, "Trunk", "Mouth", CF(0, -0.38, -1.44), V3(1.3, 0.38, 0.26), rgb(40, 26, 18), nil, "Ellipsoid")
	for k = -1, 1 do
		add(
			rig,
			"Trunk",
			"Splinter" .. k,
			CF(k * 0.36, -0.28, -1.52) * ANG(rad(180), 0, 0),
			V3(0.16, 0.22, 0.1),
			rings,
			M.Wood,
			"Wedge"
		)
	end
	-- branch arms with twig fingers, root legs
	for _, side in { "L", "R" } do
		bone(rig, "Arm" .. side, V3(0.62, 2.5, 0.62), bark, M.Wood, nil, { CastShadow = true })
		local x = side == "L" and -1 or 1
		for k = -1, 1 do
			add(
				rig,
				"Arm" .. side,
				"Twig" .. side .. k,
				CF(k * 0.22 * x, -1.45, -0.05) * ANG(rad(k * 12), 0, rad(k * 25)),
				V3(0.16, 0.7, 0.16),
				C.woodDark,
				M.Wood
			)
		end
		add(
			rig,
			"Arm" .. side,
			"Tuft" .. side,
			CF(0.25 * x, 0.6, 0),
			V3(0.7, 0.45, 0.6),
			C.leafDark,
			M.Grass,
			"Ellipsoid"
		)
		bone(rig, "Leg" .. side, V3(0.85, 1.25, 0.95), barkDark, M.Wood)
		for k = -1, 1 do
			add(
				rig,
				"Leg" .. side,
				"Root" .. side .. k,
				CF(k * 0.32, -0.55, -0.52) * ANG(rad(-20), rad(k * 25), 0),
				V3(0.28, 0.3, 0.75),
				barkDark,
				M.Wood,
				"Wedge"
			)
		end
	end
	if opts.elite then
		glowUp(rig, "Trunk", GOLD, 16)
	end
end

POSE.stumpy = function(rig, root, p)
	local s = rig.scale
	local t = p.t or 0
	local st = p.state or "idle"
	local walk, stride = p.walk or 0, p.stride or 0
	local legA = sin(walk) * 0.45 * stride
	local sway = sin(walk) * 0.1 * stride
	local bob = abs(cos(walk)) * 0.3 * stride
	local armL, armR = -legA * 0.6, legA * 0.6
	local rollL, rollR = rad(-14), rad(14)
	local lean = 0
	if st == "tell" or st == "slam" then
		armL, armR = rad(172), rad(172) -- both arms up: the slam is coming
		rollL, rollR = rad(-12), rad(12)
		lean = rad(10) + sin(t * 20) * 0.02
	elseif st == "attack" then
		armL, armR = rad(55), rad(55) -- SLAM
		lean = rad(-24)
		bob = -0.2
	elseif st == "stagger" or st == "rooted" then
		lean = rad(16) + sin(t * 12) * 0.08
		armL, armR = rad(20), rad(20)
		rollL, rollR = rad(-60), rad(60)
	elseif st == "smash" then
		armL = rad(90) + sin(t * 8) * rad(60)
		armR = rad(90) - sin(t * 8) * rad(60)
		lean = rad(-10)
	elseif st == "recover" then
		lean = rad(-12)
		armL, armR = rad(10), rad(10)
	end
	local fall = p.fall or 0
	local body = root * CF(0, bob * s, 0)
	if fall > 0 then
		body = body * CF(0, 1.3 * s * fall, 0) * ANG(rad(85) * fall, 0, 0) * CF(0, -1.3 * s * fall, 0)
	end
	local out = {}
	out.LegL = root * CF(-0.75 * s, 0.6 * s, 0) * ANG(legA, 0, 0) * CF(0, 0, -legA * 0.4 * s)
	out.LegR = root * CF(0.75 * s, 0.6 * s, 0) * ANG(-legA, 0, 0) * CF(0, 0, legA * 0.4 * s)
	local trunk = body * CF(0, 2.65 * s, 0) * ANG(lean + (p.hit or 0) * rad(12), 0, sway)
	out.Trunk = trunk
	out.ArmL = limb(trunk * CF(-1.62 * s, 0.75 * s, 0), armL, rollL, 1.1 * s)
	out.ArmR = limb(trunk * CF(1.62 * s, 0.75 * s, 0), armR, rollR, 1.1 * s)
	return out
end

-- Mimic --------------------------------------------------------------------------------------------------------------------------------------
BUILD.mimic = function(rig, opts)
	local wood = opts.elite and GOLD or C.wood
	local plank = opts.elite and GOLD_DARK or C.woodDark
	bone(rig, "Box", V3(2.3, 1.3, 1.9), wood, M.Wood, nil, { CastShadow = true })
	bone(rig, "Lid", V3(2.42, 0.42, 2.02), wood, M.Wood, nil, { CastShadow = true })
	for _, leg in { "FL", "FR", "BL", "BR" } do
		bone(rig, "Leg" .. leg, V3(0.22, 0.7, 0.22), plank, M.Wood)
		add(rig, "Leg" .. leg, "Foot" .. leg, CF(0, -0.33, -0.1), V3(0.3, 0.14, 0.42), plank, M.Wood, "Ellipsoid")
	end
	for k = -1, 1 do
		add(rig, "Box", "PlankF" .. k, CF(0, k * 0.42, -0.955), V3(2.32, 0.07, 0.02), plank, M.Wood)
		add(rig, "Box", "PlankB" .. k, CF(0, k * 0.42, 0.955), V3(2.32, 0.07, 0.02), plank, M.Wood)
	end
	for _, c in { { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } } do
		add(rig, "Box", "Corner" .. c[1] .. c[2], CF(c[1] * 1.1, 0, c[2] * 0.9), V3(0.18, 1.34, 0.18), C.iron, M.Metal)
	end
	add(rig, "Box", "Inside", CF(0, 0.6, 0), V3(2.06, 0.08, 1.66), rgb(80, 16, 28))
	add(rig, "Box", "Tongue", CF(0, 0.66, -0.25), V3(0.95, 0.22, 1.15), rgb(236, 96, 128), nil, "Ellipsoid")
	pair(rig, "Box", "Eye", 0.42, 0.74, 0.42, V3(0.32, 0.32, 0.32), rgb(255, 230, 60), M.Neon, "Ball")
	for k = -2, 2 do
		add(rig, "Box", "Tooth" .. k, CF(k * 0.42, 0.78, -0.86), V3(0.22, 0.28, 0.1), C.white, nil, "Wedge")
		add(
			rig,
			"Lid",
			"LidTooth" .. k,
			CF(k * 0.42 + 0.2, -0.32, -0.9) * ANG(rad(180), 0, 0),
			V3(0.22, 0.26, 0.1),
			C.white,
			nil,
			"Wedge"
		)
	end
	add(rig, "Lid", "Clasp", CF(0, -0.05, -1.03), V3(0.42, 0.42, 0.06), C.gold, M.Metal)
	add(rig, "Lid", "LidPlank", CF(0, 0.215, 0), V3(2.44, 0.02, 0.1), plank, M.Wood)
	if opts.elite then
		glowUp(rig, "Box", GOLD, 10)
	end
end

POSE.mimic = function(rig, root, p)
	local s = rig.scale
	local t = p.t or 0
	local st = p.state or "idle"
	local walk, stride = p.walk or 0, p.stride or 0
	local scuttle = sin(walk * 2.2) * 0.5 * stride
	local bob = abs(sin(walk * 2.2)) * 0.18 * stride
	local open = rad(8) + sin(t * 3) * rad(4)
	local low = 0
	if st == "tell" then
		open = rad(72) -- wide open: the bite is coming
	elseif st == "attack" then
		open = rad(2)
	elseif st == "flee" then
		open = rad(14) + sin(t * 14) * rad(12)
	elseif st == "tired" then
		open = rad(28) + sin(t * 5) * rad(6)
		low = 0.35
	elseif st == "stagger" or st == "rooted" then
		open = rad(40)
	elseif st == "recover" then
		open = rad(22)
	end
	local fall = p.fall or 0
	local body = root * CF(0, (bob - low) * s, 0)
	if fall > 0 then
		body = body * ANG(0, 0, rad(100) * fall) * CF(0, -0.3 * s * fall, 0)
		open = rad(60) * fall
	end
	local out = {}
	local box = body * CF(0, 1.3 * s, 0) * ANG((p.hit or 0) * rad(12), 0, sin(walk * 2.2) * 0.05 * stride)
	out.Box = box
	out.Lid = box * CF(0, 0.65 * s, 0.98 * s) * ANG(open, 0, 0) * CF(0, 0.2 * s, -1.0 * s)
	local function leg(name, x, z, a)
		out["Leg" .. name] = limb(box * CF(x * s, -0.6 * s, z * s), a, 0, 0.32 * s)
	end
	leg("FL", -0.85, -0.65, scuttle)
	leg("FR", 0.85, -0.65, -scuttle)
	leg("BL", -0.85, 0.65, -scuttle)
	leg("BR", 0.85, 0.65, scuttle)
	return out
end

-- The API ---------------------------------------------------------------------------------------------------------------------------------------
function Rigs.build(kind, opts, parent)
	opts = opts or {}
	local rig = newRig(kind, Rigs.SCALE[kind] or 1, parent)
	local build = BUILD[kind] or BUILD.snapcap
	build(rig, opts)
	rig.elite = opts.elite == true
	rig.pose = POSE[kind] or POSE.snapcap
	local first = rig.bones.Torso or rig.bones.Body or rig.bones.Trunk or rig.bones.Stalk or rig.bones.Box
	rig.model.PrimaryPart = first
	rig.head = rig.bones.Head or rig.bones.Cap or rig.bones.Trunk or rig.bones.Lid or first
	rig.model.Parent = parent
	return rig
end

-- Where every part of a rig goes for a pose.
function Rigs.pose(rig, root, p)
	local out = rig.pose(rig, root, p or {})
	local parts, cframes = {}, {}
	for name, cf in out do
		local b = rig.bones[name]
		if b then
			table.insert(parts, b)
			table.insert(cframes, cf)
		end
	end
	for _, a in rig.parts do
		local cf = out[a.bone]
		if cf then
			table.insert(parts, a.part)
			table.insert(cframes, cf * a.offset)
		end
	end
	return parts, cframes
end

-- Pose right away (the render tools; the client batches every monster into one BulkMoveTo).
function Rigs.place(rig, root, p)
	local parts, cframes = Rigs.pose(rig, root, p)
	for i, part in parts do
		part.CFrame = cframes[i]
	end
end

-- Mega Kermy's weak spot glows while he's stuck or tired.
function Rigs.setWeak(rig, on, t)
	if rig.weak then
		local pulse = on and (0.5 + 0.5 * sin((t or 0) * 8)) or 0
		rig.weak.Color = on and GOLD:Lerp(rgb(255, 255, 230), pulse) or GOLD_DARK
		rig.weak.Transparency = on and 0 or 0.25
	end
end

-- A grinwolf's eyes flash red before it darts in.
function Rigs.setEyes(rig, color)
	for _, e in rig.eyes or {} do
		e.Color = color
	end
end

return Rigs
