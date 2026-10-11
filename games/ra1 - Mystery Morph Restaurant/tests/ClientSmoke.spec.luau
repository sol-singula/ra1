--[[
Client smoke test: boots the real client scripts on the mock engine, feeds them every server → client event
the game sends, clicks through each panel, and spawns a fake customer proxy. Fails on any script error.

  luaurun tests/ClientSmoke.spec.luau      (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3, CFrame = Engine.Vector3, Engine.CFrame
local Color3 = Engine.globals.Color3

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
-- the server normally creates the remotes
local Net = Engine.require(tree.shared.Net)
Net.init()
Engine.side = "client"

local player = Engine.addPlayer("Chef", 7)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.makeCharacter(player)
Engine.runScript(tree.client.Main)
Engine.advance(0.2)
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
		-- buttons whose caption is a child label (pantry, menu cards)
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
local function sentToServer(name)
	local e = Engine.lastClientEvent(name)
	return e and e.player == "server" and e or nil
end

-- HUD state
serverSends("Profile", {
	mb = 120,
	ms = 4,
	level = 3,
	xp = 50,
	xpReq = 270,
	statPoints = 2,
	stats = { COOK_SPD = 1, COOK_QLT = 0, STR = 0, DEF = 0, REPAIR = 0, MOVE = 0, LUCK = 0, CHARM = 0, EFFICIENCY = 0 },
	effective = {
		COOK_SPD = 4,
		COOK_QLT = 1,
		STR = 0,
		DEF = 0,
		REPAIR = 0,
		MOVE = 0,
		LUCK = 0,
		CHARM = 0,
		EFFICIENCY = 3,
	},
	hp = 90,
	maxHp = 104,
	tier = "TIER_01",
	tierName = "Broken Burger Shack",
	seats = 4,
	menuSlots = 4,
	menu = { "RCP_BRG_001", "RCP_BRG_002", "RCP_FRI_001", "RCP_DRK_001" },
	stars = 2.6,
	nextTier = { name = "Tiny Mutation Diner", cost = 1000, level = 5, seats = 6, menu = 5 },
	mutation = "MUT_145",
	ability = "ABL_012",
})
local hud = gui.HUD
check("HUD built", hud ~= nil)
serverSends("Profile", { levelUp = 4 })
serverSends("Toast", "Hello chef!", "good")
serverSends("Carry", {
	{ name = "Beefy Puck Patty", detail = "GRILLED · PERFECT", color = Color3.new(0.6, 0.3, 0.2), kind = "ING" },
	{ name = "Basic Burger", detail = "Quality 95 %", color = Color3.new(1, 0.9, 0.7), kind = "DISH" },
}, 2)
serverSends("Served", {
	name = "The Polite Demon",
	satisfaction = 96,
	mood = "Delighted",
	pay = 9,
	tip = 2,
	cost = 3,
	net = 8,
	jackpot = false,
	xp = 15,
})
serverSends("Popup", Vector3.new(0, 5, 0), "+8 MB", Color3.new(1, 0.8, 0.2))
serverSends("Cooldown", "ABL_006", 12)
serverSends("Cooldown", "ABL_012", 11)
serverSends("KO", 4)
serverSends("Projectile", Vector3.new(0, 4, 0), Vector3.new(10, 3, 0), 0.9, Color3.new(1, 0, 0))
Engine.advance(2)

-- Pantry picker
serverSends("PantryOpen", { mode = "pantry", options = { "ING_BUN", "ING_BEEF_PATTY", "ING_KETCHUP" } })
click(gui.Panels, "Beefy Puck Patty")
check("pantry pick sent", sentToServer("PantryPick") and sentToServer("PantryPick").args[1] == "ING_BEEF_PATTY")
serverSends("PantryOpen", { mode = "drink", options = { "RCP_DRK_001", "RCP_DRK_002" } })
click(gui.Panels, "Lemonade")

-- Chop minigame
local t = Engine.workspace:GetServerTimeNow()
serverSends("ChopStart", { startAt = t, period = 0.9, taps = 4, done = 1, ingredient = "Crunchy Lettuce Leaf" })
click(gui.Minigames, "CHOP!")
check("chop tap sent", sentToServer("ChopTap") ~= nil)
Engine.actions.MMR_Minigame("MMR_Minigame", Engine.Enum.UserInputState.Begin)
serverSends("ChopProgress", 2, 1.0)
serverSends("ChopProgress", 3, 0.6)
Engine.advance(0.5)
serverSends("ChopEnd")
check("chop overlay closed", #gui.Minigames:GetChildren() == 0)

-- Pour minigame
serverSends(
	"PourStart",
	{ startAt = Engine.workspace:GetServerTimeNow(), seconds = 3, recipe = "Fizzy Soda", maxFill = 1.15 }
)
Engine.advance(1)
click(gui.Minigames, "STOP!")
check("pour stop sent", sentToServer("PourStop") ~= nil)
serverSends("PourEnd")

-- First mutation choice
serverSends("ChooseMutation", { "MUT_145", "MUT_144", "MUT_153" })
local picks = 0
for _, d in gui.Panels:GetDescendants() do
	if d.ClassName == "TextButton" and d.Text == "Pick" then
		picks += 1
	end
end
check("three mutation cards", picks == 3, picks)
click(gui.Panels, "Pick")
check("mutation choice sent", sentToServer("ChooseMutation") ~= nil)

-- Stats panel
click(hud, "Stats")
click(gui.Panels, "+")
check("stat allocation sent", sentToServer("AllocateStat") ~= nil)
serverSends("Profile", {
	statPoints = 1,
	effective = {
		COOK_SPD = 5,
		COOK_QLT = 1,
		STR = 0,
		DEF = 0,
		REPAIR = 0,
		MOVE = 0,
		LUCK = 0,
		CHARM = 0,
		EFFICIENCY = 3,
	},
})
click(gui.Panels, "More stats")
click(gui.Panels, "✕")

-- Menu panel
click(hud, "Menu")
click(gui.Panels, "French Fries") -- toggles off
click(gui.Panels, "Lemonade") -- toggles on (unlocked at level 2)
click(gui.Panels, "Save menu")
local setMenu = sentToServer("SetMenu")
check("menu sent", setMenu ~= nil)
if setMenu then
	local list = setMenu.args[1]
	check("menu edited", table.find(list, "RCP_DRK_002") ~= nil and table.find(list, "RCP_FRI_001") == nil)
end

-- Upgrade panel
click(hud, "Upgrade")
click(gui.Panels, "UPGRADE!")
check("upgrade sent", sentToServer("UpgradeTier") ~= nil)

-- Ability buttons and keys
click(hud, "💗")
check("calm sent", sentToServer("Ability") ~= nil)
Engine.actions.MMR_Mutation("MMR_Mutation", Engine.Enum.UserInputState.Begin)
check("mutation ability sent", sentToServer("Ability").args[1] == "ABL_012")
local UIS = Engine.game:GetService("UserInputService")
UIS.InputBegan:Fire({ UserInputType = Engine.Enum.UserInputType.MouseButton1 }, false)
Engine.advance(0.05)
check("click attacks", sentToServer("Attack") ~= nil)

-- A customer proxy arrives, orders, gets served and leaves
local CollectionService = Engine.game:GetService("CollectionService")
local proxy = Engine.Instance.new("Part")
proxy.Name = "Customer1"
proxy.Size = Vector3.new(2, 5, 2)
proxy.CFrame = CFrame.new(10, 2.5, 10)
proxy:SetAttribute("CustomerId", 1)
proxy:SetAttribute("OwnerUserId", player.UserId)
proxy:SetAttribute("Personality", "PER_002")
proxy:SetAttribute("Seed", 1234)
proxy:SetAttribute("State", "ENTER")
proxy:SetAttribute("Huff", 260)
proxy:SetAttribute("HuffMax", 260)
proxy.Parent = Engine.workspace
CollectionService:AddTag(proxy, "MMR_Customer")
Engine.advance(0.2)
check("customer visual built", Engine.workspace.ClientCustomers:FindFirstChild("The Hungry Hippo-Spider") ~= nil)
proxy:SetAttribute("State", "ORDER")
proxy.CFrame = CFrame.new(0, 2.5, 0)
Engine.advance(0.3)
proxy:SetAttribute(
	"Order",
	Engine.game:GetService("HttpService"):JSONEncode({
		{ name = "Basic Burger", mod = "Hold the pickles. Hold them far, far away.", served = false },
		{ name = "Fizzy Soda", served = true },
	})
)
proxy:SetAttribute("State", "WAIT_FOOD")
proxy:SetAttribute(
	"Order",
	Engine.game:GetService("HttpService"):JSONEncode({
		{
			id = "RCP_BRG_001",
			name = "Basic Burger",
			omit = { "ING_PICKLE" },
			mod = "Hold the pickles.",
			served = false,
		},
	})
)
proxy:SetAttribute("Patience", 0.4)
proxy:SetAttribute("AngerLevel", 3)
proxy:SetAttribute("Huff", 120)
Engine.advance(0.5)
check("recipe card shown", gui.RecipeCard.Card.Visible == true)
local sawLine = false
for _, d in gui.RecipeCard:GetDescendants() do
	if d.ClassName == "TextLabel" and d.Text and string.find(d.Text, "Beefy Puck Patty", 1, true) then
		sawLine = true
	end
end
check("recipe card lists the patty", sawLine)
local tickets = gui.Tickets:GetDescendants()
local sawTicket = false
for _, d in tickets do
	if d.ClassName == "TextLabel" and d.Text and string.find(d.Text, "Basic Burger", 1, true) then
		sawTicket = true
	end
end
check("ticket rail shows the order", sawTicket)
proxy:SetAttribute("State", "DIZZY")
Engine.advance(0.3)
proxy:SetAttribute("Mood", "Delighted")
proxy:SetAttribute("State", "EAT")
Engine.advance(0.3)
proxy:Destroy()
Engine.advance(0.5)
check("customer visual removed", #Engine.workspace.ClientCustomers:GetChildren() == 0)

-- Tutorial card and arrow
serverSends("Tutorial", { step = 3, total = 13, text = "Grab a patty from the Pantry.", target = proxy })
check("tutorial card visible", gui.Tutorial.Card.Visible == true)
check("tutorial arrow placed", gui:FindFirstChild("TutorialArrow") ~= nil)
serverSends("Tutorial", false)
check("tutorial card hidden", gui.Tutorial.Card.Visible == false and gui:FindFirstChild("TutorialArrow") == nil)

-- Food on the grill gets a progress bar
local patty = Engine.Instance.new("Part")
patty.Name = "Item"
patty.CFrame = CFrame.new(0, 3, 0)
patty:SetAttribute("StartAt", Engine.workspace:GetServerTimeNow())
patty:SetAttribute("TReady", 8)
patty:SetAttribute("Window", 2)
patty:SetAttribute("BurnAfter", 6)
patty:SetAttribute("FireAfter", 4)
patty.Parent = Engine.workspace
CollectionService:AddTag(patty, "MMR_Cooking")
Engine.advance(9)
patty:Destroy()
Engine.advance(0.2)

print(
	string.format(
		"%d passed, %d failed, %d script errors, %d warnings",
		passed,
		failed,
		#Engine.errors,
		#Engine.warnings
	)
)
for _, w in Engine.warnings do
	print("  warning: " .. w)
end
if failed > 0 or #Engine.errors > 0 then
	error("client smoke test failed")
end
