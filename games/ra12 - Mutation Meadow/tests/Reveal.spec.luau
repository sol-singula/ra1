--[[
The mutation reveal of Game Artist build-spec/04-reveal.md (RevealController): each key's timeline against the
section 3 summary table, the one Sound from Config.Art, the quiet reducedFx / sfx-off path, no stacking on a tile,
the nearest-two cap, the 60-stud range and the Mutation remote.
]]
local Assert = require("./mock/Assert")
local Client = require("./mock/Client")
local roblox = require("@lune/roblox")

local test, eq = Assert.test, Assert.eq

local V3, CF, hex = roblox.Vector3, roblox.CFrame, roblox.Color3.fromHex

local function client()
	local c = Client.boot()
	local function mod(path)
		return c.engine:require(c.engine:module(path))
	end
	c.Crop, c.Config, c.Visuals = mod("Shared/Models/Crop"), mod("Shared/Config"), mod("Shared/Visuals")
	c.Reveal = c.controllers.RevealController
	c.engine.workspace.CurrentCamera.FieldOfView = 70
	return c
end

local function crop(c, name, seed, at)
	return c.Crop.build(c.engine.workspace, name or "T", seed or "pumpkin", "ripe", CF.new(at or V3.zero))
end

-- the reveal's own instances on a crop, by name
local function temps(model)
	local out = {}
	for _, d in model:GetDescendants() do
		if string.sub(d.Name, 1, 6) == "Reveal" then
			out[d.Name] = (out[d.Name] or 0) + 1
		end
	end
	return out
end

local function sounds(model)
	local n = 0
	for _, d in model:GetDescendants() do
		if d.ClassName == "Sound" then
			n += 1
		end
	end
	return n
end

test(
	"Golden: soil 14, gold Highlight, punch, chime; stars 12 at 0.05; the shine bar from 0.15; fade 0.8; clean at 1.5",
	function()
		local c = client()
		local m = crop(c)
		local seq = c.Reveal.play(m, "golden", { force = true })
		Assert.truthy(seq, "plays")
		eq(m:GetAttribute("Muts"), "golden", "the look first")
		eq(m.Fruit1.Color, c.Visuals.GOLD)
		local h = m.RevealHighlight
		eq(
			{ h.FillColor, h.OutlineColor, h.FillTransparency, h.OutlineTransparency },
			{ hex("#FFC300"), hex("#FFF1A8"), 0.55, 0.15 }
		)
		eq(h.Adornee, m)
		eq(m.Root.RevealSoilAt.RevealSoil:GetAttribute("Emitted"), 14)
		local sound = c.Crop.fxHost(m).RevealSound
		eq({ sound.SoundId, sound.Volume, sound.RollOffMaxDistance, sound:GetAttribute("Plays") }, {
			c.Config.Art.revealSounds.golden,
			0.6,
			40,
			1,
		})
		eq(sounds(m), 1, "exactly one sound")
		eq(c.engine.workspace.CurrentCamera.FieldOfView, 66, "the FOV punch")
		eq(c.Crop.fxHost(m):FindFirstChild("RevealStars"), nil, "the burst waits for 0.05")
		c.engine:advance(0.1)
		eq(c.Crop.fxHost(m).RevealStars:GetAttribute("Emitted"), 12)
		eq(c.Crop.fxHost(m):FindFirstChild("RevealDroplets"), nil)
		c.engine:advance(0.1)
		local bar = m:FindFirstChild("RevealShine", true)
		Assert.truthy(bar, "the shine bar")
		eq({ bar.Color, bar.Material, bar.CastShadow }, { hex("#FFF1A8"), c.engine.Enum.Material.SmoothPlastic, false })
		Assert.truthy(bar.Parent:GetAttribute("Role") == "fruit", "on the largest fruit")
		eq(bar.Parent, m.Fruit1)
		local y0 = bar.Position.Y
		eq(temps(m).RevealRing, nil, "no ring on plain Golden")
		c.engine:advance(0.2)
		Assert.truthy(bar.Position.Y > y0, "it sweeps up")
		Assert.near(c.engine.workspace.CurrentCamera.FieldOfView, 70, 1e-6, "the punch is back in 0.3 s")
		c.engine:advance(0.5) -- t 0.9
		Assert.truthy(h.FillTransparency > 0.55 and h.OutlineTransparency > 0.15, "fading from 0.8")
		c.engine:advance(0.7) -- t 1.6
		eq(temps(m), {}, "the Highlight, bar, burst, puff and Sound are gone")
		eq(c.Crop.fxHost(m).MutFx:GetAttribute("Key"), "golden", "the idle glint keeps running")
		eq(#c.Reveal.active(), 0)
		eq(c.engine.errors, {})
	end
)

test("Wet: blue Highlight, drip cue, droplets 16, the Glass splash ring at 0.10; no shine", function()
	local c = client()
	local m = crop(c)
	c.Reveal.play(m, "wet", { force = true })
	eq({ m.RevealHighlight.FillColor, m.RevealHighlight.OutlineColor }, { hex("#50AAFF"), hex("#DFF4FF") })
	eq(m:FindFirstChild("RevealSound", true).SoundId, c.Config.Art.revealSounds.wet)
	c.engine:advance(0.12)
	eq(m:FindFirstChild("RevealDroplets", true):GetAttribute("Emitted"), 16)
	local ring = m.RevealRing
	eq(
		{ ring.Color, ring.Material, ring.Shape },
		{ hex("#8FD3FF"), c.engine.Enum.Material.Glass, c.engine.Enum.PartType.Cylinder }
	)
	Assert.near(ring.Reflectance, 0.2, 1e-6)
	local d0 = ring.Size.Y
	c.engine:advance(0.2)
	Assert.truthy(ring.Size.Y > d0 and ring.Transparency > 0.3, "the ring grows and fades")
	eq(m:FindFirstChild("RevealShine", true), nil, "no shine on Wet")
	c.engine:advance(0.4)
	eq(m:FindFirstChild("RevealRing"), nil, "gone after 0.45 s")
	c.engine:advance(1)
	eq(temps(m), {})
end)

test(
	"Wet+Golden: soil 10 + droplets 10 + stars 8 (<= 30), gold fill with the #8FD3FF outline, ring + bar, one cue",
	function()
		local c = client()
		local m = crop(c)
		c.Reveal.play(m, "wetgolden", { force = true })
		eq({ m.RevealHighlight.FillColor, m.RevealHighlight.OutlineColor }, { hex("#FFC300"), hex("#8FD3FF") })
		eq(m:FindFirstChild("RevealSound", true).SoundId, c.Config.Art.revealSounds.wetgolden)
		eq(sounds(m), 1, "never burst + key")
		c.engine:advance(0.2)
		local soil = m.Root.RevealSoilAt.RevealSoil:GetAttribute("Emitted")
		local drops = m:FindFirstChild("RevealDroplets", true):GetAttribute("Emitted")
		local stars = m:FindFirstChild("RevealStars", true):GetAttribute("Emitted")
		eq({ soil, drops, stars }, { 10, 10, 8 })
		Assert.truthy(soil + drops + stars <= 30, "the 30-particle budget")
		local parts = 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") and string.sub(d.Name, 1, 6) == "Reveal" then
				parts += 1
				Assert.truthy(
					d.Material ~= c.engine.Enum.Material.Foil and d.Material ~= c.engine.Enum.Material.Neon,
					d.Name
				)
			end
		end
		eq(parts, 2, "the ring and the bar")
	end
)

test("reducedFx (or sfx off): no punch, Sound, Highlight, ring or shine; the puff and the burst at half", function()
	local c = client()
	c.Visuals.setReduced(true)
	local m = crop(c)
	c.Reveal.play(m, "wetgolden", { force = true })
	c.engine:advance(0.3)
	eq(
		{ m:FindFirstChild("RevealHighlight"), m:FindFirstChild("RevealSound", true), m:FindFirstChild("RevealRing") },
		{ nil, nil, nil }
	)
	eq(m:FindFirstChild("RevealShine", true), nil)
	eq(c.engine.workspace.CurrentCamera.FieldOfView, 70, "no punch")
	eq(m.Root.RevealSoilAt.RevealSoil:GetAttribute("Emitted"), 5, "the puff at half")
	eq({
		m:FindFirstChild("RevealDroplets", true):GetAttribute("Emitted"),
		m:FindFirstChild("RevealStars", true):GetAttribute("Emitted"),
	}, { 5, 4 })
	c.Visuals.setReduced(false)
	c.state.apply({ { path = { "settings", "sfx" }, value = false } })
	local q = crop(c, "Q")
	c.Reveal.play(q, "golden", { force = true })
	eq(
		{ q:FindFirstChild("RevealHighlight"), q:FindFirstChild("RevealSound", true) },
		{ nil, nil },
		"sfx off is quiet too"
	)
end)

test("never stack: a new key on a revealing tile cancels and restarts; the same key again is ignored", function()
	local c = client()
	local m = crop(c)
	local first = c.Reveal.play(m, "wet", { force = true })
	c.engine:advance(0.3)
	eq(c.Reveal.play(m, "wet", { force = true }), first, "the remote and the tile attribute: one reveal")
	local second = c.Reveal.play(m, "wetgolden", { force = true })
	Assert.truthy(second ~= first and first.done, "the first is cancelled")
	eq(second.t, 0, "restarts from 0")
	eq(m:GetAttribute("Muts"), "wetgolden", "the final look")
	eq(temps(m).RevealHighlight, 1, "one Highlight")
	eq(sounds(m), 1, "one Sound")
	eq(m:GetAttribute("Revealed"), 2)
end)

test("at most 2 at once (the nearest), and only within 60 studs unless the tile is yours", function()
	local c = client()
	local me = c.engine.Instance.new("Model")
	local root = c.engine.Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = V3.zero
	root.Parent = me
	me.Parent = c.engine.workspace
	c.engine.game.Players.LocalPlayer.Character = me
	local a = crop(c, "A", "carrot", V3.new(10, 0, 0))
	local b = crop(c, "B", "carrot", V3.new(30, 0, 0))
	local d = crop(c, "D", "carrot", V3.new(50, 0, 0))
	local far = crop(c, "F", "carrot", V3.new(90, 0, 0))
	eq(c.Reveal.play(far, "wet"), nil, "beyond 60 studs")
	eq(far:GetAttribute("Muts"), nil)
	Assert.truthy(c.Reveal.play(far, "wet", { own = true }), "your own tile always plays")
	Assert.truthy(c.Reveal.play(b, "wet"), "B")
	eq(#c.Reveal.active(), 2)
	eq(c.Reveal.play(d, "wet"), nil, "a third, farther: dropped")
	eq(d:GetAttribute("Muts"), "wet", "but it still wears its look")
	Assert.truthy(c.Reveal.play(a, "wet"), "a nearer one bumps the farthest")
	local names = {}
	for _, s in c.Reveal.active() do
		table.insert(names, s.model.Name)
	end
	table.sort(names)
	eq(names, { "A", "F" }, "your own (distance 0) and the nearest")
end)

test("the Mutation remote reveals your tile with its full key (Golden + the new Wet = Wet+Golden)", function()
	local c = client()
	local tile = c.plot.Tiles["2"]
	local now = c.engine.workspace:GetServerTimeNow()
	for k, v in
		{ Active = true, Seed = "tomato", Grown = 360, At = now, Rate = 1, GrowSec = 360, Ripe = true, Muts = "golden" }
	do
		tile:SetAttribute(k, v)
	end
	c.engine:advance(2)
	local m = c.engine.workspace.ClientCrops.Plot1_2
	c.remotes.Mutation.OnClientEvent:Fire({ tile = "2", mut = "wet", value = 1, newEntry = false })
	c.engine:advance(0.05)
	eq({ m:GetAttribute("RevealKey"), m:GetAttribute("Muts") }, { "wetgolden", "wetgolden" })
	tile:SetAttribute("Muts", "wetgolden") -- the server's render lands after the remote
	c.engine:advance(0.5)
	eq(m:GetAttribute("Revealed"), 1, "the attribute does not replay it")
	eq(c.engine.errors, {})
end)
