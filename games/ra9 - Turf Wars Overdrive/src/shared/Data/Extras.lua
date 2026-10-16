--[[
Cosmetics given outside the win ladder (all cosmetic, nothing that helps in a fight):

  thanks   the Thank-You Trail: for answering "Are you liking the game?" (YES or NO, it's the answer that counts,
           not liking it). A white line running beside your arrow's team-coloured tracer.

  Extras.get(key)   the item, or nil
]]
local Extras = {}

Extras.list = {
	{
		key = "extra_thanks",
		id = "thanks",
		kind = "trail",
		name = "Thank-You Trail",
		desc = "For telling us what you think",
	},
}

local byKey = {}
for _, e in Extras.list do
	byKey[e.key] = e
end

function Extras.get(key)
	return byKey[key]
end

-- Is this extra in the profile's extras?
function Extras.owns(profile, key)
	local e = byKey[key]
	return e ~= nil and type(profile.extras) == "table" and profile.extras[e.id] == true
end

return Extras
