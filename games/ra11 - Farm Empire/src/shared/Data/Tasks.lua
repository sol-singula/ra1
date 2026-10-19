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
		key = "chicken1",
		text = "Step on the Chickens pad by the pens: crops grow faster",
		kind = "upgrade",
		target = "chicken",
		reward = 60,
		done = function(p)
			return (p.owned.chicken or 0) >= 1
		end,
	},
	{
		key = "feed1",
		text = "Step on the chickens' FEED plate (they boost more when fed, and when you pet them)",
		kind = "feed",
		target = "chicken",
		reward = 80,
		done = function(p)
			return (p.stats.fed or 0) + (p.stats.petted or 0) >= 1
		end,
	},
	{
		key = "tomato1",
		text = "Step on the Tomato Seeds pad: tomatoes sell for $40",
		kind = "upgrade",
		target = "tomato",
		reward = 100,
		done = function(p)
			return (p.owned.tomato or 0) >= 1
		end,
	},
	{
		key = "counter1",
		text = "Step on the Bigger Counter pad: sell faster",
		kind = "upgrade",
		target = "counter",
		reward = 120,
		done = function(p)
			return (p.owned.counter or 0) >= 1
		end,
	},
	{
		key = "premium1",
		text = "Step on the Premium Produce pad: every crop sells for 25% more",
		kind = "upgrade",
		target = "premium",
		reward = 200,
		done = function(p)
			return (p.owned.premium or 0) >= 1
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
	{ key = "harvest10", text = "Harvest 10 crops", stat = "harvested", n = 10, reward = 50 },
	{ key = "sell20", text = "Sell 20 crops", stat = "sold", n = 20, reward = 120 },
	{ key = "earn1k", text = "Earn $1,000", stat = "earned", n = 1000, reward = 300 },
	{ key = "feed3", text = "Feed or pet animals 3 times", stat = "fed", n = 3, reward = 600 },
	{ key = "golden1", text = "Tap a golden crop", stat = "golden", n = 1, reward = 1000 },
	{ key = "earn10k", text = "Earn $10,000", stat = "earned", n = 10000, reward = 2500 },
	{ key = "harvest200", text = "Harvest 200 crops", stat = "harvested", n = 200, reward = 5000 },
	{ key = "pet5", text = "Pet happy animals 5 times", stat = "petted", n = 5, reward = 10000 },
	{ key = "earn100k", text = "Earn $100,000", stat = "earned", n = 100000, reward = 25000 },
	{ key = "golden5", text = "Tap 5 golden crops", stat = "golden", n = 5, reward = 50000 },
	{ key = "sell2000", text = "Sell 2,000 crops", stat = "sold", n = 2000, reward = 100000 },
	{ key = "earn1m", text = "Earn $1,000,000", stat = "earned", n = 1000000, reward = 250000 },
	{ key = "feed30", text = "Feed or pet animals 30 times", stat = "fed", n = 30, reward = 500000 },
	{ key = "bulk10", text = "Send 10 trucks out", stat = "trucks", n = 10, reward = 1000000 },
	{ key = "earn10m", text = "Earn $10,000,000", stat = "earned", n = 10000000, reward = 2500000 },
	{ key = "golden25", text = "Tap 25 golden crops", stat = "golden", n = 25, reward = 5000000 },
	{ key = "orders5", text = "Fill 5 market orders", stat = "orders", n = 5, reward = 8000000 },
	{ key = "earn100m", text = "Earn $100,000,000", stat = "earned", n = 100000000, reward = 25000000 },
	{ key = "earn1b", text = "Earn $1,000,000,000", stat = "earned", n = 1000000000, reward = 250000000 },
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
