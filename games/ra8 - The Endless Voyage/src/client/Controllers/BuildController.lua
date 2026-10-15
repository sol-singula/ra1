--[[
Building (master plan §5: the raft is a grid, building is visible and tactile). The build panel picks a piece
(Bus.Place); then a ghost of it follows where you point (the mouse on PC, in front of you on phones and gamepads),
green where it can go and red where it can't (with the reason), and ACT / a click / a tap places it: the server
checks and builds (RaftService). Tiles keep placing until DONE; everything else places once. ROTATE turns a chair
or the helm; railings and nets pick the edge nearest to where you point. Demolish: tap a piece.
QUICK (Bus.Quick, from InputController's button): the piece the raft recommends (the next tier's missing station if
the bag can pay for it, else a tile) goes where you look, again every half second while the button is held, with
the same ghost and the same rules. Looking at the water beside the raft while a station is recommended lays tiles.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)
local Pieces = require(ReplicatedStorage.Shared.Data.Pieces)
local RaftModels = require(ReplicatedStorage.Shared.World.RaftModels)
local HudController = require(script.Parent.HudController)
local InputController = require(script.Parent.InputController)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local BuildController = { Name = "BuildController", Order = 22 }

local player = Players.LocalPlayer
local C = Theme.Color
local gui
local refs = {}
local placing -- { key, def, rot, ghost, spot = { gx, gz, level, rot }, valid, reason, demolish, quick, why }
local quickReason
local ghostFolder
local lastSpotKey
local WATERSIDE = { net = true, salvage_net = true, ladder = true, spikes = true }
local NEIGHBOURS = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }

local function root()
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function center()
	local raft = Store.get("raft")
	local layout = raft and raft.plot and OceanLayout.plot(raft.plot)
	return layout and layout.center or Vector3.zero
end

-- Lookups from the raft view: tiles, pieces on tiles, pieces on edges.
local function maps()
	local raft = Store.get("raft") or { pieces = {} }
	local tiles, onTile, edges, count = {}, {}, {}, 0
	for _, p in raft.pieces or {} do
		local def = Pieces.get(p.key)
		local k = p.level * 100000 + p.gx * 100 + p.gz
		if def and def.structural then
			tiles[k] = p
			count += 1
		elseif def and def.edge then
			edges[k * 10 + (p.rot or 0)] = p
		elseif def then
			onTile[k] = p
		end
	end
	return tiles, onTile, edges, count, raft
end

local function key(gx, gz, level)
	return level * 100000 + gx * 100 + gz
end

-- Can the piece go there? (the server's rules, mirrored, so the ghost's colour is honest)
local function check(def, gx, gz, level, rot)
	local tiles, onTile, edges, count, raft = maps()
	local profile = Store.get("profile")
	if gx < 0 or gz < 0 or gx >= Constants.GRID or gz >= Constants.GRID then
		return false, "Off the plot"
	end
	if def.blueprint and not (profile and profile.blueprints and profile.blueprints[def.key]) then
		return false, "Needs its blueprint"
	end
	if def.tier > (raft.tier or 1) then
		return false, "🔒 Grow your raft first (RAFT shows how)"
	end
	local tile = tiles[key(gx, gz, level)]
	if def.structural then
		if tile then
			return false, "A tile is there"
		end
		if count >= (raft.max or 12) then
			local grow = Formulas.growText(raft.needs)
			return false, grow and `Raft full! Build {grow} to make it bigger` or "Raft full!"
		end
		local adjacent = false
		for _, d in NEIGHBOURS do
			if tiles[key(gx + d[1], gz + d[2], level)] then
				adjacent = true
			end
		end
		if level == 1 then
			if not adjacent then
				return false, "Build next to the raft"
			end
		else
			local below = tiles[key(gx, gz, 1)]
			if not below then
				return false, "Needs a tile below"
			end
			local stairs = false
			for _, d in NEIGHBOURS do
				local t = tiles[key(gx + d[1], gz + d[2], 1)]
				if t and t.key == "stairs" then
					stairs = true
				end
			end
			if not adjacent and not stairs then
				return false, "Needs stairs or a tile beside it"
			end
		end
	else
		if not tile then
			return false, "Needs a tile"
		end
		if tile.key == "stairs" then
			return false, "Not on the stairs"
		end
		if def.deck == 2 and level ~= 2 then
			return false, "Second deck only"
		end
		if def.edge then
			if edges[key(gx, gz, level) * 10 + rot] then
				return false, "That edge is taken"
			end
			if WATERSIDE[def.key] then
				local d = NEIGHBOURS[rot + 1]
				if tiles[key(gx + d[1], gz + d[2], level)] then
					return false, "Must face the water"
				end
			end
		elseif onTile[key(gx, gz, level)] then
			return false, "That tile is taken"
		end
	end
	local inv = Store.get("inv") or { slots = {} }
	for item, n in def.cost do
		local have = 0
		for _, s in inv.slots do
			if s.key == item then
				have += s.n
			end
		end
		if have < n then
			local it = Items.get(item)
			return false, `Needs {n} {it and it.name or item} ({have})`
		end
	end
	return true
end

-- Where you look (the QUICK button, phones and gamepads): the camera's centre line on the deck you stand on, near you.
local function lookPoint()
	local r = root()
	local cam = workspace.CurrentCamera
	if not r or not cam then
		return nil
	end
	local _, _, level = Formulas.tileAt(center(), r.Position)
	local planeY = Constants.DECK_Y + (level - 1) * Constants.DECK_HEIGHT + 0.5
	local origin, dir = cam.CFrame.Position, cam.CFrame.LookVector
	local point
	if dir.Y < -0.02 then
		point = origin + dir * ((planeY - origin.Y) / dir.Y)
	end
	if not point or (Vector3.new(point.X, 0, point.Z) - Vector3.new(r.Position.X, 0, r.Position.Z)).Magnitude > 24 then
		local flat = Vector3.new(dir.X, 0, dir.Z)
		flat = flat.Magnitude > 0.01 and flat.Unit or r.CFrame.LookVector
		point = r.Position + flat * 9
	end
	return Vector3.new(point.X, planeY, point.Z)
end

-- Where you point: a world position (the mouse's hit on PC, a few studs ahead otherwise).
local function aimPoint()
	local r = root()
	if not r then
		return nil
	end
	if placing and placing.quick == "look" then
		return lookPoint()
	end
	local hit = InputController.mouseRay()
	if hit then
		return hit
	end
	local cam = workspace.CurrentCamera
	local look = cam and cam.CFrame.LookVector or r.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	flat = flat.Magnitude > 0.01 and flat.Unit or r.CFrame.LookVector
	return r.Position + flat * 7 + Vector3.new(0, -2, 0)
end

-- The tile nearest to a point (on the level the point's height says, else any), within reach.
local function nearestTile(point, level)
	local c = center()
	local best, bestD
	for _, p in (Store.get("raft") or { pieces = {} }).pieces or {} do
		local pd = Pieces.get(p.key)
		if pd and pd.structural and (not level or p.level == level) then
			local pos = Formulas.tilePosition(c, p.gx, p.gz, p.level)
			local d = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
			if d <= 10 and (not bestD or d < bestD) then
				best, bestD = p, d
			end
		end
	end
	return best
end

-- The spot the ghost goes to: the tile under the point (or the nearest one, so pointing at the water beside the
-- raft still works), and for edge pieces the edge nearest to the point.
local function spotFor(def, point, rot)
	local c = center()
	local gx, gz, level = Formulas.tileAt(c, point)
	rot = rot or 0
	if not def.structural then
		local tiles = maps()
		if not tiles[key(gx, gz, level)] then
			local t = nearestTile(point, level) or nearestTile(point, nil)
			if t then
				gx, gz, level = t.gx, t.gz, t.level
			end
		end
	end
	if def.edge then
		local tilePos = Formulas.tilePosition(c, gx, gz, level)
		local dx, dz = point.X - tilePos.X, point.Z - tilePos.Z
		if math.abs(dx) > math.abs(dz) then
			rot = dx > 0 and 0 or 2
		else
			rot = dz > 0 and 1 or 3
		end
	end
	if def.structural then
		-- a tile where you point if it's free and beside the raft, else the free spot nearest to the point
		local tiles = maps()
		local beside = false
		for _, d in NEIGHBOURS do
			if tiles[key(gx + d[1], gz + d[2], level)] then
				beside = true
			end
		end
		if tiles[key(gx, gz, level)] or not beside then
			local best, bestD
			for _, p in (Store.get("raft") or { pieces = {} }).pieces or {} do
				local pd = Pieces.get(p.key)
				if pd and pd.structural and p.level == level then
					for _, d in NEIGHBOURS do
						local nx, nz = p.gx + d[1], p.gz + d[2]
						if not tiles[key(nx, nz, level)] then
							local pos = Formulas.tilePosition(c, nx, nz, level)
							local dist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(point.X, 0, point.Z)).Magnitude
							if not bestD or dist < bestD then
								best, bestD = { nx, nz }, dist
							end
						end
					end
				end
			end
			if best then
				gx, gz = best[1], best[2]
			end
		end
	end
	return { gx = gx, gz = gz, level = level, rot = rot }
end

local function ensureFolder()
	if ghostFolder and ghostFolder.Parent then
		return ghostFolder
	end
	ghostFolder = workspace:FindFirstChild("Ghost") or Instance.new("Folder")
	ghostFolder.Name = "Ghost"
	ghostFolder.Parent = workspace
	return ghostFolder
end

local function clearGhost()
	if placing and placing.ghost then
		placing.ghost:Destroy()
		placing.ghost = nil
	end
	lastSpotKey = nil
end

local function ghostAt(spot)
	local def = placing.def
	local c = center()
	local pos = Formulas.tilePosition(c, spot.gx, spot.gz, spot.level)
	local cf = def.edge and CFrame.new(pos) or CFrame.new(pos) * CFrame.Angles(0, -(spot.rot or 0) * math.pi / 2, 0)
	local raft = Store.get("raft") or {}
	clearGhost()
	local m = RaftModels.build(
		placing.key,
		cf,
		{ colours = raft.colours, edge = def.edge and spot.rot or nil },
		ensureFolder()
	)
	m.Name = "Ghost"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Transparency = math.max(d.Transparency, 0.45)
		elseif d:IsA("ProximityPrompt") or d:IsA("Light") then
			d:Destroy()
		end
	end
	local glow = Instance.new("Highlight")
	glow.Name = "Glow"
	glow.FillTransparency = 0.6
	glow.OutlineTransparency = 0
	glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	glow.Parent = m
	placing.ghost = m
	placing.glow = glow
end

local function updateBar()
	if not placing then
		refs.bar.Visible = false
		return
	end
	refs.bar.Visible = true
	if placing.demolish then
		refs.barText.Text = "💥 DEMOLISH: tap a piece (half its cost back)"
		refs.barText.TextColor3 = C.red
		refs.rotate.Visible = false
		return
	end
	local def = placing.def
	local inv = Store.get("inv") or { slots = {} }
	local parts = {}
	for item, n in def.cost do
		local it = Items.get(item)
		local have = 0
		for _, s in inv.slots do
			if s.key == item then
				have += s.n
			end
		end
		table.insert(parts, `{it and it.icon or ""} {n} {it and it.name or item} ({have})`)
	end
	local cost = table.concat(parts, " · ")
	local lead = placing.quick and `⚡ {def.icon} {def.name} ({placing.why or "next"})` or `{def.icon} {def.name}`
	if placing.valid then
		refs.barText.Text = placing.quick and `{lead} · {cost} · hold to build` or `{lead} · {cost} · ACT to place`
		refs.barText.TextColor3 = C.good
	else
		refs.barText.Text = `{lead} · {placing.reason or ""}`
		refs.barText.TextColor3 = C.red
	end
	refs.rotate.Visible = not def.edge and not def.structural and not placing.quick
end

local function step()
	if not placing or placing.demolish then
		return
	end
	local point = aimPoint()
	if not point then
		return
	end
	local spot = spotFor(placing.def, point, placing.rot)
	placing.spot = spot
	local ok, reason = check(placing.def, spot.gx, spot.gz, spot.level, spot.rot)
	placing.valid, placing.reason = ok, reason
	local k = `{spot.gx},{spot.gz},{spot.level},{spot.rot}`
	if k ~= lastSpotKey then
		lastSpotKey = k
		ghostAt(spot)
	end
	if placing.glow then
		placing.glow.FillColor = ok and C.good or C.red
		placing.glow.OutlineColor = ok and C.good or C.red
	end
	updateBar()
end

function BuildController.start(pieceKey)
	BuildController.stop()
	if pieceKey == "demolish" then
		placing = { demolish = true }
		updateBar()
		return
	end
	local def = Pieces.get(pieceKey)
	if not def then
		return
	end
	placing = { key = pieceKey, def = def, rot = 0 }
	updateBar()
	step()
end

function BuildController.stop()
	if placing then
		clearGhost()
		placing = nil
	end
	updateBar()
end

-- ACT while placing: build it here.
function BuildController.place()
	if not placing then
		return false
	end
	if placing.demolish then
		local r = root()
		if not r then
			return false
		end
		-- the piece under the mouse, or the nearest one in front
		local _, dir, origin = InputController.mouseRay()
		local best, bestScore
		local rafts = workspace:FindFirstChild("Rafts")
		local raft = Store.get("raft")
		local folder = rafts and raft and rafts:FindFirstChild("Raft" .. tostring(raft.plot))
		for _, m in folder and folder:GetChildren() or {} do
			local id = m:GetAttribute("PieceId")
			if id then
				local pos = m:GetPivot().Position
				local score
				if origin and dir then
					local rel = pos - origin
					local along = rel:Dot(dir)
					local off = along > 0 and (rel - dir * along).Magnitude or math.huge
					score = off < 4 and off or nil
				else
					local d = (pos - r.Position).Magnitude
					score = d <= 10 and d or nil
				end
				if score and (not bestScore or score < bestScore) then
					best, bestScore = id, score
				end
			end
		end
		if best then
			Net.send("Demolish", best)
			Bus.Tap:Fire("demolish")
			return true
		end
		return false
	end
	if not placing.valid or not placing.spot then
		return false
	end
	local s = placing.spot
	Net.send("Build", placing.key, s.gx, s.gz, s.level, s.rot)
	Bus.Tap:Fire("place_" .. placing.key)
	Bus.Swing:Fire("hammer", "repair")
	if not placing.def.structural then
		task.delay(0.3, function()
			if placing and not placing.def.structural then
				BuildController.stop()
				Bus.Place:Fire(false)
			end
		end)
	end
	return true
end

-- QUICK: the recommended piece goes where you look (how: "look" for the button, phones and gamepads; "key" for F,
-- which points with the mouse on PC).
function BuildController.quickStart(how)
	local rec = Formulas.recommended(Store.get("raft"), Store.get("inv"))
	if not rec then
		return false
	end
	BuildController.start(rec.key)
	if not placing then
		return false
	end
	placing.quick = how == "key" and "key" or "look"
	placing.why = rec.why
	quickReason = nil
	step()
	return true
end

-- A tick of the hold: build it if it can go there (a tile instead, when you look at the water beside the raft).
function BuildController.quickPlace()
	if not placing or not placing.quick then
		return false
	end
	step()
	if not placing.valid and not placing.def.structural and placing.reason == "Needs a tile" then
		local how, why = placing.quick, placing.why
		BuildController.start("floor")
		if not placing then
			return false
		end
		placing.quick, placing.why = how, why
		step()
	end
	if placing.valid then
		quickReason = nil
		return BuildController.place()
	end
	if placing.reason and placing.reason ~= quickReason then
		quickReason = placing.reason
		HudController.toast(`⚡ {placing.def.name}: {placing.reason}`, "info")
	end
	return false
end

function BuildController.quickStop()
	if placing and placing.quick then
		BuildController.stop()
	end
end

function BuildController:init()
	gui = Theme.screen("Build", 5, player:WaitForChild("PlayerGui"))
	local bar = Theme.slab({
		Name = "PlaceBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, -40, 1, -84),
		Size = UDim2.fromOffset(620, 44),
		Visible = false,
		Parent = gui,
	})
	refs.bar = bar
	refs.barText = Theme.title({
		Name = "Text",
		Text = "",
		Size = UDim2.new(1, -200, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		TextSize = 16,
		outline = 2,
		Parent = bar,
	})
	refs.rotate = Theme.button({
		Name = "Rotate",
		Text = "ROTATE",
		BackgroundColor3 = C.sky,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -92, 0.5, 0),
		Size = UDim2.fromOffset(84, 32),
		TextSize = 14,
		Parent = bar,
	})
	Theme.keyHint(refs.rotate, "R", "L2")
	refs.rotate.Activated:Connect(function()
		if placing and not placing.demolish then
			placing.rot = (placing.rot + 1) % 4
			lastSpotKey = nil
		end
	end)
	local done = Theme.button({
		Name = "Done",
		Text = "DONE",
		BackgroundColor3 = C.red,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(80, 32),
		TextSize = 14,
		Parent = bar,
	})
	done.Activated:Connect(function()
		BuildController.stop()
		Bus.Place:Fire(false)
	end)
	Bus.Place:Connect(function(k)
		if k == "act" then
			BuildController.place()
		elseif k == false or k == nil then
			BuildController.stop()
		else
			BuildController.start(k)
		end
	end)
	Bus.Quick:Connect(function(what, how)
		if what == "start" then
			BuildController.quickStart(how)
		elseif what == "place" then
			BuildController.quickPlace()
		elseif what == "stop" then
			BuildController.quickStop()
		end
	end)
	game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
		if processed or not placing then
			return
		end
		if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.ButtonL2 then
			if not placing.demolish then
				placing.rot = (placing.rot + 1) % 4
				lastSpotKey = nil
			end
		elseif input.KeyCode == Enum.KeyCode.Escape then
			BuildController.stop()
			Bus.Place:Fire(false)
		end
	end)
	Store.Changed:Connect(function(partial)
		if (partial.raft or partial.inv) and placing then
			lastSpotKey = nil
		end
	end)
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.06 then
			acc = 0
			step()
		end
	end)
end

-- (tests)
function BuildController.placing()
	return placing
end
BuildController.refs = refs
return BuildController
