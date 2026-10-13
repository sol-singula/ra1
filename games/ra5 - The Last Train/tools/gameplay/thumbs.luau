--[[
Store-page thumbnails and screenshots: the real game (server + client code on the mock engine) played into a few
cinematic moments, with no UI. Snapshots are marked cinematic so render.js also writes a depth pass, and
tools/gameplay/thumbs_post.py adds the "shader" look (bloom, colour grade, depth blur, vignette) and the title.

  luaurun tools/gameplay/thumbs.luau <outDir>        (from the game folder)
  node tools/gameplay/render.js <outDir> <renderDir> --modules <node_modules>
  python3 tools/gameplay/thumbs_post.py <renderDir> <thumbDir> --font Oswald.ttf
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local rgb = Engine.globals.Color3.fromRGB
local outDir = ARGS[1] or "screens"
local only = ARGS[2] -- (optional) render just the shots whose name contains this

local tree = Engine.mountProject(".")
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1920, 1080)
Engine.runScript(tree.server.Main)
Engine.advance(0.1)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local Expedition = service("ExpeditionService")
local Train = service("TrainService")
local Resources = service("ResourceService")
local Cabins = service("CabinService")
local Records = service("RecordService")
local Recovery = service("RecoveryService")
local Layout = Engine.require(tree.shared.World.Layout)
local Stops = Engine.require(tree.shared.Data.Stops)
local CabinItems = Engine.require(tree.shared.Data.CabinItems)
local World = Engine.require(tree.server.World.WorldBuilder).layout
local ws = Engine.workspace

-- The crew: bots with their own colours, then the local player with the real client scripts
local CREW = {
	{ "RailRunner", 901, rgb(214, 74, 60), rgb(40, 46, 70), rgb(255, 206, 160) },
	{ "MapleMoss", 902, rgb(70, 140, 90), rgb(70, 52, 36), rgb(150, 100, 70) },
	{ "NovaKit", 903, rgb(90, 120, 220), rgb(30, 30, 40), rgb(240, 196, 150) },
	{ "Juniper", 904, rgb(230, 170, 60), rgb(60, 60, 70), rgb(255, 220, 190) },
	{ "Pepper", 905, rgb(170, 90, 200), rgb(240, 240, 240), rgb(120, 82, 56) },
}
local function paint(p, shirt, pants, skin)
	for _, part in p.Character:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local n = part.Name
			if n == "UpperTorso" or string.find(n, "Arm") then
				part.Color = shirt
			elseif string.find(n, "Leg") then
				part.Color = pants
			elseif n == "Head" or string.find(n, "Hand") then
				part.Color = skin
			end
		end
	end
end
local bots = {}
for i, spec in CREW do
	local p = Engine.addPlayer(spec[1], spec[2])
	Engine.makeCharacter(p)
	Engine.advance(0.1)
	Engine.fireServer(p, "Ready")
	Engine.fireServer(p, "SkipTutorial")
	paint(p, spec[3], spec[4], spec[5])
	bots[i] = p
end
local player = Engine.addPlayer("Ava", 4242)
player.DisplayName = "Ava"
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.makeCharacter(player)
paint(player, rgb(40, 150, 150), rgb(50, 44, 40), rgb(255, 214, 176))
Engine.runScript(tree.client.Main)
Engine.advance(0.8)
Engine.fireServer(player, "SkipTutorial")
Engine.advance(0.3)

local shots = {}
local function shot(name, camPos, camTarget, fov, focus)
	if only and not string.find(name, only, 1, true) then
		return
	end
	Engine.advance(0.05)
	local snap = Capture.snapshot(Engine, {
		pos = { camPos.X, camPos.Y, camPos.Z },
		target = { camTarget.X, camTarget.Y, camTarget.Z },
		fov = fov or 50,
	})
	snap.title = name
	snap.cinematic = true
	snap.hideGui = true
	snap.viewport = { w = 1920, h = 1080, dpr = 1 }
	focus = focus or camTarget
	snap.focus = { focus.X, focus.Y, focus.Z }
	writeFile(outDir .. "/" .. name .. ".json", Engine.game:GetService("HttpService"):JSONEncode(snap))
	table.insert(shots, name)
	print("shot", name, #snap.parts, "parts")
end
local function stand(p, pos, look)
	Engine.moveTo(p, pos + V3.new(0, 3, 0), look and (look + V3.new(0, 3, 0)) or nil)
end
local function skip()
	local before = Expedition:Phase()
	Expedition:Skip()
	for _ = 1, 25 do
		Engine.advance(0.2)
		if Expedition:Phase() ~= before then
			break
		end
	end
end
local function skipTo(target)
	for _ = 1, 12 do
		if Expedition:Phase() == target then
			return
		end
		skip()
	end
end

-- Everyone's cabin: Ava's is finished (oak, teal), the crew's are part way --------------------------------------
local function furnish(p, keys, color, finish, spec)
	local profile = Data:Get(p)
	for _, k in keys do
		profile.cabin.built[k] = true
	end
	profile.cabin.color = color
	profile.cabin.variants.finish = finish
	profile.cabin.variants.specialist = spec
	profile.souvenirs = { ranger = 3, timber = 2, signal = 2, platform = 1 }
	profile.visited = { ranger = true, timber = true, signal = true, platform = true }
	profile.best = 42.5
	Cabins:Draw(Cabins:IndexOf(p))
end
local all = {}
for _, item in CabinItems.list do
	table.insert(all, item.key)
end
furnish(player, all, "teal", "oak", "explorer")
furnish(bots[1], { "bunk", "lamp", "crate", "bench" }, "crimson", nil, nil)
furnish(
	bots[2],
	{ "bunk", "lamp", "crate", "bench", "worksurface", "workbench", "finish", "comfort" },
	"moss",
	"forest",
	nil
)
furnish(bots[3], { "bunk", "lamp" }, "navy", nil, nil)

-- The crew upgrades the train all the way (so the record train looks its best) -----------------------------------
do
	local giver = bots[4]
	local pg = Data:Get(giver)
	pg.storage = { wood = 99, scrap = 99, parts = 99, cloth = 99 }
	pg.blueprints = { engine = 2, radio = 1 }
	for _ = 1, 3 do
		for _, res in { "scrap", "parts", "cloth", "wood" } do
			Train:Deposit(giver, "engine", res, 99)
		end
		Train:Deposit(giver, "engine", "plans", 1)
	end
	for _ = 1, 2 do
		for _, res in { "scrap", "parts", "cloth", "wood" } do
			Train:Deposit(giver, "lamp", res, 99)
		end
		Train:Deposit(giver, "lamp", "plans", 1)
	end
	print("train stages", Train:Stage("engine"), Train:Stage("lamp"))
end
Engine.advance(0.5)

-- A record on the wall ----------------------------------------------------------------------------------------
do
	local crew = {}
	for i, b in bots do
		table.insert(crew, {
			userId = b.UserId,
			name = b.Name,
			display = b.DisplayName,
			stops = 17 - i,
			fuel = 6 - i,
			materials = 40 - i * 5,
			blueprints = i % 2,
			recovered = i == 3 and 1 or 0,
		})
	end
	table.insert(crew, 1, {
		userId = 4242,
		name = "Ava",
		display = "Ava",
		stops = 17,
		fuel = 7,
		materials = 52,
		blueprints = 2,
		recovered = 0,
	})
	Records:Save({
		schema = 1,
		id = "thumbs-record-1",
		code = "7F3A",
		km = 42.5,
		stops = 17,
		route = { "ranger", "timber", "signal", "platform" },
		milestones = 4,
		region = Stops.REGION,
		startedAt = os.time() - 4300,
		endedAt = os.time(),
		updatedAt = os.time(),
		seconds = 4300,
		crew = crew,
		helpers = 3,
		recognition = { fuel = { userId = 4242, name = "Ava", amount = 7 } },
		train = { engine = 3, lamp = 2 },
		live = false,
	})
	for i, km in { 31, 24.5, 17.5, 12.5 } do
		Records:Save({
			schema = 1,
			id = "thumbs-record-" .. (i + 1),
			code = ({ "B21C", "9DD0", "E4A7", "11F2" })[i],
			km = km,
			stops = math.floor(km / 2.5),
			route = {},
			crew = { { userId = 990 + i, name = ({ "Tumble", "Quill", "Sprocket", "Wren" })[i] } },
			helpers = 0,
			startedAt = os.time() - 2000,
			endedAt = os.time() - i * 86400,
			updatedAt = os.time() - i * 86400,
			seconds = 1800 + i * 300,
			train = { engine = 1, lamp = i % 2 },
			live = false,
		})
	end
	Records:Refresh(true)
	Engine.advance(0.5)
end

-- 1 boarding at the station: the crew walks to the doors under the iron arches ------------------------------------
local doors = Layout.doors
local function door(i)
	return doors[i].cf.Position
end
stand(bots[1], V3.new(door(4).X + 3, 4, 17), door(4))
stand(bots[2], V3.new(door(4).X - 6, 4, 22), door(4))
stand(bots[3], V3.new(door(5).X + 4, 4, 24), door(5))
stand(bots[4], V3.new(door(5).X - 2, 4, 30), door(5))
stand(bots[5], V3.new(door(6).X + 5, 4, 20), door(6))
stand(player, V3.new(door(4).X + 12, 4, 26), door(4))
Engine.advance(0.3)
shot("01_station_boarding", V3.new(door(4).X + 40, 9.5, 34), V3.new(door(4).X - 30, 8, 8), 55, door(4))
-- the concourse and the Hall of Records
stand(bots[2], V3.new(-8, 4, 98), V3.new(0, 4, 124))
stand(bots[5], V3.new(9, 4, 96), V3.new(0, 4, 124))
stand(player, V3.new(2, 4, 92), V3.new(0, 4, 124))
Engine.advance(0.3)
shot("02_hall_of_records", V3.new(0, 11, 72), V3.new(0, 11, 118), 55, V3.new(0, 7, 108))

-- 3 a finished cabin, warm and lived in -------------------------------------------------------------------------
local cabin = Layout.cabins[Cabins:IndexOf(player)]
stand(player, cabin.center + V3.new(-2.5, 0, 4), cabin.center + V3.new(0, 0, 9))
Engine.advance(0.2)
shot(
	"03_my_cabin",
	cabin.center + V3.new(3.5, 7.2, -7.8),
	cabin.center + V3.new(-1.5, 3.4, 5),
	72,
	cabin.center + V3.new(0, 3, 3)
)

-- Away we go ------------------------------------------------------------------------------------------------------
for _, p in { player, table.unpack(bots) } do
	stand(p, Layout.ENTRY_CF.Position - V3.new(0, 3, 0))
end
skipTo("traveling")
Engine.advance(6) -- the forest is streaming past
-- 7 on the line: the train in the forest at golden hour, from the trees
shot("07_on_the_line", V3.new(-150, 7, 40), V3.new(40, 9, 0), 45, V3.new(-60, 8, 12))

-- The first stop: Ranger Station at dusk ------------------------------------------------------------------------
Expedition:State().nextStop = Stops.byKey.ranger
skipTo("scavenging")
Engine.advance(1)
local function nearestNode(kind, from)
	local best, bestD
	for _, n in Resources:Nodes() do
		if n.kind == kind and n.model.Parent then
			local d = (n.root.Position - from).Magnitude
			if not bestD or d < bestD then
				best, bestD = n, d
			end
		end
	end
	return best
end
local function nodePos(kind, from)
	local n = nearestNode(kind, from)
	return n and n.root.Position or from
end
do
	local centre = V3.new(0, 0, 60)
	local w = nodePos("wood", centre)
	local c = nodePos("cloth", V3.new(40, 0, 70))
	local s = nodePos("scrap", V3.new(-40, 0, 60))
	local f = nodePos("fuel", V3.new(10, 0, 40))
	stand(bots[1], w + V3.new(2.5, 0, -1.5), w)
	stand(bots[2], w + V3.new(-6, 0, 4), w)
	stand(bots[3], s + V3.new(2, 0, 2), s)
	stand(bots[5], f + V3.new(0, 0, 3), V3.new(f.X, 0, 0))
	stand(player, w + V3.new(-3, 0, -9), V3.new(w.X - 3, 0, 0))
	stand(bots[4], V3.new(door(5).X + 2, 4, 16), V3.new(door(5).X + 2, 4, 40))
	Engine.advance(0.3)
	print("ranger wood pile at", w, "cloth", c)
	shot("04_ranger_station", w + V3.new(10, 5.5, 16), V3.new(w.X - 10, 6, 6), 55, w)
end

-- 5 the final call: everyone runs for the doors as the beacons flash ---------------------------------------------
skipTo("warning")
Expedition:Skip()
Engine.advance(0.25)
ws:SetAttribute("Final", true)
Train:Doors("closing")
for i, d in World.train.doors do
	d.beaconLight.Brightness = 2.5
	_ = i
end
do
	local x = door(5).X
	stand(bots[1], V3.new(x + 4, 4, 21), V3.new(x, 4, 13))
	stand(bots[2], V3.new(x - 6, 4, 28), V3.new(x, 4, 13))
	stand(bots[3], V3.new(x + 10, 4, 34), V3.new(x, 4, 13))
	stand(player, V3.new(x - 1, 4, 17), V3.new(x, 4, 13))
	stand(bots[5], V3.new(x - 14, 4, 40), V3.new(x, 4, 13))
	Engine.advance(0.3)
	shot("05_final_call", V3.new(x + 13, 5.5, 46), V3.new(x - 3, 6.5, 11), 52, V3.new(x, 6, 20))
end
for _, p in { player, table.unpack(bots) } do
	stand(p, Layout.ENTRY_CF.Position - V3.new(0, 3, 0))
end
skipTo("traveling")

-- 6 the signal tower at blue hour: someone's up top with the blueprint, the Radio Mast's beacon shows the way ------
Expedition:State().distance = math.max(Expedition:State().distance, 5)
Expedition:State().nextStop = Stops.byKey.signal
skipTo("scavenging")
Engine.advance(1.5)
do
	local bp = nearestNode("blueprint", V3.new(0, 30, 150))
	local top = bp and bp.root.Position or V3.new(0, 30, 150)
	stand(bots[3], top + V3.new(2, -0.5, 1), top)
	local s = nodePos("parts", V3.new(-20, 0, 80))
	stand(bots[1], s + V3.new(2, 0, 2), s)
	stand(player, V3.new(top.X - 14, 0, top.Z - 40), top)
	Engine.advance(0.4)
	shot("06_signal_tower", V3.new(top.X - 40, 8, top.Z - 76), V3.new(top.X, top.Y - 6, top.Z), 50, top)
end
for _, p in { player, table.unpack(bots) } do
	stand(p, Layout.ENTRY_CF.Position - V3.new(0, 3, 0))
end
skipTo("traveling")

-- 9 the overgrown platform in green fog
Expedition:State().distance = math.max(Expedition:State().distance, 15)
Expedition:State().nextStop = Stops.byKey.platform
skipTo("scavenging")
Engine.advance(1)
do
	local c = nodePos("cloth", V3.new(0, 0, 80))
	print("overgrown cloth at", c)
	stand(bots[2], c + V3.new(2, 0, -2), c)
	stand(bots[5], c + V3.new(-5, 0, 4), c)
	stand(player, V3.new(c.X + 6, 0, c.Z - 12), c)
	Engine.advance(0.3)
	shot("09_overgrown_platform", V3.new(c.X - 26, 8, c.Z + 30), V3.new(c.X + 4, 6, c.Z - 12), 55, c)
end

-- 10 left behind: night at the signal hut, the flare and the lever -------------------------------------------------
do
	stand(player, World.recovery.spawn.Position - V3.new(0, 3, 0))
	Recovery:Strand(player)
	Engine.advance(1.5)
	local lever = World.recovery.lever.Position
	local spot = World.recovery.fuseSpots[2].Position
	stand(player, spot + V3.new(1.5, 0, 1.5), spot)
	Engine.advance(0.5)
	shot("10_left_behind", spot + V3.new(-10, 4, 12), lever + V3.new(0, -2, 0), 58, spot)
end

writeFile(outDir .. "/index.json", Engine.game:GetService("HttpService"):JSONEncode(shots))
print(`{#shots} shots, {#Engine.errors} script errors`)
for _, e in Engine.errors do
	print(e)
end
