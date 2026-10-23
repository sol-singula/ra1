local Assert = require("./mock/Assert")
local Client = require("./mock/Client")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local roblox = require("@lune/roblox")
local SIZES = { roblox.Vector2.new(1920, 1080), roblox.Vector2.new(390, 844) }

local function count(root, pattern)
	local n = 0
	for _, d in root:GetDescendants() do
		if d.Name:match(pattern) then
			n += 1
		end
	end
	return n
end

test("the Collection Log: 27 cards, the milestone bar, Claim on a found entry and a reached milestone", function()
	local c = Client.boot(function(p)
		p.collection.found["carrot:wet"] = { at = 1, n = 3 }
		for _, e in { "strawberry:wet", "corn:golden", "corn:wet", "tomato:wet" } do
			p.collection.found[e] = { at = 1, n = 1 }
		end
		p.collection.claimed["corn:golden"] = true
	end)
	Client.press(Client.find(c.gui("Hud"), "Collection"))
	local gui = c.gui("Collection")
	eq(gui.Enabled, true)
	eq(count(gui, "^Card_"), 27)
	local carrot = Client.find(gui, "Card_carrot_wet")
	eq(Client.find(carrot, "Info").Text, "found x3")
	eq(Client.find(Client.find(gui, "Card_pumpkin_golden"), "Name").Text, "???")
	eq(Client.find(Client.find(gui, "Card_corn_golden"), "Claim"), nil, "already claimed")
	Client.press(Client.find(carrot, "Claim"))
	eq(Client.sent(c, "Collection")[1], { "claim", { entry = "carrot:wet", reqId = 1 } })
	eq(Client.find(gui, "Count").Text, "5/27 found")
	Client.press(Client.find(gui, "Milestone_5"))
	eq(Client.sent(c, "Collection")[2], { "claim", { milestone = 5, reqId = 2 } })
	eq(Client.find(gui, "Milestone_10").ClassName, "TextLabel", "10 not reached")
end)

test("a new-entry mutation toast has a one-tap Claim for the crop's whole set", function()
	local c = Client.boot(function(p)
		p.tiles["4"] = { seed = "pumpkin", muts = { wet = true }, plantedAt = 0, grown = 0, harvestsLeft = 1 }
	end)
	c.remotes.Mutation.OnClientEvent:Fire({ tile = "4", mut = "golden", value = 174000, newEntry = true })
	local action = Client.find(c.gui("Hud"), "Action")
	Assert.truthy(action, "a Claim on the toast")
	Client.press(action)
	eq(Client.sent(c, "Collection")[1], { "claim", { entry = "pumpkin:wetgolden", reqId = 1 } })
	c.remotes.Mutation.OnClientEvent:Fire({ tile = "4", mut = "golden", value = 174000, newEntry = false })
	eq(Client.find(c.gui("Hud"), "Action"), nil, "only for a new entry")
end)

test("Daily: 7 tiles, streak, Claim, the reset in local time; opens at the calendar beat with the opt-in", function()
	local c = Client.boot(function(p)
		p.daily = { day = 3, lastClaimDay = 0, streak = 2, cycle = 1 }
	end)
	eq(c.gui("Daily").Enabled, false, "not at a first-session login")
	c.state.apply({ { path = { "firstSession", "calendarShown" }, value = true } })
	c.engine:advance(0.6)
	local gui = c.gui("Daily")
	eq(gui.Enabled, true, "the calendar beat opens it")
	eq(count(gui, "^Day_%d$"), 7)
	eq(Client.find(Client.find(gui, "Day_7"), "Reward").Text, "5 Pumpkin + Petal Trail")
	eq(Client.find(Client.find(gui, "Day_2"), "Title").Text, "✓ Day 2")
	eq(Client.find(gui, "Streak").Text, "🔥 Streak: 2")
	eq(Client.find(gui, "Claim").Text, "Claim Day 3")
	Assert.truthy(Client.find(gui, "Reset").Text:match("^New day at %d+:%d%d [AP]M %(in "), "local reset time")
	Client.press(Client.find(gui, "Claim"))
	eq(Client.sent(c, "Daily")[1], { "claim", { reqId = 1 } })

	local later = Client.boot(function(p)
		p.firstSession.calendarShown = true
	end)
	later.engine:advance(0.6)
	eq(later.gui("Daily").Enabled, true, "a later login opens it when claimable")
end)

test("Quests: the starter list, then 3 daily bars with Claim and a countdown", function()
	local c = Client.boot(function(p)
		p.quests.starter.harvest5 = { n = 3, claimed = false }
	end)
	Client.press(Client.find(c.gui("Hud"), "Quests"))
	local gui = c.gui("Quests")
	eq(count(gui, "^Starter_"), 5)
	eq(Client.find(gui, "Starter_harvest5").Text, "1. Harvest 5 crops (3/5) · 🪙 50")
	c.controllers.QuestController.close()
	local Clock = c.engine:require(c.engine:module("Shared/Clock"))
	local d = Client.boot(function(p)
		for _, key in { "harvest5", "plot2", "keepMut", "pedestal", "help1" } do
			p.quests.starter[key] = { n = 1, claimed = true }
		end
		p.plotLevel = 2
		p.quests.daily =
			{ day = Clock.utcDay(1_760_000_000), progress = { harvest30 = 12, sunflower5 = 5 }, claimed = {} }
	end)
	d.controllers.QuestController.open()
	local g = d.gui("Quests")
	eq(count(g, "^Daily_"), 3)
	eq(count(g, "^Starter_"), 0)
	eq(Client.find(Client.find(g, "Daily_harvest30"), "Count").Text, "12/30")
	eq(Client.find(Client.find(g, "Daily_harvest30"), "Text").Text, "Harvest 30 crops · 🪙 1,200")
	Client.press(Client.find(Client.find(g, "Daily_sunflower5"), "Claim"))
	eq(Client.sent(d, "Quest")[1], { "claim", { questId = "sunflower5", reqId = 1 } })
	Assert.truthy(Client.find(g, "Reset").Text:match("^New quests at "), "countdown")
end)

test("Playtime: 3 boxes; the HUD gift bounces once one is ready", function()
	local c = Client.boot()
	local gift = Client.find(c.gui("Hud"), "Gift")
	c.engine:advance(2)
	eq(gift:GetAttribute("Bouncing"), false)
	Client.press(gift)
	local gui = c.gui("Playtime")
	eq(count(gui, "^Gift_%d$"), 3)
	Assert.truthy(Client.find(Client.find(gui, "Gift_1"), "Status").Text:match("^in 4m"), "counting down")
	c.engine:advance(300)
	eq(gift:GetAttribute("Bouncing"), true)
	Client.press(Client.find(Client.find(gui, "Gift_1"), "Claim"))
	eq(Client.sent(c, "Playtime")[1], { "claim", { index = 1, reqId = 1 } })
end)

test("the update board: world board + HUD view with banner, What's new, Claim and the next update", function()
	local c = Client.boot()
	local now = c.engine.workspace:GetServerTimeNow()
	c.remotes.WeeklyState.OnClientEvent:Fire({
		updateId = "2026-10-24",
		startsAt = now - 60,
		nextAt = now + 7 * 86400 - 60,
		eventWeek = false,
		claimed = false,
		notes = { title = "Moon Melons!", lines = { "A new seed", "Golden Hour is longer" } },
	})
	local surface = c.gui("UpdateBoardSurface")
	Assert.truthy(surface and surface.Adornee and surface.Adornee.Name == "UpdateBoard", "on the world board")
	eq(Client.find(surface, "Banner").Text, "📰 Moon Melons!")
	eq(Client.find(surface, "Note2").Text, "• Golden Hour is longer")
	c.engine.game.ProximityPromptService.PromptTriggered:Fire(c.engine.workspace.Street.Boards.UpdateBoard.View)
	local gui = c.gui("UpdateBoard")
	eq(gui.Enabled, true, "the board's prompt opens the HUD view")
	Assert.truthy(Client.find(gui, "Next").Text:match("^Next update %a%a%a %d+:%d%d [AP]M"), "local time")
	Client.press(Client.find(gui, "Claim"))
	eq(Client.sent(c, "Weekly")[1], { "claim", { updateId = "2026-10-24", reqId = 1 } })
	c.remotes.Toast.OnClientEvent:Fire({
		kind = "board",
		text = "Check the update board!",
		data = { nextUpdateAt = now + 3600, nextPartyAt = now + 600 },
	})
	eq(Client.find(c.gui("Hud"), "Update"):GetAttribute("Pointing"), true, "the HUD points at it")
end)

test("leaderboards: server and global boards with your rank and the reset countdown", function()
	local c = Client.boot()
	local HttpService = c.engine.game.HttpService
	local folder = c.engine.Instance.new("Folder")
	folder.Name = "Leaderboards"
	folder.Parent = c.engine.game.ReplicatedStorage
	c.engine:advance(1.1)
	local now = c.engine.workspace:GetServerTimeNow()
	folder:SetAttribute("ResetAt", now + 3 * 86400)
	folder:SetAttribute(
		"Server",
		HttpService:JSONEncode({
			{ userId = 4, name = "Ann", value = 9000 },
			{ userId = 10, name = "You", value = 120 },
		})
	)
	folder:SetAttribute("Global", HttpService:JSONEncode({ { userId = 4, name = "Ann", value = 9000 } }))
	local server, global = c.gui("ServerBoardSurface"), c.gui("GlobalBoardSurface")
	eq(Client.find(server, "Row1").Text, "1. Ann · 9,000")
	eq(Client.find(server, "You").Text, "You: #2")
	eq(Client.find(global, "You").Text, "You: not ranked yet")
	c.engine:advance(1.1)
	Assert.truthy(
		Client.find(global, "Reset").Text:match("^Resets %a%a%a .*%(in 2d")
			or Client.find(global, "Reset").Text:match("%(in %d+h"),
		Client.find(global, "Reset").Text
	)
end)

test("every M8 screen opens and closes on desktop and a phone", function()
	local c = Client.boot()
	for _, size in SIZES do
		c.engine.workspace.CurrentCamera.ViewportSize = size
		c.engine:advance(0.3)
		for _, pair in
			{
				{ "CollectionController", "Collection" },
				{ "DailyController", "Daily" },
				{ "QuestController", "Quests" },
				{ "PlaytimeController", "Playtime" },
				{ "UpdateBoardController", "UpdateBoard" },
			}
		do
			c.controllers[pair[1]].open()
			eq(c.gui(pair[2]).Enabled, true, pair[2])
			c.controllers[pair[1]].close()
			eq(c.gui(pair[2]).Enabled, false, pair[2])
		end
	end
	eq(c.engine.errors, {})
end)

test("the clock and week DevCommands are Studio-only", function()
	local plain = Farm.setup()
	local nobody = Farm.join(plain, 2)
	eq({ Farm.call(plain, nobody, "DevCommand", "run", { cmd = "clock", args = { "+60" } }) }, { nil, "no_result" })
	eq(plain.engine.workspace:GetAttribute("ClockOffset"), nil, "dropped at the dev gate")
	local live = Farm.setup(nil, function(engine)
		Server.patchConfig(engine, function(Config)
			Config.AdminUserIds = { 1 }
		end)
	end)
	local p = Farm.join(live, 1)
	eq({ Farm.call(live, p, "DevCommand", "run", { cmd = "clock", args = { "+60" } }) }, { false, "studio_only" })
	eq({ Farm.call(live, p, "DevCommand", "run", { cmd = "week", args = { "next" } }) }, { false, "studio_only" })
	local studio = Farm.setup({ studio = true })
	local q = Farm.join(studio, 1)
	local before = studio.Weekly.current().updateId
	eq(Farm.call(studio, q, "DevCommand", "run", { cmd = "week", args = { "next" } }), true)
	Assert.truthy(studio.Weekly.current().updateId ~= before, "the next update")
	eq(Farm.call(studio, q, "DevCommand", "run", { cmd = "clock", args = { "+3600" } }), true)
	Assert.truthy(studio.engine.workspace:GetAttribute("ClockOffset") > 3600, "the clock moved")
end)
