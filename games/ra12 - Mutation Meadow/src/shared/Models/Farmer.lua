--[[
The capture stage's farmers (server only): real R15 avatars from Players:CreateHumanoidModelFromDescription, with
the default face and the default (mitten) hands in skin colour. Live players are their own avatars, so the street
itself never spawns one.

A farmer's HumanoidDescription carries the skin (head, arms, hands) and the outfit's shirt (torso) and trousers
(legs). Farmer.dress then colours the sleeves, adds the outfit's props (straw sunhat, apron, overall bib, rainboots,
gloves) and hides the name and health. No outfit uses gold: the sunhat is straw brown and the rainboots red.

Poses (Farmer.pose(model, name)):
  idle, wave, cheer, walk   the stock R15 animations, played and frozen on their best frame (FREEZE_AT)
  watering                  the right arm forward holding a tin can, a slight lean (joint pose)
  surprised                 both hands up by the head, the head tipped back (joint pose)
Joint poses turn the Motor6D C0s (they replicate); Farmer.pose always resets the last pose first.

  Farmer.OUTFITS / OUTFIT_ORDER / SKINS / POSES / ANIMS
  Farmer.description(outfitKey, skinIndex) -> HumanoidDescription
  Farmer.build(parent, name, outfitKey, skinIndex, cf, pose?) -> Model (attributes Outfit, Skin, Pose)
  Farmer.pose(model, name)
]]
local Players = game:GetService("Players")

local Kit = require(script.Parent.Kit)

local Farmer = {}

local rad = math.rad

Farmer.OUTFITS = {
	overalls = { shirt = Color3.fromRGB(240, 240, 235), pants = Color3.fromRGB(60, 90, 160), bib = true },
	sunhat = {
		shirt = Color3.fromRGB(236, 150, 128), -- coral
		pants = Color3.fromRGB(120, 90, 60),
		hat = Color3.fromRGB(176, 134, 84), -- straw brown
	},
	apron = {
		shirt = Color3.fromRGB(200, 80, 80),
		pants = Color3.fromRGB(70, 60, 50),
		apron = Color3.fromRGB(245, 240, 220),
	},
	rainboots = {
		shirt = Color3.fromRGB(90, 160, 210),
		pants = Color3.fromRGB(60, 60, 70),
		boots = Color3.fromRGB(196, 48, 44), -- red
	},
	flannel = { shirt = Color3.fromRGB(170, 40, 40), pants = Color3.fromRGB(50, 70, 110) },
	gloves = {
		shirt = Color3.fromRGB(110, 170, 90),
		pants = Color3.fromRGB(90, 80, 60),
		gloves = Color3.fromRGB(120, 200, 120),
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

-- the stock R15 animations (the default Animate script's) and the second each one freezes on
Farmer.ANIMS = {
	idle = "rbxassetid://507766388",
	wave = "rbxassetid://507770239",
	cheer = "rbxassetid://507770677",
	walk = "rbxassetid://913402848",
}
local FREEZE_AT = { idle = 0.2, wave = 0.55, cheer = 0.45, walk = 0.3 }

-- joint poses: Motor6D name -> extra rotation on its C0
Farmer.POSES = {
	idle = { anim = "idle" },
	wave = { anim = "wave" },
	cheer = { anim = "cheer" },
	walk = { anim = "walk" },
	watering = {
		joints = {
			RightShoulder = CFrame.Angles(rad(75), 0, rad(-8)),
			RightElbow = CFrame.Angles(rad(15), 0, 0),
			Waist = CFrame.Angles(rad(-8), rad(-10), 0),
			Neck = CFrame.Angles(rad(-18), 0, 0),
		},
		can = true,
	},
	surprised = {
		joints = {
			LeftShoulder = CFrame.Angles(rad(150), 0, rad(-25)),
			RightShoulder = CFrame.Angles(rad(150), 0, rad(25)),
			LeftElbow = CFrame.Angles(rad(55), 0, 0),
			RightElbow = CFrame.Angles(rad(55), 0, 0),
			Neck = CFrame.Angles(rad(14), 0, 0),
			Waist = CFrame.Angles(rad(6), 0, 0),
		},
	},
}

local SLEEVES = { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }
local HANDS = { "LeftHand", "RightHand" }
local FEET = { "LeftFoot", "RightFoot" }
local TIN = Color3.fromRGB(150, 162, 172)

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
		local brim = prop(
			model,
			head,
			"SunHatBrim",
			Vector3.new(0.2, 3, 3),
			CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, rad(90)),
			o.hat
		)
		brim.Shape = Enum.PartType.Cylinder
		local crown = prop(
			model,
			head,
			"SunHat",
			Vector3.new(0.7, 1.5, 1.5),
			CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, rad(90)),
			o.hat
		)
		crown.Shape = Enum.PartType.Cylinder
	end
	if o.apron and torso then
		prop(model, torso, "Apron", Vector3.new(1.7, 2.2, 0.12), CFrame.new(0, -0.5, -0.56), o.apron)
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

local function wateringCan(model)
	local hand = find(model, "RightHand")
	if not hand then
		return
	end
	local can = Kit.model(model, "WateringCan")
	local body = prop(
		can,
		hand,
		"Can",
		Vector3.new(1.1, 0.9, 0.9),
		CFrame.new(0, -0.55, -0.35) * CFrame.Angles(0, 0, rad(90)),
		TIN,
		Enum.Material.Metal
	)
	body.Shape = Enum.PartType.Cylinder
	prop(
		can,
		body,
		"Spout",
		Vector3.new(0.14, 0.14, 1.1),
		CFrame.new(0, 0.1, -0.85) * CFrame.Angles(rad(-30), 0, 0),
		TIN,
		Enum.Material.Metal
	)
	prop(can, body, "Handle", Vector3.new(0.12, 0.6, 0.12), CFrame.new(0, 0.5, 0.2), TIN, Enum.Material.Metal)
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
