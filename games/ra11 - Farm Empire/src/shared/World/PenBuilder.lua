--[[
The four animal pens at the front right of the farm (World/Layout ANIMALS, Data/Animals). A pen you own is fenced, with its house at the back, a trough, its animals (more as it
levels) and a sign; at its gate, the feed plate. A pen you can buy is an outline with a sign (its pad sells it);
one for a later stage says which.

  PenBuilder.build(model, i, view)   the folder "Pens" under the territory model (rebuilt on change)
  PenBuilder.animal(parent, key, cframe)   one animal (a Model whose Root is at its feet)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animals = require(ReplicatedStorage.Shared.Data.Animals)
local Business = require(ReplicatedStorage.Shared.Data.Business)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)
local Layout = require(script.Parent.Layout)
local Shapes = require(script.Parent.Shapes)

local P = Constants.PALETTE
local rgb = Color3.fromRGB
local PenBuilder = {}

local INK = rgb(40, 34, 30)

local function cf(i, x, z, y, yaw)
	return Layout.cframe(i, x, z, y, yaw)
end

-- The animals: low-poly, chunky, built facing -z with their feet at the origin -------------------------------------
local function root(m)
	local r = Shapes.part(m, Vector3.new(0.5, 0.5, 0.5), CFrame.new(), Color3.new(1, 1, 1), { CanQuery = false })
	r.Name = "Root"
	r.Transparency = 1
	m.PrimaryPart = r
end

local BUILD = {}
function BUILD.chicken(m, o)
	Shapes.sphere(m, Vector3.new(1.1, 1, 1.3), o * CFrame.new(0, 0.95, 0.1), P.white)
	Shapes.sphere(m, Vector3.new(0.6, 0.6, 0.6), o * CFrame.new(0, 1.6, -0.45), P.white)
	Shapes.part(m, Vector3.new(0.18, 0.3, 0.35), o * CFrame.new(0, 1.95, -0.45), rgb(228, 40, 40))
	Shapes.part(m, Vector3.new(0.2, 0.15, 0.3), o * CFrame.new(0, 1.55, -0.85), rgb(255, 180, 40))
	Shapes.sphere(m, Vector3.new(0.5, 0.6, 0.4), o * CFrame.new(0, 1.15, 0.7), rgb(236, 232, 222)) -- the tail
	for _, x in { -0.2, 0.2 } do
		Shapes.part(m, Vector3.new(0.1, 0.5, 0.1), o * CFrame.new(x, 0.25, 0.1), rgb(255, 170, 40))
	end
end
function BUILD.pig(m, o)
	local pink = rgb(248, 168, 180)
	Shapes.sphere(m, Vector3.new(1.5, 1.3, 2.2), o * CFrame.new(0, 1.15, 0), pink)
	Shapes.sphere(m, Vector3.new(1.1, 1, 1), o * CFrame.new(0, 1.35, -1.1), pink)
	Shapes.cylinder(
		m,
		Vector3.new(0.25, 0.55, 0.55),
		o * CFrame.new(0, 1.3, -1.65) * CFrame.Angles(0, math.pi / 2, 0),
		rgb(236, 130, 150)
	)
	for _, x in { -0.35, 0.35 } do
		Shapes.part(m, Vector3.new(0.3, 0.35, 0.12), o * CFrame.new(x, 1.9, -1.0), rgb(236, 130, 150))
		Shapes.part(m, Vector3.new(0.12, 0.12, 0.06), o * CFrame.new(x * 0.6, 1.5, -1.6), INK)
		for _, z in { -0.6, 0.6 } do
			Shapes.part(m, Vector3.new(0.3, 0.6, 0.3), o * CFrame.new(x * 1.3, 0.3, z), pink)
		end
	end
end
function BUILD.cow(m, o)
	Shapes.part(m, Vector3.new(1.5, 1.3, 2.6), o * CFrame.new(0, 1.65, 0), P.white)
	for _, sp in { { 0.76, 1.8, 0.4 }, { -0.76, 1.5, -0.5 }, { 0.3, 2.31, -0.6 } } do
		Shapes.part(m, Vector3.new(0.06, 0.6, 0.8), o * CFrame.new(sp[1], sp[2], sp[3]), INK)
	end
	Shapes.part(m, Vector3.new(1, 1, 1.1), o * CFrame.new(0, 2.1, -1.6), P.white)
	Shapes.part(m, Vector3.new(0.9, 0.45, 0.3), o * CFrame.new(0, 1.85, -2.2), rgb(248, 180, 186))
	for _, x in { -0.4, 0.4 } do
		Shapes.part(m, Vector3.new(0.15, 0.4, 0.15), o * CFrame.new(x, 2.75, -1.6), rgb(240, 230, 200))
		Shapes.part(m, Vector3.new(0.4, 0.15, 0.2), o * CFrame.new(x * 1.6, 2.4, -1.5), INK)
		for _, z in { -0.9, 0.9 } do
			Shapes.part(m, Vector3.new(0.35, 1, 0.35), o * CFrame.new(x * 1.4, 0.5, z), P.white)
			Shapes.part(m, Vector3.new(0.37, 0.2, 0.37), o * CFrame.new(x * 1.4, 0.1, z), INK)
		end
	end
end
function BUILD.sheep(m, o)
	local wool = rgb(244, 242, 234)
	for _, b in { { 0, 1.3, 0, 1.6 }, { 0.35, 1.5, 0.5, 1.1 }, { -0.35, 1.5, -0.4, 1.1 }, { 0, 1.7, 0, 1.2 } } do
		Shapes.sphere(m, Vector3.new(b[4], b[4] * 0.9, b[4]), o * CFrame.new(b[1], b[2], b[3]), wool)
	end
	Shapes.sphere(m, Vector3.new(0.65, 0.75, 0.8), o * CFrame.new(0, 1.5, -1.05), rgb(60, 52, 48))
	for _, x in { -0.35, 0.35 } do
		Shapes.part(m, Vector3.new(0.3, 0.15, 0.15), o * CFrame.new(x, 1.65, -1.0), rgb(60, 52, 48))
		for _, z in { -0.5, 0.5 } do
			Shapes.part(m, Vector3.new(0.22, 0.8, 0.22), o * CFrame.new(x, 0.4, z), rgb(60, 52, 48))
		end
	end
end

function PenBuilder.animal(parent, key, cframe)
	local m = Shapes.model(parent, "Animal")
	m:SetAttribute("Kind", key)
	root(m)
	m.PrimaryPart.CFrame = cframe
	BUILD[key](m, cframe)
	return m
end

-- The houses at the back of each pen ------------------------------------------------------------------------------
local function house(m, o, key)
	if key == "chicken" then
		-- a red coop on legs with a ramp
		for _, x in { -1.6, 1.6 } do
			for _, z in { -1, 1 } do
				Shapes.part(m, Vector3.new(0.3, 1.2, 0.3), o * CFrame.new(x, 0.6, z), P.woodDark)
			end
		end
		Shapes.part(m, Vector3.new(3.6, 2.2, 2.4), o * CFrame.new(0, 2.3, 0), P.barnRed)
		Shapes.wedge(m, Vector3.new(3.8, 1.2, 1.4), o * CFrame.new(0, 4, -0.65) * CFrame.Angles(0, math.pi, 0), P.white)
		Shapes.wedge(m, Vector3.new(3.8, 1.2, 1.4), o * CFrame.new(0, 4, 0.65), P.white)
		Shapes.part(m, Vector3.new(0.9, 1, 0.1), o * CFrame.new(0, 2.1, -1.22), INK)
		Shapes.wedge(m, Vector3.new(0.9, 1.2, 1.6), o * CFrame.new(0, 0.6, -2.0) * CFrame.Angles(0, math.pi, 0), P.wood)
	elseif key == "pig" then
		-- a low wooden sty with a mud wallow in front
		Shapes.part(m, Vector3.new(4.4, 2.2, 3), o * CFrame.new(0, 1.1, 0.2), P.wood)
		Shapes.part(m, Vector3.new(4.8, 0.3, 3.6), o * CFrame.new(0, 2.35, 0.2), P.woodDark)
		Shapes.part(m, Vector3.new(1.4, 1.6, 0.1), o * CFrame.new(0, 0.8, -1.32), INK)
		local mud = Shapes.cylinder(
			m,
			Vector3.new(0.12, 4, 4),
			o * CFrame.new(-2, 0.08, -4.5) * CFrame.Angles(0, 0, math.pi / 2),
			rgb(110, 76, 50)
		)
		mud.Material = Enum.Material.Mud
	elseif key == "cow" then
		-- a little red barn with white trim
		Shapes.part(m, Vector3.new(5, 3.2, 3.4), o * CFrame.new(0, 1.6, 0.2), P.barnRed)
		Shapes.wedge(
			m,
			Vector3.new(5.2, 1.6, 1.8),
			o * CFrame.new(0, 4, -0.7) * CFrame.Angles(0, math.pi, 0),
			P.woodDark
		)
		Shapes.wedge(m, Vector3.new(5.2, 1.6, 1.8), o * CFrame.new(0, 4, 1.1), P.woodDark)
		Shapes.part(m, Vector3.new(2, 2.4, 0.1), o * CFrame.new(0, 1.2, -1.52), P.white)
		Shapes.part(m, Vector3.new(1.7, 2.1, 0.12), o * CFrame.new(0, 1.15, -1.55), P.barnRed)
		Shapes.part(m, Vector3.new(0.12, 2.6, 0.14), o * CFrame.new(0, 1.2, -1.58), P.white).Orientation =
			Vector3.new(0, 0, 40)
	else
		-- a blue-roofed shed with a hay rack
		Shapes.part(m, Vector3.new(4.6, 2.4, 3), o * CFrame.new(0, 1.2, 0.2), P.cream)
		Shapes.wedge(
			m,
			Vector3.new(4.8, 1.2, 1.6),
			o * CFrame.new(0, 3, -0.6) * CFrame.Angles(0, math.pi, 0),
			P.roofBlue
		)
		Shapes.wedge(m, Vector3.new(4.8, 1.2, 1.6), o * CFrame.new(0, 3, 1.0), P.roofBlue)
		Shapes.part(m, Vector3.new(3, 1, 0.8), o * CFrame.new(0, 0.9, -1.8), rgb(232, 196, 90))
	end
end

-- A low wooden fence along a side, with a gap (from, to: along the side, 0..len)
local function rail(m, o, len, gapFrom, gapTo)
	local segs = {}
	if gapFrom then
		table.insert(segs, { 0, gapFrom })
		table.insert(segs, { gapTo, len })
	else
		table.insert(segs, { 0, len })
	end
	for _, sg in segs do
		local a, b = sg[1], sg[2]
		if b - a > 0.2 then
			local mid, w = (a + b) / 2 - len / 2, b - a
			for _, y in { 0.7, 1.4 } do
				Shapes.part(m, Vector3.new(w, 0.2, 0.15), o * CFrame.new(mid, y, 0), P.white)
			end
			for x = a, b, math.max(1, (b - a) / math.max(1, math.floor((b - a) / 2.5))) do
				Shapes.part(m, Vector3.new(0.25, 1.7, 0.25), o * CFrame.new(x - len / 2, 0.85, 0), P.white)
			end
		end
	end
end

local function sign(m, i, x, z, title, line, color)
	return Shapes.sign(m, cf(i, x, z, 0), 6.4, 1.8, title, line, {
		name = "PenSign",
		bottom = 1.2,
		board = color or P.cream,
		ppi = 40,
	})
end

function PenBuilder.build(model, i, view)
	local old = model:FindFirstChild("Pens")
	if old then
		old:Destroy()
	end
	local f = Shapes.folder(model, "Pens")
	local stageIndex = Business[view.stage or "stand"].index
	for k, key in Layout.ANIMALS do
		local a = Animals[key]
		local u = Upgrades[key]
		local pen = Layout.PENS[key]
		local w, d = Layout.PEN.w, Layout.PEN.d
		local level = view.owned and view.owned[key] or 0
		local m = Shapes.model(f, "Pen" .. k)
		m:SetAttribute("Animal", key)
		m:SetAttribute("Level", level)
		local o = cf(i, pen.x, pen.z, 0)
		if level > 0 then
			-- the pen: straw ground, the fence (a gate gap at the front right, by the feed plate), the house,
			-- the trough, the animals
			local ground =
				Shapes.part(m, Vector3.new(w - 0.6, 0.12, d - 0.6), o * CFrame.new(0, 0.06, 0), rgb(214, 186, 120))
			ground.Material = Enum.Material.Sand
			ground.Name = "PenGround"
			rail(m, cf(i, pen.x, pen.z - d / 2 + 0.3, 0), w - 0.6, w / 2 + 0.4, w / 2 + 3.6)
			rail(m, cf(i, pen.x, pen.z + d / 2 - 0.3, 0), w - 0.6)
			for _, sx in { -1, 1 } do
				rail(m, cf(i, pen.x + sx * (w / 2 - 0.3), pen.z, 0, math.pi / 2), d - 0.6)
			end
			house(m, cf(i, pen.x, pen.z + d / 2 - 2.6, 0), key)
			local trough =
				Shapes.part(m, Vector3.new(3.2, 0.7, 1), cf(i, pen.x - 2.2, pen.z - d / 2 + 1.6, 0.35), P.woodDark)
			trough.Name = "Trough"
			Shapes.part(
				m,
				Vector3.new(2.9, 0.12, 0.7),
				cf(i, pen.x - 2.2, pen.z - d / 2 + 1.6, 0.66),
				rgb(232, 196, 90)
			).Name =
				"Feed"
			local herd = Shapes.folder(m, "Herd")
			local rng = Random.new(i * 100 + k)
			for n = 1, Animals.count(level) do
				local x = pen.x + rng:NextNumber(-w / 2 + 1.6, w / 2 - 1.6)
				local z = pen.z + rng:NextNumber(-d / 2 + 2.6, d / 2 - 5.4)
				PenBuilder.animal(herd, key, cf(i, x, z, 0.12, rng:NextNumber(-0.8, 0.8)))
				_ = n
			end
			-- the feed plate at the gate
			local fp = Layout.PENS[key].feed
			local plate =
				Shapes.part(m, Vector3.new(Layout.FEED, 0.3, Layout.FEED), cf(i, fp.x, fp.z, 0.15), rgb(232, 196, 90))
			plate.Name = "FeedPlate"
			plate:SetAttribute("Animal", key)
			plate.Material = Enum.Material.Neon
			Shapes.part(m, Vector3.new(Layout.FEED + 0.6, 0.2, Layout.FEED + 0.6), cf(i, fp.x, fp.z, 0.1), P.woodDark)
			Shapes.face(plate, "🌾 FEED", Enum.NormalId.Top, { PixelsPerStud = 30 })
		else
			-- the outline: corner posts and a sign
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					Shapes.part(
						m,
						Vector3.new(0.4, 1.4, 0.4),
						cf(i, pen.x + sx * (w / 2 - 0.5), pen.z + sz * (d / 2 - 0.5), 0.7),
						P.white
					)
				end
			end
			local open = Business[u.stage].index <= stageIndex
			sign(
				m,
				i,
				pen.x,
				pen.z - d / 2 + 2,
				`{a.icon} {string.upper(a.name)}`,
				open and `{a.word}: buy on the pad` or `opens with the {Business[u.stage].name}`,
				open and P.cream or rgb(210, 205, 196)
			)
		end
	end
	return f
end

return PenBuilder
