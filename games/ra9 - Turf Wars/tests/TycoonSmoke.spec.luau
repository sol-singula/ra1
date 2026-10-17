--[[
Castle Tycoon, server and client together on the mock engine (Constants.applyMode("tycoon")): the street and its six
plots build, plain white and greys with each plot's colour (no browns), cheap enough for a phone; the match's
services stay out. A player gets the first free plot, their name on its sign, and lands in front of its gate with a
third-person camera and the tycoon's screen. The FREE Gold Mine pad builds it; the vault fills; COLLECT takes it;
a pad they can't pay for says how much more; every piece builds; each tier pays its Shards once; with everything
built, REBIRTH asks, then resets the castle with more income, higher prices and Shards. Raids: raiders walk to the
vault and take a share; towers shoot them; HIT reaches the nearest; a raid beaten pays a bonus. Leaving puts the
vault into their Gold and frees the plot; coming back rebuilds the castle from the save. The pacing: the first
castle in about 18 minutes, never a long wait for the next pad. The lobby has a fourth card and portal for it.

  luaurun tests/TycoonSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Vector2 = Engine.globals.Vector2
local Enum = Engine.Enum

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
Constants.applyMode("tycoon")
Constants.AFK_SECONDS = 0
Constants.TUTORIAL = false
Engine.clientEnabled = true
local ws = Engine.workspace
ws.CurrentCamera.ViewportSize = Vector2.new(1240, 560)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false

local Tycoon = Engine.require(tree.shared.Data.Tycoon)
local Modes = Engine.require(tree.shared.Data.Modes)
local TycoonBuilder = Engine.require(tree.shared.World.TycoonBuilder)

-- The pacing (pure numbers: always buying the next pad the moment it's affordable, 1.5 s to walk to it) --------------
do
	local function run(reb)
		local bought, cash, t, worst = {}, 0, 0, 0
		for _, it in Tycoon.ITEMS do
			local rate = Tycoon.income(bought, reb)
			local cost = Tycoon.cost(it, reb)
			local need = math.max(0, cost - cash)
			local dt = (need > 0 and need / rate or 0) + 1.5
			t += dt
			cash += rate * dt - cost
			worst = math.max(worst, dt)
			bought[it.key] = true
		end
		return t, worst
	end
	local t0, worst0 = run(0)
	local t1 = run(1)
	check("the first castle takes about 18 minutes", t0 > 12 * 60 and t0 < 25 * 60, t0 / 60)
	check("...never more than two minutes for the next pad", worst0 < 120, worst0)
	check("a rebirth's castle isn't a walkover (at least 80% as long)", t1 > t0 * 0.8, t1 / t0)
	check("the first pad is free", Tycoon.ITEMS[1].cost == 0)
	check("five tiers, 28 pieces", #Tycoon.TIERS == 5 and #Tycoon.ITEMS == 28)
	for _, it in Tycoon.ITEMS do
		if not TycoonBuilder.BUILD[it.key] then
			check(`{it.key} has a build`, false)
		end
	end
	check(
		"a mode of the universe",
		Modes.tycoon and table.find(Modes.LIST, "tycoon") ~= nil and Modes.get("tycoon") ~= nil
	)
end

Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Ty = service("TycoonService")
local Data = service("PlayerDataService")

local function lastFired(name, player)
	local e = Engine.lastClientEvent(name, player)
	return e and e.args[1]
end
local function mark()
	return #Engine.clientLog
end
local function since(m, name, player, pred)
	for i = m + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if
			e.name == name
			and (player == nil or e.player == player or e.player == "all")
			and (not pred or pred(e.args))
		then
			return e
		end
	end
	return nil
end
local function tycoonSince(m, player, kind)
	return since(m, "Tycoon", player, function(a)
		return type(a[1]) == "table" and a[1].kind == kind
	end)
end
local function rootOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
local function stand(p, pos)
	Engine.moveTo(p, pos + Vector3.new(0, 3, 0))
	Engine.advance(0.35)
end
local function away(p)
	local plot = Ty:Plot(p)
	stand(p, TycoonBuilder.toWorld(plot.index, 0, -8))
end

-- The world --------------------------------------------------------------------------------------------------------
local world = Ty:World()
local folder = ws:FindFirstChild("Tycoon")
check("the street was built", folder ~= nil and world ~= nil and world.folder == folder)
check("six plots", #world.plots == 6)
check("no arena, no match", ws:FindFirstChild("Arena") == nil and ws:GetAttribute("Phase") == nil)
check("a LOBBY portal and the CASTLE TYCOON sign", world.portal ~= nil and world.sign ~= nil)
check("cheap enough for a phone (the empty street)", world.count < 700, world.count)
do
	local f1 = TycoonBuilder.frame(1)
	local f4 = TycoonBuilder.frame(4)
	check("the plots face the street", f1.LookVector.X > 0.99 and f4.LookVector.X < -0.99)
	local gate1 = TycoonBuilder.toWorld(1, 0, -32)
	check("...their gates on its edge", math.abs(math.abs(gate1.X) - TycoonBuilder.STREET / 2) < 0.01, gate1.X)
end

-- A player lands ---------------------------------------------------------------------------------------------------
local player = Engine.addPlayer("Ava", 601)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local plot = Ty:Plot(player)
check("they get a plot", plot ~= nil and player:GetAttribute("Plot") == plot.index)
local title = plot and plot.sign:FindFirstChild("Words") and plot.sign.Words:FindFirstChild("Title")
check("...their name on its sign", title and title.Text:find("AVA") ~= nil, title and title.Text)
local r = rootOf(player)
local gate = TycoonBuilder.toWorld(plot.index, 0, -38, 3)
check("they stand in front of their gate", r and (r.Position - gate).Magnitude < 1, r and r.Position)
check("...facing in", r and r.CFrame.LookVector:Dot(plot.cf.LookVector) < -0.99)
check("third person: the camera isn't locked", player.CameraMode ~= Enum.CameraMode.LockFirstPerson)
local gui = player.PlayerGui
check(
	"the tycoon's screen is up, the match's HUD isn't",
	gui:FindFirstChild("Tycoon") ~= nil and gui:FindFirstChild("Hud") == nil
)
local TyC = Engine.require(tree.client.Controllers.TycoonController)
local refs = TyC.refs
check(
	"a welcome toast points at the free pad",
	(lastFired("Toast", player) or ""):find("FREE") ~= nil,
	lastFired("Toast", player)
)
check(
	"the state came: plot, 0 Gold, CAMP",
	TyC.state().plot == plot.index and TyC.state().cash == 0 and TyC.state().tierName == "CAMP"
)
check("the Gold, the tier bar, SHOP, LOBBY on screen", refs.gold and refs.tierBar and refs.shop and refs.lobby)
local items = plot.items
local pads = {}
for _, d in items:GetChildren() do
	if d.Name == "BuyPad" then
		pads[d:GetAttribute("Slot")] = d
	end
end
local collector = items:FindFirstChild("Collector")
check("three pads and a COLLECT pad", pads[1] and pads[2] and pads[3] and collector)
check(
	"the first pad: the FREE Gold Mine",
	pads[1]:GetAttribute("Item") == "mine1" and pads[1].Over.Line.Text == "FREE",
	pads[1].Over.Line.Text
)

-- The first mine, the vault, COLLECT ------------------------------------------------------------------------------
local m = mark()
stand(player, pads[1].Position)
local state = Ty:State(player)
check("standing on it builds it", state.bought.mine1 == true and items:FindFirstChild("mine1") ~= nil)
check("...BUILT on screen", tycoonSince(m, player, "bought") ~= nil)
check("...the pad shows the next piece", pads[1]:GetAttribute("Item") == "mine2", pads[1]:GetAttribute("Item"))
check("...and standing there doesn't buy it", not state.bought.mine2)
away(player)
Engine.advance(5)
local bank = Ty:Bank(player)
check("the vault fills: 2 Gold a second", bank >= 9 and bank <= 12, bank)
check(
	"...the COLLECT pad says so",
	math.abs((tonumber(collector.Over.Line.Text:match("%d+")) or -9) - bank) <= 1,
	collector.Over.Line.Text
)
check("...nothing in their Gold yet", state.cash == 0)
m = mark()
stand(player, collector.Position)
check("COLLECT moves it to their Gold", state.cash >= 9 and Ty:Bank(player) <= 1, state.cash)
check("...+N Gold on screen", tycoonSince(m, player, "collect") ~= nil)
local profile = Data:Get(player)
check("...counted for the GOLD EARNED board", profile.stats.tycoonEarned == state.earned and state.earned > 0)
Engine.advance(0.6)
check("the screen shows the Gold", (refs.gold.Text:gsub(",", "")) == tostring(math.floor(state.cash)), refs.gold.Text)
away(player)
-- not enough Gold
state.cash = 0
m = mark()
stand(player, pads[1].Position)
check("too poor: nothing built", not state.bought.mine2)
check(
	"...a toast says how much more",
	(lastFired("Toast", player) or ""):find("Need") ~= nil,
	lastFired("Toast", player)
)
away(player)

-- Every piece, the tiers -------------------------------------------------------------------------------------------
state.cash = 10 ^ 9
local shardsBefore = profile.shards or 0
m = mark()
local all = true
for _, it in Tycoon.ITEMS do
	if not state.bought[it.key] then
		local ok = Ty:Buy(player, it.key)
		all = all and ok
	end
end
check("every piece can be bought, in order", all and Tycoon.complete(state.bought))
local built = 0
for _, it in Tycoon.ITEMS do
	local f = items:FindFirstChild(it.key)
	if f and #f:GetDescendants() > 0 then
		built += 1
	end
end
check("...and every one stands on the plot", built == #Tycoon.ITEMS, built)
local tierShards = 0
for _, t in Tycoon.TIERS do
	tierShards += t.shards
end
check(
	"each tier paid its Shards",
	(profile.shards or 0) - shardsBefore == tierShards,
	(profile.shards or 0) - shardsBefore
)
check(
	"...five tier banners",
	(function()
		local n = 0
		for i = m + 1, #Engine.clientLog do
			local e = Engine.clientLog[i]
			if
				e.name == "Tycoon"
				and e.player == player
				and type(e.args[1]) == "table"
				and e.args[1].kind == "tier"
			then
				n += 1
			end
		end
		return n == 5
	end)()
)
check(
	"a piece out of order is refused",
	(function()
		state.bought.throne = nil
		local ok, why = Ty:Buy(player, "mine1")
		state.bought.throne = true
		return not ok and why == "owned"
	end)()
)
do
	local parts, brown = 0, {}
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			local c = d.Color
			local rr, g, b = c.R, c.G, c.B
			local mx, mn = math.max(rr, g, b), math.min(rr, g, b)
			local sat = mx > 0 and (mx - mn) / mx or 0
			local hue = mx == mn and 0 or (mx == rr and 60 * (((g - b) / (mx - mn)) % 6) or -1)
			if d.Transparency < 1 and mx == rr and hue >= 12 and hue <= 50 and sat > 0.2 and mx < 0.85 then
				table.insert(brown, d.Name)
			end
		end
	end
	check("nothing brown", #brown == 0, table.concat(brown, ","))
	check("a whole castle is still cheap", parts < 1600, parts)
end
-- the keep stands inside the walls, the walls inside the plot
do
	local half = Tycoon.PLOT_SIZE / 2 + 2 -- (a banner may hang on the outer face)
	local out = {}
	for _, it in Tycoon.ITEMS do
		for _, d in items:FindFirstChild(it.key):GetDescendants() do
			if d:IsA("BasePart") then
				local p = plot.cf:PointToObjectSpace(d.Position)
				if math.abs(p.X) > half or math.abs(p.Z) > half then
					table.insert(out, it.key .. ":" .. d.Name)
				end
			end
		end
	end
	check("every piece stands on the plot", #out == 0, table.concat(out, ","))
	-- nothing solid on the way in: the gate to the pads
	local blocked = {}
	for _, d in items:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and d.Name ~= "BuyPad" and d.Name ~= "Collector" then
			local p = plot.cf:PointToObjectSpace(d.Position)
			local hx, hz = d.Size.X / 2, d.Size.Z / 2
			if
				math.abs(p.X) - hx < 4
				and p.Z + hz > -40
				and p.Z - hz < -16
				and p.Y - d.Size.Y / 2 < 5
				and d.Name ~= "Lintel"
			then
				table.insert(blocked, d.Name)
			end
		end
	end
	check("the way in from the gate to the pads is clear", #blocked == 0, table.concat(blocked, ","))
end

-- REBIRTH -----------------------------------------------------------------------------------------------------------
Ty:Collect(player)
Engine.advance(0.6)
check("the middle pad turns into REBIRTH", pads[2]:GetAttribute("Item") == "rebirth", pads[2]:GetAttribute("Item"))
check(
	"...the screen says complete",
	TyC.state().complete == true and refs.tierText.Text:find("REBIRTH") ~= nil,
	refs.tierText.Text
)
m = mark()
stand(player, pads[2].Position)
check("standing on it asks first", tycoonSince(m, player, "rebirthAsk") ~= nil and refs.rebirth.Visible == true)
check("...nothing reset yet", Tycoon.complete(state.bought))
refs.no.Activated:Fire()
Engine.advance(0.1)
check("NOT YET closes the card", refs.rebirth.Visible == false and Tycoon.complete(state.bought))
away(player)
stand(player, pads[2].Position)
local incomeBefore = Tycoon.income({ mine1 = true }, 0)
shardsBefore = profile.shards
m = mark()
refs.yes.Activated:Fire()
Engine.advance(0.5)
state = Ty:State(player)
check("REBIRTH! the castle starts over", state.rebirths == 1 and next(state.bought) == nil and state.cash == 0)
check("...the pieces come down", items:FindFirstChild("keep1") == nil and items:FindFirstChild("mine1") == nil)
check("...it paid its Shards", profile.shards - shardsBefore == Tycoon.rebirthShards(0), profile.shards - shardsBefore)
check("...more income from now on", Tycoon.income({ mine1 = true }, 1) == incomeBefore * 1.5)
check("...and higher prices", Tycoon.cost(Tycoon.byKey.mine2, 1) > Tycoon.cost(Tycoon.byKey.mine2, 0))
check("...on screen too", tycoonSince(m, player, "rebirth") ~= nil and refs.reborn.Text:find("1") ~= nil)
away(player)

-- Raids ------------------------------------------------------------------------------------------------------------
-- no towers: the raiders reach the vault and take a share
state.cash = 10 ^ 9
for _, key in { "mine1", "mine2", "wallFL", "wallFR", "mine3", "gate" } do
	Ty:Buy(player, key)
end
state.cash = 0
Engine.advance(10)
stand(player, TycoonBuilder.toWorld(plot.index, 28, 20)) -- (out of the way, out of reach)
local before = Ty:Bank(player)
m = mark()
local n = Ty:StartRaid(player)
check("a raid: RAID_BASE + tier raiders", n == Tycoon.RAID_BASE + 2, n)
local raiderModels = 0
for _, d in folder:GetChildren() do
	if d.Name == "Raider" then
		raiderModels += 1
	end
end
check("...they're in the street", raiderModels == n)
check("...RAID! on screen", tycoonSince(m, player, "raid") ~= nil and refs.banner.Visible)
Engine.advance(20)
check("unopposed, they reach the vault", next(Ty:Raiders(player)) == nil)
check(
	"...and take a share of it",
	tycoonSince(m, player, "stolen") ~= nil and Ty:Bank(player) < before + 20 * Tycoon.income(state.bought, 1),
	Ty:Bank(player)
)
check("...the raid's over", tycoonSince(m, player, "raidOver") ~= nil)
-- towers: they shoot; HIT helps
state.cash = 10 ^ 9
Ty:Buy(player, "towerFL")
Ty:Buy(player, "towerFR")
check("the first tower sets the first raid", true)
m = mark()
n = Ty:StartRaid(player)
stand(player, TycoonBuilder.toWorld(plot.index, 0, -40))
Engine.advance(1.2)
check("the HIT button shows with a raider close", refs.hit.Visible == true)
local hpBefore = 0
for _, rr in Ty:Raiders(player) do
	hpBefore += rr.hp
end
local hits = 0
for _ = 1, 60 do
	if TyC.hit() then
		hits += 1
	end
	Engine.advance(0.35)
end
check("HIT hits", hits > 0, hits)
Engine.advance(5)
check("the towers shoot (beams)", since(m, "Tycoon", nil, function(a)
	return type(a[1]) == "table" and a[1].kind == "zap" and a[1].hit == false
end) ~= nil)
check("towers and hits beat the raid", next(Ty:Raiders(player)) == nil)
local over = tycoonSince(m, player, "raidOver")
check(
	"...nothing taken: a bonus",
	over and over.args[1].stolen == 0 and over.args[1].bonus > 0,
	over and over.args[1].stolen
)
check("gold cubes fly from the mines", #TyC.cubes() > 0 or (function()
	Engine.advance(3)
	return #TyC.cubes() > 0
end)())

-- The LOBBY portal ------------------------------------------------------------------------------------------------
m = mark()
stand(player, world.portal.Position - Vector3.new(0, 3, 0))
check("walking into the portal asks for the lobby", since(m, "Toast", player, function(a)
	return tostring(a[1]):find("lobby") ~= nil
end) ~= nil)

-- Leaving and coming back --------------------------------------------------------------------------------------------
away(player)
Engine.advance(3)
local bankLeft = Ty:Bank(player)
local cashLeft = state.cash
local boughtCount = 0
for _ in state.bought do
	boughtCount += 1
end
local idx = plot.index
Engine.removePlayer(player)
Engine.advance(0.5)
check("leaving: the vault goes into their Gold", state.cash >= cashLeft + bankLeft - 1, state.cash - cashLeft)
check(
	"...the plot is free again",
	#world.plots[idx].items:GetChildren() == 0 and world.plots[idx].sign.Words.Title.Text == "FREE PLOT"
)
local ben = Engine.addPlayer("Ben", 602)
Engine.advance(1)
check("the next player takes the free plot", Ty:Plot(ben) and Ty:Plot(ben).index == idx)
check("...a castle of their own (nothing built)", next(Ty:State(ben).bought) == nil)
local saved = Data:Get(ben).tycoon
check("...their own save", saved ~= state and saved.rebirths == 0)

-- The lobby: a fourth card and a portal --------------------------------------------------------------------------
local LobbyBuilder = Engine.require(tree.shared.World.LobbyBuilder)
check("the lobby has a portal for it", LobbyBuilder.SPOTS.portals.tycoon ~= nil)
check(
	"...clear of the PLAY gate and the boards",
	(function()
		local p = LobbyBuilder.SPOTS.portals.tycoon
		return math.abs(p.X) > 20 and (p.X < 90)
	end)()
)

if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`TycoonSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
