-- Booting a server with a loaded player and counting handlers on every action (the Net specs)
local Server = require("./Server")

local NetHelp = {}

-- engine, NetService, NetSchema, player (loaded), calls: { { remote, action, body } }
function NetHelp.setup(opts, setup)
	local engine = Server.boot(opts, setup)
	local NetService = engine:require(engine:module("Server/Services/NetService"))
	local NetSchema = engine:require(engine:module("Shared/NetSchema"))
	local calls = {}
	for remote, actions in NetSchema.ACTIONS do
		for action in actions do
			NetService.on(remote, action, nil, function(_, body)
				table.insert(calls, { remote = remote, action = action, body = body })
				return true
			end)
		end
	end
	local player = Server.join(engine, 10)
	return engine, NetService, NetSchema, player, calls
end

-- the [Net] drop warnings printed so far, counted per reason
function NetHelp.warnings(engine)
	local out = {}
	for _, line in engine.output do
		local reason = line:match("^%[warn%] %[Net%] dropped (%S+)")
		if reason then
			out[reason] = (out[reason] or 0) + 1
		end
	end
	return out
end

return NetHelp
