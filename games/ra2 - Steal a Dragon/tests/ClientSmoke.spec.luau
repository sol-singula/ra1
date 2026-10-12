--[[
Client smoke test: boots the real client scripts on the mock engine as a phone-sized screen, feeds them every
server → client event, presses every HUD button, opens every panel and checks the prompt filtering.

  luaurun tests/ClientSmoke.spec.luau      (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame
local Color3 = Engine.globals.Color3
local Vector2 = Engine.globals.Vector2
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
local Net = Engine.require(tree.shared.Net)
local Constants = Engine.require(tree.shared.Constants)
Net.init() -- the server normally creates the remotes
Engine.side = "client"
-- a phone in landscape: 844 x 390
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false

local player = Engine.addPlayer("Ava", 7)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.makeCharacter(player)
-- a bit of world for the client to point at
local bases = Instance.new("Folder", Engine.workspace)
bases.Name = "Bases"
local base1 = Instance.new("Model", bases)
base1.Name = "Base1"
local laser = Instance.new("Part", base1)
laser.Name = "Laser"
Engine.runScript(tree.client.Main)
Engine.advance(0.3)
check("client sent Ready", Engine.lastClientEvent("Ready") ~= nil)

local gui = player.PlayerGui
local CollectionService = Engine.game:GetService("CollectionService")
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
local function sent(name)
	local e = Engine.lastClientEvent(name)
	return e and e.player == "server" and e or nil
end
local function countSent(name)
	local n = 0
	for _, e in Engine.clientLog do
		if e.player == "server" and e.name == name then
			n += 1
		end
	end
	return n
end

local hud = gui:FindFirstChild("Hud")
check("HUD built", hud ~= nil)
check("phone scale applied", math.abs(hud.Scale.Scale - 390 / 560) < 0.01, hud.Scale.Scale)
check("landscape on phones", gui.ScreenOrientation ~= nil)

-- Profile -> HUD
serverSends("Profile", {
	coins = 1234,
	cps = 12,
	friendsHere = 1,
	baseIndex = 1,
	lockUntil = 0,
	speedLevel = 1,
	passes = {},
	nests = 4,
	waiting = 2,
	team = { 99 },
	tutorialDone = false,
	carrying = false,
	daily = { streak = 1, canClaim = true, nextDay = 2, gift = "Frosty (Rare)", secondsToNext = 3600 },
	egg = { id = "STORM", name = "Storm", rarity = "Epic", secondsLeft = 72000 },
	goal = false,
})
Engine.advance(0.3)
Engine.advance(1) -- the coin counter counts up over about half a second
check("coins shown", hud.Coins.Value.Text == "1.2K", hud.Coins.Value.Text)
serverSends("Profile", { coins = 5000 })
Engine.advance(0.1)
check("coins count up, not jump", hud.Coins.Value.Text ~= "5K", hud.Coins.Value.Text)
Engine.advance(1.5)
check("coins reach the new total", hud.Coins.Value.Text == "5K", hud.Coins.Value.Text)
check(
	"income + friend bonus shown",
	string.find(hud.Coins.Cps.Text, "+12 / sec", 1, true) and string.find(hud.Coins.Cps.Text, "+10%", 1, true)
)
check("egg timer", string.find(hud.Egg.Text, "Storm egg", 1, true) ~= nil, hud.Egg.Text)
check("waiting dragons", string.find(hud.Waiting.Text, "2 dragons", 1, true) ~= nil)
check("gift dot", hud.GiftButton.Dot.Visible == true)
check("home marker on my base", gui:FindFirstChild("HomeMarker") and gui.HomeMarker.Adornee == laser)

-- Carry banner
serverSends("Profile", { carrying = { id = "BLAZE", name = "Blaze", rarity = "Epic", kind = "stolen" } })
check("carry banner", hud.Carry.Visible and string.find(hud.Carry.Text.Text, "RUN HOME", 1, true) ~= nil)
check("home marker grows while carrying", gui.HomeMarker.Size.X.Offset > 200)
serverSends("Profile", { carrying = false })
check("carry banner hides", hud.Carry.Visible == false)

-- Goal
serverSends(
	"Profile",
	{ goal = { index = 2, total = 15, text = "Buy 2 dragons", progress = 1, target = 2, reward = 100 } }
)
check("goal card", hud.Goal.Visible and string.find(hud.Goal.Text.Text, "Buy 2 dragons", 1, true) ~= nil)
check("goal progress bar", math.abs(hud.Goal.Bar.Fill.Size.X.Scale - 0.5) < 1e-6)

-- Tutorial
local target = Instance.new("Part", Engine.workspace)
target.Name = "FreePad"
serverSends("Tutorial", { step = 1, total = 8, text = "Grab the FREE dragon!", target = target })
local tut = gui.Tutorial
check("tutorial card", tut.Card.Visible and tut.Card.Text.Text == "Grab the FREE dragon!")
check("tutorial hides the goal", hud.Goal.Visible == false)
check("tutorial arrow", gui:FindFirstChild("TutorialArrow") and gui.TutorialArrow.Adornee == target)
click(tut, "Skip")
check("skip sent", sent("SkipTutorial") ~= nil)
-- Glowing path to the target
local function litChevrons()
	local lit = {}
	for _, c in Engine.workspace.GuidePath:GetChildren() do
		if c.Transparency < 1 then
			table.insert(lit, c)
		end
	end
	return lit
end
target.CFrame = CFrame.new(60, 1, 0)
Engine.advance(0.3)
check("glowing path to the tutorial target", #litChevrons() > 10, #litChevrons())
-- a target inside a base: the path goes in through the gate, not through the wall
local bases = Engine.workspace:FindFirstChild("Bases") or Instance.new("Folder", Engine.workspace)
bases.Name = "Bases"
local fakeBase = Instance.new("Model", bases)
fakeBase.Name = "Base3"
local baseCf = CFrame.lookAt(Vector3.new(100, 0, 48), Vector3.new(100, 0, 0))
local floor = Instance.new("Part", fakeBase)
floor.Name = "Floor"
floor.Size = Vector3.new(46, 0.4, 60)
floor.CFrame = baseCf
local laser = Instance.new("Part", fakeBase)
laser.Name = "Laser"
laser.Size = Vector3.new(15, 10, 0.4)
laser.CFrame = baseCf * CFrame.new(0, 5.6, -30)
local pad = Instance.new("Part", fakeBase)
pad.Name = "LockPad"
pad.CFrame = baseCf * CFrame.new(10, 0.6, -24)
serverSends("Tutorial", { step = 4, total = 8, text = "Lock your door", target = pad })
Engine.advance(0.3)
local throughGate = false
for _, c in litChevrons() do
	local d = Vector3.new(c.Position.X - laser.Position.X, 0, c.Position.Z - laser.Position.Z).Magnitude
	if d < 4 then
		throughGate = true
	end
end
check("path enters the base through its gate", throughGate)
serverSends("Tutorial", false)
Engine.advance(0.3)
check("path gone with the tutorial", #litChevrons() == 0, #litChevrons())
-- carrying a dragon: the path leads home
serverSends("Profile", { baseIndex = 3, carrying = { kind = "bought", id = "PUFF" } })
Engine.advance(0.3)
check("carrying: glowing path home", #litChevrons() > 10, #litChevrons())
serverSends("Profile", { carrying = false })
Engine.advance(0.3)
check("path gone once home", #litChevrons() == 0)
fakeBase:Destroy()
check("tutorial gone", tut.Card.Visible == false and gui:FindFirstChild("TutorialArrow") == nil)

-- Toasts, alerts, popups, bonked, events
serverSends("Toast", "Door locked!", "good")
check("toast", findButton(hud, "x") == nil and #hud.Toasts:GetChildren() >= 2)
serverSends("Alert", "STOLEN!", Color3.fromRGB(80, 220, 120))
check("alert", hud.Alert.Visible and hud.Alert.Text == "STOLEN!")
serverSends("Popup", Vector3.new(0, 5, 0), "+50", Color3.fromRGB(255, 215, 60))
check("popup in world", Engine.workspace:FindFirstChild("PopupAnchor") ~= nil)
Engine.advance(1.5)
check("popup cleans up", Engine.workspace:FindFirstChild("PopupAnchor") == nil)
serverSends("Bonked", 1.5)
check("bonked overlay", hud.Bonked.Visible)
Engine.advance(2)
check("bonked overlay hides", hud.Bonked.Visible == false)
serverSends("Event", { kind = "legend", at = Engine.workspace:GetServerTimeNow() + 20 })
serverSends("Event", { kind = "luck", untilTime = Engine.workspace:GetServerTimeNow() + 600, by = "Ben" })
Engine.advance(0.4)
check("legend countdown", hud.Event.Visible and string.find(hud.Event.Text.Text, "LEGEND", 1, true) ~= nil)
check("luck banner", hud.Luck.Visible)
serverSends("Profile", { lockUntil = Engine.workspace:GetServerTimeNow() + 42 })
Engine.advance(0.3)
check("lock button counts down", string.find(hud.LockButton.Text, "0:4", 1, true) ~= nil, hud.LockButton.Text)

-- Action buttons
check("no BONK button (the bat is in the hotbar)", hud:FindFirstChild("BonkButton") == nil)
hud.LockButton.Activated:Fire()
Engine.advance(0.05)
check("lock button", sent("Lock") ~= nil)
Engine.actions.Bonk(nil, Engine.Enum.UserInputState.Begin)
check("bonk key", countSent("Bonk") == 1)
Engine.actions.Lock(nil, Engine.Enum.UserInputState.Begin)
check("lock key", countSent("Lock") == 2)

-- Key hints follow the input in use
check("no key hints on a touch screen", hud.LockButton.KeyHint.Visible == false)
Engine.setInput(Engine.Enum.UserInputType.Keyboard)
check("keyboard hint L on LOCK", hud.LockButton.KeyHint.Visible and hud.LockButton.KeyHint.Text == "L")
Engine.setInput(Engine.Enum.UserInputType.Gamepad1)
check("gamepad hint Y on LOCK", hud.LockButton.KeyHint.Text == "Y")

-- Panels
local panels = gui.Panels
hud.ShopButton.Activated:Fire()
Engine.advance(0.05)
check("shop opens", panels.Dim.Visible and string.find(panels.Dim.Card.Title.Text, "SHOP", 1, true) ~= nil)
check("boost cards", panels.Dim.Card.Body:FindFirstChild("LUCK") ~= nil)
check("hidden products not listed", panels.Dim.Card.Body:FindFirstChild("GROW") == nil)
check("gamepad: the first panel button is selected", Engine.game:GetService("GuiService").SelectedObject ~= nil)
Engine.setInput(Engine.Enum.UserInputType.Touch)
local luckBuy = findButton(panels.Dim.Card.Body.LUCK, "R$ 99")
click(panels.Dim.Card.Body.LUCK, "R$ 99")
check("purchase button shows it's busy", luckBuy.Text == "...")
luckBuy.Activated:Fire()
Engine.advance(0.05)
check("double tap doesn't buy twice", countSent("Purchase") == 1)
Engine.advance(2)
check("button comes back", luckBuy.Text == "R$ 99")
local p = sent("Purchase")
check("buy Server Luck", p and p.args[1] == "product" and p.args[2] == "LUCK")
click(panels.Dim.Card.Tabs, "PASSES")
check("pass cards", panels.Dim.Card.Body:FindFirstChild("DOUBLE") ~= nil)
click(panels.Dim.Card.Body.DOUBLE, "R$ 129")
p = sent("Purchase")
check("buy 2x Coins", p and p.args[1] == "pass" and p.args[2] == "DOUBLE")
serverSends("Profile", { passes = { DOUBLE = true } })
check("owned pass shows OWNED", findButton(panels.Dim.Card.Body.DOUBLE, "OWNED") ~= nil)
Engine.advance(2)
click(panels.Dim.Card.Tabs, "SKINS")
check(
	"skin cards",
	panels.Dim.Card.Body:FindFirstChild("MIDNIGHT") ~= nil and panels.Dim.Card.Body:FindFirstChild("LAVA") ~= nil
)
check("Classic is worn at first", findButton(panels.Dim.Card.Body.CLASSIC, "EQUIPPED") ~= nil)
check("coin skin shows its price", findButton(panels.Dim.Card.Body.MIDNIGHT, "5K") ~= nil)
check("Robux skin shows its price", findButton(panels.Dim.Card.Body.LAVA, "R$ 99") ~= nil)
click(panels.Dim.Card.Body.MIDNIGHT, "5K")
p = sent("BuySkin")
check("buy a skin", p and p.args[1] == "MIDNIGHT")
serverSends("Profile", { skins = { CLASSIC = true, MIDNIGHT = true }, skin = "MIDNIGHT" })
check("bought skin shows EQUIPPED", findButton(panels.Dim.Card.Body.MIDNIGHT, "EQUIPPED") ~= nil)
check("Classic can be put back on", findButton(panels.Dim.Card.Body.CLASSIC, "EQUIP") ~= nil)
click(panels.Dim.Card, "✕")
check("panel closes", panels.Dim.Visible == false)

hud.SpeedButton.Activated:Fire()
Engine.advance(0.05)
click(panels.Dim.Card.Body, "+1 SPEED")
check("buy speed", sent("BuySpeed") ~= nil)
hud.GiftButton.Activated:Fire()
Engine.advance(0.05)
check("gift panel", string.find(panels.Dim.Card.Title.Text, "GIFT", 1, true) ~= nil)
check("7 day tiles", panels.Dim.Card.Body.Days:FindFirstChild("Day7") ~= nil)
click(panels.Dim.Card.Body, "CLAIM")
check("claim daily", sent("ClaimDaily") ~= nil and panels.Dim.Visible == false)

serverSends("Offline", { coins = 5000, seconds = 3600 })
check("welcome back panel", panels.Dim.Visible and string.find(panels.Dim.Card.Title.Text, "WELCOME", 1, true) ~= nil)
click(panels.Dim.Card.Body, "CLAIM")
check("claim offline", sent("ClaimOffline") ~= nil)

hud.InviteButton.Activated:Fire()
Engine.advance(0.05)
check("invite prompt", Engine.invites == 1)

-- Prompt filtering
local function makePrompt(kind, owner)
	local part = Instance.new("Part", Engine.workspace)
	local pr = Instance.new("ProximityPrompt", part)
	pr:SetAttribute("Kind", kind)
	pr:SetAttribute("OwnerUserId", owner)
	CollectionService:AddTag(pr, "DragonPrompt")
	Engine.advance(0.05)
	return pr
end
local stealOther = makePrompt("steal", 50)
local stealMine = makePrompt("steal", 7)
local stealFriend = makePrompt("steal", 99)
local sellMine = makePrompt("sell", 7)
local sellOther = makePrompt("sell", 50)
local buy = makePrompt("buy", 0)
local free = makePrompt("free", 0)
check("steal on others' dragons", stealOther.Enabled == true)
check("no steal on my dragons", stealMine.Enabled == false)
check("no steal on friends' dragons", stealFriend.Enabled == false)
check("sell on my dragons only", sellMine.Enabled == true and sellOther.Enabled == false)
check("free dragon before tutorial", free.Enabled == true)
serverSends("Profile", { carrying = { id = "PUFF", name = "Puff", rarity = "Common", kind = "bought" } })
check("hands full hides buy and steal", buy.Enabled == false and stealOther.Enabled == false)
serverSends("Profile", { carrying = false, tutorialDone = true })
check("free dragon hidden after tutorial", free.Enabled == false and buy.Enabled == true)

-- Rainbow dragon colours cycle
local rainbow = Instance.new("Model", Engine.workspace)
local body = Instance.new("Part", rainbow)
body.Name = "Body"
body.Color = Color3.new(0, 0, 0)
CollectionService:AddTag(rainbow, "RainbowDragon")
Engine.advance(0.3)
check("rainbow dragon colours change", body.Color.R + body.Color.G + body.Color.B > 0)

-- Closing panels: tap outside, or gamepad B
hud.ShopButton.Activated:Fire()
Engine.advance(0.05)
panels.Dim.Outside.Activated:Fire()
Engine.advance(0.05)
check("tap outside closes the panel", panels.Dim.Visible == false)
hud.GiftButton.Activated:Fire()
Engine.advance(0.05)
Engine.actions.ClosePanel(nil, Engine.Enum.UserInputState.Begin)
check("gamepad B closes the panel", panels.Dim.Visible == false)

-- Accessibility settings
local GuiService = Engine.game:GetService("GuiService")
Engine.setProperty(GuiService, "PreferredTransparency", 0)
check("solid backgrounds when the player turns transparency off", hud.Egg.BackgroundTransparency == 0)
GuiService.ReducedMotionEnabled = true
serverSends("Profile", { coins = 777 })
check("reduced motion: numbers snap", hud.Coins.Value.Text == "777", hud.Coins.Value.Text)
GuiService.ReducedMotionEnabled = false

-- Dragon Wings: click to jump high, glide in the air, not while carrying
do
	local character = player.Character
	local hum = character.Humanoid
	local hrp = character.HumanoidRootPart
	local wingsTool = Engine.Instance.new("Tool")
	wingsTool.Name = "Dragon Wings"
	wingsTool:SetAttribute("Kind", "wings")
	wingsTool.Parent = character
	Engine.advance(0.05)
	hum.FloorMaterial = Engine.Enum.Material.Grass
	hum.MoveDirection = Vector3.new(1, 0, 0)
	hrp.AssemblyLinearVelocity = Vector3.zero
	wingsTool.Activated:Fire()
	check("wings launch you up", hrp.AssemblyLinearVelocity.Y == Constants.WINGS_LAUNCH, hrp.AssemblyLinearVelocity.Y)
	hum.FloorMaterial = Engine.Enum.Material.Air
	hrp.AssemblyLinearVelocity = Vector3.new(0, -40, 0)
	Engine.advance(0.05)
	local v = hrp.AssemblyLinearVelocity
	check("gliding: slow fall", v.Y == -Constants.GLIDE_FALL, v.Y)
	check("gliding: fly where you steer", math.abs(v.X - Constants.GLIDE_SPEED) < 0.01, v.X)
	serverSends("Profile", { carrying = { id = "PUFF", name = "Puff", rarity = "Common", kind = "bought" } })
	Engine.advance(0.05)
	hrp.AssemblyLinearVelocity = Vector3.new(0, -40, 0)
	Engine.advance(0.05)
	check("no gliding with a dragon", hrp.AssemblyLinearVelocity.Y == -40)
	serverSends("Profile", { carrying = false })
	Engine.advance(0.05)
	wingsTool:Destroy()
	hum.FloorMaterial = Engine.Enum.Material.Grass
	hum.MoveDirection = Vector3.zero
end

-- Rotating to a bigger screen rescales
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1920, 1080)
Engine.advance(1.2)
check("rescales on a bigger screen", hud.Scale.Scale > 1, hud.Scale.Scale)

check("no script errors", #Engine.errors == 0, Engine.errors[1])
check("no warnings", #Engine.warnings == 0, Engine.warnings[1])
print(`{passed} passed, {failed} failed, {#Engine.errors} script errors, {#Engine.warnings} warnings`)
if failed > 0 or #Engine.errors > 0 then
	error("client smoke test failed")
end
