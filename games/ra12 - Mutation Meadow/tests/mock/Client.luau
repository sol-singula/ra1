--[[
A booted client: the local player owns Plot1 of a placeholder street, every remote exists, and ClientState holds a
fresh profile.

  local c = Client.boot(profileEdits?)   c.engine, c.state (ClientState), c.controllers, c.plot, c.gui(name)
  Client.sent(c, remote)                 the (action, payload) pairs the client fired on a remote
  Client.press(button)                   fires a TextButton's Activated
]]
local Engine = require("./Engine")
local Server = require("./Server")

local Client = {}

function Client.boot(edit)
	local server = Server.boot()
	local profile = Server.deepCopy(server:require(server:module("Server/Services/DataService")).TEMPLATE)
	if edit then
		edit(profile)
	end
	local engine = Engine.new({ client = true, localPlayer = 10 })
	local StreetBuilder = engine:require(engine:module("Server/World/StreetBuilder"))
	local street = StreetBuilder.build(engine.workspace)
	local plot = street.Plots.Plot1
	plot:SetAttribute("OwnerId", 10)
	local NetSchema = engine:require(engine:module("Shared/NetSchema"))
	local folder = engine.Instance.new("Folder")
	folder.Name = "Remotes"
	for _, list in { NetSchema.CLIENT_EVENTS, NetSchema.SERVER_EVENTS } do
		for _, name in list do
			engine.Instance.new("RemoteEvent", folder).Name = name
		end
	end
	engine.Instance.new("RemoteFunction", folder).Name = "Snapshot"
	folder.Parent = engine.game.ReplicatedStorage
	local ok, err = engine:runScript(engine:module("Client/Main"))
	assert(ok, err)
	engine:advance(0.1)
	local state = engine:require(engine:module("Client/ClientState"))
	state.load({ seq = 0, profile = profile })
	local controllers = {}
	for _, name in engine:require(engine:module("Client/ControllerLoader")).ORDER do
		controllers[name] = engine:require(engine:module("Client/Controllers/" .. name))
	end
	local c = { engine = engine, state = state, controllers = controllers, plot = plot, remotes = folder }
	function c.gui(name)
		return engine.game.Players.LocalPlayer.PlayerGui:FindFirstChild(name)
	end
	return c
end

function Client.sent(c, remote)
	local out = {}
	for _, e in c.engine.remoteLog do
		if e.remote == remote and e.dir == "toServer" then
			table.insert(out, { e.args[1], e.args[2] })
		end
	end
	return out
end

function Client.press(button)
	assert(button and button.ClassName == "TextButton", "not a button")
	button.Activated:Fire()
end

-- a descendant by name, anywhere under root
function Client.find(root, name)
	for _, d in root:GetDescendants() do
		if d.Name == name then
			return d
		end
	end
	return nil
end

return Client
