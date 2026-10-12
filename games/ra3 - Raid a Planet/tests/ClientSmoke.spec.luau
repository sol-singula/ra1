--[[
Client smoke test: boots the real client scripts on the mock engine as a phone-sized screen, feeds them the
server → client events, presses the HUD buttons, opens every panel, blasts a fake bug and checks what's sent.

  luaurun tests/ClientSmoke.spec.luau      (from the game folder)
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.Vector3
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
Net.init()
Engine.side = "client"
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(844, 390)
local UIS = Engine.game:GetService("UserInputService")
UIS.TouchEnabled = true
UIS.KeyboardEnabled = false

local player = Engine.addPlayer("Ava", 7)
Engine.Players.LocalPlayer = player
Engine.localPlayer = player
Engine.makeCharacter(player)
local mobs = Instance.new("Folder", Engine.workspace)
mobs.Name = "Mobs"
local fx = Instance.new("Folder", Engine.workspace)
fx.Name = "Fx"
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
local function sent(name)
	local e = Engine.lastClientEvent(name)
	return e and e.player == "server" and e or nil
end

local hud = gui:FindFirstChild("Hud")
check("HUD built", hud ~= nil)
check("phone scale applied", math.abs(hud.Scale.Scale - 390 / 560) < 0.01, hud.Scale.Scale)

-- Profile -> HUD
serverSends("Profile", {
	coins = 1234,
	gems = 7,
	ore = { DUST = 42 },
	planet = "DUST",
	unlocked = 1,
	goal = { index = 1, total = 18, text = "Blast 5 bugs", progress = 2, target = 5, reward = "50 💰" },
	playtime = { nextIn = 40, nextText = "100 coins", given = 0, total = 9, boostLeft = 500 },
	forge = {
		slots = { false },
		tiers = {
			{
				key = "small",
				name = "Small Forge",
				ore = 10,
				seconds = 15,
				emoji = "🔥",
				odds = { "Common: 70%", "Rare: 25%", "Epic: 4.5%", "Legend: 0.5%" },
			},
		},
		luck = false,
		luckLeft = 0,
	},
	blasters = {
		{
			uid = 1,
			name = "Dust Zapper",
			rarity = "Common",
			planet = "DUST",
			roll = { dmg = "plain", spd = "plain", luck = "plain", gem = "plain" },
			stars = "",
			lv = 0,
			damage = 5,
			power = 16,
			sell = 10,
			powerUp = 20,
		},
		{
			uid = 2,
			name = "Dust Blaster",
			rarity = "Rare",
			planet = "DUST",
			roll = { dmg = "shiny", spd = "plain", luck = "plain", gem = "plain" },
			stars = "✨",
			lv = 0,
			damage = 15,
			power = 50,
			sell = 40,
			powerUp = 40,
		},
	},
	equipped = 2,
	maxBlasters = 30,
	passes = {},
})
Engine.advance(1.5)
check("coins shown", hud.Coins.Value.Text == "1.2K", hud.Coins.Value.Text)
check("gems shown", hud.Gems.Value.Text == "7")
check("ore shown", string.find(hud.Ore.Text, "42 Dust Ore", 1, true) ~= nil, hud.Ore.Text)
check("planet shown", string.find(hud.Planet.Text, "Dust", 1, true) ~= nil)
check(
	"goal card",
	string.find(hud.Goal.Text.Text, "Blast 5 bugs", 1, true) ~= nil and hud.Goal.Bar.Count.Text == "2 / 5"
)
check("playtime gift pill", hud.Gift.Visible and string.find(hud.Gift.Text, "100 coins", 1, true) ~= nil)
check("boost pill", hud.Boost.Visible and string.find(hud.Boost.Text, "2x", 1, true) ~= nil)
serverSends("Event", { kind = "raid", at = Engine.workspace:GetServerTimeNow() + 600 })
Engine.advance(0.1)
check("raid countdown", hud.Raid.Visible and string.find(hud.Raid.Text, "RAID IN", 1, true) ~= nil, hud.Raid.Text)
serverSends("Event", {
	kind = "raidOpen",
	at = Engine.workspace:GetServerTimeNow() + 900,
	endsAt = Engine.workspace:GetServerTimeNow() + 180,
})
Engine.advance(0.1)
check("raid open pill", string.find(hud.Raid.Text, "RAID OPEN", 1, true) ~= nil, hud.Raid.Text)
serverSends("Profile", { planet = "RAID" })
Engine.advance(0.1)
check(
	"in the arena: the fight clock and the place",
	string.find(hud.Raid.Text, "left", 1, true) ~= nil and string.find(hud.Planet.Text, "Arena", 1, true) ~= nil
)
serverSends("Event", { kind = "raidEnd" })
serverSends("Profile", { planet = "DUST" })

-- Blasting: a fake bug in front, a blaster in hand
local tool = Instance.new("Tool")
tool.Name = "Dust Blaster"
tool:SetAttribute("Kind", "blaster")
tool:SetAttribute("Cooldown", 0.3)
local handle = Instance.new("Part", tool)
handle.Name = "Handle"
tool.Parent = player.Character
local bug = Instance.new("Model", mobs)
bug.Name = "Bug_DUST"
local root = Instance.new("Part", bug)
root.Name = "Root"
bug.PrimaryPart = root
bug:SetAttribute("MobId", 55)
local hrp = player.Character.HumanoidRootPart
root.Position = hrp.Position + hrp.CFrame.LookVector * 10
Engine.advance(0.1)
click(hud, "BLAST")
check("tapping BLAST sends a Blast at the bug", sent("Blast") ~= nil and sent("Blast").args[1] == 55)
local before = Engine.countClientEvents("Blast")
hud.BlastButton.MouseButton1Down:Fire()
Engine.advance(1)
hud.BlastButton.MouseButton1Up:Fire()
check(
	"holding BLAST keeps firing at the cooldown",
	Engine.countClientEvents("Blast") - before >= 3,
	Engine.countClientEvents("Blast") - before
)
serverSends("Beam", hrp.Position, root.Position, Color3.fromRGB(255, 255, 255))
check("beams are drawn", fx:FindFirstChild("Beam") ~= nil)
serverSends("Down", 2)
check("DOWN overlay", hud.Down.Visible)

-- Panels
local panels = gui:FindFirstChild("Panels")
check("panels built", panels ~= nil)
click(hud, "FORGE")
check(
	"Forge panel opens",
	panels.Dim.Visible and string.find(panels.Dim.Card.Header.Title.Text, "FORGE", 1, true) ~= nil
)
check("the Dust ore count shows", findButton(panels, "Dust") ~= nil)
click(panels, "Odds")
check(
	"Odds shows the exact odds",
	(function()
		for _, c in hud.Toasts:GetChildren() do
			if c:IsA("Frame") then
				for _, d in c:GetDescendants() do
					if d.ClassName == "TextLabel" and string.find(d.Text, "Legend: 0.5%", 1, true) then
						return true
					end
				end
			end
		end
		return false
	end)()
)
click(panels, "FORGE!")
check(
	"FORGE! sends Forge small DUST",
	sent("Forge") ~= nil and sent("Forge").args[1] == "small" and sent("Forge").args[2] == "DUST"
)
serverSends("Profile", {
	forge = {
		slots = { { tier = "small", planet = "DUST", left = 12, total = 15, ready = false, finishNow = 79 } },
		tiers = {},
		luck = false,
		luckLeft = 0,
	},
})
Engine.advance(0.1)
check("a cooking slot shows its timer and Finish Now", findButton(panels, "NOW R$ 79") ~= nil)
check(
	"the HUD forge pill counts down",
	hud.ForgeTimer.Visible and string.find(hud.ForgeTimer.Text, "Forge:", 1, true) ~= nil,
	hud.ForgeTimer.Text
)
click(panels, "NOW R$")
check("Finish Now asks the server", sent("FinishNow") ~= nil and sent("FinishNow").args[1] == 1)
serverSends("Profile", {
	forge = {
		slots = { { tier = "small", planet = "DUST", left = 0, total = 15, ready = true } },
		tiers = {},
		luck = false,
		luckLeft = 0,
	},
})
Engine.advance(0.1)
check(
	"a ready slot says TAKE OUT and the pill says READY",
	findButton(panels, "TAKE OUT") ~= nil and string.find(hud.ForgeTimer.Text, "READY", 1, true) ~= nil
)
click(panels, "TAKE OUT")
check("TAKE OUT sends ClaimForge", sent("ClaimForge") ~= nil)
serverSends("Forged", {
	uid = 3,
	name = "Dust Cannon",
	rarity = "Epic",
	planet = "DUST",
	roll = { dmg = "god", spd = "plain", luck = "shiny", gem = "plain" },
	stars = "🌟✨",
	lv = 0,
	damage = 60,
	power = 200,
	sell = 200,
	powerUp = 80,
})
check(
	"the reveal card shows the roll",
	string.find(panels.Dim.Card.Header.Title.Text, "FORGED", 1, true) ~= nil and findButton(panels, "NICE") ~= nil
)
click(panels, "NICE")
check("reveal closes", not panels.Dim.Visible)

click(hud, "BAG")
check("Bag panel lists the blasters", findButton(panels, "HOLD") ~= nil)
click(panels, "HOLD")
check("HOLD sends Equip of the other blaster", sent("Equip") ~= nil and sent("Equip").args[1] == 1)
click(panels, "⬆️")
check("Power Up sends PowerUp", sent("PowerUp") ~= nil)
click(panels, "💰")
check("Sell sends Sell", sent("Sell") ~= nil)
serverSends("Profile", {
	quests = {
		{ text = "Blast 100 bugs", progress = 40, target = 100, gems = 3, done = false },
		{ text = "Join a raid", progress = 1, target = 1, gems = 5, done = true },
	},
	daily = {
		streak = 0,
		canClaim = true,
		nextDay = 1,
		gift = "200 coins",
		gifts = { "200 coins", "30 Dust Ore" },
		secondsToNext = 3600,
	},
	rebirths = 1,
	nightmare = false,
})
Engine.advance(0.1)
check("quest dot when a gift waits", hud.QuestsButton.Dot.Visible == true)
check("Nightmare button after a rebirth", hud.NightmareButton.Visible == true)
click(hud, "QUESTS")
check(
	"Quests panel lists quests and the gift",
	findButton(panels, "CLAIM") ~= nil and string.find(panels.Dim.Card.Header.Title.Text, "QUEST", 1, true) ~= nil
)
click(panels, "CLAIM")
check("CLAIM sends ClaimDaily", sent("ClaimDaily") ~= nil)
panels.Dim.Card.Close.Activated:Fire()
Engine.advance(0.05)
click(hud, "BAG")
click(panels, "🎲")
check("a reroll button sends Reroll", sent("Reroll") ~= nil and sent("Reroll").args[2] ~= nil)
panels.Dim.Card.Close.Activated:Fire()
Engine.advance(0.05)
click(hud, "NIGHT")
check("the Nightmare button sends Nightmare", sent("Nightmare") ~= nil)
-- stalls and booths
serverSends("Profile", {
	stalls = {
		false,
		{
			seller = "Ben",
			sellerId = 99,
			name = "Dust Blaster",
			stars = "✨",
			rarity = "Rare",
			damage = 15,
			price = 25,
		},
	},
	booths = {
		false,
		{ owner = "Ben", ownerId = 99, assetId = 777001, name = "Cool Shirt", price = 5, message = "hi" },
		{ owner = "Ava", ownerId = 7 },
	},
	canTrade = true,
})
Engine.advance(0.1)
local Panels = Engine.require(tree.client.Controllers.PanelController)
Panels.open("Stall", 1)
check("an empty stall offers your blasters at a price", findButton(panels, "SELL 💎") ~= nil)
click(panels, "💎50")
check("a price can be picked", findButton(panels, "SELL 💎50") ~= nil)
click(panels, "SELL 💎50")
check("listing sends ListStall", sent("ListStall") ~= nil and sent("ListStall").args[3] == 50)
Panels.open("Stall", 2)
click(panels, "BUY for 25")
check("buying sends BuyStall", sent("BuyStall") ~= nil and sent("BuyStall").args[1] == 2)
Panels.open("Booth", 1)
click(panels, "CLAIM THIS BOOTH")
check("claiming sends ClaimBooth", sent("ClaimBooth") ~= nil)
Panels.open("Booth", 2)
click(panels, "BUY for R$")
check("a booth buy sends BuyBooth", sent("BuyBooth") ~= nil and sent("BuyBooth").args[1] == 2)
Panels.open("Booth", 3)
local idBox
for _, d in panels:GetDescendants() do
	if d.Name == "AssetId" then
		idBox = d
	end
end
check("my booth has an ID box", idBox ~= nil)
idBox.Text = "123456"
click(panels, "SHOW IT")
check("SHOW IT sends SetBooth with the ID", sent("SetBooth") ~= nil and sent("SetBooth").args[2] == 123456)
Panels.close()
serverSends(
	"Profile",
	{
		petView = {
			pets = {
				{ uid = 9, id = "MOONPUP", name = "Moon Pup", rarity = "Common", dmg = 0.03, luck = 0.02, out = false },
			},
			eggs = {
				{
					key = "STAR",
					name = "Star Egg",
					gems = 25,
					emoji = "🥚",
					odds = { "Common: 75%", "Rare: 22%", "Epic: 3%" },
				},
			},
			slots = 1,
			canRandom = true,
			bonusDmg = 0,
			bonusLuck = 0,
		},
	}
)
Engine.advance(0.1)
click(hud, "PETS")
click(panels, "TAKE OUT")
check("TAKE OUT sends EquipPet", sent("EquipPet") ~= nil and sent("EquipPet").args[1] == 9)
click(panels, "GET EGGS")
click(panels, "💎 25")
check("an egg buy sends BuyEgg", sent("BuyEgg") ~= nil and sent("BuyEgg").args[1] == "STAR")
Panels.close()
click(hud, "SHOP")
check("Shop panel", findButton(panels, "Auto Blast") ~= nil or findButton(panels, "R$ 249") ~= nil)
click(panels, "R$ 249")
check("a pass opens its purchase", sent("Purchase") ~= nil and sent("Purchase").args[1] == "pass")
panels.Dim.Card.Close.Activated:Fire()
Engine.advance(0.05)
check("close button", not panels.Dim.Visible)
click(hud, "HUB")
check("HUB button sends Travel HUB", sent("Travel") ~= nil and sent("Travel").args[1] == "HUB")

-- toasts, alerts, announcements, popups
serverSends("Toast", "Hello!", "good")
check("toast", hud.Toasts:FindFirstChild("Toast") ~= nil)
serverSends("Alert", "BOSS!", Color3.fromRGB(255, 0, 0))
check("alert", hud.Alert.Visible and hud.Alert.Text == "BOSS!")
serverSends("Announce", "Ava beat the Dust King!", Color3.fromRGB(255, 200, 0))
check("announcement banner", hud:FindFirstChild("Announce") ~= nil)
serverSends("Popup", Vector3.new(0, 5, 0), "+5", Color3.fromRGB(255, 255, 0))
check("popup", Engine.workspace:FindFirstChild("PopupAnchor") ~= nil)

check("no script errors", #Engine.errors == 0, Engine.errors[1])
check("no warnings", #Engine.warnings == 0, Engine.warnings[1])
print(`{passed} passed, {failed} failed, {#Engine.errors} script errors, {#Engine.warnings} warnings`)
if failed > 0 or #Engine.errors > 0 then
	error("client smoke test failed")
end
