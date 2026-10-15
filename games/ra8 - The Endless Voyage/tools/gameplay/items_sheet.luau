--[[
A contact sheet of every item's model (World/ItemModels), the way the UI's 3D icons show them (client/UI/Icons:
turned to run along +X and tilted up), laid out in a grid on a plain deck, for checking them by eye.

  tools/luaurun/target/release/luaurun tools/gameplay/items_sheet.luau <outDir>
  node tools/gameplay/render.js <outDir> <renderDir> --modules <node_modules> --textures <pbr dir>
]]
local Engine = loadModule("tests/mock/Engine.luau")
local Capture = loadModule("tools/gameplay/Capture.luau")
local V3, CF = Engine.Vector3, Engine.CFrame
local Vector2 = Engine.globals.Vector2
local Instance = Engine.Instance
local outDir = ARGS[1] or "thumbs"

local tree = Engine.mountProject(".")
Engine.workspace.CurrentCamera.ViewportSize = Vector2.new(1920, 1080)
local ItemModels = Engine.require(tree.shared.World.ItemModels)
local LightingPresets = Engine.require(tree.shared.World.LightingPresets)
local Items = Engine.require(tree.shared.Data.Items)
local Kit = Engine.require(tree.shared.World.Kit)
local C, M = Kit.C, Kit.M
local ws = Engine.workspace

local viewer = Engine.addPlayer("Viewer", 4242)
Engine.Players.LocalPlayer = viewer
Engine.localPlayer = viewer

local sheet = Instance.new("Folder", ws)
sheet.Name = "Sheet"
LightingPresets.apply("day", 11)

local COLS = 9
local STEP = 7
local keys = {}
for _, it in Items.list do
	table.insert(keys, it.key)
end
local rows = math.ceil(#keys / COLS)
Kit.box(sheet, "Deck", CF.new(0, -1, 0), V3.new(COLS * STEP + 6, 1, rows * STEP + 6), C.plank, M.WoodPlanks)
for i, key in keys do
	local item = Items.get(key)
	local col, row = (i - 1) % COLS, (i - 1) // COLS
	local x = (col - (COLS - 1) / 2) * STEP
	local z = (row - (rows - 1) / 2) * STEP
	local m = ItemModels.icon(item, sheet)
	m:PivotTo(CF.new(x, 1.6, z) * CF.Angles(0, 0, math.rad(32)) * CF.Angles(0, -math.pi / 2, 0))
	Kit.text(
		Kit.box(sheet, "Label", CF.new(x, 0.02, z + 2.6), V3.new(5, 0.04, 1), C.cream, M.SmoothPlastic),
		Engine.Enum.NormalId.Top,
		item.name,
		{ size = 18 }
	)
end

local function shot(name, camPos, camTarget, fov)
	local snap = Capture.snapshot(Engine, {
		pos = { camPos.X, camPos.Y, camPos.Z },
		target = { camTarget.X, camTarget.Y, camTarget.Z },
		fov = fov or 50,
	})
	snap.title = name
	snap.cinematic = false
	snap.hideGui = true
	snap.viewport = { w = 1920, h = 1080, dpr = 1 }
	snap.focus = { camTarget.X, camTarget.Y, camTarget.Z }
	Capture.save(Engine, snap, outDir, name)
	print("shot", name, #snap.parts, "parts")
	return name
end
local shots = {}
-- three rows at a time, close enough to see the detail
local perShot = 3
for first = 0, rows - 1, perShot do
	local last = math.min(rows - 1, first + perShot - 1)
	local zc = ((first + last) / 2 - (rows - 1) / 2) * STEP
	table.insert(
		shots,
		shot(string.format("items_%d", first / perShot + 1), V3.new(0, 24, zc + 16), V3.new(0, 0.5, zc - 1), 52)
	)
end
local http = Engine.game:GetService("HttpService")
writeFile(outDir .. "/index.json", http:JSONEncode(shots))
