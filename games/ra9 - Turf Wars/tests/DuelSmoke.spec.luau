--[[
The lobby's duels (DuelService, DuelController, World/DuelArena) on the mock engine, in the lobby mode: the place
boots without MatchService or TeamService; the pads queue you (stepping on, the prompt) and let you go (stepping
off, CANCEL); a full queue counts down and starts a 1v1 and a 2v2; a party is kept together on one side; the arena
is built far out past the plaza with both decks, nothing brown, and reused slots; CombatService takes the sides from
DuelService (no friendly fire, the plaza can't be hurt); knockouts score rounds, the first side to 5 wins and is paid
(DUEL), the result card and the scoreboard show on the client, REMATCH queues again, a leaver forfeits, the cap
ends a duel, and the teardown leaves nothing.

  luaurun tests/DuelSmoke.spec.luau
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
local Constants = Engine.require(tree.shared.Constants)
Constants.applyMode("lobby")
Constants.TUTORIAL = false
Constants.AFK_SECONDS = 0
Engine.clientEnabled = true
local ws = Engine.workspace
local Players = Engine.Players

-- The lobby place boots its own small set by hand (no match: no MatchService, no TeamService, no BuildService), the
-- way Main.server does: the saves first, then every service's OnPlayerReady
local Net = Engine.require(tree.shared.Net)
Net.init()
local Loader = Engine.require(tree.server.Loader)
local registry, order = Loader.boot(tree.server.Services, {
	PlayerDataService = true,
	ArenaService = true,
	CombatService = true,
	EconomyService = true,
	DuelService = true,
})
local Data = registry.PlayerDataService
Players.PlayerAdded:Connect(function(player)
	local profile = Data:Load(player)
	if not profile or not player.Parent then
		return
	end
	for _, hook in { "OnPlayerLoaded", "OnPlayerReady" } do
		for _, svc in order do
			if svc[hook] then
				svc[hook](svc, player, profile)
			end
		end
	end
end)
Players.PlayerRemoving:Connect(function(player)
	local profile = Data:Get(player)
	if profile then
		for i = #order, 1, -1 do
			local svc = order[i]
			if svc.OnPlayerLeaving then
				svc:OnPlayerLeaving(player, profile)
			end
		end
	end
	Data:Release(player)
end)
Engine.advance(0.5)
local Duel = registry.DuelService
local Combat = registry.CombatService
local Arena = registry.ArenaService
local Maps = Engine.require(tree.shared.Data.Maps)

check("the lobby boots without MatchService", registry.MatchService == nil and registry.DuelService ~= nil)
check("...and without TeamService (DuelService is CombatService's team provider)", registry.TeamService == nil)
check("the blade is always allowed in the lobby (the CHARGE stays on)", ws:GetAttribute("Charge") == true)
check("nothing failed booting", #Engine.errors == 0, Engine.errors[1])
local padsFolder = ws:FindFirstChild("DuelPads")
check("four pads wired, a prompt each", padsFolder ~= nil and #Engine.prompts(padsFolder) == 4)

-- Helpers ------------------------------------------------------------------------------------------------------
local function join(name, id)
	local p = Engine.addPlayer(name, id)
	Engine.advance(1)
	Engine.fireServer(p, "Ready")
	p:LoadCharacter()
	Engine.moveTo(p, Vector3.new(0, 3, 0)) -- (on the plaza)
	Engine.advance(0.5)
	return p
end
local function rootOf(p)
	return p.Character and p.Character:FindFirstChild("HumanoidRootPart")
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
local function duelEvent(m, player, kind)
	local e = since(m, "Duel", player, function(args)
		return type(args[1]) == "table" and args[1].kind == kind
	end)
	return e and e.args[1]
end
local function step(p, padIndex)
	Engine.moveTo(p, Constants.DUEL_PADS[padIndex] + Vector3.new(1, 3, 0))
	Engine.advance(0.5)
end
local function promptOf(size)
	for _, pr in Engine.prompts(padsFolder) do
		if pr.Parent:GetAttribute("Size") == size then
			return pr
		end
	end
	return nil
end
local function tap(p, size)
	promptOf(size).Triggered:Fire(p)
	Engine.advance(0.3)
end
-- knock someone out in a duel: out in the open, past the spawn protection, by someone on the other side
local function knockOut(victim, killer)
	local d = Duel:Of(victim)
	Engine.moveTo(victim, d.arena.origin + Vector3.new(10, 3, 0))
	Engine.moveTo(killer, d.arena.origin + Vector3.new(-10, 3, 0))
	local ok, killed = Combat:Damage(victim, 100, killer, { weapon = "bow", kind = "arrow", head = false })
	Engine.advance(0.3)
	return ok and killed
end
-- a round just started: everyone is back, protected for a moment
local function nextRound()
	Engine.advance(Constants.DUEL_ROUND_WAIT + Constants.SPAWN_PROTECT + 0.5)
end
local function partsOf(folder)
	local n, brown, far = 0, {}, true
	local o = folder:GetAttribute("Slot")
	local z0 = Constants.DUEL_ORIGIN_Z - (o - 1) * Constants.DUEL_GAP
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			if math.abs(d.CFrame.Position.Z - z0) > 200 or math.abs(d.CFrame.Position.X) > 200 then
				far = false
			end
			local c = d.Color
			local r, g, b = c.R, c.G, c.B
			local mx, mn = math.max(r, g, b), math.min(r, g, b)
			local sat = mx > 0 and (mx - mn) / mx or 0
			local hue = mx == mn and 0 or (mx == r and 60 * (((g - b) / (mx - mn)) % 6) or -1)
			if d.Transparency < 1 and mx == r and hue >= 12 and hue <= 50 and sat > 0.2 and mx < 0.85 then
				table.insert(brown, d.Name)
			end
		end
	end
	return n, brown, far
end

-- 1. The queue: stepping on, stepping off, the prompt, CANCEL ------------------------------------------------------
local ava = join("Ava", 501)
Engine.Players.LocalPlayer = ava
Engine.localPlayer = ava
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local ben = join("Ben", 502)
check("the client booted", #Engine.errors == 0, Engine.errors[1])
local DuelC = Engine.require(tree.client.Controllers.DuelController)
local HudC = Engine.require(tree.client.Controllers.HudController)
local Store = Engine.require(tree.client.Store)

local m = mark()
step(ava, 1)
local q = duelEvent(m, ava, "queue")
check("stepping on the 1v1 pad joins its queue", #Duel:Queue(1) == 1 and Duel:Queue(1)[1] == ava)
check("...the chip: 1v1 · 1/2 ready", q ~= nil and q.size == 1 and q.n == 1 and q.of == 2 and q.seconds == nil)
check(
	"...on screen",
	DuelC.refs.chip.Visible == true and DuelC.refs.chipText.Text == "1v1 · 1/2 ready",
	DuelC.refs.chipText.Text
)
m = mark()
Engine.moveTo(ava, Vector3.new(0, 3, 0))
Engine.advance(0.5)
check("stepping off leaves it", #Duel:Queue(1) == 0)
check("...the chip goes", duelEvent(m, ava, "queue") ~= nil and duelEvent(m, ava, "queue").off == true)
check("...on screen too", DuelC.refs.chip.Visible == false)

step(ava, 1)
m = mark()
tap(ben, 1)
q = duelEvent(m, ben, "queue")
check("the prompt joins too: 2/2", #Duel:Queue(1) == 2 and q ~= nil and q.n == 2)
check("...a full queue counts down", q.seconds ~= nil and q.seconds > 4 and q.seconds <= 5, q.seconds)
m = mark()
Engine.fireServer(ben, "Duel", "cancel")
Engine.advance(0.3)
q = duelEvent(m, ava, "queue")
check("CANCEL leaves the queue", #Duel:Queue(1) == 1)
check("...and stops the countdown", q ~= nil and q.n == 1 and q.seconds == nil)
check("...a prompt joiner isn't on the pad, so nothing else moves them", Duel:Queue(1)[1] == ava)
check("no duel yet", #Duel:List() == 0)

-- 2. A 1v1 starts: the arena far out, both decks, the sides -----------------------------------------------------
tap(ben, 1)
m = mark()
Engine.advance(Constants.DUEL_COUNTDOWN + 1)
local d1 = Duel:Of(ava)
check("the countdown ends and the duel starts", d1 ~= nil and Duel:Of(ben) == d1 and #Duel:List() == 1)
check("...the queue is empty", #Duel:Queue(1) == 0)
check("...the chip is gone", DuelC.refs.chip.Visible == false)
check("...two sides", d1 and d1.side[ava] ~= nil and d1.side[ben] ~= nil and d1.side[ava] ~= d1.side[ben])
check(
	"...marked on the players",
	ava:GetAttribute("Duel") == d1.id
		and ava:GetAttribute("DuelSide") == d1.side[ava]
		and ava:GetAttribute("Team") == d1.side[ava]
)
check(
	"CombatService sees the sides through DuelService",
	Duel:Team(ava) == d1.side[ava] and Duel:Team(ben) == d1.side[ben]
)
local me = since(m, "Me", ava)
check("...Me carries the side", me ~= nil and me.args[1].team == d1.side[ava], me and me.args[1].team)
local st = duelEvent(m, ava, "start")
check(
	"the start: your side, the map, first to 5, the clock",
	st ~= nil and st.side == d1.side[ava] and st.map == d1.def.key and st.rounds == 5 and st.endsAt ~= nil
)
local folder = ws:FindFirstChild("Duel1")
check("the arena stands in slot 1", folder ~= nil and d1.slot == 1 and d1.arena.folder == folder)
check("...far out past the plaza", d1.arena.origin.Z == -800 and d1.arena.origin.X == 0, d1.arena.origin.Z)
local n, brown, far = partsOf(folder)
check("...all of it there (no skyline wandering off)", far and n > 300, n)
check("...nothing brown", #brown == 0, table.concat(brown, ","))
check(
	"...both decks, red west and blue east",
	#d1.arena.spawns.red >= 1
		and #d1.arena.spawns.blue >= 1
		and d1.arena.spawns.red[1].Position.X < -60
		and d1.arena.spawns.blue[1].Position.X > 60
		and math.abs(d1.arena.spawns.red[1].Position.Z + 800) < 60
)
check("...its solids count for every arrow", #Arena:Solids() == #d1.arena.solids and #d1.arena.solids > 50)
check("...and it's inside the world", Arena:Inside(d1.arena.origin + Vector3.new(0, 5, 0)))
local function onOwnDeck(p)
	local r = rootOf(p)
	return r ~= nil and Arena:OnDeck(p, d1.side[p]) and math.abs(r.Position.Z + 800) < 60
end
check("both stand on their decks, alive", onOwnDeck(ava) and onOwnDeck(ben) and Combat:Alive(ava) and Combat:Alive(ben))
check("...dressed in their side", ava.Character:GetAttribute("Team") == d1.side[ava])
check("...the round began: ROUND 1", duelEvent(m, ava, "round") ~= nil and duelEvent(m, ava, "round").n == 1)
check("...with the horn and the banner", since(m, "Alert", ava, function(a)
	return a[1] == "ROUND 1"
end) ~= nil)
check("the fight is on", Combat:Enabled() == true)
check("...the TNT is refused", Combat.allowed("tnt", ava) == false and Combat.allowed("blade", ava) == true)
check("...no comeback shield, no new-player help", not Combat.comebackShield and not Combat.newPlayerHelp)
check(
	"the client plays a fight: the scoreboard where the frontline bar was",
	DuelC.state().duel ~= nil
		and DuelC.refs.board.Visible == true
		and HudC.refs.bar.Visible == false
		and Store.get("match").phase == "fight",
	Store.get("match").phase
)

-- 3. Knockouts score rounds; the first to 5 wins and is paid ------------------------------------------------------
check("on your deck you're safe until you shoot", Combat:Damage(ben, 100, ava) == false)
Engine.advance(Constants.SPAWN_PROTECT + 0.5)
m = mark()
check("a knockout in the open", knockOut(ben, ava) == true)
local kill = since(m, "Kill", ava)
check("...the kill feed and the kill cam, with the sides", kill ~= nil and kill.args[1].killerTeam == d1.side[ava])
local re = duelEvent(m, ava, "roundEnd")
check("...the round to the side left standing", re ~= nil and re.winner == d1.side[ava] and re.score[d1.side[ava]] == 1)
check("...the banner", since(m, "Alert", ben, function(a)
	return a[1] == `{Constants.DUEL_SIDE_NAME[d1.side[ava]]} WINS THE ROUND`
end) ~= nil)
local earned = since(m, "Earned", ava)
check(
	"...3 Shards for the knockout, labelled DUEL",
	earned ~= nil and earned.args[1].amount == 3 and earned.args[1].why == "duel"
)
check(
	"...the scoreboard",
	DuelC.refs.redScore.Text == `RED {d1.score.red}` and DuelC.refs.blueScore.Text == `{d1.score.blue} BLUE`
)
m = mark()
nextRound()
check(
	"the next round: everyone back on their deck",
	duelEvent(m, ava, "round") ~= nil and duelEvent(m, ava, "round").n == 2
)
check("...alive again", Combat:Alive(ben) and onOwnDeck(ben) and onOwnDeck(ava))
check("...ROUND 2 on screen", DuelC.refs.roundText.Text == "ROUND 2 · FIRST TO 5", DuelC.refs.roundText.Text)
for _ = 1, 3 do
	knockOut(ben, ava)
	nextRound()
end
check("four rounds up, still on", d1.score[d1.side[ava]] == 4 and d1.phase == "round")
m = mark()
knockOut(ben, ava)
Engine.advance(0.5)
check("the fifth round wins it", d1.phase == "over" and d1.winner == d1.side[ava])
local win = duelEvent(m, ava, "result")
local loss = duelEvent(m, ben, "result")
check(
	"the result: VICTORY for one, DEFEAT for the other",
	win ~= nil and win.won == true and loss ~= nil and loss.won == false
)
check("...20 Shards for the win (DUEL)", win.shards == 20 and since(m, "Earned", ava, function(a)
	return a[1].amount == 20 and a[1].why == "duel"
end) ~= nil)
check(
	"...the tally: 5 knockouts, 35 Shards",
	Data:Get(ava).shards == 35 and Data:Get(ben).shards == 0,
	Data:Get(ava).shards
)
check("...on the profiles", Data:Get(ava).stats.duelWins == 1 and Data:Get(ben).stats.duelLosses == 1)
check(
	"...the card on screen: VICTORY, REMATCH, BACK TO LOBBY",
	DuelC.refs.result ~= nil
		and DuelC.refs.result.Head.Title.Text == "VICTORY"
		and DuelC.refs.rematch.Visible == true
		and DuelC.refs.back ~= nil
)
check("...the scoreboard steps aside for it", DuelC.refs.board.Visible == false)

-- 4. REMATCH: back in the queue, a new duel in the next slot (the old arena still stands for the card) ------------
m = mark()
Engine.fireServer(ava, "Duel", "rematch")
Engine.fireServer(ben, "Duel", "rematch")
Engine.advance(0.5)
check("REMATCH takes you out of the duel and into the pad's queue", Duel:Of(ava) == nil and #Duel:Queue(1) == 2)
check("...told how many are in", duelEvent(m, ava, "rematch") ~= nil and duelEvent(m, ava, "rematch").n >= 1)
check("...the card closed, the lobby's HUD back", DuelC.refs.result == nil and Store.get("match").phase ~= "fight")
check(
	"...home by the pad, not on it",
	rootOf(ava) ~= nil
		and (rootOf(ava).Position - Constants.DUEL_PADS[1]).Magnitude < 20
		and ava:GetAttribute("Duel") == nil
)
Engine.advance(Constants.DUEL_COUNTDOWN + 1)
local d2 = Duel:Of(ava)
check("the rematch starts", d2 ~= nil and d2 ~= d1 and Duel:Of(ben) == d2)
check(
	"...in the next slot while the old arena stands",
	d2.slot == 2 and d2.arena.origin.Z == -1100 and ws:FindFirstChild("Duel1") ~= nil
)
check("...on a different map", d2.def.key ~= d1.def.key, d2.def.key)
Engine.advance(Constants.DUEL_RESULT_SECONDS)
check("the old arena comes down after the card", ws:FindFirstChild("Duel1") == nil and #Duel:List() == 1)
check("...slot 1 is free again (the next duel takes it)", #Arena:Solids() == #d2.arena.solids)

-- 5. A leaver forfeits: a side left empty loses -------------------------------------------------------------------
local benProfile = Data:Get(ben)
m = mark()
Engine.removePlayer(ben)
Engine.advance(0.5)
check("a leaver forfeits: the other side wins", d2.phase == "over" and d2.winner == d2.side[ava])
check("...a loss on the leaver's save", benProfile.stats.duelLosses == 2, benProfile.stats.duelLosses)
check("...a win for the one left", duelEvent(m, ava, "result") ~= nil and duelEvent(m, ava, "result").won == true)
Engine.fireServer(ava, "Duel", "leave")
Engine.advance(0.5)
check("BACK TO LOBBY after the result: home at once", Duel:Of(ava) == nil and ava:GetAttribute("Duel") == nil)
Engine.advance(Constants.DUEL_RESULT_SECONDS + 1)
check("the teardown leaves nothing", ws:FindFirstChild("Duel2") == nil and #Duel:List() == 0 and #Arena:Solids() == 0)
check("...the fight is off", Combat:Enabled() == false)
check("...nothing failed so far", #Engine.errors == 0, Engine.errors[1])

-- 6. A 2v2 with a party kept together; no friendly fire; the plaza is safe; the cap ------------------------------
local cal, dan, eve, fay = join("Cal", 503), join("Dan", 504), join("Eve", 505), join("Fay", 506)
Duel:SetParties(function(p)
	if p == cal or p == dan then
		return { cal, dan }
	end
	return nil
end)
m = mark()
step(cal, 2)
check(
	"a party steps on together",
	#Duel:Queue(2) == 2 and duelEvent(m, dan, "queue") ~= nil and duelEvent(m, dan, "queue").n == 2
)
tap(eve, 2)
tap(fay, 2)
Engine.advance(Constants.DUEL_COUNTDOWN + 1)
local d3 = Duel:Of(cal)
check("the 2v2 starts", d3 ~= nil and d3.size == 2 and Duel:Of(fay) == d3)
check(
	"...the party on one side",
	d3.side[cal] == d3.side[dan] and d3.side[eve] == d3.side[fay] and d3.side[cal] ~= d3.side[eve]
)
check("...in slot 1 again", d3.slot == 1 and ws:FindFirstChild("Duel1") ~= nil)
Engine.advance(Constants.SPAWN_PROTECT + 0.5)
Engine.moveTo(dan, d3.arena.origin + Vector3.new(5, 3, 5))
check("no friendly fire", Combat:Damage(dan, 100, cal) == false)
check(
	"the plaza can't be hurt, and can't shoot in (out of the fight once home)",
	Combat:Damage(ava, 100, cal) == false and Combat:Alive(ava) == false
)
m = mark()
knockOut(eve, cal)
check("one down of two: the round goes on", d3.phase == "round" and duelEvent(m, cal, "roundEnd") == nil)
knockOut(fay, dan)
check("...both down: the round", d3.phase == "wait" and d3.score[d3.side[cal]] == 1)
nextRound()
check(
	"the next round brings all four back",
	Combat:Alive(eve) and Combat:Alive(fay) and Combat:Alive(cal) and Combat:Alive(dan)
)
m = mark()
d3.endsAt = Engine.now() -- (the cap runs out)
Engine.advance(0.5)
check("the cap: the side ahead on rounds wins", d3.phase == "over" and d3.winner == d3.side[cal])
check(
	"...the result for all four",
	duelEvent(m, dan, "result") ~= nil
		and duelEvent(m, eve, "result") ~= nil
		and duelEvent(m, eve, "result").won == false
)
Engine.advance(Constants.DUEL_RESULT_SECONDS + 1)
check("...and the teardown", #Duel:List() == 0 and ws:FindFirstChild("Duel1") == nil)
check("the phase pill's fight snapshot went with the duel (Ava's own)", Store.get("match").phase ~= "fight")
check("nothing failed", #Engine.errors == 0, Engine.errors[1])
_ = Maps

print(`DuelSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error("DuelSmoke failed")
end
