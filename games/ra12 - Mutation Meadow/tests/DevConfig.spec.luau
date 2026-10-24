local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

local function devConfig(opts, adminIds)
	local engine = Engine.new(opts)
	if adminIds then
		-- a test copy of Config with different AdminUserIds
		local other = Engine.new()
		local real = other:require(other:module("Shared/Config"))
		local copy = table.clone(real)
		copy.AdminUserIds = adminIds
		engine:stub(engine:module("Shared/Config"), copy)
	end
	return engine:require(engine:module("Server/DevConfig")), engine
end

test("not allowed outside Studio for an unknown UserId", function()
	local DevConfig, engine = devConfig({ studio = false })
	eq(DevConfig.isStudio(), false)
	eq(DevConfig.isAllowed(engine:addPlayer(123)), false)
end)

test("allowed in Studio", function()
	local DevConfig, engine = devConfig({ studio = true })
	eq(DevConfig.isStudio(), true)
	eq(DevConfig.isAllowed(engine:addPlayer(123)), true)
end)

test("an id in AdminUserIds is not allowed outside Studio: dev commands are Studio only", function()
	local DevConfig, engine = devConfig({ studio = false }, { 0, 456 })
	eq(DevConfig.isAllowed(engine:addPlayer(456)), false)
	eq(DevConfig.isAllowed(engine:addPlayer(123)), false)
	local inStudio, studioEngine = devConfig({ studio = true }, { 0, 456 })
	eq(inStudio.isAllowed(studioEngine:addPlayer(456)), true)
end)
