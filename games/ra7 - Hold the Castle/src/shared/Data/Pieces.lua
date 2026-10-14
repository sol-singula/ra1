-- Everything the dwarves can build (master plan §7). Pieces sit on the 4-stud build grid: `size` is in cells,
-- { along the piece's own X, along its Z } before it is turned (rot 1 swaps them). `need` is what the piece takes
-- (anyone can bring it: every hammer hit puts in what you carry), `work` the hammer hits it takes a regular
-- dwarf (Builders hit twice as hard, a Healer nearby adds a quarter). Everything breaks (`hp`); `solid` pieces stop
-- monsters; `points` count toward the castle's stage around its shrine (Camp, Town, Castle).
local Pieces = {}

Pieces.list = {
	{
		key = "stoneWall",
		name = "Stone Wall",
		icon = "🧱",
		line = "Strong and tall.",
		need = { stone = 6 },
		work = 6,
		hp = 700,
		size = { 2, 1 },
		height = 10,
		solid = true,
		points = 3,
		upgrade = { key = "thick", name = "Thicker Wall", need = { stone = 4 }, work = 4, hpMult = 1.8 },
	},
	{
		key = "woodWall",
		name = "Wood Wall",
		icon = "🪵",
		line = "Cheap. But it burns.",
		need = { wood = 4 },
		work = 4,
		hp = 360,
		size = { 2, 1 },
		height = 9,
		solid = true,
		burns = true,
		points = 2,
		upgrade = { key = "stone", name = "Stone Facing", need = { stone = 4 }, work = 4, hpMult = 1.8 },
	},
	{
		key = "gate",
		name = "Gate",
		icon = "🚪",
		line = "Dwarves walk through. Monsters don't.",
		need = { wood = 4, stone = 4 },
		work = 8,
		hp = 800,
		size = { 2, 1 },
		height = 12,
		solid = true,
		gate = true,
		points = 5,
		upgrade = { key = "iron", name = "Iron Gate", need = { stone = 2, gold = 2 }, work = 6, hpMult = 1.8 },
	},
	{
		key = "tower",
		name = "Archer Tower",
		icon = "🗼",
		line = "Archers shoot harder from the top.",
		need = { stone = 12, wood = 6 },
		work = 20,
		hp = 1400,
		size = { 2, 2 },
		height = 26,
		solid = true,
		tower = true,
		points = 10,
		upgrade = { key = "grand", name = "Grand Tower", need = { stone = 6, gold = 2 }, work = 8, hpMult = 1.6 },
	},
	{
		key = "quickWall",
		name = "Quick Wall",
		icon = "⚡",
		line = "Fast to build. Blocks a gap.",
		need = { wood = 2 },
		work = 1,
		hp = 160,
		size = { 2, 1 },
		height = 6,
		solid = true,
		burns = true,
		points = 1,
	},
	{
		key = "stairs",
		name = "Stairs",
		icon = "🪜",
		line = "Climb up onto your walls.",
		need = { wood = 2 },
		work = 2,
		hp = 200,
		size = { 1, 2 },
		height = 10,
		stairs = true,
		points = 1,
	},
	{
		key = "spikes",
		name = "Spike Trap",
		icon = "📌",
		line = "Hurts and slows monsters.",
		need = { wood = 3, stone = 2 },
		work = 3,
		hp = 220,
		size = { 1, 1 },
		height = 1.2,
		trap = "spikes",
		points = 2,
	},
	{
		key = "pit",
		name = "Pit Trap",
		icon = "🕳️",
		line = "Monsters get stuck in it.",
		need = { stone = 3 },
		work = 3,
		hp = 260,
		size = { 1, 1 },
		height = 0.6,
		trap = "pit",
		points = 2,
	},
	{
		key = "oilPot",
		name = "Oil Pot",
		icon = "🔥",
		line = "Pours fire on monsters near it.",
		need = { gold = 2, wood = 2 },
		work = 4,
		hp = 300,
		size = { 1, 1 },
		height = 7,
		solid = true,
		trap = "oil",
		points = 3,
	},
	{
		key = "fixStation",
		name = "Fix-it Station",
		icon = "🔧",
		line = "Mends the pieces around it.",
		need = { wood = 4, gold = 1 },
		work = 5,
		hp = 350,
		size = { 1, 1 },
		height = 6,
		solid = true,
		station = "fix",
		points = 3,
	},
	{
		key = "healStation",
		name = "Healing Station",
		icon = "💚",
		line = "Heals dwarves near it.",
		need = { gold = 3, wood = 2 },
		work = 5,
		hp = 350,
		size = { 1, 1 },
		height = 6,
		solid = true,
		station = "heal",
		points = 3,
	},
	{
		key = "forge",
		name = "Forge",
		icon = "⚒️",
		line = "Better armor and weapons.",
		need = { stone = 6, gold = 3 },
		work = 8,
		hp = 600,
		size = { 2, 1 },
		height = 8,
		solid = true,
		station = "forge",
		points = 5,
	},
	{
		key = "kitchen",
		name = "Kitchen",
		icon = "🍲",
		line = "Cook food that heals.",
		need = { wood = 6, stone = 2 },
		work = 6,
		hp = 450,
		size = { 2, 1 },
		height = 8,
		solid = true,
		station = "kitchen",
		points = 4,
	},
	{
		key = "potionTable",
		name = "Potion Table",
		icon = "🧪",
		line = "Brew a quick heal and a burst of speed.",
		need = { wood = 3, gold = 3 },
		work = 5,
		hp = 350,
		size = { 1, 1 },
		height = 5,
		solid = true,
		station = "potion",
		points = 3,
	},
	{
		key = "flag",
		name = "Banner",
		icon = "🚩",
		line = "Just for looks. Makes the castle grand.",
		need = { gold = 1 },
		work = 1,
		hp = 150,
		size = { 1, 1 },
		height = 14,
		points = 2,
	},
	{
		key = "shrineWard",
		name = "Shrine Ward",
		icon = "🔮",
		line = "The shrine drains slower. Two per shrine.",
		need = { gold = 6, stone = 6 },
		work = 10,
		hp = 1000,
		size = { 1, 1 },
		height = 9,
		solid = true,
		ward = true,
		points = 6,
	},
}

Pieces.byKey = {}
for i, p in Pieces.list do
	p.order = i
	Pieces.byKey[p.key] = p
end

-- The materials, in the order the HUD shows them.
Pieces.MATERIALS = {
	{ key = "stone", name = "Stone", icon = "🪨" },
	{ key = "wood", name = "Wood", icon = "🪵" },
	{ key = "gold", name = "Gold", icon = "🪙" },
}
Pieces.MATERIAL = {}
for _, m in Pieces.MATERIALS do
	Pieces.MATERIAL[m.key] = m
end

-- "6 🪨 · 2 🪵"
function Pieces.costText(need)
	local parts = {}
	for _, m in Pieces.MATERIALS do
		local n = need[m.key]
		if n and n > 0 then
			table.insert(parts, `{n} {m.icon}`)
		end
	end
	return table.concat(parts, " · ")
end

-- Cells a piece covers when turned (rot 0 or 1).
function Pieces.cells(piece, rot)
	local w, d = piece.size[1], piece.size[2]
	if rot == 1 then
		return d, w
	end
	return w, d
end

return Pieces
