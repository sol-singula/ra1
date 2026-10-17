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

Pieces placed touching join up (joins): walls end to end in a row run on as one wall (no gap in the body, the coping
and the merlons running on evenly over the seam, a pilaster on the joint), a wall whose end meets another's side
makes a square corner post there (an L or a T), a wall's end butts into a taller wall or a Watchtower's face, a
Rampart's deck runs on into the next and drops its palisade where a wall stands against it, Shield Walls side by side
close up. Joining only moves and trims the parts (and usually drops a few); the footprint box is the same, so the
building rules, the arrows' boxes and the bots don't change. BuildService works the joins out from the grid when a
piece goes up or comes down and reshapes its neighbours; the hotbar's pictures have none.

  StructureModel.parts(key, team, min, max, joins?)   { { name, cf, size, tone, solid, flag?, glow? } }
  StructureModel.joins(piece, at)             the joins for a piece { key, team, cx, cz, w, d } from what stands
                                              round it (at(cx, cz) -> the piece on that cell, or nil), or nil
  StructureModel.joinsKey(joins)              a short string, to tell whether a piece's joins changed
  StructureModel.color(tone, team)            "stone" | "stoneDark" | "mortar" | "wood" | "woodDark" | "iron" |
                                              "team" | "teamDark" | "flame" | "glow" (and the old "build" | "armor")
  StructureModel.make(spec, team)             a Part for one entry, its tone in a "Tone" attribute

joins, in the piece's own frame (A along its long side, X for a square piece; C across, A x up):
  left, right    its -A and +A ends: "run" (the same height of wall goes on in line), "butt" (it ends against a
                 taller wall, or a corner post), "flush" (a lower wall butts into it: its end finishes, set flush),
                 "tower" (it ends against a Watchtower), "wall" (a Rampart's end against a wall or a tower)
  front, back    its +C and -C sides, a character per cell along A (left to right): "p" (another wall's end meets
                 it there: a corner post), "w" (a wall or tower stands against a Rampart there), "d" (another
                 Rampart's deck), "s" (a Shield Wall beside a Shield Wall), "." nothing
Strings only, so they go over the network as they are (the "destroyed" message carries them for the debris).
]]
local Constants = require(script.Parent.Constants)
local Structures = require(script.Parent.Data.Structures)

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

-- The wall pieces (they run on in a row and meet at corners), and how each is made: the plinth's height, the stone,
-- how much thinner than the footprint the body is and how far it's set in at a free end, the top of the body, the
-- coping (height, how much thinner, tone) and the merlons (length, height, how much thinner, tone)
local WALLS = {
	barricade = {
		plinth = 0.6,
		stone = "stone",
		thin = 1,
		inset = 0.2,
		top = 2.8,
		cope = 0.3,
		copeThin = 0.6,
		copeTone = "teamDark",
		m = 1.6,
		mh = 0.9,
		mThin = 0.9,
		mTone = "team",
	},
	wall = {
		plinth = 1,
		stone = "stone",
		thin = 1.2,
		inset = 0.2,
		top = 8.4,
		cope = 0.5,
		copeThin = 0,
		copeTone = "teamDark",
		m = 1.6,
		mh = 1.1,
		mThin = 0.6,
		mTone = "team",
	},
	reinforced = {
		plinth = 1.2,
		stone = "stoneDark",
		thin = 0.4,
		inset = 0.1,
		top = 8.4,
		cope = 0.5,
		copeThin = 0,
		copeTone = "team",
		m = 1.8,
		mh = 1.1,
		mThin = 0.4,
		mTone = "teamDark",
	},
}
StructureModel.WALLS = WALLS

-- What touches a piece, worked out from the grid (BuildService's cells; the tutorial's own). Only the same team's
-- pieces join. Returns nil when nothing does.
function StructureModel.joins(piece, at)
	local def = piece and Structures.get(piece.key)
	if not def then
		return nil
	end
	local alongX = piece.w >= piece.d
	local n = alongX and piece.w or piece.d -- (cells along A)
	local m = alongX and piece.d or piece.w -- (cells across)
	-- the cell at i along A (-1 and n: past the ends) and j across (-1: the back, m: the front)
	local function cell(i, j)
		local N
		if alongX then
			N = at(piece.cx + i, piece.cz + j)
		else
			N = at(piece.cx + (m - 1) - j, piece.cz + i) -- (C is -X when A is Z)
		end
		if N and N ~= piece and N.team == piece.team and Structures.get(N.key) then
			return N, Structures.get(N.key), (N.w >= N.d) == alongX
		end
		return nil
	end
	local out, any = {}, false
	if WALLS[def.key] then
		for _, e in { { "left", -1 }, { "right", n } } do
			local N, nd, parallel = cell(e[2], 0)
			local kind
			if N and WALLS[nd.key] then
				if parallel then
					kind = nd.h == def.h and "run" or nd.h > def.h and "butt" or "flush"
				else
					kind = nd.h >= def.h and "butt" or "flush" -- (it meets the other's corner post)
				end
			elseif N and nd.key == "tower" then
				kind = "tower"
			end
			out[e[1]] = kind
			any = any or kind ~= nil
		end
		for _, s in { { "front", m }, { "back", -1 } } do
			local str = ""
			for i = 0, n - 1 do
				local N, nd, parallel = cell(i, s[2])
				local post = N and WALLS[nd.key] and not parallel
				str ..= post and "p" or "."
				any = any or post
			end
			out[s[1]] = str
		end
	elseif def.key == "bridge" then
		for _, e in { { "left", -1 }, { "right", n } } do
			local N, nd, parallel = cell(e[2], 0)
			local kind
			if N and nd.key == "bridge" and parallel then
				kind = "run"
			elseif N and (WALLS[nd.key] or nd.key == "tower" or nd.key == "bridge") then
				kind = "wall"
			end
			out[e[1]] = kind
			any = any or kind ~= nil
		end
		for _, s in { { "front", m }, { "back", -1 } } do
			local str = ""
			for i = 0, n - 1 do
				local N, nd = cell(i, s[2])
				local c = "."
				if N and (WALLS[nd.key] or nd.key == "tower") then
					c = "w"
				elseif N and nd.key == "bridge" then
					c = "d"
				end
				str ..= c
				any = any or c ~= "."
			end
			out[s[1]] = str
		end
	elseif def.key == "cover" then
		for _, s in { { "front", m }, { "back", -1 } } do
			local N, nd = cell(0, s[2])
			local c = N and nd.key == "cover" and "s" or "."
			out[s[1]] = c
			any = any or c ~= "."
		end
	end
	return any and out or nil
end

function StructureModel.joinsKey(joins)
	if type(joins) ~= "table" then
		return ""
	end
	local out = {}
	for _, k in { "left", "right", "front", "back" } do
		table.insert(out, type(joins[k]) == "string" and joins[k] or "")
	end
	return table.concat(out, "|")
end

function StructureModel.parts(key, team, mn, mx, joins)
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
	-- what touches it (joins): an end's kind, and a side's character at cell i along A ("." for none)
	local function joinAt(side)
		local v = joins and joins[side]
		return type(v) == "string" and v or nil
	end
	local function sideAt(side, i)
		local v = joinAt(side)
		local ch = v and v:sub(i + 1, i + 1) or ""
		return ch ~= "" and ch or "."
	end
	local CELL = Constants.CELL
	local cells = math.max(1, math.floor(L / CELL + 0.5)) -- (cells along A)

	local wl = WALLS[key]
	if wl then
		-- the three walls: the Battlement (a low wall, a coping in the team's dark shade, merlons in its colour), the
		-- Castle Wall (tall, a walkway coping, a torch on the home face) and the Keep Wall (thick dark stone, a gate in
		-- it, an iron strap, the coping in the team's colour and heavy merlons in its dark shade), each a body on a
		-- plinth. Joined, the body runs right to the end, the coping runs on and the merlons are spaced from seam to
		-- seam (the one on the seam cut in half: the neighbour has the other half) with a pilaster on the joint; a
		-- square post takes an end cell where another wall's end meets its side (an L or a T)
		local lj, rj = joinAt("left"), joinAt("right")
		local function post(i)
			return sideAt("front", i) == "p" or sideAt("back", i) == "p"
		end
		local lp, rp = post(0), cells > 1 and post(cells - 1)
		local s0 = lp and -L / 2 + CELL or -L / 2 -- (the stretch of wall between the posts)
		local s1 = rp and L / 2 - CELL or L / 2
		local body = T - wl.thin
		local copeY = wl.top + wl.cope
		box("Plinth", wl.stone, 0, wl.plinth / 2, 0, L, wl.plinth, T)
		if s1 - s0 > 0.05 then
			local b0 = s0 + ((lj or lp) and 0 or wl.inset)
			local b1 = s1 - ((rj or rp) and 0 or wl.inset)
			box("Body", wl.stone, (b0 + b1) / 2, (wl.plinth + wl.top) / 2, 0, b1 - b0, wl.top - wl.plinth, body)
		end
		if key == "reinforced" and not (lp or rp) then
			-- the gate (a solid one: it still blocks): an oak door with iron bands between stone jambs under a lintel
			-- and keystone (no room for it beside a corner post)
			box("Gate", "woodDark", 0, 3.6, 0, 3.4, 4.8, body + 0.1, false)
			for _, s in { 1, -1 } do
				box("Jamb", "stone", s * 1.95, 3.6, 0, 0.5, 4.8, body + 0.16, false)
			end
			box("Lintel", "stone", 0, 6.35, 0, 4.4, 0.7, body + 0.16, false)
			box("Keystone", "stone", 0, 6.6, 0, 1, 1.2, body + 0.22, false)
			for _, y in { 2.4, 4.8 } do
				box("GateBand", "iron", 0, y, 0, 3.5, 0.3, body + 0.14, false)
			end
		end
		if key == "reinforced" and s1 - s0 > 0.05 then
			local t0 = s0 + ((lj or lp) and 0 or 0.05)
			local t1 = s1 - ((rj or rp) and 0 or 0.05)
			box("Strap", "iron", (t0 + t1) / 2, 7.7, 0, t1 - t0, 0.35, body + 0.08, false)
		end
		if s1 - s0 > 0.05 then
			box("Coping", wl.copeTone, (s0 + s1) / 2, wl.top + wl.cope / 2, 0, s1 - s0, wl.cope, T - wl.copeThin)
			-- the merlons, evenly from end to end: a free (or flush) end has a whole one at its corner, a seam or a
			-- post the middle of one (cut where the piece ends), so a row of walls keeps one rhythm over its joints
			local lseam = lp or (lj ~= nil and lj ~= "flush")
			local rseam = rp or (rj ~= nil and rj ~= "flush")
			local c0 = lseam and s0 or s0 + wl.m / 2
			local c1 = rseam and s1 or s1 - wl.m / 2
			local span = c1 - c0
			local count = span > 0.05 and math.floor(span / (2 * wl.m) + 0.4) + 1 or 1
			for k = 0, count - 1 do
				local c = count > 1 and c0 + span * k / (count - 1) or (c0 + c1) / 2
				local lo, hi = math.max(c - wl.m / 2, s0), math.min(c + wl.m / 2, s1)
				if hi - lo > 0.05 then
					box("Merlon", wl.mTone, (lo + hi) / 2, copeY + wl.mh / 2, 0, hi - lo, wl.mh, T - wl.mThin)
				end
			end
		end
		-- the joint with the next wall in the row: a pilaster over the seam (the left one of the pair makes it)
		if rj == "run" and not rp then
			local pt = key == "barricade" and body + 0.3 or T - 0.1
			box("Pilaster", wl.stone, L / 2, (wl.plinth + wl.top) / 2, 0, 0.8, wl.top - wl.plinth, pt, false)
		end
		-- a corner post: a square pier on the end cell, a little over the merlons, capped in the coping's tone
		local topY = copeY + wl.mh + 0.2
		for _, p in { { lp, -L / 2 + CELL / 2 }, { rp, L / 2 - CELL / 2 } } do
			if p[1] then
				box("Post", wl.stone, p[2], (wl.plinth + topY) / 2, 0, CELL, topY - wl.plinth, T)
				box("PostCap", wl.copeTone, p[2], topY + 0.2, 0, CELL + 0.3, 0.4, T + 0.3, false)
			end
		end
		-- against a Watchtower: its shaft stands back from its plinth's edge, so the wall reaches in to meet it
		for _, e in { { lj, -1 }, { rj, 1 } } do
			if e[1] == "tower" then
				local y0 = math.max(wl.plinth, 1)
				box(
					"Abut",
					wl.stone,
					e[2] * (L / 2 + 0.2),
					(y0 + copeY) / 2,
					0,
					0.4,
					copeY - y0,
					T - wl.copeThin,
					false
				)
			end
		end
		if key == "wall" then
			-- the torch on an iron bracket on the home face (in a cell without a corner post)
			local ta = not rp and 1 or not lp and -1 or nil
			if ta then
				local tc = home * (body / 2 + 0.35)
				box("Bracket", "iron", ta, 5.4, home * (body / 2 + 0.25), 0.3, 0.9, 0.5, false)
				box("Torch", "woodDark", ta, 6, tc, 0.3, 1, 0.3, false)
				box("Flame", "flame", ta, 6.7, tc, 0.45, 0.5, 0.45, false)
			end
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
		-- the ends and a ladder up the home side. Joined: end to end the decks run on as one (the posts on the seam
		-- are the next one's, no kerbs between), and where a wall or a tower (or another deck) stands against a side
		-- the deck reaches it and the palisade stops there (the wall is the parapet)
		local enemy = -home
		local deckT = T - 0.6
		local lj, rj = joinAt("left"), joinAt("right")
		local function touched(side)
			return (joinAt(side) or ""):find("[wd]") ~= nil
		end
		local touch = { [1] = touched("front"), [-1] = touched("back") }
		for _, a in { -(L / 2 - 0.4), 0, L / 2 - 0.4 } do
			if not (rj == "run" and a > 0.5) then
				for _, s in { 1, -1 } do
					box("Post", "woodDark", a, 2.6, s * (T / 2 - 0.4), 0.8, 5.2, 0.8)
				end
			end
		end
		for _, s in { 1, -1 } do
			local c = s * (T / 2 - 0.4)
			box("Beam", "woodDark", 0, 4.95, c, L, 0.5, 0.5, false)
			brace("Brace", "woodDark", c, -(L / 2 - 0.8), 0.6, -0.4, 4.6, 0.3, false)
			brace("Brace", "woodDark", c, 0.4, 4.6, L / 2 - 0.8, 0.6, 0.3, false)
			if not touch[s] then
				box("Fascia", "team", 0, 5.45, s * (deckT / 2 + 0.06), L, 0.45, 0.12, false)
			end
		end
		local d0 = touch[-1] and -T / 2 or -deckT / 2
		local d1 = touch[1] and T / 2 or deckT / 2
		for i = 1, 4 do
			local p0 = (i == 1 and lj) and -L / 2 or -L / 2 + (i - 1) * L / 4 + 0.05
			local p1 = (i == 4 and rj) and L / 2 or -L / 2 + i * L / 4 - 0.05
			box("Plank", "wood", (p0 + p1) / 2, h - 0.4, (d0 + d1) / 2, p1 - p0, 0.8, d1 - d0)
		end
		-- (the palisade, in stretches over the cells with nothing standing against them)
		local eside = enemy == 1 and "front" or "back"
		local i0
		for i = 0, cells do
			local open = i < cells and not sideAt(eside, i):find("[wd]")
			if open and not i0 then
				i0 = i
			elseif not open and i0 then
				local a0, a1 = -L / 2 + i0 * CELL, -L / 2 + i * CELL
				box("Palisade", "wood", (a0 + a1) / 2, h + 0.55, enemy * (deckT / 2 - 0.2), a1 - a0, 1.1, 0.35)
				box("Trim", "team", (a0 + a1) / 2, h + 1.22, enemy * (deckT / 2 - 0.2), a1 - a0, 0.25, 0.5, false)
				i0 = nil
			end
		end
		for _, e in { { lj, -1 }, { rj, 1 } } do
			if not e[1] then
				box("Kerb", "woodDark", e[2] * (L / 2 - 0.15), h + 0.3, 0, 0.25, 0.6, deckT - 1, false)
			end
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
		-- crossbar, with iron bands, a broad band in the team's colour with an iron boss, and a team cap. Side by
		-- side, the boards close up into one shield wall (no slit between them)
		local fa = f * 0.9 -- (the board, toward the enemy)
		local fj, bj = sideAt("front", 0) == "s", sideAt("back", 0) == "s"
		-- (across, `width` wide, or right to the edge on a joined side): its middle and its size
		local function across(width)
			local lo, hi = bj and -T / 2 or -width / 2, fj and T / 2 or width / 2
			return (lo + hi) / 2, hi - lo
		end
		for _, s in { 1, -1 } do
			box("Skid", "woodDark", 0, 0.2, s * 1.5, L, 0.4, 0.6)
		end
		local bc, bw = across(T - 0.1)
		box("Board", "wood", fa, 3.1, bc, 0.7, 5.4, bw)
		for _, s in { 1, -1 } do
			box("Seam", "woodDark", fa, 3.1, s * 0.65, 0.8, 5.3, 0.12, false)
		end
		for _, y in { 1.2, 5.2 } do
			local c, w = across(T - 0.06)
			box("Band", "iron", fa, y, c, 0.78, 0.25, w, false)
		end
		local sc, sw = across(T - 0.04)
		box("Stripe", "team", fa, 3.3, sc, 0.82, 1.2, sw, false)
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
