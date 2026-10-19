--[[
The build pads: eight in the yard by the spawn, the guide's upgrade on the first; walking onto one buys it,
standing on it buys the next level, stepping off and on buys again, and the pads repaint when you can (or can't)
afford them.

  luaurun tests/PadSmoke.spec.luau
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
local Data = service("PlayerDataService")
local Pads = service("PadService")
local Territory = service("TerritoryService")
local Tasks = service("TaskService")
local Layout = Engine.require(tree.shared.World.Layout)
local TasksData = Engine.require(tree.shared.Data.Tasks)

local player = Engine.addPlayer("Pip", 4401)
Engine.advance(3)
local p = Data:Get(player)
local t = Territory:Territory(player)
check("the player has a farm", p ~= nil and t ~= nil)
local folder = t.model:FindFirstChild("Pads")
check("the pads are built", folder ~= nil and folder:FindFirstChild("Pad1") ~= nil)
local count = 0
for _, m in folder and folder:GetChildren() or {} do
	if m:FindFirstChild("Pad") then
		count += 1
	end
end
check("...several of them", count >= 3, count)

-- Jump the tutorial to "buy 4 more tiles": that upgrade goes on pad 1, gold
local stepIndex
for k, s in TasksData.ONBOARDING do
	if s.key == "tiles1" then
		stepIndex = k
	end
end
p.task.step = stepIndex
p.cash = 0
Engine.advance(2.5)
check("the guide's upgrade is on pad 1", Pads:Shown(player)[1] == "tiles", Pads:Shown(player)[1])
local pad1 = folder:FindFirstChild("Pad1")
check("...gold (recommended)", pad1 and pad1:GetAttribute("Recommended") == true)
check("...not affordable yet", pad1 and pad1:GetAttribute("Affordable") == false)
check("...its sign names it and its price", pad1 and pad1.Pad.Tag.Card.Price.Text:find("%$") ~= nil)
service("EconomyService"):Add(player, 1000000, "test")
Engine.advance(0.6)
check("the pads repaint when you can afford them", pad1:GetAttribute("Affordable") == true)

-- Walk onto it
local spot = Layout.PADS[1]
local before = p.owned.tiles or 0
Engine.moveTo(player, Layout.toWorld(t.index, spot.x, spot.z, 3))
Engine.advance(0.6)
check("stepping on the pad buys it", (p.owned.tiles or 0) == before + 1, p.owned.tiles)
check("...the tutorial moved on", Tasks:Primary(player).key ~= "tiles1", Tasks:Primary(player).key)
-- Standing on: only the same thing again (the guide moved pad 1 on to the next step: no surprise buys)
local snap = {}
for k, v in p.owned do
	snap[k] = v
end
Engine.advance(1.6)
local surprise = {}
for k, v in p.owned do
	if v ~= (snap[k] or 0) and k ~= "tiles" then
		table.insert(surprise, k)
	end
end
check("standing still never buys a different upgrade", #surprise == 0, table.concat(surprise, ","))
-- Off and on again
Engine.moveTo(player, Layout.toWorld(t.index, Layout.SPOTS.spawn.x, Layout.SPOTS.spawn.z, 3))
Engine.advance(0.6)
local key2 = Pads:Shown(player)[2]
local l2 = key2 and p.owned[key2] or 0
local spot2 = Layout.PADS[2]
Engine.moveTo(player, Layout.toWorld(t.index, spot2.x, spot2.z, 3))
Engine.advance(0.6)
check("stepping onto another pad buys that one", key2 ~= nil and (p.owned[key2] or 0) > l2, tostring(key2))
-- Nobody else's pads buy for you
local other = Engine.addPlayer("Wren", 4402)
Engine.advance(3)
local p2 = Data:Get(other)
p2.cash = 1000000
local spent = 0
for _ in p2.owned do
	spent += 1
end
Engine.moveTo(other, Layout.toWorld(t.index, spot.x, spot.z, 3))
Engine.advance(1)
local after = 0
for _ in p2.owned do
	after += 1
end
check("another farm's pads do nothing for a visitor", after == spent and p2.cash == 1000000, p2.cash)

if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`PadSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
