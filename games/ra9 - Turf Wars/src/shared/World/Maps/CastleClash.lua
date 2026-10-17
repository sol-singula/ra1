--[[
Castle Clash: a white stone courtyard inside high castle walls. Each half has a rampart (a gate arch and two side
gaps) under a walk you climb by stairs from your own side (the high ground: battlements in front, exposed from the
towers), tall gate towers with battlements and flags, a corner keep, statues of archers guarding the gate, and an
arcade on each long wall. In the middle, two colonnades under a crowned entablature, topiary in planters, and the
fountain with its obelisk. Balanced lanes, moderate cover: the map that teaches the game.

Drawn for the small arena; A:fx / A:fz stretch it for a bigger one, and the colonnades and arcades grow more bays.
]]
return {
	key = "castle",
	name = "Castle Clash",
	tagline = "A courtyard of arches. Hold the gate.",
	length = 200,
	width = 96,
	wallHeight = 40,
	crown = "battlements",
	palette = {
		white = Color3.fromRGB(244, 243, 240),
		light = Color3.fromRGB(228, 227, 223),
		grey = Color3.fromRGB(198, 197, 194),
		dark = Color3.fromRGB(160, 158, 155),
	},
	lighting = { clock = 14.2, ambient = Color3.fromRGB(170, 170, 172), brightness = 2.6, haze = 1.2 },
	-- distant keeps: a tall block, a narrower stage, a stepped cap
	skyline = function(A, x, z, w, d, h, _, i)
		local c = (i % 2 == 0) and A.white or A.light
		A:box(
			Vector3.new(x, h / 2 - 2, z),
			Vector3.new(w * 0.7, h, d * 0.7),
			{ color = c, collide = false, solid = false, shadow = false }
		)
		A:box(
			Vector3.new(x, h + h * 0.1 - 2, z),
			Vector3.new(w * 0.45, h * 0.2, d * 0.45),
			{ color = A.light, collide = false, solid = false, shadow = false }
		)
		if i % 3 == 0 then
			A:box(
				Vector3.new(x, h * 1.2 + 2, z),
				Vector3.new(w * 0.25, 8, d * 0.25),
				{ color = A.white, collide = false, solid = false, shadow = false }
			)
		end
		return true
	end,
	build = function(A)
		local W = A.W
		local leaf = Color3.fromRGB(212, 222, 204)
		local leaf2 = Color3.fromRGB(198, 210, 190)
		local function deco(c, extra)
			local o = { color = c, solid = false, collide = false }
			for k, v in extra or {} do
				o[k] = v
			end
			return o
		end
		A:mirror(function(s)
			local wx = s * A:fx(58)
			local span = A:fz(10)
			local pier = 3
			local gate0, gate1 = span / 2 + pier, A:fz(24)
			-- the rampart: the gate arch (its lintel is the walk's floor) and a wall each side of it, 10 high
			A:arch(wx, 0, span, 7, 4, "x", { pier = pier })
			for _, zs in { -1, 1 } do
				local cz, len = zs * (gate0 + gate1) / 2, gate1 - gate0
				A:block(wx, cz, 4, len, 10, { color = A.white })
				A:block(wx, cz, 5, len + 1, 0.8, { color = A.light }, 10)
				-- battlements on the field side of the walk
				local n = math.floor(len / 2.4)
				for i = 0, n - 1 do
					A:block(
						wx - s * 1.9,
						cz - len / 2 + 1 + i * ((len - 2) / math.max(1, n - 1)),
						1,
						1.2,
						2,
						{ color = A.white },
						10.8
					)
				end
				-- arrow slits and a tall banner on the wall's face
				for k = 0, 2 do
					A:block(wx - s * 2.05, cz + (k - 1) * len / 3.2, 0.2, 0.7, 3, deco(A.dark), 4)
				end
				A:block(wx - s * 2.15, cz, 0.2, 3.4, 7.4, deco(A:teamColor(s)), 2.4)
				A:block(wx - s * 2.25, cz, 0.2, 0.7, 7, deco(A.white), 2.6)
			end
			-- over the gate: the walk's parapet and a crest
			for i = -2, 2 do
				A:block(wx - s * 1.9, i * span / 5, 1, 1.2, 2, { color = A.white }, 10.8)
			end
			A:block(wx - s * 2.1, 0, 0.3, 6, 2.6, deco(A:teamColor(s)), 7.2)
			-- stairs up to the walk from your own side, by both wall halves
			for _, zs in { -1, 1 } do
				local z = zs * (gate0 + gate1) / 2
				for i = 1, 10 do
					A:block(
						wx + s * (2 + 12.5 - (i - 0.5) * 1.25),
						z,
						1.25,
						5,
						i,
						{ color = (i % 2 == 0) and A.white or A.light }
					)
				end
				-- a low wall up the open side of the stairs
				A:box(
					CFrame.new(wx + s * 8.25, 5.6, z + zs * 2.7) * CFrame.Angles(0, 0, math.rad(s * 38.7)),
					Vector3.new(16, 0.8, 0.5),
					{ color = A.light, solid = false, collide = false }
				)
			end
			-- the gate towers at the rampart's ends, with battlements and a flag
			for _, zs in { -1, 1 } do
				local tz = zs * A:fz(38)
				local top = A:tower(wx, tz, 11, 16, 26, { floor = 8.5 })
				A:flag(wx, tz, top + 3, s)
			end
			-- the keep in the corner by the base: taller still, a stepped roof
			for _, zs in { -1, 1 } do
				A:tower(s * (A.edge - 6), zs * (W - 7), 9, 9, 34, { crown = "roof", floor = 8.5 })
			end
			-- statues of archers on the field side of the gate, looking out over the courtyard
			for _, zs in { -1, 1 } do
				A:statue(s * A:fx(44), zs * A:fz(10), -s, 1, s)
			end
			-- low cover in front of the gate: a stone bench
			A:block(s * A:fx(34), 0, 2, 9, 3.4, { color = A.light })
			A:block(s * A:fx(34), 0, 2.6, 9.6, 0.4, { color = A.white }, 3.4)
			-- the colonnades: columns under a crowned entablature, both sides of the courtyard
			local c0, c1 = s * A:fx(8), s * A:fx(32)
			local cols = math.floor(math.abs(c1 - c0) / 8 + 0.5) + 1
			for _, zs in { -1, 1 } do
				A:colonnade(c0, c1, zs * A:fz(24), "x", cols, 18, 1.3)
			end
			-- arcades against the long walls: arches every 10 studs from the colonnade's end to the gate
			for ax = A:fx(26), A:fx(52), 10 do
				for _, zs in { -1, 1 } do
					A:arch(s * ax, zs * (W - 3), 6, 11, 2, "z", { pier = 1.5 })
				end
			end
			-- (detail) torches either side of the gate, a cobbled path through it, crates by the stairs
			for _, zs in { -1, 1 } do
				A:lamp(wx - s * 4, zs * (gate0 + 1.5), 6, Color3.fromRGB(255, 236, 200))
			end
			for i = 0, 9 do
				A:block(wx - s * (6 + i * 3), 0, 2.6, 7, 0.1, deco((i % 2 == 0) and A.light or A.grey))
			end
			A:crates(wx + s * 6, A:fz(28), 3, 15)
			A:crates(wx + s * 6, -A:fz(28), 2, -20)
			for _, zs in { -1, 1 } do
				A:rubble(wx - s * 7, zs * A:fz(31), 5, 11 + zs)
			end
			-- topiary in planters between the colonnade and the wall: a box, a cone of clipped leaves
			for k = 0, cols - 2 do
				local px = s * (A:fx(12) + k * 8)
				for _, zs in { -1, 1 } do
					local pz = zs * A:fz(31)
					A:block(px, pz, 2.6, 2.6, 1.6, { color = A.light })
					A:block(px, pz, 2, 2, 1.6, deco(leaf), 1.6)
					A:block(px, pz, 1.3, 1.3, 1.4, deco(leaf2), 3.2)
					A:block(px, pz, 0.7, 0.7, 1, deco(leaf), 4.6)
				end
			end
			-- (a bigger arena) a walled garden bed either side of the gate's path: low cover with topiary
			if A.tier ~= "small" then
				for _, zs in { -1, 1 } do
					local gx, gz = s * A:fx(39), zs * A:fz(19)
					A:block(gx, gz, 8, 3, 2.2, { color = A.light })
					A:block(gx, gz, 8.4, 3.4, 0.3, { color = A.white, solid = false, collide = false }, 2.2)
					for k = -1, 1 do
						A:block(gx + k * 2.6, gz, 1.6, 1.6, 1.8, deco(leaf), 2.2)
						A:block(gx + k * 2.6, gz, 0.8, 0.8, 1, deco(leaf2), 4)
					end
				end
			end
			-- lamp posts down the middle lanes
			for _, zs in { -1, 1 } do
				A:lamp(s * A:fx(20), zs * A:fz(16), 8)
			end
		end)
		-- the fountain in the middle: stacked plinths, a basin of water, an obelisk with a crown
		A:block(0, 0, 12, 12, 1, { color = A.light })
		A:block(0, 0, 9, 9, 2.2, { color = A.white }, 1)
		A:block(0, 0, 9.6, 9.6, 0.4, { color = A.light }, 3.2)
		A:block(0, 0, 3, 3, 12, { color = A.white }, 3.2)
		A:block(0, 0, 3.6, 3.6, 0.6, { color = A.light }, 15.2)
		A:block(0, 0, 2.2, 2.2, 2, { color = A.white }, 15.8)
		A:block(0, 0, 1.2, 1.2, 2.2, { color = A.light }, 17.8)
		A:block(0, 0, 8.2, 8.2, 0.3, {
			color = Color3.fromRGB(205, 225, 240),
			material = Enum.Material.Glass,
			transparency = 0.3,
			solid = false,
			collide = false,
		}, 3)
		for _, c in { { 9, 9 }, { -9, 9 }, { 9, -9 }, { -9, -9 } } do
			A:lamp(c[1], c[2], 7)
		end
		-- a ring of paving round the fountain
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			A:box(
				CFrame.new(math.cos(a) * 8, 0.05, math.sin(a) * 8) * CFrame.Angles(0, -a, 0),
				Vector3.new(1.4, 0.1, 3),
				{ color = (i % 2 == 0) and A.light or A.grey, solid = false, collide = false }
			)
		end
	end,
}
