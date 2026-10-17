-- The map rotation (master plan §4): four layouts, never the same one twice in a row.
local MapsFolder = script.Parent.Parent.World.Maps

local Maps = {}

Maps.list = {
	require(MapsFolder.CastleClash),
	require(MapsFolder.Frostbite),
	require(MapsFolder.JungleRush),
	require(MapsFolder.DustDevil),
}

local byKey = {}
for i, m in Maps.list do
	m.order = i
	byKey[m.key] = m
end

function Maps.get(key)
	return byKey[key]
end

-- The next map: any but the last one (random among the rest), so the rotation never repeats back to back.
function Maps.next(lastKey, random)
	local choices = {}
	for _, m in Maps.list do
		if m.key ~= lastKey then
			table.insert(choices, m)
		end
	end
	if #choices == 0 then
		return Maps.list[1]
	end
	local r = random or math.random
	return choices[r(1, #choices)]
end

return Maps
