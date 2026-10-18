-- Farm levels: the XP each level needs (harvests, sales and the guide pay XP; master plan §3). Level 2 comes after
-- about ten strawberries, so the first unlock lands in the first two minutes.
local Levels = {}

Levels.MAX = 60

-- XP to go from level n to n + 1
function Levels.need(n)
	return math.floor(10 * n ^ 1.55 + 0.5)
end

-- The level an XP total reaches, and how far into the next: level, into, need
function Levels.of(xp)
	local level = 1
	while level < Levels.MAX and xp >= Levels.need(level) do
		xp -= Levels.need(level)
		level += 1
	end
	return level, xp, Levels.need(level)
end

return Levels
