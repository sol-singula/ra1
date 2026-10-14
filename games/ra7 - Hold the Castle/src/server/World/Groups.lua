-- Collision groups: who bumps into what.
--   Dwarves / Monsters   players' characters, by team (everyone else, like the hangout, is Default)
--   MonsterWall          the walls of magic between shrines and around the castle's safe zones: monsters only
--   DwarfWall            around the monster spawn: dwarves only (no spawn camping)
--   Gate                 a gate's blocker: monsters bump into it, dwarves walk straight through
local PhysicsService = game:GetService("PhysicsService")

local Groups = {}

local ready = false

function Groups.setup()
	if ready then
		return
	end
	ready = true
	pcall(function()
		for _, name in { "Dwarves", "Monsters", "MonsterWall", "DwarfWall", "Gate" } do
			PhysicsService:RegisterCollisionGroup(name)
		end
		local function set(a, b, on)
			PhysicsService:CollisionGroupSetCollidable(a, b, on)
		end
		set("MonsterWall", "Default", false)
		set("MonsterWall", "Dwarves", false)
		set("MonsterWall", "MonsterWall", false)
		set("MonsterWall", "DwarfWall", false)
		set("MonsterWall", "Gate", false)
		set("DwarfWall", "Default", false)
		set("DwarfWall", "Monsters", false)
		set("DwarfWall", "DwarfWall", false)
		set("DwarfWall", "Gate", false)
		set("Gate", "Dwarves", false)
		set("Dwarves", "Monsters", true)
	end)
end

-- Put a part, or every part in a model, into a group.
function Groups.set(target, group)
	if not target then
		return
	end
	if target:IsA("BasePart") then
		target.CollisionGroup = group
		return
	end
	for _, d in target:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
end

return Groups
