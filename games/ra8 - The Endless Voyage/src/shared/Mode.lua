-- Which kind of server this is (ModeService sets the workspace's "Mode" attribute):
--   "hub"     a public server: the game plays as usual, and the menu asks MY WORLD or ONLINE
--   "world"   your own world (a reserved server): your raft, and friends you invite
--   "online"  the shared ocean: everyone builds one giant ship together, and it's saved for everyone
local Mode = {}

function Mode.get()
	return workspace:GetAttribute("Mode") or "hub"
end

function Mode.online()
	return Mode.get() == "online"
end

return Mode
