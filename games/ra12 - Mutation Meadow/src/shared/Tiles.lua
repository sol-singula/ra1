--[[
Tile ids on a plot. The main plot is an 8 x 8 grid, row-major: id = tostring((r - 1) * 8 + c) for row r and column
c in 1..8, so ids never change as the plot grows. A level's plot is the w x d corner (Config.Upgrades.plotSize,
{ width, depth }): active when c <= w and r <= d. "extra1".."extra8" are the Extra Plot Row.

  Tiles.GRID                       8
  Tiles.id(r, c)                   the main tile id
  Tiles.rc(id)                     r, c for a main tile id (nil for extra tiles and junk)
  Tiles.isExtra(id)                the extra-row index 1..8, or nil
  Tiles.isActive(id, level, hasExtra)
  Tiles.activeTiles(level, hasExtra)   the active ids: main tiles in id order, then extra1..8
  Tiles.neighbors(id, size)        the main tiles in the size x size square centred on id (clipped to the grid)
  Tiles.neighbors3x3(id)
]]
local Config = require(script.Parent.Config)

local Tiles = {}

Tiles.GRID = 8
local EXTRA = Config.Catalog.passes.extraRow.tiles

function Tiles.id(r, c)
	return tostring((r - 1) * Tiles.GRID + c)
end

function Tiles.rc(id)
	if type(id) ~= "string" then
		return nil
	end
	local n = tonumber(id:match("^([1-9]%d?)$"))
	if not n or n > Tiles.GRID * Tiles.GRID then
		return nil
	end
	return (n - 1) // Tiles.GRID + 1, (n - 1) % Tiles.GRID + 1
end

function Tiles.isExtra(id)
	local n = type(id) == "string" and tonumber(id:match("^extra([1-9]%d*)$"))
	if n and n <= EXTRA then
		return n
	end
	return nil
end

function Tiles.isActive(id, level, hasExtra)
	if Tiles.isExtra(id) then
		return hasExtra == true
	end
	local r, c = Tiles.rc(id)
	local size = Config.Upgrades.plotSize[level]
	return r ~= nil and size ~= nil and c <= size[1] and r <= size[2]
end

function Tiles.activeTiles(level, hasExtra)
	local out = {}
	local size = Config.Upgrades.plotSize[level]
	if size then
		for r = 1, size[2] do
			for c = 1, size[1] do
				table.insert(out, Tiles.id(r, c))
			end
		end
		table.sort(out, function(a, b)
			return tonumber(a) < tonumber(b)
		end)
	end
	if hasExtra then
		for i = 1, EXTRA do
			table.insert(out, "extra" .. i)
		end
	end
	return out
end

function Tiles.neighbors(id, size)
	local r, c = Tiles.rc(id)
	if not r then
		return {}
	end
	local reach = (size - 1) // 2
	local out = {}
	for dr = -reach, reach do
		for dc = -reach, reach do
			local rr, cc = r + dr, c + dc
			if rr >= 1 and rr <= Tiles.GRID and cc >= 1 and cc <= Tiles.GRID then
				table.insert(out, Tiles.id(rr, cc))
			end
		end
	end
	return out
end

function Tiles.neighbors3x3(id)
	return Tiles.neighbors(id, 3)
end

return Tiles
