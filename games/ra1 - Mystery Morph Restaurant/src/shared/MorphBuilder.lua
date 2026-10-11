-- One builder for greybox morph bodies (GDD §27.4.1 Shared/Morph). Clients use buildCustomer() for the visual
-- side of each customer proxy (SPCV); the server uses attachMutation() on player characters.
-- Everything is primitive parts until the art team's mutation models (§C13.7 rig contract) exist.
local MorphBuilder = {}

local SHIRTS = {
	Color3.fromRGB(255, 197, 49),
	Color3.fromRGB(46, 196, 182),
	Color3.fromRGB(255, 75, 62),
	Color3.fromRGB(91, 141, 239),
	Color3.fromRGB(161, 92, 255),
	Color3.fromRGB(255, 255, 255),
}
local INK = Color3.fromRGB(27, 29, 43)
local WHITE = Color3.fromRGB(250, 250, 250)

local function part(parent, props)
	local p = Instance.new(props.Shape and "Part" or (props.Class or "Part"))
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Size = props.Size
	p.Color = props.Color or WHITE
	p.Name = props.Name or "Part"
	p.Parent = parent
	return p
end

-- Weld `p` to `root` at offset `cf` (relative to root).
local function attach(root, p, cf)
	p.CFrame = root.CFrame * cf
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	return p
end

local function eyes(root, headCf, headSize)
	local z = -headSize.Z / 2
	for _, x in { -0.35, 0.35 } do
		local white = part(root.Parent, { Name = "Eye", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5) })
		attach(root, white, headCf * CFrame.new(x * headSize.X / 1.8, 0.15, z))
		local pupil = part(root.Parent, {
			Name = "Pupil",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.24, 0.24, 0.24),
			Color = INK,
		})
		attach(root, pupil, headCf * CFrame.new(x * headSize.X / 1.8, 0.15, z - 0.2))
	end
end

-- Seeded random helper: same seed → same look on every client.
local function rng(seed)
	return Random.new(seed)
end

--[[
Build a customer body. Returns a Model whose PrimaryPart ("Root") is anchored and centred where the
5-stud-tall server proxy is; move it by setting Root.CFrame.
]]
function MorphBuilder.buildCustomer(personality, seed)
	local r = rng(seed)
	local look = personality.look
	local skin = look.skin
	local shirt = SHIRTS[r:NextInteger(1, #SHIRTS)]
	local model = Instance.new("Model")
	model.Name = personality.name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 5, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root

	local bulky = look.extra == "muscles" or look.head == "golem" or look.head == "hippo"
	local armSize = bulky and Vector3.new(1.1, 1.9, 1.1) or Vector3.new(0.8, 1.8, 0.8)
	local torsoSize = bulky and Vector3.new(2.6, 2, 1.4) or Vector3.new(2, 2, 1.2)

	-- legs, torso, arms (root centre is 2.5 above the floor)
	for _, x in { -0.5, 0.5 } do
		attach(
			root,
			part(model, { Name = "Leg", Size = Vector3.new(0.9, 1.6, 0.9), Color = INK }),
			CFrame.new(x, -1.7, 0)
		)
	end
	attach(root, part(model, { Name = "Torso", Size = torsoSize, Color = shirt }), CFrame.new(0, -0.1, 0))
	local armX = torsoSize.X / 2 + armSize.X / 2
	for _, x in { -armX, armX } do
		attach(root, part(model, { Name = "Arm", Size = armSize, Color = skin }), CFrame.new(x, -0.2, 0))
	end

	-- head by species
	local headSize = Vector3.new(1.8, 1.8, 1.8)
	if look.head == "hippo" then
		headSize = Vector3.new(2.4, 1.8, 2.2)
	elseif look.head == "pigeon" then
		headSize = Vector3.new(1.7, 1.7, 1.7)
	end
	local headCf = CFrame.new(0, 1.85, 0)
	local head = part(model, {
		Name = "Head",
		Size = headSize,
		Color = skin,
		Shape = look.head == "pigeon" and Enum.PartType.Ball or nil,
	})
	attach(root, head, headCf)
	eyes(root, headCf, headSize)

	local front = -headSize.Z / 2
	if look.head == "dino" then
		attach(
			root,
			part(model, { Name = "Snout", Size = Vector3.new(1.4, 0.8, 1.0), Color = skin }),
			headCf * CFrame.new(0, -0.4, front - 0.4)
		)
		for _, x in { -0.4, 0, 0.4 } do
			attach(
				root,
				part(model, { Name = "Tooth", Size = Vector3.new(0.18, 0.25, 0.18) }),
				headCf * CFrame.new(x, -0.85, front - 0.75)
			)
		end
	elseif look.head == "hippo" then
		attach(
			root,
			part(model, { Name = "Muzzle", Size = Vector3.new(2.0, 0.9, 0.6), Color = skin }),
			headCf * CFrame.new(0, -0.45, front - 0.25)
		)
		for _, x in { -0.8, 0.8 } do
			attach(
				root,
				part(model, { Name = "Ear", Size = Vector3.new(0.4, 0.4, 0.3), Color = skin }),
				headCf * CFrame.new(x, 1.0, 0)
			)
		end
	elseif look.head == "pigeon" then
		attach(
			root,
			part(model, {
				Name = "Beak",
				Class = "WedgePart",
				Size = Vector3.new(0.5, 0.4, 0.7),
				Color = Color3.fromRGB(240, 150, 40),
			}),
			headCf * CFrame.new(0, -0.2, front - 0.3) * CFrame.Angles(0, math.pi, 0)
		)
	elseif look.head == "sloth" then
		attach(
			root,
			part(model, { Name = "Mask", Size = Vector3.new(1.4, 0.7, 0.1), Color = Color3.fromRGB(90, 66, 48) }),
			headCf * CFrame.new(0, 0.15, front - 0.02)
		)
	end

	-- signature extras
	if look.extra == "horns" then
		for _, x in { -0.55, 0.55 } do
			attach(
				root,
				part(model, { Name = "Horn", Class = "WedgePart", Size = Vector3.new(0.3, 0.8, 0.4), Color = INK }),
				headCf * CFrame.new(x, 1.3, 0)
			)
		end
	elseif look.extra == "pointyears" or look.extra == "bigears" then
		local s = look.extra == "bigears" and Vector3.new(0.3, 1.2, 1.0) or Vector3.new(0.25, 0.6, 0.9)
		for _, x in { -1, 1 } do
			attach(
				root,
				part(model, { Name = "Ear", Class = "WedgePart", Size = s, Color = skin }),
				headCf * CFrame.new(x * (headSize.X / 2 + 0.2), 0.4, 0) * CFrame.Angles(0, 0, x * math.rad(60))
			)
		end
	elseif look.extra == "spiderlegs" then
		for i = 1, 4 do
			local x = i <= 2 and -1 or 1
			local z = (i % 2 == 0) and 0.4 or -0.4
			attach(
				root,
				part(model, { Name = "SpiderLeg", Size = Vector3.new(2.2, 0.25, 0.25), Color = INK }),
				CFrame.new(x * 1.9, -0.8, z) * CFrame.Angles(0, 0, x * math.rad(-25))
			)
		end
	elseif look.extra == "rocket" then
		attach(
			root,
			part(model, {
				Name = "Rocket",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.8, 0.9, 0.9),
				Color = Color3.fromRGB(190, 196, 206),
			}),
			CFrame.new(0, -0.1, 1.05) * CFrame.Angles(0, 0, math.rad(90))
		)
		attach(
			root,
			part(model, {
				Name = "Flame",
				Class = "WedgePart",
				Size = Vector3.new(0.6, 0.7, 0.6),
				Color = Color3.fromRGB(255, 140, 30),
				Material = Enum.Material.Neon,
			}),
			CFrame.new(0, -1.3, 1.05) * CFrame.Angles(math.pi, 0, 0)
		)
	elseif look.extra == "hairbun" then
		attach(
			root,
			part(model, {
				Name = "Bun",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1, 1, 1),
				Color = Color3.fromRGB(230, 230, 236),
			}),
			headCf * CFrame.new(0, 1.15, 0.2)
		)
	elseif look.extra == "pearls" then
		attach(
			root,
			part(
				model,
				{ Name = "Pearls", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 1.9, 1.9), Color = WHITE }
			),
			CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90))
		)
	end

	-- a little size variety
	model:ScaleTo(0.9 + r:NextNumber() * 0.25)
	return model
end

-- Server: attach a tutorial arm mutation to a player character's left arm. Removes any previous one.
function MorphBuilder.attachMutation(character, mutation)
	local old = character:FindFirstChild("MutationParts")
	if old then
		old:Destroy()
	end
	if not mutation then
		return
	end
	local hand = character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")
	if not hand then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "MutationParts"
	folder.Parent = character
	local isR6 = hand.Name == "Left Arm"
	local base = hand.CFrame * CFrame.new(0, isR6 and -1 or -0.2, 0)

	local function add(props, offset)
		local p = part(folder, props)
		p.CFrame = base * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = hand
		w.Part1 = p
		w.Parent = p
		return p
	end

	if mutation.id == "MUT_145" then -- Octopus Arm: curling tentacle with suction cups
		local y, angle = 0, 0
		for i = 1, 5 do
			local size = 0.75 - i * 0.08
			add({
				Name = "Tentacle",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size) * 1.4,
				Color = mutation.color,
			}, CFrame.new(0, y, 0) * CFrame.Angles(angle, 0, 0))
			add({
				Name = "Sucker",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.25, 0.25, 0.25),
				Color = Color3.fromRGB(240, 190, 230),
			}, CFrame.new(0, y, -size * 0.6))
			y -= size * 0.9
			angle += math.rad(12)
		end
	elseif mutation.id == "MUT_144" then -- Crab Claw Arm: two big pincers
		add({ Name = "ClawBase", Size = Vector3.new(1.1, 0.9, 1.1), Color = mutation.color }, CFrame.new(0, -0.3, 0))
		add(
			{ Name = "PincerTop", Class = "WedgePart", Size = Vector3.new(0.7, 0.6, 1.4), Color = mutation.color },
			CFrame.new(0, -0.6, -0.7) * CFrame.Angles(math.rad(20), 0, 0)
		)
		add(
			{ Name = "PincerBottom", Class = "WedgePart", Size = Vector3.new(0.7, 0.5, 1.2), Color = mutation.color },
			CFrame.new(0, -1.0, -0.6) * CFrame.Angles(math.rad(160), 0, 0)
		)
	elseif mutation.id == "MUT_153" then -- Wrench Claw Arm: grey shaft with an open wrench jaw
		add({
			Name = "Shaft",
			Size = Vector3.new(0.5, 1.2, 0.5),
			Color = mutation.color,
			Material = Enum.Material.Metal,
		}, CFrame.new(0, -0.5, 0))
		for _, x in { -0.35, 0.35 } do
			add({
				Name = "Jaw",
				Size = Vector3.new(0.25, 0.7, 0.4),
				Color = mutation.color,
				Material = Enum.Material.Metal,
			}, CFrame.new(x, -1.3, 0))
		end
	end
end

return MorphBuilder
