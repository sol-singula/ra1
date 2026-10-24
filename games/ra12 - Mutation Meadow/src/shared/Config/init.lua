--[[
Every tuning number in the game, in one frozen table. Each child module holds one top-level table; this module
requires them all, deep-freezes the result and returns it, so `Config.Seeds.carrot.buy` reads the same on the
server and the client and can never be changed at runtime.
]]
local Config = {}

for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") then
		Config[child.Name] = require(child)
	end
end

Config.AdminUserIds = { 11787294097 } -- Mason; DevCommands are Studio only, so this grants nothing live

local function deepFreeze(t)
	for _, v in t do
		if type(v) == "table" and not table.isfrozen(v) then
			deepFreeze(v)
		end
	end
	if not table.isfrozen(t) then
		table.freeze(t)
	end
	return t
end

return deepFreeze(Config)
