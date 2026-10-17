--[[
Frostbite: a glacier in white and the palest blue. Each half has a high ice terrace (a slab you climb by steps cut
into its back, with a second, higher shelf on top: the long firing ledges), leaning ice walls that make protected
routes, crystal monoliths, and towering ice spires against the long walls behind a frozen colonnade. In the middle, a
broken ridge of shards with three gaps under a great arch of ice, and a pillar of light. More protected routes and
clear high ground; no slippery floors.

Drawn for the small arena; A:fx / A:fz stretch it for a bigger one, and the colonnades and spires grow in number.
]]
return {
	key = "frost",
	name = "Frostbite",
	tagline = "A glacier of shards. Take the high terrace.",
	length = 200,
	width = 96,
	wallHeight = 38,
	palette = {
		white = Color3.fromRGB(240, 245, 250),
		light = Color3.fromRGB(220, 231, 242),
		grey = Color3.fromRGB(186, 201, 217),
		dark = Color3.fromRGB(150, 168, 188),
	},
	lighting = { clock = 10.5, ambient = Color3.fromRGB(165, 175, 190), brightness = 3, haze = 1.6 },
	-- distant ice: leaning spires and flat-topped glaciers
	skyline = function(A, x, z, w, d, h, r, i)
		local c = (i % 2 == 0) and A.white or A.light
		local o = { color = c, collide = false, solid = false, shadow = false }
		if i % 3 == 0 then
			A:box(Vector3.new(x, h * 0.2 - 2, z), Vector3.new(w * 1.8, h * 0.4, d * 1.4), o)
		else
			A:box(
				CFrame.new(x, h / 2 - 4, z)
					* CFrame.Angles(r:NextNumber(-0.12, 0.12), r:NextNumber(0, 3), r:NextNumber(-0.12, 0.12)),
				Vector3.new(w * 0.6, h * 1.1, d * 0.5),
				o
			)
			A:box(
				CFrame.new(x + w * 0.3, h * 0.3, z) * CFrame.Angles(0.15, r:NextNumber(0, 3), -0.2),
				Vector3.new(w * 0.35, h * 0.6, d * 0.35),
				{ color = A.grey, collide = false, solid = false, shadow = false }
			)
		end
		return true
	end,
	build = function(A)
		local W = A.W
		local glow = Color3.fromRGB(200, 228, 255)
		local function deco(c, extra)
			local o = { color = c, solid = false, collide = false }
			for k, v in extra or {} do
				o[k] = v
			end
			return o
		end
		A:mirror(function(s)
			-- the terrace: a long slab 7 studs up, steps cut into its back, a lip along its front; on top, at the back, a
			-- higher shelf (11 up) reached by its own steps
			local tx = s * A:fx(50)
			local tl = A:fz(34)
			A:block(tx, 0, 12, tl, 7, { color = A.light })
			A:block(tx - s * 6.2, 0, 0.6, tl, 1.2, { color = A.white }, 7) -- the lip
			for i = 1, 7 do
				A:block(
					tx + s * (6 + (i - 0.5) * 1.3),
					0,
					1.3,
					8,
					7 - (i - 1),
					{ color = (i % 2 == 0) and A.white or A.light }
				)
			end
			for _, zs in { -1, 1 } do
				local sz = zs * (tl / 2 - 5)
				A:block(tx + s * 3, sz, 6, 8, 4, { color = A.white }, 7)
				A:block(tx + s * 0.2, sz, 0.5, 8, 1, { color = A.light }, 11)
				A:stairs(tx + s * 3, sz - zs * 8, zs > 0 and "+z" or "-z", 4, 1, 1.3, 4, { y0 = 7 })
				-- icicles under its lip
				for k = -3, 3 do
					A:wedge(
						CFrame.new(tx - s * 0.1, 11 - 0.6, sz + k * 1.1) * CFrame.Angles(math.rad(180), 0, 0),
						Vector3.new(0.4, 1.2 + (k % 2) * 0.6, 0.5),
						deco(A.white)
					)
				end
			end
			-- shard crowns on the terrace's ends: tall crystals
			A:shard(tx, tl / 2 + 2, 5, 22, 8, -6, { yaw = 15 })
			A:shard(tx, -tl / 2 - 2, 5, 22, -8, 6, { yaw = -20 })
			-- leaning ice walls: protected routes down each side
			for _, zs in { -1, 1 } do
				local cf = CFrame.new(s * A:fx(28), 6, zs * A:fz(30))
					* CFrame.Angles(0, 0, math.rad(s * 8))
					* CFrame.Angles(math.rad(zs * 6), 0, 0)
				A:box(cf, Vector3.new(2.5, 12, 18), { color = A.white })
				A:box(cf * CFrame.new(0, 6.4, 0), Vector3.new(3.2, 0.8, 18.6), { color = A.light })
				A:shard(s * A:fx(32), zs * A:fz(20), 3, 7, 10, 10, { yaw = 40 })
			end
			-- shard clusters in the open (cover for the middle lanes)
			A:shard(s * A:fx(18), A:fz(12), 4, 10, 6, -10, { yaw = 30 })
			A:shard(s * A:fx(18), -A:fz(12), 4, 10, -6, 10, { yaw = -30 })
			-- (a bigger arena) more shard clusters out toward the walls
			if A.tier ~= "small" then
				A:shard(s * A:fx(10), A:fz(27), 4, 11, 8, -6, { yaw = 60 })
				A:shard(s * A:fx(10), -A:fz(27), 4, 11, -8, 6, { yaw = -60 })
				A:shard(s * A:fx(58), 0, 3.5, 8, 10, 6, { yaw = 15 })
			end
			-- crystal monoliths: a tall faceted stone with a glowing core, on a plinth
			for _, zs in { -1, 1 } do
				local mx, mz = s * A:fx(40), zs * A:fz(7)
				A:block(mx, mz, 4.4, 4.4, 1, { color = A.light })
				A:box(
					CFrame.new(mx, 7, mz) * CFrame.Angles(0, math.rad(45), 0),
					Vector3.new(2.6, 12, 2.6),
					{ color = A.white }
				)
				A:box(
					CFrame.new(mx, 7, mz) * CFrame.Angles(0, math.rad(45), 0),
					Vector3.new(2.7, 6, 1.2),
					deco(glow, { material = Enum.Material.Neon, transparency = 0.2 })
				)
				A:wedge(
					CFrame.new(mx, 14, mz) * CFrame.Angles(0, math.rad(45), 0),
					Vector3.new(2.6, 2, 2.6),
					{ color = A.light }
				)
			end
			-- the frozen colonnade along the long walls: ice pillars under a slab of ice, a sheltered walk
			local p0, p1 = s * A:fx(14), s * A:fx(70)
			local n = math.floor(math.abs(p1 - p0) / 12) + 1
			for _, zs in { -1, 1 } do
				local z = zs * (W - 5)
				for k = 0, n - 1 do
					local px = p0 + (p1 - p0) * k / (n - 1)
					A:pillar(px, z, 14, 2, { color = A.white })
					for j = -1, 1 do
						A:wedge(
							CFrame.new(px + j * 0.7, 12.4, z) * CFrame.Angles(math.rad(180), 0, 0),
							Vector3.new(0.4, 1.6 - math.abs(j) * 0.5, 0.5),
							deco(A.white)
						)
					end
				end
				A:block((p0 + p1) / 2, z, math.abs(p1 - p0) + 4, 5, 1.4, { color = A.light }, 14)
				A:block((p0 + p1) / 2, z - zs * 0.3, math.abs(p1 - p0) + 5, 5.8, 0.4, deco(A.white), 15.4)
			end
			-- towering ice spires against the long walls, between the colonnade and the wall
			for k, fx in { 24, 48, 66 } do
				for _, zs in { -1, 1 } do
					local h = 24 + (k % 2) * 10
					local sx, sz = s * A:fx(fx), zs * (W - 2.2)
					A:box(
						CFrame.new(sx, h / 2 - 1, sz) * CFrame.Angles(math.rad(zs * -5), math.rad(s * 20 + k * 30), 0),
						Vector3.new(3.4, h, 2.6),
						deco(A.white, { shadow = true })
					)
					A:box(
						CFrame.new(sx + s * 1.6, h * 0.32, sz)
							* CFrame.Angles(math.rad(zs * -12), math.rad(k * 50), math.rad(s * 10)),
						Vector3.new(2, h * 0.55, 1.6),
						deco(A.light, { shadow = true })
					)
				end
			end
			-- (detail) icicles under the terrace lip, crystal lamps, snow drifts along the walls
			for k = -7, 7 do
				local len = 1.2 + (k % 3) * 0.7
				A:wedge(
					CFrame.new(tx - s * 6.4, 7 - len / 2, k * tl / 15.5) * CFrame.Angles(math.rad(180), 0, 0),
					Vector3.new(0.5, len, 0.6),
					deco(A.white)
				)
			end
			for _, zs in { -1, 1 } do
				A:lamp(s * A:fx(60), zs * A:fz(12), 6, glow)
				for k = 0, 3 do
					A:wedge(
						CFrame.new(s * A:fx(16 + k * 14), 1, zs * (W - 1.5))
							* CFrame.Angles(0, zs > 0 and 0 or math.rad(180), 0),
						Vector3.new(10, 2, 3),
						deco(A.white)
					)
				end
				A:crates(tx + s * 2, zs * (tl / 2 + 6), 2, zs * 25)
				A:shard(s * A:fx(64), zs * A:fz(30), 2.5, 6, 14, -8, { yaw = zs * 50 })
			end
			-- cracks in the ice floor: thin pale lines
			for k = 0, 4 do
				A:box(
					CFrame.new(s * A:fx(14 + k * 9), 0.06, (k % 2 == 0 and 1 or -1) * A:fz(6 + k * 3))
						* CFrame.Angles(0, math.rad(k * 37), 0),
					Vector3.new(0.25, 0.1, 6 + k),
					deco(A.grey)
				)
			end
			A:rubble(s * A:fx(24), 0, 6, 30 + s)
		end)
		-- the ridge across the middle: four shard walls with three gaps between
		local ridge = { -A:fz(36), -A:fz(14), A:fz(14), A:fz(36) }
		for _, zc in ridge do
			-- (centred on the middle line and tilted only across it, so both sides see the same ridge)
			local cf = CFrame.new(0, 5, zc) * CFrame.Angles(math.rad((zc > 0) and 7 or -7), math.rad(45), 0)
			A:box(cf, Vector3.new(5, 11, 5), { color = A.white })
			A:box(
				CFrame.new(0, 11.2, zc) * CFrame.Angles(0, math.rad(45), 0),
				Vector3.new(3, 2, 3),
				{ color = A.light }
			)
			A:block(0, zc, 4, 9, 2, { color = A.light })
		end
		-- the great arch of ice over the ridge, from its outer walls: a curve of blocks, high over everyone
		local R = A:fz(36)
		local segs = 9
		for i = 0, segs - 1 do
			local a0, a1 = math.pi * i / segs, math.pi * (i + 1) / segs
			local p0 = Vector3.new(0, 10 + math.sin(a0) * 22, -math.cos(a0) * R)
			local p1 = Vector3.new(0, 10 + math.sin(a1) * 22, -math.cos(a1) * R)
			local mid = (p0 + p1) / 2
			A:box(
				CFrame.lookAt(mid, p1),
				Vector3.new(3, 2.4, (p1 - p0).Magnitude + 0.6),
				{ color = (i % 2 == 0) and A.white or A.light }
			)
			A:box(
				CFrame.lookAt(mid - Vector3.new(0, 1.4, 0), p1 - Vector3.new(0, 1.4, 0)),
				Vector3.new(2, 0.6, (p1 - p0).Magnitude),
				deco(A.grey)
			)
		end
		-- a frozen pillar of light in the ridge's middle gap
		A:block(0, 0, 1.2, 1.2, 0.4, deco(A.light))
		A:block(0, 0, 0.6, 0.6, 26, {
			color = Color3.fromRGB(215, 235, 255),
			material = Enum.Material.Neon,
			transparency = 0.4,
			solid = false,
			collide = false,
		}, 0.4)
	end,
}
