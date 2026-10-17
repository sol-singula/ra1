--[[
Jungle Rush: overgrown ruins, all in matte off-white with pale sage "leaves" (flat geometric slabs, never textures).
Each half has two stepped temples (four tiers and a roofed shrine on top; stairs up the back from your own side to
the third tier, the firing ledge), broken walls that cut the field into narrow routes, a grove of tall square pillars
with leaf canopies along the walls, giant stone heads watching the middle, and great trees in the corners. In the
middle, a corbelled gate with a carved lintel and two side passages. More cover, narrower routes, flanks. Leaves
sit high, so nobody hides in them at head height.

Drawn for the small arena; A:fx / A:fz stretch it for a bigger one, and the grove grows more pillars.
]]
return {
	key = "jungle",
	name = "Jungle Rush",
	tagline = "Overgrown ruins. Flank through the grove.",
	length = 200,
	width = 96,
	wallHeight = 36,
	palette = {
		white = Color3.fromRGB(242, 243, 238),
		light = Color3.fromRGB(226, 230, 220),
		grey = Color3.fromRGB(196, 204, 190),
		dark = Color3.fromRGB(150, 162, 145),
	},
	lighting = { clock = 15.5, ambient = Color3.fromRGB(165, 172, 160), brightness = 2.4, haze = 1.4 },
	-- the jungle beyond the walls: giant trees, and now and then a ruined pyramid
	skyline = function(A, x, z, w, _, h, r, i)
		local leaf = (i % 2 == 0) and Color3.fromRGB(206, 220, 196) or Color3.fromRGB(190, 206, 180)
		local o = { color = leaf, collide = false, solid = false, shadow = false }
		if i % 7 == 0 then
			for k = 0, 3 do
				A:box(
					Vector3.new(x, k * 9 + 2.5, z),
					Vector3.new(w * 1.6 - k * w * 0.35, 9, w * 1.6 - k * w * 0.35),
					{ color = (k % 2 == 0) and A.white or A.light, collide = false, solid = false, shadow = false }
				)
			end
			return true
		end
		A:box(
			Vector3.new(x, h * 0.4, z),
			Vector3.new(2.4, h * 0.8, 2.4),
			{ color = A.grey, collide = false, solid = false, shadow = false }
		)
		A:box(
			CFrame.new(x, h * 0.8, z) * CFrame.Angles(0.08, r:NextNumber(0, 3), -0.05),
			Vector3.new(w * 1.2, 5, w * 1.1),
			o
		)
		A:box(
			CFrame.new(x, h * 0.8 + 4, z) * CFrame.Angles(-0.06, r:NextNumber(0, 3), 0.07),
			Vector3.new(w * 0.8, 4, w * 0.75),
			{ color = A.light, collide = false, solid = false, shadow = false }
		)
		return true
	end,
	build = function(A)
		local W = A.W
		local leaf = Color3.fromRGB(206, 220, 196)
		local leafDark = Color3.fromRGB(186, 204, 176)
		local function deco(c, extra)
			local o = { color = c, solid = false, collide = false }
			for k, v in extra or {} do
				o[k] = v
			end
			return o
		end
		local function canopy(x, z, y, size)
			-- three flat slabs at different angles: a geometric tuft of leaves
			for i = 0, 2 do
				local cf = CFrame.new(x, y + i * 0.6, z)
					* CFrame.Angles(math.rad((i - 1) * 9), math.rad(i * 40), math.rad((1 - i) * 7))
				A:box(
					cf,
					Vector3.new(size - i, 0.5, size * 0.7 - i * 0.5),
					deco((i == 1) and leafDark or leaf, { shadow = true })
				)
			end
		end
		-- a vine hanging down a face: a few thin strips, each a little shorter
		local function vine(x, z, y, len, alongX)
			for k = 0, 2 do
				local off = (k - 1) * 0.6
				A:block(
					x + (alongX and off or 0),
					z + (alongX and 0 or off),
					alongX and 0.3 or 0.15,
					alongX and 0.15 or 0.3,
					len - k * len * 0.25,
					deco((k % 2 == 0) and leafDark or leaf),
					y - len + k * len * 0.25
				)
			end
		end
		A:mirror(function(s)
			-- the temples: four tiers, a roofed shrine on top, steps (decor) up the front; up the back, stairs a person
			-- walks: from the floor to the second tier, then to the third
			local tx, tz = s * A:fx(52), A:fz(28)
			for _, zs in { -1, 1 } do
				local z = zs * tz
				A:block(tx, z, 16, 14, 3, { color = A.light })
				A:block(tx, z, 12, 11, 3, { color = A.white }, 3)
				A:block(tx, z, 8, 8, 3, { color = A.light }, 6)
				A:block(tx, z, 5, 5, 3, { color = A.white }, 9)
				-- the shrine: four short piers under a stepped roof, a lamp inside
				for _, c in { { -1.8, -1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { 1.8, 1.8 } } do
					A:block(tx + c[1], z + c[2], 0.9, 0.9, 3.2, { color = A.light }, 12)
				end
				A:block(tx, z, 5.4, 5.4, 0.8, { color = A.white }, 15.2)
				A:block(tx, z, 4, 4, 0.8, { color = A.light }, 16)
				A:block(tx, z, 2.4, 2.4, 1, { color = A.white }, 16.8)
				A:block(tx, z, 1, 1, 1, deco(Color3.fromRGB(230, 255, 220), { material = Enum.Material.Neon }), 12.6)
				canopy(tx + 2, z - 2, 18.4, 7)
				-- carved bands: dark glyph squares round the second tier
				for k = -2, 2 do
					A:block(tx - s * 6.05, z + k * 2, 0.2, 1, 1, deco(A.dark), 4)
				end
				-- steps up the front (toward the middle): big stones, a jump each
				for i = 1, 3 do
					A:block(tx - s * (8 + 0.75) + s * (i - 1) * 2.5, z, 1.5, 4, i * 3 - 1.5, { color = A.white })
				end
				-- stairs up the back from your own side: to the second tier (6), then on it to the third (9)
				A:stairs(tx + s * (6 + 6 * 1.3), z + zs * 3, s > 0 and "-x" or "+x", 6, 1, 1.3, 3.6)
				A:stairs(tx + s * (4 + 3 * 0.65), z - zs * 3, s > 0 and "-x" or "+x", 3, 1, 0.65, 2.6, { y0 = 6 })
				vine(tx - s * 8.05, z + zs * 4, 3, 2.6, false)
				vine(tx + zs * 0, z + zs * 7.05, 6, 3.4, true)
			end
			-- broken walls: narrow routes through the middle third
			A:block(s * A:fx(30), 0, 2, 12, 8, { color = A.white })
			A:block(s * A:fx(30), 0, 2.4, 12.4, 0.6, { color = A.light }, 8)
			vine(s * A:fx(30) - s * 1.05, 2, 8, 5, false)
			for _, zs in { -1, 1 } do
				A:block(s * A:fx(22), zs * A:fz(16), 10, 2, 4, { color = A.light })
				A:block(s * A:fx(22) + s * 3, zs * A:fz(16), 4, 2, 2.5, { color = A.white }, 4)
			end
			-- the grove: tall square pillars with leaf canopies and vines, flanking routes along the walls
			local g0, g1 = A:fx(14), A:fx(41)
			local n = math.floor((g1 - g0) / 9 + 0.5)
			for k = 0, n do
				for _, zs in { -1, 1 } do
					local px, pz = s * (g0 + k * 9), zs * (W - 8 - (k % 2) * 3)
					local h = 16 + (k % 2) * 4
					A:pillar(px, pz, h, 2)
					canopy(px, pz, h + 1.5, 7)
					A:block(px + 1.05, pz, 0.15, 0.6, h - 6, deco(leafDark), 3)
					A:block(px, pz - 1.05, 0.5, 0.15, h - 8, deco(leaf), 5)
				end
			end
			-- giant stone heads against the long walls, watching the middle
			for _, zs in { -1, 1 } do
				local hx, hz = s * A:fx(62), zs * (W - 6)
				local f = -s -- (the face looks toward the middle)
				A:block(hx, hz, 7, 7, 1, { color = A.light })
				A:block(hx, hz, 6, 6, 7, { color = A.white }, 1)
				A:block(hx, hz, 6.6, 6.6, 1.4, { color = A.light }, 8) -- the headdress band
				A:block(hx, hz, 5, 5, 1.6, { color = A.white }, 9.4)
				A:block(hx + f * 3.05, hz, 0.3, 5, 0.8, deco(A.light), 6) -- the brow
				for _, e in { -1.3, 1.3 } do
					A:block(hx + f * 3.1, hz + e, 0.2, 1.2, 0.8, deco(A.dark), 5) -- the eyes
				end
				A:wedge(
					CFrame.new(hx + f * 3.4, 4, hz) * CFrame.Angles(0, f > 0 and -math.pi / 2 or math.pi / 2, 0),
					Vector3.new(1.4, 2, 0.8),
					deco(A.light)
				) -- the nose
				A:block(hx + f * 3.1, hz, 0.2, 2.6, 0.4, deco(A.dark), 2.4) -- the mouth
				canopy(hx, hz, 11.4, 6)
			end
			-- great trees in the corners by the base
			for _, zs in { -1, 1 } do
				A:tree(s * (A.edge - 5), zs * (W - 6), 18, leaf, leafDark, 1.6)
			end
			-- (a bigger arena) a ring of broken columns in the open, a drum fallen from one
			if A.tier ~= "small" then
				for _, zs in { -1, 1 } do
					local bx, bz = s * A:fx(46), zs * A:fz(10)
					A:pillar(bx, bz, 7, 2)
					A:pillar(bx + s * 5, bz + zs * 3, 4, 2)
					A:box(
						CFrame.new(bx - s * 3, 1, bz + zs * 3) * CFrame.Angles(0, math.rad(30), math.rad(90)),
						Vector3.new(4, 2, 2),
						{ color = A.light }
					)
					canopy(bx, bz, 8.5, 5)
				end
			end
			-- fallen blocks: low cover
			A:box(
				CFrame.new(s * A:fx(40), 1.2, -A:fz(6)) * CFrame.Angles(0, math.rad(s * 20), math.rad(8)),
				Vector3.new(6, 2.4, 3),
				{ color = A.light }
			)
			A:box(
				CFrame.new(s * A:fx(40), 1.2, A:fz(8)) * CFrame.Angles(0, math.rad(-s * 35), math.rad(-6)),
				Vector3.new(5, 2.4, 3),
				{ color = A.white }
			)
			-- (detail) stepping stones, a shrine lamp by each temple, rubble, ferns at the walls' feet
			for i = 0, 6 do
				A:block(
					s * A:fx(10 + i * 6),
					(i % 2 == 0) and 4 or -4,
					2.4,
					2.4,
					0.15,
					deco((i % 2 == 0) and A.light or A.grey)
				)
			end
			for _, zs in { -1, 1 } do
				A:lamp(tx, zs * (tz + 9), 3, Color3.fromRGB(230, 255, 220))
				A:rubble(s * A:fx(34), zs * A:fz(26), 6, 40 + zs)
				canopy(s * A:fx(30), zs * 6, 10.5, 5)
			end
			A:crates(s * A:fx(66), 0, 3, s * 10)
			for k = 0, 3 do
				for _, zs in { -1, 1 } do
					local cf = CFrame.new(s * A:fx(20 + k * 15), 0.6, zs * (W - 1.4))
						* CFrame.Angles(math.rad(zs * 20), math.rad(k * 30), 0)
					A:box(cf, Vector3.new(3, 0.3, 2), deco(leaf))
				end
			end
			-- vines hanging from the tops of the long walls
			for x = A:fx(8), A.edge - 4, 9 do
				for _, zs in { -1, 1 } do
					vine(s * x, zs * (W - 0.2), A.wallH - 1, 6 + (x % 5), true)
				end
			end
		end)
		-- the gate in the middle: a corbelled arch (each course steps in over the opening), a carved lintel, a capstone
		-- and a canopy; the side passages beside it
		for _, zs in { -1, 1 } do
			A:block(0, zs * 6, 3, 4, 9, { color = A.white })
			for k = 1, 3 do
				A:block(
					0,
					zs * (6 - k * 0.9),
					3,
					4,
					1.2,
					{ color = (k % 2 == 0) and A.white or A.light },
					9 + (k - 1) * 1.2
				)
			end
		end
		A:block(0, 0, 3.4, 10, 2, { color = A.white }, 12.6)
		for k = -2, 2 do
			A:block(1.75, k * 1.8, 0.2, 1, 1, deco(A.dark), 13.1)
			A:block(-1.75, k * 1.8, 0.2, 1, 1, deco(A.dark), 13.1)
		end
		A:block(0, 0, 2.6, 4, 2, { color = A.light }, 14.6)
		canopy(0, 0, 17, 10)
		for _, zs in { -1, 1 } do
			A:block(0, zs * A:fz(20), 3, 14, 7, { color = A.white })
			A:block(0, zs * A:fz(20), 3.6, 14.6, 0.6, { color = A.light }, 7)
			vine(1.55, zs * A:fz(20), 7, 4, false)
			vine(-1.55, zs * A:fz(20), 7, 4, false)
		end
	end,
}
