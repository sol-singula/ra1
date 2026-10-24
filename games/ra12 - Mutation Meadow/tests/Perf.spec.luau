local Assert = require("./mock/Assert")
local Client = require("./mock/Client")
local Farm = require("./mock/Farm")

local test, eq = Assert.test, Assert.eq

test("reduced effects cut mutation particles by 75% and turn the rain sheet off", function()
	local c = Client.boot()
	local Visuals = c.engine:require(c.engine:module("Shared/Visuals"))
	local part = c.engine.Instance.new("Part")
	Visuals.mutationFx(part, "wetgolden")
	eq(part.MutFx.Rate, 14)
	c.state.apply({ { path = { "settings", "reducedFx" }, value = true } })
	eq(part.MutFx.Rate, 14 * 0.25, "live emitters follow the setting")
	local other = c.engine.Instance.new("Part")
	Visuals.mutationFx(other, "wet")
	eq(other.MutFx.Rate, 2)
	c.remotes.Weather.OnClientEvent:Fire({
		kind = "rain",
		scope = "server",
		startsAt = 0,
		endsAt = c.engine.workspace:GetServerTimeNow() + 60,
	})
	c.engine:advance(0.6)
	eq(c.engine.workspace.RainCloud.Rain.Enabled, false, "no rain sheet")
	c.state.apply({ { path = { "settings", "reducedFx" }, value = false } })
	c.engine:advance(0.6)
	eq(c.engine.workspace.RainCloud.Rain.Enabled, true)
	eq(part.MutFx.Rate, 14)
end)

test("mutation sparkles reuse pooled emitters", function()
	local c = Client.boot()
	local Visuals = c.engine:require(c.engine:module("Shared/Visuals"))
	local made = 0
	local parts = {}
	for i = 1, 20 do
		parts[i] = c.engine.Instance.new("Part")
		Visuals.mutationFx(parts[i], "golden")
	end
	local first = parts[1].MutFx
	for i = 1, 20 do
		Visuals.release(parts[i])
	end
	eq(Visuals.poolSize(), 20)
	for i = 1, 20 do
		local p = c.engine.Instance.new("Part")
		Visuals.mutationFx(p, "wet")
		if p.MutFx == first then
			made += 1
		end
	end
	eq(Visuals.poolSize(), 0, "all 20 reused")
	eq(made, 1, "the same emitter came back")
	local p = c.engine.Instance.new("Part")
	Visuals.mutationFx(p, "wet")
	Visuals.mutationFx(p, "golden")
	eq(#p:GetChildren(), 1, "a key change reuses the part's own emitter")
end)

-- the State deltas one player's client receives, in bytes per second (JSON size of each State payload)
test("8 players with full plots: State replication stays under 4 KB/s per player", function()
	local ctx = Farm.setup()
	local HttpService = ctx.engine.game.HttpService
	local players = {}
	for id = 1, 8 do
		players[id] = Farm.join(ctx, id)
		local profile = ctx.Data.get(players[id])
		profile.plotLevel = 5
		local Tiles = ctx.engine:require(ctx.engine:module("Shared/Tiles"))
		for _, tid in Tiles.activeTiles(5, false) do
			Farm.crop(ctx, players[id], tid, if tonumber(tid) % 2 == 0 then "carrot" else "strawberry")
		end
	end
	ctx.engine:advance(10)
	local from = #ctx.engine.remoteLog
	local start = ctx.engine.now
	ctx.engine:advance(120)
	local secs = ctx.engine.now - start
	for id = 1, 8 do
		local bytes = 0
		for i = from + 1, #ctx.engine.remoteLog do
			local e = ctx.engine.remoteLog[i]
			if e.remote == "State" and e.userId == id then
				bytes += #HttpService:JSONEncode(e.args[1])
			end
		end
		Assert.truthy(bytes / secs <= 4096, `player {id}: {math.floor(bytes / secs)} B/s`)
		if id == 1 then
			print(`[perf] State to player 1: {math.floor(bytes / secs)} B/s`)
		end
	end
end)
