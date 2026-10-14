--[[
Earned looks worn on your own avatar (Data/Progression.LOOKS; master plan §13: cosmetics are for showing off, never
power). Built from plain parts and welded to the character by the server (ProgressService), so everyone sees them.

  Looks.wear(character, key) -> model
]]
local Kit = require(script.Parent.Kit)

local Looks = {}

local C, M = Kit.C, Kit.M
local V3 = Vector3.new

local function p(m, name, size, color, material, shape, cf)
	local part = Kit.box(m, name, cf or CFrame.new(), size, color, material or M.SmoothPlastic, {
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CastShadow = false,
		Anchored = false,
	})
	if shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	end
	return part
end

local function weld(a, b, c0)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = c0
	w.Parent = b
	return w
end

local build = {}

function build.ranger_hat(m, head)
	local brim = p(m, "Brim", V3(0.2, 2.6, 2.6), C.woodDark, M.Fabric, "Cylinder")
	weld(head, brim, CFrame.new(0, head.Size.Y / 2 + 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local crown = p(m, "Crown", V3(1, 1.4, 1.4), C.wood, M.Fabric, "Cylinder")
	weld(head, crown, CFrame.new(0, head.Size.Y / 2 + 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)))
	local band = p(m, "Band", V3(0.25, 1.45, 1.45), C.red, M.Fabric, "Cylinder")
	weld(head, band, CFrame.new(0, head.Size.Y / 2 + 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)))
end

function build.leaf_crown(m, head)
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		local leaf = p(m, "Leaf", V3(0.5, 0.15, 0.9), k % 2 == 0 and C.leaf or C.autumn, M.Grass)
		weld(
			head,
			leaf,
			CFrame.new(math.cos(a) * 0.6, head.Size.Y / 2 + 0.1, math.sin(a) * 0.6) * CFrame.Angles(0, -a, math.rad(30))
		)
	end
end

function build.kermy_hood(m, head)
	local hood = p(m, "Hood", V3(1.6, 1.4, 1.6), C.kermy, M.Fabric, "Ball")
	weld(head, hood, CFrame.new(0, 0.25, 0.15))
	for _, x in { -0.4, 0.4 } do
		local eye = p(m, "Eye", V3(0.6, 0.6, 0.6), C.yellow, M.SmoothPlastic, "Ball")
		weld(head, eye, CFrame.new(x, head.Size.Y / 2 + 0.25, -0.35))
		local pupil = p(m, "Pupil", V3(0.22, 0.22, 0.22), C.black, M.SmoothPlastic, "Ball")
		weld(head, pupil, CFrame.new(x, head.Size.Y / 2 + 0.25, -0.62))
	end
end

function build.crown_67(m, head)
	local ring = p(m, "Ring", V3(0.4, 1.5, 1.5), C.gold, M.Metal, "Cylinder")
	weld(head, ring, CFrame.new(0, head.Size.Y / 2 + 0.2, 0) * CFrame.Angles(0, 0, math.rad(90)))
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		local spike = p(m, "Spike", V3(0.2, 0.5, 0.2), C.gold, M.Metal)
		weld(head, spike, CFrame.new(math.cos(a) * 0.65, head.Size.Y / 2 + 0.6, math.sin(a) * 0.65))
	end
	local gem = p(m, "Gem", V3(0.35, 0.35, 0.35), C.jersey, M.Neon, "Ball")
	weld(head, gem, CFrame.new(0, head.Size.Y / 2 + 0.2, -0.75))
end

function build.golden_67(m, _, torso)
	if not torso then
		return
	end
	local chain = p(m, "Chain", V3(0.15, 1.8, 1.4), C.gold, M.Metal, "Cylinder")
	weld(torso, chain, CFrame.new(0, torso.Size.Y / 2 - 0.2, -0.2) * CFrame.Angles(math.rad(70), 0, math.rad(90)))
	local plate = p(m, "Plate", V3(0.9, 0.6, 0.15), C.gold, M.Metal)
	weld(torso, plate, CFrame.new(0, torso.Size.Y / 2 - 0.9, -torso.Size.Z / 2 - 0.1))
	Kit.text(plate, Enum.NormalId.Front, "67", { font = Enum.Font.LuckiestGuy, color = C.jersey, ppu = 40 })
end

function build.camp_pack(m, _, torso)
	if not torso then
		return
	end
	local bag = p(m, "Bag", V3(1.6, 1.8, 0.9), C.canvasGreen, M.Fabric)
	weld(torso, bag, CFrame.new(0, 0, torso.Size.Z / 2 + 0.45))
	local roll = p(m, "Bedroll", V3(1.8, 0.6, 0.6), C.canvasRed, M.Fabric, "Cylinder")
	weld(torso, roll, CFrame.new(0, 1.05, torso.Size.Z / 2 + 0.45))
end

function build.lantern_pack(m, _, torso)
	if not torso then
		return
	end
	local bag = p(m, "Bag", V3(1.4, 1.6, 0.8), C.wood, M.Fabric)
	weld(torso, bag, CFrame.new(0, 0, torso.Size.Z / 2 + 0.4))
	local pole = p(m, "Pole", V3(0.15, 2.2, 0.15), C.woodDark, M.Wood)
	weld(torso, pole, CFrame.new(0.5, 1.2, torso.Size.Z / 2 + 0.5))
	local lamp = p(m, "Lamp", V3(0.6, 0.7, 0.6), C.warm, M.Neon)
	weld(torso, lamp, CFrame.new(0.5, 2.4, torso.Size.Z / 2 + 0.5))
	Kit.light(lamp, "PointLight", { Color = C.warm, Range = 14, Brightness = 1.2 })
end

function build.firefly_trail(m, _, torso)
	if not torso then
		return
	end
	local anchor = p(m, "Fireflies", V3(0.2, 0.2, 0.2), C.yellow, M.Neon)
	anchor.Transparency = 1
	weld(torso, anchor, CFrame.new(0, 0, 0))
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkles"
	e.Rate = 6
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.18)
	e.Color = ColorSequence.new(Color3.fromRGB(220, 255, 120))
	e.Parent = anchor
end

function Looks.wear(character, key)
	local fn = build[key]
	if not fn then
		return nil
	end
	local head = character:FindFirstChild("Head")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not head then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Look_" .. key
	fn(m, head, torso)
	m.Parent = character
	return m
end

return Looks
