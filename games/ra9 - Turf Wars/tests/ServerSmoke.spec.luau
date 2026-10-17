--[[
Server smoke test: boots the real server on the mock engine and plays a match: four players join (two of them
friends), teams balance with the friends together, the build phase (valid and refused placements, budgets, the
lane rule), the fight (a timed draw, a server arrow, a hit, a kill, the frontline moving, assists, friendly fire,
spawn protection, knockback), the turf rule, structures taking arrows, the crossbow's magazine, a team pushed out,
the results, a qualifying win on the ladder, and the next map loading in the same server.

  luaurun tests/ServerSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local Enum = Engine.Enum
local CFrame = Engine.CFrame
local Instance = Engine.Instance

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
Engine.require(tree.shared.Constants).TUTORIAL = false -- (the players here know the game: tests/TutorialSmoke is the tutorial's)
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
local AC = service("AntiCheatService")
local acFlags = {} -- every flag the anti-cheat raises during the whole run: { player, kind, detail }
AC.Flagged:Connect(function(player, kind, detail)
	table.insert(acFlags, { player = player, kind = kind, detail = detail })
end)
local Teams = service("TeamService")
local Arena = service("ArenaService")
local Combat = service("CombatService")
local Build = service("BuildService")
local Match = service("MatchService")
local Progress = service("ProgressService")
local Constants = Engine.require(tree.shared.Constants)
local Formulas = Engine.require(tree.shared.Formulas)
local Weapons = Engine.require(tree.shared.Data.Weapons)
local ws = Engine.workspace

local function lastFired(name, player)
	local e = Engine.lastClientEvent(name, player)
	return e and e.args[1]
end
local function mark()
	return #Engine.clientLog
end
local function firedSince(m, name, player, pred)
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
local function send(player, name, ...)
	Engine.fireServer(player, name, ...)
	Engine.advance(0.05)
end
local function rootOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
end
local function stand(p, pos, look)
	Engine.moveTo(p, pos, look)
	Engine.advance(0.05)
end
-- shoot from where you stand at a point, after drawing for `draw` seconds
local function shootAt(p, target, draw)
	send(p, "Draw", true)
	Engine.advance(draw or 1)
	local r = rootOf(p)
	local origin = r.Position + Vector3.new(0, 1.5, 0)
	send(p, "Shoot", origin, (target - origin).Unit, 1)
	Engine.advance(0.6)
end

-- The arena and the first match ---------------------------------------------------------------------------------
check("an arena was built", ws:FindFirstChild("Arena") ~= nil)
check("the first map is Castle Clash", ws:GetAttribute("MapKey") == "castle")
do
	-- a place made from Roblox's Baseplate template: its baseplate and spawn go
	local bp = Instance.new("Part")
	bp.Name = "Baseplate"
	bp.Parent = ws
	local sl = Instance.new("SpawnLocation")
	sl.Parent = ws
	Arena:ClearTemplate()
	check("no template baseplate or spawn", ws:FindFirstChild("Baseplate") == nil and sl.Parent == nil)
	check("...the arena stays", ws:FindFirstChild("Arena") ~= nil)
end
check("the match opens in the build phase", ws:GetAttribute("Phase") == "build")
check("the frontline starts in the middle", ws:GetAttribute("Frontline") == 0)
check(
	"the turf is painted: red west, blue east",
	(function()
		local a = Arena:Current()
		return a.strips[1].Color == Constants.TURF_COLOR.red and a.strips[#a.strips].Color ~= Constants.TURF_COLOR.red
	end)()
)
check("Red and Blue teams exist", Engine.game:GetService("Teams"):FindFirstChild("RED") ~= nil)

-- Four players join; Ava and Ben are friends --------------------------------------------------------------------
Engine.friends["501:502"], Engine.friends["502:501"] = true, true -- (friends before they join)
-- (one at a time: Ava and Cy split, Ben joins the even teams with the turf even: his friend's side; Dee the smaller)
local ava = Engine.addPlayer("Ava", 501)
local cy = Engine.addPlayer("Cy", 503)
Engine.advance(1)
send(ava, "Ready")
send(cy, "Ready")
Engine.advance(0.5)
check("two players: one each", Teams:Team(ava) and Teams:Team(cy) and Teams:Team(ava) ~= Teams:Team(cy))
local ben = Engine.addPlayer("Ben", 502)
Engine.advance(0.3)
send(ben, "Ready")
Engine.advance(0.3)
local dee = Engine.addPlayer("Dee", 504)
Engine.advance(0.3)
send(dee, "Ready")
Engine.advance(0.5)
check("everyone has a team", Teams:Team(ava) and Teams:Team(ben) and Teams:Team(cy) and Teams:Team(dee))
check(
	"even teams, even turf: a friend joins his friend",
	Teams:Team(ava) == Teams:Team(ben),
	`{Teams:Team(ava)} {Teams:Team(ben)}`
)
check("the odd one out joins the smaller team", Teams:Team(dee) == Teams:Team(cy))
check("teams are even", Teams:Count("red") == 2 and Teams:Count("blue") == 2)
local red = Teams:Team(ava) == "red" and ava or cy
local red2 = red == ava and ben or dee
local blue = Teams:Team(ava) == "red" and cy or ava
local blue2 = blue == ava and ben or dee
check("everyone spawned alive", Combat:Alive(ava) and Combat:Alive(cy))
do
	local d = ava.Character:FindFirstChildOfClass("Humanoid"):GetAppliedDescription()
	check(
		"everyone has the same plain R15 body (standard size, no packages)",
		d.HeightScale == 1 and d.WidthScale == 1 and d.BodyTypeScale == 0 and d.Torso == 0 and d.Head == 0
	)
end
do
	local r = rootOf(red)
	check("red spawns at the west end", r and r.Position.X < -70, r and r.Position.X)
	check("blue spawns at the east end", rootOf(blue).Position.X > 70)
	local arm = red.Character:FindFirstChild("RightUpperArm") or red.Character:FindFirstChild("Head")
	check("players are mannequins in their team's colour", arm and arm.Color == Constants.TEAM_COLOR.red)
end
check("the client got the match", lastFired("Match", red) ~= nil and lastFired("Match", red).phase == "build")

-- The build phase ---------------------------------------------------------------------------------------------
stand(red, Vector3.new(-40, 3, -12))
local m0 = mark()
local cx, cz = Formulas.cellOf(-44, -28)
local ok, s = Build:Place(red, "wall", cx, cz, 0)
check("a wall on your own turf is built", ok == true, s)
check("...in your team's colour", ok and s.model and s.model:GetAttribute("Team") == Teams:Team(red))
check("...everyone is told", firedSince(m0, "Structure", nil) ~= nil)
check("...and it cost its points", Build:Budget(red) == Constants.BUILD_BUDGET - 10, Build:Budget(red))
local ok2, why2 = Build:Place(red, "wall", cx, cz, 0)
check("not on top of another", not ok2 and why2 ~= nil, why2)
local ex = Formulas.cellOf(12, 0)
local ok3, why3 = Build:Place(red, "cover", ex, Formulas.cellOf(0, -12) and select(2, Formulas.cellOf(0, -12)), 0)
check("not on enemy turf", not ok3 and why3 and why3:find("turf") ~= nil, why3)
local farX = Formulas.cellOf(-76, 0)
local ok4, why4 = Build:Place(red, "cover", farX, 4, 0)
check("not out of reach", not ok4, why4)
stand(red, Vector3.new(-48, 3, -30))
local ok5, why5 = Build:Place(red, "cover", Formulas.cellOf(-58, -38), select(2, Formulas.cellOf(-58, -38)), 0)
check("not on the map's own walls", not ok5 and why5 ~= nil, why5)
do
	-- right up to the line: the cell touching it is yours to build on (and the cell against the long wall)
	local F = ws:GetAttribute("Frontline")
	local side = Teams:Team(red) == "red" and -1 or 1
	stand(red, Vector3.new(F + side * 10, 3, 14))
	Build:Refill()
	local lx, lz = Formulas.cellOf(F + side * 2, 14)
	local okL, whyL = Build:Place(red, "cover", lx, lz, 0)
	check("you can build in the cell touching the line", okL == true, whyL)
	stand(red, Vector3.new(F + side * 14, 3, -40))
	local wx, wz = Formulas.cellOf(F + side * 14, -47)
	local okW, whyW = Build:Place(red, "cover", wx, wz, 0)
	check("...and in the cell against the long wall", okW == true, whyW)
	Build:Refill()
end
-- the lane rule: wall a whole row and the last openings are refused
do
	stand(red2, Vector3.new(-40, 3, 0))
	local col = Formulas.cellOf(-38, 0)
	local refused
	local _, z0 = Formulas.cellOf(0, -47)
	local _, z1 = Formulas.cellOf(0, 47)
	Build:Refill()
	for z = z0, z1 do
		stand(red2, Vector3.new(-40, 3, z * Constants.CELL))
		local okW, whyW = Build:Place(red2, "reinforced", col, z, 1)
		if not okW and whyW and whyW:find("wall off") then
			refused = true
			break
		end
		if Build:Budget(red2) < 22 then
			Build:Refill()
		end
	end
	check("no wall ever seals the whole field", refused == true)
end
check("the budget is spent per player", Build:Budget(blue) == Constants.BUILD_BUDGET)
local okB, whyB = Build:Place(blue, "tower", Formulas.cellOf(30, 0), 2, 0)
check("blue can't build beside the line from spawn (reach)", not okB, whyB)

-- The fight -----------------------------------------------------------------------------------------------------
check(
	"no damage in the build phase",
	(function()
		stand(red, Vector3.new(-10, 3, -12))
		stand(blue, Vector3.new(10, 3, -12))
		shootAt(red, rootOf(blue).Position, 1)
		return Combat:Health(blue) == Constants.MAX_HEALTH
	end)()
)
Engine.advance(Constants.BUILD_SECONDS + 0.5)
check("the horn: the fight is on", ws:GetAttribute("Phase") == "fight", ws:GetAttribute("Phase"))
check("building is closed in the fight", not Build:Place(red, "cover", Formulas.cellOf(-36, 0), 1, 0))
-- protection wears off (they spawned a while ago); a tap does some damage, not a kill
stand(red, Vector3.new(-10, 3, -12), Vector3.new(10, 3, -12))
stand(blue, Vector3.new(10, 3, -12), Vector3.new(-10, 3, -12))
local m1 = mark()
send(red, "Draw", true)
Engine.advance(0.05)
send(red, "Shoot", rootOf(red).Position + Vector3.new(0, 1.5, 0), Vector3.new(1, 0, 0), 7)
Engine.advance(0.6)
check("everyone sees the arrow", firedSince(m1, "Arrow", nil) ~= nil)
local hp = Combat:Health(blue)
check("a tap hits for part of a life", hp < Constants.MAX_HEALTH and hp > 0, hp)
check("the shooter gets a hit marker", firedSince(m1, "Hit", red) ~= nil)
check("the victim is told where it came from", firedSince(m1, "Hurt", blue) ~= nil)
-- an assist first: red2 chips blue, then red finishes with a full draw
send(red2, "Equip", "crossbow") -- (34 a bolt: with the tap's 51, not yet a kill)
stand(red2, Vector3.new(-12, 3, -16), Vector3.new(10, 3, -12))
shootAt(red2, rootOf(blue).Position + Vector3.new(0, 0.2, 0), 0.1)
check("two hits, still standing", Combat:Alive(blue) and Combat:Health(blue) < 30, Combat:Health(blue))
local before = ws:GetAttribute("Frontline")
local m2 = mark()
shootAt(red, rootOf(blue).Position + Vector3.new(0, 0.2, 0), 1)
check("a full draw kills", not Combat:Alive(blue), Combat:Health(blue))
local push = Formulas.pushCells(4) * Constants.CELL
check(
	"the kill pushes the frontline toward blue",
	ws:GetAttribute("Frontline") == before + push,
	ws:GetAttribute("Frontline")
)
check(
	"...and repaints the turf",
	(function()
		local a = Arena:Current()
		local i = math.floor((before + push / 2 + a.half) / Constants.CELL) + 1
		return a.strips[i].Color ~= Constants.TURF_COLOR.blue
	end)()
)
local feed = firedSince(m2, "Kill", nil)
check("the kill feed says who and how far", feed and feed.args[1].killer == red.UserId and feed.args[1].push == push)
check("the kill counts", Match:Stats(red).kills == 1)
check("the helper gets an assist", Match:Stats(red2).assists == 1, Match:Stats(red2).assists)
do
	-- a fifth player joins two against two: the team losing on turf (blue, pushed back) gets them
	local eve = Engine.addPlayer("Eve", 505)
	Engine.advance(0.3)
	send(eve, "Ready")
	Engine.advance(0.3)
	check("even teams: a newcomer joins the losing team", Teams:Team(eve) == "blue", Teams:Team(eve))
	Engine.removePlayer(eve)
	Engine.advance(0.3)
end
Engine.advance(Constants.RESPAWN_SECONDS + 0.4)
check("blue respawns", Combat:Alive(blue))
check(
	"...protected for a moment",
	(function()
		local h = Combat:Health(blue)
		stand(red, Vector3.new(60, 3, -12))
		return h == Constants.MAX_HEALTH
	end)()
)
-- friendly fire
stand(red, Vector3.new(-10, 3, -12), Vector3.new(-6, 3, -12))
stand(red2, Vector3.new(-4, 3, -12))
shootAt(red, rootOf(red2).Position, 1)
check("no friendly fire", Combat:Health(red2) == Constants.MAX_HEALTH, Combat:Health(red2))
-- the blade: up close, in front, on its cadence; more from behind
do
	local blade = Weapons.get("blade")
	local F = ws:GetAttribute("Frontline")
	send(red, "Equip", "blade")
	Engine.advance(Constants.SPAWN_PROTECT)
	check("the blade in hand", Combat:Weapon(red) == "blade")
	stand(blue, Vector3.new(F + 2.5, 3, 30), Vector3.new(F - 10, 3, 30))
	stand(red, Vector3.new(F - 2.5, 3, 30), Vector3.new(F + 10, 3, 30))
	local h0 = Combat:Health(blue)
	local m = mark()
	send(red, "Swing", Vector3.new(1, 0, 0))
	check("a slash hits who's in front, in reach", Combat:Health(blue) == h0 - blade.damage[1], Combat:Health(blue))
	check("...and everyone sees it", firedSince(m, "Swing", nil) ~= nil)
	local h1 = Combat:Health(blue)
	send(red, "Swing", Vector3.new(1, 0, 0))
	check("...not faster than the blade swings", Combat:Health(blue) == h1, Combat:Health(blue))
	Engine.advance(blade.cooldown)
	send(red, "Swing", Vector3.new(-1, 0, 0))
	check("...not who's behind you", Combat:Health(blue) == h1, Combat:Health(blue))
	Engine.advance(blade.cooldown)
	stand(red, Vector3.new(F - 14, 3, 30), Vector3.new(F + 10, 3, 30))
	send(red, "Swing", Vector3.new(1, 0, 0))
	check("...not out of reach", Combat:Health(blue) == h1, Combat:Health(blue))
	Engine.advance(blade.cooldown)
	-- from behind: blue looks away
	stand(blue, Vector3.new(F + 2.5, 3, 30), Vector3.new(F + 20, 3, 30))
	stand(red, Vector3.new(F - 2, 3, 30), Vector3.new(F + 10, 3, 30))
	send(red, "Swing", Vector3.new(1, 0, 0))
	local back = math.floor(blade.damage[1] * blade.backstab + 0.5)
	check("from behind it hits harder", Combat:Health(blue) == h1 - back, Combat:Health(blue))
	Combat:Spawned(blue) -- (whole again for what follows)
	send(red, "Equip", "bow")
end
-- the turf rule: red can't walk onto blue's turf
stand(red, Vector3.new(ws:GetAttribute("Frontline") + 10, 3, 20))
Engine.advance(0.4)
check(
	"stepping over the line puts you back",
	rootOf(red).Position.X <= ws:GetAttribute("Frontline"),
	rootOf(red).Position.X
)
-- arrows break structures: blue's heavy bow at red's wall
do
	local wall
	for _, st in Build:All() do
		if st.team == Teams:Team(red) and st.key == "wall" then
			wall = st
			break
		end
	end
	send(blue, "Equip", "heavy")
	Engine.advance(Constants.SPAWN_PROTECT)
	local target = (wall.boxMin + wall.boxMax) / 2
	stand(blue, Vector3.new(ws:GetAttribute("Frontline") + 6, 3, target.Z), target)
	local hp0 = wall.hp
	shootAt(blue, target, 1.6)
	check("an arrow chips a structure", wall.hp < hp0 or Build:All()[wall.id] == nil, wall.hp)
	for _ = 1, 4 do
		shootAt(blue, target, 1.6)
	end
	check("...and the heavy bow breaks it", Build:All()[wall.id] == nil)
end
-- the crossbow: a magazine and a reload
send(blue2, "Equip", "crossbow")
local cb = Weapons.get("crossbow")
stand(blue2, Vector3.new(ws:GetAttribute("Frontline") + 8, 3, 40), Vector3.new(0, 3, 40))
local m3 = mark()
for _ = 1, cb.mag + 2 do
	send(blue2, "Shoot", rootOf(blue2).Position + Vector3.new(0, 1.5, 0), Vector3.new(-1, 0, 0), 2)
	Engine.advance(cb.cooldown + 0.02)
end
local n = 0
for i = m3 + 1, #Engine.clientLog do
	local e = Engine.clientLog[i]
	if e.name == "Arrow" and e.args[1].by == blue2.UserId then
		n += 1
	end
end
check("the crossbow fires its magazine, then has to reload", n == cb.mag, n)
Engine.advance(cb.reload + 0.2)
check("...and refills", lastFired("Me", blue2).ammo == cb.mag)

-- Pushing a team out -------------------------------------------------------------------------------------------
Engine.advance(30) -- (well past the qualifying time by the end)
local m4 = mark()
for _ = 1, 120 do
	if ws:GetAttribute("Phase") ~= "fight" then
		if ws:GetAttribute("Phase") == "build" then
			Engine.advance(Constants.BUILD_SECONDS + 0.3)
		else
			break
		end
	end
	if not Combat:Alive(blue) then
		Engine.advance(Constants.RESPAWN_SECONDS + Constants.SPAWN_PROTECT + 0.3)
	end
	local f = ws:GetAttribute("Frontline")
	stand(blue, Vector3.new(f + 3, 3, -27), Vector3.new(f - 3, 3, -27))
	stand(red, Vector3.new(f - 3, 3, -27), Vector3.new(f + 3, 3, -27))
	if Combat:Alive(blue) and Combat:Alive(red) then
		shootAt(red, rootOf(blue).Position + Vector3.new(0, 0.2, 0), 1)
	else
		Engine.advance(0.5)
	end
end
check("red pushed blue out: red wins", firedSince(m4, "Results", red) ~= nil, ws:GetAttribute("Frontline"))
local results = lastFired("Results", red)
check("the results list everyone, best first", results and #results.rows == 4)
check("an MVP is named", results and results.mvp ~= nil)
check(
	"the winner's win qualified",
	results and results.you.won and results.you.qualified,
	results and tostring(results.you.qualified)
)
check("...the ladder's first step unlocked", Data:Get(red).wins == 1 and lastFired("Unlock", red) ~= nil)
check("the losers' streak is zero", Data:Get(blue).streak == 0 and Data:Get(blue).stats.losses == 1)
check("the next map is named in the results", results and results.next and results.next.key ~= "castle")
check("combat stops at the victory", ws:GetAttribute("Phase") == "victory")
check("the winner is known to everyone (fireworks)", ws:GetAttribute("Winner") == Teams:Team(red))
check("a banner for everyone: who won", firedSince(m4, "Announce", nil, function(a)
	return a[1].kind == "win" and a[1].text:find("wins") ~= nil
end) ~= nil)
check("...and who was MVP", firedSince(m4, "Announce", nil, function(a)
	return a[1].kind == "status" and a[1].text:find("MVP") ~= nil
end) ~= nil)
check(
	"a 30 s countdown to the next game",
	math.abs(ws:GetAttribute("PhaseEnds") - Engine.workspace:GetServerTimeNow() - 30) < 1,
	ws:GetAttribute("PhaseEnds") - Engine.workspace:GetServerTimeNow()
)
do
	-- the wait for the next game: nobody stays dead, and anyone can run anywhere (no turf rule)
	Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
	check("dead at the win: back up to run about", Combat:Alive(blue), Combat:Alive(blue))
	local enemySide = Teams:Team(blue) == "blue" and -60 or 60
	stand(blue, Vector3.new(enemySide, 3, 10))
	Engine.advance(0.4)
	check(
		"...and free to walk onto the other team's side",
		math.abs(rootOf(blue).Position.X - enemySide) < 2,
		rootOf(blue).Position.X
	)
end
local mAsk = mark()
Engine.advance(Constants.FEEDBACK_ASK_DELAY + 0.3)
local ask = firedSince(mAsk, "Ask", red)
check("the winners are asked if they like the game", ask and ask.args[1].kind == "enjoy")
check("...the losers aren't", firedSince(mAsk, "Ask", blue) == nil)
local mThanks = mark()
send(red, "Feedback", "enjoy", true)
check("the answer is kept", Data:Get(red).feedback.answer == true and Data:Get(red).feedback.pendingLike == true)
local thanks = firedSince(mThanks, "Unlock", red)
check(
	"answering gives the Thank-You Trail",
	Data:Get(red).extras.thanks == true and Data:Get(red).equipped.trail == "extra_thanks"
)
check(
	"...with a THANK YOU card",
	thanks and thanks.args[1].extra == true and thanks.args[1].step.key == "extra_thanks",
	thanks and thanks.args[1].title
)
check(
	"...and it can be equipped again later (an owned extra)",
	(function()
		Data:Get(red).equipped.trail = nil
		send(red, "Settings", "equip", { kind = "trail", key = "extra_thanks" })
		return Data:Get(red).equipped.trail == "extra_thanks"
	end)()
)
check(
	"...but nobody else can equip it",
	(function()
		send(blue, "Settings", "equip", { kind = "trail", key = "extra_thanks" })
		return Data:Get(blue).equipped.trail ~= "extra_thanks"
	end)()
)
Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1)
check("the next map loads in the same server", ws:GetAttribute("MapKey") == results.next.key, ws:GetAttribute("MapKey"))
check("...the frontline resets", ws:GetAttribute("Frontline") == 0)
check("...structures are gone", next(Build:All()) == nil)
check("...a new build phase", ws:GetAttribute("Phase") == "build")
check("...everyone is back on a pad", Combat:Alive(red) and Combat:Alive(blue) and rootOf(red).Position.X < -70)
check("...budgets are full", Build:Budget(red) == Constants.BUILD_BUDGET)
check("only one Arena exists", #(function()
	local out = {}
	for _, c in ws:GetChildren() do
		if c.Name == "Arena" then
			table.insert(out, c)
		end
	end
	return out
end)() == 1)

-- Leaving and joining mid-match --------------------------------------------------------------------------------
Engine.removePlayer(dee)
Engine.advance(0.5)
local eve = Engine.addPlayer("Eve", 505)
Engine.advance(1)
send(eve, "Ready")
Engine.advance(0.5)
check(
	"a newcomer joins the smaller side",
	Teams:Count("red") == Teams:Count("blue"),
	`{Teams:Count("red")} {Teams:Count("blue")}`
)
check("...and spawns right away", Combat:Alive(eve))

-- A fall out of the world: no credit, no push ------------------------------------------------------------------
Engine.advance(Constants.BUILD_SECONDS + 0.5)
local f0 = ws:GetAttribute("Frontline")
stand(red, Vector3.new(-30, -40, 0))
Engine.advance(0.5)
check("falling below the map kills", not Combat:Alive(red))
check("...and pushes nothing", ws:GetAttribute("Frontline") == f0)

-- The winners' next win: a like is asked for (once); a third win the same day asks nothing ------------------------
do
	Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1)
	local mine = Teams:Team(red)
	local m5 = mark()
	Match:Victory(mine)
	Engine.advance(Constants.FEEDBACK_ASK_DELAY + 0.3)
	local a = firedSince(m5, "Ask", red)
	check("their next win asks for a like", a and a.args[1].kind == "like", a and a.args[1].kind)
	local mLike = mark()
	send(red, "Feedback", "like", "ok")
	check("...and remembers it", Data:Get(red).feedback.likeAnswer == "ok")
	check("...with no reward for it (only answering the question is thanked)", firedSince(mLike, "Unlock", red) == nil)
	Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1)
	local m6 = mark()
	Match:Victory(mine)
	Engine.advance(Constants.FEEDBACK_ASK_DELAY + 0.3)
	check("a third win the same day asks nothing", firedSince(m6, "Ask", red) == nil)
	check(
		"an answer to a card you weren't shown is ignored",
		not service("FeedbackService"):Answer(red, "enjoy", false)
	)
	check("the thank-you is given once only", not service("FeedbackService"):Thank(red))
	-- a NO is thanked the same as a YES
	local nay = service("FeedbackService")
	nay:Ask(blue, "enjoy")
	send(blue, "Feedback", "enjoy", false)
	check("a NO gets the Thank-You Trail too", Data:Get(blue).extras.thanks == true)
	-- the trail rides on their arrows
	Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + Constants.BUILD_SECONDS + 1.5)
	local m7 = mark()
	send(
		red,
		"Shoot",
		rootOf(red).Position + Vector3.new(0, 1.5, 0),
		Vector3.new(Teams:Team(red) == "red" and 1 or -1, 0, 0),
		99
	)
	local shotSeen = firedSince(m7, "Arrow", nil)
	check(
		"everyone sees the trail they wear on their arrows",
		shotSeen and shotSeen.args[1].trail == "extra_thanks",
		shotSeen and tostring(shotSeen.args[1].trail) or ws:GetAttribute("Phase")
	)
end

-- Invite a friend: both get the Buddy Trail ----------------------------------------------------------------------
do
	local Invite = service("InviteService")
	local function join(name, id, launch)
		local m = mark()
		local p = Engine.addPlayer(name, id, launch)
		Engine.advance(1)
		send(p, "Ready")
		Engine.advance(0.5)
		return p, m
	end
	local function card(m, p)
		local u = firedSince(m, "Unlock", p)
		return u and u.args[1] or {}
	end
	local hostCount = Data:Get(red).invite.count
	Engine.friends["7001:" .. red.UserId] = true
	local mHost = mark()
	local pal, mPal = join("Pal", 7001, "i:" .. red.UserId)
	check(
		"a friend who joins from your invite gets the Buddy Trail",
		Data:Get(pal).extras.buddy == true and Data:Get(pal).equipped.trail == "extra_buddy"
	)
	check(
		"...with a card saying who invited them",
		card(mPal, pal).title == "A FRIEND INVITED YOU!",
		card(mPal, pal).line
	)
	check("...and so do you", Data:Get(red).extras.buddy == true and Data:Get(red).invite.count == hostCount + 1)
	check(
		"...with a card naming the friend",
		card(mHost, red).title == "FRIEND JOINED!" and tostring(card(mHost, red).line):find("Pal") ~= nil,
		card(mHost, red).line
	)
	Engine.removePlayer(pal)
	Engine.advance(1)
	local mAgain = mark()
	local pal2 = join("Pal", 7001, "i:" .. red.UserId)
	check(
		"joining from an invite again gives nothing more",
		Data:Get(red).invite.count == hostCount + 1 and firedSince(mAgain, "Unlock", red) == nil
	)
	Engine.removePlayer(pal2)
	local stranger = join("Stranger", 7002, "i:" .. red.UserId)
	check("someone who isn't your friend doesn't count", Data:Get(stranger).extras.buddy == nil)
	Engine.removePlayer(stranger)
	local me = join("Selfie", 7003, "i:7003")
	check("nor does inviting yourself", Data:Get(me).extras.buddy == nil and Data:Get(me).invite.by == nil)
	Engine.removePlayer(me)
	-- the inviter wasn't in this server: their credit waits and comes when they join
	Engine.friends["7004:7005"] = true
	local late = join("Late", 7004, "i:7005")
	check("a friend gets the trail even when you're in another server", Data:Get(late).extras.buddy == true)
	local mHost2 = mark()
	local host2 = join("Host", 7005)
	check(
		"...and you get yours when you next join",
		Data:Get(host2).extras.buddy == true and Data:Get(host2).invite.friends["7004"] == true,
		Data:Get(host2).invite.count
	)
	check("...with the card", card(mHost2, host2).title == "FRIEND JOINED!")
	check("...once", not Invite:Credit(host2, 7004, "Late"))
	Engine.removePlayer(late)
	Engine.removePlayer(host2)
	Engine.advance(1)
end

-- Money: Shards, the shop, Robux, the pass, goals, VIP, MVP --------------------------------------------------------
do
	local Economy = service("EconomyService")
	local ShopS = service("ShopService")
	local SeasonS = service("SeasonService")
	local Progress = service("ProgressService")
	local Status = service("StatusService")
	local Shop = Engine.require(tree.shared.Data.Shop)
	local Season = Engine.require(tree.shared.Data.Season)
	local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
	local MPS = Engine.game:GetService("MarketplaceService")
	local rawSend = send
	local function send(...)
		Engine.advance(0.6) -- (each remote has a per-player rate limit)
		rawSend(...)
	end
	local p = Data:Get(red)
	check("matches pay Shards", (p.shards or 0) > 0, p.shards)
	check("...and pass XP", (p.season and p.season.xp or 0) > 0)
	check(
		"the results say what you earned",
		results and results.you and results.you.earned ~= nil and (results.you.earned.shards or 0) > 0
	)
	-- buying with Shards
	local today = Shop.daily(Shop.dayOf(ShopS.now()))
	local key = today[1]
	local it = Cosmetics.get(key)
	local price = Shop.price(it)
	p.shards = price - 1
	send(red, "Buy", "item", key)
	check("not enough Shards: no sale", p.shards == price - 1 and not (p.owned or {})[key])
	Economy:Add(red, 1)
	send(red, "Buy", "item", key)
	check("today's item bought with Shards", p.owned[key] == true and p.shards == 0)
	check("...and worn at once", p.equipped[it.kind] == key)
	Economy:Add(red, 5000)
	local before = p.shards
	send(red, "Buy", "item", key)
	check("...and never sold twice", p.shards == before)
	local notToday
	for _, k in Shop.pool do
		if not table.find(today, k) then
			notToday = k
			break
		end
	end
	send(red, "Buy", "item", notToday)
	check("an item not in today's shop can't be bought", not p.owned[notToday] and p.shards == before)
	send(red, "Buy", "item", "goal_sharp")
	send(red, "Buy", "item", "vip_title")
	check(
		"goal and VIP cosmetics can't be bought",
		not p.owned.goal_sharp and not p.owned.vip_title and p.shards == before
	)
	local bundle = Shop.weekly(Shop.weekOf(ShopS.now()))
	send(red, "Buy", "bundle")
	check(
		"the week's bundle",
		p.owned[bundle.keys[1]] and p.owned[bundle.keys[3]] and p.shards == before - bundle.price
	)
	-- Robux: receipts, granted exactly once
	Shop.PACKS[2].id = 9001
	Shop.PASS.id = 9002
	Shop.TIER.id = 9003
	local s0 = p.shards
	local function receipt(id, pid)
		return MPS.ProcessReceipt({ PlayerId = red.UserId, ProductId = pid, PurchaseId = id })
	end
	local d1 = receipt("buy-1", 9001)
	check("a Shard pack", d1 == Enum.ProductPurchaseDecision.PurchaseGranted and p.shards == s0 + Shop.PACKS[2].shards)
	receipt("buy-1", 9001)
	check("...the same receipt again gives nothing", p.shards == s0 + Shop.PACKS[2].shards)
	check(
		"a receipt for someone not here waits (Roblox retries)",
		MPS.ProcessReceipt({ PlayerId = 424242, ProductId = 9001, PurchaseId = "x" })
			== Enum.ProductPurchaseDecision.NotProcessedYet
	)
	-- the pass
	local st = SeasonS:State(red)
	st.xp = 0
	st.claimed = {}
	send(red, "Claim", 1, "p")
	check("the premium track needs the pass", not st.claimed["1p"])
	local mPass = mark()
	receipt("buy-2", 9002)
	check("the Turf Pass: premium", st.premium == true and firedSince(mPass, "Unlock", red) ~= nil)
	send(red, "Claim", 1, "p")
	check("...but tier 1 needs tier 1", not st.claimed["1p"])
	receipt("buy-3", 9003)
	check("+1 tier", Season.tierOf(st.xp) == 1)
	send(red, "Claim", 1, "p")
	check("premium tier 1 claimed: the season title", st.claimed["1p"] and p.owned[`s{st.n}_1p`] == true)
	send(red, "Settings", "equip", { kind = "title", key = `s{st.n}_1p` })
	check("...and it can be worn", p.equipped.title == `s{st.n}_1p`)
	local sh = p.shards
	send(red, "Claim", 1, "p")
	check("...once", p.shards == sh)
	SeasonS:AddTiers(red, 1)
	local s2 = p.shards
	send(red, "Claim", 2, "f")
	check("a free tier's Shards", p.shards == s2 + Season.reward(st.n, 2, "f").amount)
	send(red, "Claim", 5, "f")
	check("a tier not reached can't be claimed", not st.claimed["5f"])
	-- equip checks
	send(red, "Settings", "equip", { kind = "trail", key = "shop_overcharge" })
	check("you can't wear what you don't own", p.equipped.trail ~= "shop_overcharge" or p.owned.shop_overcharge)
	send(red, "Settings", "equip", { kind = "trail", key = false })
	check("...and you can wear nothing", p.equipped.trail == nil)
	-- the Starter Pack
	local s3 = p.shards
	check(
		"the Starter Pack",
		ShopS:GrantStarter(red) and p.shards == s3 + Shop.STARTER.shards and p.owned.starter_founder
	)
	check("...once", not ShopS:GrantStarter(red))
	-- the Shard Club (a subscription): a month's Shards, once a month
	Shop.CLUB.subscriptionId = "EXP-TEST"
	Engine.subscribed[red.UserId .. ":EXP-TEST"] = true
	local s4 = p.shards
	check("the Shard Club's monthly Shards", ShopS:CheckClub(red) and p.shards == s4 + Shop.CLUB.monthlyShards)
	check("...once a month", not ShopS:CheckClub(red))
	Shop.CLUB.subscriptionId = nil
	-- goals: reached at a match's end, announced, worn
	p.stats.headshots = 99
	local mGoal = mark()
	Progress:Award(red, { won = false, seconds = 200, active = true, kills = 1, headshots = 1 })
	local g = firedSince(mGoal, "Unlock", red)
	check(
		"a goal reached: its card",
		g and tostring(g.args[1].title):find("SHARPSHOOTER") ~= nil,
		g and g.args[1].title
	)
	check("...its reward worn", p.equipped.trail == "goal_sharp")
	-- VIP: earned, never bought
	p.wins, p.stats.mvps = 49, 10
	local mVip = mark()
	Progress:Award(red, { won = true, seconds = 300, active = true, kills = 3 })
	check("50 wins and 10 MVPs: VIP", p.vip == true and red:GetAttribute("VIP") == true)
	check("...with its card", firedSince(mVip, "Unlock", red, function(e)
		return e[1].title == "YOU'RE VIP!"
	end) ~= nil)
	Engine.advance(0.2)
	local tag = red.Character and red.Character:FindFirstChild("StatusTag")
	local tagText = ""
	for _, l in tag and tag:GetChildren() or {} do
		tagText ..= l.Text .. "|"
	end
	check("...a VIP tag over their head", tagText:find("VIP") ~= nil, tagText)
	check("...and the halo", red.Character:FindFirstChild("VipHalo") ~= nil)
	-- MVP: the crown through the next match
	Status:SetMvp(blue)
	Engine.advance(0.1)
	check("the MVP wears the crown", blue.Character and blue.Character:FindFirstChild("MvpCrown") ~= nil)
	Status:SetMvp(nil)
	check("...until the next MVP", blue.Character:FindFirstChild("MvpCrown") == nil)
	-- kill effects ride on the kill feed; banners carry the builder's emblem
	Data:Get(blue).owned.shop_ink = true
	send(blue, "Settings", "equip", { kind = "effect", key = "shop_ink" })
	check("...worn", Data:Get(blue).equipped.effect == "shop_ink")
	red:SetAttribute("LookBanner", "starter_founder")
	local root = rootOf(red)
	Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS + 1)
	Match:NewMatch()
	Engine.advance(1)
	local sx = Teams:Team(red) == "red" and -40 or 40
	stand(red, Vector3.new(sx, 3, -12))
	-- (the first free spot near you: each map has its own walls and columns)
	local placed, why
	for _, dz in { -28, -20, -4, 4, 12, 20, 28, -36, 36 } do
		for _, dx in { -4, 0, 4, -8, 8 } do
			if not placed then
				local bx, bz = Formulas.cellOf(sx + dx, dz)
				placed, why = Build:Place(red, "banner", bx, bz, 0)
			end
		end
	end
	local emblem = false
	for _, m in ws:GetDescendants() do
		if m.Name == "Emblem" then
			emblem = true
		end
	end
	check(
		"a banner shows the emblem its builder wears",
		emblem,
		tostring(placed) .. " " .. tostring(why) .. " " .. tostring(ws:GetAttribute("Phase"))
	)
	_ = root
end

-- Anti-cheat ---------------------------------------------------------------------------------------------------------
do
	local honest = {}
	for _, f in acFlags do
		table.insert(honest, `{f.player.Name} {f.kind} {f.detail}`)
	end
	check("a whole run of honest play: the anti-cheat flags nobody", #honest == 0, table.concat(honest, " | "))
	Match:NewMatch()
	Engine.advance(1)
	local cheat = Engine.addPlayer("Cheater", 6660)
	Engine.advance(1)
	send(cheat, "Ready")
	Engine.advance(3) -- (spawned, the spawn's grace over)
	local function flagsOf(kind)
		local n = 0
		for _, f in acFlags do
			if f.player == cheat and f.kind == kind then
				n += 1
			end
		end
		return n
	end
	local r = rootOf(cheat)
	check("the cheater is in and alive", r ~= nil and service("CombatService"):Alive(cheat))
	-- walking at a normal speed: fine
	local start = r.Position
	for i = 1, 8 do
		r.CFrame = CFrame.new(start + Vector3.new(0, 0, i * Constants.WALK_SPEED * 0.25))
		Engine.advance(0.25)
	end
	check("walking: nothing", flagsOf("speed") == 0 and AC:Strikes(cheat) == 0)
	-- a speed hack: 3x as fast
	local from = rootOf(cheat).Position
	-- (a speed hack pushes the body along from wherever it is, 3x a walk)
	for _ = 1, 8 do
		rootOf(cheat).CFrame = rootOf(cheat).CFrame + Vector3.new(0, 0, -Constants.WALK_SPEED * 3 * 0.25)
		Engine.advance(0.25)
	end
	local went = (rootOf(cheat).Position - from).Magnitude
	check("too fast: flagged", flagsOf("speed") >= 1, AC:Strikes(cheat))
	check("...and pulled back (it gets them nowhere much)", went < Constants.WALK_SPEED * 3 * 2 * 0.6, went)
	-- a sprint is allowed its speed (the server heard the sprint)
	local before = flagsOf("speed")
	send(cheat, "Sprint", true)
	Engine.advance(1.2)
	local s0 = rootOf(cheat).Position
	for i = 1, 8 do
		rootOf(cheat).CFrame = CFrame.new(s0 + Vector3.new(0, 0, i * Constants.SPRINT_SPEED * 0.25))
		Engine.advance(0.25)
	end
	check("sprinting at sprint speed: nothing", flagsOf("speed") == before)
	send(cheat, "Sprint", false)
	-- a teleport
	Engine.advance(1)
	local strikes = AC:Strikes(cheat)
	rootOf(cheat).CFrame = rootOf(cheat).CFrame + Vector3.new(0, 0, 150)
	Engine.advance(0.3)
	check("a teleport: 3 strikes", flagsOf("teleport") == 1 and AC:Strikes(cheat) >= strikes + 3, AC:Strikes(cheat))
	-- our own teleports don't count
	local t0 = flagsOf("teleport")
	Engine.moveTo(cheat, rootOf(cheat).Position + Vector3.new(0, 0, -120))
	Engine.advance(0.5)
	check("...our own teleports never count", flagsOf("teleport") == t0)
	-- flying
	local realGround = AC.groundDistance
	AC.groundDistance = function(p, pos)
		if p == cheat then
			return 30
		end
		return realGround(p, pos)
	end
	Engine.advance(AC.AIR_SECONDS + 3)
	check("hovering high for seconds: flying", flagsOf("fly") >= 1)
	AC.groundDistance = realGround
	-- spam and refused shots
	AC.Dropped(AC, cheat, "Shoot")
	for _ = 1, AC.SPAM_LIMIT do
		AC:Dropped(cheat, "Shoot")
	end
	check("calls over the rate limits: spam", flagsOf("spam") >= 1)
	for _ = 1, AC.REJECT_LIMIT do
		service("CombatService").Rejected:Fire(cheat, "rate")
	end
	Engine.advance(0.1)
	check("shots refused again and again: flagged", flagsOf("shots") >= 1)
	-- aim: a note, never a strike
	local k0 = AC:Strikes(cheat)
	for _ = 1, AC.AIM_MIN_KILLS do
		service("CombatService").Killed:Fire(red, cheat, { head = true })
	end
	Engine.advance(0.1)
	check("all headshots for 25 kills: noted for a look", flagsOf("aim") == 1 and AC:Strikes(cheat) == k0)
	-- enough strikes: removed
	check(
		"enough strikes: removed from the server",
		cheat.Parent == nil or AC:Strikes(cheat) >= AC.KICK_STRIKES,
		AC:Strikes(cheat)
	)
	check(
		"...and it's on their record",
		Data:Get(cheat) == nil or (Data:Get(cheat).ac and Data:Get(cheat).ac.flags >= 4)
	)
end

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(5, #Engine.errors) do
		print(Engine.errors[i])
	end
	print(#Engine.errors .. " script errors")
	failed += #Engine.errors
end
if failed > 0 then
	error("ServerSmoke: " .. failed .. " failures")
end
