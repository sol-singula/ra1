--[[
Cosmetics given outside the win ladder (all cosmetic, nothing that helps in a fight):

  thanks   the Thank-You Trail: for answering "Are you liking the game?" (YES or NO, it's the answer that counts,
           not liking it). A white line running beside your arrow's team-coloured tracer.
  buddy    the Buddy Trail: you invited a friend and they joined, or a friend's invite brought you in (both get it,
           InviteService). Two white lines, one each side of the tracer.
  supporter  the Supporter banner: for tapping VERIFY at the lobby's stand (LobbyService; "if you like the game, tap
           verify": an honour-system thank-you, never gated on a like). A 👍 on your team banners.
  parkour  the Parkour title: for the top of the lobby's parkour tower, the first time (LobbyService).

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
	{ key = "extra_buddy", id = "buddy", kind = "trail", name = "Buddy Trail", desc = "You and a friend, both" },
	{ key = "extra_supporter", id = "supporter", kind = "banner", name = "Supporter", desc = "You tapped VERIFY" },
	{ key = "extra_parkour", id = "parkour", kind = "title", name = "Parkour", desc = "Top of the lobby tower" },
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
