--[[
Bonk Arena smoke test: boots the server in arena mode on the mock engine (only profiles and the arena), with two
players: spawning on the pads with their weapon and a shield, bonking, knock-outs and KOs, respawning, the board.

  luaurun tests/ArenaSmoke.spec.luau        (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local CFrame = Engine.CFrame

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
Engine.workspace:SetAttribute("ArenaTest", true)
Engine.runScript(tree.server.Main)
Engine.advance(0.1)
local Constants = Engine.require(tree.shared.Constants)
local World = Engine.require(tree.server.World.WorldBuilder).layout
local Arena = Engine.require(tree.server.Arena.ArenaService)
local Data = Engine.require(tree.server.Services.PlayerDataService)

check("arena mode is on", Engine.workspace:GetAttribute("Arena") == true)
check(
	"arena map with spawn pads, board and a portal back",
	World.arena and #World.arena.spawns >= 8 and World.arena.board and World.arena.backPortal
)
check("no castles or dragon road in the arena", Engine.workspace:FindFirstChild("Bases") == nil)

local function join(name, id)
	local p = Engine.addPlayer(name, id)
	Engine.makeCharacter(p)
	Engine.advance(1)
	return p
end
local a = join("Ava", 2001)
local b = join("Ben", 2002)
check("profiles load", Data:Get(a) ~= nil and Data:Get(b) ~= nil)
local function weapon(p)
	for _, t in p.Character:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("Kind") == "bonk" then
			return t
		end
	end
	for _, t in p.Backpack:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("Kind") == "bonk" then
			return t
		end
	end
end
check("you get your weapon", weapon(a) ~= nil)
check("a shield after spawning", a.Character:FindFirstChild("SpawnShield") ~= nil)
check("KOs in the player list", a.leaderstats and a.leaderstats.KOs.Value == 0)
check("no bonking a shielded player", not Arena.bonk(a))
Engine.advance(Constants.ARENA_SPAWN_SAFE + 0.2)
-- face each other in the middle
Engine.moveTo(a, Vector3.new(0, 4.5, 10), Vector3.new(0, 4.5, 14))
Engine.moveTo(b, Vector3.new(0, 4.5, 14), Vector3.new(0, 4.5, 10))
Engine.advance(0.1)
check("bonk knocks them out", Arena.bonk(a))
check("a KO for the bonker", a.leaderstats.KOs.Value == 1 and (Data:Get(a).stats.arenaKOs or 0) == 1)
local ko = Engine.lastClientEvent("ArenaKO", b)
check("the bonked player is told who did it", ko and ko.args[1].by == "Ava")
check("no swing spam", not Arena.bonk(a))
local oldChar = b.Character
Engine.advance(Constants.ARENA_RESPAWN_SECONDS + 0.5)
check("they respawn", b.Character ~= nil and b.Character ~= oldChar, tostring(b.Character))
Arena.redraw()
check("TOP BONKERS board", World.arena.board.rows[1].name.Text == "Ava")

check("no script errors", #Engine.errors == 0, Engine.errors[1])
print(`{passed} passed, {failed} failed, {#Engine.errors} script errors, {#Engine.warnings} warnings`)
if failed > 0 or #Engine.errors > 0 then
	error("arena smoke test failed")
end
