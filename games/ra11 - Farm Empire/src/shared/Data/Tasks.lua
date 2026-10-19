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
		text = "Tap the empty tile to plant a strawberry",
		kind = "tile",
		done = function(_, s)
			return (s.planted or 0) >= 1
		end,
	},
	{
		key = "harvest1",
		text = "Harvest the strawberry when it's red",
		kind = "tile",
		done = function(p)
			return (p.stats.harvested or 0) >= 1
		end,
	},
	{
		key = "sale1",
		text = "Watch a customer buy it at the stand",
		kind = "stand",
		done = function(p)
			return (p.stats.sold or 0) >= 1
		end,
	},
	{
		key = "plantAll",
		text = "Plant every empty tile",
		kind = "tile",
		done = function(_, s)
			return s.empty == 0 and s.tiles >= 4
		end,
	},
	{
		key = "tiles1",
		text = "Buy 4 more tiles",
		kind = "upgrade",
		target = "tiles",
		done = function(p)
			return (p.owned.tiles or 0) >= 1
		end,
	},
	{
		key = "counter1",
		text = "The line is growing: upgrade the counter",
		kind = "upgrade",
		target = "counter",
		done = function(p)
			return (p.owned.counter or 0) >= 1
		end,
	},
	{
		key = "seeder1",
		text = "Buy the Auto-Seeder so tiles replant themselves",
		kind = "upgrade",
		target = "seeder",
		done = function(p)
			return (p.owned.seeder or 0) >= 1
		end,
	},
	{
		key = "tomato1",
		text = "Unlock tomatoes: a dearer crop",
		kind = "upgrade",
		target = "tomato",
		done = function(p)
			return (p.owned.tomato or 0) >= 1
		end,
	},
	{
		key = "sign1",
		text = "Put up a road sign: more customers",
		kind = "upgrade",
		target = "sign",
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
	{ key = "harvest50", text = "Harvest 50 crops", stat = "harvested", n = 50, reward = 60 },
	{ key = "sell200", text = "Sell 200 units", stat = "sold", n = 200, reward = 200 },
	{ key = "earn1k", text = "Earn $1,000 all time", stat = "earned", n = 1000, reward = 300 },
	{ key = "harvest500", text = "Harvest 500 crops", stat = "harvested", n = 500, reward = 800 },
	{ key = "earn25k", text = "Earn $25,000 all time", stat = "earned", n = 25000, reward = 3000 },
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
