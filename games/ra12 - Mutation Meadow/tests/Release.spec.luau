--[[
The release switch (§11.5). Until release, every Catalog and badge id is 0 (TODO: create on Mason's account).
AdminUserIds already holds Mason's UserId. At release, run with RELEASE=1: then no id may be 0 and AdminUserIds must
hold a real UserId.

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
	test("before release: the 29 store items and 10 badges are all still 0 (docs/ids-todo.md)", function()
		local list, Config = ids()
		eq(#list, 29 + 10)
		for _, entry in list do
			eq(entry.id, 0, entry.where)
		end
		eq(Config.AdminUserIds, { 11787294097 })
	end)
end
