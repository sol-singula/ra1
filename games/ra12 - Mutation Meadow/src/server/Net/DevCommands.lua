--[[
The DevCommand registry. NetService only lets DevCommand:run through for Guards.dev players (Studio, or a UserId in
Config.AdminUserIds); everyone else is dropped as dev_gate before this runs.

  DevCommands.register(cmd, fn)        fn(player, args) -> ok, code?
  DevCommands.run(player, payload)     the DevCommand:run handler: { cmd, args }
  DevCommands.list()                   the registered names
]]
local DevCommands = {}

local registry = {}

function DevCommands.register(cmd, fn)
	registry[cmd] = fn
end

function DevCommands.run(player, payload)
	local fn = registry[payload.cmd]
	if not fn then
		return false, "unknown_cmd"
	end
	return fn(player, payload.args)
end

function DevCommands.list()
	local out = {}
	for cmd in registry do
		table.insert(out, cmd)
	end
	table.sort(out)
	return out
end

return DevCommands
