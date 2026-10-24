local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

local H = (1_760_000_000 // 3600 + 1) * 3600 -- an hour boundary just after the default clock

local function setup(n, opts)
	local ctx =
		Farm.setup({ now = H - 20, studio = opts and opts.studio, privateServerId = opts and opts.privateServerId })
	local players = {}
	for id = 1, n do
		players[id] = Farm.join(ctx, id)
		Farm.standAtSunflower(ctx, players[id])
	end
	Farm.at(ctx, H + 0.5)
	return ctx, players
end

local function water(ctx, player)
	return Farm.call(ctx, player, "BlockParty", "water", {})
end

test("goal: 3 players -> 30, 1 player -> 20; it opens Drooping at the top of the hour", function()
	local ctx = setup(3)
	local w = ctx.BP.state()
	eq({ w.hour, w.goal, w.phase, w.stage, w.waters }, { H, 30, "open", "drooping", 0 })
	local one = setup(1)
	eq(one.BP.state().goal, 20)
	eq({ ctx.BP.goalFor(8), ctx.BP.goalFor(0) }, { 80, 20 })
end)

test(
	"private servers: goal max(2, players), 1 water earns the reward; public stays max(20, 10 x players) and 5",
	function()
		eq({
			setup(2, { privateServerId = "ps-1" }).BP.state().goal,
			setup(3, { privateServerId = "ps-1" }).BP.state().goal,
		}, { 2, 3 })
		local ctx, players = setup(1, { privateServerId = "ps-1" })
		eq({ ctx.BP.isPrivate(), ctx.BP.state().goal, ctx.BP.minWaters() }, { true, 2, 1 })
		eq({ ctx.BP.goalFor(0, true), ctx.BP.goalFor(5, true), ctx.BP.goalFor(5, false) }, { 2, 5, 50 })
		local pub = setup(3)
		eq({ pub.BP.isPrivate(), pub.BP.state().goal, pub.BP.minWaters() }, { false, 30, 5 })

		local two, pair = setup(2, { privateServerId = "ps-1" })
		local a, b = pair[1], pair[2]
		local coinsA, coinsB = two.Data.get(a).coins, two.Data.get(b).coins
		eq(water(two, a), true)
		eq(two.BP.state().stage, "perking")
		eq(water(two, b), true)
		eq(two.BP.state().stage, "bloom", "2 friends bloom it")
		eq(two.Data.get(a).coins, coinsA + 100)
		eq(two.Data.get(b).coins, coinsB + 100)
	end
)

test("a second water within 2s is refused; you must be near the sunflower", function()
	local ctx, players = setup(1)
	local p = players[1]
	eq(water(ctx, p), true)
	local first = ctx.engine.now - 0.11
	Farm.at(ctx, first + 1.9)
	eq({ water(ctx, p) }, { false, "cooldown" })
	Farm.at(ctx, first + 2.05)
	eq(water(ctx, p), true)
	Farm.standAtTile(ctx, p, p, "1")
	Farm.at(ctx, ctx.engine.now + 2.1)
	eq({ water(ctx, p) }, { false, "too_far" })
	eq(ctx.Data.get(p).blockParty.waters, 2)
	eq(ctx.Data.get(p).blockParty.window, H)
end)

test("stages flip at 10, 20 and 30 of 30", function()
	local ctx, players = setup(3)
	local seen = {}
	local count = 0
	for _ = 1, 10 do
		for _, p in players do
			eq(water(ctx, p), true)
			count += 1
			seen[count] = ctx.BP.state().stage
		end
		ctx.engine:advance(2)
	end
	eq(
		{ seen[9], seen[10], seen[19], seen[20], seen[29], seen[30] },
		{ "drooping", "perking", "perking", "standing", "standing", "bloom" }
	)
	eq(ctx.BP.state().phase, "weather")
	local sunflower = ctx.engine.workspace.Street.Sunflower
	eq(sunflower:GetAttribute("Look"), "Bloom")
	eq({ sunflower.Bloom.Petal1.Transparency, sunflower.Bloom.Centre.Transparency }, { 0, 0 })
	eq({ sunflower.Drooping.Petal1.Transparency, sunflower.Drooping.Centre.Transparency }, { 1, 1 })
end)

test("goal met at :02:00: weather :02-:07, wilt to :08, drooped to :60", function()
	local ctx, players = setup(1)
	local p = players[1]
	for i = 1, 20 do
		Farm.at(ctx, H + 120 - (20 - i) * 2.05)
		ctx.engine:fireServer(p, "BlockParty", "water", {})
	end
	local w = ctx.BP.state()
	eq(w.phase, "weather")
	Assert.near(w.bloomAt, H + 120, 0.01)
	local e = ctx.Weather.current()
	Assert.near(e.endsAt, H + 420, 0.01)
	Farm.at(ctx, H + 419.5)
	eq(ctx.BP.state().phase, "weather")
	Farm.at(ctx, H + 422)
	eq(ctx.BP.state().phase, "wilt")
	eq(ctx.engine.workspace.Street.Sunflower:GetAttribute("Look"), "Wilt")
	eq(ctx.engine.workspace.Street.Sunflower.Wilt.Petal1.Transparency, 0)
	Farm.at(ctx, H + 479)
	eq(ctx.BP.state().phase, "wilt")
	Farm.at(ctx, H + 483)
	eq({ ctx.BP.state().phase, ctx.BP.state().stage }, { "drooped", "drooping" })
	Farm.at(ctx, H + 3599)
	eq(ctx.BP.state().phase, "drooped")
	Farm.at(ctx, H + 3601)
	eq({ ctx.BP.state().phase, ctx.BP.state().hour }, { "open", H + 3600 })
end)

test("no goal: it blooms at :10:00 anyway", function()
	local ctx, players = setup(2)
	eq(water(ctx, players[1]), true)
	Farm.at(ctx, H + 599)
	eq(ctx.BP.state().phase, "open")
	Farm.at(ctx, H + 601.5)
	eq(ctx.BP.state().phase, "weather")
	Assert.truthy(ctx.Weather.current(), "the weather started")
	ctx.engine:advance(3)
	eq({ water(ctx, players[1]) }, { false, "closed" })
end)

test("5 waters at level 2 pay 400 once; 4 waters pay nothing; the 10th reward earns sunflower_friend", function()
	local ctx, players = setup(2)
	local a, b = players[1], players[2]
	ctx.Data.get(a).plotLevel = 2
	ctx.Data.get(a).blockParty.rewardsTotal = 9
	local badges = {}
	ctx.BP.BadgeEarned:Connect(function(p, key)
		table.insert(badges, { p.UserId, key })
	end)
	for i = 1, 5 do
		eq(water(ctx, a), true)
		if i <= 4 then
			eq(water(ctx, b), true)
		end
		ctx.engine:advance(2.1)
	end
	local coinsA, coinsB = ctx.Data.get(a).coins, ctx.Data.get(b).coins
	ctx.engine:run(function()
		ctx.BP.bloom(ctx.engine.now)
	end)
	eq(ctx.Data.get(a).coins, coinsA + 400)
	eq(ctx.Data.get(b).coins, coinsB)
	eq({ ctx.Data.get(a).blockParty.rewarded, ctx.Data.get(a).blockParty.rewardsTotal }, { true, 10 })
	eq(badges, { { 1, "sunflower_friend" } })
	ctx.engine:run(function()
		ctx.BP.bloom(ctx.engine.now)
	end)
	eq(ctx.Data.get(a).coins, coinsA + 400, "once")
end)

test("BlockPartyState reaches every player with their own waters, every second while open", function()
	local ctx, players = setup(2)
	eq(water(ctx, players[1]), true)
	ctx.engine:advance(1.5)
	local mine = ctx.engine:clientEvents("BlockPartyState", 1)
	local theirs = ctx.engine:clientEvents("BlockPartyState", 2)
	local last1, last2 = mine[#mine][1], theirs[#theirs][1]
	eq({ last1.waters, last1.yourWaters, last1.goal, last1.phase }, { 1, 1, 20, "open" })
	eq({ last2.waters, last2.yourWaters }, { 1, 0 })
	eq(last1.endsAt, H + 600)
	local n = #mine
	ctx.engine:advance(3)
	Assert.truthy(#ctx.engine:clientEvents("BlockPartyState", 1) >= n + 3, "every second")
end)

test("DevCommand bp start|bloom|end (gated)", function()
	local ctx, players = setup(1, { studio = true })
	local p = players[1]
	Farm.at(ctx, H + 1000) -- drooped by now
	eq(Farm.call(ctx, p, "DevCommand", "run", { cmd = "bp", args = { "start" } }), true)
	eq(ctx.BP.state().phase, "open")
	eq(Farm.call(ctx, p, "DevCommand", "run", { cmd = "bp", args = { "bloom" } }), true)
	eq(ctx.BP.state().phase, "weather")
	eq(Farm.call(ctx, p, "DevCommand", "run", { cmd = "bp", args = { "end" } }), true)
	eq(ctx.BP.state().phase, "drooped")
	eq(ctx.Weather.current(), nil)
	eq(
		{ Farm.call(ctx, p, "DevCommand", "run", { cmd = "bp", args = { "dance" } }) },
		{ false, "usage: bp start|bloom|end" }
	)
	local live, livePlayers = setup(1)
	eq(
		{ Farm.call(live, livePlayers[1], "DevCommand", "run", { cmd = "bp", args = { "start" } }) },
		{ nil, "no_result" },
		"dev_gate outside Studio: dropped, no Result"
	)
end)

test("a server that starts after :10 waits for the next hour", function()
	local ctx = Farm.setup({ now = H + 1200 })
	ctx.engine:advance(1)
	eq(ctx.BP.state().phase, "drooped")
	eq(ctx.Weather.current(), nil)
end)
