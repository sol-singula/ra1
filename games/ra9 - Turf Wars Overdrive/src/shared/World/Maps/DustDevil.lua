--[[
Dust Devil: a canyon of tall warm-white slabs. Mesas line both long walls and pinch the field in the middle; a
bridge with railings crosses each half high up (the long-range perch); tall standing slabs at angles give the few
covers that matter. The floor between is long and open: sightlines for the heavy bow.
]]
return {
	key = "dust",
	name = "Dust Devil",
	tagline = "A canyon of slabs. Long shots across open ground.",
	length = 200,
	width = 96,
	palette = {
		white = Color3.fromRGB(246, 241, 232),
		light = Color3.fromRGB(234, 226, 212),
		grey = Color3.fromRGB(208, 197, 180),
		dark = Color3.fromRGB(170, 156, 136),
	},
	lighting = { clock = 16.8, ambient = Color3.fromRGB(180, 170, 158), brightness = 3.2, haze = 1 },
	build = function(A)
		A:mirror(function(s)
			-- mesas along the long walls: stacked slabs, stepped tops
			for _, zs in { -1, 1 } do
				for k = 0, 2 do
					local mx = s * (18 + k * 20)
					local depth = 10 - k * 2
					local h = 24 - k * 5
					A:block(mx, zs * (48 - depth / 2), 16, depth, h, { color = (k % 2 == 0) and A.white or A.light })
					A:block(mx, zs * (48 - depth / 2 - 1), 12, depth - 2, 2.5, { color = A.light }, h)
					-- strata lines: thin ledges across the mesa's face
					A:block(mx, zs * (48 - depth - 0.2), 16.4, 0.5, 0.5, { color = A.grey, solid = false }, h * 0.4)
					A:block(mx, zs * (48 - depth - 0.2), 16.4, 0.5, 0.5, { color = A.grey, solid = false }, h * 0.7)
				end
			end
			-- the bridge across the half: a deck 10 up between the mesas, piers in the middle, railings both sides
			local bx = s * 46
			A:block(bx, 0, 6, 64, 1.2, { color = A.white }, 10)
			for _, side in { -1, 1 } do
				A:railing(Vector3.new(bx + side * 3, 0, -32), Vector3.new(bx + side * 3, 0, 32), 11.2)
			end
			for _, zs in { -1, 1 } do
				A:block(bx, zs * 12, 3, 3, 10, { color = A.light })
			end
			-- ramps up to the bridge from the mesa ends (on your own side of it)
			for _, zs in { -1, 1 } do
				local cf = CFrame.new(bx + s * 9, 5, zs * 30) * CFrame.Angles(0, 0, math.rad(-s * 34))
				A:box(cf, Vector3.new(20, 1.2, 6), { color = A.light })
			end
			-- standing slabs at angles: the covers that matter
			A:box(
				CFrame.new(s * 26, 7, 8) * CFrame.Angles(0, math.rad(s * 25), math.rad(s * 6)),
				Vector3.new(2, 14, 9),
				{ color = A.white }
			)
			A:box(
				CFrame.new(s * 30, 6, -14) * CFrame.Angles(0, math.rad(-s * 15), math.rad(-s * 5)),
				Vector3.new(2, 12, 8),
				{ color = A.light }
			)
			A:block(s * 64, 0, 3, 10, 3.5, { color = A.light })
			A:block(s * 64, 0, 3.6, 10.6, 0.5, { color = A.white }, 3.5)
		end)
		-- the middle: one low wall and two boulders. Open ground, few places to hide
		A:block(0, 0, 2, 14, 3.2, { color = A.light })
		A:block(0, 0, 2.6, 14.6, 0.5, { color = A.white }, 3.2)
		A:box(
			CFrame.new(-6, 1.6, 24) * CFrame.Angles(math.rad(10), math.rad(30), 0),
			Vector3.new(5, 3.2, 4),
			{ color = A.white }
		)
		A:box(
			CFrame.new(6, 1.6, -24) * CFrame.Angles(math.rad(-10), math.rad(210), 0),
			Vector3.new(5, 3.2, 4),
			{ color = A.white }
		)
	end,
}
