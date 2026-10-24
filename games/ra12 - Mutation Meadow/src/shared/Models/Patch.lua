--[[
Patch the shopkeeper's look, shared by the street (PatchService's rig, when the place brings none) and the capture
stage: a cream shirt, a green apron, brown work trousers and gloves, and his #FF8C1A pumpkin head with a carved face
and a stem. There is no gold anywhere on him. He faces cf's LookVector, his counter in front of him.

  Patch.build(model, cf)      adds Counter, Legs, Body, Apron, arms, PumpkinHead (and its ribs, face and stem)
  Patch.ORANGE / SHIRT / APRON
]]
local Kit = require(script.Parent.Kit)

local Patch = {}

Patch.ORANGE = Color3.fromHex("#FF8C1A")
Patch.SHIRT = Color3.fromRGB(245, 236, 214)
Patch.APRON = Color3.fromRGB(58, 140, 72)
local TROUSERS = Color3.fromRGB(78, 66, 52)
local GLOVES = Color3.fromRGB(122, 86, 56)
local FACE = Color3.fromRGB(28, 20, 14)
local STEM = Color3.fromRGB(112, 82, 46)

function Patch.build(model, cf)
	local function at(x, y, z)
		return cf * CFrame.new(x, y, z)
	end
	local counter = Kit.part(
		model,
		"Counter",
		Vector3.new(8, 3, 3),
		at(0, 1.5, -3),
		Color3.fromRGB(190, 140, 90),
		Enum.Material.WoodPlanks
	)
	counter.CanCollide = true
	counter.CanQuery = true
	for i, side in { -1, 1 } do
		Kit.part(model, "Leg" .. i, Vector3.new(0.9, 2, 1), at(0.5 * side, 1, 0), TROUSERS, Enum.Material.Fabric)
	end
	local body = Kit.part(model, "Body", Vector3.new(2, 2, 1.2), at(0, 3, 0), Patch.SHIRT, Enum.Material.Fabric)
	body.CanCollide = true
	Kit.part(model, "Apron", Vector3.new(1.9, 2.6, 0.2), at(0, 2.6, -0.68), Patch.APRON, Enum.Material.Fabric)
	Kit.part(model, "ApronStrap", Vector3.new(1.2, 0.25, 0.16), at(0, 3.85, -0.66), Patch.APRON, Enum.Material.Fabric)
	for i, side in { -1, 1 } do
		Kit.part(
			model,
			"Arm" .. i,
			Vector3.new(0.8, 1.9, 0.8),
			at(1.45 * side, 3.05, 0) * CFrame.Angles(0, 0, math.rad(8 * side)),
			Patch.SHIRT,
			Enum.Material.Fabric
		)
		Kit.part(
			model,
			"Glove" .. i,
			Vector3.new(0.75, 0.55, 0.75),
			at(1.58 * side, 1.9, 0),
			GLOVES,
			Enum.Material.Fabric
		)
	end
	local head = Kit.ball(model, "PumpkinHead", Vector3.new(2.6, 2.2, 2.6), at(0, 5.1, 0), Patch.ORANGE)
	head:SetAttribute("Patch", true)
	for i, o in { { 0.38, 0, 2.0, 2.5 }, { -0.38, 0, 2.0, 2.5 } } do
		local rib = Kit.ball(model, "HeadRib" .. i, Vector3.new(o[3], 2.12, o[4]), at(o[1], 5.08, o[2]), Patch.ORANGE)
		rib:SetAttribute("Patch", true)
	end
	for i, side in { -1, 1 } do
		Kit.part(model, "Eye" .. i, Vector3.new(0.42, 0.46, 0.12), at(0.5 * side, 5.38, -1.24), FACE)
	end
	Kit.part(model, "Mouth", Vector3.new(1.1, 0.26, 0.12), at(0, 4.72, -1.22), FACE)
	Kit.cylinder(model, "Stem", 0.7, 0.36, at(0, 6.4, 0) * CFrame.Angles(math.rad(10), 0, 0), STEM, Enum.Material.Wood)
	return head
end

return Patch
