--[[
Build mode (master plan §7: a ghost shape shows where it goes, tap to place it, it snaps to the grid; easy on a
phone: big buttons, clear ghosts). Pick a piece from the bar; a ghost follows the grid in front of you (or your
mouse), green where it can go and red where it can't; ROTATE turns it, PLACE puts the blueprint down for everyone
to build. Next to a finished piece that can be upgraded, an UPGRADE button appears. Next to a forge, kitchen or
potion table, a card with what it makes.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local MapLayout = require(ReplicatedStorage.Shared.World.MapLayout)
local Net = require(ReplicatedStorage.Shared.Net)
local PieceModels = require(ReplicatedStorage.Shared.World.PieceModels)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local BuildController = { Name = "BuildController", Order = 25 }

local player = Players.LocalPlayer
local C = Theme.Color
local new = Theme.new
local gui
local refs = {}
local active = false
local selected = nil -- piece key
local rot = 0
local ghost, ghostKey, ghostRot, ghostOk
local spot -- { i, j, ok, reason }
local GREEN = Color3.fromRGB(90, 230, 120)
local RED = Color3.fromRGB(255, 80, 80)

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- The cells every piece in the world covers (from the models' attributes).
local function occupied()
	local cells = {}
	local castle = workspace:FindFirstChild("Castle")
	for _, m in castle and castle:GetChildren() or {} do
		local key = m:GetAttribute("Key")
		local def = key and Pieces.byKey[key]
		local i, j, r = m:GetAttribute("I"), m:GetAttribute("J"), m:GetAttribute("Rot")
		if def and i then
			local w, d = Pieces.cells(def, r)
			for a = 0, w - 1 do
				for b = 0, d - 1 do
					cells[(i + a) .. "," .. (j + b)] = m
				end
			end
		end
	end
	return cells
end

-- The same rules the server checks (BuildService:Check), so the ghost is honest.
function BuildController.check(key, i, j, r)
	local def = Pieces.byKey[key]
	if not def then
		return false, "Pick a piece."
	end
	local w, d = Pieces.cells(def, r)
	local cells = occupied()
	local shrine
	for a = 0, w - 1 do
		for b = 0, d - 1 do
			local x, z = MapLayout.cellCenter(i + a, j + b)
			local zone = MapLayout.buildZoneAt(x, z)
			if not zone or (shrine and zone ~= shrine) then
				return false, "Only around a shrine"
			end
			shrine = zone
			if cells[(i + a) .. "," .. (j + b)] then
				return false, "Something's there"
			end
		end
	end
	local m = Store.get("match")
	if m and shrine <= (m.fallen or 0) then
		return false, "That shrine fell"
	end
	local s = MapLayout.shrines[shrine]
	local cx, cz = (i + w / 2) * MapLayout.CELL, (j + d / 2) * MapLayout.CELL
	local flat = Vector2.new(cx - s.pos.X, cz - s.pos.Z).Magnitude
	if def.ward then
		if flat > Constants.WARD_RANGE then
			return false, "Right by the shrine"
		end
		if flat < 6 then
			return false, "Too close"
		end
	elseif flat - math.max(w, d) * MapLayout.CELL / 2 < Constants.SHRINE_KEEP_CLEAR then
		return false, "Keep the shrine clear"
	end
	for _, jb in MapLayout.jobBoards do
		if math.abs(jb.pos.X - cx) < w * 2 + 4 and math.abs(jb.pos.Z - cz) < d * 2 + 4 then
			return false, "Keep the Job Board clear"
		end
	end
	return true
end

-- Where the ghost goes: under the mouse (keyboard), or a little in front of you.
local function aimPoint()
	local r = root()
	if not r then
		return nil
	end
	local cam = workspace.CurrentCamera
	if cam and Theme.inputKind() == "keyboard" and UserInputService.MouseEnabled then
		local ok, hit = pcall(function()
			local m = UserInputService:GetMouseLocation()
			local ray = cam:ViewportPointToRay(m.X, m.Y)
			-- the ground plane at your feet
			local y = MapLayout.groundY(r.Position.X, r.Position.Z)
			if math.abs(ray.Direction.Y) < 1e-3 then
				return nil
			end
			local t = (y - ray.Origin.Y) / ray.Direction.Y
			if t <= 0 or t > 120 then
				return nil
			end
			return ray.Origin + ray.Direction * t
		end)
		if ok and hit and (hit - r.Position).Magnitude < 50 then
			return hit
		end
	end
	local look = r.CFrame.LookVector
	return r.Position + Vector3.new(look.X, 0, look.Z).Unit * 10
end

local function spotFor(key, r, point)
	local def = Pieces.byKey[key]
	local w, d = Pieces.cells(def, r)
	local i = math.floor(point.X / MapLayout.CELL - w / 2 + 0.5)
	local j = math.floor(point.Z / MapLayout.CELL - d / 2 + 0.5)
	return i, j
end

local function clearGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	ghostKey = nil
end

local function updateGhost()
	if not active or not selected then
		clearGhost()
		spot = nil
		return
	end
	local point = aimPoint()
	if not point then
		return
	end
	local i, j = spotFor(selected, rot, point)
	local ok, reason = BuildController.check(selected, i, j, rot)
	spot = { i = i, j = j, ok = ok, reason = reason }
	local def = Pieces.byKey[selected]
	local w, d = Pieces.cells(def, rot)
	local cx, cz = (i + w / 2) * MapLayout.CELL, (j + d / 2) * MapLayout.CELL
	local cf = PieceModels.frame(def, i, j, rot, MapLayout.groundY(cx, cz))
	if not ghost or ghostKey ~= selected or ghostRot ~= rot or ghostOk ~= ok then
		clearGhost()
		ghost = PieceModels.build(selected, cf, { ghost = ok and GREEN or RED, parent = workspace })
		ghost.Name = "PlacementGhost"
		ghostKey, ghostRot, ghostOk = selected, rot, ok
	else
		ghost:PivotTo(cf)
	end
	refs.place.Text = ok and "✅ PLACE" or "❌ " .. (reason or "")
	refs.place.BackgroundColor3 = ok and C.good or C.muted
end

function BuildController.place()
	if not active or not selected or not spot then
		return
	end
	if not spot.ok then
		Bus.Tap:Fire("place_blocked")
		return
	end
	Bus.Tap:Fire("place")
	Net.send("Place", selected, spot.i, spot.j, rot)
end

function BuildController.select(key)
	selected = key
	for k, card in refs.cards do
		card.BackgroundColor3 = k == key and C.mustard or C.paper
	end
	updateGhost()
end

function BuildController.rotate()
	rot = 1 - rot
	updateGhost()
end

local function setActive(on)
	active = on
	refs.bar.Visible = on
	refs.controls.Visible = on
	if not on then
		clearGhost()
		return
	end
	if not selected then
		BuildController.select("stoneWall")
	end
	Net.send("Viewed", "build")
end

-- The piece bar ------------------------------------------------------------------------------------------------------
local function buildBar()
	local bar = new("ScrollingFrame", {
		Name = "PieceBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -70, 1, -8),
		Size = UDim2.fromOffset(560, 104),
		BackgroundTransparency = 1,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.fromOffset(0, 0),
		Visible = false,
		Parent = gui,
	}, {
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})
	refs.bar = bar
	refs.cards = {}
	for k, p in Pieces.list do
		local card = Theme.button({
			Name = p.key,
			Text = "",
			BackgroundColor3 = C.paper,
			dark = true,
			LayoutOrder = k,
			Size = UDim2.fromOffset(92, 92),
			Parent = bar,
		})
		Theme.text({
			Text = p.icon,
			Size = UDim2.new(1, 0, 0, 38),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		Theme.text({
			Text = p.name,
			Font = Theme.Display,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 38),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		Theme.text({
			Text = Pieces.costText(p.need),
			TextSize = 13,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 58),
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = card,
		})
		card.Activated:Connect(function()
			Bus.Tap:Fire("piece_" .. p.key)
			BuildController.select(p.key)
		end)
		refs.cards[p.key] = card
	end
	local controls = new("Frame", {
		Name = "BuildControls",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -70, 1, -118),
		Size = UDim2.fromOffset(420, 56),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	refs.controls = controls
	refs.place = Theme.button({
		Name = "Place",
		Text = "✅ PLACE",
		BackgroundColor3 = C.good,
		Size = UDim2.fromOffset(220, 54),
		Parent = controls,
	})
	Theme.keyHint(refs.place, "Click", "A")
	refs.place.Activated:Connect(BuildController.place)
	local turn = Theme.button({
		Name = "Rotate",
		Text = "🔄 TURN",
		BackgroundColor3 = C.sky,
		Size = UDim2.fromOffset(110, 54),
		Position = UDim2.fromOffset(228, 0),
		Parent = controls,
	})
	Theme.keyHint(turn, "R", "X")
	turn.Activated:Connect(function()
		Bus.Tap:Fire("rotate")
		BuildController.rotate()
	end)
	local close = Theme.button({
		Name = "Close",
		Text = "✖",
		BackgroundColor3 = C.red,
		Size = UDim2.fromOffset(60, 54),
		Position = UDim2.fromOffset(346, 0),
		Parent = controls,
	})
	close.Activated:Connect(function()
		Bus.BuildMode:Fire(false)
	end)
	-- upgrade a finished piece next to you
	refs.upgrade = Theme.button({
		Name = "Upgrade",
		Text = "",
		BackgroundColor3 = C.purple,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -70, 1, -180),
		Size = UDim2.fromOffset(300, 48),
		Visible = false,
		Parent = gui,
	})
	refs.upgrade.Activated:Connect(function()
		local id = refs.upgrade:GetAttribute("PieceId")
		if id then
			Bus.Tap:Fire("upgrade")
			Net.send("Upgrade", id)
		end
	end)
	-- the station card (forge, kitchen, potion table)
	refs.station = Theme.slab({
		Name = "Station",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -170),
		Size = UDim2.fromOffset(250, 150),
		Visible = false,
		Parent = gui,
	})
	refs.stationTitle = Theme.title({
		Text = "",
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(8, 4),
		Parent = refs.station,
	})
	refs.stationButtons = {}
end

local STATION_ITEMS = {
	forge = { { "armor", "🛡️ Armor" }, { "weapon", "⚔️ Weapon" } },
	kitchen = { { "food", "🍲 Stew" } },
	potion = { { "potion", "🧪 Potion" } },
}
local STATION_NAMES = { forge = "⚒️ FORGE", kitchen = "🍲 KITCHEN", potion = "🧪 POTION TABLE" }

local function costFor(item)
	local me = Store.get("me") or {}
	if item == "armor" or item == "weapon" then
		local tier = me.gear and me.gear[item] or 0
		return Constants.GEAR_COST[tier + 1], tier
	elseif item == "food" then
		return Constants.FOOD_COST
	end
	return Constants.POTION_COST
end

local currentStation
local function showStation(kind)
	-- a different station: new buttons (the same one: just refresh the costs below)
	if kind ~= currentStation then
		currentStation = kind
		for _, b in refs.stationButtons do
			b:Destroy()
		end
		refs.stationButtons = {}
		if kind then
			refs.stationTitle.Text = STATION_NAMES[kind]
			for k, it in STATION_ITEMS[kind] do
				local b = Theme.button({
					Name = it[1],
					Text = it[2],
					BackgroundColor3 = C.orange,
					Size = UDim2.new(1, -16, 0, 50),
					Position = UDim2.fromOffset(8, 36 + (k - 1) * 56),
					Parent = refs.station,
				})
				b.Activated:Connect(function()
					Bus.Tap:Fire("craft_" .. it[1])
					Net.send("Craft", it[1])
				end)
				refs.stationButtons[it[1]] = b
			end
		end
	end
	refs.station.Visible = kind ~= nil
	if kind then
		for item, b in refs.stationButtons do
			local cost, tier = costFor(item)
			local name = STATION_ITEMS[kind][1][1] == item and STATION_ITEMS[kind][1][2] or STATION_ITEMS[kind][2][2]
			if cost then
				b.Text = name
					.. ((item == "armor" or item == "weapon") and ` {tier + 1}` or "")
					.. "  "
					.. Pieces.costText(cost)
			else
				b.Text = name .. "  MAX"
			end
		end
	end
end

-- What's near you: a station to use, a piece to upgrade.
local function nearby()
	local r = root()
	local me = Store.get("me") or {}
	if not r or me.team ~= "dwarf" or not Store.inMatch() then
		showStation(nil)
		refs.upgrade.Visible = false
		return
	end
	local pos = r.Position
	local stationKind, upgradePiece, best = nil, nil, nil
	local castle = workspace:FindFirstChild("Castle")
	for _, m in castle and castle:GetChildren() or {} do
		local key = m:GetAttribute("Key")
		local def = key and Pieces.byKey[key]
		if def and m:GetAttribute("Built") then
			local i, j, rr = m:GetAttribute("I"), m:GetAttribute("J"), m:GetAttribute("Rot")
			local w, d = Pieces.cells(def, rr)
			local cx, cz = (i + w / 2) * MapLayout.CELL, (j + d / 2) * MapLayout.CELL
			local dist = Vector2.new(pos.X - cx, pos.Z - cz).Magnitude - math.max(w, d) * 2
			if def.station and def.station ~= "fix" and def.station ~= "heal" and dist <= Constants.CRAFT_RANGE - 2 then
				stationKind = def.station
			end
			if
				active
				and def.upgrade
				and not m:GetAttribute("Upgraded")
				and not m:GetAttribute("Upgrading")
				and dist <= 10
			then
				if not best or dist < best then
					best = dist
					upgradePiece = m
				end
			end
		end
	end
	showStation(stationKind)
	if upgradePiece then
		local def = Pieces.byKey[upgradePiece:GetAttribute("Key")]
		refs.upgrade.Text = "⬆️ " .. def.upgrade.name .. "  " .. Pieces.costText(def.upgrade.need)
		refs.upgrade:SetAttribute("PieceId", upgradePiece:GetAttribute("PieceId"))
		refs.upgrade.Visible = true
	else
		refs.upgrade.Visible = false
	end
end

function BuildController:init()
	gui = Theme.screen("Build", 7, player:WaitForChild("PlayerGui"))
	buildBar()
	Bus.BuildMode:Connect(setActive)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not active then
			return
		end
		if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonX then
			BuildController.rotate()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonA then
			BuildController.place()
		elseif input.KeyCode.Value >= Enum.KeyCode.One.Value and input.KeyCode.Value <= Enum.KeyCode.Nine.Value then
			local idx = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
			local p = Pieces.list[idx]
			if p then
				BuildController.select(p.key)
			end
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if active then
			updateGhost()
		end
		if acc >= 0.3 then
			acc = 0
			nearby()
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.me and partial.me.team ~= "dwarf" and active then
			Bus.BuildMode:Fire(false)
		end
	end)
end

-- (tests)
function BuildController.state()
	return { active = active, selected = selected, rot = rot, spot = spot, ghost = ghost }
end
BuildController.refs = refs

return BuildController
