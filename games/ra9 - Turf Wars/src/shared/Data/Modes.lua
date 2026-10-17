--[[
The universe: one experience, four places. The lobby is the start place (everyone lands there and picks a game);
the four modes are places of their own, each a server running this same code with Constants.MODE set by the
Mode value Rojo puts under ReplicatedStorage (places/*.project.json; default.project.json is turf, as the one
place has always been). Modes.LIST is what you can play: the lobby isn't one of them.

Until the owner has made the places (Creator Dashboard) and put their ids here, Modes.multiPlace() is false and
everything behaves as today: one place, no teleports (PlaceService only says the mode isn't open yet), the lobby's
features dormant.

  Modes.LIST                     { "turf", "ctf", "brawl", "tycoon" }
  Modes[key]                     { key, name, placeId (0 until made), blurb, minPlayers, bots, color }
  Modes.LOBBY_PLACE              the lobby's place id (0 until made)
  Modes.current()                Constants.MODE ("lobby" | "turf" | "ctf" | "brawl" | "tycoon")
  Modes.get(key)                 the mode, or nil
  Modes.multiPlace()             true only when every place id (the lobby's too) is set
  Modes.runsIn(module, mode?)    a service or controller with Modes = { keys } runs in those modes; none: in all
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Modes = {}

Modes.LIST = { "turf", "ctf", "brawl", "tycoon" }
Modes.LOBBY_PLACE = 0

Modes.turf = {
	key = "turf",
	name = "Turf Wars",
	placeId = 0,
	blurb = "Build, shoot, push the line. Knock the other team off the map!",
	minPlayers = 1,
	bots = true,
	color = Color3.fromRGB(255, 196, 40), -- (the lobby's card and portal)
}
Modes.ctf = {
	key = "ctf",
	name = "Capture the Flag",
	placeId = 0,
	blurb = "Purple v orange. Grab their flag and bring it home!",
	minPlayers = 4,
	bots = false,
	color = Color3.fromRGB(150, 90, 240),
}
Modes.brawl = {
	key = "brawl",
	name = "Bot Brawl",
	placeId = 0,
	blurb = "Team up against waves of bots. How long can you last?",
	minPlayers = 1,
	bots = true,
	color = Color3.fromRGB(46, 170, 90),
}
Modes.tycoon = {
	key = "tycoon",
	name = "Castle Tycoon",
	placeId = 0,
	blurb = "Your own plot. Build a castle, grow your Gold, rebirth!",
	minPlayers = 1,
	bots = false,
	color = Color3.fromRGB(30, 200, 185),
}

function Modes.current()
	return Constants.MODE
end

function Modes.get(key)
	return table.find(Modes.LIST, key) and Modes[key] or nil
end

function Modes.multiPlace()
	if (Modes.LOBBY_PLACE or 0) == 0 then
		return false
	end
	for _, key in Modes.LIST do
		if (Modes[key].placeId or 0) == 0 then
			return false
		end
	end
	return true
end

function Modes.runsIn(module, mode)
	local list = type(module) == "table" and module.Modes or nil
	if type(list) ~= "table" then
		return true
	end
	return table.find(list, mode or Constants.MODE) ~= nil
end

return Modes
