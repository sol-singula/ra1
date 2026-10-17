--[[
Server smoke test: boots the real server on the mock engine and plays a match: four players join (two of them
friends), teams balance with the friends together, the build phase (valid and refused placements, budgets, the
lane rule), the fight (a timed draw, a server arrow, a hit, a kill, the frontline moving, assists, friendly fire,
spawn protection, knockback), the turf rule, structures taking arrows, the TNT (the throw, the lob, the blast on
enemy structures and players, line of sight, teammates, the push, the deck, the cooldown, the checks), a team pushed out,
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
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
Engine.require(tree.shared.Constants).TUTORIAL = false -- (the players here know the game: tests/TutorialSmoke is the tutorial's)
Engine.runScript(tree.server.Main)
-- (the first-knockout help is tests/FeelSmoke's: here every new test player plays as anyone would)
Engine.require(tree.server.Services.CombatService).firstKillHelp = false
Engine.require(tree.server.Services.CombatService).comebackShield = false -- (and the comeback shield: tests/FeelSmoke)
Engine.require(tree.server.Services.CombatService).newPlayerHelp = false -- (and the new-player aim help: it bends shots at the wall toward people)
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
local mJoin = mark()
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
check("someone joins: their new teammates get a chip", firedSince(mJoin, "Announce", cy, function(a)
	return a[1].kind == "join" and a[1].ally == true and string.find(a[1].text, "your team") ~= nil
end) ~= nil)
check("...the other side hears of a new enemy", firedSince(mJoin, "Announce", ava, function(a)
	return a[1].kind == "join" and a[1].ally == false and string.find(a[1].text, "new enemy") ~= nil
end) ~= nil)
check("...and not the one who joined", firedSince(mJoin, "Announce", dee, function(a)
	return a[1].kind == "join"
end) == nil)
check("teams are even", Teams:Count("red") == 2 and Teams:Count("blue") == 2)
local red = Teams:Team(ava) == "red" and ava or cy
local red2 = red == ava and ben or dee
local blue = Teams:Team(ava) == "red" and cy or ava
local blue2 = blue == ava and ben or dee
check("everyone spawned alive", Combat:Alive(ava) and Combat:Alive(cy))
do
	local d = ava.Character:FindFirstChildOfClass("Humanoid"):GetAppliedDescription()
	check(
		"everyone wears their own avatar, at the standard size",
		d.HeightScale == 1 and d.WidthScale == 1 and d.DepthScale == 1 and d.BodyTypeScale == 0
	)
end
do
	local r = rootOf(red)
	check("red spawns at the west end", r and r.Position.X < -70, r and r.Position.X)
	check("blue spawns at the east end", rootOf(blue).Position.X > 70)
	local bands, outline = 0, red.Character:FindFirstChild("TeamOutline")
	for _, c in red.Character:GetChildren() do
		if c.Name == "TeamBand" and c.Color == Constants.TEAM_COLOR.red then
			bands += 1
		end
	end
	check("...wearing their team: bands in its colour", bands >= 1, bands)
	check("...and a team-coloured outline", outline and outline.OutlineColor == Constants.TEAM_COLOR.red)
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
	-- a little overlap with the map is fine: a cell whose box pokes into a shape only at its edge
	local a = Arena:Current()
	local side = Teams:Team(red) == "red" and -1 or 1
	local F = ws:GetAttribute("Frontline")
	local found
	for x = -70, 70, 4 do
		for z = -46, 46, 4 do
			local px, pz = Formulas.cellOf(x, z)
			local mn, mx = Formulas.footprintBox(px, pz, 1, 1, 0, 3)
			local centre = (mn + mx) / 2
			if (centre.X - F) * side > 2 and not found then
				local edge, inside = false, false
				for _, sol in a.solids do
					if sol.part ~= a.strips[1] and sol.max.Y > 0.6 then
						local pad = Vector3.new(Constants.BUILD_MAP_OVERLAP, 0, Constants.BUILD_MAP_OVERLAP)
						if
							Formulas.boxesOverlap(
								mn + Vector3.new(0.05, 0.6, 0.05),
								mx - Vector3.new(0.05, 0, 0.05),
								sol.min,
								sol.max
							)
						then
							edge = true
						end
						if Formulas.boxesOverlap(mn + pad + Vector3.new(0, 0.6, 0), mx - pad, sol.min, sol.max) then
							inside = true
						end
					end
				end
				if edge and not inside then
					found = { px, pz, centre }
				end
			end
		end
	end
	if found then
		stand(red, Vector3.new(found[3].X, 3, found[3].Z) + Vector3.new(-side * 6, 0, 0))
		Build:Refill()
		local okO, whyO = Build:Check(red, "cover", found[1], found[2], 0)
		check("a little overlap with the map is fine", okO == true or (whyO and not whyO:find("map")), whyO)
	else
		print("  (no edge-overlap cell on this map: skipped)")
	end
end
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
	-- the line moves into red's turf: red's piece at the line falls, the one further back stays
	local lineId = type(whyL) == "table" and whyL.id
	local backId = type(whyW) == "table" and whyW.id
	Match:_setFrontline(F + side * 8)
	check("the line moves in: what they built on the lost turf comes down", lineId and Build:All()[lineId] == nil)
	check("...what's still on their side stays", backId and Build:All()[backId] ~= nil)
	Match:_setFrontline(F)
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
	-- pieces touching join up (StructureModel.joins): that column of Keep Walls is one wall; take one back and the
	-- one it ran into finishes its end again, in the same box
	local row = {}
	for _, st in Build:All() do
		if st.key == "reinforced" and st.cx == col then
			row[st.cz] = st
		end
	end
	local a, b
	for z, st in row do
		if row[z + 2] and not row[z + 4] then
			a, b = st, row[z + 2]
		end
	end
	check("walls end to end join up", a and a.joins and a.joins.right == "run" and b.joins.left == "run")
	if a and b then
		local box0, box1, solids = a.boxMin, a.boxMax, a.solid
		check("...the server built the joint (a pilaster on the seam)", a.model:FindFirstChild("Pilaster") ~= nil)
		local mr = mark()
		Build:Remove(b.id, nil, true)
		check("...take one back: the other finishes its end", a.joins == nil or a.joins.right == nil)
		check("...its parts made again (no pilaster now)", a.model:FindFirstChild("Pilaster") == nil)
		local entry
		for _, sol in Arena:Solids() do
			if sol.id == a.id then
				entry = sol
			end
		end
		local live = #solids > 0
		for _, p in solids do
			live = live and p.Parent == a.model and p.CanCollide
		end
		check(
			"...its box exactly as it was, the arrows' list of its solid parts the new ones",
			a.boxMin == box0
				and a.boxMax == box1
				and entry
				and entry.min == box0
				and entry.max == box1
				and entry.parts == solids
				and live
		)
		local gone = firedSince(mr, "Structure", nil, function(m)
			return m[1].kind == "destroyed" and m[1].id == b.id
		end)
		check(
			"...the debris is told the shape it had (its joins)",
			gone and type(gone.args[1].joins) == "table" and gone.args[1].joins.left == "run"
		)
	end
end
check("the budget is spent per player", Build:Budget(blue) == Constants.BUILD_BUDGET)
local okB, whyB = Build:Place(blue, "tower", Formulas.cellOf(30, 0), 2, 0)
check("blue can't build beside the line from spawn (reach)", not okB, whyB)

-- Stacking: pieces on the tops of pieces (Formulas.stackCheck), the caps, the chain when a support falls ----------
do
	check("a build phase gives 200 points", Constants.BUILD_BUDGET == 200 and Build:BudgetMax() == 200)
	Build:SetBudget(120)
	Build:Refill()
	check("...another mode can set its own", Build:Budget(red) == 120, Build:Budget(red))
	Build:SetBudget(Constants.BUILD_BUDGET)
	Build:Refill()
	-- a 2 x 2 block of free cells on red's side (two walls side by side go there, and a tower over them)
	local function near(cx, cz)
		local px, pz = Formulas.cellCenter(cx, cz)
		stand(red, Vector3.new(px - 10, 3, pz))
	end
	local cx, cz
	for x = -16, -5 do
		for z = -6, 6 do
			if not cx then
				near(x, z)
				if
					Build:Check(red, "wall", x, z, 0)
					and Build:Check(red, "wall", x, z + 1, 0)
					and Build:Check(red, "wall", x + 2, z, 0)
				then
					cx, cz = x, z
				end
			end
		end
	end
	check("a clear patch to stack on", cx ~= nil)
	near(cx, cz)
	local mS = mark()
	local ok1, A = Build:Place(red, "wall", cx, cz, 0)
	check("a wall on the floor", ok1 == true, A)
	local ok2, B = Build:Place(red, "wall", cx, cz, 0, 10)
	check("a wall on top of it is built", ok2 == true, B)
	check("...its box starts where the first tops out", ok2 and B.boxMin.Y == 10 and B.boxMax.Y == 20)
	check(
		"...joined down: no plinth of its own (the stack reads as one tall wall)",
		ok2
			and B.joins
			and B.joins.below == "wall"
			and B.model:FindFirstChild("Plinth") == nil
			and A.model:FindFirstChild("Plinth") ~= nil
			and B.model:FindFirstChild("Body") ~= nil
	)
	check("...everyone is told, with its box (the preview stacks on it)", firedSince(mS, "Structure", nil, function(m)
		return m[1].kind == "built" and m[1].id == B.id and m[1].boxMin == B.boxMin and m[1].boxMax == B.boxMax
	end) ~= nil)
	local entry
	for _, sol in Arena:Solids() do
		if sol.id == B.id then
			entry = sol
		end
	end
	check(
		"...the arrows' box is the stacked one",
		entry and entry.min.Y == 10 and entry.max.Y == 20 and entry.parts == B.solid
	)
	local okU, whyU = Build:Place(red, "wall", cx, cz, 0, 5)
	check("half way up a wall: no support", not okU and whyU == "No support", whyU)
	local okU2, whyU2 = Build:Place(red, "wall", cx + 2, cz, 0, 10)
	check("...in the air beside it: no support", not okU2 and whyU2 == "No support", whyU2)
	local okU3, whyU3 = Build:Place(red, "tower", cx, cz, 0, 10)
	check("...a tower over a stack and thin air: no support", not okU3 and whyU3 == "No support", whyU3)
	local okU4, whyU4 = Build:Place(red, "wall", cx, cz, 0, 0)
	check("...on the floor where the stack stands: taken", not okU4 and whyU4 == "Something's already there", whyU4)
	local ok3, C = Build:Place(red, "wall", cx, cz, 0, 20)
	check("a third wall: three high, the cap", ok3 == true and C.boxMax.Y == Constants.BUILD_MAX_HEIGHT, C)
	local okH, whyH = Build:Place(red, "barricade", cx, cz, 0, 30)
	check("...nothing above it", not okH and whyH and whyH:find("Too high") ~= nil, whyH)
	-- take the top one back: a battlement on the wall is a parapet; a banner stays on the floor
	local b0 = Build:Budget(red)
	Build:Remove(C.id, nil, true)
	check("taking the top back refunds it", Build:Budget(red) == b0 + 10 and Build:All()[C.id] == nil)
	local okP, P = Build:Place(red, "barricade", cx, cz, 0, 20)
	check("a battlement on a wall: a parapet", okP == true and P.boxMin.Y == 20 and P.boxMax.Y == 24, P)
	local okBan, whyBan = Build:Place(red, "banner", cx, cz, 0, 24)
	check("the Rally Banner stays on the floor", not okBan and whyBan == "Only on the floor", whyBan)
	-- a shield wall takes nothing on it; a rampart takes a wall
	local okSh, Sh = Build:Place(red, "cover", cx + 2, cz, 0)
	local okSh2, Sh2 = Build:Place(red, "cover", cx + 3, cz, 0)
	local okOn, whyOn = Build:Place(red, "barricade", cx + 2, cz, 0, 6)
	check(
		"nothing goes on a shield wall",
		okSh == true and okSh2 == true and not okOn and whyOn == "No support",
		okSh and okSh2 and whyOn or Sh2 or Sh
	)
	-- reach is to the piece: from where the floor is in reach, the top of a stack may not be
	do
		local mid = (P.boxMin + P.boxMax) / 2
		stand(red, Vector3.new(mid.X - 40, 3, mid.Z))
		local _, whyF = Build:Check(red, "barricade", cx, cz, 0)
		local _, whyT = Build:Check(red, "barricade", cx, cz, 0, 24)
		check(
			"reach is measured to the piece: the stack's foot in reach, its top not",
			whyF == "Something's already there" and whyT == "Too far away",
			(whyF or "?") .. " / " .. (whyT or "?")
		)
		near(cx, cz)
	end
	-- a player standing on the stack's top is not inside it (the anti-cheat's noclip test)
	do
		local mid = (P.boxMin + P.boxMax) / 2
		stand(red, Vector3.new(mid.X, P.boxMax.Y + 3, mid.Z))
		local realGround = AC.groundDistance
		AC.groundDistance = function(p, pos)
			if p == red then
				return 3
			end
			return realGround(p, pos)
		end
		local n0 = #acFlags
		Engine.advance(3.2) -- (past the teleport's grace, then a few checks)
		local flagged = false
		for i = n0 + 1, #acFlags do
			if acFlags[i].player == red then
				flagged = true
			end
		end
		check(
			"standing on top of a stack: the anti-cheat sees nothing wrong",
			not flagged,
			flagged and acFlags[#acFlags].kind
		)
		AC.groundDistance = realGround
		near(cx, cz)
	end
	-- the support comes down: everything on it falls with it (no refund), each with its own debris, to the floor
	local fell = {}
	local conn = Build.Destroyed:Connect(function(s)
		table.insert(fell, s.id)
	end)
	local mD = mark()
	local bBefore = Build:Budget(red)
	Build:Hit(A.id, 9999, blue)
	conn:Disconnect()
	check(
		"break the bottom wall: the whole stack comes down",
		Build:All()[A.id] == nil and Build:All()[B.id] == nil and Build:All()[P.id] == nil
	)
	check("...each counted as destroyed", #fell == 3, #fell)
	local top = firedSince(mD, "Structure", nil, function(m)
		return m[1].kind == "destroyed" and m[1].id == P.id
	end)
	check(
		"...the parapet's debris falls to the floor the stack stood on",
		top and top.args[1].floor == 0 and top.args[1].min.Y == 20,
		top and top.args[1].floor
	)
	check("...nothing refunded", Build:Budget(red) == bBefore)
	check("...the cells are free again", Build:Place(red, "wall", cx, cz, 0) == true)
	-- taken back by hand: the stack comes down refunded
	local okA2, A2 = true, nil
	for _, st in Build:All() do
		if st.cx == cx and st.cz == cz and st.team == Teams:Team(red) and st.boxMin.Y == 0 then
			A2 = st
		end
	end
	local okB2, B2 = Build:Place(red, "wall", cx, cz, 0, 10)
	local bb = Build:Budget(red)
	check("a stack again", okA2 and A2 and okB2 == true, B2)
	Build:Remove(A2.id, nil, true)
	check(
		"take the bottom back: both go, both refunded",
		Build:All()[B2.id] == nil and Build:Budget(red) == math.min(Constants.BUILD_BUDGET, bb + 20),
		Build:Budget(red)
	)
	for _, sh in { okSh and Sh, okSh2 and Sh2 } do
		if sh then
			Build:Remove(sh.id, nil, true)
		end
	end
	-- the cap on standing pieces: 24 each, LIMIT REACHED after
	Build:Refill()
	local placed, whyCap = {}, nil
	for x = -16, -4 do
		near(x, 0) -- (a column at a time: the whole column is in reach from its middle)
		for z = -8, 8 do
			if not whyCap then
				local okC, res = Build:Place(red, "barricade", x, z, 0)
				if okC then
					table.insert(placed, res.id)
				elseif res and res:find("Limit reached") then
					whyCap = res
				end
				if Build:Budget(red) < 10 then
					Build:Refill()
				end
			end
		end
	end
	check(
		"a player's standing pieces are capped at 24: LIMIT REACHED",
		whyCap ~= nil and Build:PlayerCount(red) == Constants.PLAYER_STRUCTURES,
		whyCap or Build:PlayerCount(red)
	)
	for _, id in placed do
		Build:Remove(id, nil, true)
	end
	check("...taken back, there's room again", Build:PlayerCount(red) < Constants.PLAYER_STRUCTURES)
	Build:Refill()
	stand(red, Vector3.new(-40, 3, -12))
end

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
-- protection wears off (they spawned a while ago); every hit is a knockout, even a tap
stand(red, Vector3.new(-10, 3, -12), Vector3.new(10, 3, -12))
stand(blue, Vector3.new(10, 3, -12), Vector3.new(-10, 3, -12))
local before = ws:GetAttribute("Frontline")
local m1 = mark()
send(red, "Draw", true)
Engine.advance(0.05)
send(red, "Shoot", rootOf(red).Position + Vector3.new(0, 1.5, 0), Vector3.new(1, 0, 0), 7)
Engine.advance(0.6)
check("everyone sees the arrow", firedSince(m1, "Arrow", nil) ~= nil)
check("a tap is a knockout (one hit, every time)", not Combat:Alive(blue), Combat:Health(blue))
check("the shooter gets a hit marker", firedSince(m1, "Hit", red) ~= nil)
check("the victim is told where it came from", firedSince(m1, "Hurt", blue) ~= nil)
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
local feed = firedSince(m1, "Kill", nil)
check("the kill feed says who and how far", feed and feed.args[1].killer == red.UserId and feed.args[1].push == push)
check("the kill counts", Match:Stats(red).kills == 1)
do
	local earned = firedSince(m1, "Earned", red)
	check(
		"a knockout pays Shards right away (the +N flies to their counter)",
		earned
			and earned.args[1].amount >= Engine.require(tree.shared.Data.Shop).EARN.perKill
			and earned.args[1].why ~= nil,
		earned and earned.args[1].amount
	)
end
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
-- the blade: works AT the line (you can't cross it): a long slash knocks out who's in reach on the other side, and
-- its swing knocks arrows back at the archer
do
	local blade = Weapons.get("blade")
	local F = ws:GetAttribute("Frontline")
	local function whole(p)
		Combat:Spawned(p)
		Engine.advance(Constants.SPAWN_PROTECT + 0.1)
	end
	send(red, "Equip", "blade")
	Engine.advance(0.1)
	check("no blade before the CHARGE (bows only)", Combat:Weapon(red) ~= "blade" and not Match:Charging())
	-- (the whole fight counts as the CHARGE for this block)
	local charge0 = Constants.CHARGE_SECONDS
	Constants.CHARGE_SECONDS = 1e6
	Engine.advance(0.5)
	check("the CHARGE: workspace says so", ws:GetAttribute("Charge") == true)
	send(red, "Equip", "blade")
	Engine.advance(Constants.SPAWN_PROTECT)
	check("the blade in hand", Combat:Weapon(red) == "blade")
	whole(blue)
	stand(blue, Vector3.new(F + 4.5, 3, 30), Vector3.new(F - 10, 3, 30))
	stand(red, Vector3.new(F - 4.5, 3, 30), Vector3.new(F + 10, 3, 30))
	local m = mark()
	send(red, "Swing", Vector3.new(1, 0, 0))
	check("a slash reaches across the line: a knockout", not Combat:Alive(blue), Combat:Health(blue))
	check("...and everyone sees it", firedSince(m, "Swing", nil) ~= nil)
	whole(blue)
	stand(blue, Vector3.new(F + 4.5, 3, 30), Vector3.new(F - 10, 3, 30))
	send(red, "Swing", Vector3.new(-1, 0, 0))
	check("...not who's behind you", Combat:Alive(blue), Combat:Health(blue))
	Engine.advance(blade.cooldown)
	stand(red, Vector3.new(F - 14, 3, 30), Vector3.new(F + 10, 3, 30))
	send(red, "Swing", Vector3.new(1, 0, 0))
	check("...not out of reach", Combat:Alive(blue), Combat:Health(blue))
	Engine.advance(blade.cooldown)
	-- the lunge carries you in: a slash at someone a few steps past the blade's reach still lands (one slash, one
	-- knockout)
	-- (quick respawns and no spawn shield for these, so they fit in the fight; back in once the server's own
	-- respawn is done, so it doesn't land mid-test)
	local quick0 = { Constants.RESPAWN_SECONDS, Constants.RESPAWN_SECONDS_NEW, Constants.SPAWN_PROTECT }
	Constants.RESPAWN_SECONDS, Constants.RESPAWN_SECONDS_NEW, Constants.SPAWN_PROTECT = 0.2, 0.2, 0
	local function fresh(p)
		if not Combat:Alive(p) then
			Engine.advance(0.4)
		end
		Match:_setFrontline(F) -- (each knockout here pushed the line: back where it was, so the fight goes on)
		whole(p)
	end
	local function at(p, x, lookX)
		stand(p, Vector3.new(F + x, 3, 30), Vector3.new(F + lookX, 3, 30))
	end
	fresh(blue)
	at(blue, 7, -10)
	at(red, -7, 10)
	send(red, "Swing", Vector3.new(1, 0, 0))
	check(
		"the lunge: a slash reaches past the blade's range (it carries you in)",
		not Combat:Alive(blue) and 14 > blade.range,
		Combat:Health(blue)
	)
	check("...still one slash, one knockout", blade.damage[1] >= Constants.MAX_HEALTH)
	Engine.advance(blade.cooldown)
	-- a wide arc: someone well off to the side (60 degrees) is still caught
	fresh(blue)
	stand(blue, Vector3.new(F + 4, 3, 30 + 4 * math.tan(math.rad(60))), Vector3.new(F - 10, 3, 30))
	at(red, 0, 10)
	send(red, "Swing", Vector3.new(1, 0, 0))
	check("...a wide arc: 60 degrees off is still caught", not Combat:Alive(blue), Combat:Health(blue))
	Engine.advance(blade.cooldown)
	-- the slash keeps cutting for a moment: someone stepping in just after the click is caught
	fresh(blue)
	at(blue, 14, -10)
	at(red, -6, 10)
	local mw = mark()
	Engine.fireServer(red, "Swing", Vector3.new(1, 0, 0))
	check("...out of reach as you click: nothing yet", Combat:Alive(blue))
	Engine.advance(Constants.BLADE_WINDOW * 0.3)
	at(blue, 6, -10)
	Engine.advance(0.05)
	check("...but stepping into the slash a moment later: knocked out", not Combat:Alive(blue), Combat:Health(blue))
	check("...(no whiff for a hit)", firedSince(mw, "Swing", red, function(a)
		return a[1].whiff == true
	end) == nil)
	Engine.advance(blade.cooldown)
	-- a slash that cuts no one: once it's done, the swinger hears the whiff
	fresh(blue)
	at(blue, 30, -10)
	at(red, -6, 10)
	mw = mark()
	send(red, "Swing", Vector3.new(1, 0, 0))
	Engine.advance(Constants.BLADE_WINDOW + 0.05)
	check("a slash at no one: a whiff (only the swinger's told)", firedSince(mw, "Swing", red, function(a)
		return a[1].whiff == true and a[1].by == red.UserId
	end) ~= nil and Combat:Alive(blue))
	Engine.advance(blade.cooldown)
	-- not spammy: a second slash before the cooldown does nothing
	at(blue, 8, -10)
	at(red, 0, 10)
	send(red, "Swing", Vector3.new(-1, 0, 0)) -- (the wrong way: a whiff, and the blade's cooling down)
	send(red, "Swing", Vector3.new(1, 0, 0))
	Engine.advance(0.05)
	check("the cooldown: no second slash straight after", Combat:Alive(blue), Combat:Health(blue))
	Engine.advance(blade.cooldown)
	-- lag: a laggy swinger's slash is also tested where they saw the target (their ping ago), like an arrow
	local ping0 = Combat.pingOf
	fresh(blue)
	at(blue, 8, -10)
	at(red, -4, 10)
	Engine.advance(0.5) -- (the server's kept where blue was)
	Combat.pingOf = function(p)
		return p == red and 0.2 or 0
	end
	Engine.moveTo(blue, Vector3.new(F + 40, 3, 30), Vector3.new(F, 3, 30)) -- (blue's already gone on the server)
	Engine.advance(0.12) -- (gone a moment: longer ago than the mock's own ping, not red's)
	send(red, "Swing", Vector3.new(1, 0, 0))
	check("lag: a slash where the swinger saw them (their ping ago) still lands", not Combat:Alive(blue))
	Combat.pingOf = ping0
	Engine.advance(blade.cooldown)
	fresh(blue)
	at(blue, 8, -10)
	Engine.advance(0.5)
	Engine.moveTo(blue, Vector3.new(F + 40, 3, 30), Vector3.new(F, 3, 30))
	Engine.advance(0.12)
	send(red, "Swing", Vector3.new(1, 0, 0))
	Engine.advance(Constants.BLADE_WINDOW)
	check("...(no lag: nothing to forgive)", Combat:Alive(blue))
	Engine.advance(blade.cooldown)
	-- a clash: blue's blade is already swinging at red as red's slash lands: no knockout, both thrown apart
	send(blue, "Equip", "blade")
	fresh(blue)
	at(blue, 12, -10)
	at(red, -8, 10)
	local mc = mark()
	Engine.fireServer(blue, "Swing", Vector3.new(-1, 0, 0)) -- (red's just out of blue's reach: still cutting)
	Engine.moveTo(red, Vector3.new(F, 3, 30), Vector3.new(F + 10, 3, 30)) -- (red steps in and slashes back at once)
	Engine.fireServer(red, "Swing", Vector3.new(1, 0, 0))
	Engine.advance(0.1)
	check("a clash: two blades swung at each other, no knockout", Combat:Alive(blue) and Combat:Alive(red))
	check("...both hear it", firedSince(mc, "Hit", red, function(a)
		return a[1].clash == true
	end) ~= nil and firedSince(mc, "Hit", blue, function(a)
		return a[1].clash == true
	end) ~= nil)
	Engine.advance(blade.cooldown)
	-- ...but a slash a while after theirs (they swung and missed) lands
	at(blue, 12, -10)
	at(red, -8, 10)
	send(blue, "Swing", Vector3.new(-1, 0, 0))
	Engine.advance(Constants.BLADE_CLASH + 0.1)
	at(red, 0, 10)
	send(red, "Swing", Vector3.new(1, 0, 0))
	check("...not long after theirs: it lands", not Combat:Alive(blue), Combat:Health(blue))
	send(blue, "Equip", "bow")
	fresh(blue)
	Constants.RESPAWN_SECONDS, Constants.RESPAWN_SECONDS_NEW, Constants.SPAWN_PROTECT = table.unpack(quick0)
	Engine.advance(blade.cooldown)
	-- the parry: blue swings a blade toward red as red's arrow arrives; it flies back and knocks red out
	send(red, "Equip", "bow")
	send(blue, "Equip", "blade")
	whole(red)
	whole(blue)
	stand(red, Vector3.new(F - 30, 3, 30), Vector3.new(F + 10, 3, 30))
	stand(blue, Vector3.new(F + 6, 3, 30), Vector3.new(F - 30, 3, 30))
	local mp = mark()
	send(red, "Draw", true)
	Engine.advance(1)
	send(red, "Shoot", rootOf(red).Position + Vector3.new(0, 1.5, 0), Vector3.new(1, 0, 0), 9)
	Engine.advance(0.05)
	send(blue, "Swing", Vector3.new(-1, 0, 0))
	Engine.advance(1)
	check("a blade swing parries an arrow from the front", Combat:Alive(blue), Combat:Health(blue))
	check("...the swinger hears it", firedSince(mp, "Hit", blue, function(a)
		return a[1].parry == true
	end) ~= nil)
	check("...and it flies back and knocks the archer out", not Combat:Alive(red), Combat:Health(red))
	whole(red)
	whole(blue)
	send(blue, "Equip", "bow")
	Constants.CHARGE_SECONDS = charge0
	Engine.advance(0.5)
	check("...and the CHARGE is over", not Match:Charging())
end
-- the turf rule: red can't walk onto blue's turf
local mTurf = mark()
stand(red, Vector3.new(ws:GetAttribute("Frontline") + 10, 3, 20))
Engine.advance(0.4)
check(
	"stepping over the line puts you back",
	rootOf(red).Position.X <= ws:GetAttribute("Frontline"),
	rootOf(red).Position.X
)
check("...and tells you when you can charge across", firedSince(mTurf, "Toast", red, function(a)
	return string.find(a[1], "charge across in") ~= nil
end) ~= nil)
-- the CHARGE (the fight's last seconds): the line opens, the blade comes out; when it ends, the blade goes away and
-- anyone over the line goes home
do
	send(red, "Equip", "bow")
	check("skip to the CHARGE", Match:SkipTo("charge") and Match:Charging())
	check("...everyone's told", firedSince(0, "Announce", nil, function(a)
		return string.find(a[1].text, "CHARGE") ~= nil
	end) ~= nil)
	local F = ws:GetAttribute("Frontline")
	stand(red, Vector3.new(F + 10, 3, 20))
	Engine.advance(0.4)
	check("...you can cross the line", rootOf(red).Position.X > F + 5, rootOf(red).Position.X)
	send(red, "Equip", "blade")
	Engine.advance(0.1)
	check("...the blade is out", Combat:Weapon(red) == "blade")
	Match:SkipTo("build")
	Engine.advance(0.5)
	check("the CHARGE ends with the fight", not Match:Charging() and ws:GetAttribute("Charge") ~= true)
	check("...the blade goes away", Combat:Weapon(red) == "bow", Combat:Weapon(red))
	check(
		"...and anyone over the line goes home",
		rootOf(red).Position.X < ws:GetAttribute("Frontline"),
		rootOf(red).Position.X
	)
	Match:SkipTo("fight")
	Engine.advance(0.5)
end
-- arrows break structures: blue's bow at red's wall, and when it comes down everyone is told where it stood and what
-- broke it (the debris flies from there)
do
	local wall
	for _, st in Build:All() do
		if st.team == Teams:Team(red) and st.key == "wall" then
			wall = st
			break
		end
	end
	send(blue, "Equip", "bow")
	Engine.advance(Constants.SPAWN_PROTECT)
	local target = (wall.boxMin + wall.boxMax) / 2
	stand(blue, Vector3.new(ws:GetAttribute("Frontline") + 6, 3, target.Z), target)
	local hp0 = wall.hp
	local mw = mark()
	shootAt(blue, target, 1)
	check("an arrow chips a structure", wall.hp < hp0 or Build:All()[wall.id] == nil, wall.hp)
	for _ = 1, 3 do
		shootAt(blue, target, 1)
	end
	check("...and a few more break it", Build:All()[wall.id] == nil)
	local gone = firedSince(mw, "Structure", nil, function(a)
		return a[1].kind == "destroyed" and a[1].id == wall.id
	end)
	local info = gone and gone.args[1]
	check(
		"...everyone is told where it stood (its box, its turn)",
		info and info.min == wall.boxMin and info.max == wall.boxMax and info.rot == wall.rot and info.key == "wall"
	)
	check(
		"...and what broke it: an arrow, from where it hit (the debris flies from there)",
		info
			and type(info.blast) == "table"
			and info.blast.pos.X ~= nil
			and info.blast.power > 0
			and info.blast.power < 1
			and not info.blast.tnt
			and (info.blast.pos - target).Magnitude < 6,
		info and info.blast and `{info.blast.pos} {info.blast.power} {target}`
	)
end

-- TNT: wound up, thrown in a lob, it blows up enemy structures (never your own team's) and knocks out enemies close
-- to it with nothing between; a cooldown between throws; checked like a shot
do
	local tnt = Weapons.get("tnt")
	local function whole(p)
		Combat:Spawned(p)
		Engine.advance(Constants.SPAWN_PROTECT + 0.1)
	end
	local function eye(p)
		return rootOf(p).Position + Vector3.new(0, 1.5, 0)
	end
	-- wind up for `held` seconds, then throw onto `target`
	local function throwAt(p, target, held)
		send(p, "Draw", true)
		Engine.advance(held)
		local charge = Formulas.charge(tnt, held + 0.05)
		local dir = Formulas.lobAim(eye(p), target, Formulas.shot(tnt, charge).speed)
		send(p, "Shoot", eye(p), dir, 77)
	end
	local F = ws:GetAttribute("Frontline")
	-- a red wall at the line, a blue cover just across it (inside the blast), built for the test where the map is clear
	Build:SetOpen(true)
	local okR, rw, okB, bc
	for _, z0 in { 30, 18, 6, -6, -18, 40, -40 } do
		Build:Refill()
		stand(red, Vector3.new(F - 12, 3, z0))
		okR, rw = Build:Place(red, "wall", Formulas.cellOf(F - 4, z0), select(2, Formulas.cellOf(F - 4, z0)), 1)
		if okR then
			stand(blue, Vector3.new(F + 12, 3, z0))
			okB, bc =
				Build:Place(blue, "cover", Formulas.cellOf(F + 1, z0 + 9), select(2, Formulas.cellOf(F + 1, z0 + 9)), 0)
			if okB then
				break
			end
			Build:Remove(rw.id, nil, true)
		end
	end
	Build:SetOpen(false)
	check("(a red wall and a blue cover at the line for the test)", okR == true and okB == true, `{rw} {bc}`)
	whole(red)
	whole(blue)
	-- the TNT is a Robux unlock: no free throws, locked until it's bought
	blue:SetAttribute("OwnsTNT", nil)
	send(blue, "Equip", "tnt")
	check("TNT not bought: locked, the bow stays in hand", Combat:Weapon(blue) ~= "tnt", Combat:Weapon(blue))
	check("...no free try left anywhere", blue:GetAttribute("TntTry") == nil)
	do
		local Shop = Engine.require(tree.shared.Data.Shop)
		check(
			"...80% off its old price, PERMANENT",
			Shop.off(Shop.TNT) == 80 and string.find(Shop.TNT.desc, "PERMANENT") ~= nil
		)
		-- the day's deal: one Robux-only item 70% off, for a real hour
		local ShopS = service("ShopService")
		Data:Get(blue).deal = nil
		ShopS:RefreshDeal(blue)
		local key = blue:GetAttribute("Deal")
		local d = type(key) == "string" and Shop.products[key]
		check(
			"a deal is on: a Robux-only item they don't own, 70% off, an hour left",
			d
				and d.deal == true
				and d.robux == math.floor(d.was * 0.3 + 0.5)
				and not Data:Get(blue).owned[d.cosmetic]
				and math.abs(blue:GetAttribute("DealEnds") - ShopS.now() - 3600) <= 2,
			tostring(key)
		)
		ShopS:RefreshDeal(blue)
		check("...the same deal all day (not re-rolled)", blue:GetAttribute("Deal") == key)
		Data:Get(blue).deal.ends = ShopS.now() - 1
		ShopS:RefreshDeal(blue)
		check("...its hour over: gone (and not back today)", blue:GetAttribute("Deal") == nil)
		local ok, why = ShopS:PromptRobux(blue, key)
		check("...and it can't be bought any more", ok == false and string.find(why, "over") ~= nil, tostring(why))
		Data:Get(blue).deal = { day = Shop.dayOf(ShopS.now()) - 1, key = key, ends = 0 }
		ShopS:RefreshDeal(blue)
		check("tomorrow: a new deal", type(blue:GetAttribute("Deal")) == "string")
		local k2 = blue:GetAttribute("Deal")
		ShopS:Grant(blue, Shop.products[k2])
		check(
			"bought: yours, and no deal left today",
			Data:Get(blue).owned[Shop.products[k2].cosmetic] == true and blue:GetAttribute("Deal") == nil
		)
	end
	-- bought (the game pass): for good
	service("ShopService"):GrantTNT(blue)
	check("bought: owned (saved)", blue:GetAttribute("OwnsTNT") == true and Data:Get(blue).tnt == true)
	send(blue, "Equip", "tnt")
	check("the TNT in hand", Combat:Weapon(blue) == "tnt")
	local held = blue.Character:FindFirstChild("HeldBow")
	check(
		"...everyone sees red sticks in your hand",
		held and held:GetAttribute("Weapon") == "tnt" and held:FindFirstChild("Stick") ~= nil
	)
	local wallMid = (rw.boxMin + rw.boxMax) / 2
	stand(blue, Vector3.new(F + 12, 3, wallMid.Z), wallMid)
	stand(red, Vector3.new(F - 30, 3, wallMid.Z - 20))
	local m = mark()
	throwAt(blue, wallMid, 0.4)
	local thrown = firedSince(m, "Bomb", nil)
	check("a throw: everyone is told (Bomb)", thrown ~= nil and thrown.args[1].by == blue.UserId)
	check("...it flies on the server", #Combat:Bombs() == 1, #Combat:Bombs())
	do
		-- a lob: it rises above a straight line from your hand, then comes down
		local b = thrown and thrown.args[1]
		local mid = b and Formulas.lobAt(b.origin, b.velocity, 0.15)
		local line = b and b.origin + b.velocity * 0.15
		check("...in an arc (gravity pulls it down)", mid and mid.Y < line.Y)
	end
	-- (straight away again: the cooldown)
	local mr = mark()
	local rejected
	local conn = Combat.Rejected:Connect(function(p, why)
		if p == blue then
			rejected = why
		end
	end)
	send(blue, "Shoot", eye(blue), Vector3.new(-1, 0, 0), 78)
	check(
		"a second throw straight away is refused (the cooldown)",
		firedSince(mr, "Bomb", nil) == nil and rejected == "rate",
		rejected
	)
	conn:Disconnect()
	Engine.advance(Constants.TNT_FUSE + 0.2)
	local blast = firedSince(m, "Blast", nil)
	check("it goes off: everyone is told (Blast)", blast ~= nil and blast.args[1].radius == Constants.TNT_RADIUS)
	check("...at the wall", blast and (blast.args[1].pos - wallMid).Magnitude < 5, blast and blast.args[1].pos)
	check("...the enemy's wall is blown up", Build:All()[rw.id] == nil)
	check("...never your own team's", Build:All()[bc.id] ~= nil)
	local gone = firedSince(m, "Structure", nil, function(a)
		return a[1].kind == "destroyed" and a[1].id == rw.id
	end)
	local info = gone and gone.args[1]
	check(
		"...its debris goes out with the blast: where and how hard (a TNT: much harder than an arrow)",
		info
			and info.blast
			and info.blast.tnt == true
			and info.blast.power >= 0.75
			and (info.blast.pos - blast.args[1].pos).Magnitude < 0.01
	)
	check("...and the bomb is gone", #Combat:Bombs() == 0)
	-- a knockout: thrown at an enemy's feet in the open
	F = ws:GetAttribute("Frontline")
	whole(red2)
	stand(red2, Vector3.new(F - 8, 3, -36), Vector3.new(F + 10, 3, -36))
	stand(blue, Vector3.new(F + 14, 3, -36), Vector3.new(F - 8, 3, -36))
	Engine.advance(tnt.cooldown)
	local mk = mark()
	throwAt(blue, rootOf(red2).Position - Vector3.new(0, 2.5, 0), 0.5)
	Engine.advance(Constants.TNT_FUSE + 0.2)
	check("thrown at an enemy's feet: it goes off by them", firedSince(mk, "Blast", nil) ~= nil)
	check("...a knockout", not Combat:Alive(red2), Combat:Health(red2))
	local kill = firedSince(mk, "Kill", nil)
	check(
		"...credited to the thrower, with the TNT",
		kill and kill.args[1].killer == blue.UserId and kill.args[1].weapon == "tnt"
	)
	-- checked like a shot: from far off your head it starts at your head; never from the far side of a wall
	Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
	Engine.advance(tnt.cooldown)
	F = ws:GetAttribute("Frontline")
	stand(blue, Vector3.new(F + 14, 3, -36), Vector3.new(F - 8, 3, -36))
	local mo = mark()
	send(blue, "Draw", true)
	Engine.advance(0.3)
	send(blue, "Shoot", eye(blue) + Vector3.new(0, 40, 0), Vector3.new(-1, 0, 0), 79)
	local far = firedSince(mo, "Bomb", nil)
	check(
		"a throw from far off your head starts at your head",
		far and (far.args[1].origin - eye(blue)).Magnitude < 0.5
	)
	Engine.advance(tnt.cooldown + 0.2)
	local head = eye(blue)
	Arena:AddBox("test_screen", head + Vector3.new(-2.5, -3, -3), head + Vector3.new(-1.5, 3, 3))
	local mt = mark()
	send(blue, "Shoot", head + Vector3.new(-4, 0, 0), Vector3.new(-1, 0, 0), 80)
	local through = firedSince(mt, "Bomb", nil)
	check("...and never from the far side of a wall", through and (through.args[1].origin - head).Magnitude < 0.5)
	Arena:RemoveBox("test_screen")
	Engine.advance(Constants.TNT_FUSE + 0.3)
	-- the fuse: thrown up into the air it goes off when the fuse runs out
	Engine.advance(tnt.cooldown)
	send(blue, "Draw", true)
	-- (wound up most of the way: high enough to stay up the whole fuse, under the ceiling a full throw now reaches)
	Engine.advance(tnt.draw * 0.75)
	local mf = mark()
	send(blue, "Shoot", eye(blue), Vector3.new(0, 1, 0), 81)
	Engine.advance(Constants.TNT_FUSE - 0.15)
	check("up in the air: not yet...", firedSince(mf, "Blast", nil) == nil)
	Engine.advance(0.3)
	local fuse = firedSince(mf, "Blast", nil)
	check("...then the fuse runs out and it goes off in the air", fuse and fuse.args[1].pos.Y > eye(blue).Y + 3)
	-- the blast itself (straight at the server's own explode): the core, line of sight, teammates, the push, the deck
	F = ws:GetAttribute("Frontline")
	whole(red)
	whole(red2)
	whole(blue2)
	local spot = Vector3.new(F - 10, 1, 40)
	stand(red, spot + Vector3.new(-3, 2, 0))
	stand(blue2, spot + Vector3.new(0, 2, 3)) -- (blue's own: on red's turf just for this)
	stand(red2, spot + Vector3.new(7.5, 2, 0))
	local v0 = rootOf(red2).AssemblyLinearVelocity
	Arena:AddBox("test_block", spot + Vector3.new(-2, -1, -3), spot + Vector3.new(-1.2, 6, 3))
	local mx = mark()
	Combat:_explode({ id = 901, by = blue, team = "blue" }, spot)
	check("in the core but behind something solid: safe (line of sight)", Combat:Alive(red))
	check("a teammate in the core is never hurt", Combat:Alive(blue2))
	check(
		"in the blast, out of the core: thrown back, not knocked out",
		Combat:Alive(red2) and rootOf(red2).AssemblyLinearVelocity.X > v0.X + 5
	)
	check("...and told (the push for its own client)", firedSince(mx, "Hurt", red2, function(a)
		return a[1].blast == true and a[1].amount == 0 and a[1].knock.X > 0
	end) ~= nil)
	Arena:RemoveBox("test_block")
	Combat:_explode({ id = 902, by = blue, team = "blue" }, spot)
	check("...in the open: knocked out", not Combat:Alive(red))
	-- the spawn deck keeps you safe until you shoot, TNT or not
	Engine.advance(Constants.RESPAWN_SECONDS + 0.5)
	whole(red)
	local deck = Arena:SpawnFor("red", 1).Position
	stand(red, deck)
	check("(standing on red's spawn deck)", Arena:OnDeck(red, "red"))
	Combat:_explode({ id = 903, by = blue, team = "blue" }, rootOf(red).Position + Vector3.new(1, -1.5, 0))
	check("on your own spawn deck: safe from the TNT too", Combat:Alive(red))
	whole(red)
	whole(red2)
	whole(blue)
	whole(blue2)
	send(blue, "Equip", "bow")
	send(blue2, "Equip", "bow")
end

-- Pushing a team out -------------------------------------------------------------------------------------------
Engine.advance(30) -- (well past the qualifying time by the end)
-- (these players have seen their first match's shop: the cards after this win are the ones checked here;
-- tests/GiftSmoke has the first match's own end)
for _, p in Engine.Players:GetPlayers() do
	local prof = Data:Get(p)
	if prof then
		prof.gifts.firstShop = true
	end
end
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
	"a 15 s countdown to the next game (time to see the shop)",
	math.abs(ws:GetAttribute("PhaseEnds") - Engine.workspace:GetServerTimeNow() - 15) < 1,
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
local askLoser = firedSince(mAsk, "Ask", blue)
check("...the losers too (the ones who'd say why not)", askLoser and askLoser.args[1].kind == "enjoy")
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
	-- the win pays on its own (VICTORY), apart from playing the match, each flying to the counter
	local whys = {}
	for i = m5 + 1, #Engine.clientLog do
		local ev = Engine.clientLog[i]
		if ev.name == "Earned" and ev.player == red then
			whys[ev.args[1].why] = ev.args[1].amount
		end
	end
	check(
		"a win: VICTORY Shards and MATCH PLAYED Shards, each its own",
		(whys.win or 0) >= Engine.require(tree.shared.Data.Shop).EARN.win and (whys.match or 0) > 0,
		`{whys.win} {whys.match}`
	)
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
	check("a NO without a reason isn't taken (they must say why)", not (Data:Get(blue).extras or {}).thanks)
	send(blue, "Feedback", "enjoy", false, { "made_up" })
	check("...nor with only a made-up one", not (Data:Get(blue).extras or {}).thanks)
	send(blue, "Feedback", "enjoy", false, { "hard", "lag" })
	check(
		"a NO with its reasons is taken, kept, and gets the Thank-You Trail too",
		Data:Get(blue).extras.thanks == true and Data:Get(blue).feedback.reasons[2] == "lag",
		`{tostring(Data:Get(blue).extras.thanks)} {table.concat(Data:Get(blue).feedback.reasons or {}, ",")}`
	)
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
	check(
		"an item not in today's four can be bought too (everything is for sale, every day)",
		p.owned[notToday] and p.shards == before - Shop.price(Cosmetics.get(notToday))
	)
	before = p.shards
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
	-- a save that fails: not granted yet (Roblox asks again), and the retry doesn't give it twice
	Engine.dataStoreFails = true
	local d2 = receipt("buy-save", 9001)
	check("a purchase whose save fails: not granted yet", d2 == Enum.ProductPurchaseDecision.NotProcessedYet, d2)
	Engine.dataStoreFails = false
	local d3 = receipt("buy-save", 9001)
	check(
		"...Roblox asks again: granted once it's saved, given only once",
		d3 == Enum.ProductPurchaseDecision.PurchaseGranted and p.shards == s0 + 2 * Shop.PACKS[2].shards,
		`{d3} {p.shards}`
	)
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
	-- a bundle's EQUIP NOW: a few at once in one request, still only what you own
	p.owned.shop_barcode, p.owned.shop_diamond, p.owned.shop_overcharge = true, true, nil
	send(red, "Settings", "equip", {
		{ kind = "banner", key = "shop_diamond" },
		{ kind = "trail", key = "shop_barcode" },
		{ kind = "skin", key = "shop_overcharge" },
	})
	check(
		"EQUIP NOW: a few at once",
		p.equipped.trail == "shop_barcode"
			and p.equipped.banner == "shop_diamond"
			and p.equipped.skin ~= "shop_overcharge"
	)
	-- the shop's first-time tour, remembered
	send(red, "Settings", "shopTour", "yes")
	check("the shop tour setting takes only true or false", p.settings.shopTour == nil)
	send(red, "Settings", "shopTour", true)
	check("...the tour seen is kept in the profile", p.settings.shopTour == true)
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

-- The Rally Banner: the team comes back to life beside it while it stands -----------------------------------------
do
	Match:NewMatch()
	Engine.advance(1)
	local team = Teams:Team(red)
	local mate, foe
	for _, p in { ava, ben, cy, dee } do
		if p ~= red and p.Parent and Teams:Team(p) == team then
			mate = p
		elseif p.Parent and Teams:Team(p) and Teams:Team(p) ~= team then
			foe = p
		end
	end
	local fwd = Formulas.forward(team)
	local sx = -fwd * 40
	stand(red, Vector3.new(sx, 3, -12))
	Build:Refill()
	local m0 = mark()
	local banner
	for _, dz in { -12, -4, 4, -20, 12, 20, -28, 28 } do
		for _, dx in { 0, 4, -4, 8 } do
			if not banner then
				local ok, st =
					Build:Place(red, "banner", Formulas.cellOf(sx + dx, dz), select(2, Formulas.cellOf(0, dz)), 0)
				if ok then
					banner = st
				end
			end
		end
	end
	check("a Rally Banner goes up", banner ~= nil)
	if banner then
		local function toastSince(m, p, words)
			return firedSince(m, "Toast", p, function(a)
				return string.find(tostring(a[1]), words, 1, true) ~= nil
			end) ~= nil
		end
		check(
			"...its team hears it",
			toastSince(m0, red, "Rally Banner up") and (not mate or toastSince(m0, mate, "Rally Banner up"))
		)
		check("...the other side doesn't", not foe or not toastSince(m0, foe, "Rally"))
		local glow, light, tag = banner.model:FindFirstChild("RallyGlow"), false, false
		for _, d in banner.model:GetDescendants() do
			light = light or d:IsA("PointLight")
			tag = tag or d.Name == "RallyTag"
		end
		check("...it glows a little and wears a RALLY tag", glow ~= nil and light and tag)
		-- one a team
		local again, whyAgain = Build:Place(red, "banner", banner.cx, banner.cz + 2, 0)
		check(
			"one Rally Banner a team: a second is refused",
			not again and tostring(whyAgain):find("already") ~= nil,
			whyAgain
		)
		if mate then
			local mateTry, mateWhy = Build:Place(mate, "banner", banner.cx, banner.cz - 2, 0)
			check("...a team-mate's too", not mateTry and tostring(mateWhy):find("already") ~= nil, mateWhy)
		end
		-- down and back up: beside it, not in the spawn room, protected as anywhere
		local bc = (banner.boxMin + banner.boxMax) / 2
		local a = Arena:Current()
		local function insideSomething(pos)
			for _, b in Arena:Solids() do
				if
					b.part ~= a.strips[1]
					and pos.X > b.min.X - 0.5
					and pos.X < b.max.X + 0.5
					and pos.Z > b.min.Z - 0.5
					and pos.Z < b.max.Z + 0.5
					and pos.Y - 2.5 < b.max.Y
					and pos.Y + 2.5 > b.min.Y
				then
					return true
				end
			end
			return false
		end
		local m1 = mark()
		Combat:Kill(red, nil, { kind = "reset" })
		Engine.advance(Constants.RESPAWN_SECONDS + 1)
		local r = rootOf(red)
		local near = r and (Vector3.new(r.Position.X - bc.X, 0, r.Position.Z - bc.Z)).Magnitude
		check("down and back up: beside the Rally Banner", Combat:Alive(red) and near ~= nil and near < 12, near)
		check(
			"...on your own side, a cell back from the line",
			r and (Match:Frontline() - r.Position.X) * fwd >= Constants.CELL - 0.01,
			r and r.Position.X
		)
		check("...never inside a wall or a shape", r and not insideSomething(r.Position))
		check("...with spawn protection", firedSince(m1, "Me", red, function(m)
			return m[1].protected == true
		end) ~= nil)
		-- walled in behind: the spot moves to a free cell, never into a piece
		Build:Refill()
		local walled = 0
		for dz = -1, 1 do
			if Build:Place(red, "cover", banner.cx - fwd, banner.cz + dz, 0) then
				walled += 1
			end
		end
		local cf = Build:RallySpawn(red)
		check(
			"...walled in behind it: a free cell instead",
			walled > 0 and cf ~= nil and not insideSomething(cf.Position),
			walled
		)
		-- the line passes it: no rallying on turf that's been lost (ClearLost takes it down too)
		Build:SetFrontline(function()
			return bc.X - fwd * 6
		end)
		check("its turf lost: nobody rallies there", Build:RallySpawn(red) == nil and Build:Rally(team) == nil)
		Build:SetFrontline(function()
			return Match:Frontline()
		end)
		check("...the line back: it counts again", Build:RallySpawn(red) ~= nil)
		-- knocked down: the team hears it, and it's the spawn room again
		local m2 = mark()
		Build:Remove(banner.id, foe, false)
		check("knocked down: the team hears it", toastSince(m2, red, "Rally Banner fell"))
		check("...and nobody rallies there", Build:Rally(team) == nil and Build:RallySpawn(red) == nil)
		Combat:Kill(red, nil, { kind = "reset" })
		Engine.advance(Constants.RESPAWN_SECONDS + 1)
		r = rootOf(red)
		check("...back in the spawn room", Combat:Alive(red) and r and r.Position.X * fwd < -60, r and r.Position.X)
		-- a new one may go up once the old one's down
		Build:Refill()
		stand(red, Vector3.new(sx, 3, -12))
		local okNew = Build:Place(red, "banner", banner.cx, banner.cz, 0)
		check("...and a new Rally Banner may go up", okNew == true)
	end
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
	local s0 = AC:Strikes(cheat)
	Engine.advance(AC.AIR_SECONDS + 3)
	check("hovering high for seconds: flying", flagsOf("fly") >= 1)
	check("...logged, but no strike (knockback and towers set it off for honest players)", AC:Strikes(cheat) <= s0)
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

-- the spawn deck: open (no walls), and safe by rule until you shoot
do
	service("BotService"):SetEnabled(false) -- (no bot shooting the one being tested)
	local victim = Engine.addPlayer("Deck", 611)
	local shooter = Engine.addPlayer("Archer", 612)
	Engine.advance(0.5)
	send(victim, "Ready")
	send(shooter, "Ready")
	Engine.advance(0.5)
	if Teams:Team(victim) == Teams:Team(shooter) then
		Teams:Set(shooter, Teams:Team(victim) == "red" and "blue" or "red")
	end
	Match:NewMatch()
	Engine.advance(0.5)
	Match:SkipTo("fight")
	Engine.advance(Constants.SPAWN_PROTECT + 0.5)
	local deck = Arena:SpawnFor(Teams:Team(victim), 1)
	Engine.moveTo(victim, deck.Position)
	check(
		"on your own spawn deck",
		Arena:OnDeck(victim, Teams:Team(victim)),
		`{rootOf(victim) and rootOf(victim).Position} {deck.Position} {Teams:Team(victim)}`
	)
	check("...nobody can hurt you there", Combat:Damage(victim, 10, shooter) == false)
	Combat:Equip(victim, "bow")
	Engine.advance(1)
	Combat:Shoot(victim, rootOf(victim).Position + Vector3.new(0, 1.5, 0), Vector3.new(1, 0, 0))
	check("...until you shoot", Combat:Damage(victim, 10, shooter) == true)
	service("BotService"):SetEnabled(true)
end

-- the AFK limbo: standing still in a match sends you to a room above the arena; walking around there brings you back
do
	local Afk = service("AfkService")
	local idle = Engine.addPlayer("Idle", 621)
	local mover = Engine.addPlayer("Mover", 622)
	Engine.advance(0.5)
	send(idle, "Ready")
	send(mover, "Ready")
	Engine.advance(0.5)
	Match:NewMatch()
	Engine.advance(1)
	check("a match is on", Match:Phase() == "build" or Match:Phase() == "fight", Match:Phase())
	Constants.AFK_SECONDS = 6
	Constants.AFK_JOIN_GRACE = 0 -- (just joined: normally never sent)
	for _ = 1, 25 do
		if Afk:Away(idle) then
			break
		end
		-- (the mover walks about; the idle one doesn't)
		local r = rootOf(mover)
		if r then
			Engine.moveTo(mover, r.Position + Vector3.new(0, 0, 3))
		end
		Engine.advance(1)
	end
	check("standing still: off to the AFK room", Afk:Away(idle) and Teams:Team(idle) == nil)
	check("...out of the match (not counted)", not table.find(Match:People(), idle))
	check("...up in the room", rootOf(idle) and rootOf(idle).Position.Y > 500, rootOf(idle) and rootOf(idle).Position)
	check("...and told how to come back", firedSince(0, "Announce", idle, function(a)
		return string.find(a[1].text, "AFK") ~= nil
	end) ~= nil)
	check("someone moving stays in", not Afk:Away(mover) and Teams:Team(mover) ~= nil)
	Engine.moveTo(idle, rootOf(idle).Position + Vector3.new(6, 0, 0))
	Engine.advance(1.5)
	check("walking around in the room: back in the game", not Afk:Away(idle) and Teams:Team(idle) ~= nil)
	check("...on the field again", rootOf(idle) and rootOf(idle).Position.Y < 100)
	-- the hall: columns, crown molding, and three leaderboards on the far wall
	local hall = ws:FindFirstChild("Limbo")
	check("the AFK hall is built (detailed)", hall and #hall:GetChildren() > 120, hall and #hall:GetChildren())
	local lit = false
	for _, d in hall and hall:GetDescendants() or {} do
		lit = lit or d.ClassName == "PointLight"
	end
	check("...a lamp lights it", lit)
	Afk:RefreshBoards()
	for _, key in Afk.BOARD_KEYS do
		local b = hall and hall:FindFirstChild("LimboBoard_" .. key)
		local rows = b and b.Board.Rows
		local first = rows and (rows:FindFirstChild("Row1") or rows:FindFirstChild("Empty"))
		check(`...a {key} board with rows`, first ~= nil and first.Text ~= "", first and first.Text)
	end
	Constants.AFK_SECONDS = 0
end

-- a new player's whisper of aim help: a near miss turns a hair onto the enemy; a real miss, or a veteran, doesn't
do
	local newbie = Engine.addPlayer("Newbie", 641)
	local foe = Engine.addPlayer("Foe", 642)
	Engine.advance(0.5)
	send(newbie, "Ready")
	send(foe, "Ready")
	Engine.advance(0.5)
	if Teams:Team(newbie) == Teams:Team(foe) then
		Teams:Set(foe, Teams:Team(newbie) == "red" and "blue" or "red")
	end
	Combat:Spawned(newbie)
	Combat:Spawned(foe)
	stand(newbie, Vector3.new(-40, 3, 0))
	stand(foe, Vector3.new(20, 3, 0))
	local origin = Vector3.new(-40, 4.5, 0)
	local speed = 200
	local function angleTo(dir)
		local tt = (Vector3.new(20, 3.6, 0) - origin).Magnitude / speed
		local ideal = (Vector3.new(20, 3.6 + 0.5 * Constants.GRAVITY * tt * tt, 0) - origin).Unit
		return math.deg(math.acos(math.clamp(dir:Dot(ideal), -1, 1))), ideal
	end
	local _, ideal = angleTo(Vector3.new(1, 0, 0))
	local off3 = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.rad(3)) * ideal).Unit
	local a0 = angleTo(off3)
	-- (the whisper alone: past the first matches' extra help, tests/FeelSmoke checks that)
	Data:Get(newbie).stats.matches = Constants.NEW_PLAYER_MATCHES
	local a1 = angleTo(Combat:Assist(newbie, origin, off3, speed))
	check(
		"a near miss (3°) turns a little onto them",
		a1 < a0 - 0.5 and a1 > a0 - Constants.AIM_ASSIST_MAX - 0.05,
		`{a0} -> {a1}`
	)
	local off10 = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.rad(10)) * ideal).Unit
	check("...a real miss (10°) stays a miss", angleTo(Combat:Assist(newbie, origin, off10, speed)) > 9.99)
	Data:Get(newbie).stats.matches = Constants.AIM_ASSIST_MATCHES
	check(
		"...and after their first matches, no help at all",
		math.abs(angleTo(Combat:Assist(newbie, origin, off3, speed)) - a0) < 0.001
	)
	Engine.removePlayer(newbie)
	Engine.removePlayer(foe)
	Engine.advance(1)
end

-- joining a game that's already going: a team and a body at once, in this match (never left out until the next)
do
	Match:SkipTo("fight")
	Engine.advance(0.5)
	local matchId = ws:GetAttribute("MatchId")
	local late = Engine.addPlayer("Latecomer", 651)
	Engine.advance(0.5)
	send(late, "Ready")
	Engine.advance(1.5)
	check("joining mid-game: on a team at once", Teams:Team(late) ~= nil, Teams:Team(late))
	check("...in the game now, alive", Combat:Alive(late) and rootOf(late) ~= nil)
	check("...the same match goes on", ws:GetAttribute("MatchId") == matchId)
	Engine.advance(10)
	check("...and not sent off as AFK while settling in", not service("AfkService"):Away(late))
	Engine.removePlayer(late)
	Engine.advance(1)
end

-- leave and come back before the match ends: the same side, and straight back in (never stuck "respawning")
do
	local r1 = Engine.addPlayer("Rejoin", 631)
	local o1 = Engine.addPlayer("Other", 632)
	Engine.advance(0.5)
	send(r1, "Ready")
	send(o1, "Ready")
	Engine.advance(0.5)
	Match:NewMatch()
	Engine.advance(1)
	Match:SkipTo("fight")
	Engine.advance(0.5)
	local was = Teams:Team(r1)
	local matchId = ws:GetAttribute("MatchId")
	Engine.removePlayer(r1)
	Engine.advance(2)
	local r2 = Engine.addPlayer("Rejoin", 631)
	Engine.advance(0.5)
	send(r2, "Ready")
	Engine.advance(1.5)
	check("rejoining the same match: the side you were on", Teams:Team(r2) == was, `{Teams:Team(r2)} {was}`)
	check("...the match goes on (no restart)", ws:GetAttribute("MatchId") == matchId)
	check("...and you're back in, alive", Combat:Alive(r2) and rootOf(r2) ~= nil)
	local look = rootOf(r2) and rootOf(r2).CFrame.LookVector
	check("...facing the line", look and look.X * Formulas.forward(Teams:Team(r2)) > 0.95, look)
	-- a body that goes missing (it never loaded, it fell apart): the server puts them back in on its own
	r2.Character:Destroy()
	r2.Character = nil
	local back = false
	for _ = 1, 20 do
		Engine.advance(0.5)
		if r2.Character and rootOf(r2) and Combat:Alive(r2) then
			back = true
			break
		end
	end
	check("no body and nothing coming: put back in within seconds", back)
	Engine.removePlayer(r2)
	Engine.removePlayer(o1)
	Engine.advance(1)
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
