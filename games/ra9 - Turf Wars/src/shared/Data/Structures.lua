--[[
What a team can build (master plan §2B, §7): modular castle pieces that snap to the 4-stud grid. How they look is
StructureModel's: stone, wood and iron with the team's colour on the trim, the merlons, the roofs and the banners.
The keys are the old ones (other code and the tutorial name pieces by key); only the names and the looks changed.

  w, d     footprint in cells (w along X, d along Z, before rotation)
  h        height in studs
  cost     budget points
  hp       durability (arrows chip it; TNT wrecks it)
  blocks   true: a tall piece that blocks a lane (the server keeps one open cell in every row across the field)
  walkTop  true: you can stand on it (the watchtower's platform, the rampart's deck)
  rally    true: your team comes back to life beside it while it stands (BuildService:RallySpawn); one per team
  role     what it's for, in a few words (the build tray's hint when you pick it)
]]
local Structures = {}

Structures.list = {
	{
		key = "barricade",
		name = "Battlement",
		icon = "▬",
		w = 2,
		d = 1,
		h = 4,
		cost = 5,
		hp = 60,
		role = "Low stone wall: duck behind it",
	},
	{
		key = "wall",
		name = "Castle Wall",
		icon = "▮",
		w = 2,
		d = 1,
		h = 10,
		cost = 10,
		hp = 140,
		blocks = true,
		role = "Tall stone wall: blocks arrows and the way",
	},
	{
		key = "reinforced",
		name = "Keep Wall",
		icon = "■",
		w = 2,
		d = 1,
		h = 10,
		cost = 22,
		hp = 360,
		blocks = true,
		role = "The toughest wall: shrugs off arrows",
	},
	{
		key = "tower",
		name = "Watchtower",
		icon = "▲",
		w = 2,
		d = 2,
		h = 12,
		cost = 30,
		hp = 280,
		blocks = true,
		walkTop = true,
		role = "Climb the ladder, shoot from the top",
	},
	{
		key = "bridge",
		name = "Rampart",
		icon = "═",
		w = 1,
		d = 3,
		h = 6,
		cost = 14,
		hp = 120,
		walkTop = true,
		role = "Climb up, shoot over the walls",
	},
	{
		key = "cover",
		name = "Shield Wall",
		icon = "◆",
		w = 1,
		d = 1,
		h = 6,
		cost = 5,
		hp = 80,
		role = "A big shield to hide behind",
	},
	{
		key = "banner",
		name = "Rally Banner",
		icon = "⚑",
		w = 1,
		d = 1,
		h = 12,
		cost = 2,
		hp = 30,
		rally = true,
		role = "Your team respawns here (one per team)",
	},
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
