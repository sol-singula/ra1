--[[
Bots: alone in a server you get bots (allies and enemies) that walk, see, shoot, kill and respawn through the same
combat as everyone; you can kill them and push the line; the second person to join takes over a bot on the other
side (its team, where it stood) and every bot leaves; back to one person, they return.

  luaurun tests/BotSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3

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
local Bots = service("BotService")
local Teams = service("TeamService")
local Combat = service("CombatService")
local Match = service("MatchService")
local Constants = Engine.require(tree.shared.Constants)
local ws = Engine.workspace

local function root(who)
	return who.Character and who.Character:FindFirstChild("HumanoidRootPart")
end

-- one person: bots
local solo = Engine.addPlayer("Solo", 801)
Engine.advance(1)
Engine.fireServer(solo, "Ready")
Engine.advance(2)
local list = Bots:List()
check("alone: bots join", #list == Constants.BOT_ALLIES + Constants.BOT_ENEMIES, #list)
local mine = Teams:Team(solo)
local allies, enemies = 0, 0
for _, b in list do
	if Teams:Team(b) == mine then
		allies += 1
	else
		enemies += 1
	end
end
check(
	"...allies on your side, enemies on the other",
	allies == Constants.BOT_ALLIES and enemies == Constants.BOT_ENEMIES,
	`{allies} {enemies}`
)
check("...with bodies in the arena", list[1] and root(list[1]) ~= nil and list[1].Character.Parent ~= nil)
check("...named as bots", list[1].Character:FindFirstChild("BotTag") ~= nil)
check("...counted in the match", #Match:Everyone() == 1 + #list)
check("...holding a bow", list[1].Character:FindFirstChild("HeldBow") ~= nil)

-- the build phase: they walk to their own side
local start = root(list[1]).Position
Engine.advance(3)
check("in the build phase they move about", (root(list[1]).Position - start).Magnitude > 2)

-- the fight: they find someone and shoot
Engine.advance(Constants.BUILD_SECONDS + 1)
check("FIGHT", Match:Phase() == "fight", Match:Phase())
-- stand the solo player in the open in front of an enemy bot
local enemy
for _, b in list do
	if Teams:Team(b) ~= mine then
		enemy = b
		break
	end
end
local er = root(enemy)
local fwd = mine == "red" and -1 or 1
local line = Match:Frontline()
Engine.moveTo(solo, Vector3.new(line + fwd * 10, 3, er.Position.Z), er.Position)
local arrows = 0
local hurt = false
local m0 = #Engine.clientLog
for _ = 1, 60 do
	Engine.advance(0.25)
	-- keep the target standing still in the open
	Engine.moveTo(solo, Vector3.new(line + fwd * 10, 3, root(enemy) and root(enemy).Position.Z or 0))
end
for i = m0 + 1, #Engine.clientLog do
	local e = Engine.clientLog[i]
	if e.name == "Arrow" and e.args[1].by < 0 then
		arrows += 1
	end
	if e.name == "Hurt" and e.player == solo then
		hurt = true
	end
end
check("bots shoot (server arrows, like anyone's)", arrows >= 3, arrows)
check("...and hit you sometimes", hurt)

-- you can kill a bot, and it pushes the line
local f0 = Match:Frontline()
local victim
for _, b in Bots:List() do
	if Teams:Team(b) ~= mine and Combat:Alive(b) then
		victim = b
	end
end
if not Combat:Alive(solo) then
	Engine.advance(Constants.RESPAWN_SECONDS + 1)
end
Combat:Kill(victim, solo, { weapon = "bow" })
Engine.advance(0.2)
check("killing a bot pushes the line", Match:Frontline() ~= f0, `{f0} -> {Match:Frontline()}`)
check(
	"...and it respawns",
	(function()
		Engine.advance(Constants.RESPAWN_SECONDS + 1)
		return Combat:Alive(victim)
	end)()
)

-- a second person: they take over an enemy bot, and the bots go
local pick -- (the one the takeover chooses: the first enemy bot that's alive)
for _, b in Bots:List() do
	if Teams:Team(b) ~= mine and Combat:Alive(b) and not pick then
		pick = b
	end
end
local spot = root(pick).Position
local pal = Engine.addPlayer("Pal", 802)
Engine.advance(1)
Engine.fireServer(pal, "Ready")
Engine.advance(1)
check("a second person: every bot leaves", #Bots:List() == 0 and #ws.Bots:GetChildren() == 0, #Bots:List())
check("...and they take the bot's side", Teams:Team(pal) ~= mine and Teams:Team(pal) ~= nil, Teams:Team(pal))
check(
	"...where it stood",
	root(pal) and (root(pal).Position - spot).Magnitude < 4,
	root(pal) and (root(pal).Position - spot).Magnitude
)
check("...counted as two now", #Match:Everyone() == 2)
Engine.advance(3)
check("two people: no bots come back", #Bots:List() == 0)

-- back to one: the bots return
Engine.removePlayer(pal)
Engine.advance(2.5)
check("back to one person: bots again", #Bots:List() == Constants.BOT_ALLIES + Constants.BOT_ENEMIES, #Bots:List())
Engine.removePlayer(solo)
Engine.advance(2.5)
check("nobody on: no bots", #Bots:List() == 0)

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	failed += #Engine.errors
end
if failed > 0 then
	error("BotSmoke: " .. failed .. " failures")
end
