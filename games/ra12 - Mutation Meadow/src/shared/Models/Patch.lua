--[[
Patch the shopkeeper (Game Artist build-spec/05-patch.md), shared by the street (PatchService builds him when the
place brings no rig; PatchRigController poses him on the client) and the capture stage. Config.PatchVisuals holds
every number: the Counter (Root, Counter, CounterTop) and 30 SmoothPlastic character parts - a cream #EADBB8 body
with a leafy green apron, arms and legs, root-brown feet, and the #FF8C1A pumpkin head with its shade, light, stem
curl, cowlick and a Decal-free face (part swaps under PumpkinHead). No gold, Foil, Neon, Metal, lights or
particles anywhere on him. He faces cf's LookVector (-Z), the Counter in front of him.

Poses move whole groups of parts about their joints (section 4): the character lifts, the upper body leans about
the hips, the head turns about its centre and the arms swing about the shoulders (the hands ride the arms).

  Patch.build(model, cf) -> PumpkinHead   (the Origin attribute; PrimaryPart = Root)
  Patch.pose(anim) -> params / Patch.mix(a, b, t) / Patch.apply(model, params) / Patch.setPose(model, anim)
  Patch.setFace(model, face)              the face's part swap (the Face attribute)
  Patch.setFar(model, far)                the LOD: SeedPacket, SeedDot, the eye shines, cheeks and Cowlick hide
  Patch.ORANGE / SHIRT / APRON / FACES / ANIMS
]]
local Config = require(script.Parent.Parent.Config)
local Kit = require(script.Parent.Kit)

local Patch = {}

local PV = Config.PatchVisuals
local rad = math.rad
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- Kit.cylinder's stand-up turn

Patch.ORANGE = Color3.fromHex("#FF8C1A")
Patch.SHIRT = Color3.fromHex("#EADBB8")
Patch.APRON = Color3.fromHex("#5BC236")
Patch.FACES = { "happy", "wow", "thinking", "wink", "sleepy" }
Patch.ANIMS = { "idle", "wave", "point", "cheer", "announce", "lean" }

local function v3(t)
	return Vector3.new(t[1], t[2], t[3])
end

-- the arms' angles are mirrored in the spec (a raise is -rx, the left arm opens with +rz): turn them into Roblox's
local function armRest(spec)
	local rz = if spec.name == "ArmL" then PV.rest.armL[2] else PV.rest.armR[2]
	return CFrame.new(v3(spec.offset)) * CFrame.Angles(0, 0, rad(-rz))
end

-- every part's rest CFrame in O's space
local REST, SPEC = {}, {}
for _, p in PV.parts do
	SPEC[p.name] = p
end
for _, p in PV.parts do
	if p.name == "ArmL" or p.name == "ArmR" then
		REST[p.name] = armRest(p)
	elseif p.hand then
		REST[p.name] = armRest(SPEC[p.hand]) * CFrame.new(0, -PV.handDrop, 0)
	else
		local r = p.rot or { 0, 0, 0 }
		REST[p.name] = CFrame.new(v3(p.offset)) * CFrame.Angles(rad(r[1]), rad(r[2]), rad(r[3]))
	end
end
local HEAD_AT = REST.PumpkinHead.Position
local SHOULDER = {
	armL = (REST.ArmL * CFrame.new(0, SPEC.ArmL.size[2] / 2, 0)).Position,
	armR = (REST.ArmR * CFrame.new(0, SPEC.ArmR.size[2] / 2, 0)).Position,
}

local last = setmetatable({}, { __mode = "k" }) -- [model] = the params on the parts
local farOf = setmetatable({}, { __mode = "k" })

local function make(parent, name, shape, size, colour, material)
	if shape == "ball" then
		return Kit.sphere(parent, name, size[1], CFrame.new(), colour, material)
	elseif shape == "ell" then
		return Kit.ball(parent, name, v3(size), CFrame.new(), colour, material)
	elseif shape == "cylV" then
		return Kit.cylinder(parent, name, size[1], size[2], CFrame.new(), colour, material)
	elseif shape == "wedge" then
		return Kit.wedge(parent, name, v3(size), CFrame.new(), colour, material)
	end
	return Kit.part(parent, name, v3(size), CFrame.new(), colour, material)
end

function Patch.build(model, cf)
	model:SetAttribute("Origin", cf)
	local head
	for _, p in PV.parts do
		local material = if p.material then Enum.Material[p.material] else nil
		local part = make(model, p.name, p.shape, p.size, Color3.fromHex(p.hex), material)
		part.Transparency = p.transparency or 0
		if p.name == "PumpkinHead" then
			head = part
			head:SetAttribute("Patch", true)
		end
	end
	model.Counter.CanCollide = true
	model.Counter.CanQuery = true -- the ShopPrompt sits on it
	model.CounterTop.CanCollide = true
	for name, f in PV.face.parts do
		make(head, name, f.shape, f.size, Color3.fromHex(f.hex))
	end
	model.PrimaryPart = model.Root
	if model:GetAttribute("Face") == nil then
		model:SetAttribute("Face", "happy")
	end
	if model:GetAttribute("Anim") == nil then
		model:SetAttribute("Anim", "idle")
	end
	Patch.setPose(model, "idle")
	Patch.setFace(model, model:GetAttribute("Face"))
	return head
end

-- poses -------------------------------------------------------------------------------------------------------------

function Patch.pose(anim)
	local s = PV.poses[anim] or PV.poses.idle
	return {
		lift = s.lift and v3(s.lift) or Vector3.zero,
		lean = s.lean or 0,
		yaw = s.yaw or 0,
		nod = s.nod or 0,
		tilt = s.tilt or 0,
		breath = 0,
		armL = { (s.armL or { 0, 0 })[1], (s.armL or { 0, 0 })[2] },
		armR = { (s.armR or { 0, 0 })[1], (s.armR or { 0, 0 })[2] },
	}
end

function Patch.mix(a, b, t)
	local function n(x, y)
		return x + (y - x) * t
	end
	return {
		lift = a.lift:Lerp(b.lift, t),
		lean = n(a.lean, b.lean),
		yaw = n(a.yaw, b.yaw),
		nod = n(a.nod, b.nod),
		tilt = n(a.tilt, b.tilt),
		breath = n(a.breath, b.breath),
		armL = { n(a.armL[1], b.armL[1]), n(a.armL[2], b.armL[2]) },
		armR = { n(a.armR[1], b.armR[1]), n(a.armR[2], b.armR[2]) },
	}
end

-- the face layout: [part] = { offset, size, shown }
local function layout(face)
	local F = PV.face
	local f = F.faces[face] or F.faces.happy
	local eyeL, eyeR = v3(f.eyeL or F.eyeL), v3(f.eyeR or F.eyeR)
	local eye = f.eyeSize or F.parts.EyeL.size[1]
	local mouth = v3(f.mouth or F.mouth)
	local shine = v3(F.shine)
	return {
		EyeL = { eyeL, Vector3.one * eye, not f.flatL },
		EyeR = { eyeR, Vector3.one * eye, not f.flatR },
		EyeLFlat = { eyeL, v3(F.parts.EyeLFlat.size), f.flatL == true },
		EyeRFlat = { eyeR, v3(F.parts.EyeRFlat.size), f.flatR == true },
		EyeShineL = { eyeL + shine, nil, not f.flatL },
		EyeShineR = { eyeR + shine, nil, not f.flatR },
		CheekL = { v3(F.cheekL), nil, true },
		CheekR = { v3(F.cheekR), nil, true },
		Mouth = { mouth, v3(f.mouthSize or F.parts.Mouth.size), not f.open },
		MouthOpen = { mouth, nil, f.open == true },
		Brow = { v3(f.brow or { 0, 0, 0 }), nil, f.brow ~= nil },
	}
end

function Patch.apply(model, p)
	local O = model:GetAttribute("Origin") or CFrame.new()
	local face = PV.face.faces[model:GetAttribute("Face")] or PV.face.faces.happy
	local lift = CFrame.new(p.lift)
	local hip = CFrame.new(0, PV.hip, 0)
	local body = lift * hip * CFrame.Angles(rad(p.lean), 0, 0) * hip:Inverse() * CFrame.new(0, p.breath, 0)
	local pivot = CFrame.new(HEAD_AT)
	local head = body * pivot * CFrame.Angles(rad(p.nod), rad(p.yaw), rad(p.tilt + (face.tilt or 0))) * pivot:Inverse()
	local T = { counter = CFrame.new(), legs = lift, body = body, head = head }
	for key, angles in { armL = p.armL, armR = p.armR } do
		local s = CFrame.new(SHOULDER[key])
		T[key] = body * s * CFrame.Angles(rad(-angles[1]), 0, rad(-angles[2])) * s:Inverse()
	end
	for _, spec in PV.parts do
		local part = model:FindFirstChild(spec.name)
		if part then
			local cf = O * T[spec.group] * REST[spec.name]
			part.CFrame = if spec.shape == "cylV" then cf * UPRIGHT else cf
		end
	end
	local headPart = model:FindFirstChild("PumpkinHead")
	if headPart then
		local centre = O * head * pivot
		for name, l in layout(model:GetAttribute("Face")) do
			local part = headPart:FindFirstChild(name)
			if part then
				part.CFrame = centre * CFrame.new(l[1])
			end
		end
	end
	last[model] = p
end

function Patch.setPose(model, anim)
	Patch.apply(model, Patch.pose(anim))
	model:SetAttribute("Pose", anim)
end

local function visibility(model)
	local head = model:FindFirstChild("PumpkinHead")
	if not head then
		return
	end
	local F = PV.face
	local f = F.faces[model:GetAttribute("Face")] or F.faces.happy
	local far = farOf[model] == true
	for name, l in layout(model:GetAttribute("Face")) do
		local part = head:FindFirstChild(name)
		if part then
			if l[2] then
				part.Size = l[2]
			end
			local base = if name == "CheekL" or name == "CheekR"
				then (f.cheekTransparency or F.cheekTransparency)
				else 0
			local hidden = not l[3] or (far and F.parts[name].lod)
			part.Transparency = if hidden then 1 else base
		end
	end
	for _, name in PV.lod.hide do
		local part = model:FindFirstChild(name)
		if part then
			part.Transparency = if far then 1 else (SPEC[name].transparency or 0)
		end
	end
end

function Patch.setFace(model, face)
	model:SetAttribute("Face", if PV.face.faces[face] then face else "happy")
	visibility(model)
	Patch.apply(model, last[model] or Patch.pose(model:GetAttribute("Anim") or "idle"))
end

function Patch.setFar(model, far)
	farOf[model] = far == true
	model:SetAttribute("Far", far == true)
	visibility(model)
end

return Patch
