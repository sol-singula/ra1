--[[
Parties: a party that arrives by teleport forms again on one team (alone on one side, they get a bot each to fight); an invite and its
card (YES, NO, no answer in 20 s); the party on one team when it forms in the build phase and when a friend joins;
a party that forms in the fight waits for the next match; Rebalance evens the teams and never splits a party (one
bigger than half the server too); the max size; kick, leave, a new leader; a friend who joins (or follows you in)
gets "Party up?"; the leader's FIND A NEW SERVER teleports everyone together with the party in the teleport data;
the notifications.

  luaurun tests/PartySmoke.spec.luau
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
Engine.require(tree.shared.Constants).AFK_SECONDS = 0 -- (test players stand still: tests/ServerSmoke checks the AFK limbo on its own)
Engine.require(tree.shared.Constants).MIN_SIDE = 1 -- (the old minimum: these checks count the bots themselves; BotSmoke checks 2 v 2)
Engine.game.PlaceId = 4242
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Party = service("PartyService")
local Teams = service("TeamService")
local Bots = service("BotService")
local Match = service("MatchService")
local Constants = Engine.require(tree.shared.Constants)
Constants.BUILD_SECONDS = 60 -- (these checks were written around a long build phase; the game uses 20 s)

local function join(name, id, data)
	local p = Engine.addPlayer(name, id, nil, data)
	Engine.advance(1)
	Engine.fireServer(p, "Ready")
	Engine.advance(1)
	return p
end

-- the banners a player got since log index `from`
local function banners(p, from)
	local out = {}
	for i = from or 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.name == "Announce" and (e.player == p or e.player == "all") and e.args[1].kind == "party" then
			table.insert(out, e.args[1].text)
		end
	end
	return out
end
local function got(p, from, pattern)
	for _, t in banners(p, from) do
		if string.find(t, pattern) then
			return true
		end
	end
	return false
end
local function lastInvite(p, from)
	for i = #Engine.clientLog, from or 1, -1 do
		local e = Engine.clientLog[i]
		if e.name == "PartyInvite" and e.player == p then
			return e.args[1]
		end
	end
	return nil
end
local function state(p)
	local e = Engine.lastClientEvent("PartyState", p)
	return e and e.args[1]
end
local function members(p)
	local party = Party:Of(p)
	return party and #party.members or 0
end
local function same(list)
	local t = Teams:Team(list[1])
	for _, p in list do
		if Teams:Team(p) ~= t or t == nil then
			return false
		end
	end
	return true
end
local function mark()
	return #Engine.clientLog + 1
end

-- 1. A party arrives by teleport (two people, an empty server) --------------------------------------------------
local trip = { party = { id = "trip-1", leader = 912, members = { 911, 912 } } }
local h = join("Hana", 911, { teleportData = trip })
check("the first of a party to arrive: alone for now", Party:Of(h) == nil)
check("...with a bot (one person on)", #Bots:List() >= 1, #Bots:List())
local m0 = mark()
local ivo = join("Ivo", 912, { teleportData = trip })
check("the second arrives: the party forms again", Party:Of(h) ~= nil and Party:Of(h) == Party:Of(ivo))
check("...the old leader leads again", Party:Of(h) and Party:Of(h).leader == ivo)
check("...on one team (not the bot's side the takeover gave)", same({ h, ivo }), `{Teams:Team(h)} {Teams:Team(ivo)}`)
check("...and they hear it", got(ivo, m0, "back together"), table.concat(banners(ivo, m0), " | "))
check("...their clients get the party", state(ivo) and #state(ivo).members == 2)
local function botsAgainst(side)
	for _, b in Bots:List() do
		if Teams:Team(b) == side then
			return false
		end
	end
	return true
end
Engine.advance(1)
check("a party of two alone on one side: a bot each against them", #Bots:List() == 2, #Bots:List())
check("...all on the other team", botsAgainst(Teams:Team(h)))
Engine.advance(3)
check("...still two after a while", #Bots:List() == 2, #Bots:List())
local zed = join("Zed", 913)
Engine.advance(1)
check(
	"someone joins the other side: 2 against 1, so one bot stays, on their side (2 v 2)",
	Teams:Team(zed) ~= Teams:Team(h) and #Bots:List() == 1 and Teams:Team(Bots:List()[1]) == Teams:Team(zed),
	`{#Bots:List()} {Teams:Team(zed)} {Teams:Team(h)}`
)
do
	-- one more on Zed's side: even now, no bots
	local yan = join("Yan", 914)
	Engine.advance(1)
	check(
		"...one more joins them: 2 v 2 people, no bots",
		Teams:Team(yan) == Teams:Team(zed) and #Bots:List() == 0,
		#Bots:List()
	)
	-- and one more on the party's side: 3 v 2, a bot fills in for Zed's side
	local wes = join("Wes", 915)
	Engine.advance(1)
	if Teams:Team(wes) ~= Teams:Team(h) then
		Teams:Set(wes, Teams:Team(h))
		Bots:Ensure()
	end
	local filler = Bots:List()[1]
	check(
		"...3 v 2: one bot for the side that's short",
		#Bots:List() == 1 and filler and Teams:Team(filler) == Teams:Team(zed),
		#Bots:List()
	)
	Engine.removePlayer(wes)
	Engine.removePlayer(yan)
	Engine.advance(1)
end
Engine.removePlayer(zed)
Engine.advance(1)
check("...nothing broke", #Engine.errors == 0, Engine.errors[1])
Engine.removePlayer(h)
Engine.removePlayer(ivo)
Engine.advance(2)
check("the party ends when they go", #Party:List() == 0, #Party:List())

-- 2. Invites: NO, no answer, YES -----------------------------------------------------------------------------------
check("the build phase", Match:Phase() == "build", Match:Phase())
local ava = join("Ava", 901)
local ben = join("Ben", 902)
check("two strangers: one each (solo rule)", Teams:Team(ava) ~= Teams:Team(ben))
check("...no party card for strangers", lastInvite(ben) == nil)
m0 = mark()
Engine.fireServer(ava, "Party", "invite", ben.UserId)
Engine.advance(0.3)
local card = lastInvite(ben, m0)
check("an invite brings a card", card and card.name == "Ava" and card.kind == "invite" and card.seconds == 20)
check("...and a banner for each", got(ben, m0, "Ava wants you") and got(ava, m0, "You asked Ben"))
m0 = mark()
Engine.fireServer(ben, "Party", "decline")
Engine.advance(0.3)
check("NO: no party", Party:Of(ava) == nil and Party:Of(ben) == nil)
check("...and Ava hears it", got(ava, m0, "Ben said no"))
Party:Invite(ava, ben)
m0 = mark()
Engine.advance(Party.INVITE_SECONDS + 0.5)
check("no answer in 20 s: the card goes", lastInvite(ben, m0) and lastInvite(ben, m0).cancel == true)
check("...and Ava hears it", got(ava, m0, "did not answer"))
check("...a late YES does nothing", Party:Answer(ben, true) == false and Party:Of(ben) == nil)
local benTeam = Teams:Team(ben)
Party:Invite(ava, ben)
Engine.advance(0.3)
m0 = mark()
Engine.fireServer(ben, "Party", "accept")
Engine.advance(0.3)
local party = Party:Of(ava)
check("YES: the party forms", party and party == Party:Of(ben) and party.leader == ava)
check("...the one who asked leads", state(ben) and state(ben).leader == ava.UserId)
check("...on the leader's team, at once (build phase)", same({ ava, ben }) and Teams:Team(ben) ~= benTeam)
check(
	"...Ben respawns on his new side",
	ben.Character and ben.Character:GetAttribute("Team") == Teams:Team(ava),
	ben.Character and ben.Character:GetAttribute("Team")
)
check("...banners: joined", got(ava, m0, "Ben joined your party") and got(ben, m0, "You joined Ava's party"))
check("...and where the party is", got(ben, m0, "Your party is on " .. Constants.TEAM_NAME[Teams:Team(ava)]))
check("...the Party attribute (for everyone's lists)", ava:GetAttribute("Party") == party.id)

-- 3. Solo players still follow the solo rule; a friend gets "Party up?" ---------------------------------------
local cy = join("Cy", 903)
check("a solo newcomer joins the smaller team", Teams:Team(cy) ~= Teams:Team(ava))
local dee = join("Dee", 904)
check("...and the next one too", Teams:Team(dee) ~= Teams:Team(ava), Teams:Team(dee))
-- Eve is Ava's friend; Ava's side is ahead on turf, so the solo rule sends Eve to the other side
Engine.friends["901:905"], Engine.friends["905:901"] = true, true
local ahead = Teams:Team(ava)
Match:_setFrontline(ahead == "red" and 6 or -6)
m0 = mark()
local eve = join("Eve", 905)
check("a friend still joins by the solo rule (the losing side)", Teams:Team(eve) ~= ahead, Teams:Team(eve))
local offer = lastInvite(eve, m0)
check("...and gets 'Party up with Ava?'", offer and offer.kind == "friend" and offer.name == "Ava")
m0 = mark()
Engine.fireServer(eve, "Party", "accept")
Engine.advance(0.3)
check("one tap: Eve's in Ava's party", Party:Of(eve) == party and members(ava) == 3)
check("...on Ava's team", same({ ava, ben, eve }))
check("...Ava hears it", got(ava, m0, "Eve joined your party"))
Match:_setFrontline(0)

-- 4. Rebalance never splits a party ------------------------------------------------------------------------------
local X = Teams:Team(ava)
local Y = X == "red" and "blue" or "red"
Teams:Set(cy, X)
Teams:Set(dee, X)
local moved = Teams:Rebalance()
check("5 v 0: the solo players move", Teams:Team(cy) == Y and Teams:Team(dee) == Y, #moved)
check("...the party stays together (3 of 5: more than half)", same({ ava, ben, eve }) and Teams:Team(ava) == X)
-- a second party (Cy and Dee), and everyone on X: the smaller party moves whole
Party:Invite(cy, dee)
Party:Answer(dee, true)
check("a second party", Party:Of(cy) ~= nil and Party:Of(cy) == Party:Of(dee))
Teams:Set(cy, X)
Teams:Set(dee, X)
Teams:Rebalance()
check("only parties on the big side: the smaller one moves whole", same({ cy, dee }) and Teams:Team(cy) == Y)
check("...the bigger one stays whole", same({ ava, ben, eve }))
-- split one by hand: Rebalance puts it back on the leader's team
Teams:Set(ben, Y)
Teams:Rebalance()
check("a split party goes back to its leader's team", same({ ava, ben, eve }) and Teams:Team(ava) == X)

-- 5. Max size, kick, leave, a new leader ---------------------------------------------------------------------------
m0 = mark()
Party:Invite(ava, cy)
Party:Answer(cy, true)
check("the fourth member (from another party)", members(ava) == 4 and Party:Of(cy) == party)
check("...Dee's party is over", Party:Of(dee) == nil and got(dee, m0, "party has ended"))
check("...Cy moves to Ava's team", Teams:Team(cy) == X)
m0 = mark()
local ok = Party:Invite(ava, dee)
check("a full party: no more invites", ok == false and lastInvite(dee, m0) == nil)
check("...and Ava is told", got(ava, m0, "full"))
-- a full party can't take one more from a friend's card either
check("...or a 'Party up?' card", Party:Offer(dee, ava) == false)
m0 = mark()
check("only the leader can kick", Party:Kick(ben, eve) == false and members(ava) == 4)
Engine.fireServer(ava, "Party", "kick", cy.UserId)
Engine.advance(0.3)
check("the leader kicks", Party:Of(cy) == nil and members(ava) == 3)
check("...Cy is told", got(cy, m0, "taken out") and state(cy) == false)
m0 = mark()
Engine.fireServer(ben, "Party", "leave")
Engine.advance(0.3)
check("leave", Party:Of(ben) == nil and members(ava) == 2)
check("...the others hear it", got(ava, m0, "Ben left") and got(ben, m0, "You left"))
Party:Invite(ava, ben)
Party:Answer(ben, true)
m0 = mark()
Party:Leave(ava)
check("the leader leaves: the next member leads", party.leader ~= ava and members(eve) == 2)
check("...and they hear it", got(eve, m0, "leads the party now"))

-- 6. A party that forms in the fight waits for the next match ----------------------------------------------------
Teams:Rebalance()
Match:_setPhase("fight", Constants.FIGHT_SECONDS)
local lead = party.leader
local leadTeam = Teams:Team(lead)
-- Ava (solo now) onto the other side, then invited mid-fight
Teams:Set(ava, leadTeam == "red" and "blue" or "red")
m0 = mark()
Party:Invite(lead, ava)
Party:Answer(ava, true)
check("in the fight: in the party at once", Party:Of(ava) == party)
check("...but nobody switches sides mid-fight", Teams:Team(ava) ~= leadTeam)
check("...told where they go", got(ava, m0, "next game"))
-- a player who joins the server mid-fight with a party goes straight to its team (they haven't spawned yet)
local trip2 = { party = { id = party.id, leader = lead.UserId, members = { lead.UserId, 906 } } }
local fay = join("Fay", 906, { teleportData = trip2 })
check("a member arriving mid-fight lands on the party's team", Party:Of(fay) == party and Teams:Team(fay) == leadTeam)
Match:NewMatch()
Engine.advance(0.5)
check("the next match: the whole party on one team", same(party.members), #party.members)

-- 7. Follow a friend in with Roblox's Join --------------------------------------------------------------------------
Party:Leave(ava)
m0 = mark()
local gus = join("Gus", 907, { followUserId = ava.UserId })
local fol = lastInvite(gus, m0)
check("followed someone in: 'Party up with them?'", fol and fol.kind == "friend" and fol.name == "Ava")
Party:Answer(gus, true)
check("...one tap and they're a party", Party:Of(gus) ~= nil and Party:Of(gus) == Party:Of(ava))
check("...on one team", same({ ava, gus }))

-- 8. Move together --------------------------------------------------------------------------------------------------
local p2 = Party:Of(ava)
local t0 = #Engine.teleports
check("only the leader can move the party", Party:Move(gus, "new") == false and #Engine.teleports == t0)
m0 = mark()
Engine.fireServer(ava, "Party", "move", "new")
Engine.advance(0.3)
local tp = Engine.teleports[#Engine.teleports]
check("FIND A NEW SERVER: one teleport for the whole party", #Engine.teleports == t0 + 1 and tp and #tp.players == 2)
check("...to this game", tp and tp.placeId == 4242)
local td = tp and tp.options and tp.options:GetTeleportData()
check(
	"...with the party in the teleport data",
	td and td.party and td.party.id == p2.id and td.party.leader == ava.UserId and #td.party.members == 2
)
check("...everyone hears it", got(ava, m0, "new server") and got(gus, m0, "new server"))
check("...not twice in a row", Party:Move(ava, "new") == false)
Engine.advance(Party.MOVE_COOLDOWN + 1)
Party.findServer = function(size)
	return size <= 2 and "job-77" or nil
end
Party:Move(ava, "fuller")
tp = Engine.teleports[#Engine.teleports]
check("JOIN A FULLER SERVER: a server list's pick when there is one", tp.options.ServerInstanceId == "job-77")
Party.findServer = nil
-- they arrive in the new server: the party forms again (the same teleport data)
Engine.removePlayer(ava)
Engine.removePlayer(gus)
Engine.advance(1)
local ava2 = join("Ava", 901, { teleportData = td })
local gus2 = join("Gus", 907, { teleportData = td })
check("on arrival the party forms again", Party:Of(ava2) ~= nil and Party:Of(ava2) == Party:Of(gus2))
check("...Ava leads", Party:Of(ava2) and Party:Of(ava2).leader == ava2)
check("...one team", same({ ava2, gus2 }))
-- a teleport that fails is told
Engine.advance(Party.MOVE_COOLDOWN + 1)
Engine.teleportResult = "Failure"
m0 = mark()
Party:Move(ava2, "new")
Engine.advance(0.5)
check("a failed teleport: 'Could not move'", got(ava2, m0, "Could not move"))
Engine.teleportResult = nil

-- 9. Leaving the server -----------------------------------------------------------------------------------------
m0 = mark()
Engine.removePlayer(gus2)
Engine.advance(0.5)
check("a member leaves the server: a party of one is over", Party:Of(ava2) == nil and got(ava2, m0, "Gus left"))

print(`\n{passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for i = 1, math.min(6, #Engine.errors) do
		print(Engine.errors[i])
	end
	failed += #Engine.errors
end
if failed > 0 then
	error("PartySmoke: " .. failed .. " failures")
end
