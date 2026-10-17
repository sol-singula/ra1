--[[
What each structure looks like, as a list of parts, shared by the server (BuildService builds it in the world), the
hotbar (UI/Icons draws it in a ViewportFrame) and the debris (DebrisController breaks the same shapes into chunks
when it comes down), so all three always agree.

Castle pieces, kept plain like the maps: white and pale grey blocks (a touch of the team's colour in them), no
browns or orange, and the team's colour where a castle wears it: the coping and
the merlons on the walls, the tower's platform and roof, the rampart's trim, the shield's band, every banner. Only
boxes: nothing round anywhere (no balls, no cylinders), and few, large parts (most players are on phones
and a match fills up with pieces). Nothing solid reaches outside the footprint box or far above its height, so the
building rules, the arrows' boxes and the tests see the same piece as before; trim and detail are not solid.

  StructureModel.parts(key, team, min, max)   { { name, cf, size, tone, solid, flag?, glow? } }
  StructureModel.color(tone, team)            "stone" | "stoneDark" | "mortar" | "wood" | "woodDark" | "iron" |
                                              "team" | "teamDark" | "flame" | "glow" (and the old "build" | "armor")
  StructureModel.make(spec, team)             a Part for one entry, its tone in a "Tone" attribute
]]
local Constants = require(script.Parent.Constants)

local StructureModel = {}

local Y = Vector3.new(0, 1, 0)

-- The palette: plain, like the maps: white and pale grey with a touch of the team in them (so a piece's body leans
-- red or blue), the trim in the team's own build shade. No browns, no orange: "wood" and "iron" are just lighter and
-- darker greys now, and the torch's flame and the rally marker glow in the team's colour.
local STONE = Color3.fromRGB(236, 236, 240)
local STONE_DARK = Color3.fromRGB(176, 178, 186)
local LIGHT = Color3.fromRGB(214, 216, 222) -- ("wood": planks, posts, the door)
local MID = Color3.fromRGB(150, 152, 160) -- ("woodDark", "iron": bands, brackets, rungs)
local GLOWS = { flame = true, glow = true } -- (Neon: the torch's flame, the Rally Banner's marker)

function StructureModel.color(tone, team)
	local build = Constants.BUILD_COLOR[team or ""] or Constants.BUILD_COLOR.red
	local armor = Constants.ARMOR_COLOR[team or ""] or Constants.ARMOR_COLOR.red
	if tone == "stone" then
		return STONE:Lerp(build, 0.12)
	elseif tone == "stoneDark" then
		return STONE_DARK:Lerp(armor, 0.22)
	elseif tone == "wood" then
		return LIGHT:Lerp(build, 0.1)
	elseif tone == "woodDark" or tone == "iron" or tone == "mortar" then
		return MID:Lerp(armor, 0.15)
	elseif tone == "teamDark" or tone == "armor" then
		return armor
	end
	return build -- "team", "glow", "flame" (and the old "build")
end

function StructureModel.parts(key, team, mn, mx)
	local out = {}
	local size = mx - mn
	local mid = (mn + mx) / 2
	local base = Vector3.new(mid.X, mn.Y, mid.Z)
	-- the piece's own frame: A along its long side (X for a square piece), C across, Y up
	local A = size.X >= size.Z - 0.01 and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
	local C = A:Cross(Y)
	local L = A.X == 1 and size.X or size.Z
	local T = A.X == 1 and size.Z or size.X
	local h = size.Y
	-- (the enemy's side, along A: red looks toward +X; only square pieces care, their A is X)
	local f = team == "blue" and -1 or 1
	-- (the home side across C, for a long piece turned to face the enemy; +C when it runs along the line)
	local home = C.X ~= 0 and (C.X * -f > 0 and 1 or -1) or 1
	local function frame(a, y, c)
		return CFrame.fromMatrix(base + A * a + Y * y + C * c, A, Y, C)
	end
	-- a box in `tone` at (a, y, c) in the frame (y its middle), la x ly x lc
	local function box(name, tone, a, y, c, la, ly, lc, solid, turn)
		local e = {
			name = name,
			cf = frame(a, y, c) * (turn or CFrame.new()),
			size = Vector3.new(la, ly, lc),
			tone = tone,
			solid = solid ~= false,
		}
		if tone ~= "mortar" then
			table.insert(out, e) -- (no mortar lines: the blocks stay plain)
		end
		return e
	end
	-- a square bar in the face plane at across c, from (a0, y0) to (a1, y1)
	local function brace(name, tone, c, a0, y0, a1, y1, thick, solid)
		local da, dy = a1 - a0, y1 - y0
		local len = math.sqrt(da * da + dy * dy)
		local turn = CFrame.fromAxisAngle(Vector3.new(0, 0, 1), math.atan2(dy, da))
		return box(name, tone, (a0 + a1) / 2, (y0 + y1) / 2, c, len, thick, thick, solid, turn)
	end
	-- mortar: a thin line right through a stone body (la long, lc a hair wider than it), so it shows on both faces;
	-- a joint is the same standing up, between y0 and y1
	local function course(y, la, lc)
		box("Course", "mortar", 0, y, 0, la, 0.14, lc, false)
	end
	local function joint(a, y0, y1, lc)
		box("Joint", "mortar", a, (y0 + y1) / 2, 0, 0.14, y1 - y0, lc, false)
	end

	if key == "barricade" then
		-- the Battlement: a low stone wall in two courses on a plinth, a coping in the team's dark shade and three
		-- merlons in its colour on top
		local body = T - 1
		box("Plinth", "stone", 0, 0.3, 0, L, 0.6, T)
		box("Body", "stone", 0, 1.7, 0, L - 0.4, 2.2, body)
		course(1.7, L - 0.3, body + 0.1)
		joint(-L / 4, 0.6, 1.7, body + 0.1)
		joint(L / 4, 0.6, 1.7, body + 0.1)
		joint(0, 1.7, 2.8, body + 0.1)
		box("Coping", "teamDark", 0, 2.95, 0, L, 0.3, T - 0.6)
		for _, a in { -(L / 2 - 0.8), 0, L / 2 - 0.8 } do
			box("Merlon", "team", a, 3.55, 0, 1.6, 0.9, T - 0.9)
		end
	elseif key == "wall" then
		-- the Castle Wall: four courses of stone blocks (staggered joints) on a plinth, a walkway coping and three
		-- merlons in the team's colours, and a torch on an iron bracket on the home face
		local body = T - 1.2
		box("Plinth", "stone", 0, 0.5, 0, L, 1, T)
		box("Body", "stone", 0, 4.7, 0, L - 0.4, 7.4, body)
		local ch = 1.85 -- (a course's height: 1 to 8.4 in four)
		for k = 0, 3 do
			local y0 = 1 + ch * k
			if k > 0 then
				course(y0, L - 0.3, body + 0.1)
			end
			for _, a in (k % 2 == 0) and { -L / 4, L / 4 } or { 0 } do
				joint(a, y0, y0 + ch, body + 0.1)
			end
		end
		box("Coping", "teamDark", 0, 8.65, 0, L, 0.5, T)
		for _, a in { -(L / 2 - 0.8), 0, L / 2 - 0.8 } do
			box("Merlon", "team", a, 9.45, 0, 1.6, 1.1, T - 0.6)
		end
		local tc = home * (body / 2 + 0.35)
		box("Bracket", "iron", 1, 5.4, home * (body / 2 + 0.25), 0.3, 0.9, 0.5, false)
		box("Torch", "woodDark", 1, 6, tc, 0.3, 1, 0.3, false)
		box("Flame", "flame", 1, 6.7, tc, 0.45, 0.5, 0.45, false)
	elseif key == "reinforced" then
		-- the Keep Wall: thick dark stone with a gate in it (a solid one: it still blocks), an oak door with iron
		-- bands between stone jambs under a lintel and keystone, an iron strap along the top, coursed stone either
		-- side, then the coping in the team's colour and heavy merlons in its dark shade
		local body = T - 0.4
		box("Plinth", "stoneDark", 0, 0.6, 0, L, 1.2, T)
		box("Body", "stoneDark", 0, 4.8, 0, L - 0.2, 7.2, body)
		box("Gate", "woodDark", 0, 3.6, 0, 3.4, 4.8, body + 0.1, false)
		for _, s in { 1, -1 } do
			box("Jamb", "stone", s * 1.95, 3.6, 0, 0.5, 4.8, body + 0.16, false)
		end
		box("Lintel", "stone", 0, 6.35, 0, 4.4, 0.7, body + 0.16, false)
		box("Keystone", "stone", 0, 6.6, 0, 1, 1.2, body + 0.22, false)
		for _, y in { 2.4, 4.8 } do
			box("GateBand", "iron", 0, y, 0, 3.5, 0.3, body + 0.14, false)
		end
		box("Strap", "iron", 0, 7.7, 0, L - 0.1, 0.35, body + 0.08, false)
		for _, s in { 1, -1 } do
			for _, y in { 3, 5 } do
				box("Course", "mortar", s * 3.05, y, 0, 1.7, 0.14, body + 0.1, false)
			end
		end
		box("Coping", "team", 0, 8.65, 0, L, 0.5, T)
		for _, a in { -(L / 2 - 0.9), 0, L / 2 - 0.9 } do
			box("Merlon", "teamDark", a, 9.45, 0, 1.8, 1.1, T - 0.4)
		end
	elseif key == "tower" then
		-- the Watchtower: a square stone shaft in courses with arrow slits on the front and sides, a platform in the
		-- team's colour on top (you stand on it) behind a crenellated parapet, a square turret at the front corner
		-- with a stepped roof and the team's flag, and a ladder up the back in a recess, through a hatch
		local b = -f -- (the back, along A: toward home)
		local w = L - 0.8 -- (the shaft)
		local slot, inner = 2.4, 2.5 -- (the recess: its width across, and its inside wall from the middle)
		box("Plinth", "stone", 0, 0.5, 0, L, 1, T)
		local front = w / 2 + inner
		box("Shaft", "stone", b * (inner - front / 2), 5.9, 0, front, 9.8, w)
		for _, s in { 1, -1 } do
			box(
				"Shaft",
				"stone",
				b * (inner + (w / 2 - inner) / 2),
				5.9,
				s * (slot / 2 + (w - slot) / 4),
				w / 2 - inner,
				9.8,
				(w - slot) / 2
			)
		end
		for _, y in { 3.45, 5.9, 8.35 } do
			box("Course", "mortar", b * (inner - front / 2), y, 0, front + 0.1, 0.14, w + 0.1, false)
		end
		for _, y in { 4.6, 8 } do
			-- (the slits: two through the front, one right through the sides)
			for _, s in { 1, -1 } do
				box("Slit", "iron", b * (inner - front / 2), y, s * 2.2, front + 0.1, 1.6, 0.4, false)
			end
			box("Slit", "iron", b * (inner - front / 2), y, 0, 0.4, 1.6, w + 0.1, false)
		end
		-- the platform, open over the ladder (a hatch)
		local deck = h - 1.2
		box("Platform", "team", b * (inner - L / 2) / 2, deck + 0.6, 0, L / 2 + inner, 1.2, T)
		for _, s in { 1, -1 } do
			box(
				"Platform",
				"team",
				b * (inner + L / 2) / 2,
				deck + 0.6,
				s * (slot / 2 + (T - slot) / 4),
				L / 2 - inner,
				1.2,
				(T - slot) / 2
			)
		end
		-- the parapet (the back in two, either side of the hatch) and its merlons; the turret takes the front corner
		local p = 0.6
		for _, s in { 1, -1 } do
			box("Parapet", "stone", 0, h + 0.45, s * (T / 2 - p / 2), L, 0.9, p)
			box(
				"Parapet",
				"stone",
				b * (L / 2 - p / 2),
				h + 0.45,
				s * (slot / 2 + (T / 2 - p - slot / 2) / 2),
				p,
				0.9,
				T / 2 - p - slot / 2
			)
		end
		box("Parapet", "stone", -b * (L / 2 - p / 2), h + 0.45, 0, p, 0.9, T - p * 2)
		local tc = T / 2 - 1.1 -- (the turret's corner: front, +C)
		for _, corner in { { b, 1 }, { b, -1 }, { -b, -1 } } do
			box("Merlon", "stone", corner[1] * (L / 2 - 0.45), h + 1.4, corner[2] * (T / 2 - 0.45), 0.9, 1, 0.9)
		end
		for _, s in { 1, -1 } do
			box("Merlon", "stone", 0, h + 1.4, s * (T / 2 - 0.35), 1.4, 1, 0.7)
		end
		box("Merlon", "stone", -b * (L / 2 - 0.35), h + 1.4, 0, 0.7, 1, 1.4)
		local ta = -b * (L / 2 - 1.1)
		box("Turret", "stone", ta, h + 1.5, tc, 2.2, 3, 2.2)
		for i, s in { 2.8, 2, 1.2 } do
			box("Roof", "team", ta, h + 2.75 + 0.5 * i, tc, s, 0.5, s, false)
		end
		box("Pole", "woodDark", ta, h + 6, tc, 0.25, 3, 0.25, false)
		box("Flag", "team", ta, h + 6.7, tc - 1.2, 0.12, 1.5, 2.2, false).flag = true
		-- the ladder: two rails (up past the platform, to hold) and square rungs in the recess, through the hatch
		local la = b * (L / 2 - 0.5)
		for _, s in { 1, -1 } do
			box("LadderRail", "woodDark", la, (1 + h + 1) / 2, s * 1, 0.3, h, 0.3)
		end
		local y = 1.6
		while y < h - 0.4 do
			box("Rung", "woodDark", la, y, 0, 0.25, 0.25, 2)
			y += 1.6
		end
	elseif key == "bridge" then
		-- the Rampart: a plank deck on six square posts (stood on to shoot over the walls), braced underneath, a
		-- palisade with the team's trim on the enemy's side, a team-coloured fascia along both edges, low kerbs at
		-- the ends and a ladder up the home side
		local enemy = -home
		local deckT = T - 0.6
		for _, a in { -(L / 2 - 0.4), 0, L / 2 - 0.4 } do
			for _, s in { 1, -1 } do
				box("Post", "woodDark", a, 2.6, s * (T / 2 - 0.4), 0.8, 5.2, 0.8)
			end
		end
		for _, s in { 1, -1 } do
			local c = s * (T / 2 - 0.4)
			box("Beam", "woodDark", 0, 4.95, c, L, 0.5, 0.5, false)
			brace("Brace", "woodDark", c, -(L / 2 - 0.8), 0.6, -0.4, 4.6, 0.3, false)
			brace("Brace", "woodDark", c, 0.4, 4.6, L / 2 - 0.8, 0.6, 0.3, false)
			box("Fascia", "team", 0, 5.45, s * (deckT / 2 + 0.06), L, 0.45, 0.12, false)
		end
		for i = 1, 4 do
			box("Plank", "wood", -L / 2 + (i - 0.5) * L / 4, h - 0.4, 0, L / 4 - 0.1, 0.8, deckT)
		end
		box("Palisade", "wood", 0, h + 0.55, enemy * (deckT / 2 - 0.2), L, 1.1, 0.35)
		box("Trim", "team", 0, h + 1.22, enemy * (deckT / 2 - 0.2), L, 0.25, 0.5, false)
		for _, s in { 1, -1 } do
			box("Kerb", "woodDark", s * (L / 2 - 0.15), h + 0.3, 0, 0.25, 0.6, deckT - 1, false)
		end
		-- (the ladder: just outside the deck's edge on the home side, between two posts)
		local lc = home * (T / 2 - 0.2)
		for _, a in { L / 4 - 0.9, L / 4 + 0.9 } do
			box("LadderRail", "woodDark", a, (h + 1.2) / 2, lc, 0.3, h + 1.2, 0.3)
		end
		local y = 0.9
		while y < h do
			box("Rung", "woodDark", L / 4, y, lc, 2, 0.25, 0.25)
			y += 1.2
		end
	elseif key == "cover" then
		-- the Shield Wall: a big plank mantlet facing the enemy on two skids, propped from behind by two struts and a
		-- crossbar, with iron bands, a broad band in the team's colour with an iron boss, and a team cap
		local fa = f * 0.9 -- (the board, toward the enemy)
		for _, s in { 1, -1 } do
			box("Skid", "woodDark", 0, 0.2, s * 1.5, L, 0.4, 0.6)
		end
		box("Board", "wood", fa, 3.1, 0, 0.7, 5.4, T - 0.1)
		for _, s in { 1, -1 } do
			box("Seam", "woodDark", fa, 3.1, s * 0.65, 0.8, 5.3, 0.12, false)
		end
		for _, y in { 1.2, 5.2 } do
			box("Band", "iron", fa, y, 0, 0.78, 0.25, T - 0.06, false)
		end
		box("Stripe", "team", fa, 3.3, 0, 0.82, 1.2, T - 0.04, false)
		box("Boss", "iron", fa, 3.3, 0, 0.95, 1, 1, false)
		box("Cap", "team", fa, 5.92, 0, 0.9, 0.25, T, false)
		for _, s in { 1, -1 } do
			brace("Strut", "woodDark", s * 1.3, f * 0.5, 5, -f * 1.6, 0.4, 0.3, false)
		end
		box("Crossbar", "woodDark", -f * 1.05, 1.6, 0, 0.3, 0.3, 2.9, false)
	elseif key == "banner" then
		-- the Rally Banner: a war banner in the team's colour (the builder's emblem on it) hung from an iron
		-- crossbar on a square pole, on a stepped stone base, with a glowing square on the ground round it (your
		-- team comes back here: BuildService)
		box("RallyGlow", "glow", 0, 0.06, 0, 3.4, 0.12, 3.4, false).glow = true
		box("Base", "stone", 0, 0.3, 0, 2.6, 0.6, 2.6)
		box("Base", "teamDark", 0, 0.85, 0, 1.8, 0.5, 1.8)
		box("Pole", "woodDark", 0, (1.1 + h) / 2, 0, 0.5, h - 1.1, 0.5)
		box("Crossbar", "iron", 0, h - 0.9, 0, 3.2, 0.3, 0.3, false)
		box("Flag", "team", 0, h - 3.55, 0.35, 2.6, 5, 0.15, false).flag = true
		box("FlagTop", "teamDark", 0, h - 1.3, 0.35, 2.7, 0.5, 0.2, false)
		for _, s in { 1, -1 } do
			-- (the tails: two square tabs at the bottom, a notch between them)
			box("FlagTail", "team", s * 0.85, h - 6.5, 0.35, 0.9, 0.9, 0.15, false)
		end
		box("Finial", "iron", 0, h + 0.18, 0, 0.75, 0.35, 0.75, false)
		box("Finial", "iron", 0, h + 0.6, 0, 0.35, 0.5, 0.35, false)
	else
		box("Body", "stone", 0, h / 2, 0, L, h, T)
	end
	return out
end

-- One entry as a part (anchored; solid or not as it says; its tone kept so a team change can paint it again)
function StructureModel.make(spec, team)
	local p = Instance.new("Part")
	p.Name = spec.name or "Piece"
	p.Anchored = true
	p.Size = spec.size
	p.CFrame = spec.cf
	p.Material = GLOWS[spec.tone] and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Color = StructureModel.color(spec.tone, team)
	p.CanCollide = spec.solid ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if spec.tone == "glow" then
		p.Transparency = 0.35
		p.CastShadow = false
	end
	p:SetAttribute("Tone", spec.tone)
	return p
end

return StructureModel
