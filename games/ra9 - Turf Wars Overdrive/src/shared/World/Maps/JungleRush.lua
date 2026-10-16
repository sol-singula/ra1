--[[
Jungle Rush: overgrown ruins, all in matte off-white with pale sage "leaves" (flat geometric slabs, never textures).
Each half has a stepped temple (three tiers you climb), broken walls that cut the field into narrow routes, and a
grove of square pillars with leaf canopies. In the middle, a ruined gate with two side passages. More cover,
narrower routes, flanks. Leaves sit high, so nobody hides in them at head height.
]]
return {
	key = "jungle",
	name = "Jungle Rush",
	tagline = "Overgrown ruins. Flank through the grove.",
	length = 200,
	width = 96,
	palette = {
		white = Color3.fromRGB(242, 243, 238),
		light = Color3.fromRGB(226, 230, 220),
		grey = Color3.fromRGB(196, 204, 190),
		dark = Color3.fromRGB(150, 162, 145),
	},
	lighting = { clock = 15.5, ambient = Color3.fromRGB(165, 172, 160), brightness = 2.4, haze = 1.4 },
	build = function(A)
		local leaf = Color3.fromRGB(206, 220, 196)
		local leafDark = Color3.fromRGB(186, 204, 176)
		local function canopy(x, z, y, size)
			-- three flat slabs at different angles: a geometric tuft of leaves
			for i = 0, 2 do
				local cf = CFrame.new(x, y + i * 0.6, z)
					* CFrame.Angles(math.rad((i - 1) * 9), math.rad(i * 40), math.rad((1 - i) * 7))
				A:box(
					cf,
					Vector3.new(size - i, 0.5, size * 0.7 - i * 0.5),
					{ color = (i == 1) and leafDark or leaf, solid = false, collide = false }
				)
			end
		end
		A:mirror(function(s)
			-- the temple: three tiers, steps on its front and back, a little shrine on top
			local tx, tz = s * 52, 28
			for _, zs in { -1, 1 } do
				local z = zs * tz
				A:block(tx, z, 16, 14, 3, { color = A.light })
				A:block(tx, z, 11, 10, 3, { color = A.white }, 3)
				A:block(tx, z, 6, 6, 3, { color = A.light }, 6)
				A:block(tx, z, 3, 3, 4, { color = A.white }, 9)
				A:block(tx, z, 4, 4, 0.6, { color = A.light }, 13)
				canopy(tx + 2, z - 2, 14.5, 7)
				-- steps up the front (toward the middle)
				for i = 1, 3 do
					A:block(tx - s * (8 + 0.75) + s * (i - 1) * 2.5, z, 1.5, 4, i * 3 - 1.5, { color = A.white })
				end
			end
			-- broken walls: narrow routes through the middle third
			A:block(s * 30, 0, 2, 12, 8, { color = A.white })
			A:block(s * 30, 0, 2.4, 12.4, 0.6, { color = A.light }, 8)
			for _, zs in { -1, 1 } do
				A:block(s * 22, zs * 16, 10, 2, 6 - 2, { color = A.light })
				A:block(s * 22 + s * 3, zs * 16, 4, 2, 2.5, { color = A.white }, 4)
			end
			-- the grove: square pillars with leaf canopies, flanking routes along the walls
			for k = 0, 3 do
				for _, zs in { -1, 1 } do
					local px, pz = s * (14 + k * 9), zs * (40 - (k % 2) * 3)
					A:pillar(px, pz, 12 + (k % 2) * 2, 2)
					canopy(px, pz, 13.5 + (k % 2) * 2, 6)
				end
			end
			-- fallen blocks: low cover
			A:box(
				CFrame.new(s * 40, 1.2, -6) * CFrame.Angles(0, math.rad(s * 20), math.rad(8)),
				Vector3.new(6, 2.4, 3),
				{ color = A.light }
			)
			A:box(
				CFrame.new(s * 40, 1.2, 8) * CFrame.Angles(0, math.rad(-s * 35), math.rad(-6)),
				Vector3.new(5, 2.4, 3),
				{ color = A.white }
			)
		end)
		-- the ruined gate in the middle, with two passages beside it
		A:arch(0, 0, 8, 10, 3, "x", { pier = 3 })
		canopy(0, 0, 14, 9)
		for _, zs in { -1, 1 } do
			A:block(0, zs * 20, 3, 14, 7, { color = A.white })
			A:block(0, zs * 20, 3.6, 14.6, 0.6, { color = A.light }, 7)
		end
	end,
}
