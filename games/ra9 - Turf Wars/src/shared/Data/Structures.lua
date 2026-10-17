--[[
What a team can build (master plan §2B, §7): modular pieces that snap to the 4-stud grid. How they look is
StructureModel's: every piece in one shade of the team's colour, the Reinforced Wall (the armour) darker.

  w, d     footprint in cells (w along X, d along Z, before rotation)
  h        height in studs
  cost     budget points
  hp       durability (arrows chip it; TNT wrecks it)
  blocks   true: a tall piece that blocks a lane (the server keeps one open cell in every row across the field)
  walkTop  true: you can stand on it (the tower's platform, the bridge's deck)
]]
local Structures = {}

Structures.list = {
	{ key = "barricade", name = "Low Barricade", icon = "▬", w = 2, d = 1, h = 4, cost = 5, hp = 60 },
	{ key = "wall", name = "Wall", icon = "▮", w = 2, d = 1, h = 10, cost = 10, hp = 140, blocks = true },
	{
		key = "reinforced",
		name = "Reinforced Wall",
		icon = "■",
		w = 2,
		d = 1,
		h = 10,
		cost = 22,
		hp = 360,
		blocks = true,
	},
	{
		key = "tower",
		name = "Short Tower",
		icon = "▲",
		w = 2,
		d = 2,
		h = 12,
		cost = 30,
		hp = 280,
		blocks = true,
		walkTop = true,
	},
	{ key = "bridge", name = "Bridge", icon = "═", w = 1, d = 3, h = 6, cost = 14, hp = 120, walkTop = true },
	{ key = "cover", name = "Cover", icon = "◆", w = 1, d = 1, h = 6, cost = 5, hp = 80 },
	{ key = "banner", name = "Team Banner", icon = "⚑", w = 1, d = 1, h = 12, cost = 2, hp = 30 },
}

local byKey = {}
for i, s in Structures.list do
	s.order = i
	byKey[s.key] = s
end

function Structures.get(key)
	return byKey[key]
end

-- The footprint in cells after rotation (rot 0: w along X; rot 1: turned 90°).
function Structures.footprint(def, rot)
	if rot == 1 then
		return def.d, def.w
	end
	return def.w, def.d
end

return Structures
