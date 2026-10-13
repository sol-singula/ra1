--[[
Client smoke test: boots the real client scripts on the mock engine as a phone-sized screen, feeds them the
server → client events, presses the buttons, fires the rifle and checks what's sent and shown.

  luaurun tests/ClientSmoke.spec.luau      (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
local CFrame = Engine.CFrame
local Color3 = Engine.globals.Color3
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
local Net = Engine.require(tree.shared.Net)
Net.init()
Engine.side = "client"
local camera = Engine.workspace.CurrentCamera
camera.ViewportSize = Vector2.new(844, 390)
camera.CFrame = CFrame.new(0, 5, 10)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false

local player = Engine.addPlayer("Ava", 7)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.makeCharacter(player)
player:SetAttribute("Zone", "lobby")
Engine.runScript(tree.client.Main)
Engine.advance(0.3)
check("client sent Ready", Engine.lastClientEvent("Ready") ~= nil)

local gui = player.PlayerGui
local function serverSends(name, ...)
	Engine.remote(name):FireClient(player, ...)
	Engine.advance(0.05)
end
local function findButton(root, text)
	for _, d in root:GetDescendants() do
		if d.ClassName == "TextButton" and d.Text and string.find(d.Text, text, 1, true) then
			return d
		end
		if
			d.ClassName == "TextLabel"
			and d.Text
			and string.find(d.Text, text, 1, true)
			and d.Parent
			and d.Parent.ClassName == "TextButton"
		then
			return d.Parent
		end
	end
	return nil
end
local function click(root, text)
	local b = findButton(root, text)
	check("button '" .. text .. "' exists", b ~= nil)
	if b then
		b.Activated:Fire()
		Engine.advance(0.05)
	end
	return b
end
local function sentCount(name)
	local n = 0
	for _, e in Engine.clientLog do
		if e.name == name and e.player == "server" then
			n += 1
		end
	end
	return n
end
local function lastSent(name)
	for i = #Engine.clientLog, 1, -1 do
		local e = Engine.clientLog[i]
		if e.name == name and e.player == "server" then
			return e
		end
	end
	return nil
end
local function textIn(root, text)
	for _, d in root:GetDescendants() do
		if
			(d.ClassName == "TextLabel" or d.ClassName == "TextButton")
			and d.Text
			and string.find(d.Text, text, 1, true)
		then
			return d
		end
	end
	return nil
end

local hud = gui:FindFirstChild("Hud")
local rifleGui = gui:FindFirstChild("Rifle")
check("HUD built", hud ~= nil)
check("rifle screen built", rifleGui ~= nil)

-- Profile -----------------------------------------------------------------------------------------------------
serverSends("Profile", {
	coins = 1234,
	keys = 3,
	level = 4,
	xpInto = 120,
	xpNeed = 480,
	passes = {},
	loadout = {
		rifle = "BOLT",
		rifles = { { key = "BOLT", owned = true, equipped = true, tier = 0, mastery = 3 } },
		skins = {},
		crosshair = "DOT",
		effects = { BRICKS = true },
		effect = "BRICKS",
		emotes = { WAVE = true },
		emote = "WAVE",
		crosshairs = { DOT = true },
		nameColors = { WHITE = true },
		nameColor = "WHITE",
		shop = {},
	},
})
Engine.advance(1)
check("coins shown", hud.Coins.Value.Text == "1.2K", hud.Coins.Value.Text)
check("keys shown", hud.Keys.Value.Text == "3")
check("level shown", hud.Level.Value.Text == "LV 4")
check("level bar fill", math.abs(hud.LevelBar.Fill.Size.X.Scale - 0.25) < 0.01)

-- Round states ----------------------------------------------------------------------------------------------------
serverSends("Round", { state = "waiting", endsAt = 0, minPlayers = 2, players = 1 })
Engine.advance(0.3)
check("waiting shown", hud.Round.Clock.Text:find("WAITING", 1, true) ~= nil, hud.Round.Clock.Text)
check("lobby menu visible", hud.Menu.Visible == true)
check("no PLAY button while waiting", hud.PlayButton.Visible == false)
local now = Engine.workspace:GetServerTimeNow()
serverSends("Round", { state = "lobby", endsAt = now + 12, minPlayers = 2, players = 2 })
Engine.advance(0.3)
check("lobby countdown", hud.Round.Clock.Text:find("0:1", 1, true) ~= nil, hud.Round.Clock.Text)
serverSends("Round", {
	state = "round",
	endsAt = now + 200,
	map = "Block Town",
	mapKey = "TOWN",
	size = "small",
	minPlayers = 2,
	players = 2,
})
Engine.advance(0.3)
check("round clock", hud.Round.Clock.Text:find("3:", 1, true) ~= nil, hud.Round.Clock.Text)
check("PLAY button when a round is on", hud.PlayButton.Visible == true)
click(hud, "PLAY")
check("PLAY sends Play", lastSent("Play") ~= nil)

-- In the arena ------------------------------------------------------------------------------------------------------
check("third person in the lobby", player.CameraMode == Engine.Enum.CameraMode.Classic)
player:SetAttribute("Zone", "arena")
Engine.advance(0.3)
check("first person in the arena", player.CameraMode == Engine.Enum.CameraMode.LockFirstPerson)
check("crosshair shows", rifleGui.Crosshair.Visible == true)
check("FIRE button on phones", rifleGui.FireButton.Visible == true)
check("SCOPE button on phones", rifleGui.ScopeButton.Visible == true)
check("menu hidden in the arena", hud.Menu.Visible == false)
check("LOBBY button in the arena", hud.LobbyButton.Visible == true)
check("view model follows the camera", camera:FindFirstChild("ViewModel") ~= nil)
-- firing
camera.CFrame = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.new(0, 5, -10))
local firesBefore = sentCount("Fire")
rifleGui.FireButton.MouseButton1Down:Fire()
Engine.advance(0.05)
check("FIRE sends a shot", sentCount("Fire") == firesBefore + 1)
local shot = lastSent("Fire")
check("the shot starts at the camera", shot and (shot.args[1] - Vector3.new(0, 5, 10)).Magnitude < 0.01)
check("the shot goes where you look (with hip spread)", shot and shot.args[2]:Dot(Vector3.new(0, 0, -1)) > 0.99)
check("the shot carries the time", shot and type(shot.args[3]) == "number")
check("my tracer shows right away", Engine.workspace.Fx:FindFirstChild("Tracer") ~= nil)
rifleGui.FireButton.MouseButton1Down:Fire()
Engine.advance(0.05)
check("the bolt: no second shot right away", sentCount("Fire") == firesBefore + 1)
check("the bolt ring shows", rifleGui.Crosshair.Bolt.Visible == true)
Engine.advance(1.3)
check("the bolt ring hides when ready", rifleGui.Crosshair.Bolt.Visible == false)
-- scope
click(rifleGui, "SCOPE")
check("the scope overlay shows", rifleGui.Scope.Visible == true)
check(
	"the view model hides while scoped",
	(camera.ViewModel.PrimaryPart.Position - camera.CFrame.Position).Magnitude > 100
)
-- aim help: a target just off the crosshair, scoped, on a phone
local other = Engine.addPlayer("Ben", 8)
Engine.makeCharacter(other)
other:SetAttribute("Zone", "arena")
Engine.moveTo(other, Vector3.new(1.2, 5, -60))
Engine.advance(0.4) -- (scope settled)
rifleGui.FireButton.MouseButton1Down:Fire()
Engine.advance(0.05)
shot = lastSent("Fire")
local toBen = (Vector3.new(1.2, 5.3, -60) - Vector3.new(0, 5, 10)).Unit
check(
	"light aim help bends the shot onto a close miss",
	shot and shot.args[2]:Dot(toBen) > 0.9999,
	shot and shot.args[2]
)
check("the bolt kicks you out of the scope", rifleGui.Scope.Visible == false)
-- hit marker
serverSends("Hit", true)
check("hit marker shows (headshot)", rifleGui.HitMarker.Visible == true and rifleGui.HitMarker.Text == "🎯")
Engine.advance(0.5)
check("hit marker hides", rifleGui.HitMarker.Visible == false)

-- What others do --------------------------------------------------------------------------------------------------
local tracersBefore = #Engine.workspace.Fx:GetChildren()
serverSends("Shot", Vector3.new(0, 5, 0), Vector3.new(0, 5, -40), Color3.fromRGB(255, 0, 0), 8, true)
check("other players' tracers show", #Engine.workspace.Fx:GetChildren() > tracersBefore)
serverSends("Shot", Vector3.new(0, 5, 0), Vector3.new(0, 5, -40), Color3.fromRGB(255, 0, 0), 7, true)
serverSends("Pop", Vector3.new(0, 3, -40), "CONFETTI")
check("pops burst into bits", Engine.workspace.Fx:FindFirstChild("Bit") ~= nil)
serverSends("Feed", { killer = "Ava", victim = "Ben", headshot = true, rifle = "Bolt", tag = "😤 REVENGE" })
check("kill feed line", hud.Feed:FindFirstChild("FeedLine") ~= nil and textIn(hud.Feed, "REVENGE") ~= nil)
serverSends("Streak", "Ava", "🔥 ON FIRE", Color3.fromRGB(255, 140, 30))
check("streak banner", hud.Streak.Visible == true and hud.Streak.Text:find("ON FIRE", 1, true) ~= nil)
serverSends("Score", {
	{ userId = 7, name = "Ava", pops = 5, deaths = 1 },
	{ userId = 8, name = "Ben", pops = 3, deaths = 4 },
	{ userId = 0, name = "Robo", pops = 1, deaths = 2, robot = true },
})
Engine.advance(0.3)
check("scoreboard rows", hud.Scores:FindFirstChild("Row1") ~= nil and hud.Scores.Row1.Text:find("Ava", 1, true) ~= nil)
check(
	"my pops and place",
	hud.Mine.Visible and hud.Mine.Text:find("5 pops", 1, true) ~= nil and hud.Mine.Text:find("#1 of 3", 1, true) ~= nil,
	hud.Mine.Text
)
player:SetAttribute("Crown", true)
Engine.advance(0.3)
check("crown notice", hud.Crown.Visible == true)
check("my own crown shows over me", player.Character.Head:FindFirstChild("CrownTag") ~= nil)
player:SetAttribute("Crown", nil)
serverSends(
	"Round",
	{ state = "round", endsAt = Engine.workspace:GetServerTimeNow() + 40, map = "Block Town", lastMinute = true }
)
Engine.advance(0.3)
check("last minute pill", hud.LastMinute.Visible == true)

-- Popped ---------------------------------------------------------------------------------------------------------
player:SetAttribute("Popped", true)
serverSends("Popped", {
	by = "Ben",
	userId = 8,
	level = 9,
	rifle = "Swift",
	skin = "Galaxy",
	effect = "BRICKS",
	headshot = false,
	back = Engine.workspace:GetServerTimeNow() + 5,
	how = "shot",
})
Engine.advance(0.1)
check("the pop screen shows who got you", hud.Popped.Visible and hud.Popped.Title.Text:find("Ben", 1, true) ~= nil)
check("and their rifle and skin", hud.Popped.Sub.Text:find("Galaxy", 1, true) ~= nil)
check("the countdown", hud.Popped.Count.Text:find("BACK IN", 1, true) ~= nil)
check("pop cam looks at the shooter", Engine.require(tree.client.Controllers.FxController).camMode() == "pop")
check("no crosshair while popped", rifleGui.Crosshair.Visible == false)
click(hud.Popped, "BACK NOW")
check("Revive sends the purchase", lastSent("Purchase") and lastSent("Purchase").args[2] == "REVIVE")
player:SetAttribute("Popped", nil)
Engine.advance(0.4)
check("the pop screen goes away", hud.Popped.Visible == false)
check("pop cam ends", Engine.require(tree.client.Controllers.FxController).camMode() == nil)

-- Leaving and the podium -------------------------------------------------------------------------------------------
click(hud, "LOBBY")
check("LOBBY sends Leave", lastSent("Leave") ~= nil)
player:SetAttribute("Zone", "lobby")
serverSends("Podium", { { name = "Ava", pops = 9, rank = 1 }, { name = "Ben", pops = 4, rank = 2 } })
check("podium banner", hud.Podium.Visible == true and textIn(hud.Podium, "Ava (9)") ~= nil)
check("podium camera", Engine.require(tree.client.Controllers.FxController).camMode() == "podium")
Engine.advance(9)
check("podium banner hides", hud.Podium.Visible == false)

-- Toasts, alerts, announcements -------------------------------------------------------------------------------------
serverSends("Toast", "+20 💰 🎯 HEADSHOT", "good")
check("toast", hud.Toasts:FindFirstChild("Toast") ~= nil)
serverSends("Alert", "🏆 YOU WON!", Color3.fromRGB(255, 215, 60))
check("alert", hud.Alert.Visible == true)
serverSends("Announce", "⏰ LAST MINUTE! 2X COINS!", Color3.fromRGB(255, 140, 30))
check("announcement", hud:FindFirstChild("Announce") ~= nil)
serverSends("Sfx", "pop", Vector3.new(0, 3, 0))

-- Panels --------------------------------------------------------------------------------------------------------------
local panels = gui:FindFirstChild("Panels")
check("panels built", panels ~= nil)
serverSends("Profile", {
	coins = 50000,
	keys = 2,
	level = 6,
	canPaidRandom = true,
	canTrade = true,
	passes = {},
	loadout = {
		rifle = "BOLT",
		rifle2 = nil,
		rifles = {
			{ key = "BOLT", owned = true, equipped = true, tier = 1, mastery = 120 },
			{ key = "SWIFT", owned = false, locked = false, tier = 0, mastery = 0 },
			{ key = "EAGLE", owned = false, locked = true, tier = 0, mastery = 0 },
		},
		skins = { { uid = 5, id = "GOLD" }, { uid = 6, id = "MINT", on = "BOLT" } },
		effects = { BRICKS = true, CONFETTI = true },
		effect = "BRICKS",
		emotes = { WAVE = true },
		emote = "WAVE",
		crosshairs = { DOT = true },
		crosshair = "DOT",
		nameColors = { WHITE = true },
		nameColor = "WHITE",
		shop = {
			{ kind = "skin", id = "TIGER", price = 2000, bought = false },
			{ kind = "effect", id = "FIRE", price = 22500, bought = true },
		},
		shopEndsAt = os.time() + 3600,
	},
	quests = {
		list = { { text = "Pop 15 players", progress = 4, target = 15, reward = "300 💰", done = false } },
		canSwap = true,
		swapCoins = 300,
	},
	daily = {
		canClaim = true,
		nextDay = 2,
		gifts = { "200 coins", "300 coins", "1 key", "600 coins", "800 coins", "2 keys", "1500 coins + 2 keys" },
		secondsToNext = 3600,
		streak = 1,
	},
	season = { n = 3, endsAt = os.time() + 86400, xp = 1300, tier = 2, pass = false, claimed = {} },
	stalls = { { seller = "Ben", sellerId = 8, skin = "GALAXY", price = 25000 }, false, false },
	vote = {
		open = true,
		options = {
			{ key = "TOWN", name = "Block Town", emoji = "🏘️", votes = 1 },
			{ key = "CANDY", name = "Candy Canyon", emoji = "🍭", votes = 0 },
		},
	},
	playtime = { nextIn = 120, nextText = "150 coins", given = 1, total = 9 },
})
player:SetAttribute("Zone", "lobby")
serverSends("Round", { state = "lobby", endsAt = Engine.workspace:GetServerTimeNow() + 10 })
Engine.advance(0.4)
check("vote buttons in the lobby", hud.VoteBar.Visible and hud.VoteBar:FindFirstChild("Vote_TOWN") ~= nil)
click(hud.VoteBar, "Candy Canyon")
check("vote sends Vote", lastSent("Vote") and lastSent("Vote").args[1] == "CANDY")
check("next gift pill", hud.Gift.Visible and hud.Gift.Text:find("150 coins", 1, true) ~= nil)
check("quest dot when the daily gift is ready", hud.Menu.QuestsButton.Dot.Visible == true)
-- Shop
click(hud.Menu, "SHOP")
check("shop panel", panels.Dim.Visible and textIn(panels, "DAILY SHOP") ~= nil)
check("shop shows today's items", textIn(panels, "Tiger") ~= nil and textIn(panels, "BOUGHT") ~= nil)
click(panels, "2K")
check("buy sends BuyShop", lastSent("BuyShop") and lastSent("BuyShop").args[1] == 1)
-- Rifles
click(hud.Menu, "RIFLES")
check("rifles panel", textIn(panels, "RIFLES") ~= nil and textIn(panels, "Bolt") ~= nil)
check("locked rifles show their level", textIn(panels, "LV 12") ~= nil)
click(panels, "5K")
check("buy rifle", lastSent("BuyRifle") and lastSent("BuyRifle").args[1] == "SWIFT")
click(panels, "SKIN")
check("skin list", textIn(panels, "Gold") ~= nil)
click(panels, "Gold")
check("equip skin", lastSent("EquipSkin") and lastSent("EquipSkin").args[2] == 5)
-- Style
click(hud.Menu, "STYLE")
check("style panel", textIn(panels, "STYLE") ~= nil and textIn(panels, "Confetti") ~= nil)
click(panels, "USE")
check("use a pop effect", lastSent("EquipStyle") and lastSent("EquipStyle").args[1] == "effect")
click(panels, "AIM")
click(panels, "1K")
check("buy a crosshair", lastSent("BuyStyle") and lastSent("BuyStyle").args[1] == "crosshair")
-- Quests
click(hud.Menu, "QUESTS")
check("quests panel", textIn(panels, "Pop 15 players") ~= nil and textIn(panels, "4 / 15") ~= nil)
click(panels, "CLAIM")
check("claim daily", lastSent("ClaimDaily") ~= nil)
click(panels, "300")
check("swap quest", lastSent("RerollQuest") and lastSent("RerollQuest").args[1] == 1)
-- Crates
click(hud.Menu, "CRATES")
check(
	"crates panel with odds",
	textIn(panels, "Coin Crate") ~= nil and textIn(panels, "Odds") ~= nil and textIn(panels, "70%") ~= nil
)
click(panels, "OPEN")
check("open crate", lastSent("OpenCrate") ~= nil)
serverSends("Crate", { crate = "COIN", skin = "LAVA" })
check("crate reveal", textIn(panels, "Lava") ~= nil and textIn(panels, "EPIC SKIN") ~= nil)
serverSends("Profile", { canPaidRandom = false })
click(hud.Menu, "CRATES")
check("key crate hidden when paid random items are restricted", textIn(panels, "Key Crate") == nil)
-- Season
click(hud.Menu, "SEASON")
check("season panel", textIn(panels, "Season 3") ~= nil and textIn(panels, "Tier 2") ~= nil)
click(panels, "FREE")
check("claim season tier", lastSent("ClaimSeason") and lastSent("ClaimSeason").args[2] == "free")
click(panels, "R$ 399")
check("buy the season pass", lastSent("Purchase") and lastSent("Purchase").args[2] == "SEASON")
-- Store
click(hud.Menu, "STORE")
check("store panel", textIn(panels, "VIP") ~= nil and textIn(panels, "Crate Keys") ~= nil)
Engine.advance(2)
-- Stall
local Panel = Engine.require(tree.client.Controllers.PanelController)
Panel.open("Stall", 1)
check("stall with an offer", textIn(panels, "Galaxy") ~= nil and textIn(panels, "by Ben") ~= nil)
click(panels, "25K")
check("buy from a stall", lastSent("BuyStall") and lastSent("BuyStall").args[1] == 1)
Panel.open("Stall", 2)
check("empty stall: prices and skins", textIn(panels, "SELL") ~= nil)
click(panels, "SELL")
check("list a skin", lastSent("ListStall") and lastSent("ListStall").args[1] == 2)
-- panels close when you go into a round
player:SetAttribute("Zone", "arena")
Engine.advance(0.1)
check("panels close in a round", panels.Dim.Visible == false)

check("no script errors", #Engine.errors == 0, Engine.errors[1])
print(`{passed} passed, {failed} failed, {#Engine.errors} script errors, {#Engine.warnings} warnings`)
if failed > 0 or #Engine.errors > 0 then
	error("client smoke test failed")
end
