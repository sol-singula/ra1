--[[
The maps, at every size: every map builds, its spawns are open decks (from every pad you see out onto the field: no
walls, no hall; they're safe by rule, see ServerSmoke), and from every pad there's a clear walk out that never runs
into a wall. Then the sizes in a match: a new match with a lot of people gets the large arena (the lose lines move
with it), people joining mid-match never resize it, and the next match with few gets the small one again.

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
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
Engine.require(tree.shared.Constants).TUTORIAL = false -- (the players here know the game: tests/TutorialSmoke is the tutorial's)
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local Arena = Engine.require(tree.server.Services.ArenaService)
local Combat = Engine.require(tree.server.Services.CombatService)
local ArenaBuilder = Engine.require(tree.shared.World.ArenaBuilder)
local Maps = Engine.require(tree.shared.Data.Maps)

for _, m in Maps.list do
	for _, tier in ArenaBuilder.TIERS do
		local name = `{m.name} ({tier})`
		local a = Arena:Load(m.key, tier)
		check(`{name}: builds`, a and #a.spawns.red == 10 and #a.spawns.blue == 10 and a.tier == tier)
		local parts = #a.folder:GetDescendants()
		check(`{name}: detailed (hundreds of pieces)`, parts >= 450, parts)
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
		check(`{name}: open spawn decks (you see out)`, blind == 0, firstBlind)
		-- a clear walk out from every pad
		local stuck = 0
		for _, team in { "red", "blue" } do
			local s = team == "red" and -1 or 1
			for _, cf in a.spawns[team] do
				-- (straight out along the pad's own lane: the deck's cover stands between the lanes)
				local goal = V3.new(s * (a.half - 40), 3.5, cf.Position.Z)
				local p, out = cf.Position, false
				for _ = 1, 300 do
					local nxt = ArenaBuilder.route(a, team, p, goal)
					local dir = V3.new(nxt.X - p.X, 0, nxt.Z - p.Z)
					if dir.Magnitude < 0.3 then
						break
					end
					local step = dir.Unit * math.min(1, dir.Magnitude)
					local ahead = step.Unit * 1.6
					if
						Combat:Blocked(p, p + ahead) or Combat:Blocked(p + V3.new(0, 2, 0), p + ahead + V3.new(0, 2, 0))
					then
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
		check(`{name}: every pad has a clear way out`, stuck == 0, stuck)
		-- cover on both decks: solid parapets and piers between the lanes, that stop a shot across the deck
		for _, team in { "red", "blue" } do
			local s = team == "red" and -1 or 1
			local n = 0
			for _, solid in a.solids do
				if solid.part and solid.part.Name == "Cover" and s * solid.min.X > a.half - a.spawnDepth - 1 then
					n += 1
				end
			end
			local c = a.room.cover
			local z = c.pitch / 2
			local behind = V3.new(s * (a.half - c.parapet + 3), 2.5, z)
			local front = V3.new(s * (a.half - c.parapet - 6), 2.5, z)
			check(`{name}: {team}'s deck has cover`, n >= 12, n)
			check(`{name}: ...that stops a low shot at someone crouched behind it`, Combat:Blocked(front, behind))
		end
	end
end

-- the sizes in a match
do
	local Match = Engine.require(tree.server.Services.MatchService)
	local Constants = Engine.require(tree.shared.Constants)
	local crowd = {}
	for i = 1, 24 do
		table.insert(crowd, Engine.addPlayer("Crowd" .. i, 6000 + i))
	end
	Engine.advance(1)
	for _, p in crowd do
		Engine.fireServer(p, "Ready")
	end
	Engine.advance(1)
	Match:NewMatch("castle")
	Engine.advance(0.5)
	local a = Arena:Current()
	check("24 people: a new match gets the large arena", a.tier == "large", a.tier)
	check(
		"...its lose lines and the clients' copy move with it",
		Match:Snapshot().loseBlue == a.half - a.spawnDepth
			and Engine.workspace:GetAttribute("LoseRed") == -(a.half - a.spawnDepth)
			and Match:Snapshot().width == a.width,
		Match:Snapshot().loseBlue
	)
	local spawned = 0
	for _, p in crowd do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and math.abs(r.Position.X) > a.half - a.spawnDepth then
			spawned += 1
		end
	end
	check("...and everyone spawns on its decks", spawned == #crowd, spawned)
	for i = 1, 20 do
		Engine.removePlayer(crowd[i])
	end
	Engine.advance(1)
	check("people leaving mid-match never resize it", Arena:Current() == a and a.tier == "large")
	Match:NewMatch("frost")
	Engine.advance(0.5)
	check("the next match with 4 people: the small arena", Arena:Current().tier == "small", Arena:Current().tier)
	for i = 1, 8 do
		table.insert(crowd, Engine.addPlayer("Late" .. i, 6100 + i))
	end
	Engine.advance(2)
	check("people joining mid-match never resize it", Arena:Current().tier == "small", Arena:Current().tier)
	Match:NewMatch("jungle")
	Engine.advance(0.5)
	check("...the next match with 12: medium", Arena:Current().tier == "medium", Arena:Current().tier)
	_ = Constants
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
