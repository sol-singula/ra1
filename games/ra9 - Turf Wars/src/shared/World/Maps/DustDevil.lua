--[[
Dust Devil: a canyon of tall warm-white slabs. Stepped mesas with strata line both long walls and pinch the field in
the middle, hoodoos (stacked, narrowing rocks) stand between them, and a rock arch spans each corner by the base. A
bridge with railings crosses each half high up between gate pylons (the long-range perch, up its ramps from your own
side), an adobe lookout with stairs stands by each base, and tall standing slabs at angles give the few covers that
matter. The floor between is long and open: sightlines for the heavy bow.

Drawn for the small arena; A:fx / A:fz stretch it for a bigger one, and the mesas and poles grow in number.
]]
return {
	key = "dust",
	name = "Dust Devil",
	tagline = "A canyon of slabs. Long shots across open ground.",
	length = 200,
	width = 96,
	wallHeight = 36,
	palette = {
		white = Color3.fromRGB(246, 241, 232),
		light = Color3.fromRGB(234, 226, 212),
		grey = Color3.fromRGB(208, 197, 180),
		dark = Color3.fromRGB(170, 156, 136),
	},
	lighting = { clock = 16.8, ambient = Color3.fromRGB(180, 170, 158), brightness = 3.2, haze = 1 },
	-- the desert beyond the walls: flat-topped mesas, buttes, and the odd windmill
	skyline = function(A, x, z, w, d, h, _, i)
		local o = { color = (i % 2 == 0) and A.white or A.light, collide = false, solid = false, shadow = false }
		if i % 9 == 0 then
			A:box(Vector3.new(x, 14, z), Vector3.new(2, 32, 2), o)
			for k = 0, 3 do
				A:box(
					CFrame.new(x, 30, z) * CFrame.Angles(0, 0, k * math.pi / 2 + 0.3) * CFrame.new(0, 5, -1.4),
					Vector3.new(1.4, 10, 0.3),
					{ color = A.grey, collide = false, solid = false, shadow = false }
				)
			end
			return true
		end
		local hh = h * 0.6
		A:box(Vector3.new(x, hh / 2 - 2, z), Vector3.new(w * 1.6, hh, d * 1.3), o)
		A:box(
			Vector3.new(x, hh + 1, z),
			Vector3.new(w * 1.2, 6, d * 0.9),
			{ color = A.grey, collide = false, solid = false, shadow = false }
		)
		return true
	end,
	build = function(A)
		local W = A.W
		local cactus = Color3.fromRGB(214, 220, 196)
		local cactus2 = Color3.fromRGB(206, 214, 188)
		local function deco(c, extra)
			local o = { color = c, solid = false, collide = false }
			for k, v in extra or {} do
				o[k] = v
			end
			return o
		end
		-- a hoodoo: stacked rocks, each narrower, a wide cap on top (solid at the bottom, looks above)
		local function hoodoo(x, z, h, yaw)
			local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0)
			A:box(cf * CFrame.new(0, h * 0.2, 0), Vector3.new(4.2, h * 0.4, 3.6), { color = A.light })
			A:box(cf * CFrame.new(0.2, h * 0.55, 0), Vector3.new(3, h * 0.32, 2.6), deco(A.white, { shadow = true }))
			A:box(cf * CFrame.new(-0.1, h * 0.8, 0.1), Vector3.new(2, h * 0.2, 1.8), deco(A.grey, { shadow = true }))
			A:box(cf * CFrame.new(0, h * 0.93, 0), Vector3.new(4.6, 1.4, 4), deco(A.light, { shadow = true }))
		end
		A:mirror(function(s)
			-- mesas along the long walls: stacked slabs, stepped tops, strata lines across their faces
			local m0, m1 = A:fx(18), A:fx(58)
			local n = math.floor((m1 - m0) / 20 + 0.5)
			for _, zs in { -1, 1 } do
				for k = 0, n do
					local mx = s * (m0 + k * 20)
					local depth = 10 - (k % 3) * 2
					local h = 32 - (k % 3) * 6
					local face = zs * (W - depth / 2)
					A:block(mx, face, 16, depth, h, { color = (k % 2 == 0) and A.white or A.light })
					A:block(mx, zs * (W - depth / 2 - 1), 12, depth - 2, 3, { color = A.light }, h)
					A:block(mx + s * 2, zs * (W - depth / 2 + 1), 7, depth - 4, 3, { color = A.white }, h + 3)
					for _, f in { 0.25, 0.45, 0.7 } do
						A:block(mx, zs * (W - depth - 0.2), 16.4, 0.5, 0.5, deco(A.grey), h * f)
					end
					-- an overhang near the top, the canyon's lip
					A:block(mx, zs * (W - depth - 0.6), 14, 1.6, 1, deco(A.light, { shadow = true }), h - 2)
				end
			end
			-- hoodoos between the mesas, out in front of the walls
			for k = 0, n - 1 do
				for _, zs in { -1, 1 } do
					hoodoo(s * (m0 + 10 + k * 20), zs * (W - 13), 14 + (k % 2) * 5, k * 40 + zs * 15)
				end
			end
			-- a rock arch over each corner by the base: two legs and a lintel of stacked slabs
			for _, zs in { -1, 1 } do
				local ax = s * (A.edge - 7)
				A:block(ax, zs * (W - 3), 6, 6, 22, { color = A.light })
				A:block(ax - s * 9, zs * (W - 3), 5, 5, 20, { color = A.white })
				A:block(ax - s * 4.5, zs * (W - 3), 17, 6, 4, { color = A.white }, 20)
				A:block(ax - s * 4.5, zs * (W - 3.5), 13, 5, 2, { color = A.light }, 24)
			end
			-- the bridge across the half: a deck 10 up, piers in the middle, railings both sides, gate pylons at its ends
			local bx = s * A:fx(46)
			local bl = A:fz(64)
			A:block(bx, 0, 6, bl, 1.2, { color = A.white }, 10)
			A:block(bx, 0, 6.6, bl, 0.4, deco(A.light), 9.6)
			for _, side in { -1, 1 } do
				A:railing(Vector3.new(bx + side * 3, 0, -bl / 2), Vector3.new(bx + side * 3, 0, bl / 2), 11.2)
			end
			for _, zs in { -1, 1 } do
				A:block(bx, zs * A:fz(12), 3, 3, 10, { color = A.light })
				-- the pylons: two posts and a beam over the deck, a lamp on each post
				local pz = zs * (bl / 2 - 2)
				for _, side in { -1, 1 } do
					A:block(bx + side * 3.6, pz, 1.4, 1.4, 20, { color = A.light })
					A:block(bx + side * 3.6, pz, 2, 2, 0.6, deco(A.white), 20)
				end
				A:block(bx, pz, 9, 1.6, 1.4, { color = A.white }, 18.6)
				A:block(bx, pz, 3.2, 0.3, 1.4, deco(A:teamColor(s)), 17)
				A:lamp(bx, zs * A:fz(12) + zs * 2.2, 9, Color3.fromRGB(255, 230, 190))
			end
			-- ramps up to the bridge from the mesa ends (on your own side of it)
			for _, zs in { -1, 1 } do
				local cf = CFrame.new(bx + s * 9, 5, zs * A:fz(30)) * CFrame.Angles(0, 0, math.rad(-s * 34))
				A:box(cf, Vector3.new(20, 1.2, 6), { color = A.light })
			end
			-- standing slabs at angles: the covers that matter
			A:box(
				CFrame.new(s * A:fx(26), 8, A:fz(8)) * CFrame.Angles(0, math.rad(s * 25), math.rad(s * 6)),
				Vector3.new(2, 16, 9),
				{ color = A.white }
			)
			A:box(
				CFrame.new(s * A:fx(30), 7, -A:fz(14)) * CFrame.Angles(0, math.rad(-s * 15), math.rad(-s * 5)),
				Vector3.new(2, 14, 8),
				{ color = A.light }
			)
			-- (a bigger arena) another pair of standing slabs out in the open
			if A.tier ~= "small" then
				A:box(
					CFrame.new(s * A:fx(14), 7, A:fz(27)) * CFrame.Angles(0, math.rad(-s * 30), math.rad(s * 4)),
					Vector3.new(2, 14, 8),
					{ color = A.light }
				)
				A:box(
					CFrame.new(s * A:fx(40), 6, -A:fz(2)) * CFrame.Angles(0, math.rad(s * 10), math.rad(-s * 6)),
					Vector3.new(2, 12, 7),
					{ color = A.white }
				)
			end
			-- the lookout by the base: an adobe deck with stairs from your own side and a parapet, a shade roof on posts
			local lx = s * A:fx(68)
			for _, zs in { -1, 1 } do
				local lz = zs * A:fz(18)
				A:platform(lx, lz, 8, 8, 6, s > 0 and "+x" or "-x", 4)
				A:block(lx - s * 3.8, lz, 0.6, 8, 1.6, { color = A.white }, 6)
				for _, c in { { -3.4, -3.4 }, { 3.4, -3.4 }, { -3.4, 3.4 }, { 3.4, 3.4 } } do
					A:block(lx + c[1], lz + c[2], 0.6, 0.6, 5, deco(A.light, { shadow = true }), 6)
				end
				A:block(lx, lz, 9, 9, 0.5, deco(A.white, { shadow = true }), 11)
				A:block(lx, lz, 9.4, 1, 0.3, deco(A:teamColor(s)), 10.7)
			end
			A:block(s * A:fx(64), 0, 3, 10, 3.5, { color = A.light })
			A:block(s * A:fx(64), 0, 3.6, 10.6, 0.5, { color = A.white }, 3.5)
			-- (detail) geometric cacti, boulders, sandbags by the ramps, telegraph poles along a wall
			for _, c in { { 36, 20 }, { 54, -22 }, { 22, -30 } } do
				local cx, cz = s * A:fx(c[1]), A:fz(c[2])
				A:block(cx, cz, 1.4, 1.4, 7, { color = cactus })
				A:block(cx + 1.2, cz, 1.0, 1.0, 1, deco(cactus), 2.6)
				A:block(cx + 1.7, cz, 1.0, 1.0, 2.6, deco(cactus2), 3.1)
				A:block(cx - 1.2, cz, 1.0, 1.0, 1, deco(cactus), 3.6)
				A:block(cx - 1.7, cz, 1.0, 1.0, 2, deco(cactus2), 4.1)
			end
			for _, zs in { -1, 1 } do
				for k = 0, 3 do
					A:block(bx + s * 13, zs * (A:fz(24) + k * 1.6), 3.2, 1.4, 1.1, { color = A.light })
				end
				A:rubble(s * A:fx(52), zs * A:fz(36), 6, 60 + zs)
			end
			A:box(
				CFrame.new(s * A:fx(16), 1.4, -A:fz(34)) * CFrame.Angles(math.rad(14), math.rad(s * 40), 0),
				Vector3.new(4, 2.8, 3.4),
				{ color = A.light }
			)
			A:crates(s * A:fx(72), A:fz(4), 3, s * 12)
			local poles = {}
			for x = A:fx(10), A.edge - 14, 16 do
				local px, pz = s * x, -(W - 15)
				A:block(px, pz, 0.6, 0.6, 14, deco(A.grey, { shadow = true }))
				A:block(px, pz, 0.4, 4, 0.4, deco(A.grey), 13)
				table.insert(poles, Vector3.new(px, 13.5, pz))
			end
			for i = 1, #poles - 1 do
				for _, off in { -1.6, 1.6 } do
					local a, b = poles[i] + Vector3.new(0, 0, off), poles[i + 1] + Vector3.new(0, 0, off)
					A:box(
						CFrame.lookAt((a + b) / 2 - Vector3.new(0, 0.6, 0), b),
						Vector3.new(0.08, 0.08, (b - a).Magnitude),
						deco(A.dark)
					)
				end
			end
			-- wind lines in the sand: long thin pale streaks
			for k = 0, 5 do
				A:box(
					CFrame.new(s * A:fx(12 + k * 10), 0.05, (k - 2.5) * A:fz(11))
						* CFrame.Angles(0, math.rad(8 + k * 3), 0),
					Vector3.new(14, 0.1, 0.35),
					deco(A.light)
				)
			end
		end)
		-- the middle: one low wall and two boulders. Open ground, few places to hide
		A:block(0, 0, 2, 14, 3.2, { color = A.light })
		A:block(0, 0, 2.6, 14.6, 0.5, { color = A.white }, 3.2)
		A:box(
			CFrame.new(-6, 1.6, A:fz(24)) * CFrame.Angles(math.rad(10), math.rad(30), 0),
			Vector3.new(5, 3.2, 4),
			{ color = A.white }
		)
		A:box(
			CFrame.new(6, 1.6, -A:fz(24)) * CFrame.Angles(math.rad(-10), math.rad(210), 0),
			Vector3.new(5, 3.2, 4),
			{ color = A.white }
		)
	end,
}
