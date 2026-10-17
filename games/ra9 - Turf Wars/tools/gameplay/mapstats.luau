--[[
Every map at every size: its part count (all, and the ones that collide), solid boxes, and the narrowest row of
open cells (the lane rule), for tuning a map's detail against the budget.

  luaurun tools/gameplay/mapstats.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local tree = Engine.mountProject(".")
local Maps = Engine.require(tree.shared.Data.Maps)
local ArenaBuilder = Engine.require(tree.shared.World.ArenaBuilder)
local Formulas = Engine.require(tree.shared.Formulas)

for _, def in Maps.list do
	for _, tier in ArenaBuilder.TIERS do
		local holder = Engine.Instance.new("Folder")
		local a = ArenaBuilder.build(def, holder, tier)
		local parts, collide = 0, 0
		for _, x in a.folder:GetDescendants() do
			if x:IsA("BasePart") then
				parts += 1
				if x.CanCollide then
					collide += 1
				end
			end
		end
		local edge = a.half - a.spawnDepth
		local _, z0 = Formulas.cellOf(0, -a.width / 2 + 0.01)
		local _, z1 = Formulas.cellOf(0, a.width / 2 - 0.01)
		local worst, at = math.huge, nil
		for cx = Formulas.cellOf(-edge + 0.01, 0), Formulas.cellOf(edge - 0.01, 0) do
			local free = 0
			for cz = z0, z1 do
				if not (a.blocked[cx] and a.blocked[cx][cz]) then
					free += 1
				end
			end
			if free < worst then
				worst, at = free, cx
			end
		end
		print(
			string.format(
				"%-7s %-6s %3dx%3d  parts %4d  collide %4d  solids %4d  narrowest row %d free (cell %s)",
				def.key,
				tier,
				a.length,
				a.width,
				parts,
				collide,
				#a.solids,
				worst,
				tostring(at)
			)
		)
		holder:Destroy()
	end
end
