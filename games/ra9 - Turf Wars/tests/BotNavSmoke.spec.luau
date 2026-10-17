--[[
Bots finding their way: on every map (and at every size), eight bots play two minutes of build and fight on the
mock engine with real bodies (tests/mock/Walker.luau: walls stop them, ledges need a step or a jump, edges drop
them), and none stays stuck: whenever a bot wants to go somewhere it keeps getting there.

  luaurun tests/BotNavSmoke.spec.luau [mapKey]
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Walker = loadModule("tests/mock/Walker.luau")
local V3 = Engine.Vector3

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

local tree = Engine.mountProject(".")
local Constants = Engine.require(tree.shared.Constants)
Constants.AFK_SECONDS = 0 -- (the person here stands still on purpose)
Constants.MIN_SIDE = 4 -- (four a side: the person and three bots, four bots against them)
Constants.TUTORIAL = false
Walker.install(Engine)
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Bots = service("BotService")
local Match = service("MatchService")
local Combat = service("CombatService")
local Arena = service("ArenaService")
local Maps = Engine.require(tree.shared.Data.Maps)
local Formulas = Engine.require(tree.shared.Formulas)

-- one person, kept far above the field (out of every bot's sight), so the bots fight each other
local solo = Engine.addPlayer("Watcher", 901)
Engine.advance(1)
Engine.fireServer(solo, "Ready")
Engine.advance(2)
local function park()
	if solo.Character and solo.Character:FindFirstChild("HumanoidRootPart") then
		Engine.moveTo(solo, V3.new(0, 500, 0))
	end
end

local function root(who)
	return who.Character and who.Character:FindFirstChild("HumanoidRootPart")
end

local only = ARGS and ARGS[1] ~= "all" and ARGS[1] or nil
local DEBUG = ARGS and ARGS[2] == "debug"
local SIM = 120 -- simulated seconds per map
local STUCK = 4 -- seconds of wanting to move without getting anywhere that count as stuck
for _, def in Maps.list do
	for _, size in { "small", "medium", "large" } do
		if only and only ~= def.key then
			continue
		end
		Match:NewMatch(def.key, size)
		Engine.advance(0.5)
		park()
		local a = Arena:Current()
		local track = {} -- [bot] = { hist = { {t, pos} }, wantFor, worst, at, reached, travelled }
		local t = 0
		local kills0 = 0
		while t < SIM do
			Engine.advance(0.25)
			t += 0.25
			park()
			for _, b in Bots:List() do
				local r = root(b)
				local tr = track[b] or { hist = {}, stuckFor = 0, worst = 0, travelled = 0 }
				track[b] = tr
				if r and Combat:Alive(b) and (Match:Phase() == "build" or Match:Phase() == "fight") then
					local p = r.Position
					table.insert(tr.hist, { t, p })
					while #tr.hist > 0 and tr.hist[1][1] < t - 1.5 do
						table.remove(tr.hist, 1)
					end
					if tr.last then
						local d = V3.new(p.X - tr.last.X, 0, p.Z - tr.last.Z).Magnitude
						if d < 6 then
							tr.travelled += d
						end
					end
					tr.last = p
					local want = b.wantAt or b.moveGoal
					local far = want and V3.new(want.X - p.X, 0, want.Z - p.Z).Magnitude > 3
					local old = tr.hist[1][2]
					local moved = V3.new(p.X - old.X, 0, p.Z - old.Z).Magnitude
					if far and t - tr.hist[1][1] >= 1.25 and moved < 1 then
						tr.stuckFor += 0.25
					elseif not far or moved >= 1 then
						tr.stuckFor = 0
					end
					if tr.stuckFor > tr.worst then
						tr.worst, tr.at, tr.goalAt = tr.stuckFor, p, want
					end
					if DEBUG and tr.stuckFor == 3 then
						local g = Bots.nav()
						local function cls(v)
							return v and g:ClassAt(v)
						end
						local near = {}
						for _, box in Arena:Collide() do
							if
								box.max.X > p.X - 3
								and box.min.X < p.X + 3
								and box.max.Z > p.Z - 3
								and box.min.Z < p.Z + 3
								and box.max.Y > 0.3
							then
								table.insert(
									near,
									string.format(
										"[%.1f..%.1f y%.1f..%.1f z%.1f..%.1f]",
										box.min.X,
										box.max.X,
										box.min.Y,
										box.max.Y,
										box.min.Z,
										box.max.Z
									)
								)
							end
						end
						print(
							string.format(
								"STUCK %s %s t=%.1f phase=%s at (%.1f,%.1f,%.1f) want (%.1f,%.1f) class %s/%s path=%s line=%.0f n=%s near %s",
								def.key,
								size,
								t,
								Match:Phase(),
								p.X,
								p.Y,
								p.Z,
								want.X,
								want.Z,
								tostring(cls(p)),
								tostring(cls(want)),
								tostring(b.path and #b.path),
								Match:Frontline(),
								tostring(b.stuckN),
								table.concat(near, " ")
							)
						)
					end
				else
					tr.hist, tr.stuckFor, tr.last = {}, 0, nil
				end
			end
			if Match:Phase() == "victory" or Match:Phase() == "loading" then
				break -- (someone won: the map's run is over)
			end
		end
		local worst, who, travelledMin = 0, nil, math.huge
		for b, tr in track do
			if tr.worst > worst then
				worst, who = tr.worst, tr
			end
			travelledMin = math.min(travelledMin, tr.travelled)
			_ = b
		end
		local where = who
				and who.at
				and string.format(
					"%.1fs at (%.0f, %.1f, %.0f) wanting (%.0f, %.0f)",
					who.worst,
					who.at.X,
					who.at.Y,
					who.at.Z,
					who.goalAt and who.goalAt.X or 0,
					who.goalAt and who.goalAt.Z or 0
				)
			or ""
		print(`{def.key} {size}: {#Bots:List()} bots, field {a.length}x{a.width}, worst stuck {where}`)
		check(`{def.name} ({size}): eight bots out on the field`, #Bots:List() == 7, #Bots:List())
		check(`{def.name} ({size}): no bot stays stuck`, worst < STUCK, where)
		check(`{def.name} ({size}): every bot gets about (40+ studs walked)`, travelledMin >= 40, travelledMin)
		_ = kills0
		_ = Formulas
	end
end

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	failed += #Engine.errors
end
if failed > 0 then
	error("BotNavSmoke: " .. failed .. " failures")
end
