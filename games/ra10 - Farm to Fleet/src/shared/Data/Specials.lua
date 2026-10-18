--[[
Special Orders (master plan §13.3): rare, big, on a short clock. One breaks in every EVERY_MIN..EVERY_MAX minutes of
play once the packing shed stands, and one is waiting on the first visit of each (UTC) day. It comes on an express
truck that pulls up on the shared road where the whole street can see it, pays many times a normal order, often
with Gems, and leaves the moment it's packed.

  emergency   Emergency Supermarket: a big mixed order of quick crops, 10 minutes
  golden      Golden Harvest: only golden crops will do (the scarecrow and the cows suddenly matter)
  chef        Celebrity Chef: one premium crop, plenty of it
  night       Night Express: only in the evening and the night (UTC 18:00-06:00), 8 minutes
  holiday     Holiday Mega Delivery: weekends only (Friday to Sunday, UTC): huge, half an hour, lots of Gems

  Specials.KINDS[key]          { key, name, time (seconds), mult, gems, weight, when? (t -> bool) }
  Specials.available(t)        the kinds that can come at UTC time t (os.time())
  Specials.make(level, rng, t) -> { kind, who, items = { [item] = n }, value, mult, gems, time }   items "*crop"
                               are golden crops
  Specials.reward(special, bonus) -> Cash, XP
]]
local Crops = require(script.Parent.Crops)
local Orders = require(script.Parent.Orders)

local Specials = {}

Specials.EVERY_MIN = 20 * 60 -- seconds of play between specials, at least...
Specials.EVERY_MAX = 40 * 60 -- ...and at most
Specials.FIRST = 4 * 60 -- the first one, after the shed's built
Specials.EXPRESS = 12 -- seconds the express truck takes to drive off with it (it pays when it's gone)

local function hour(t)
	return os.date("!*t", t).hour
end
local function night(t)
	local h = hour(t)
	return h >= 18 or h < 6
end
local function weekend(t)
	local wday = os.date("!*t", t).wday -- (1 Sunday .. 7 Saturday)
	return wday == 1 or wday == 6 or wday == 7
end

-- stylua: ignore start
Specials.KINDS = {
	emergency = { key = "emergency", name = "Emergency Supermarket", time = 10 * 60, mult = 6,  gems = 3,  weight = 4 },
	golden    = { key = "golden",    name = "Golden Harvest",        time = 20 * 60, mult = 3,  gems = 5,  weight = 2 },
	chef      = { key = "chef",      name = "Celebrity Chef",        time = 15 * 60, mult = 8,  gems = 4,  weight = 3 },
	night     = { key = "night",     name = "Night Express",         time = 8 * 60,  mult = 7,  gems = 3,  weight = 3,
		when = night },
	holiday   = { key = "holiday",   name = "Holiday Mega Delivery", time = 30 * 60, mult = 10, gems = 10, weight = 5,
		when = weekend },
}
Specials.ORDER = { "emergency", "golden", "chef", "night", "holiday" }
-- stylua: ignore end

function Specials.available(t)
	local out = {}
	for _, key in Specials.ORDER do
		local k = Specials.KINDS[key]
		if not k.when or k.when(t) then
			table.insert(out, k)
		end
	end
	return out
end

-- What can be grown in time: crops that ripen at least four times over before the clock runs out
local function quick(level, time)
	local out = {}
	for _, key in Crops.unlocked(level) do
		if Crops[key].grow <= math.min(Orders.MAX_GROW, (time or Orders.TIME) / 4) then
			table.insert(out, key)
		end
	end
	return out
end

function Specials.make(level, rng, t)
	rng = rng or Random.new()
	rng:NextNumber()
	local kinds = Specials.available(t or os.time())
	local total = 0
	for _, k in kinds do
		total += k.weight
	end
	local roll, kind = rng:NextNumber() * total, kinds[1]
	for _, k in kinds do
		roll -= k.weight
		if roll <= 0 then
			kind = k
			break
		end
	end
	local target = Orders.target(level)
	local items, value = {}, 0
	local function add(key, n)
		local golden = string.sub(key, 1, 1) == "*"
		local c = Crops[golden and string.sub(key, 2) or key]
		items[key] = n
		value += c.value * n * (golden and Crops.GOLDEN_VALUE or 1)
	end
	local pool = quick(level, kind.time)
	if #pool == 0 then
		pool = { "strawberry" }
	end
	if kind.key == "golden" then
		-- a few golden crops of one or two cheap kinds
		for i = 1, math.min(2, #pool) do
			local key = pool[rng:NextInteger(1, math.min(#pool, 3))]
			if not items["*" .. key] then
				add("*" .. key, rng:NextInteger(2, 5) + (i == 1 and 1 or 0))
			end
		end
	elseif kind.key == "chef" then
		-- the best crop they can grow in time: plenty of it
		local best = pool[#pool]
		add(best, math.clamp(math.floor(target * 1.5 / Crops[best].value + 0.5), 3, 60))
	else
		local size = ({ emergency = 3, night = 2, holiday = 6 })[kind.key] or 3
		local count = math.min(#pool, kind.key == "holiday" and 3 or 2)
		for i = 1, count do
			local key = pool[math.max(1, #pool - (i - 1))]
			add(key, math.clamp(math.floor(target * size / count / Crops[key].value + 0.5), 5, 240))
		end
	end
	local who = ({
		emergency = { "MegaMart", "FreshCo Supermarket", "Corner Grocer Chain" },
		golden = { "The Royal Kitchen", "Golden Spoon", "Museum Gala" },
		chef = { "Chef Rosa", "Chef Marco", "Chef Yuki" },
		night = { "Night Market", "24h Diner", "Moonlight Bakery" },
		holiday = { "Holiday Festival", "City Parade", "Winter Fair" },
	})[kind.key]
	return {
		kind = kind.key,
		name = kind.name,
		who = who[rng:NextInteger(1, #who)],
		items = items,
		value = value,
		mult = kind.mult,
		gems = kind.gems,
		time = kind.time,
	}
end

function Specials.reward(special, bonus)
	local cash = math.floor(special.value * special.mult * (1 + (bonus or 0)) + 0.5)
	return cash, math.max(20, math.floor(cash / 30))
end

return Specials
