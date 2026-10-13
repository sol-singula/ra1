-- What you can pick up at a stop. Four personal materials (they go to your own storage when you get back on the
-- train), fuel (it goes straight into the train's tank: it belongs to the crew) and blueprints (rare plans for a
-- cabin item or a train upgrade, one at each stop's landmark).
local Resources = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Resources.list = {
	{
		key = "wood",
		name = "Wood",
		icon = "🪵",
		color = rgb(176, 120, 70),
		text = "Furniture, crates, benches.",
	},
	{
		key = "scrap",
		name = "Scrap",
		icon = "🔩",
		color = rgb(150, 156, 168),
		text = "Repairs, fixtures, tools and the engine.",
	},
	{
		key = "parts",
		name = "Parts",
		icon = "⚙️",
		color = rgb(90, 150, 220),
		text = "Mechanical parts: workbenches and engine systems.",
	},
	{
		key = "cloth",
		name = "Cloth",
		icon = "🧵",
		color = rgb(222, 196, 140),
		text = "Bedding, insulation, soft things.",
	},
}

-- the four personal materials, in display order
Resources.MATERIALS = { "wood", "scrap", "parts", "cloth" }

Resources.FUEL = {
	key = "fuel",
	name = "Fuel",
	icon = "⛽",
	color = rgb(220, 60, 50),
	text = "Goes into the train's tank. Every trip burns some.",
}

-- Blueprints: personal ones unlock a cabin item, train ones are given to a train upgrade.
Resources.BLUEPRINTS = {
	map = { name = "Map Board plans", icon = "🗺️", use = "cabin", text = "Build a Map Board in your cabin." },
	specialist = {
		name = "Specialist Station plans",
		icon = "🧰",
		use = "cabin",
		text = "Turn your work surface into a specialist station.",
	},
	engine = {
		name = "Engine plans",
		icon = "📜",
		use = "train",
		text = "Give them to the Engine Overhaul (stages II and III).",
	},
	radio = { name = "Radio Mast plans", icon = "📡", use = "train", text = "Give them to the Radio Mast." },
}

Resources.byKey = {}
for _, r in Resources.list do
	Resources.byKey[r.key] = r
end
Resources.byKey.fuel = Resources.FUEL

function Resources.isMaterial(key)
	return Resources.byKey[key] ~= nil and key ~= "fuel"
end

-- "4 🔩 2 🧵" for a cost table
function Resources.costText(cost)
	local parts = {}
	for _, key in Resources.MATERIALS do
		if cost[key] and cost[key] > 0 then
			table.insert(parts, `{cost[key]} {Resources.byKey[key].icon}`)
		end
	end
	return table.concat(parts, "  ")
end

return Resources
