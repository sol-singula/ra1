--[[
The layout holds together: no two zones of a farm overlap, every zone is inside the fence, every farm's front
faces the avenue (its front is nearer the road than its back), the pads sit in the build yard, and nothing of the
town or the city stands inside a farm.

  luaurun tests/LayoutSmoke.spec.luau
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Vector3 = Engine.globals.Vector3

local passed, failed = 0, 0
local function check(name, cond, detail)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. (detail ~= nil and (": " .. tostring(detail)) or ""))
	end
end

local tree = Engine.mountProject(".")
local Layout = Engine.require(tree.shared.World.Layout)

-- The zones ------------------------------------------------------------------------------------------------------
local names = {}
for name in Layout.ZONES do
	table.insert(names, name)
end
table.sort(names)
local overlaps = {}
for a = 1, #names do
	for b = a + 1, #names do
		local A, B = Layout.ZONES[names[a]], Layout.ZONES[names[b]]
		local ox = math.abs(A.cx - B.cx) < (A.w + B.w) / 2 - 0.01
		local oz = math.abs(A.cz - B.cz) < (A.d + B.d) / 2 - 0.01
		if ox and oz then
			table.insert(overlaps, names[a] .. "/" .. names[b])
		end
	end
end
check("no two zones overlap", #overlaps == 0, table.concat(overlaps, ", "))
local outside = {}
for _, name in names do
	local z = Layout.ZONES[name]
	if math.abs(z.cx) + z.w / 2 > Layout.FENCE.x + 0.01 or math.abs(z.cz) + z.d / 2 > Layout.FENCE.z + 1.6 then
		table.insert(outside, name)
	end
end
check("every zone is inside the fence", #outside == 0, table.concat(outside, ", "))

-- Every field's tiles are inside its zone
local loose = {}
for _, key in Layout.FIELD_LIST do
	local z = Layout.ZONES[key]
	for n = 1, Layout.FIELDS[key].tiles do
		local x, zz = Layout.tilePos(key, n)
		if math.abs(x - z.cx) > z.w / 2 or math.abs(zz - z.cz) > z.d / 2 then
			table.insert(loose, key .. "#" .. n)
		end
	end
end
check("every tile is inside its field", #loose == 0, table.concat(loose, ", "))

-- The pads are in the build yard, apart
local yard = Layout.ZONES.yard
local padsOk = true
for k, pad in Layout.PADS do
	if
		math.abs(pad.x - yard.cx) + Layout.PAD / 2 > yard.w / 2
		or math.abs(pad.z - yard.cz) + Layout.PAD / 2 > yard.d / 2
	then
		padsOk = false
	end
	for j = k + 1, #Layout.PADS do
		local q = Layout.PADS[j]
		if math.abs(pad.x - q.x) < Layout.PAD + 1 and math.abs(pad.z - q.z) < Layout.PAD + 1 then
			padsOk = false
		end
	end
end
check("the eight pads sit apart in the build yard", padsOk and #Layout.PADS == 8)

-- Every farm faces the avenue (z = 0): its front (local -z) is nearer the road than its back
local facing = {}
for i = 1, 12 do
	local front = Layout.toWorld(i, 0, -Layout.DEPTH / 2, 0)
	local back = Layout.toWorld(i, 0, Layout.DEPTH / 2, 0)
	if math.abs(front.Z) >= math.abs(back.Z) then
		table.insert(facing, i)
	end
	-- and stays off the avenue and the city
	local t = Layout.territory(i)
	if math.abs(t.cz) - Layout.DEPTH / 2 < Layout.AVENUE / 2 - 0.01 then
		table.insert(facing, i .. " on the avenue")
	end
	if math.abs(t.cx) - Layout.WIDTH / 2 < Layout.CITY.half - 0.01 then
		table.insert(facing, i .. " in the city")
	end
end
check("every farm's front faces the avenue", #facing == 0, table.concat(facing, ", "))
check(
	"territoryAt finds a farm's middle and nothing on the avenue",
	Layout.territoryAt(Layout.toWorld(3, 0, 0, 0)) == 3 and Layout.territoryAt(Vector3.new(400, 0, 0)) == nil
)

-- The built world: nothing of the town inside a farm ----------------------------------------------------------------
Engine.runScript(tree.server.Main)
Engine.advance(0.5)
local town = Engine.workspace:FindFirstChild("Town")
check("the town is built", town ~= nil)
local intruders = {}
local parts = 0
for _, d in town and town:GetDescendants() or {} do
	if d:IsA("BasePart") and d.Size.X < 300 and d.Size.Z < 300 then
		parts += 1
		local i = Layout.territoryAt(d.Position)
		if i then
			table.insert(intruders, d.Name .. "@" .. math.floor(d.Position.X) .. "," .. math.floor(d.Position.Z))
		end
	end
end
check("the city has detail (many parts)", parts > 1500, parts)
check(
	"no town part stands inside a farm",
	#intruders == 0,
	#intruders .. " " .. table.concat(intruders, " ", 1, math.min(6, #intruders))
)
-- the city's fake buildings and the courtyard's features
local buildings, boards, store, market = 0, 0, false, false
for _, d in town and town:GetDescendants() or {} do
	if d.Name == "Leaderboard" then
		boards += 1
	elseif d.Name == "Store" and d:IsA("Model") then
		store = true
	elseif d.Name == "MarketHall" then
		market = true
	elseif d:IsA("Model") and d.Name == "Building" then
		buildings += 1
	end
end
check("three leaderboards face the courtyard", boards == 3, boards)
check("the store and the market hall stand on the square", store and market)
check("a city of fake buildings round it", buildings >= 30, buildings)

if #Engine.errors > 0 then
	for _, e in Engine.errors do
		print("ERROR " .. tostring(e))
	end
	failed += #Engine.errors
end
print(`LayoutSmoke: {passed} passed, {failed} failed`)
if failed > 0 then
	error(`{failed} failed`)
end
