local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

local function count(list, id)
	local n = 0
	for _, x in list do
		if x == id then
			n += 1
		end
	end
	return n
end

local function rejoin(ctx, p)
	ctx.engine:removePlayer(p)
	ctx.engine:advance(7)
	local again = Farm.join(ctx, p.UserId)
	ctx.engine:advance(15) -- the load retries past the final save's same-key cooldown
	assert(ctx.Data.get(again), "loaded again")
	Farm.standAtTile(ctx, again, again, "1")
	return again
end

test("flagged lines fire once per profile, across rejoins; shopAgain every later open", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	eq(Farm.lines(ctx, p), { "plant" }, "first spawn with nothing planted")
	Farm.openShop(ctx, p)
	Farm.openShop(ctx, p)
	ctx.engine:run(function()
		ctx.Patch.say(p, "shower")
		ctx.Patch.say(p, "shower")
	end)
	p = rejoin(ctx, p)
	Farm.openShop(ctx, p)
	ctx.engine:run(function()
		ctx.Patch.say(p, "shower")
		ctx.Patch.say(p, "plant")
	end)
	local lines = Farm.lines(ctx, p)
	eq(
		{ count(lines, "plant"), count(lines, "shopHello"), count(lines, "shopAgain"), count(lines, "shower") },
		{ 1, 1, 2, 1 }
	)
	local tips = Server.raw(ctx.engine, 1).patchTips
	eq({ tips.plant, tips.shopHello, tips.shower }, { true, true, true }, "saved")
end)

test("mutation: the first mutation on your own crop, as Wet or Golden; blockParty: the first window", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	Farm.crop(ctx, p, "1", "corn")
	Farm.crop(ctx, p, "2", "corn")
	ctx.engine:run(function()
		ctx.Mut.roll(p, "1", "golden", 0.08, Farm.fixedRng(0))
		ctx.Mut.roll(p, "2", "wet", 0.25, Farm.fixedRng(0))
	end)
	local mutation
	for _, args in ctx.engine:clientEvents("PatchLine", 1) do
		if args[1].id == "mutation" then
			Assert.truthy(mutation == nil, "once")
			mutation = args[1]
		end
	end
	eq(mutation, {
		id = "mutation",
		text = "Ooh, a Golden crop! Tap it to keep it.",
		display = "toast",
		hideSec = 5,
		hideOn = "harvest",
	})
	ctx.engine:run(function()
		ctx.BP.open(ctx.engine.now, true)
		ctx.BP.open(ctx.engine.now + 3600, true)
	end)
	eq(count(Farm.lines(ctx, p), "blockParty"), 1)
end)

test("update fires once per updateId", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local Schedule = ctx.engine:require(ctx.engine:module("Shared/Schedule"))
	ctx.engine:run(function()
		eq(ctx.Patch.say(p, "update"), true)
		eq(ctx.Patch.say(p, "update"), false)
	end)
	eq(ctx.Data.get(p).weekly.lineSeen, Schedule.currentUpdate(ctx.engine.now).updateId)
	ctx.Data.get(p).weekly.lineSeen = "2000-01-01" -- a later update went live
	ctx.engine:run(function()
		eq(ctx.Patch.say(p, "update"), true)
	end)
	eq(count(Farm.lines(ctx, p), "update"), 2)
end)

test("every formatted line fits Config.Patch.maxChars (the longest seed name)", function()
	local ctx = Farm.setup()
	local Config = ctx.engine:require(ctx.engine:module("Shared/Config"))
	local longest = ""
	for _, s in Config.Seeds do
		if #s.name > #longest then
			longest = s.name
		end
	end
	for id, line in Config.Patch.lines do
		local fmt = if id == "rare" then longest elseif id == "mutation" then "Golden" else nil
		local text = ctx.Patch.textFor(id, fmt)
		Assert.truthy(not text:find("%%s"), id .. " formatted")
		Assert.truthy(utf8.len(text) <= Config.Patch.maxChars, `{id}: {utf8.len(text)} chars`)
		local _ = line
	end
end)

test(
	"the rig: no Humanoid, an AnimationController + Animator, an orange head, the prompt from Config; faces and naps",
	function()
		local ctx = Farm.setup()
		local rig = ctx.engine.workspace.Street.Patch
		eq(rig:FindFirstChildOfClass("Humanoid"), nil)
		local controller = rig:FindFirstChildOfClass("AnimationController")
		Assert.truthy(controller and controller:FindFirstChildOfClass("Animator"), "animator")
		eq(rig.PumpkinHead.Color, ctx.engine:require(ctx.engine:module("Server/Services/CaptureService")).PATCH_ORANGE)
		local names = {}
		for _, a in rig.Animations:GetChildren() do
			table.insert(names, a.Name)
		end
		table.sort(names)
		eq(names, { "announce", "cheer", "idle", "lean", "point", "wave" })
		local prompt = rig.Counter.ShopPrompt
		eq(
			{ prompt.ActionText, prompt.ObjectText, prompt.MaxActivationDistance, prompt.HoldDuration },
			{ "Shop", "Patch's Seed Shop", 10, 0 }
		)
		local p = Farm.join(ctx, 1)
		eq({ rig:GetAttribute("Anim"), rig:GetAttribute("Face") }, { "point", "happy" }, "the plant line")
		Farm.openShop(ctx, p)
		eq({ rig:GetAttribute("Anim"), rig:GetAttribute("Face") }, { "wave", "happy" })
		Farm.openShop(ctx, p)
		eq({ rig:GetAttribute("Anim"), rig:GetAttribute("Face") }, { "lean", "wink" })
		Farm.standAtTile(ctx, p, p, "1")
		ctx.engine:advance(62)
		eq(rig:GetAttribute("Face"), "sleepy", "nobody near for 60s")
		Farm.standAtPatch(ctx, p)
		ctx.engine:advance(1.5)
		eq(rig:GetAttribute("Face"), "happy", "wakes up")
	end
)

test("Settings: Patch alerts and the rest; patchAck is logged", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	eq(Farm.call(ctx, p, "Settings", "set", { key = "patchAlerts", value = false }), true)
	eq(Farm.call(ctx, p, "Settings", "set", { key = "gnomeOn", value = false }), true)
	local profile = ctx.Data.get(p)
	eq({ profile.settings.patchAlerts, profile.gnomeOn }, { false, false })
	eq(Farm.call(ctx, p, "Settings", "patchAck", { id = "plant", how = "tap" }), true)
	local Telemetry = ctx.engine:require(ctx.engine:module("Server/Telemetry"))
	local shown, dismissed = false, false
	for _, e in Telemetry.events do
		shown = shown or (e.name == "patch_line_shown" and e.data.id == "plant")
		dismissed = dismissed or (e.name == "patch_line_dismissed" and e.data.id == "plant" and e.data.how == "tap")
	end
	eq({ shown, dismissed }, { true, true })
end)
