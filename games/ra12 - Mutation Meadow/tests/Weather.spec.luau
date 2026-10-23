local Assert = require("./mock/Assert")
local Farm = require("./mock/Farm")
local Server = require("./mock/Server")

local test, eq = Assert.test, Assert.eq

-- count roll attempts per crop (player:tile:plantedAt)
local function countRolls(ctx)
	local counts = {}
	local real = ctx.Mut.roll
	ctx.Mut.roll = function(player, tileId, ...)
		local tile = ctx.Data.get(player).tiles[tileId]
		local key = `{player.UserId}:{tileId}:{tile and tile.plantedAt}`
		counts[key] = (counts[key] or 0) + 1
		return real(player, tileId, ...)
	end
	return counts
end

test("10,000 seeded picks: Rain 80% +-1.5", function()
	local ctx = Farm.setup()
	local rng = ctx.engine.Random.new(2026)
	local rain = 0
	for _ = 1, 10000 do
		if ctx.Weather.pick(rng) == "rain" then
			rain += 1
		end
	end
	Assert.truthy(math.abs(rain / 10000 - 0.8) <= 0.015, `rain {rain / 100}%`)
end)

test("every crop rolls exactly once per event; one planted during it rolls once too", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	for _, id in { "1", "2", "3", "9" } do
		Farm.crop(ctx, p, id, "corn")
	end
	Farm.crop(ctx, p, "10", "corn", true) -- ripe crops roll as well
	local counts = countRolls(ctx)
	ctx.engine:run(function()
		ctx.Weather.startEvent("rain")
	end)
	ctx.engine:advance(100)
	eq(Farm.call(ctx, p, "Plot", "plant", { tile = "11", seed = "carrot" }), true)
	ctx.engine:advance(250)
	local n, total = 0, 0
	for _, c in counts do
		n += 1
		total += c
		eq(c, 1)
	end
	eq({ n, total }, { 6, 6 })
	eq(ctx.Weather.current(), nil, "300s later it ended")
end)

test("a crop harvested before its roll doesn't roll; a player who left never rolls", function()
	local ctx = Farm.setup()
	local a = Farm.join(ctx, 1)
	local b = Farm.join(ctx, 2)
	Farm.crop(ctx, a, "1", "corn")
	Farm.crop(ctx, a, "2", "corn")
	Farm.crop(ctx, b, "1", "corn")
	local counts = countRolls(ctx)
	ctx.engine:run(function()
		ctx.Weather.startEvent("rain")
		ctx.Data.get(a).tiles["2"] = nil -- harvested right away
	end)
	ctx.engine:removePlayer(b)
	ctx.engine:advance(310)
	local keys = {}
	for k in counts do
		table.insert(keys, k)
	end
	eq(#keys, 1)
	Assert.truthy(keys[1]:find("^1:1:"), keys[1])
end)

test("Rain grows every plot 1.5x; Golden Hour warms the lighting and doesn't", function()
	local ctx = Farm.setup()
	local p = Farm.join(ctx, 1)
	local profile = ctx.Data.get(p)
	local lighting = ctx.engine.game.Lighting
	ctx.engine:run(function()
		ctx.Weather.startEvent("rain")
	end)
	eq(ctx.FarmS.rateFor(p, profile, "1"), 1.5)
	local weather = ctx.engine:clientEvents("Weather", 1)
	eq(weather[#weather][1].scope, "server")
	eq(weather[#weather][1].kind, "rain")
	ctx.engine:run(function()
		ctx.Weather.startEvent("goldenHour")
	end)
	eq(ctx.FarmS.rateFor(p, profile, "1"), 1)
	Assert.truthy(lighting.ClockTime ~= 14, "golden light")
	ctx.engine:run(function()
		ctx.Weather.stopEvent()
	end)
	eq(lighting.ClockTime, 14, "restored")
	eq(ctx.engine:clientEvents("Weather", 1)[#ctx.engine:clientEvents("Weather", 1)][1].kind, nil)
end)

local function showerSetup()
	local ctx = Farm.setup(nil, function(e)
		Server.patchConfig(e, function(cfg)
			cfg.Mutations.wet.chance.welcomeShower = 0 -- only the guaranteed one
		end)
	end)
	local p = Farm.join(ctx, 1)
	local other = Farm.join(ctx, 2)
	return ctx, p, other
end

test("the Welcome Shower guarantees exactly 1 Wet at +10s, on the best crop, on its own plot only", function()
	local ctx, p, other = showerSetup()
	Farm.crop(ctx, p, "1", "carrot")
	Farm.crop(ctx, p, "2", "corn")
	Farm.crop(ctx, p, "3", "tomato")
	Farm.crop(ctx, other, "1", "corn")
	local start = ctx.engine.now
	ctx.engine:run(function()
		ctx.Weather.startShower(p)
	end)
	local weather = ctx.engine:clientEvents("Weather", 1)
	eq({ weather[#weather][1].scope, weather[#weather][1].kind }, { "ownPlot", "rain" })
	for _, args in ctx.engine:clientEvents("Weather", 2) do
		Assert.truthy(args[1].scope ~= "ownPlot", "only the owner hears the shower")
	end
	eq(ctx.FarmS.rateFor(p, ctx.Data.get(p), "1"), 1.5)
	eq(ctx.FarmS.rateFor(other, ctx.Data.get(other), "1"), 1)
	Farm.at(ctx, start + 9.5)
	eq(ctx.Data.get(p).tiles["2"].muts, {})
	Farm.at(ctx, start + 11)
	local wet = 0
	for _, tile in ctx.Data.get(p).tiles do
		if tile.muts.wet then
			wet += 1
		end
	end
	eq(wet, 1)
	eq(ctx.Data.get(p).tiles["2"].muts, { wet = true }, "corn sells best")
	eq(ctx.Data.get(p).firstSession.wetGuaranteed, true)
	eq(ctx.Data.get(other).tiles["1"].muts, {})
	Farm.at(ctx, start + 62)
	eq(ctx.Weather.showerOf(p), nil)
	eq(ctx.FarmS.rateFor(p, ctx.Data.get(p), "1"), 1)
end)

test("no crop at +10s: it retries each second; still none -> the next crop gets its Wet 10s after planting", function()
	local ctx, p = showerSetup()
	local start = ctx.engine.now
	ctx.engine:run(function()
		ctx.Weather.startShower(p)
	end)
	Farm.at(ctx, start + 20)
	eq(Farm.call(ctx, p, "Plot", "plant", { tile = "1", seed = "carrot" }), true)
	ctx.engine:advance(1.5)
	eq(ctx.Data.get(p).tiles["1"].muts, { wet = true }, "found on a retry")

	local ctx2, p2 = showerSetup()
	local start2 = ctx2.engine.now
	ctx2.engine:run(function()
		ctx2.Weather.startShower(p2)
	end)
	Farm.at(ctx2, start2 + 62)
	eq(ctx2.Data.get(p2).firstSession.wetGuaranteed, false)
	eq(Farm.call(ctx2, p2, "Plot", "plant", { tile = "1", seed = "carrot" }), true)
	ctx2.engine:advance(9)
	eq(ctx2.Data.get(p2).tiles["1"].muts, {})
	ctx2.engine:advance(2)
	eq(ctx2.Data.get(p2).tiles["1"].muts, { wet = true })
	eq(ctx2.Data.get(p2).firstSession.wetGuaranteed, true)
end)

test("DevCommand weather rain|golden|off", function()
	local ctx = Farm.setup({ studio = true })
	local p = Farm.join(ctx, 1)
	eq(Farm.call(ctx, p, "DevCommand", "run", { cmd = "weather", args = { "golden" } }), true)
	eq(ctx.Weather.current().kind, "goldenHour")
	eq(Farm.call(ctx, p, "DevCommand", "run", { cmd = "weather", args = { "rain" } }), true)
	eq(ctx.Weather.current().kind, "rain")
	eq(Farm.call(ctx, p, "DevCommand", "run", { cmd = "weather", args = { "off" } }), true)
	eq(ctx.Weather.current(), nil)
end)
