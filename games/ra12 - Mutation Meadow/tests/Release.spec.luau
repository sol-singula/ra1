--[[
The release switch (§11.5). Every Catalog id and five badge ids hold their Creator Hub ids; master_gardener,
week_of_sprouts, full_meadow, moonstruck and sunflower_friend are still 0 (TODO: create on Mason's account).
AdminUserIds holds Mason's UserId. At release, run with RELEASE=1: then no id may be 0 and AdminUserIds must hold a
real UserId.

  RELEASE=1 tools/run_tests.sh Release
]]
local process = require("@lune/process")

local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

local RELEASE = process.env.RELEASE == "1"

local function ids()
	local e = Engine.new()
	local Config = e:require(e:module("Shared/Config"))
	local out = {}
	for _, groupName in { "passes", "products", "cosmetics", "gifts" } do
		for key, item in Config.Catalog[groupName] do
			table.insert(out, { where = `Catalog.{groupName}.{key}`, id = item.id })
		end
	end
	for key, badge in Config.Badges do
		table.insert(out, { where = `Badges.{key}`, id = badge.id })
	end
	return out, Config
end

if RELEASE then
	test("release: no id is 0, and AdminUserIds holds Mason's UserId", function()
		local list, Config = ids()
		eq(#list, 29 + 10)
		for _, entry in list do
			Assert.truthy(entry.id ~= 0, `{entry.where} is still 0`)
		end
		Assert.truthy(#Config.AdminUserIds > 0, "AdminUserIds")
		for _, id in Config.AdminUserIds do
			Assert.truthy(id > 0, "a real UserId in AdminUserIds")
		end
	end)
else
	local PENDING = {
		["Badges.master_gardener"] = true,
		["Badges.week_of_sprouts"] = true,
		["Badges.full_meadow"] = true,
		["Badges.moonstruck"] = true,
		["Badges.sunflower_friend"] = true,
	}
	test(
		"before release: the 29 store items and 5 badges have real ids; 5 badges are still 0 (docs/ids-todo.md)",
		function()
			local list, Config = ids()
			eq(#list, 29 + 10)
			local seen = {}
			for _, entry in list do
				if PENDING[entry.where] then
					eq(entry.id, 0, entry.where)
				else
					Assert.truthy(entry.id > 0, `{entry.where} has its Creator Hub id`)
					Assert.truthy(not seen[entry.id], `{entry.where}: {entry.id} is used twice`)
					seen[entry.id] = true
				end
			end
			eq(Config.AdminUserIds, { 11787294097 })
		end
	)
end
