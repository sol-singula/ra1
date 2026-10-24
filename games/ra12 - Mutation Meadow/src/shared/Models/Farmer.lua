--[[
The capture stage's farmers (server only), per Game Artist build-spec/06-avatars.md: real R15 avatars from
Players:CreateHumanoidModelFromDescription, with the default face (rbxasset://textures/face.png on the Head's
"face" Decal; catalog face ids wait for a Studio check) and skin-coloured mitten hands (Hand L/R 1.05 x 0.55 x
1.05). Live players are their own avatars, so the street itself never spawns one.

A farmer's HumanoidDescription carries the skin (head, arms, hands) and the outfit's shirt (torso) and trousers
(legs). Farmer.dress then colours the sleeves, adds the outfit's props (the #E8C56A Fabric sunhat, the apron, the
overall bib, the #3A7CBC rubber rainboots, gloves) and hides the name and health. No gold, Foil or Metal on any
farmer, and no lights or particles.

Poses (Farmer.pose(model, name)), section 4, held for the capture stills:
  idle                      the rest pose
  wave / cheer / surprised  the arms raised (cheer hops 0.4)
  watering                  the right arm forward, the torso tipped forward, a blue can in the left hand
  walk                      the stock R15 walk, played and frozen on its best frame (FREEZE_AT)
Joint poses turn the Motor6D C0s (they replicate); Farmer.pose always resets the last pose first.

  Farmer.OUTFITS / OUTFIT_ORDER / SKINS / POSES / ANIMS / FACE / MITTEN
  Farmer.description(outfitKey, skinIndex) -> HumanoidDescription
  Farmer.build(parent, name, outfitKey, skinIndex, cf, pose?) -> Model (attributes Outfit, Skin, Pose)
  Farmer.pose(model, name)
]]
local Players = game:GetService("Players")

local Kit = require(script.Parent.Kit)

local Farmer = {}

local rad = math.rad

-- section 3
Farmer.OUTFITS = {
	overalls = { shirt = Color3.fromHex("#F0F0EB"), pants = Color3.fromHex("#3C5AA0"), bib = true },
	sunhat = { shirt = Color3.fromHex("#F5C878"), pants = Color3.fromHex("#785A3C"), hat = Color3.fromHex("#E8C56A") },
	apron = { shirt = Color3.fromHex("#C85050"), pants = Color3.fromHex("#463C32"), apron = Color3.fromHex("#F5F0DC") },
	rainboots = {
		shirt = Color3.fromHex("#5AA0D2"),
		pants = Color3.fromHex("#3C3C46"),
		boots = Color3.fromHex("#3A7CBC"),
	},
	flannel = { shirt = Color3.fromHex("#AA2828"), pants = Color3.fromHex("#32466E") },
	gloves = {
		shirt = Color3.fromHex("#6EAA5A"),
		pants = Color3.fromHex("#5A503C"),
		gloves = Color3.fromHex("#78C878"),
	},
}
Farmer.OUTFIT_ORDER = { "overalls", "sunhat", "apron", "rainboots", "flannel", "gloves" }

Farmer.SKINS = {
	Color3.fromRGB(255, 220, 186),
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(204, 142, 105),
	Color3.fromRGB(161, 102, 68),
	Color3.fromRGB(120, 74, 48),
	Color3.fromRGB(86, 54, 36),
}

Farmer.FACE = "rbxasset://textures/face.png" -- section 2: the verified built-in default
Farmer.MITTEN = Vector3.new(1.05, 0.55, 1.05) -- section 1

-- the stock R15 walk (the default Animate script's) and the second it freezes on
Farmer.ANIMS = { walk = "rbxassetid://913402848" }
local FREEZE_AT = { walk = 0.3 }

-- section 4 as Motor6D C0 turns (the spec raises an arm with -rx and opens the right arm with -rz; Roblox's
-- shoulders raise with +rx and open the right arm with +rz; the torso and head keep the spec's sign: -rx forward)
Farmer.POSES = {
	idle = { joints = {} },
	wave = { joints = { RightShoulder = CFrame.Angles(rad(140), 0, 0) } },
	cheer = {
		joints = {
			LeftShoulder = CFrame.Angles(rad(160), 0, 0),
			RightShoulder = CFrame.Angles(rad(160), 0, 0),
			Root = CFrame.new(0, 0.4, 0), -- the hop
		},
	},
	watering = {
		joints = { RightShoulder = CFrame.Angles(rad(40), 0, rad(20)), Waist = CFrame.Angles(rad(-8), 0, 0) },
		can = true,
	},
	surprised = {
		joints = {
			LeftShoulder = CFrame.Angles(rad(100), 0, 0),
			RightShoulder = CFrame.Angles(rad(100), 0, 0),
			Neck = CFrame.Angles(rad(-10), 0, 0),
		},
	},
	walk = { anim = "walk" },
}

local SLEEVES = { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }
local HANDS = { "LeftHand", "RightHand" }
local FEET = { "LeftFoot", "RightFoot" }
local CAN = Color3.fromHex("#5AA0D2") -- section 4: the watering can

function Farmer.description(outfitKey, skinIndex)
	local o = Farmer.OUTFITS[outfitKey]
	local skin = Farmer.SKINS[(skinIndex - 1) % #Farmer.SKINS + 1]
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = skin
	d.LeftArmColor = skin
	d.RightArmColor = skin
	d.TorsoColor = o.shirt
	d.LeftLegColor = o.pants
	d.RightLegColor = o.pants
	d.Face = 0 -- the default face
	d.Shirt = 0
	d.Pants = 0
	d.GraphicTShirt = 0
	return d
end

local function find(model, name)
	return model:FindFirstChild(name, true)
end

local function prop(model, to, name, size, offset, color, material)
	local p = Kit.part(model, name, size, to.CFrame * offset, color, material or Enum.Material.Fabric)
	p.Reflectance = 0
	Kit.weld(p, to)
	return p
end

function Farmer.dress(model, outfitKey)
	local o = Farmer.OUTFITS[outfitKey]
	for _, name in SLEEVES do
		local p = find(model, name)
		if p then
			p.Color = o.shirt
		end
	end
	for _, name in HANDS do
		local p = find(model, name)
		if p then
			p.Size = Farmer.MITTEN
			if p.ClassName == "Part" then -- a blocky Part hand gets rounded into a mitten
				local mesh = Instance.new("SpecialMesh")
				mesh.Name = "Mitten"
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			end
		end
	end
	local headPart = find(model, "Head")
	if headPart then
		local face = headPart:FindFirstChild("face") or headPart:FindFirstChild("Face")
		if not face then
			face = Instance.new("Decal")
			face.Name = "face"
			face.Face = Enum.NormalId.Front
			face.Parent = headPart
		end
		face.Texture = Farmer.FACE
	end
	if o.gloves then
		for _, name in HANDS do
			local p = find(model, name)
			if p then
				p.Color = o.gloves
			end
		end
	end
	if o.boots then
		for _, name in FEET do
			local p = find(model, name)
			if p then
				p.Color = o.boots
				p.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	local head, torso = find(model, "Head"), find(model, "UpperTorso")
	if o.hat and head then
		-- a Cylinder disc (0.15, 2.2, 2.2) and a crown Block (1.2, 0.7, 1.2) on the Head's top (0.6 up)
		local brim = prop(
			model,
			head,
			"SunHatBrim",
			Vector3.new(0.15, 2.2, 2.2),
			CFrame.new(0, 0.6 + 0.075, 0) * CFrame.Angles(0, 0, rad(90)),
			o.hat
		)
		brim.Shape = Enum.PartType.Cylinder
		prop(model, head, "SunHat", Vector3.new(1.2, 0.7, 1.2), CFrame.new(0, 0.6 + 0.15 + 0.35, 0), o.hat)
	end
	if o.apron and torso then
		prop(model, torso, "Apron", Vector3.new(1.7, 1.4, 0.12), CFrame.new(0, -0.5, -0.56), o.apron)
	end
	if o.bib and torso then
		prop(
			model,
			torso,
			"Bib",
			Vector3.new(1.3, 1.1, 0.12),
			CFrame.new(0, -0.1, -0.54),
			o.pants,
			Enum.Material.Fabric
		)
		for i, side in { -1, 1 } do
			prop(model, torso, "Strap" .. i, Vector3.new(0.25, 1, 0.12), CFrame.new(0.5 * side, 0.45, -0.54), o.pants)
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	model:SetAttribute("Outfit", outfitKey)
end

local function animator(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator")
end

local function motors(model)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			out[d.Name] = d
		end
	end
	return out
end

local base = setmetatable({}, { __mode = "k" }) -- [Motor6D] = its C0 before any pose
local tracks = setmetatable({}, { __mode = "k" }) -- [model] = the playing pose track

local function reset(model)
	local track = tracks[model]
	if track then
		pcall(function()
			track:Stop(0)
		end)
		tracks[model] = nil
	end
	for _, motor in motors(model) do
		if base[motor] then
			motor.C0 = base[motor]
		end
	end
	local can = model:FindFirstChild("WateringCan")
	if can then
		can:Destroy()
	end
end

-- section 4: the can (0.5 x 0.6 x 0.35, #5AA0D2) in the left hand
local function wateringCan(model)
	local hand = find(model, "LeftHand")
	if not hand then
		return
	end
	local can = Kit.model(model, "WateringCan")
	prop(can, hand, "Can", Vector3.new(0.5, 0.6, 0.35), CFrame.new(0, -0.45, -0.1), CAN, Enum.Material.SmoothPlastic)
end

function Farmer.pose(model, name)
	local pose = Farmer.POSES[name]
	if not pose then
		return false
	end
	reset(model)
	model:SetAttribute("Pose", name)
	if pose.joints then
		local all = motors(model)
		for jointName, turn in pose.joints do
			local motor = all[jointName]
			if motor then
				base[motor] = base[motor] or motor.C0
				motor.C0 = base[motor] * turn
			end
		end
		if pose.can then
			wateringCan(model)
		end
		return true
	end
	local a = animator(model)
	if not a then
		return false
	end
	local anim = Instance.new("Animation")
	anim.Name = name
	anim.AnimationId = Farmer.ANIMS[pose.anim]
	anim.Parent = model
	local ok, track = pcall(function()
		return a:LoadAnimation(anim)
	end)
	if not ok or not track then
		return false
	end
	tracks[model] = track
	track.Looped = true
	track:Play(0)
	-- freeze on the pose's best frame once the animation has loaded (its Length is 0 until then)
	task.spawn(function()
		local waited = 0
		while track.Length == 0 and waited < 5 do
			waited += task.wait(0.1)
		end
		if tracks[model] == track then
			track.TimePosition = math.min(FREEZE_AT[pose.anim], math.max(0, track.Length - 0.01))
			track:AdjustSpeed(0)
		end
	end)
	return true
end

function Farmer.build(parent, name, outfitKey, skinIndex, cf, pose)
	local description = Farmer.description(outfitKey, skinIndex)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn(`Farmer.build: {name}: {model}`)
		return nil
	end
	model.Name = name
	model:SetAttribute("Skin", skinIndex)
	Farmer.dress(model, outfitKey)
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if root then
		root.Anchored = true
	end
	-- cf is the ground under the feet: the rig pivots on its root, HipHeight + half the root above the floor
	local lift = (if humanoid then humanoid.HipHeight else 2) + (if root then root.Size.Y / 2 else 1)
	model:PivotTo(cf * CFrame.new(0, lift, 0))
	model.Parent = parent
	if pose then
		Farmer.pose(model, pose)
	end
	return model
end

return Farmer
