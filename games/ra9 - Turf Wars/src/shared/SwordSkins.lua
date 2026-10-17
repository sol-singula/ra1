--[[
The blade, in every sword skin (Data/Cosmetics kind "sword"): the same plain box parts wherever it's drawn, so the
one in your hand (WeaponController's view model), the one in everyone else's (CombatService:HoldBow, welded by the
server), the shop's pictures (UI/Icons), the live previews (UI/ItemPreview) and the Crate's rack (CrateController)
all build from one list. The client brings a skin alive with FX/Flair.sword (its moving colours, particles, arcs,
the sticker).

Everything is laid out in the hilt's frame: the grip's middle at the origin, the blade along -Z, the edge's bright
line (the bevel) on the -Y side. A look's shape says which parts: sword (the plain one: grip, pommel, guard, gem,
edge, bevel, spine, tip), katana (long and thin, a flat square tsuba), gladius (short and wide), cleaver (a big
slab with a glowing edge line), pixel (a stair of cubes), saber (a neon bar out of a dark hilt), scythe (a long
pole with the blade across its end).

  SwordSkins.PLAIN                  the plain steel look (no skin equipped)
  SwordSkins.lookOf(key)            a sword cosmetic's look (nil or anything else: PLAIN)
  SwordSkins.specs(look, team)      { { name, size, offset (CFrame), color, token, material, transparency?, tint? } }
  SwordSkins.build(holder, look, team, opts?) -> sword   the parts made under holder; opts = { scale?, anchored? }
  SwordSkins.place(sword, hilt)     every part's CFrame from the hilt's (each frame, the view model)
  SwordSkins.adopt(model, look, team) -> sword   the server's parts (by name) as a sword, for Flair.sword
  SwordSkins.length(look)           studs from the grip's middle to the tip
  SwordSkins.trailToken(look)       the colour token its slash streak is drawn in (nil: plain, the team's)
]]
local Cosmetics = require(script.Parent.Data.Cosmetics)

local SwordSkins = {}

SwordSkins.PLAIN = Cosmetics.SWORD["Steel"]

function SwordSkins.lookOf(key)
	local it = Cosmetics.get(key)
	return it and it.kind == "sword" and it.look or SwordSkins.PLAIN
end

-- (these anims light the edge's lines up: Neon)
local GLOW = { neon = true, ember = true, rainbow = true, electric = true, shadow = true, pulse = true }

local function spec(list, name, size, offset, token, material, transparency)
	table.insert(list, {
		name = name,
		size = size,
		offset = offset,
		token = token,
		material = material or "SmoothPlastic",
		transparency = transparency,
	})
end

-- The hilt: the grip (gripLen long), the pommel behind it, the guard and its gem in front
local function hilt(list, look, gripLen, guard, pommel, gripMaterial)
	spec(list, "Grip", Vector3.new(0.25, 0.25, gripLen), CFrame.new(0, 0, 0), look.grip, gripMaterial or "Fabric")
	if pommel then
		spec(list, "Pommel", pommel, CFrame.new(0, 0, gripLen / 2 + pommel.Z / 2 - 0.02), look.guard)
	end
	local z = -(gripLen / 2 + guard.Z / 2 - 0.02)
	spec(list, "Guard", guard, CFrame.new(0, 0, z), look.guard)
	spec(list, "Gem", Vector3.new(0.18, 0.18, guard.Z + 0.1), CFrame.new(0, 0, z), look.gem, "Neon")
	return -(gripLen / 2 + guard.Z) - 0.03 -- (where the blade starts)
end

-- A straight blade: L long, w thick, h tall, its middle at y; the bevel along its underside, the spine along the
-- top, a diamond tip
local function blade(list, look, start, L, w, h, y, edgeMat, tip)
	local z = start - L / 2
	local glow = GLOW[look.anim] and "Neon" or nil
	spec(list, "Edge", Vector3.new(w, h, L), CFrame.new(0, y, z), look.edge, edgeMat)
	spec(list, "Bevel", Vector3.new(w + 0.01, 0.06, L - 0.1), CFrame.new(0, y - h / 2 + 0.03, z), look.bevel, glow)
	if look.spine then
		spec(
			list,
			"Spine",
			Vector3.new(w + 0.01, 0.06, L * 0.8),
			CFrame.new(0, y + h / 2 - 0.03, z + L * 0.1),
			look.spine,
			glow
		)
	end
	local t = tip or h * 0.73
	spec(
		list,
		"Tip",
		Vector3.new(w, t, t),
		CFrame.new(0, y, start - L - t * 0.6) * CFrame.Angles(math.rad(45), 0, 0),
		look.edge,
		edgeMat
	)
end

local SHAPE = {}
function SHAPE.sword(list, look)
	local start = hilt(list, look, 0.75, Vector3.new(0.9, 0.2, 0.2), Vector3.new(0.32, 0.32, 0.22))
	blade(list, look, start, 2.4, 0.12, 0.3, 0, look.material)
end
function SHAPE.katana(list, look)
	-- long and thin, a flat square tsuba, the edge line lit
	local start = hilt(list, look, 1.05, Vector3.new(0.5, 0.5, 0.07), Vector3.new(0.27, 0.27, 0.12))
	blade(list, look, start, 2.8, 0.07, 0.22, 0, look.anim == "electric" and "Neon" or look.material)
end
function SHAPE.gladius(list, look)
	-- short and wide, a heavy pommel
	local start = hilt(list, look, 0.7, Vector3.new(0.75, 0.28, 0.26), Vector3.new(0.42, 0.42, 0.3))
	blade(list, look, start, 1.7, 0.14, 0.44, 0, look.material, 0.34)
end
function SHAPE.cleaver(list, look)
	-- a big slab rising above the hilt, its edge line and its back lit, a squared-off end
	local start = hilt(list, look, 0.8, Vector3.new(0.5, 0.5, 0.22), Vector3.new(0.34, 0.34, 0.2))
	local L, h, y = 2.2, 0.75, 0.18
	local z = start - L / 2
	local glow = GLOW[look.anim] and "Neon" or nil
	spec(list, "Edge", Vector3.new(0.16, h, L), CFrame.new(0, y, z), look.edge, look.material)
	spec(list, "Bevel", Vector3.new(0.17, 0.08, L - 0.1), CFrame.new(0, y - h / 2 + 0.04, z), look.bevel, glow)
	spec(
		list,
		"Spine",
		Vector3.new(0.17, 0.08, L * 0.6),
		CFrame.new(0, y + h / 2 - 0.04, z + L * 0.2),
		look.spine,
		glow
	)
	spec(list, "Tip", Vector3.new(0.16, 0.5, 0.3), CFrame.new(0, y + 0.12, start - L - 0.15), look.edge, look.material)
end
function SHAPE.pixel(list, look)
	-- a stair of cubes: three for the grip, one for the pommel, three across for the guard, seven up the blade
	-- (the edge's and the bevel's colours turn about), the last two smaller for the point
	for i = 0, 2 do
		spec(
			list,
			i == 0 and "Grip" or "Grip" .. i,
			Vector3.new(0.28, 0.28, 0.28),
			CFrame.new(0, 0, (i - 1) * 0.28),
			look.grip
		)
	end
	spec(list, "Pommel", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0, 0.58), look.gem, "Neon")
	for i = -1, 1 do
		spec(
			list,
			i == 0 and "Guard" or "Guard" .. (i + 2),
			Vector3.new(0.3, 0.3, 0.3),
			CFrame.new(i * 0.3, 0, -0.44),
			look.guard
		)
	end
	spec(list, "Gem", Vector3.new(0.12, 0.32, 0.12), CFrame.new(0, 0, -0.44), look.gem, "Neon")
	for i = 1, 7 do
		local s = i <= 5 and 0.3 or (i == 6 and 0.22 or 0.15)
		local z = -0.44 - 0.15 - 0.3 * (i - 1) - s / 2 + 0.15
		spec(
			list,
			i == 1 and "Edge" or "Pixel" .. i,
			Vector3.new(s, s, s),
			CFrame.new(0, 0, z),
			i % 2 == 1 and look.edge or look.bevel
		)
	end
end
function SHAPE.saber(list, look)
	-- a dark hilt, a lit bar out of it, a button in its colour on the grip
	spec(list, "Grip", Vector3.new(0.22, 0.22, 0.9), CFrame.new(0, 0, 0), look.grip, "SmoothPlastic")
	spec(list, "Pommel", Vector3.new(0.26, 0.26, 0.1), CFrame.new(0, 0, 0.5), look.guard)
	spec(list, "Guard", Vector3.new(0.3, 0.3, 0.35), CFrame.new(0, 0, -0.6), look.guard)
	spec(list, "Gem", Vector3.new(0.1, 0.12, 0.22), CFrame.new(0, 0.14, 0.05), look.gem, "Neon")
	local L = 2.6
	spec(list, "Edge", Vector3.new(0.1, 0.1, L), CFrame.new(0, 0, -0.78 - L / 2), look.edge, "Neon")
	spec(list, "Bevel", Vector3.new(0.04, 0.04, L + 0.04), CFrame.new(0, 0, -0.78 - L / 2), look.bevel, "Neon")
	spec(
		list,
		"Tip",
		Vector3.new(0.1, 0.1, 0.1),
		CFrame.new(0, 0, -0.78 - L - 0.05) * CFrame.Angles(math.rad(45), 0, 0),
		look.edge,
		"Neon"
	)
end
function SHAPE.scythe(list, look)
	-- a long pole, a dark blade across its end (out to -X), its lines lit, a hooked point
	spec(list, "Grip", Vector3.new(0.18, 0.18, 2.9), CFrame.new(0, 0, -0.75), look.grip, "SmoothPlastic")
	spec(list, "Pommel", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, 0, 0.82), look.guard)
	spec(list, "Guard", Vector3.new(0.3, 0.3, 0.4), CFrame.new(0, 0, -2.2), look.guard)
	spec(list, "Gem", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 0.22, -2.2), look.gem, "Neon")
	local glow = GLOW[look.anim] and "Neon" or nil
	spec(list, "Edge", Vector3.new(2.0, 0.3, 0.14), CFrame.new(-0.85, 0, -2.35), look.edge, look.material)
	spec(list, "Bevel", Vector3.new(1.9, 0.06, 0.15), CFrame.new(-0.85, -0.14, -2.35), look.bevel, glow)
	spec(list, "Spine", Vector3.new(1.4, 0.06, 0.15), CFrame.new(-0.75, 0.11, -2.35), look.spine, glow)
	spec(
		list,
		"Tip",
		Vector3.new(0.14, 0.3, 0.3),
		CFrame.new(-1.95, -0.06, -2.35) * CFrame.Angles(0, 0, math.rad(45)),
		look.edge,
		look.material
	)
end

-- A token's tint for UI/Icons.paint (the team's colour follows a team change)
local function tintOf(token)
	if token == "team" then
		return 0
	elseif token == "light" then
		return 0.5
	end
	return nil
end

function SwordSkins.specs(look, team)
	look = look or SwordSkins.PLAIN
	local list = {}
	local make = SHAPE[look.shape] or SHAPE.sword
	make(list, look)
	for _, s in list do
		s.color = Cosmetics.color(s.token, team)
		s.tint = tintOf(s.token)
		if look.anim == "frost" and (s.name == "Edge" or s.name == "Tip") then
			s.transparency = 0.12
		end
	end
	return list
end

function SwordSkins.build(holder, look, team, opts)
	opts = opts or {}
	look = look or SwordSkins.PLAIN
	local sword = { parts = {}, look = look, team = team, scale = opts.scale or 1, holder = holder }
	for _, s in SwordSkins.specs(look, team) do
		local p = Instance.new("Part")
		p.Name = s.name
		p.Anchored = opts.anchored ~= false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Size = s.size * sword.scale
		p.Color = s.color
		p.Material = Enum.Material[s.material] or Enum.Material.SmoothPlastic
		p.Transparency = s.transparency or 0
		if s.tint then
			p:SetAttribute("Tint", s.tint)
		end
		p.Parent = holder
		table.insert(sword.parts, { part = p, offset = s.offset, token = s.token, name = s.name })
	end
	return sword
end

function SwordSkins.place(sword, at)
	local k = sword.scale
	for _, e in sword.parts do
		local o = e.offset
		e.part.CFrame = at * (k == 1 and o or (CFrame.new(o.Position * k) * o.Rotation))
	end
end

-- The parts the server built (CombatService:HoldBow), matched by name to the look's list
function SwordSkins.adopt(model, look, team)
	look = look or SwordSkins.PLAIN
	local sword = { parts = {}, look = look, team = team, scale = 1, holder = model }
	for _, s in SwordSkins.specs(look, team) do
		local p = model:FindFirstChild(s.name)
		if p then
			table.insert(sword.parts, { part = p, offset = s.offset, token = s.token, name = s.name })
		end
	end
	return sword
end

function SwordSkins.length(look)
	local far = 0
	for _, s in SwordSkins.specs(look, "red") do
		far = math.max(far, -s.offset.Position.Z + s.size.Z / 2)
	end
	return far
end

function SwordSkins.trailToken(look)
	if not look or look == SwordSkins.PLAIN then
		return nil
	end
	local token = look.trail or look.edge
	return type(token) == "string" and token or nil
end

return SwordSkins
