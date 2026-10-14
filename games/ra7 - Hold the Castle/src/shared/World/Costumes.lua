--[[
How dwarves and monsters look (master plan §9, §14): chunky friendly dwarves with big beards and big tools;
monsters that look cool, not gross, each with its own shape so you know what it is before you read its name.

Costumes are plain parts attached to body parts ("bones"), so the same art dresses:
  * players' characters (the server welds the parts on: TeamService), and
  * NPCs, which have a small rig of their own (Costumes.npc) that the client animates (HordeController) and the
    render tools pose (Costumes.pose).

Costumes.dress(rig, look) with rig = { bones = { Head = part, ... }, add = fn(boneName, part, offset), scale }
and look = { team = "dwarf" | "monster", job = jobKey, armor, beard, skin, weapon = look items (Data/Looks) }
]]
local Kit = require(script.Parent.Kit)
local Looks = require(script.Parent.Parent.Data.Looks)

local Costumes = {}

local C, M = Kit.C, Kit.M
local rgb = Kit.rgb

-- Monster colours by job (the "Classic" skin): main (skin), trim (horns, nails, clothes), eyes.
Costumes.MONSTER = {
	grunt = { main = rgb(126, 206, 86), trim = rgb(88, 150, 62), eyes = rgb(255, 230, 60), cloth = rgb(150, 96, 56) },
	brute = { main = rgb(120, 132, 192), trim = rgb(80, 86, 134), eyes = rgb(255, 150, 50), cloth = rgb(110, 70, 50) },
	spitter = {
		main = rgb(168, 106, 218),
		trim = rgb(152, 232, 72),
		eyes = rgb(170, 255, 90),
		cloth = rgb(92, 56, 140),
	},
	witch = {
		main = rgb(178, 224, 162),
		trim = rgb(112, 60, 172),
		eyes = rgb(255, 120, 240),
		cloth = rgb(112, 60, 172),
	},
	breaker = { main = rgb(228, 142, 76), trim = rgb(122, 82, 52), eyes = rgb(255, 236, 90), cloth = rgb(96, 70, 50) },
	imp = { main = rgb(234, 78, 78), trim = rgb(122, 32, 44), eyes = rgb(255, 240, 120), cloth = rgb(122, 32, 44) },
	scout = { main = rgb(150, 212, 92), trim = rgb(112, 82, 60), eyes = rgb(255, 230, 60), cloth = rgb(112, 82, 60) },
}
-- NPC dwarves' clothes (players wear their own avatar's)
Costumes.DWARF_SHIRTS = { rgb(70, 130, 220), rgb(220, 70, 70), rgb(70, 170, 90), rgb(230, 170, 50), rgb(150, 90, 210) }
Costumes.SKIN = rgb(240, 190, 150)

-- The colours a monster wears: its job's classic colours, painted by a skin look if it has one.
function Costumes.monsterColors(job, skin)
	local base = Costumes.MONSTER[job] or Costumes.MONSTER.grunt
	if not skin or not skin.main then
		return base
	end
	return {
		main = skin.main,
		trim = skin.trim or base.trim,
		eyes = skin.glow or base.eyes,
		cloth = (skin.trim or base.cloth):Lerp(base.cloth, 0.4),
		glow = skin.glow,
	}
end

local function add(rig, bone, name, offset, size, color, material, shape, extra)
	local b = rig.bones[bone]
	if not b then
		return nil
	end
	local props = {
		Name = name,
		Size = size,
		Color = color,
		Material = material or M.SmoothPlastic,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Massless = true,
		CastShadow = false,
		Anchored = rig.anchored == true,
		CFrame = b.CFrame * offset,
	}
	for k, val in extra or {} do
		props[k] = val
	end
	local p
	if shape == "Wedge" then
		props.ClassName = "WedgePart"
		p = Kit.part(props)
	else
		p = Kit.part(props)
		if shape == "Ball" then
			p.Shape = Enum.PartType.Ball
		elseif shape == "Cylinder" then
			p.Shape = Enum.PartType.Cylinder
		elseif shape == "Ellipsoid" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
	end
	p.Parent = rig.parent or b.Parent
	rig.add(bone, p, offset)
	return p
end
Costumes.add = add

local function sizeOf(rig, bone)
	local b = rig.bones[bone]
	return b and b.Size or Vector3.new(1, 1, 1)
end

-- Offsets in the bone's own size units (so the costume fits any avatar).
local function rel(rig, bone, x, y, z)
	local s = sizeOf(rig, bone)
	return CFrame.new(s.X * x, s.Y * y, s.Z * z)
end

local function weaponColors(look)
	local w = look and look.weapon
	return (w and w.main) or C.steel, w and w.glow, w and w.trim
end

-- Tools, held in the right hand (the handle points forward out of the fist; the left hand for bows).
local tools = {}

function tools.hammer(rig, s, look, big)
	local head, glow = weaponColors(look)
	local len = (big and 3.6 or 2.6) * s
	add(
		rig,
		"RightHand",
		"Handle",
		CFrame.new(0, 0, -len * 0.35) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(len, 0.32 * s, 0.32 * s),
		C.woodDark,
		M.Wood,
		"Cylinder"
	)
	local hs = big and Vector3.new(1.4, 2.2, 1.4) * s or Vector3.new(0.9, 1.5, 0.9) * s
	add(rig, "RightHand", "HammerHead", CFrame.new(0, 0, -len * 0.82), hs, head, glow and M.Neon or M.Metal)
	add(
		rig,
		"RightHand",
		"HammerBand",
		CFrame.new(0, 0, -len * 0.82),
		Vector3.new(hs.X + 0.12 * s, hs.Y * 0.25, hs.Z + 0.12 * s),
		C.gold,
		M.Metal
	)
end

function tools.pick(rig, s, look)
	local head, glow = weaponColors(look)
	local len = 2.8 * s
	add(
		rig,
		"RightHand",
		"Handle",
		CFrame.new(0, 0, -len * 0.35) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(len, 0.3 * s, 0.3 * s),
		C.woodDark,
		M.Wood,
		"Cylinder"
	)
	for _, side in { -1, 1 } do
		add(
			rig,
			"RightHand",
			"PickHead",
			CFrame.new(0, side * 0.7 * s, -len * 0.84) * CFrame.Angles(math.rad(side * 18), 0, 0),
			Vector3.new(0.34 * s, 1.5 * s, 0.4 * s),
			head,
			glow and M.Neon or M.Metal
		)
	end
end

function tools.bow(rig, s, look)
	local wood, glow = weaponColors(look)
	wood = look and look.weapon and look.weapon.price and look.weapon.price > 0 and wood or C.wood
	for _, seg in { { 0, 0 }, { 1, 25 }, { -1, -25 } } do
		add(
			rig,
			"LeftHand",
			"Bow",
			CFrame.new(0, seg[1] * 1.15 * s, -0.25 * s + math.abs(seg[1]) * 0.35 * s)
				* CFrame.Angles(math.rad(seg[2]), 0, 0),
			Vector3.new(0.28 * s, 1.4 * s, 0.32 * s),
			wood,
			glow and M.Neon or M.Wood
		)
	end
	add(
		rig,
		"LeftHand",
		"String",
		CFrame.new(0, 0, 0.35 * s),
		Vector3.new(0.06, 3.3 * s, 0.06),
		C.white,
		M.SmoothPlastic
	)
	-- the quiver on the back
	add(
		rig,
		"UpperTorso",
		"Quiver",
		rel(rig, "UpperTorso", 0.25, 0.05, 0.62) * CFrame.Angles(0, 0, math.rad(20)) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(2 * s, 0.7 * s, 0.7 * s),
		C.woodDark,
		M.Leather,
		"Cylinder"
	)
	for k = -1, 1 do
		add(
			rig,
			"UpperTorso",
			"Fletch",
			rel(rig, "UpperTorso", 0.18 + k * 0.08, 0.62, 0.62),
			Vector3.new(0.2, 0.5, 0.06) * s,
			C.red,
			M.SmoothPlastic
		)
	end
end

function tools.staff(rig, s, look, orb)
	local _, glow = weaponColors(look)
	local len = 4.6 * s
	add(
		rig,
		"RightHand",
		"Staff",
		CFrame.new(0, len * 0.25, -0.2 * s) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(len, 0.3 * s, 0.3 * s),
		C.woodDark,
		M.Wood,
		"Cylinder"
	)
	add(
		rig,
		"RightHand",
		"Orb",
		CFrame.new(0, len * 0.76, -0.2 * s),
		Vector3.new(0.9, 0.9, 0.9) * s,
		glow or orb or C.green,
		M.Neon,
		"Ball"
	)
end

function tools.shield(rig, s, look)
	local armor = look and look.armor or Looks.byKey.iron
	add(
		rig,
		"LeftHand",
		"Shield",
		CFrame.new(-0.35 * s, 0.4 * s, 0) * CFrame.Angles(0, 0, 0),
		Vector3.new(0.4 * s, 2.8 * s, 2.8 * s),
		armor.trim or C.iron,
		M.Metal,
		"Cylinder"
	)
	add(
		rig,
		"LeftHand",
		"ShieldFace",
		CFrame.new(-0.6 * s, 0.4 * s, 0),
		Vector3.new(0.2 * s, 2.3 * s, 2.3 * s),
		armor.main or C.steel,
		M.Metal,
		"Cylinder"
	)
	add(
		rig,
		"LeftHand",
		"Boss",
		CFrame.new(-0.75 * s, 0.4 * s, 0),
		Vector3.new(0.7, 0.7, 0.7) * s,
		C.gold,
		M.Metal,
		"Ball"
	)
end

function tools.club(rig, s, col)
	add(
		rig,
		"RightHand",
		"Club",
		CFrame.new(0, 0.2 * s, -1 * s) * CFrame.Angles(math.rad(-75), 0, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(2.6 * s, 0.7 * s, 0.7 * s),
		col,
		M.Wood,
		"Cylinder"
	)
	add(
		rig,
		"RightHand",
		"ClubEnd",
		CFrame.new(0, 0.55 * s, -2.2 * s),
		Vector3.new(1.1, 1.1, 1.1) * s,
		col:Lerp(C.black, 0.15),
		M.Wood,
		"Ball"
	)
end

-- Dwarves -------------------------------------------------------------------------------------------------------
local function beardOf(look)
	return look and look.beard or Looks.byKey.brown
end

local function armorOf(look)
	return look and look.armor or Looks.byKey.iron
end

function Costumes.dwarf(rig, look)
	local s = rig.scale or 1
	local beard = beardOf(look)
	local armor = armorOf(look)
	local beardColor = beard.main
	-- the beard: a big round one under the face, a moustache, and braids for the fancy ones
	add(
		rig,
		"Head",
		"Beard",
		rel(rig, "Head", 0, -0.42, -0.36),
		Vector3.new(1, 0.95, 0.62) * sizeOf(rig, "Head"),
		beardColor,
		M.SmoothPlastic,
		"Ellipsoid"
	)
	add(
		rig,
		"Head",
		"BeardTip",
		rel(rig, "Head", 0, -0.86, -0.32),
		Vector3.new(0.62, 0.5, 0.46) * sizeOf(rig, "Head"),
		beardColor:Lerp(C.black, 0.08),
		M.SmoothPlastic,
		"Ellipsoid"
	)
	for _, side in { -1, 1 } do
		add(
			rig,
			"Head",
			"Moustache",
			rel(rig, "Head", side * 0.2, -0.12, -0.5) * CFrame.Angles(0, 0, math.rad(side * -20)),
			Vector3.new(0.42, 0.2, 0.22) * sizeOf(rig, "Head"),
			beardColor:Lerp(C.black, 0.12),
			M.SmoothPlastic,
			"Ellipsoid"
		)
	end
	if beard.rainbow then
		for k = 1, 3 do
			add(
				rig,
				"Head",
				"Stripe",
				rel(rig, "Head", 0, -0.3 - k * 0.16, -0.66),
				Vector3.new(0.8 - k * 0.12, 0.1, 0.06) * sizeOf(rig, "Head"),
				Looks.RAINBOW[k * 2],
				M.SmoothPlastic
			)
		end
	elseif beard.trim then
		for _, side in { -1, 1 } do
			add(
				rig,
				"Head",
				"Braid",
				rel(rig, "Head", side * 0.22, -1.0, -0.3),
				Vector3.new(0.18, 0.5, 0.18) * sizeOf(rig, "Head"),
				beard.trim,
				M.Metal,
				"Ball"
			)
		end
	end
	-- the helmet: a dome, a rim and a nose guard (horns on fighters)
	add(
		rig,
		"Head",
		"Helmet",
		rel(rig, "Head", 0, 0.2, 0.02),
		Vector3.new(1.16, 0.95, 1.16) * sizeOf(rig, "Head"),
		armor.main,
		M.Metal,
		"Ellipsoid"
	)
	add(
		rig,
		"Head",
		"Rim",
		rel(rig, "Head", 0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.14, 1.22, 1.22) * sizeOf(rig, "Head"),
		armor.trim,
		M.Metal,
		"Cylinder"
	)
	add(
		rig,
		"Head",
		"Spike",
		rel(rig, "Head", 0, 0.66, 0),
		Vector3.new(0.18, 0.18, 0.18) * sizeOf(rig, "Head") * 1.5,
		armor.glow or armor.trim,
		armor.glow and M.Neon or M.Metal,
		"Ball"
	)
	if look and look.job == "fighter" then
		for _, side in { -1, 1 } do
			add(
				rig,
				"Head",
				"Horn",
				rel(rig, "Head", side * 0.56, 0.42, 0) * CFrame.Angles(0, 0, math.rad(side * -35)),
				Vector3.new(0.26, 0.62, 0.26) * sizeOf(rig, "Head"),
				C.cream,
				M.SmoothPlastic,
				"Ellipsoid"
			)
		end
	end
	-- the chest plate, the belt with its buckle and the shoulder pads
	add(
		rig,
		"UpperTorso",
		"Plate",
		rel(rig, "UpperTorso", 0, 0.08, -0.5),
		Vector3.new(0.9, 0.62, 0.16) * sizeOf(rig, "UpperTorso"),
		armor.main,
		M.Metal
	)
	if armor.glow then
		add(
			rig,
			"UpperTorso",
			"Gem",
			rel(rig, "UpperTorso", 0, 0.12, -0.6),
			Vector3.new(0.18, 0.18, 0.18) * sizeOf(rig, "UpperTorso").X,
			armor.glow,
			M.Neon,
			"Ball"
		)
	end
	local beltBone = rig.bones.LowerTorso and "LowerTorso" or "UpperTorso"
	local beltY = beltBone == "LowerTorso" and 0.1 or -0.42
	add(
		rig,
		beltBone,
		"Belt",
		rel(rig, beltBone, 0, beltY, 0),
		Vector3.new(1.06, 0.24 * (beltBone == "LowerTorso" and 2 or 1), 1.1) * sizeOf(rig, beltBone),
		C.woodDark,
		M.Leather
	)
	add(
		rig,
		beltBone,
		"Buckle",
		rel(rig, beltBone, 0, beltY, -0.56),
		Vector3.new(0.26, 0.26 * (beltBone == "LowerTorso" and 2 or 1), 0.06) * sizeOf(rig, beltBone),
		C.gold,
		M.Metal
	)
	for _, side in { "Left", "Right" } do
		local bone = side .. "UpperArm"
		add(
			rig,
			bone,
			"Pad",
			rel(rig, bone, 0, 0.36, 0),
			Vector3.new(1.3, 0.42, 1.3) * sizeOf(rig, bone),
			armor.trim,
			M.Metal,
			"Ellipsoid"
		)
	end
	-- the heavy sack (shown when the bag is full: TeamService sets its transparency)
	local sack = add(
		rig,
		"UpperTorso",
		"Sack",
		rel(rig, "UpperTorso", 0, 0.1, 0.75),
		Vector3.new(1.5, 1.6, 1.1) * s,
		C.dirt:Lerp(C.cream, 0.2),
		M.Fabric,
		"Ellipsoid"
	)
	if sack then
		sack.Transparency = look and look.heavy and 0 or 1
		local rock = add(
			rig,
			"UpperTorso",
			"SackRock",
			rel(rig, "UpperTorso", 0.15, 0.62, 0.8),
			Vector3.new(0.8, 0.6, 0.7) * s,
			C.rock,
			M.SmoothPlastic,
			"Ellipsoid"
		)
		if rock then
			rock.Transparency = sack.Transparency
		end
	end
	-- the job's tool
	local job = look and look.job or "builder"
	if job == "builder" then
		tools.hammer(rig, s, look, false)
	elseif job == "miner" then
		tools.pick(rig, s, look)
		add(
			rig,
			"Head",
			"Lamp",
			rel(rig, "Head", 0, 0.42, -0.5),
			Vector3.new(0.3, 0.3, 0.2) * sizeOf(rig, "Head").X * 1.4,
			C.warm,
			M.Neon,
			"Ball"
		)
	elseif job == "fighter" then
		tools.hammer(rig, s, look, true)
		tools.shield(rig, s, look)
	elseif job == "archer" then
		tools.bow(rig, s, look)
	elseif job == "healer" then
		tools.staff(rig, s, look, C.green)
		add(
			rig,
			"UpperTorso",
			"Cape",
			rel(rig, "UpperTorso", 0, -0.1, 0.62),
			Vector3.new(1, 1.5, 0.12) * sizeOf(rig, "UpperTorso"),
			C.green,
			M.Fabric
		)
	end
end

-- Monsters ------------------------------------------------------------------------------------------------------
-- The mask: a big rounded head over the player's own, with glowing eyes, brows and a toothy grin.
local function mask(rig, col, size, shape)
	local hs = sizeOf(rig, "Head")
	local scale = size or 1.3
	add(
		rig,
		"Head",
		"Mask",
		CFrame.new(),
		Vector3.new(hs.X, hs.Y, hs.Z) * scale,
		col.main,
		M.SmoothPlastic,
		shape or "Ellipsoid"
	)
	for _, side in { -1, 1 } do
		add(
			rig,
			"Head",
			"Eye",
			rel(rig, "Head", side * 0.26 * scale, 0.08 * scale, -0.56 * scale),
			Vector3.new(0.26, 0.3, 0.12) * hs.X * scale,
			col.eyes,
			M.Neon,
			"Ball"
		)
		add(
			rig,
			"Head",
			"Brow",
			rel(rig, "Head", side * 0.27 * scale, 0.3 * scale, -0.56 * scale) * CFrame.Angles(0, 0, math.rad(side * 18)),
			Vector3.new(0.36, 0.1, 0.1) * hs.X * scale,
			col.trim:Lerp(C.black, 0.4),
			M.SmoothPlastic
		)
	end
	add(
		rig,
		"Head",
		"Mouth",
		rel(rig, "Head", 0, -0.26 * scale, -0.56 * scale),
		Vector3.new(0.56, 0.12, 0.1) * hs.X * scale,
		C.black,
		M.SmoothPlastic
	)
	for _, side in { -1, 1 } do
		add(
			rig,
			"Head",
			"Tooth",
			rel(rig, "Head", side * 0.14 * scale, -0.2 * scale, -0.6 * scale),
			Vector3.new(0.1, 0.14, 0.06) * hs.X * scale,
			C.white,
			M.SmoothPlastic
		)
	end
end

local function skinBody(rig, col)
	-- paint the body parts (NPC rigs and players' blocky monster bodies); clothes stay off monsters
	for name, b in rig.bones do
		if name ~= "Head" and b:IsA("BasePart") and b.Transparency < 1 then
			b.Color = string.find(name, "Leg") and col.cloth or col.main
		end
	end
end
Costumes.skinBody = skinBody

local monsters = {}

function monsters.grunt(rig, col, s)
	mask(rig, col, 1.3)
	for _, side in { -1, 1 } do
		add(
			rig,
			"Head",
			"Ear",
			rel(rig, "Head", side * 0.78, 0.12, 0)
				* CFrame.Angles(0, 0, math.rad(side * 70))
				* CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0),
			Vector3.new(0.3, 0.7, 1.1) * sizeOf(rig, "Head").X,
			col.main,
			M.SmoothPlastic,
			"Wedge"
		)
		add(
			rig,
			"Head",
			"Tusk",
			rel(rig, "Head", side * 0.22, -0.48, -0.5) * CFrame.Angles(math.rad(-15), 0, 0),
			Vector3.new(0.12, 0.3, 0.12) * sizeOf(rig, "Head").X * 1.4,
			C.cream,
			M.SmoothPlastic,
			"Ellipsoid"
		)
	end
	add(
		rig,
		"UpperTorso",
		"Strap",
		rel(rig, "UpperTorso", 0, 0, -0.04) * CFrame.Angles(0, 0, math.rad(40)),
		Vector3.new(0.22, 1.5, 1.08) * sizeOf(rig, "UpperTorso").X,
		col.cloth,
		M.Leather
	)
	tools.club(rig, s, C.woodLight)
end

function monsters.brute(rig, col, s)
	mask(rig, col, 1.35)
	for _, side in { -1, 1 } do
		add(
			rig,
			"Head",
			"Horn",
			rel(rig, "Head", side * 0.55, 0.62, -0.05) * CFrame.Angles(0, 0, math.rad(side * -40)),
			Vector3.new(0.34, 0.95, 0.34) * sizeOf(rig, "Head").X,
			C.cream,
			M.SmoothPlastic,
			"Ellipsoid"
		)
		local arm = side < 0 and "LeftUpperArm" or "RightUpperArm"
		add(
			rig,
			arm,
			"Spikes",
			rel(rig, arm, 0, 0.4, 0),
			Vector3.new(1.6, 0.6, 1.6) * sizeOf(rig, arm),
			col.trim,
			M.SmoothPlastic,
			"Ellipsoid"
		)
		add(
			rig,
			arm,
			"Spike",
			rel(rig, arm, side * 0.2, 0.75, 0),
			Vector3.new(0.4, 0.5, 0.4) * sizeOf(rig, arm).X,
			C.cream,
			M.SmoothPlastic,
			"Ball"
		)
		local hand = side < 0 and "LeftHand" or "RightHand"
		add(
			rig,
			hand,
			"Fist",
			CFrame.new(),
			Vector3.new(1.7, 1.7, 1.7) * math.max(0.6, sizeOf(rig, hand).X),
			col.main:Lerp(col.trim, 0.25),
			M.SmoothPlastic,
			"Ball"
		)
	end
	add(
		rig,
		"UpperTorso",
		"Belly",
		rel(rig, "UpperTorso", 0, -0.18, -0.38),
		Vector3.new(0.9, 0.8, 0.5) * sizeOf(rig, "UpperTorso"),
		col.main:Lerp(C.cream, 0.25),
		M.SmoothPlastic,
		"Ellipsoid"
	)
	_ = s
end

function monsters.spitter(rig, col, s)
	mask(rig, col, 1.25)
	for k = -1, 1 do
		add(
			rig,
			"Head",
			"Frill",
			rel(rig, "Head", 0, 0.55, 0.15 + k * 0.25) * CFrame.Angles(math.rad(-20 + k * 20), 0, 0),
			Vector3.new(0.12, 0.6, 0.5) * sizeOf(rig, "Head").X,
			col.trim,
			M.SmoothPlastic,
			"Wedge"
		)
	end
	add(
		rig,
		"Head",
		"Drip",
		rel(rig, "Head", 0.18, -0.48, -0.55),
		Vector3.new(0.16, 0.26, 0.16) * sizeOf(rig, "Head").X * 1.4,
		col.trim,
		M.Neon,
		"Ellipsoid"
	)
	add(
		rig,
		"UpperTorso",
		"Sac",
		rel(rig, "UpperTorso", 0, 0.15, 0.8),
		Vector3.new(1.7, 1.7, 1.4) * s,
		col.trim,
		M.Neon,
		"Ellipsoid",
		{ Transparency = 0.15 }
	)
	for k = 1, 3 do
		add(
			rig,
			"UpperTorso",
			"Spot",
			rel(rig, "UpperTorso", -0.3 + k * 0.18, 0.3 - k * 0.2, -0.52),
			Vector3.new(0.3, 0.3, 0.1) * s,
			col.trim,
			M.SmoothPlastic,
			"Ball"
		)
	end
end

function monsters.witch(rig, col, s)
	mask(rig, col, 1.2)
	-- the pointy hat: a wide brim and three tapering layers, with a band
	add(
		rig,
		"Head",
		"Brim",
		rel(rig, "Head", 0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.14 * sizeOf(rig, "Head").Y, 2.2 * sizeOf(rig, "Head").X, 2.2 * sizeOf(rig, "Head").X),
		col.trim,
		M.Fabric,
		"Cylinder"
	)
	for k = 1, 3 do
		add(
			rig,
			"Head",
			"Hat",
			rel(rig, "Head", 0.05 * k, 0.6 + k * 0.42, 0.06 * k) * CFrame.Angles(math.rad(-6 * k), 0, math.rad(90)),
			Vector3.new(
				0.5 * sizeOf(rig, "Head").Y,
				(1.3 - k * 0.32) * sizeOf(rig, "Head").X,
				(1.3 - k * 0.32) * sizeOf(rig, "Head").X
			),
			col.trim,
			M.Fabric,
			"Cylinder"
		)
	end
	add(
		rig,
		"Head",
		"Band",
		rel(rig, "Head", 0, 0.78, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.18 * sizeOf(rig, "Head").Y, 1.34 * sizeOf(rig, "Head").X, 1.34 * sizeOf(rig, "Head").X),
		Costumes.MONSTER.spitter.trim,
		M.Neon,
		"Cylinder"
	)
	-- the robe: a long skirt that floats
	local base = rig.bones.LowerTorso and "LowerTorso" or "UpperTorso"
	for k = 1, 3 do
		add(
			rig,
			base,
			"Robe",
			rel(rig, base, 0, (base == "LowerTorso" and -0.6 or -0.9) - k * (base == "LowerTorso" and 0.9 or 0.45), 0)
				* CFrame.Angles(0, 0, math.rad(90)),
			Vector3.new(1.1 * s, (1.5 + k * 0.45) * s, (1.4 + k * 0.4) * s),
			col.trim:Lerp(C.black, k * 0.06),
			M.Fabric,
			"Cylinder"
		)
	end
	tools.staff(rig, s, nil, col.glow or C.crystalPink)
end

function monsters.breaker(rig, col, s)
	mask(rig, col, 1.28)
	add(
		rig,
		"Head",
		"Helm",
		rel(rig, "Head", 0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Vector3.new(0.5 * sizeOf(rig, "Head").Y, 1.1 * sizeOf(rig, "Head").X, 1.1 * sizeOf(rig, "Head").X),
		C.iron,
		M.Metal,
		"Cylinder"
	)
	for k = -1, 1 do
		add(
			rig,
			"Head",
			"HelmSpike",
			rel(rig, "Head", k * 0.3, 0.78, 0),
			Vector3.new(0.2, 0.4, 0.2) * sizeOf(rig, "Head").X,
			C.steel,
			M.Metal,
			"Ellipsoid"
		)
	end
	-- the big log over the right shoulder
	add(
		rig,
		"RightUpperArm",
		"Log",
		rel(rig, "RightUpperArm", 0, 0.75, 0.2) * CFrame.Angles(0, math.rad(90), math.rad(-12)),
		Vector3.new(6.2 * s, 1.6 * s, 1.6 * s),
		C.bark:Lerp(C.woodLight, 0.2),
		M.Wood,
		"Cylinder"
	)
	-- the bomb belt
	local base = rig.bones.LowerTorso and "LowerTorso" or "UpperTorso"
	for k = -1, 1 do
		add(
			rig,
			base,
			"Bomb",
			rel(rig, base, k * 0.32, base == "LowerTorso" and 0 or -0.4, -0.6),
			Vector3.new(0.7, 0.7, 0.7) * s,
			C.black,
			M.SmoothPlastic,
			"Ball"
		)
		add(
			rig,
			base,
			"Fuse",
			rel(rig, base, k * 0.32, base == "LowerTorso" and 0.5 or -0.2, -0.6),
			Vector3.new(0.12, 0.3, 0.12) * s,
			C.fire,
			M.Neon
		)
	end
end

function monsters.imp(rig, col, s)
	mask(rig, col, 1.25)
	for _, side in { -1, 1 } do
		add(
			rig,
			"Head",
			"Horn",
			rel(rig, "Head", side * 0.36, 0.62, 0) * CFrame.Angles(0, 0, math.rad(side * -25)),
			Vector3.new(0.18, 0.45, 0.18) * sizeOf(rig, "Head").X,
			col.trim,
			M.SmoothPlastic,
			"Ellipsoid"
		)
		add(
			rig,
			"UpperTorso",
			"Wing",
			rel(rig, "UpperTorso", side * 0.9, 0.35, 0.55) * CFrame.Angles(0, math.rad(side * 30), math.rad(side * -20)),
			Vector3.new(0.15, 1.6, 1.6) * s,
			col.trim,
			M.SmoothPlastic,
			"Wedge"
		)
	end
end

function monsters.scout(rig, col, s)
	mask(rig, col, 1.25)
	add(
		rig,
		"Head",
		"Hood",
		rel(rig, "Head", 0, 0.18, 0.12),
		Vector3.new(1.42, 1.32, 1.42) * sizeOf(rig, "Head"),
		col.trim,
		M.Fabric,
		"Ellipsoid"
	)
	for _, side in { -1, 1 } do
		add(
			rig,
			"Head",
			"Ear",
			rel(rig, "Head", side * 0.75, 0.05, 0)
				* CFrame.Angles(0, 0, math.rad(side * 70))
				* CFrame.Angles(0, side > 0 and math.rad(90) or math.rad(-90), 0),
			Vector3.new(0.25, 0.5, 0.8) * sizeOf(rig, "Head").X,
			col.main,
			M.SmoothPlastic,
			"Wedge"
		)
	end
	tools.club(rig, s * 0.8, C.wood)
end

function Costumes.monster(rig, look)
	local job = look and look.job or "grunt"
	local col = Costumes.monsterColors(job, look and look.skin)
	skinBody(rig, col)
	local build = monsters[job] or monsters.grunt
	build(rig, col, rig.scale or 1)
	if col.glow and job ~= "witch" then
		add(
			rig,
			"UpperTorso",
			"Glow",
			rel(rig, "UpperTorso", 0, 0.1, -0.56),
			Vector3.new(0.3, 0.3, 0.1) * (rig.scale or 1),
			col.glow,
			M.Neon,
			"Ball"
		)
	end
end

function Costumes.dress(rig, look)
	if look and look.team == "monster" then
		Costumes.monster(rig, look)
	else
		Costumes.dwarf(rig, look)
	end
end

-- NPC rigs -------------------------------------------------------------------------------------------------------
-- A small rig for an NPC: anchored body parts moved every frame (no physics, no Humanoid). Joints and sizes are
-- for scale 1 (a regular grunt: about 6 studs tall).
local BONES = {
	{ name = "LowerTorso", size = Vector3.new(1.9, 1, 1.15) },
	{ name = "UpperTorso", size = Vector3.new(2.1, 1.7, 1.2) },
	{ name = "Head", size = Vector3.new(1.6, 1.6, 1.6) },
	{ name = "LeftUpperArm", size = Vector3.new(0.85, 2, 0.85) },
	{ name = "RightUpperArm", size = Vector3.new(0.85, 2, 0.85) },
	{ name = "LeftHand", size = Vector3.new(0.8, 0.8, 0.8), ball = true },
	{ name = "RightHand", size = Vector3.new(0.8, 0.8, 0.8), ball = true },
	{ name = "LeftUpperLeg", size = Vector3.new(0.95, 2.2, 0.95) },
	{ name = "RightUpperLeg", size = Vector3.new(0.95, 2.2, 0.95) },
}
Costumes.NPC_SCALE = {
	grunt = 1,
	brute = 1.45,
	spitter = 0.95,
	witch = 1,
	breaker = 1.02,
	imp = 0.6,
	scout = 0.8,
	dwarf = 0.86,
}
Costumes.NPC_WIDE = { dwarf = 1.2, brute = 1.15 } -- dwarves are short and wide

-- Build an NPC model: { model, bones, parts = { { part, bone, offset } }, scale, kind }.
-- look: { team, job, skin, armor, beard, shirt } (dwarf NPCs wear `shirt`).
function Costumes.npc(kind, look, parent)
	local s = Costumes.NPC_SCALE[kind] or 1
	local wide = Costumes.NPC_WIDE[kind] or 1
	local model = Instance.new("Model")
	model.Name = kind
	local npc = { model = model, bones = {}, parts = {}, scale = s, kind = kind, wide = wide }
	local monster = kind ~= "dwarf"
	local col = monster and Costumes.monsterColors(kind, look and look.skin) or nil
	for _, b in BONES do
		local size = b.size * s
		if b.name ~= "Head" then
			size = Vector3.new(size.X * wide, size.Y, size.Z * wide)
		end
		local color
		if monster then
			color = string.find(b.name, "Leg") and col.cloth or col.main
		elseif b.name == "Head" or string.find(b.name, "Hand") then
			color = Costumes.SKIN
		elseif string.find(b.name, "Leg") or b.name == "LowerTorso" then
			color = rgb(110, 76, 52)
		else
			color = look and look.shirt or Costumes.DWARF_SHIRTS[1]
		end
		local p = Kit.part({
			Name = b.name,
			Size = size,
			Color = color,
			Material = M.SmoothPlastic,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = b.name == "UpperTorso",
			Parent = model,
		})
		if b.ball or b.name == "Head" then
			p.Shape = Enum.PartType.Ball
		end
		npc.bones[b.name] = p
	end
	model.PrimaryPart = npc.bones.UpperTorso
	local rig = {
		bones = npc.bones,
		scale = s,
		anchored = true,
		parent = model,
		add = function(bone, part, offset)
			table.insert(npc.parts, { part = part, bone = bone, offset = offset })
		end,
	}
	local dressLook = table.clone(look or {})
	dressLook.job = kind == "dwarf" and (dressLook.job or "builder") or kind
	dressLook.team = monster and "monster" or "dwarf"
	Costumes.dress(rig, dressLook)
	model.Parent = parent
	return npc
end

-- Where every bone of an NPC goes for a pose. root: the CFrame on the ground (feet), facing -Z.
-- pose: { walk = phase (radians), stride = 0..1, swing = 0..1 (an attack: wind-up then strike), hit = 0..1
--         (flinch), carry = bool (arms forward, a rock on the head), cheer = 0..1, fall = 0..1 (dying),
--         float = studs (the witch) }
local SWING_UP, SWING_DOWN = math.rad(-150), math.rad(-40)
function Costumes.pose(npc, root, pose)
	local s = npc.scale
	local wide = npc.wide or 1
	pose = pose or {}
	local walk = pose.walk or 0
	local stride = pose.stride or 0
	local legA = math.sin(walk) * 0.6 * stride
	local armA = math.sin(walk) * 0.5 * stride
	local bob = math.abs(math.cos(walk)) * 0.25 * stride * s
	local lean = (pose.hit or 0) * -0.35 + stride * 0.08
	local fall = pose.fall or 0
	local base = root
	if fall > 0 then
		base = root * CFrame.new(0, -fall * 1.2 * s, 0) * CFrame.Angles(-fall * math.rad(80), 0, 0)
	end
	base = base * CFrame.new(0, bob + (pose.float or 0), 0)
	local hipY = 2.2 * s
	local waist = base * CFrame.new(0, hipY + 0.5 * s, 0) * CFrame.Angles(lean, 0, 0)
	local bones = npc.bones
	local out = {}
	out.LowerTorso = base * CFrame.new(0, hipY + 0.2 * s, 0)
	out.UpperTorso = waist * CFrame.new(0, 0.85 * s, 0)
	out.Head = waist * CFrame.new(0, 2.4 * s, 0) * CFrame.Angles((pose.hit or 0) * -0.3, 0, 0)
	-- the right arm: walking swing, or the attack (wind up high, then strike down), or carrying, or cheering
	local swing = pose.swing or 0
	local rArm
	if swing > 0 then
		local a
		if swing < 0.55 then
			a = SWING_UP * (swing / 0.55)
		else
			a = SWING_UP + (SWING_DOWN - SWING_UP) * math.min(1, (swing - 0.55) / 0.2)
		end
		rArm = CFrame.Angles(a, 0, 0)
	elseif pose.carry then
		rArm = CFrame.Angles(math.rad(-150), 0, math.rad(-15))
	elseif (pose.cheer or 0) > 0 then
		rArm = CFrame.Angles(math.rad(-170), 0, math.rad(-10 - 20 * math.sin(pose.cheer * 12)))
	else
		rArm = CFrame.Angles(-armA, 0, math.rad(4))
	end
	local lArm
	if pose.carry then
		lArm = CFrame.Angles(math.rad(-150), 0, math.rad(15))
	elseif (pose.cheer or 0) > 0 then
		lArm = CFrame.Angles(math.rad(-170), 0, math.rad(10 + 20 * math.sin(pose.cheer * 12)))
	else
		lArm = CFrame.Angles(armA, 0, math.rad(-4))
	end
	local shoulderY = 1.55 * s
	local shoulderX = 1.48 * s * wide
	local rShoulder = waist * CFrame.new(shoulderX, shoulderY, 0) * rArm
	local lShoulder = waist * CFrame.new(-shoulderX, shoulderY, 0) * lArm
	out.RightUpperArm = rShoulder * CFrame.new(0, -0.95 * s, 0)
	out.LeftUpperArm = lShoulder * CFrame.new(0, -0.95 * s, 0)
	out.RightHand = rShoulder * CFrame.new(0, -2.05 * s, 0)
	out.LeftHand = lShoulder * CFrame.new(0, -2.05 * s, 0)
	out.RightUpperLeg = base
		* CFrame.new(0.52 * s * wide, hipY, 0)
		* CFrame.Angles(-legA, 0, 0)
		* CFrame.new(0, -1.1 * s, 0)
	out.LeftUpperLeg = base
		* CFrame.new(-0.52 * s * wide, hipY, 0)
		* CFrame.Angles(legA, 0, 0)
		* CFrame.new(0, -1.1 * s, 0)
	local parts, cframes = {}, {}
	for name, cf in out do
		local b = bones[name]
		if b then
			table.insert(parts, b)
			table.insert(cframes, cf)
		end
	end
	for _, a in npc.parts do
		local cf = out[a.bone]
		if cf then
			table.insert(parts, a.part)
			table.insert(cframes, cf * a.offset)
		end
	end
	return parts, cframes
end

-- Pose and move an NPC right away (the render tools; the client batches many NPCs into one BulkMoveTo).
function Costumes.place(npc, root, pose)
	local parts, cframes = Costumes.pose(npc, root, pose)
	for i, p in parts do
		p.CFrame = cframes[i]
	end
end

return Costumes
