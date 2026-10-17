--[[
A duel's arena (DuelService): one of the real maps (Data/Maps) at the small size, built far out past the plaza in its
own slot along Z (Constants.DUEL_ORIGIN_Z, DUEL_GAP apart), with no skyline and a tight ground (ArenaBuilder's
compact build), then moved whole to its slot: every part, every solid and collide box, both decks' pads. Red at -X,
blue at +X like every arena, the turf painted for a line in the middle (nothing ever moves it: a duel has no turf).

  DuelArena.origin(slot)              the slot's middle on the floor (y = 0, like every arena)
  DuelArena.build(def, parent, slot)  -> arena (ArenaBuilder.build's, plus origin and slot; its folder "Duel<slot>")
  DuelArena.spawn(arena, side, i)     the i-th pad of that side's deck, facing the field (a CFrame)
  DuelArena.inside(arena, pos)        inside its walls
  DuelArena.onDeck(arena, side, pos)  on that side's deck (safe until you shoot: CombatService)
  DuelArena.destroy(arena)
]]
local Constants = require(script.Parent.Parent.Constants)
local ArenaBuilder = require(script.Parent.ArenaBuilder)

local DuelArena = {}

function DuelArena.origin(slot)
	return Vector3.new(0, 0, Constants.DUEL_ORIGIN_Z - (math.max(1, slot) - 1) * Constants.DUEL_GAP)
end

function DuelArena.build(def, parent, slot)
	local arena = ArenaBuilder.build(def, parent, "small", { compact = true })
	local origin = DuelArena.origin(slot)
	ArenaBuilder.paint(arena, 0) -- (red west, blue east, a white line between: painted once, then moved with the rest)
	for _, d in arena.folder:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + origin
		end
	end
	for _, list in { arena.solids, arena.collide } do
		for _, s in list do
			s.min += origin
			s.max += origin
		end
	end
	for _, side in Constants.TEAMS do
		for i, cf in arena.spawns[side] do
			arena.spawns[side][i] = cf + origin
		end
	end
	arena.origin = origin
	arena.slot = slot
	arena.folder.Name = "Duel" .. slot
	arena.folder:SetAttribute("Slot", slot)
	return arena
end

function DuelArena.spawn(arena, side, i)
	local list = arena.spawns[side] or {}
	if #list == 0 then
		return CFrame.new(arena.origin + Vector3.new(0, 5, 0))
	end
	return list[(i - 1) % #list + 1]
end

function DuelArena.inside(arena, pos)
	local mn, mx = ArenaBuilder.bounds(arena)
	local p = pos - arena.origin
	return p.X >= mn.X and p.X <= mx.X and p.Y >= mn.Y and p.Y <= mx.Y and p.Z >= mn.Z and p.Z <= mx.Z
end

function DuelArena.onDeck(arena, side, pos)
	local p = pos - arena.origin
	return math.abs(p.Z) <= arena.width / 2 and ArenaBuilder.inRoom(arena, side, p)
end

function DuelArena.destroy(arena)
	if arena.folder then
		arena.folder:Destroy()
	end
end

return DuelArena
