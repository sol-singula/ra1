local Assert = require("./mock/Assert")
local Engine = require("./mock/Engine")

local test, eq = Assert.test, Assert.eq

local engine = Engine.new()
local Tiles = engine:require(engine:module("Shared/Tiles"))

test("active tiles: 12, 20, 30, 48, 64 for levels 1-5, +8 with the extra row", function()
	local counts = {}
	for level = 1, 5 do
		counts[level] = #Tiles.activeTiles(level, false)
	end
	eq(counts, { 12, 20, 30, 48, 64 })
	eq(#Tiles.activeTiles(1, true), 20)
	eq(#Tiles.activeTiles(5, true), 72)
	eq(Tiles.activeTiles(1, false), { "1", "2", "3", "9", "10", "11", "17", "18", "19", "25", "26", "27" })
end)

test("ids: row-major, stable across levels; width x depth", function()
	eq({ Tiles.id(1, 1), Tiles.id(1, 8), Tiles.id(2, 1), Tiles.id(8, 8) }, { "1", "8", "9", "64" })
	eq({ Tiles.rc("10") }, { 2, 2 })
	eq(Tiles.rc("extra1"), nil)
	-- level 1 is 3 wide and 4 deep: column 4 is off, row 4 is on, row 5 is off
	eq(
		{ Tiles.isActive("3", 1), Tiles.isActive("4", 1), Tiles.isActive("25", 1), Tiles.isActive("33", 1) },
		{ true, false, true, false }
	)
	eq({ Tiles.isActive("4", 2), Tiles.isActive("33", 2) }, { true, true })
	eq(
		{ Tiles.isActive("extra1", 5, false), Tiles.isActive("extra8", 1, true), Tiles.isActive("extra9", 1, true) },
		{ false, true, false }
	)
	eq(Tiles.isExtra("extra3"), 3)
end)

test("neighbors3x3: clipped at the edges, main plot only", function()
	local function sorted(t)
		table.sort(t, function(a, b)
			return tonumber(a) < tonumber(b)
		end)
		return t
	end
	eq(sorted(Tiles.neighbors3x3("1")), { "1", "2", "9", "10" })
	eq(sorted(Tiles.neighbors3x3("10")), { "1", "2", "3", "9", "10", "11", "17", "18", "19" })
	eq(sorted(Tiles.neighbors3x3("64")), { "55", "56", "63", "64" })
	eq(Tiles.neighbors3x3("extra2"), {})
end)
