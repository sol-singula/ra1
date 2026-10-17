--[[
Renders each map the way it plays (for the docs and the store page): the real server boots on the mock engine,
loads each map in turn, stages a moment of a match (players in their team colours on both sides of the line,
structures up, arrows in flight, the turf pushed off centre), and saves snapshots for render.js:

  luaurun tools/gameplay/maps.luau <outDir> [mapKey] [small|large]
  node tools/gameplay/render.js <outDir> <pngDir> --modules <node_modules> --chromium <chrome>

Each map at the small size (<key>_overview, _line, _side) and the large one (<key>_large, _large_line).
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local Instance = Engine.Instance
local Enum = Engine.Enum
local outDir = ARGS[1]
local tree = Engine.mountProject(".")
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1600, 900)
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Arena = service("ArenaService")
local Teams = service("TeamService")
local Build = service("BuildService")
local Match = service("MatchService")
local Constants = Engine.require(tree.shared.Constants)
local Formulas = Engine.require(tree.shared.Formulas)
local Maps = Engine.require(tree.shared.Data.Maps)
local ws = Engine.workspace

-- eight players, four a side
local players = {}
for i = 1, 8 do
	local p = Engine.addPlayer("P" .. i, 7000 + i)
	table.insert(players, p)
end
Engine.advance(1)
for _, p in players do
	Engine.fireServer(p, "Ready")
end
Engine.advance(1)
local viewer = players[1]
Engine.Players.LocalPlayer = viewer
Engine.localPlayer = viewer

local shots = {}
local function shot(name, pos, target, fov)
	local snap = Capture.snapshot(
		Engine,
		{ pos = { pos.X, pos.Y, pos.Z }, target = { target.X, target.Y, target.Z }, fov = fov or 70 }
	)
	snap.title = name
	snap.cinematic = false
	snap.hideGui = true
	snap.viewport = { w = 1600, h = 900, dpr = 1 }
	snap.focus = { target.X, target.Y, target.Z }
	Capture.save(Engine, snap, outDir, name)
	table.insert(shots, name)
end

-- an arrow frozen mid-flight: a white shaft and a long tracer in the team's colour (what ArrowController draws)
local fx = Instance.new("Folder")
fx.Name = "RenderArrows"
fx.Parent = ws
local function arrow(from, to, team)
	local dir = (to - from).Unit
	local len = (to - from).Magnitude
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.Size = V3.new(0.12, 0.12, len)
	tracer.CFrame = CF.lookAt((from + to) / 2, to)
	tracer.Color = Constants.TEAM_COLOR[team]
	tracer.Material = Enum.Material.Neon
	tracer.Parent = fx
	local shaft = Instance.new("Part")
	shaft.Anchored = true
	shaft.Size = V3.new(0.2, 0.2, 2.6)
	shaft.CFrame = CF.lookAt(to, to + dir)
	shaft.Color = Constants.WHITE
	shaft.Material = Enum.Material.SmoothPlastic
	shaft.Parent = fx
end

local onlyMap, onlySize = ARGS[2], ARGS[3]
local jobs = {}
for _, def in Maps.list do
	for _, size in { "small", "large" } do
		if (not onlyMap or onlyMap == def.key or onlyMap == "all") and (not onlySize or onlySize == size) then
			table.insert(jobs, { def = def, size = size })
		end
	end
end
for _, job in jobs do
	local def, size = job.def, job.size
	Match:NewMatch(def.key, size)
	Engine.advance(0.5)
	local frontline = -12
	Match:_setFrontline(frontline)
	-- structures on each side (built by the server's own rules)
	local red, blue = Teams:Members("red"), Teams:Members("blue")
	local plan = {
		{ "wall", -26, -28 },
		{ "tower", -34, 30 },
		{ "barricade", -22, 8 },
		{ "banner", -30, -10 },
		{ "wall", 6, 26 },
		{ "reinforced", 8, -24 },
		{ "tower", 20, 10 },
		{ "banner", 14, -6 },
	}
	for _, b in plan do
		local x, z = b[2], b[3]
		local team = Formulas.sideOf(x, frontline)
		local who = (team == "red" and red or blue)[1]
		if who then
			Engine.moveTo(who, V3.new(x, 3, z))
			local cx, cz = Formulas.cellOf(x, z)
			Build:Place(who, b[1], cx, cz, 0)
		end
	end
	-- players: spread along their side of the line
	for i, p in red do
		Engine.moveTo(p, V3.new(frontline - 8 - i * 7, 3, -30 + i * 14), V3.new(frontline + 20, 3, 0))
	end
	for i, p in blue do
		Engine.moveTo(p, V3.new(frontline + 10 + i * 8, 3, -26 + i * 13), V3.new(frontline - 20, 3, 0))
	end
	fx:ClearAllChildren()
	arrow(V3.new(frontline - 20, 4.5, -2), V3.new(frontline + 14, 4.2, 6), "red")
	arrow(V3.new(frontline + 30, 5, 20), V3.new(frontline - 2, 4.6, 14), "blue")
	arrow(V3.new(frontline - 30, 6, 24), V3.new(frontline + 6, 5.5, 30), "red")
	Engine.advance(0.1)
	-- (where a map's own shapes would stand in front of the camera, it gets its own spot)
	local cams = {
		castle = { side = { V3.new(24, 24, 36), V3.new(-20, 2, -6) } },
		dust = { line = { V3.new(frontline - 26, 6, 0), V3.new(frontline + 40, 4, 0) } },
	}
	local cam = cams[def.key] or {}
	if size == "small" then
		local line = cam.line or { V3.new(frontline - 26, 5.5, -10), V3.new(frontline + 40, 4, 2) }
		local side = cam.side or { V3.new(30, 17, 30), V3.new(-14, 4, -8) }
		shot(def.key .. "_overview", V3.new(-62, 78, -66), V3.new(14, 0, 8), 60)
		shot(def.key .. "_line", line[1], line[2], 75)
		shot(def.key .. "_side", side[1], side[2], 70)
	else
		local a = Arena:Current()
		shot(def.key .. "_large", V3.new(-a.half * 0.62, 104, -a.width * 0.7), V3.new(a.half * 0.1, 0, 8), 62)
		shot(def.key .. "_large_line", V3.new(frontline - 30, 6, -10), V3.new(frontline + 60, 5, 6), 75)
	end
end

local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
print("shots", #shots)
