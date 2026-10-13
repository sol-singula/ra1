-- The places the train stops (World/StopBuilder builds them, ExpeditionService picks the next one). Region 1 is the
-- Overgrown Line: a disused forest railway. Each stop has its own landmark, light and mix of materials, and one
-- blueprint at the landmark (the farthest, riskiest spot).
--   minKm      the crew must have travelled this far before it can come up
--   light      the Lighting preset while the train is here (World/LightingPresets)
--   plans      the blueprints found here (the first one the player still needs, else the first one)
--   rich       what there's a lot of (the Searchlight shows this before you arrive)
local Stops = {}

Stops.REGION = "Overgrown Line"

Stops.list = {
	{
		key = "ranger",
		name = "Ranger Station",
		text = "An old ranger post at the edge of the woods. Sheds full of cloth and tools.",
		landmark = "the fire lookout",
		minKm = 0,
		light = "dusk",
		plans = { "map", "specialist" },
		rich = { "cloth", "wood" },
	},
	{
		key = "timber",
		name = "Timber Yard",
		text = "Stacks of lumber and a rusted sawmill. A crane still hangs over the yard.",
		landmark = "the gantry crane",
		minKm = 0,
		light = "overcast",
		plans = { "engine", "specialist" },
		rich = { "wood", "scrap" },
	},
	{
		key = "signal",
		name = "Signal Tower",
		text = "A tall signal tower blinking over relay huts and cable spools.",
		landmark = "the top of the tower",
		minKm = 5,
		light = "bluehour",
		plans = { "radio", "engine" },
		rich = { "parts", "scrap" },
	},
	{
		key = "platform",
		name = "Overgrown Platform",
		text = "A station nobody has used in years, swallowed by vines. Rare finds.",
		landmark = "the old waiting room",
		minKm = 15,
		light = "greenfog",
		plans = { "engine", "radio", "map", "specialist" },
		rich = { "parts", "cloth" },
	},
}

Stops.byKey = {}
for i, s in Stops.list do
	s.index = i
	Stops.byKey[s.key] = s
end

-- The stops the crew can reach at this distance.
function Stops.available(distanceKm)
	local out = {}
	for _, s in Stops.list do
		if distanceKm >= s.minKm then
			table.insert(out, s)
		end
	end
	return out
end

return Stops
