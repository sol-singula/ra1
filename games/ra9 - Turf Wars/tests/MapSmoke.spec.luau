--[[
The maps: every map builds, its spawns are open decks (from every pad you see out onto the field: no walls, no
hall; they're safe by rule, see ServerSmoke), and from every pad there's a clear walk out that never runs into a
wall.

  luaurun tests/MapSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
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
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local Arena = Engine.require(tree.server.Services.ArenaService)
local Combat = Engine.require(tree.server.Services.CombatService)
local ArenaBuilder = Engine.require(tree.shared.World.ArenaBuilder)
local Maps = Engine.require(tree.shared.Data.Maps)

for _, m in Maps.list do
	local a = Arena:Load(m.key)
	check(`{m.name}: builds`, a and #a.spawns.red == 10 and #a.spawns.blue == 10)
	local parts = #a.folder:GetDescendants()
	check(`{m.name}: detailed (hundreds of pieces)`, parts >= 450, parts)
	-- the spawn is an open deck: from every pad you see the field (no walls, no hall)
	local blind, firstBlind = 0, nil
	for _, team in { "red", "blue" } do
		local s = team == "red" and -1 or 1
		for _, cf in a.spawns[team] do
			local eye = cf.Position + V3.new(0, 1.5, 0)
			local out = V3.new(s * (a.half - a.room.front1 - 6), eye.Y, cf.Position.Z)
			if Combat:Blocked(eye, out) then
				blind += 1
				firstBlind = firstBlind or `{eye} -> {out}`
			end
		end
	end
	check(`{m.name}: open spawn decks (you see out)`, blind == 0, firstBlind)
	-- a clear walk out from every pad
	local stuck = 0
	for _, team in { "red", "blue" } do
		local s = team == "red" and -1 or 1
		local goal = V3.new(s * (a.half - 40), 3.5, 0)
		for _, cf in a.spawns[team] do
			local p, out = cf.Position, false
			for _ = 1, 300 do
				local nxt = ArenaBuilder.route(a, team, p, goal)
				local dir = V3.new(nxt.X - p.X, 0, nxt.Z - p.Z)
				if dir.Magnitude < 0.3 then
					break
				end
				local step = dir.Unit * math.min(1, dir.Magnitude)
				local ahead = step.Unit * 1.6
				if Combat:Blocked(p, p + ahead) or Combat:Blocked(p + V3.new(0, 2, 0), p + ahead + V3.new(0, 2, 0)) then
					break
				end
				p += step
				if not ArenaBuilder.inRoom(a, team, p) then
					out = true
					break
				end
			end
			if not out then
				stuck += 1
			end
		end
	end
	check(`{m.name}: every pad has a clear way out`, stuck == 0, stuck)
end

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	failed += #Engine.errors
end
if failed > 0 then
	error("MapSmoke: " .. failed .. " failures")
end
