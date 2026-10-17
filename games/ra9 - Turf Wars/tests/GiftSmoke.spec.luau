--[[
The free match-end gifts (GiftService + GiftController), the real server and client together: a player who hasn't
bought anything gets a free shop cosmetic at each match's end (owned, not worn), shown as the end screen ("YOU WON
A FREE TRAIL!"); EQUIP IT opens the locker on it with a ring and a hand; the kinds go round (trail, kill effect,
bow, banner), skipping kinds already worn; it stops once a gift of each of trail, effect and bow has been worn, or
after GIFT_MAX, or as soon as they buy anything (then a "NEW IN THE SHOP" card a couple of times, then nothing).

  luaurun tests/GiftSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector2 = Engine.globals.Vector2

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
Constants.AFK_SECONDS = 0
Constants.MIN_SIDE = 1
Constants.TUTORIAL = false
Engine.clientEnabled = true
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(844, 390)
Engine.runScript(tree.server.Main)
Engine.advance(0.2)
local function service(name)
	return Engine.require(tree.server.Services[name])
end
local Teams = service("TeamService")
local Match = service("MatchService")
local Data = service("PlayerDataService")
local Gifts = service("GiftService")
local ShopS = service("ShopService")
local Cosmetics = Engine.require(tree.shared.Data.Cosmetics)

local function mark()
	return #Engine.clientLog
end
local function giftsSince(m, player)
	local out = {}
	for i = m + 1, #Engine.clientLog do
		local e = Engine.clientLog[i]
		if e.name == "Gift" and e.player == player then
			table.insert(out, e.args[1])
		end
	end
	return out
end

local foe = Engine.addPlayer("Foe", 910)
Engine.advance(0.5)
Engine.fireServer(foe, "Ready")
local buyer = Engine.addPlayer("Buyer", 911)
Engine.advance(0.5)
Engine.fireServer(buyer, "Ready")
local player = Engine.addPlayer("Ava", 512)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.runScript(tree.client.Main)
Engine.advance(2)
local GiftC = Engine.require(tree.client.Controllers.GiftController)
local Panel = Engine.require(tree.client.Controllers.PanelController)

-- one match's end: a win for the player's side, the gift's delay, then on to the next match
local function matchEnd()
	local m = mark()
	Match:Victory(Teams:Team(player) or "red")
	Engine.advance(Constants.GIFT_DELAY + 0.5)
	local got = {
		ava = giftsSince(m, player)[1],
		foe = giftsSince(m, foe)[1],
		buyer = giftsSince(m, buyer)[1],
	}
	return got
end
local function nextMatch()
	if GiftC.current() then
		GiftC.later()
	end
	if Panel.isOpen() then
		Panel.close()
	end
	Engine.advance(Constants.VICTORY_SECONDS + Constants.TRANSITION_SECONDS - Constants.GIFT_DELAY + 1)
end

-- the buyer buys something before the first match ends: no gifts for them, ever
ShopS.Bought:Fire(buyer, "shards_s", nil, 49)
Engine.advance(0.1)

-- 1: a trail, owned not worn, as the end screen
local g1 = matchEnd()
local a = g1.ava
check("a match's end: a free gift", a ~= nil and a.key ~= nil, a and a.key)
local it = a and Cosmetics.get(a.key)
check("...from the shop's pool (never Robux-only)", it and it.source == "shop", it and it.source)
check("...the first one a trail", it and it.kind == "trail", it and it.kind)
check("...cheap first (common or rare)", it and (it.rarity == "common" or it.rarity == "rare"), it and it.rarity)
check("...owned", Data:Get(player).owned[a.key] == true)
check("...NOT worn (they wear it themselves)", Data:Get(player).equipped.trail ~= a.key)
check("...gift 1 of GIFT_MAX", a.count == 1 and a.of == Constants.GIFT_MAX)
local shown, scr = GiftC.current()
check("the end screen shows it", shown and shown.key == a.key and scr and scr.Parent ~= nil)
local card = scr and scr:FindFirstChild("Card")
check(
	"...YOU WON A FREE TRAIL!, the prize, EQUIP IT, LATER, a Robux tease",
	card
		and string.find(card.Title.Text, "TRAIL") ~= nil
		and card:FindFirstChild("Prize") ~= nil
		and card:FindFirstChild("Equip") ~= nil
		and card:FindFirstChild("Later") ~= nil
		and card:FindFirstChild("Tease") ~= nil,
	card and card.Title.Text
)
Engine.advance(0.4)
check("...sparkles fly when it lands", card:FindFirstChild("Sparkle1") ~= nil and card.Sparkle1.TextTransparency < 1)
-- EQUIP IT: the locker, on the gift, pointed at
check("EQUIP IT", GiftC.equip() and GiftC.current() == nil)
Engine.advance(0.2)
check("...opens the shop panel on the locker", Panel.isOpen() and Panel.tab() == "locker", Panel.tab())
check("...with the gift spotlit", Panel.spotlight() == a.key)
local spot
for _, d in Engine.localPlayer.PlayerGui:GetDescendants() do
	if d.Name == "Spotlight" and d.Parent and d.Parent:GetAttribute("Key") == a.key then
		spot = d
	end
end
check("...a ring (and a hand) on its card", spot ~= nil and spot.Parent:FindFirstChild("Hand") ~= nil)
-- they wear it (what the card's tap sends)
Engine.fireServer(player, "Settings", "equip", { kind = "trail", key = a.key })
Engine.advance(0.3)
check("worn from the locker: counted", Data:Get(player).gifts.wore.trail == true)
check("...the spotlight goes once it's worn", Panel.spotlight() == nil)
check(
	"the buyer got no gift, a NEW IN THE SHOP card",
	g1.buyer ~= nil and g1.buyer.nudge == true and g1.buyer.key == nil
)
check("the other player got one too", g1.foe ~= nil and g1.foe.key ~= nil)
nextMatch()

-- 2: a kill effect (the trail's been worn)
local g2 = matchEnd()
local e2 = g2.ava and Cosmetics.get(g2.ava.key)
check("the buyer's 2nd and last NEW IN THE SHOP card", g2.buyer ~= nil and g2.buyer.nudge == true)
check("the next one: a kill effect", e2 and e2.kind == "effect", e2 and e2.kind)
Engine.fireServer(player, "Settings", "equip", { kind = "effect", key = g2.ava.key })
Engine.advance(0.2)
nextMatch()

-- 3 on: the free ones are done (GIFT_MAX, a taste): a first-buy offer instead, a different one each match
local offers = {}
for i = 1, 3 do
	local g = matchEnd()
	if i == 1 then
		check("after GIFT_MAX gifts no more free ones", Data:Get(player).gifts.n == Constants.GIFT_MAX)
		check("...then nothing for the buyer", g.buyer == nil)
	end
	local o = g.ava
	check(`match {i + 2}: a first-buy offer`, o ~= nil and o.offer ~= nil and type(o.key) == "string", o and o.offer)
	if o then
		offers[o.offer] = (offers[o.offer] or 0) + 1
		local _, scr2 = GiftC.current()
		local c = scr2 and scr2:FindFirstChild("Card")
		check(
			"...shown with BUY and its price, and LATER",
			c and c:FindFirstChild("Equip") and string.find(c.Equip.Text, "BUY") ~= nil and c:FindFirstChild("Later"),
			c and c:FindFirstChild("Equip") and c.Equip.Text
		)
		if o.offer == "tnt" then
			check(
				"...the TNT one says PERMANENT and its % off",
				string.find(c.Title.Text, "PERMANENT") ~= nil and string.find(c.Title.Text, "% OFF") ~= nil,
				c.Title.Text
			)
		elseif o.offer == "deal" then
			check("...the deal one counts down", string.find(c.Line.Text, "ENDS IN") ~= nil, c.Line.Text)
		end
		if i == 3 then
			local asked = false
			local real = ShopS.PromptRobux
			ShopS.PromptRobux = function(self, who, key)
				asked = asked or (who == player and key == o.key)
				return real(self, who, key)
			end
			check("BUY: the Robux prompt for it, the card gone", GiftC.buy() and GiftC.current() == nil)
			Engine.advance(0.3)
			ShopS.PromptRobux = real
			check("...(Buy robux sent)", asked)
		end
	end
	nextMatch()
end
check("...they go round (the TNT and the Starter Pack both offered)", offers.tnt and offers.starter, offers)
check("the foe got GIFT_MAX gifts, all from the shop", Data:Get(foe).gifts.n == Constants.GIFT_MAX)

-- a buy stops the gifts at once
local fresh = Engine.addPlayer("Fresh", 913)
Engine.advance(0.5)
Engine.fireServer(fresh, "Ready")
Engine.advance(1)
ShopS.Bought:Fire(fresh, "tnt", nil, 75)
Engine.advance(0.1)
local g10 = matchEnd()
check("buying anything: no free gifts", Data:Get(fresh).gifts.n == 0)

print(`GiftSmoke: {passed} passed, {failed} failed`)
if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	error("GiftSmoke: script errors")
end
if failed > 0 then
	error("GiftSmoke failed")
end
