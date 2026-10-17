--[[
What each structure looks like, as a list of parts, shared by the server (BuildService builds it in the world), the
hotbar (UI/Icons draws it in a ViewportFrame) and the debris (DebrisController breaks the same shapes into chunks
when it comes down), so all three always agree.

Every piece is one shade of its team's colour (Constants.BUILD_COLOR) except the Reinforced Wall, the armoured one,
which is all in the darker shade (Constants.ARMOR_COLOR): the shapes carry the detail (plinths, bevelled caps,
pilasters, slits, crenellations, braces, a tapered tower with a lookout, a ladder and a banner), the light and
shadow do the rest. Nothing solid reaches outside the footprint box or far above its height, so the building rules,
the arrows' boxes and the tests see the same piece as before; overhangs and trim are not solid.

  StructureModel.parts(key, team, min, max)   { { name, cf, size, tone, shape?, wedge?, solid, flag? } }
  StructureModel.color(tone, team)            "build" | "armor"
  StructureModel.make(spec, team)             a Part (or WedgePart) for one entry, its tone in a "Tone" attribute
]]
local Constants = require(script.Parent.Constants)

local StructureModel = {}

local Y = Vector3.new(0, 1, 0)
local PI = math.pi

function StructureModel.color(tone, team)
	local set = tone == "armor" and Constants.ARMOR_COLOR or Constants.BUILD_COLOR
	return set[team or ""] or set.red
end

-- The wedges' turns: the slope of a WedgePart faces its own -Z (and up); these face it outward along the piece's
-- frame (A along, C across)
local FACE = {
	["-C"] = CFrame.new(),
	["+C"] = CFrame.Angles(0, PI, 0),
	["+A"] = CFrame.Angles(0, -PI / 2, 0),
	["-A"] = CFrame.Angles(0, PI / 2, 0),
}

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
	local tone = key == "reinforced" and "armor" or "build"
	-- (the enemy's side, along A: red looks toward +X; only square pieces care, their A is X)
	local f = team == "blue" and -1 or 1
	local function frame(a, y, c)
		return CFrame.fromMatrix(base + A * a + Y * y + C * c, A, Y, C)
	end
	-- a box at (a, y, c) in the frame (y its middle), la x ly x lc
	local function box(name, a, y, c, la, ly, lc, solid, turn)
		local e = {
			name = name,
			cf = frame(a, y, c) * (turn or CFrame.new()),
			size = Vector3.new(la, ly, lc),
			tone = tone,
			solid = solid ~= false,
		}
		table.insert(out, e)
		return e
	end
	-- a wedge whose slope faces `face` (and up; down = true: an upside-down corbel), its edge len long
	local function wedge(name, a, y, c, len, ht, depth, face, down, solid)
		local e =
			box(name, a, y, c, len, ht, depth, solid, FACE[face] * (down and CFrame.Angles(0, 0, PI) or CFrame.new()))
		e.wedge = true
		return e
	end
	local function cylinder(name, a, y, c, len, dia, turn, solid)
		local e = box(name, a, y, c, len, dia, dia, solid, turn)
		e.shape = "Cylinder"
		return e
	end
	local function ball(name, a, y, c, dia, solid)
		local e = box(name, a, y, c, dia, dia, dia, solid)
		e.shape = "Ball"
		return e
	end
	-- a bevelled cap: a slab with wedges along both long edges (and the short ends when `ends`)
	local function cap(name, y, la, lc, th, bevel, ends)
		box(name, 0, y, 0, la - bevel * 2 * (ends and 1 or 0), th, lc - bevel * 2)
		for _, s in { 1, -1 } do
			wedge(
				name .. "Bevel",
				0,
				y,
				s * (lc / 2 - bevel / 2),
				la - (ends and bevel * 2 or 0),
				th,
				bevel,
				s > 0 and "+C" or "-C"
			)
			if ends then
				wedge(
					name .. "Bevel",
					s * (la / 2 - bevel / 2),
					y,
					0,
					lc - bevel * 2,
					th,
					bevel,
					s > 0 and "+A" or "-A"
				)
			end
		end
	end
	-- a diagonal brace in the face plane at across c, from (a0, y0) to (a1, y1)
	local function brace(name, c, a0, y0, a1, y1, thick, solid)
		local da, dy = a1 - a0, y1 - y0
		local len = math.sqrt(da * da + dy * dy)
		local turn = CFrame.fromAxisAngle(Vector3.new(0, 0, 1), math.atan2(dy, da))
		return box(name, (a0 + a1) / 2, (y0 + y1) / 2, c, len, thick, thick, solid, turn)
	end

	if key == "barricade" then
		-- a low rampart: a plinth, a recessed body between end posts, crossed braces on both faces, a bevelled rail
		box("Plinth", 0, 0.3, 0, L, 0.6, T)
		box("Body", 0, 0.6 + (h - 1.5) / 2, 0, L - 1.6, h - 1.5, T - 1.4)
		for _, s in { 1, -1 } do
			box("Post", s * (L / 2 - 0.5), (h - 0.2) / 2, 0, 1, h - 0.2, T - 0.4)
			box("PostCap", s * (L / 2 - 0.5), h - 0.1, 0, 1.2, 0.2, T - 0.2, false)
		end
		for _, s in { 1, -1 } do
			local c = s * (T / 2 - 0.55)
			brace("Brace", c, -L / 2 + 1, 0.8, L / 2 - 1, h - 1.1, 0.35, false)
			brace("Brace", c, -L / 2 + 1, h - 1.1, L / 2 - 1, 0.8, 0.35, false)
		end
		cap("Rail", h - 0.6, L - 2, T - 0.6, 0.5, 0.35)
	elseif key == "wall" or key == "reinforced" then
		local armored = key == "reinforced"
		local body = armored and T - 0.8 or T - 1.6
		box("Plinth", 0, 0.45, 0, L, 0.9, T)
		wedge("PlinthBevel", 0, 1.1, T / 2 - 0.3, L, 0.4, 0.6, "+C", false, false)
		wedge("PlinthBevel", 0, 1.1, -(T / 2 - 0.3), L, 0.4, 0.6, "-C", false, false)
		box("Body", 0, 0.9 + (h - 2.5) / 2, 0, L - 0.8, h - 2.5, body)
		if armored then
			-- armour: raised plates on both faces (two across, three up) with a rivet at each corner, buttresses at
			-- the ends, and a heavy flat top with two square merlons
			local ph = (h - 3) / 3
			for _, s in { 1, -1 } do
				local c = s * (body / 2 + 0.15)
				for i = 0, 1 do
					for j = 0, 2 do
						local a = (i - 0.5) * (L / 2 - 0.3)
						local y = 1.2 + ph * (j + 0.5)
						box("Plate", a, y, c, L / 2 - 0.9, ph - 0.35, 0.3, false)
						for _, ra in { -1, 1 } do
							for _, ry in { -1, 1 } do
								ball(
									"Rivet",
									a + ra * (L / 4 - 0.75),
									y + ry * (ph / 2 - 0.4),
									c + s * 0.15,
									0.28,
									false
								)
							end
						end
					end
				end
				for _, e in { 1, -1 } do
					wedge(
						"Buttress",
						e * (L / 2 - 0.6),
						0.9 + 2,
						s * (body / 2 + (T - body) / 4),
						1.2,
						4,
						(T - body) / 2,
						s > 0 and "+C" or "-C"
					)
				end
			end
			box("Top", 0, h - 1.2, 0, L - 0.2, 0.8, T - 0.2)
			cap("TopCap", h - 0.55, L, T, 0.5, 0.4, true)
			for _, s in { 1, -1 } do
				box("Merlon", s * (L / 2 - 1.3), h - 0.1, 0, 2, 0.6, T - 1.2, false)
			end
		else
			-- pilasters at the ends and the middle, a band, slits between, a corbelled walkway and crenellations
			for _, a in { -(L / 2 - 0.55), 0, L / 2 - 0.55 } do
				box("Pilaster", a, 0.9 + (h - 2.4) / 2, 0, a == 0 and 0.9 or 1.1, h - 2.4, T - 0.5)
			end
			box("Band", 0, 0.9 + (h - 2.6) * 0.45, 0, L - 0.4, 0.45, body + 0.5, false)
			for _, s in { 1, -1 } do
				for _, a in { -L / 4, L / 4 } do
					-- (an arrow slit: two ribs either side of a dark gap in the face)
					for _, side in { -1, 1 } do
						box("Slit", a + side * 0.4, h * 0.62, s * (body / 2 + 0.1), 0.3, 2.2, 0.25, false)
					end
					box("SlitSill", a, h * 0.62 - 1.2, s * (body / 2 + 0.12), 1.1, 0.25, 0.3, false)
				end
				wedge("Corbel", 0, h - 1.95, s * (T / 2 - 0.5), L - 0.4, 0.7, 0.9, s > 0 and "+C" or "-C", true, false)
			end
			box("Walk", 0, h - 1.35, 0, L, 0.5, T)
			for i, a in { -(L / 2 - 0.8), 0, L / 2 - 0.8 } do
				box("Merlon", a, h - 0.55, 0, i == 2 and 1.6 or 1.5, 1.1, T - 0.5)
			end
		end
	elseif key == "tower" then
		-- a tapered keep: a plinth with corner spurs, two tiers stepping in (bevelled steps, slits on every face),
		-- corbels out to a lookout platform on top (walk on it), battlements round it, a ladder up the back in a
		-- recess, and a banner on a pole at the front corner
		local back = -f -- (the ladder's side: toward home)
		box("Plinth", 0, 0.5, 0, L, 1, T)
		for _, sa in { 1, -1 } do
			for _, sc in { 1, -1 } do
				wedge(
					"Spur",
					sa * (L / 2 - 0.5),
					1.6,
					sc * (T / 2 - 0.9),
					1,
					1.2,
					1.2,
					sc > 0 and "+C" or "-C",
					false,
					false
				)
			end
		end
		-- the tiers, each a ring of blocks round a recess at the back for the ladder (2.4 wide)
		local slot = 2.4
		local tiers = { { y0 = 1, y1 = 5.4, w = 7.4 }, { y0 = 5.4, y1 = 9.4, w = 6.6 } }
		for ti, tr in tiers do
			local ht = tr.y1 - tr.y0
			local y = tr.y0 + ht / 2
			local inner = L / 2 - 1.3 -- (the recess's inside wall, from the middle)
			local w = tr.w
			-- the front part (up to the recess) and the two sides of the recess
			local frontDepth = w / 2 + inner
			box("Tier" .. ti, -back * (w / 2 - frontDepth / 2), y, 0, frontDepth, ht, w)
			local sideW = (w - slot) / 2
			local depth = w / 2 - inner
			for _, sc in { 1, -1 } do
				box("Tier" .. ti, back * (inner + depth / 2), y, sc * (slot / 2 + sideW / 2), depth, ht, sideW)
			end
			-- the step out to the tier below: bevels on the three faces without the ladder
			local step = (ti == 1 and L or tiers[ti - 1].w) - w
			if step > 0.05 then
				for _, sc in { 1, -1 } do
					wedge(
						"Step",
						0,
						tr.y0 + 0.25,
						sc * (w / 2 + step / 4),
						w,
						0.5,
						step / 2,
						sc > 0 and "+C" or "-C",
						false,
						false
					)
				end
				wedge(
					"Step",
					-back * (w / 2 + step / 4),
					tr.y0 + 0.25,
					0,
					w,
					0.5,
					step / 2,
					-back > 0 and "+A" or "-A",
					false,
					false
				)
			end
			-- slits: the front and both sides
			for _, face in { { 0, 1 }, { 0, -1 }, { -back, 0 } } do
				local fa, fc = face[1], face[2]
				for _, side in { -1, 1 } do
					local along = side * 0.45
					local a = fa ~= 0 and fa * (w / 2 + 0.1) or along
					local c = fc ~= 0 and fc * (w / 2 + 0.1) or along
					box("Slit", a, y + 0.2, c, fa ~= 0 and 0.25 or 0.3, ht * 0.5, fa ~= 0 and 0.3 or 0.25, false)
				end
			end
		end
		-- the corbels: out from the top tier to the lookout's edge, all round
		local top = tiers[#tiers]
		local over = (L - top.w) / 2
		for _, sc in { 1, -1 } do
			wedge(
				"Corbel",
				0,
				top.y1 + 0.5,
				sc * (top.w / 2 + over / 2),
				L,
				1,
				over,
				sc > 0 and "+C" or "-C",
				true,
				false
			)
		end
		wedge(
			"Corbel",
			-back * (top.w / 2 + over / 2),
			top.y1 + 0.5,
			0,
			top.w,
			1,
			over,
			-back > 0 and "+A" or "-A",
			true,
			false
		)
		-- the lookout: the platform (its top at the piece's height: you stand on it) and its battlements; the back
		-- has an opening over the ladder
		box("Lookout", 0, top.y1 + 1 + (h - top.y1 - 1) / 2, 0, L, h - top.y1 - 1, T)
		local parapet = 0.6
		for _, sc in { 1, -1 } do
			box("Parapet", 0, h + 0.45, sc * (T / 2 - parapet / 2), L, 0.9, parapet)
			for _, a in { -(L / 2 - 0.8), 0, L / 2 - 0.8 } do
				box("Merlon", a, h + 1.45, sc * (T / 2 - parapet / 2), 1.6, 1.1, parapet + 0.1)
			end
		end
		for _, sa in { 1, -1 } do
			local side = sa == back and "back" or "front"
			if side == "front" then
				box("Parapet", sa * (L / 2 - parapet / 2), h + 0.45, 0, parapet, 0.9, T - parapet * 2)
				box("Merlon", sa * (L / 2 - parapet / 2), h + 1.45, 0, parapet + 0.1, 1.1, 1.6)
			else
				-- (either side of the opening)
				local w = (T - parapet * 2 - slot) / 2
				for _, sc in { 1, -1 } do
					box("Parapet", sa * (L / 2 - parapet / 2), h + 0.95, sc * (slot / 2 + w / 2), parapet, 1.9, w)
				end
			end
		end
		-- the ladder: two rails and rungs in the recess at the back, from the plinth to the lookout
		local la = back * (L / 2 - 0.45)
		for _, sc in { 1, -1 } do
			box("LadderRail", la, (1 + h) / 2, sc * (slot / 2 - 0.2), 0.3, h - 1, 0.3)
		end
		local y = 1.6
		while y < top.y1 + 0.8 do
			cylinder("Rung", la, y, 0, slot - 0.4, 0.22, CFrame.Angles(0, PI / 2, 0))
			y += 1.4
		end
		-- the banner: a pole at a front corner with a flag in the team's colour (not solid)
		local pa, pc = -back * (L / 2 - 0.3), T / 2 - 0.3
		cylinder("Pole", pa, h + 3.4, pc, 6.8, 0.3, CFrame.Angles(0, 0, PI / 2), false)
		ball("Finial", pa, h + 6.9, pc, 0.55, false)
		local flag = box("Flag", pa, h + 5.4, pc - 1.35, 0.15, 2.2, 2.4, false)
		flag.flag = true
		wedge("FlagTail", pa, h + 3.9, pc - 1.35, 0.15, 0.8, 2.4, "-C", true, false)
	elseif key == "bridge" then
		-- a deck of planks on two stringers between bevelled piers at the ends, braces under it, a rail each side
		local deckY = h - 0.4
		local planks = 6
		for i = 1, planks do
			local a = -L / 2 + (i - 0.5) * L / planks
			box("Plank", a, deckY, 0, L / planks - 0.12, 0.8, T)
		end
		for _, sc in { 1, -1 } do
			box("Stringer", 0, h - 1.1, sc * (T / 2 - 0.35), L - 0.4, 0.6, 0.7, false)
		end
		for _, sa in { 1, -1 } do
			local a = sa * (L / 2 - 0.8)
			box("Pier", a, (h - 0.8) / 2, 0, 1.6, h - 0.8, T - 0.4)
			box("PierFoot", a, 0.3, 0, 2, 0.6, T)
			-- (braces from each pier out under the deck)
			for _, sc in { 1, -1 } do
				brace("Brace", sc * (T / 2 - 0.5), a - sa * 0.8, h * 0.35, a - sa * 3.4, h - 1.3, 0.4, false)
			end
		end
		for _, sc in { 1, -1 } do
			local c = sc * (T / 2 - 0.15)
			box("Rail", 0, h + 1.1, c, L - 0.2, 0.25, 0.25, false)
			for i = 0, 4 do
				box("RailPost", -L / 2 + 0.3 + i * (L - 0.6) / 4, h + 0.55, c, 0.3, 1.1, 0.3, false)
			end
		end
	elseif key == "cover" then
		-- a stout block: a plinth, corner posts, crossed braces on every face, a bevelled cap
		box("Plinth", 0, 0.3, 0, L, 0.6, T)
		box("Body", 0, 0.6 + (h - 1.4) / 2, 0, L - 0.9, h - 1.4, T - 0.9)
		for _, sa in { 1, -1 } do
			for _, sc in { 1, -1 } do
				box("Post", sa * (L / 2 - 0.4), (h - 0.2) / 2, sc * (T / 2 - 0.4), 0.8, h - 0.2, 0.8)
			end
		end
		for _, sc in { 1, -1 } do
			local c = sc * (T / 2 - 0.4)
			brace("Brace", c, -L / 2 + 0.8, 1, L / 2 - 0.8, h - 1.2, 0.3, false)
			brace("Brace", c, -L / 2 + 0.8, h - 1.2, L / 2 - 0.8, 1, 0.3, false)
		end
		for _, sa in { 1, -1 } do
			local a = sa * (L / 2 - 0.4)
			local turn = CFrame.Angles(0, PI / 2, 0)
			box(
				"Brace",
				a,
				h / 2,
				0,
				math.sqrt((T - 1.6) ^ 2 + (h - 2.2) ^ 2),
				0.3,
				0.3,
				false,
				turn * CFrame.fromAxisAngle(Vector3.new(0, 0, 1), math.atan2(h - 2.2, T - 1.6))
			)
			box(
				"Brace",
				a,
				h / 2,
				0,
				math.sqrt((T - 1.6) ^ 2 + (h - 2.2) ^ 2),
				0.3,
				0.3,
				false,
				turn * CFrame.fromAxisAngle(Vector3.new(0, 0, 1), -math.atan2(h - 2.2, T - 1.6))
			)
		end
		cap("Cap", h - 0.3, L, T, 0.6, 0.4, true)
	elseif key == "banner" then
		-- a stepped base, a pole with a finial, a crossbar, and the flag (the builder's emblem on it)
		box("Base", 0, 0.25, 0, 2.6, 0.5, 2.6)
		box("Base", 0, 0.7, 0, 1.8, 0.4, 1.8)
		cap("BaseCap", 1.05, 1.4, 1.4, 0.3, 0.25, true)
		cylinder("Pole", 0, (1.2 + h) / 2, 0, h - 1.2, 0.6, CFrame.Angles(0, 0, PI / 2))
		ball("Finial", 0, h + 0.3, 0, 0.8, false)
		box("Crossbar", 1.2, h - 0.5, 0, 2.8, 0.25, 0.25, false)
		local flag = box("Flag", 1.2, h - 2.6, 0, 2.4, 3.8, 0.2, false)
		flag.flag = true
		for _, s in { -1, 1 } do
			-- (the swallowtail: two points at the bottom, the notch between them)
			wedge("FlagTail", 1.2 + s * 0.6, h - 4.9, 0, 0.2, 0.8, 1.2, s > 0 and "-A" or "+A", true, false)
		end
	else
		box("Body", 0, h / 2, 0, L, h, T)
	end
	return out
end

-- One entry as a part (anchored; solid or not as it says; its tone kept so a team change can paint it again)
function StructureModel.make(spec, team)
	local p = Instance.new(spec.wedge and "WedgePart" or "Part")
	p.Name = spec.name or "Piece"
	p.Anchored = true
	p.Size = spec.size
	p.CFrame = spec.cf
	p.Material = Enum.Material.SmoothPlastic
	p.Color = StructureModel.color(spec.tone, team)
	p.CanCollide = spec.solid ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if spec.shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	elseif spec.shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	end
	p:SetAttribute("Tone", spec.tone)
	return p
end

return StructureModel
