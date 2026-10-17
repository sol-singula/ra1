--[[
The invite-a-friend card and its prize (InviteService, InvitePromoController): never too early, never in the first
match being taught, never mid-fight, a gap between cards, no more after two LATERs; a streak waits for the fight
to end; the card's reel spins and lands on a kill effect; a friend who joins from your invite wins you a random
effect you didn't have (yours for good, put on) and the reel lands on exactly that one; sending an invite alone
gives nothing.

  luaurun tests/InviteSmoke.spec.luau
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
Engine.require(tree.shared.Constants).AFK_SECONDS = 0
Engine.require(tree.shared.Constants).MIN_SIDE = 1
Engine.require(tree.shared.Constants).TUTORIAL = false
Engine.clientEnabled = true
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Invite = service("InviteService")
local Data = service("PlayerDataService")
local Match = service("MatchService")
local Teams = service("TeamService")
local Combat = service("CombatService")
local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)
local P = Invite.PROMO
P.minAge, P.gap, P.max, P.declines, P.play, P.pulseEvery = 3, 20, 3, 2, 1e9, 1e9

local function mark()
	return #Engine.clientLog
end
local function firedSince(m, name, player)
	for i = m + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.name == name and (player == nil or e.player == player or e.player == "all") then
			return e
		end
	end
	return nil
end

local foe = Engine.addPlayer("Foe", 900)
Engine.advance(0.5)
Engine.fireServer(foe, "Ready")
local host = Engine.addPlayer("Host", 501)
Engine.Players.LocalPlayer = host
Engine.localPlayer = host
Engine.runScript(tree.client.Main)
Engine.advance(1.5)
local Promo = Engine.require(tree.client.Controllers.InvitePromoController)

-- timing ---------------------------------------------------------------------------------------------------------
check("a visit's first minutes: no card", Invite:Blocked(host) == "new" and not Invite:Promote(host, "win"))
Engine.advance(P.minAge + 0.5)
Data:Get(host).tutorial = { done = false, skipped = false }
check("still being taught the first match: no card", Invite:Blocked(host) == "tutorial", Invite:Blocked(host))
Data:Get(host).tutorial = { done = true }
Match:SkipTo("fight")
check("mid-fight: no card", Invite:Blocked(host) == "fight", Invite:Blocked(host))
local mWin = mark()
Match:Victory(Teams:Team(host))
Engine.advance(4) -- (the tick shows the visit's first win once the fight's over)
local shown = firedSince(mWin, "InvitePromo", host)
check(
	"the first win of the visit: the card goes up",
	shown and shown.args[1].why ~= nil and type(shown.args[1].pool) == "table",
	shown and shown.args[1].why
)
local kind, card = Promo.current()
check(
	"...on screen: INVITE A FRIEND → GET A RANDOM EFFECT",
	kind == "promo" and card and card.Head.Text:find("INVITE") ~= nil
)
check("...with INVITE and LATER", card and card:FindFirstChild("Invite") ~= nil and card:FindFirstChild("Later") ~= nil)
Engine.advance(2.5)
local landed = Promo.landed()
local it = landed and Cosmetics.get(landed)
check("...and landing on a kill effect", it ~= nil and it.kind == "effect", landed)
check("...whose name it shows", it and card.Reel.EffectName.Text == string.upper(it.name))
-- the reel spins again while the card is up
Engine.advance(1.8)
check("...and spins again while the card is up", Promo.landed() == nil)
check("a second card straight after: no (the gap)", Invite:Blocked(host) == "gap" and not Invite:Promote(host, "win"))
Promo.later()
Engine.advance(0.2)
check("LATER closes it and goes to the server", Promo.current() == nil)

-- a streak waits for the fight to end ----------------------------------------------------------------------------
Engine.advance(P.gap + 1)
Engine.advance(25) -- (on to the next match's fight)
for _ = 1, 40 do
	if Match:Phase() == "fight" then
		break
	end
	Engine.advance(2)
end
if Match:Phase() ~= "fight" then
	Match:SkipTo("fight")
end
for _ = 1, P.streak do
	Combat.Killed:Fire(foe, host, {})
end
local mStreak = mark()
Engine.advance(4)
check("a streak mid-fight: the card waits", firedSince(mStreak, "InvitePromo", host) == nil, Match:Phase())
Match:Victory(Teams:Team(foe))
Engine.advance(4)
local s2 = firedSince(mStreak, "InvitePromo", host)
check(
	"...and goes up once the fight is over",
	s2 and (s2.args[1].why == "streak" or s2.args[1].why == "mvp"),
	s2 and s2.args[1].why
)
Promo.later()
Engine.advance(P.gap + 1)
check("LATER twice: no more cards", Invite:Blocked(host) == "declined", Invite:Blocked(host))

-- the prize: only for a friend who comes -------------------------------------------------------------------------
local before = table.clone(Data:Get(host).owned or {})
local mSent = mark()
Invite:Answer(host, "sent", 3)
Engine.advance(0.5)
check("sending an invite alone gives nothing", firedSince(mSent, "InviteReward", host) == nil)
Engine.friends["7101:" .. host.UserId] = true
Engine.friends[host.UserId .. ":7101"] = true
local mJoin = mark()
local pal = Engine.addPlayer("Pal", 7101, "i:" .. host.UserId)
Engine.advance(1)
Engine.fireServer(pal, "Ready")
Engine.advance(1)
local won = firedSince(mJoin, "InviteReward", host)
local key = won and won.args[1].key
local prize = key and Cosmetics.get(key)
check("a friend joins from your invite: you win a kill effect", prize ~= nil and prize.kind == "effect", key)
check("...one you didn't have", key and not before[key])
check(
	"...yours for good, and put on",
	key and Data:Get(host).owned[key] == true and Data:Get(host).equipped.effect == key
)
local rk = Promo.current()
check("...revealed by the reel", rk == "reward" and Promo.landed() == nil)
Engine.advance(2.5)
check("...which lands on exactly the effect you won", Promo.landed() == key, Promo.landed())

-- the draw ---------------------------------------------------------------------------------------------------------
do
	local pool = Invite.prizePool()
	local profile = { owned = {} }
	for i = 2, #pool do
		profile.owned[pool[i]] = true
	end
	check("the prize is one you don't have", Invite.randomEffect(profile) == pool[1])
	profile.owned[pool[1]] = true
	check("...and none when you have them all", Invite.randomEffect(profile) == nil)
end

print(`InviteSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error("InviteSmoke failed")
end
