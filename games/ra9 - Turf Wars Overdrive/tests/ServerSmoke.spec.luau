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
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Data = service("PlayerDataService")
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
local ava = Engine.addPlayer("Ava", 501)
local ben = Engine.addPlayer("Ben", 502)
local cy = Engine.addPlayer("Cy", 503)
local dee = Engine.addPlayer("Dee", 504)
Engine.advance(1)
for _, p in { ava, ben, cy, dee } do
	send(p, "Ready")
end
Engine.advance(0.5)
check("everyone has a team", Teams:Team(ava) and Teams:Team(ben) and Teams:Team(cy) and Teams:Team(dee))
check("friends are kept together", Teams:Team(ava) == Teams:Team(ben), `{Teams:Team(ava)} {Teams:Team(ben)}`)
check("teams are even", Teams:Count("red") == 2 and Teams:Count("blue") == 2)
local red = Teams:Team(ava) == "red" and ava or cy
local red2 = red == ava and ben or dee
local blue = Teams:Team(ava) == "red" and cy or ava
local blue2 = blue == ava and ben or dee
check("everyone spawned alive", Combat:Alive(ava) and Combat:Alive(cy))
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
-- the lane rule: wall a whole row and the last openings are refused
do
	stand(red2, Vector3.new(-28, 3, 0))
	local col = Formulas.cellOf(-26, 0)
	local refused
	local _, z0 = Formulas.cellOf(0, -47)
	local _, z1 = Formulas.cellOf(0, 47)
	Build:Refill()
	for z = z0, z1 do
		stand(red2, Vector3.new(-28, 3, z * Constants.CELL))
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
check(
	"a 30 s countdown to the next game",
	math.abs(ws:GetAttribute("PhaseEnds") - Engine.workspace:GetServerTimeNow() - 30) < 1,
	ws:GetAttribute("PhaseEnds") - Engine.workspace:GetServerTimeNow()
)
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
