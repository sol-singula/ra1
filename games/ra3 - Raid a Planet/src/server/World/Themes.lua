-- What each planet looks like: its scenery (built from plain parts in the brick style) and the extra bits on its
-- bugs and boss. One function per planet, called by WorldBuilder for the island and by MobBuilder for the mobs.
local Scenery = require(script.Parent.Scenery)

local part, disc, ball, rgb = Scenery.part, Scenery.disc, Scenery.ball, Scenery.rgb

local Themes = {}

local function box(parent, name, size, cf, color, material, extra)
	local props = {
		Name = name,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Parent = parent,
	}
	for k, v in extra or {} do
		props[k] = v
	end
	return part(props)
end

-- A tree: a trunk and leaf balls.
local function tree(parent, pos, scale, leaf, trunk, rng)
	box(
		parent,
		"Trunk",
		Vector3.new(1.2, 5, 1.2) * scale,
		CFrame.new(pos + Vector3.new(0, 2.5 * scale, 0)),
		trunk,
		Enum.Material.Wood
	)
	for i = 1, 3 do
		local a = i * 2.1 + rng:NextNumber(0, 1)
		ball(
			parent,
			"Leaves",
			pos + Vector3.new(math.cos(a) * 1.3, 5.5 + i * 0.6, math.sin(a) * 1.3) * scale,
			3.6 * scale,
			leaf:Lerp(rgb(255, 255, 255), i * 0.06),
			Enum.Material.Plastic,
			{ CanCollide = false, CastShadow = false }
		)
	end
end

-- A glowing pool on the floor.
local function pool(parent, pos, size, color)
	disc(
		parent,
		"Pool",
		pos + Vector3.new(0, 0.12, 0),
		size,
		0.25,
		color,
		Enum.Material.Neon,
		{ CanCollide = false, CastShadow = false }
	)
	disc(
		parent,
		"PoolRim",
		pos + Vector3.new(0, 0.06, 0),
		size + 2,
		0.15,
		rgb(40, 35, 45),
		Enum.Material.Plastic,
		{ CanCollide = false, CastShadow = false }
	)
end

-- A tall spire: stacked narrowing boxes.
local function spire(parent, pos, height, color, rng)
	local y = 0
	local w = height * 0.3
	for i = 1, 4 do
		local h = height / 4
		box(
			parent,
			"Spire",
			Vector3.new(w, h, w),
			CFrame.new(pos + Vector3.new(0, y + h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
			color:Lerp(rgb(0, 0, 0), i * 0.06),
			Enum.Material.Slate
		)
		y += h
		w *= 0.72
	end
end

Themes.scenery = {
	DUST = function(parent, p, planet, rng)
		if rng:NextNumber() < 0.5 then
			Scenery.rock(parent, p, rng:NextNumber(3, 7), planet.dark, rng)
		else
			-- a crater
			disc(
				parent,
				"Crater",
				p + Vector3.new(0, 0.05, 0),
				rng:NextNumber(6, 12),
				0.2,
				planet.dark:Lerp(rgb(0, 0, 0), 0.2),
				Enum.Material.Plastic,
				{ CanCollide = false }
			)
		end
		if rng:NextNumber() < 0.3 then
			spire(parent, p + Vector3.new(4, 0, 2), rng:NextNumber(6, 10), planet.dark, rng)
		end
	end,
	ICE = function(parent, p, _planet, rng)
		if rng:NextNumber() < 0.6 then
			Scenery.crystal(parent, p, rng:NextNumber(5, 11), rgb(200, 240, 255), rng)
			Scenery.crystal(parent, p + Vector3.new(2, 0, 1), rng:NextNumber(3, 6), rgb(160, 225, 255), rng)
		else
			ball(
				parent,
				"Snow",
				p + Vector3.new(0, 0.5, 0),
				rng:NextNumber(5, 9),
				rgb(245, 250, 255),
				Enum.Material.Plastic,
				{ CastShadow = false }
			)
		end
	end,
	LAVA = function(parent, p, _planet, rng)
		if rng:NextNumber() < 0.5 then
			pool(parent, p, rng:NextNumber(7, 13), rgb(255, 120, 30))
		else
			Scenery.rock(parent, p, rng:NextNumber(4, 7), rgb(40, 30, 30), rng)
			local f = box(
				parent,
				"Vent",
				Vector3.new(1.5, 2, 1.5),
				CFrame.new(p + Vector3.new(0, 3.5, 0)),
				rgb(60, 40, 40),
				Enum.Material.Slate
			)
			local fire = Instance.new("Fire")
			fire.Size = 4
			fire.Heat = 6
			fire.Parent = f
		end
	end,
	JUNGLE = function(parent, p, _planet, rng)
		if rng:NextNumber() < 0.7 then
			tree(parent, p, rng:NextNumber(1, 1.8), rgb(70, 190, 80), rgb(110, 75, 50), rng)
		else
			for i = 1, 3 do
				ball(
					parent,
					"Bush",
					p + Vector3.new(i * 1.6 - 3, 1, 0),
					rng:NextNumber(2.5, 4),
					rgb(60, 160, 70),
					Enum.Material.Plastic,
					{ CastShadow = false }
				)
			end
		end
	end,
	CRYSTAL = function(parent, p, _planet, rng)
		for i = 1, 3 do
			Scenery.crystal(
				parent,
				p + Vector3.new(i * 1.5 - 3, 0, rng:NextNumber(-1, 1)),
				rng:NextNumber(5, 14),
				i % 2 == 0 and rgb(230, 130, 255) or rgb(160, 200, 255),
				rng
			)
		end
	end,
	STORM = function(parent, p, _planet, rng)
		spire(parent, p, rng:NextNumber(8, 16), rgb(90, 95, 130), rng)
		local tip = ball(
			parent,
			"Spark",
			p + Vector3.new(0, rng:NextNumber(8, 16) + 1, 0),
			1.4,
			rgb(255, 245, 140),
			Enum.Material.Neon,
			{ CanCollide = false }
		)
		local light = Instance.new("PointLight")
		light.Color = rgb(200, 210, 255)
		light.Range = 14
		light.Parent = tip
	end,
	SHADOW = function(parent, p, _planet, rng)
		box(
			parent,
			"Obelisk",
			Vector3.new(2.5, rng:NextNumber(8, 14), 2.5),
			CFrame.new(p + Vector3.new(0, 5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0),
			rgb(30, 20, 50),
			Enum.Material.Slate
		)
		box(
			parent,
			"Rune",
			Vector3.new(0.4, 2, 0.4),
			CFrame.new(p + Vector3.new(0, 7, -1.3)),
			rgb(190, 120, 255),
			Enum.Material.Neon,
			{ CanCollide = false }
		)
		local fog = ball(
			parent,
			"Fog",
			p + Vector3.new(3, 1, 2),
			rng:NextNumber(5, 9),
			rgb(90, 60, 130),
			Enum.Material.SmoothPlastic,
			{ Transparency = 0.6, CanCollide = false, CastShadow = false }
		)
		_ = fog
	end,
	SUN = function(parent, p, _planet, rng)
		if rng:NextNumber() < 0.5 then
			pool(parent, p, rng:NextNumber(6, 10), rgb(255, 240, 120))
		else
			local pillar = box(
				parent,
				"FlamePillar",
				Vector3.new(2, rng:NextNumber(5, 9), 2),
				CFrame.new(p + Vector3.new(0, 3.5, 0)),
				rgb(220, 150, 20),
				Enum.Material.Slate
			)
			local fire = Instance.new("Fire")
			fire.Size = 5
			fire.Heat = 10
			fire.Color = rgb(255, 230, 90)
			fire.Parent = pillar
		end
	end,
}

-- Extra bits on a mob (built after the body): called with (model, s, planet, isBoss, boxFn)
Themes.mob = {
	DUST = function(model, s, planet, _, mbox)
		-- a dusty hump and little horns
		mbox(model, "Hump", Vector3.new(1.4, 0.6, 1.4) * s, CFrame.new(0, 2.2 * s, 0.4 * s), planet.dark)
	end,
	ICE = function(model, s, _planet, _, mbox)
		for i = -1, 1 do
			mbox(
				model,
				"IceSpike",
				Vector3.new(0.3, 1.2, 0.3) * s,
				CFrame.new(i * 0.6 * s, 2.5 * s, (0.2 - i * 0.3) * s),
				rgb(220, 245, 255),
				Enum.Material.Neon
			)
		end
	end,
	LAVA = function(model, s, _planet, _, mbox)
		local p = mbox(
			model,
			"Ember",
			Vector3.new(0.8, 0.5, 0.8) * s,
			CFrame.new(0, 2.3 * s, 0.3 * s),
			rgb(255, 150, 40),
			Enum.Material.Neon
		)
		local fire = Instance.new("Fire")
		fire.Size = 2.5 * s
		fire.Heat = 4
		fire.Parent = p
	end,
	JUNGLE = function(model, s, _planet, _, mbox)
		for _, side in { -1, 1 } do
			mbox(
				model,
				"Leaf",
				Vector3.new(1.2, 0.1, 2) * s,
				CFrame.new(side * 1.1 * s, 2.25 * s, 0.4 * s) * CFrame.Angles(0, side * 0.3, side * -0.4),
				rgb(50, 150, 60)
			)
		end
	end,
	CRYSTAL = function(model, s, _planet, _, mbox)
		for i = 1, 3 do
			mbox(
				model,
				"Gem",
				Vector3.new(0.4, 1, 0.4) * s,
				CFrame.new((i - 2) * 0.6 * s, 2.5 * s, 0.3 * s) * CFrame.Angles(0.2, i, 0),
				rgb(240, 160, 255),
				Enum.Material.Neon
			)
		end
	end,
	STORM = function(model, s, _planet, _, mbox)
		local tip = mbox(
			model,
			"Bolt",
			Vector3.new(0.3, 0.3, 0.3) * s,
			CFrame.new(0, 3.2 * s, -1.9 * s),
			rgb(255, 245, 140),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Color = rgb(200, 210, 255)
		light.Range = 8 * s
		light.Parent = tip
	end,
	SHADOW = function(model, s, _planet, _, mbox)
		for _, side in { -1, 1 } do
			mbox(
				model,
				"BatWing",
				Vector3.new(1.8, 0.08, 1.4) * s,
				CFrame.new(side * 1.2 * s, 2.3 * s, 0.3 * s) * CFrame.Angles(0, 0, side * -0.5),
				rgb(40, 25, 60)
			)
		end
	end,
	SUN = function(model, s, _planet, _, mbox)
		local p = mbox(
			model,
			"Halo",
			Vector3.new(1.6, 0.15, 1.6) * s,
			CFrame.new(0, 3 * s, -1.6 * s),
			rgb(255, 240, 120),
			Enum.Material.Neon
		)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 230, 120)
		light.Range = 10 * s
		light.Parent = p
	end,
}

-- Eye colours per planet (bosses get red pupils)
Themes.eyes = {
	DUST = rgb(255, 255, 255),
	ICE = rgb(200, 240, 255),
	LAVA = rgb(255, 220, 120),
	JUNGLE = rgb(220, 255, 200),
	CRYSTAL = rgb(255, 220, 255),
	STORM = rgb(255, 255, 200),
	SHADOW = rgb(200, 120, 255),
	SUN = rgb(255, 255, 220),
}

return Themes
