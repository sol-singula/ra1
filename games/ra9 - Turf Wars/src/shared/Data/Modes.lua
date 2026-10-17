--[[
The game's modes: what the lobby's cards and portals say about each, and which places there are. (A stub until the
framework's lands: the same shape, so the lobby reads it either way.)

  Modes.LIST            the playable modes, in the lobby's order
  Modes[key]            { name, blurb, minPlayers, color }
  Modes.multiPlace()    true when each mode is its own place (the lobby teleports); false: one place runs it all
]]
local Modes = {}

Modes.LIST = { "turf", "ctf", "brawl" }

Modes.turf = {
	name = "Turf Wars",
	blurb = "Push the line. Take their base.",
	minPlayers = 2,
	color = Color3.fromRGB(255, 196, 40),
}
Modes.ctf = {
	name = "Capture the Flag",
	blurb = "Steal their flag, run it home.",
	minPlayers = 2,
	color = Color3.fromRGB(150, 90, 240),
}
Modes.brawl = {
	name = "Bot Brawl",
	blurb = "Everyone against the bots.",
	minPlayers = 1,
	color = Color3.fromRGB(46, 170, 90),
}

function Modes.multiPlace()
	return false
end

return Modes
