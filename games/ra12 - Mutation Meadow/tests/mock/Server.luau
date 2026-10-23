--[[
Test helpers for booting the server.

  Server.boot(opts, setup?)     a new engine (Engine.new(opts)) with src/server/Main run; setup(engine) runs first
                                (stub modules, inject failures). Returns engine, DataService
  Server.join(engine, userId, settle?)   adds a player and runs the clock settle seconds (default 0.5)
  Server.patchConfig(engine, fn)         stubs Config with an unfrozen copy that fn edits (call from setup)
  Server.raw(engine, userId)    the stored profile for userId
  Server.deepCopy(t)
  Server.kicksFor(engine, userId)        the kick messages that player got
]]
local Engine = require("./Engine")

local Server = {}

function Server.deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = Server.deepCopy(v)
	end
	return out
end

function Server.patchConfig(engine, fn)
	local other = Engine.new()
	local copy = Server.deepCopy(other:require(other:module("Shared/Config")))
	fn(copy)
	engine:stub(engine:module("Shared/Config"), copy)
end

function Server.boot(opts, setup)
	local engine = Engine.new(opts)
	if setup then
		setup(engine)
	end
	local ok, err = engine:runScript(engine:module("Server/Main"))
	assert(ok, err)
	return engine, engine:require(engine:module("Server/Services/DataService"))
end

function Server.join(engine, userId, settle)
	local player = engine:addPlayer(userId)
	engine:advance(settle or 0.5)
	return player
end

function Server.raw(engine, userId)
	local data = engine.dataStores._raw("MM_Profiles_v1")
	return data and data["u_" .. userId]
end

function Server.kicksFor(engine, userId)
	local out = {}
	for _, k in engine.kicks do
		if k.userId == userId then
			table.insert(out, k.reason)
		end
	end
	return out
end

return Server
