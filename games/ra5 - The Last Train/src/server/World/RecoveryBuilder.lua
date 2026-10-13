-- The emergency signal hut, far out in the woods (Layout.RECOVERY_ORIGIN): where you end up when the train leaves
-- without you. A small clearing at night with a hut, a generator, a fuse box and a signal flare. Three fuses glow in
-- the grass round it (RecoveryService: find them, fit them, pull the lever, and a pickup brings you back).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ReplicatedStorage.Shared.World.Kit)
local Layout = require(ReplicatedStorage.Shared.World.Layout)

local RecoveryBuilder = {}

local C, M = Kit.C, Kit.M
local box, cyl, disc = Kit.box, Kit.cyl, Kit.disc

function RecoveryBuilder.build(parent)
	local origin = Layout.RECOVERY_ORIGIN
	local model = Kit.model("Recovery", parent)
	local rng = Random.new(77)
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end
	box(model, "Ground", at(0, -1, 0), Vector3.new(260, 2, 260), C.grassDark, M.Grass)
	box(model, "Clearing", at(0, 0.02, 0), Vector3.new(70, 0.06, 70), C.dirt:Lerp(C.grassDark, 0.4), M.Ground, { CastShadow = false })
	-- a disused spur of track running into the trees
	Kit.track(model, at(0, 0.1, 30), 200)
	-- the hut
	local hut = Kit.model("SignalHut", model)
	box(hut, "HutFloor", at(0, 0.6, -14), Vector3.new(16, 1.2, 12), C.concreteDark, M.Concrete)
	box(hut, "HutBack", at(0, 6, -19.6), Vector3.new(16, 10, 0.8), C.woodDark, M.WoodPlanks)
	box(hut, "HutSide", at(-7.6, 6, -14), Vector3.new(0.8, 10, 12), C.woodDark, M.WoodPlanks)
	box(hut, "HutSide", at(7.6, 6, -14), Vector3.new(0.8, 10, 12), C.woodDark, M.WoodPlanks)
	box(hut, "HutRoof", at(0, 11.4, -14) * CFrame.Angles(math.rad(10), 0, 0), Vector3.new(18, 0.6, 14), C.rust, M.CorrodedMetal)
	local lamp = Kit.bulb(hut, "HutLamp", (at(0, 9.6, -15)).Position, 0.7, C.warm, 26, 1.6)
	_ = lamp
	-- the fuse box (on the back wall) and the lever
	local fuseBox = box(hut, "FuseBox", at(-3, 5, -19), Vector3.new(3, 4, 0.8), C.iron, M.Metal)
	local fuseLamp = box(hut, "FuseLamp", at(-3, 7.4, -18.55), Vector3.new(1.6, 0.4, 0.2), C.signal, M.Neon, { CastShadow = false })
	local lever = box(hut, "Lever", at(3, 4.5, -18.8) * CFrame.Angles(math.rad(-30), 0, 0), Vector3.new(0.5, 3.2, 0.5), C.red, M.Metal)
	box(hut, "LeverBase", at(3, 3.2, -19.1), Vector3.new(1.6, 1.2, 0.6), C.iron, M.Metal)
	-- generator and a jerrycan
	box(hut, "Generator", at(5, 2.4, -9), Vector3.new(4, 3.4, 3), Kit.rgb(70, 96, 78), M.Metal)
	cyl(hut, "Exhaust", at(6.4, 4.8, -9), 1.6, 0.5, C.steel, M.Metal)
	-- the flare launcher (fires when the signal goes up)
	disc(model, "FlareBase", (at(12, 0.6, -6)).Position, 2, 1.2, C.iron, M.Metal)
	local flare = box(model, "FlareTube", at(12, 2.6, -6), Vector3.new(0.6, 3, 0.6), C.signal, M.Metal)
	-- the sign
	Kit.sign(model, at(0, 13, -7.2) * CFrame.Angles(0, math.pi, 0), 14, 2, "EMERGENCY SIGNAL POINT", { ppu = 30 })
	-- fuse spots (in the grass around the clearing)
	local fuseSpots = {}
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(18, 30)
		table.insert(fuseSpots, at(math.cos(a) * r, 0, math.sin(a) * r + 4))
	end
	-- the forest round the clearing
	local trees = Kit.folder("Forest", model)
	for _ = 1, 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(42, 110)
		Kit.pine(trees, (at(math.cos(a) * r, 0, math.sin(a) * r)).Position, rng:NextNumber(30, 50), rng)
	end
	for _ = 1, 20 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(10, 34)
		Kit.fern(model, (at(math.cos(a) * r, 0, math.sin(a) * r)).Position, rng)
	end
	-- walls: a ring of invisible boxes
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		Kit.wall(model, at(math.cos(a) * 46, 20, math.sin(a) * 46) * CFrame.Angles(0, -a, 0), Vector3.new(2, 40, 26))
	end
	return {
		model = model,
		spawn = at(0, 3, 6) * CFrame.Angles(0, math.pi, 0),
		fuseBox = fuseBox,
		fuseLamp = fuseLamp,
		lever = lever,
		flare = flare,
		fuseSpots = fuseSpots,
	}
end

return RecoveryBuilder
