--[[
A stand-in for the admin tools (src/server/Services/AdminService.lua) for tests/LogSmoke.spec.luau while the real
one isn't there: just its Used signal (admin, action, detail), which the game log and analytics listen to.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)

return {
	Name = "AdminService",
	Dependencies = {},
	Used = Signal.new("AdminService.Used"),
}
