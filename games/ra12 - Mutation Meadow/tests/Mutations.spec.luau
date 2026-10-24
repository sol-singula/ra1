--[[
The mutation looks of Game Artist build-spec/02-mutations.md (GA-02): the caps on a full mutated plot, the template
look restored, the corn husks, the part budget, and gold kept off the Sell buttons and the Block Party meter.
]]
local Assert = require("./mock/Assert")
local Client = require("./mock/Client")
local Engine = require("./mock/Engine")
local roblox = require("@lune/roblox")

local test, eq = Assert.test, Assert.eq

local engine = Engine.new()
local Crop = engine:require(engine:module("Shared/Models/Crop"))
local Config = engine:require(engine:module("Shared/Config"))
local MV = Config.MutationVisuals

local SEEDS =
	{ "carrot", "strawberry", "blueberry", "tomato", "corn", "pumpkin", "watermelon", "dragonfruit", "moonmelon" }
local KEYS = { "wet", "golden", "wetgolden" }
local V3, CF, hex = roblox.Vector3, roblox.CFrame, roblox.Color3.fromHex

local function parts(model)
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			out[d.Name] = d
		end
	end
	return out
end

local function look(model)
	local out = {}
	for name, p in parts(model) do
		out[name] = { p.Color, p.Material, p.Reflectance, p.Transparency }
	end
	return out
end

local function emitting(crop)
	for _, d in crop:GetDescendants() do
		if d.ClassName == "ParticleEmitter" and (d.Name == "MutFx" or d.Name == "MutDrops") and d.Enabled then
			return true
		end
	end
	return false
end

local function lit(crop)
	for _, d in crop:GetDescendants() do
		if d.Name == "MutLight" and d.Enabled then
			return true
		end
	end
	return false
end

-- every tile of Plot1 ripe and mutated (the seeds and the keys in turn)
local function fullPlot(keys)
	local c = Client.boot()
	local now = c.engine.workspace:GetServerTimeNow()
	local tiles = c.plot.Tiles:GetChildren()
	for i, tile in tiles do
		local attrs = {
			Active = true,
			Seed = SEEDS[(i - 1) % #SEEDS + 1],
			Grown = 720,
			At = now,
			Rate = 1,
			GrowSec = 720,
			Ripe = true,
			Muts = keys[(i - 1) % #keys + 1],
		}
		for k, v in attrs do
			tile:SetAttribute(k, v)
		end
	end
	return c, tiles
end

local function crops(c)
	local out = {}
	for _, crop in c.engine.workspace.ClientCrops:GetChildren() do
		if crop:GetAttribute("Muts") then
			table.insert(out, crop)
		end
	end
	return out
end

local function centre(tiles)
	local sum = V3.zero
	for _, t in tiles do
		sum += t.Position
	end
	return sum / #tiles
end

test("a full mutated plot: at most 3 emitting (Wet+Golden counts 2), at most 8 MutLights, beads within 80", function()
	local c, tiles = fullPlot(KEYS)
	local camera = c.engine.workspace.CurrentCamera
	camera.CFrame = CF.new(centre(tiles) + V3.new(0, 20, -30))
	c.engine:advance(1.5)
	local list = crops(c)
	eq(#list, #tiles, "every tile has its crop")
	local weight, lights = 0, 0
	for _, crop in list do
		eq(emitting(crop), crop:GetAttribute("Emitting") == true, crop.Name)
		if emitting(crop) then
			weight += MV.caps.weights[crop:GetAttribute("Muts")]
		end
		if lit(crop) then
			lights += 1
			Assert.truthy(crop:GetAttribute("Muts") ~= "wet", "Wet has no light")
		end
		for _, d in crop:GetDescendants() do
			if string.sub(d.Name, 1, 7) == "MutBead" then
				Assert.truthy(d.Transparency < 1, d.Name .. " shown within 80 studs")
			end
		end
	end
	Assert.truthy(weight >= 1 and weight <= 3, `emitting weight {weight}`)
	eq(lights, 8)

	-- far away: nothing emits or glows
	camera.CFrame = CF.new(centre(tiles) + V3.new(0, 20, -200))
	c.engine:advance(1.5)
	for _, crop in crops(c) do
		eq({ emitting(crop), lit(crop) }, { false, false }, crop.Name .. " beyond 160 studs")
	end
	eq(c.engine.errors, {})
end)

test("Wet+Golden counts as 2: three of them on a plot leave just one emitting", function()
	local c, tiles = fullPlot({ "wetgolden" })
	c.engine.workspace.CurrentCamera.CFrame = CF.new(centre(tiles) + V3.new(0, 20, -30))
	c.engine:advance(1.5)
	local n = 0
	for _, crop in crops(c) do
		if emitting(crop) then
			n += 1
			eq(crop.Fx.MutFx.Rate, MV.glint.rateWetGolden)
			eq(crop:FindFirstChild("MutDrops", true).Enabled, true, "drip and glint together")
		end
	end
	eq(n, 1)
end)

test("between 80 and 160 studs: emitters and the light stay, the beads hide", function()
	local c, tiles = fullPlot({ "wetgolden" })
	local tile = tiles[1]
	c.engine.workspace.CurrentCamera.CFrame = CF.new(tile.Position + V3.new(0, 0, -100))
	c.engine:advance(1.5)
	local crop = c.engine.workspace.ClientCrops["Plot1_" .. tile.Name]
	Assert.truthy(not crop:GetAttribute("Far"), "100 studs is still the full build")
	eq(crop:GetAttribute("Beads"), false)
	local beads = 0
	for _, d in crop:GetDescendants() do
		if string.sub(d.Name, 1, 7) == "MutBead" then
			beads += 1
			eq(d.Transparency, 1, d.Name)
		end
	end
	Assert.truthy(beads > 0, "the beads are there, hidden")
	eq({ emitting(crop), lit(crop) }, { true, true }, "the nearest crop still glints and glows")
end)

test("every mutation, then none: the template look comes back and nothing added is left", function()
	for _, seed in SEEDS do
		for _, stage in { "sprout", "ripe" } do
			local m = Crop.build(nil, "T", seed, stage, CF.new(0, 0, 0))
			local before = look(m)
			for _, key in KEYS do
				Crop.applyMutation(m, key)
			end
			Crop.applyMutation(m, nil)
			eq(look(m), before, `{seed} {stage}`)
			for _, d in m:GetDescendants() do
				Assert.truthy(
					d.Name ~= "Fx" and d.Name ~= "GoldLight" and string.sub(d.Name, 1, 3) ~= "Mut",
					`{seed} {stage}: {d.Name} left behind`
				)
			end
			Crop.destroy(m)
		end
	end
end)

test("corn: Golden keeps the husks the template green; Wet+Golden makes them #71A824", function()
	local plain = Crop.build(nil, "T", "corn", "ripe", CF.new())
	local m = Crop.build(nil, "T", "corn", "ripe", CF.new(), "golden")
	eq(m.Fruit1.Color, hex("#FFC300"), "the kernels go gold")
	eq(m.FruitDetail1.Color, plain.FruitDetail1.Color, "the husks stay green")
	eq(m.FruitDetail1.Material, plain.FruitDetail1.Material)
	Crop.applyMutation(m, "wetgolden")
	eq(m.Fruit1.Color, hex("#D9A600"))
	eq({ m.FruitDetail1.Color, m.FruitDetail2.Color }, { hex("#71A824"), hex("#71A824") })
end)

-- section 5 budgets the visible extras (GoldLight + the beads); the invisible Fx emitter host is not one of them
test("a mutation adds at most 11 parts (GoldLight + beads) to any crop", function()
	for _, seed in SEEDS do
		for _, key in KEYS do
			local n = 0
			for name in parts(Crop.build(nil, "T", seed, "ripe", CF.new(), key)) do
				if name == "GoldLight" or string.sub(name, 1, 7) == "MutBead" then
					n += 1
				end
			end
			Assert.truthy(n <= MV.maxMutParts, `{seed} {key}: {n} parts added`)
		end
	end
end)

test("no gold in the UI kit: Sell is green with white text and a dark outline; the chips say x2/x20/x40", function()
	local c = Client.boot()
	local UI = c.engine:require(c.engine:module("Client/UI"))
	eq(UI.COLORS.gold, nil)
	eq(UI.COLORS.mutGold, hex("#FFC300"))
	local frame = c.engine.Instance.new("Frame")
	local b = UI.sellButton(frame, "Sell", function() end)
	eq({ b.BackgroundColor3, b.TextColor3, b.UIStroke.Color, b:GetAttribute("PressedColor") }, {
		hex("#4CAF50"),
		roblox.Color3.new(1, 1, 1),
		hex("#1E1B2E"),
		hex("#3D8C40"),
	})
	for key, text in { wet = "Wet x2", golden = "Golden x20", wetgolden = "Wet+Golden x40" } do
		local chip = UI.mutChip(frame, key)
		eq(chip.Text, text)
		eq(string.find(chip.Text, "×", 1, true), nil, "a plain x")
		eq(chip.BackgroundColor3, hex(MV.chips[key].fill))
		eq({ chip.UIStroke.Color, chip.UIStroke.Thickness }, { hex(MV.chips[key].stroke), 2 })
	end
end)

test("the Sell buttons in play are green, and the Block Party meter is flat #FFE066 on a dark track", function()
	local c = Client.boot()
	c.controllers.SellController.open()
	c.controllers.TileController.offerSell(c.plot, "1")
	local found = 0
	for _, gui in c.engine.game.Players.LocalPlayer.PlayerGui:GetChildren() do
		for _, d in gui:GetDescendants() do
			if d.ClassName == "TextButton" and string.sub(d.Name, 1, 4) == "Sell" then
				found += 1
				eq(d.BackgroundColor3, hex("#4CAF50"), d:GetFullName())
			end
		end
	end
	Assert.truthy(found >= 3, `{found} Sell buttons`)
	local bar = Client.find(c.gui("BlockParty"), "Bar")
	eq({ bar.BackgroundColor3, bar.BackgroundTransparency }, { hex("#1E1B2E"), 0.35 })
	eq(bar.Fill.BackgroundColor3, hex("#FFE066"))
	eq(bar.Fill:FindFirstChildOfClass("UIGradient"), nil, "flat")
end)
