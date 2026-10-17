--[[
Castle Clash: a white stone courtyard. Each half has a rampart with a gate arch and two side gaps, gate towers with
battlements at the corners, and stairs up to the rampart walk (high ground, but exposed). In the middle, two
colonnades under a long lintel and a fountain plinth with an obelisk. Balanced lanes, moderate cover: the map that
teaches the game.
]]
return {
	key = "castle",
	name = "Castle Clash",
	tagline = "A courtyard of arches. Hold the gate.",
	length = 200,
	width = 96,
	palette = {
		white = Color3.fromRGB(244, 243, 240),
		light = Color3.fromRGB(228, 227, 223),
		grey = Color3.fromRGB(198, 197, 194),
		dark = Color3.fromRGB(160, 158, 155),
	},
	lighting = { clock = 14.2, ambient = Color3.fromRGB(170, 170, 172), brightness = 2.6, haze = 1.2 },
	build = function(A)
		A:mirror(function(s)
			local wx = s * 58
			-- the gate towers at the corners, with battlements
			for _, zs in { -1, 1 } do
				local tz = zs * 38
				A:block(wx, tz, 11, 16, 20, { color = A.white })
				A:block(wx, tz, 12, 17, 1, { color = A.light }, 20)
				for i = -2, 2 do
					A:block(wx + 5.5 * 1, tz + i * 3.4, 1.4, 1.6, 2.2, { color = A.white }, 21)
					A:block(wx - 5.5, tz + i * 3.4, 1.4, 1.6, 2.2, { color = A.white }, 21)
				end
				-- slit windows: thin dark lines on the tower's face toward the courtyard
				for k = 0, 2 do
					A:block(wx - s * 5.6, tz + (k - 1) * 4, 0.3, 0.8, 4, { color = A.dark, solid = false }, 7 + k * 0.1)
				end
			end
			-- the rampart: two walls, a gate arch between, gaps at the towers
			for _, zs in { -1, 1 } do
				local cz = zs * 16
				A:block(wx, cz, 4, 16, 8, { color = A.white })
				A:block(wx, cz, 5, 17, 0.8, { color = A.light }, 8)
				for i = -3, 3 do
					A:block(wx + s * 1.9, cz + i * 2.3, 1, 1.2, 1.8, { color = A.white }, 8.8)
				end
			end
			A:arch(wx, 0, 10, 10, 4, "x", { pier = 3 })
			-- stairs up to the rampart walk, on the side away from the frontline
			for _, zs in { -1, 1 } do
				local base = wx + s * 14
				for i = 1, 8 do
					A:block(
						base - s * (i - 0.5) * 1.25,
						zs * 16,
						1.25,
						6,
						i,
						{ color = (i % 2 == 0) and A.white or A.light }
					)
				end
			end
			-- the colonnade: columns under a lintel, both sides of the courtyard
			for _, zs in { -1, 1 } do
				for k = 0, 3 do
					A:column(s * (8 + k * 8), zs * 24, 16, 1.3)
				end
				A:block(s * 20, zs * 24, 30, 3, 2, { color = A.white }, 16)
				A:block(s * 20, zs * 24, 31, 3.6, 0.6, { color = A.light }, 18)
			end
			-- low cover in front of the gate: a stone bench and two plinths
			A:block(s * 34, 0, 2, 9, 3.4, { color = A.light })
			A:block(s * 34, 0, 2.6, 9.6, 0.4, { color = A.white }, 3.4)
			for _, zs in { -1, 1 } do
				A:pillar(s * 44, zs * 8, 5, 2.5)
			end
			-- arcades against the long walls (detail, and a little cover along the edges)
			for _, ax in { 30, 40 } do
				for _, zs in { -1, 1 } do
					A:arch(s * ax, zs * 45, 6, 9, 2, "z", { pier = 1.5 })
				end
			end
			-- (detail) flags on the gate towers, banners over the gate, torches either side of it
			for _, zs in { -1, 1 } do
				A:flag(wx, zs * 38, 22.4, s)
				A:lamp(wx - s * 4, zs * 7.5, 6, Color3.fromRGB(255, 236, 200))
			end
			A:block(wx - s * 2.1, 0, 0.3, 8, 3, { color = A:teamColor(s), solid = false, collide = false }, 13.8)
			-- a cobbled path through the gate: flat tiles in two shades
			for i = 0, 7 do
				A:block(wx - s * (8 + i * 3), 0, 2.6, 7, 0.1, {
					color = (i % 2 == 0) and A.light or A.grey,
					solid = false,
					collide = false,
				})
			end
			-- crates and barrels by the rampart stairs (low cover on your own side)
			A:crates(wx + s * 6, 26, 3, 15)
			A:crates(wx + s * 6, -26, 2, -20)
			-- wall-walk crenels on the rampart's back edge and rubble at the tower feet
			for _, zs in { -1, 1 } do
				A:rubble(wx - s * 7, zs * 30, 5, 11 + zs)
				A:block(s * 20, zs * 24, 30, 0.3, 0.6, { color = A.grey, solid = false, collide = false }, 13)
			end
			-- planters along the colonnade: low boxes with a tuft of pale leaves
			for k = 0, 2 do
				local px = s * (12 + k * 8)
				for _, zs in { -1, 1 } do
					A:block(px, zs * 30, 2.4, 2.4, 1.6, { color = A.light })
					A:block(px, zs * 30, 1.8, 1.8, 0.8, {
						color = Color3.fromRGB(214, 222, 206),
						solid = false,
						collide = false,
					}, 1.6)
				end
			end
		end)
		-- the fountain in the middle: stacked plinths and an obelisk
		A:block(0, 0, 12, 12, 1, { color = A.light })
		A:block(0, 0, 9, 9, 2.2, { color = A.white }, 1)
		A:block(0, 0, 3, 3, 9, { color = A.white }, 3.2)
		A:block(0, 0, 3.6, 3.6, 0.6, { color = A.light }, 12.2)
		A:wedge(CFrame.new(0, 13.6, 0), Vector3.new(3, 2.2, 1.5), { color = A.white })
		A:wedge(
			CFrame.new(0, 13.6, 0) * CFrame.Angles(0, math.rad(180), 0),
			Vector3.new(3, 2.2, 1.5),
			{ color = A.white }
		)
		-- the fountain's water: a pale glassy pool, and four lamps round the square
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
