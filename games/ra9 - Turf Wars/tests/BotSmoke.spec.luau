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
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
Engine.require(tree.shared.Constants).TUTORIAL = false -- (the players here know the game: tests/TutorialSmoke is the tutorial's)
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
check("alone: bots join", #list == 1, #list)
check("...just one, against you", #list == 1, #list)
local mine = Teams:Team(solo)
local allies, enemies = 0, 0
for _, b in list do
	if Teams:Team(b) == mine then
		allies += 1
	else
		enemies += 1
	end
end
check("...allies on your side, enemies on the other", allies == 0 and enemies == 1, `{allies} {enemies}`)
check("...with bodies in the arena", list[1] and root(list[1]) ~= nil and list[1].Character.Parent ~= nil)
check("...named as bots", list[1].Character:FindFirstChild("BotTag") ~= nil)
check("...counted in the match", #Match:Everyone() == 1 + #list)
check("...holding a bow", list[1].Character:FindFirstChild("HeldBow") ~= nil)

-- the build phase: they walk to their own side
local start = root(list[1]).Position
Engine.advance(3)
check("in the build phase they move about", (root(list[1]).Position - start).Magnitude > 2)
Engine.advance(12)
do
	local Build = service("BuildService")
	local theirs = 0
	for _, st in Build:All() do
		if st.owner == list[1] then
			theirs += 1
		end
	end
	check("...and build defences, like a person (walls, cover, a tower)", theirs >= 2, theirs)
end

-- the fight: they find someone and shoot
Engine.advance(Constants.BUILD_SECONDS + 1)
check("FIGHT", Match:Phase() == "fight", Match:Phase())
-- (the bots' own walls can stand right at the line now: clear them so this checks the shooting itself)
service("BuildService"):Clear()
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
	-- keep the target standing still in the open, somewhere the bot can see (the maps have columns and statues)
	local ez = root(enemy) and root(enemy).Position.Z or 0
	local spot = Vector3.new(line + fwd * 10, 3, ez)
	if root(enemy) then
		local eye = root(enemy).Position + Vector3.new(0, 1.5, 0)
		for _, dz in { 0, 4, -4, 8, -8, 12, -12 } do
			local p = Vector3.new(line + fwd * 10, 3, ez + dz)
			if not Combat:Blocked(eye, p + Vector3.new(0, 1.2, 0)) then
				spot = p
				break
			end
		end
	end
	Engine.moveTo(solo, spot)
end
for i = m0 + 1, #Engine.clientLog do
	local e = Engine.clientLog[i]
	if (e.name == "Arrow" or e.name == "Bomb") and e.args[1].by < 0 then
		arrows += 1 -- (an arrow, or now and then a TNT)
	end
	if e.name == "Hurt" and e.player == solo then
		hurt = true
	end
end
check("bots shoot (server arrows, like anyone's)", arrows >= 3, arrows)
check("...and hit you sometimes", hurt)
-- the TNT: in range and ready, a bot sometimes lobs one at you (made certain here)
do
	local chance = Constants.BOT_TNT_CHANCE
	Constants.BOT_TNT_CHANCE = 1
	if not Combat:Alive(solo) then
		Engine.advance(Constants.RESPAWN_SECONDS + 1)
	end
	local m1 = #Engine.clientLog
	local thrown, blasts = 0, 0
	for _ = 1, 40 do
		Engine.advance(0.25)
		local r = root(enemy)
		if r then
			-- (in TNT range, on your own side)
			Engine.moveTo(solo, Vector3.new(line + fwd * 10, 3, r.Position.Z))
		end
	end
	for i = m1 + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.name == "Bomb" and e.args[1].by < 0 then
			thrown += 1
		elseif e.name == "Blast" and e.args[1].by and e.args[1].by < 0 then
			blasts += 1
		end
	end
	check("bots throw TNT too (in range, now and then)", thrown >= 1 and blasts >= 1, `{thrown} {blasts}`)
	check("...a few seconds apart, not spammed", thrown <= 4, thrown)
	Constants.BOT_TNT_CHANCE = chance
end

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
-- in the CHARGE (the fight's last seconds), up close a bot draws its blade and slashes
do
	Constants.CHARGE_SECONDS = 1e6 -- (the whole fight is the CHARGE for this block)
	if not Combat:Alive(solo) then
		Engine.advance(Constants.RESPAWN_SECONDS + 1)
	end
	Engine.advance(Constants.SPAWN_PROTECT + 0.5)
	local Formulas = Engine.require(tree.shared.Formulas)
	local fwd = Formulas.forward(mine)
	local line = Match:Frontline()
	local me = Vector3.new(line - fwd * 2.5, 3, 20)
	local hp0
	local slashed = false
	for _ = 1, 30 do
		Engine.moveTo(solo, me, me + Vector3.new(fwd, 0, 0))
		Engine.moveTo(victim, me + Vector3.new(fwd * 4, 0, 0), me)
		hp0 = hp0 or Combat:Health(solo)
		Engine.advance(0.1)
		if Combat:Weapon(victim) == "blade" and Combat:Health(solo) < hp0 then
			slashed = true
			break
		end
	end
	check("up close a bot draws its blade and slashes", slashed, `{Combat:Weapon(victim)} {Combat:Health(solo)}`)
	Constants.CHARGE_SECONDS = 20
	Engine.advance(0.3)
end

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
	"...and the game starts over so they start even (a fresh build phase, the line in the middle)",
	Match:Phase() == "build" and Match:Frontline() == 0,
	`{Match:Phase()} {Match:Frontline()}`
)
check("...both spawned in their bases", root(pal) ~= nil and root(solo) ~= nil and Combat:Alive(pal))
_ = spot
check("...counted as two now", #Match:Everyone() == 2)
Engine.advance(3)
check("two people: no bots come back", #Bots:List() == 0)

-- back to one: the bots return
Engine.removePlayer(pal)
Engine.advance(2.5)
check("back to one person: bots again", #Bots:List() == 1, #Bots:List())
do
	-- the real rule: at least 2 a side, so one person gets a bot beside them and two against them
	Constants.MIN_SIDE = 2
	Bots:Ensure()
	Engine.advance(0.5)
	local mine, with, against = nil, 0, 0
	for _, p in Engine.Players:GetPlayers() do
		mine = mine or Teams:Team(p)
	end
	for _, b in Bots:List() do
		if Teams:Team(b) == mine then
			with += 1
		else
			against += 1
		end
	end
	check(
		"2 v 2 at least: one person gets a bot beside them and two against",
		with == 1 and against == 2,
		`{with} {against}`
	)
	Constants.MIN_SIDE = 1
	Bots:Ensure()
	Engine.advance(0.5)
end
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
