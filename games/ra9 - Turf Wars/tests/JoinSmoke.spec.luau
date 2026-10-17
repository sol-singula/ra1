--[[
Joining: with the live settings (2 v 2 minimum, bots, the tutorial on, the AFK room on), everyone who joins, at any
point of the match, one after another, gets a team and a body on their side and is alive; nobody is left without
one. (The live bug: people loading in, standing in the floor with RESPAWNING and no team.)

  luaurun tests/JoinSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")

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
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Teams = service("TeamService")
local Combat = service("CombatService")
local Match = service("MatchService")

local function root(who)
	return who.Character and who.Character:FindFirstChild("HumanoidRootPart")
end

local people = {}
local function join(i)
	local p = Engine.addPlayer("Joiner" .. i, 9100 + i)
	Engine.advance(0.5)
	Engine.fireServer(p, "Ready")
	table.insert(people, p)
	return p
end

local Bots = service("BotService")
local function audit(label)
	local red, blue = Teams:People("red"), Teams:People("blue")
	local want = math.abs(red - blue)
	if red + blue == 1 then
		want = 1
	end
	check(`{label}: bots only for the odd one out`, #Bots:List() == want, `{#Bots:List()} bots, {red} v {blue}`)
	for _, p in people do
		if p.Parent then
			local r = root(p)
			check(`{label}: {p.Name} has a team`, Teams:Team(p) ~= nil, Match:Phase())
			check(`{label}: {p.Name} is alive`, Combat:Alive(p), Match:Phase())
			check(`{label}: {p.Name} has a body`, r ~= nil)
			check(`{label}: {p.Name} is not in the floor`, r == nil or r.Position.Y > 1, r and r.Position.Y)
		end
	end
end

-- a restart: everyone back at once (the live bug: 28 people in 6 seconds, 2 of them got a team)
local burst = {}
for i = 1, 20 do
	local p = Engine.addPlayer("Burst" .. i, 9500 + i)
	table.insert(burst, p)
	table.insert(people, p)
	Engine.advance(0.25)
end
for _, p in burst do
	Engine.fireServer(p, "Ready")
end
Engine.advance(8)
audit("a burst of 20 joins")
for _, p in burst do
	p:Destroy()
end
people = {}
Engine.advance(3)

-- one by one, every few seconds, through the build phase, the fight and the next match
for i = 1, 7 do
	join(i)
	Engine.advance(6)
	audit("after join " .. i .. " (" .. Match:Phase() .. ")")
end
-- through to the fight
for _ = 1, 40 do
	Engine.advance(3)
	if Match:Phase() == "fight" then
		break
	end
end
Engine.advance(5)
join(8)
Engine.advance(6)
audit("joined in the fight")
-- someone leaves, someone else comes
people[2]:Destroy()
Engine.advance(3)
join(9)
Engine.advance(6)
audit("after a leave and a join")

-- whatever goes wrong while joining, they still end up on a team, alive
do
	local pick, dress = Teams._pick, Teams.Dress
	Teams._pick = function()
		error("picking a team broke (as live: a crowd joining at once)")
	end
	Teams.Dress = function()
		error("the look broke")
	end
	local p = join(20)
	Engine.advance(6)
	Teams._pick, Teams.Dress = pick, dress
	check("picking a team throws: still on a team", Teams:Team(p) ~= nil)
	check("the look throws: still alive", Combat:Alive(p))
	check("...with a body", root(p) ~= nil)
end
-- someone left with no team at all (however it happened): the watchdog joins them again in a few seconds
do
	local p = people[#people]
	Teams:Clear(p)
	Engine.advance(8)
	check("no team: the watchdog puts them back on one", Teams:Team(p) ~= nil)
	check("...alive", Combat:Alive(p))
end

print(`JoinSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error("JoinSmoke failed")
end
