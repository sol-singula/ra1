--[[
Server time, shared by the server and the client.

  Clock.now()          workspace:GetServerTimeNow(), plus the Studio-only test offset (the workspace attribute
                       ClockOffset, set by the DevCommands "clock +<sec>" and "week next"; nil in live games)
  Clock.utcDay(t)      the UTC day number of t (days since the epoch)
  Clock.hourStart(t)   the start of t's UTC hour
]]
local Clock = {}

function Clock.now()
	return workspace:GetServerTimeNow() + (workspace:GetAttribute("ClockOffset") or 0)
end

function Clock.utcDay(t)
	return t // 86400
end

function Clock.hourStart(t)
	return t // 3600 * 3600
end

return Clock
