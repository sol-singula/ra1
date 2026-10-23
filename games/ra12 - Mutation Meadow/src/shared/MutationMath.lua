--[[
Mutation keys and values (pure; server and client agree on prices).

  MutationMath.key(muts)            "wet" | "golden" | "wetgolden" | nil
  MutationMath.mult(muts)           Wet 2, Golden 20, both Config.Mutations.stackMult (40); none 1
  MutationMath.value(seed, muts)    sell x mult (before 2x Sell Cash)
  MutationMath.label(muts)          "Wet" | "Golden" | "Wet + Golden"
]]
local Config = require(script.Parent.Config)

local MutationMath = {}

function MutationMath.key(muts)
	if not muts then
		return nil
	end
	if muts.wet and muts.golden then
		return "wetgolden"
	elseif muts.wet then
		return "wet"
	elseif muts.golden then
		return "golden"
	end
	return nil
end

function MutationMath.mult(muts)
	local key = MutationMath.key(muts)
	if key == "wetgolden" then
		return Config.Mutations.stackMult
	elseif key then
		return Config.Mutations[key].mult
	end
	return 1
end

function MutationMath.value(seed, muts)
	return Config.Seeds[seed].sell * MutationMath.mult(muts)
end

local LABELS = { wet = "Wet", golden = "Golden", wetgolden = "Wet + Golden" }

function MutationMath.label(muts)
	local key = if type(muts) == "string" then muts else MutationMath.key(muts)
	return key and LABELS[key] or ""
end

return MutationMath
