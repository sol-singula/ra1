--[[
Guidance (master plan §16): three layers, one prominent task on screen.

  Tasks.ONBOARDING   the first primary tasks in order, until the loop is understood. Each: key, text, kind
                     ("tile" | "stand" | "upgrade" | "wait"), target (a tile, the stand, an upgrade key), done(p, s)
  Tasks.GOALS        secondary goals: optional progress with a small reward each
  Tasks.milestone(p) the long-term milestone: the next building's silhouette and price

After onboarding, the primary task is the recommendation: the highest-value affordable upgrade for the bottleneck
(TaskService). Reward text is shown once when a task completes; the next one follows at once.
]]
local Business = require(script.Parent.Business)
local Upgrades = require(script.Parent.Upgrades)

local Tasks = {}

Tasks.ONBOARDING = {
	{
		key = "plant1",
		text = "Tap a brown tile in your field to plant a strawberry",
		kind = "tile",
		reward = 10,
		done = function(_, s)
			return (s.planted or 0) >= 1
		end,
	},
	{
		key = "harvest1",
		text = "It's ripe! Tap it, or walk over it, to harvest",
		kind = "tile",
		reward = 10,
		done = function(p)
			return (p.stats.harvested or 0) >= 1
		end,
	},
	{
		key = "sale1",
		text = "A customer is coming to buy it at your stand",
		kind = "stand",
		reward = 25,
		done = function(p)
			return (p.stats.sold or 0) >= 1
		end,
	},
	{
		key = "plantAll",
		text = "Press PLANT ALL to plant every tile",
		kind = "plantAll",
		reward = 25,
		done = function(_, s)
			return s.empty == 0 and s.tiles >= 4
		end,
	},
	{
		key = "tiles1",
		text = "Step on the glowing pad to buy 4 more tiles",
		kind = "upgrade",
		target = "tiles",
		reward = 40,
		done = function(p)
			return (p.owned.tiles or 0) >= 1
		end,
	},
	{
		key = "counter1",
		text = "A line is forming! Step on the Bigger Counter pad",
		kind = "upgrade",
		target = "counter",
		reward = 60,
		done = function(p)
			return (p.owned.counter or 0) >= 1
		end,
	},
	{
		key = "seeder1",
		text = "Step on the Auto-Seeder pad: tiles replant themselves",
		kind = "upgrade",
		target = "seeder",
		reward = 80,
		done = function(p)
			return (p.owned.seeder or 0) >= 1
		end,
	},
	{
		key = "tomato1",
		text = "Step on the Tomato Seeds pad: tomatoes sell for more",
		kind = "upgrade",
		target = "tomato",
		reward = 120,
		done = function(p)
			return (p.owned.tomato or 0) >= 1
		end,
	},
	{
		key = "sign1",
		text = "Step on the Road Sign pad: more customers",
		kind = "upgrade",
		target = "sign",
		reward = 150,
		done = function(p)
			return (p.owned.sign or 0) >= 1
		end,
	},
}

Tasks.byKey = {}
for i, t in Tasks.ONBOARDING do
	t.index = i
	Tasks.byKey[t.key] = t
end

-- Secondary goals: each pays a little Cash once (the stat it watches and the count)
Tasks.GOALS = {
	{ key = "harvest10", text = "Harvest 10 crops", stat = "harvested", n = 10, reward = 30 },
	{ key = "sell40", text = "Sell 40 crops", stat = "sold", n = 40, reward = 80 },
	{ key = "harvest50", text = "Harvest 50 crops", stat = "harvested", n = 50, reward = 150 },
	{ key = "earn1k", text = "Earn $1,000", stat = "earned", n = 1000, reward = 250 },
	{ key = "sell200", text = "Sell 200 crops", stat = "sold", n = 200, reward = 400 },
	{ key = "earn5k", text = "Earn $5,000", stat = "earned", n = 5000, reward = 800 },
	{ key = "harvest500", text = "Harvest 500 crops", stat = "harvested", n = 500, reward = 1500 },
	{ key = "earn25k", text = "Earn $25,000", stat = "earned", n = 25000, reward = 4000 },
	{ key = "bulk10", text = "Send 10 trucks out", stat = "trucks", n = 10, reward = 6000 },
	{ key = "orders5", text = "Fill 5 market orders", stat = "orders", n = 5, reward = 10000 },
	{ key = "earn1m", text = "Earn $1,000,000 all time", stat = "earned", n = 1000000, reward = 100000 },
}
Tasks.goalByKey = {}
for _, g in Tasks.GOALS do
	Tasks.goalByKey[g.key] = g
end

-- The long-term milestone: the next building, its price and a line about it
function Tasks.milestone(p)
	local nxt = Business.next(p.stage or "stand")
	if not nxt then
		return { key = "region", name = "A New Region", cost = Upgrades.region.cost, text = Business.center.preview }
	end
	return { key = nxt.key, name = nxt.name, cost = nxt.cost, text = Business[p.stage or "stand"].preview }
end

return Tasks
