--[[
The client's copy of its own profile, kept in step by StateController (Snapshot, then State deltas).

  ClientState.profile            the public profile (nil until the first Snapshot)
  ClientState.extra              the rest of the Snapshot (weather, blockParty, ...)
  ClientState.load(snapshot)     replaces it
  ClientState.apply(changes)     { { path = { "tiles", "3" }, value = ... } }; a missing value deletes the key
  ClientState.get(...)           ClientState.get("seeds", "carrot") -> the value or nil
  ClientState.Changed(rootKeys)  fires after load (rootKeys = nil: everything) and after apply ({ [key] = true })
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)

local ClientState = {
	profile = nil,
	Changed = Signal.new(),
}

function ClientState.load(snapshot)
	ClientState.profile = snapshot and snapshot.profile or nil
	ClientState.extra = snapshot
	ClientState.Changed:Fire(nil)
end

function ClientState.apply(changes)
	local profile = ClientState.profile
	if not profile then
		return
	end
	local roots = {}
	for _, change in changes do
		local path = change.path
		local t = profile
		for i = 1, #path - 1 do
			local key = path[i]
			if type(t[key]) ~= "table" then
				t[key] = {}
			end
			t = t[key]
		end
		t[path[#path]] = change.value
		roots[path[1]] = true
	end
	ClientState.Changed:Fire(roots)
end

function ClientState.get(...)
	local t = ClientState.profile
	for _, key in { ... } do
		if type(t) ~= "table" then
			return nil
		end
		t = t[key]
	end
	return t
end

return ClientState
