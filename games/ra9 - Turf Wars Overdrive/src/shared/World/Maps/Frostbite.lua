--[[
Frostbite: a glacier in white and the palest blue. Each half has a high ice terrace (a slab you climb by steps cut
into it: the long firing ledge), leaning ice walls that make protected routes, and shard clusters. In the middle, a
broken ridge of shards with three gaps. More protected routes and clear high ground; no slippery floors.
]]
return {
	key = "frost",
	name = "Frostbite",
	tagline = "A glacier of shards. Take the high terrace.",
	length = 200,
	width = 96,
	palette = {
		white = Color3.fromRGB(240, 245, 250),
		light = Color3.fromRGB(220, 231, 242),
		grey = Color3.fromRGB(186, 201, 217),
		dark = Color3.fromRGB(150, 168, 188),
	},
	lighting = { clock = 10.5, ambient = Color3.fromRGB(165, 175, 190), brightness = 3, haze = 1.6 },
	build = function(A)
		A:mirror(function(s)
			-- the terrace: a long slab 7 studs up, steps cut into its back, a lip along its front
			local tx = s * 50
			A:block(tx, 0, 12, 34, 7, { color = A.light })
			A:block(tx - s * 6.2, 0, 0.6, 34, 1.2, { color = A.white }, 7) -- the lip
			for i = 1, 6 do
				A:block(
					tx + s * (6 + (i - 0.5) * 1.3),
					0,
					1.3,
					8,
					7 - (i - 1) * 7 / 6,
					{ color = (i % 2 == 0) and A.white or A.light }
				)
			end
			-- shard crowns on the terrace's ends
			A:shard(tx, 19, 5, 14, 8, -6, { yaw = 15 })
			A:shard(tx, -19, 5, 14, -8, 6, { yaw = -20 })
			-- leaning ice walls: protected routes down each side
			for _, zs in { -1, 1 } do
				local cf = CFrame.new(s * 28, 5, zs * 30)
					* CFrame.Angles(0, 0, math.rad(s * 8))
					* CFrame.Angles(math.rad(zs * 6), 0, 0)
				A:box(cf, Vector3.new(2.5, 10, 18), { color = A.white })
				A:box(cf * CFrame.new(0, 5.4, 0), Vector3.new(3.2, 0.8, 18.6), { color = A.light })
				-- small shards at their feet
				A:shard(s * 32, zs * 20, 3, 6, 10, 10, { yaw = 40 })
			end
			-- shard clusters in the open (cover for the middle lanes)
			A:shard(s * 18, 12, 4, 9, 6, -10, { yaw = 30 })
			A:shard(s * 18, -12, 4, 9, -6, 10, { yaw = -30 })
			A:shard(s * 38, 0, 3.5, 7, 12, 4, { yaw = 70 })
			-- frozen blocks along the long walls
			for k = 0, 2 do
				A:block(s * (24 + k * 16), 44, 8, 6, 4 + k * 2, { color = (k % 2 == 0) and A.light or A.white })
				A:block(s * (24 + k * 16), -44, 8, 6, 4 + k * 2, { color = (k % 2 == 1) and A.light or A.white })
			end
		end)
		-- the ridge across the middle: four shard walls with three gaps between
		for _, zc in { -36, -14, 14, 36 } do
			-- (centred on the middle line and tilted only across it, so both sides see the same ridge)
			local cf = CFrame.new(0, 4.5, zc) * CFrame.Angles(math.rad((zc > 0) and 7 or -7), math.rad(45), 0)
			A:box(cf, Vector3.new(5, 10, 5), { color = A.white })
			A:box(
				CFrame.new(0, 10.2, zc) * CFrame.Angles(0, math.rad(45), 0),
				Vector3.new(3, 2, 3),
				{ color = A.light }
			)
			A:block(0, zc, 4, 9, 2, { color = A.light })
		end
	end,
}
