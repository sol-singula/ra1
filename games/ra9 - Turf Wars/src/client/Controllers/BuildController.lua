--[[
Building (master plan §2B, §7) on your side: pick a structure from the tray (a click, a tap, 1-7, or the mouse
wheel), and a see-through preview follows where you look, snapped to the 4-stud grid: green where it can go, red
where it can't (enemy turf, the spawn zones, out of reach, something already there, nothing under it); right up to
the line is fine. Click (or the PLACE button) to build; R or a right click (or TURN) turns it. The server checks
everything again and says why if not.

Pieces stack: look at the top of a piece your team built and the preview sits on it (the base at its top, y), so
walls go on walls, a battlement on a wall as its parapet, walls and towers on ramparts (Formulas.stackCheck: every
cell under it must top out at the same height, never on a tower, a shield or a banner, never above
BUILD_MAX_HEIGHT; the reason reads NO SUPPORT or TOO HIGH). Look at a piece's side and the preview is on the floor
in front of it. Where you look is the camera's ray against the boxes of what stands (the server tells every client
each piece's box: Net "Structure" built) and then the floor at y = 0: no raycast, the same on every device, so a
phone's and a pad's aim-to-place work the same as a mouse.

Hold the button (the mouse, the pad's R2 or the touch PLACE) and pieces go down one after another as you swing your
aim along: a run of wall, each costing as usual; while the aim is still over the piece just placed, the next one
goes in line past it (the way you're aiming), so a row comes out straight. A fainter second ghost shows the next
slot in line while you build. Nothing is placed while a menu is open (the click is the menu's).
]]
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Structures = require(ReplicatedStorage.Shared.Data.Structures)
local Bus = require(script.Parent.Parent.UI.Bus)
local Layout = require(script.Parent.Parent.UI.Layout)
local Store = require(script.Parent.Parent.Store)

local BuildController = { Name = "BuildController", Order = 32 }

local GREEN = Color3.fromRGB(96, 224, 128)
local HOLD_GAP = 0.18 -- seconds between pieces in a run (under the Build event's rate)

local picked -- structure key
local rot = 0
local ghost, ghost2 -- the preview, and the fainter one for the next slot in line
local spot -- { cx, cz, y, ok, why }
local boxes = {} -- [id] = { min, max, team, key } every standing piece (the server's "Structure" messages)
local holding = false -- the place button held: a run
local run -- { key, cx, cz, w, d, y, rot, min, dir } the last piece the server built for us (the run goes on in line from it)
local pending -- the same, for the piece just sent (the server hasn't answered yet)
local lastSend = 0

function BuildController.picked()
	return picked
end

function BuildController.spot()
	return spot
end

function BuildController.boxes()
	return boxes
end

function BuildController.pick(key)
	if key and not Structures.get(key) then
		return
	end
	picked = (picked ~= key) and key or nil
	for _, g in { ghost, ghost2 } do
		if g then
			g:Destroy()
		end
	end
	ghost, ghost2, run = nil, nil, nil
	Bus.BuildPick:Fire(picked)
end

-- The mouse wheel: the next (step 1) or the one before (step -1) in the tray, round the end; from nothing, the first
-- or the last.
function BuildController.cycle(step)
	local n = #Structures.list
	local at
	for i, s in Structures.list do
		if s.key == picked then
			at = i
		end
	end
	local i = at and ((at - 1 + step) % n + 1) or (step > 0 and 1 or n)
	picked = nil -- (so pick() picks it rather than toggling it off)
	BuildController.pick(Structures.list[i].key)
	return picked
end

-- The tallest standing piece on cell (x, z), as { top, team, key }, or nil for the bare floor
local function topAt(x, z)
	local px, pz = Formulas.cellCenter(x, z)
	local best
	for _, b in boxes do
		if px > b.min.X and px < b.max.X and pz > b.min.Z and pz < b.max.Z and (not best or b.max.Y > best.top) then
			best = { top = b.max.Y, team = b.team, key = b.key }
		end
	end
	return best
end
BuildController.topAt = topAt

local function clampReach(o, p)
	local flat = Vector3.new(p.X - o.X, 0, p.Z - o.Z)
	if flat.Magnitude > Constants.BUILD_REACH - 4 then
		return Vector3.new(o.X, p.Y, o.Z) + flat.Unit * (Constants.BUILD_REACH - 4), true
	end
	return p, false
end

-- Where the camera's ray meets what stands (the top of a piece: the point and that height; its side: the floor in
-- front of it) or the floor (y = 0), or nil if you look up at nothing. Returns the point, the base height and the
-- piece's box when the ray met one.
function BuildController.aimPoint()
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local o, d = cam.CFrame.Position, cam.CFrame.LookVector
	local far = o + d * (Constants.BUILD_REACH + 24)
	local bestT, best
	for _, b in boxes do
		local t = Formulas.segmentBox(o, far, b.min, b.max)
		if t and (not bestT or t < bestT) then
			bestT, best = t, b
		end
	end
	if best then
		local hit = o + (far - o) * bestT
		local _, farOff = clampReach(o, hit)
		if not farOff then
			if hit.Y >= best.max.Y - 0.05 then
				return Vector3.new(hit.X, best.max.Y, hit.Z), best.max.Y, best
			end
			-- (its side: the cell in front of it)
			local flat = Vector3.new(d.X, 0, d.Z)
			flat = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(1, 0, 0)
			return Vector3.new(hit.X, 0, hit.Z) - flat * 0.6, 0, best
		end
	end
	if d.Y > -0.05 then
		-- (looking level or up: a point straight ahead at reach)
		return o + Vector3.new(d.X, 0, d.Z).Unit * 16 - Vector3.new(0, o.Y, 0), 0
	end
	local t = -o.Y / d.Y
	local p = clampReach(o, o + d * t)
	return Vector3.new(p.X, 0, p.Z), 0
end

-- The local check (the server's is the one that counts): your turf, back from the line, in the field, your points,
-- what it stands on, in reach. y: the base height (0, the floor).
function BuildController.check(key, cx, cz, r, y)
	local def = Structures.get(key)
	local m = Store.get("match") or {}
	local team = Store.team()
	if not def or not team then
		return false, "No team"
	end
	if m.phase ~= "build" then
		return false, "Building is only in the build phase"
	end
	y = y or 0
	local w, d = Structures.footprint(def, r)
	local mn, mx = Formulas.footprintBox(cx, cz, w, d, y, def.h)
	local front = m.frontline or 0
	local gap = Constants.BUILD_FRONT_GAP * Constants.CELL
	if team == "red" and mx.X > front - gap or team == "blue" and mn.X < front + gap then
		return false, "Only on your own turf"
	end
	local edge = math.abs(m.loseRed or 80)
	if mn.X < -edge or mx.X > edge then
		return false, "Not in the spawn zones"
	end
	local me = Store.get("me") or {}
	if (me.budget or 0) < def.cost then
		return false, "Not enough build points"
	end
	local ok, why = Formulas.stackCheck(def, team, cx, cz, w, d, y, topAt)
	if not ok then
		return false, why
	end
	local c = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if root and ((mn + mx) / 2 - root.Position).Magnitude > Constants.BUILD_REACH then
		return false, "Too far away"
	end
	return true, nil, mn, mx
end

local function newGhost(name)
	local g = Instance.new("Part")
	g.Name = name
	g.Anchored = true
	g.CanCollide = false
	g.CanQuery = false
	g.CastShadow = false
	g.Material = Enum.Material.SmoothPlastic
	g.Transparency = 0.5
	return g
end

local function showGhost(g, mn, mx, ok, faint)
	g.Size = mx - mn
	g.CFrame = CFrame.new((mn + mx) / 2)
	g.Color = ok and GREEN or Constants.TEAM_COLOR.red
	g.Transparency = faint and 0.82 or (ok and 0.45 or 0.6)
	g.Parent = workspace
end

-- The next slot in line from a piece at (cx, cz): along its long side, the way that leads away from the camera
local function nextSlot(cx, cz, w, d)
	local cam = workspace.CurrentCamera
	local mn, mx = Formulas.footprintBox(cx, cz, w, d, 0, 1)
	local centre = (mn + mx) / 2
	local from = cam and cam.CFrame.Position or centre
	if w >= d then
		local sign = centre.X - from.X >= 0 and 1 or -1
		return cx + sign * w, cz
	end
	local sign = centre.Z - from.Z >= 0 and 1 or -1
	return cx, cz + sign * d
end

local function placeGhost()
	if not picked or Store.phase() ~= "build" then
		for _, g in { ghost, ghost2 } do
			if g then
				g.Parent = nil
			end
		end
		spot = nil
		return
	end
	local p, y, hitBox = BuildController.aimPoint()
	if not p then
		return
	end
	local def = Structures.get(picked)
	local w, d = Structures.footprint(def, rot)
	local cx, cz = Formulas.cellOf(p.X - (w - 1) * Constants.CELL / 2, p.Z - (d - 1) * Constants.CELL / 2)
	-- a run (the button held): every piece in the line of the last one built, at its height; while the aim is still
	-- on that piece (over it, or the ray meets it), the next slot in line past it, the way the aim is moving
	if holding and run and run.key == picked and run.rot == rot then
		if w >= d then
			cz = run.cz
		else
			cx = run.cx
		end
		y = run.y
		local over = cx < run.cx + run.w and cx + w > run.cx and cz < run.cz + run.d and cz + d > run.cz
		if hitBox and (hitBox.min - run.min).Magnitude < 0.01 then
			over = true
		end
		if over then
			-- (which way: the way the aim has moved off the piece's middle; until it moves, nothing more goes down)
			local c = Constants.CELL
			local off = w >= d and p.X - (run.cx + run.w / 2) * c or p.Z - (run.cz + run.d / 2) * c
			if math.abs(off) > 1 then
				run.dir = off > 0 and 1 or -1
			end
		end
		if over and run.dir then
			if w >= d then
				cx = run.dir > 0 and run.cx + run.w or run.cx - w
			else
				cz = run.dir > 0 and run.cz + run.d or run.cz - d
			end
		end
	end
	local ok, why, mn, mx = BuildController.check(picked, cx, cz, rot, y)
	spot = { cx = cx, cz = cz, y = y, ok = ok, why = why }
	ghost = ghost or newGhost("BuildGhost")
	ghost2 = ghost2 or newGhost("BuildGhostNext")
	if not mn then
		mn, mx = Formulas.footprintBox(cx, cz, w, d, y, def.h)
	end
	showGhost(ghost, mn, mx, ok, false)
	-- (the next slot in line, faintly, when it can go there too)
	local nx, nz = nextSlot(cx, cz, w, d)
	local ok2, _, mn2, mx2 = BuildController.check(picked, nx, nz, rot, y)
	if ok and ok2 and mn2 then
		showGhost(ghost2, mn2, mx2, true, true)
	else
		ghost2.Parent = nil
	end
	-- the run: the next piece as soon as the aim is on a new, good spot (not the one just sent or built)
	local function same(r)
		return r ~= nil and r.cx == cx and r.cz == cz and r.y == y
	end
	if holding and ok and os.clock() - lastSend >= HOLD_GAP and not same(run) and not same(pending) then
		BuildController.place()
	end
end

function BuildController.place()
	if not picked or not spot or Layout.panel() or Layout.modalOpen() then
		return false
	end
	if not spot.ok then
		Bus.Tap:Fire("build_refused")
		return false
	end
	local def = Structures.get(picked)
	local w, d = Structures.footprint(def, rot)
	-- (once the server builds it, the run goes on from it, the way it was going: the "built" message, which can
	-- come straight back)
	local mn = Formulas.footprintBox(spot.cx, spot.cz, w, d, spot.y or 0, def.h)
	pending = {
		key = picked,
		cx = spot.cx,
		cz = spot.cz,
		w = w,
		d = d,
		y = spot.y or 0,
		rot = rot,
		min = mn,
		dir = run and run.dir or nil,
	}
	lastSend = os.clock()
	Net.send("Build", picked, spot.cx, spot.cz, rot, spot.y or 0)
	Bus.Tap:Fire("build_" .. picked)
	return true
end

-- The place button held (true) or let go: a run of pieces along where you aim
function BuildController.hold(on)
	holding = on == true
	if not holding then
		run, pending = nil, nil
	end
end

function BuildController.holding()
	return holding
end

function BuildController.rotation()
	return rot
end

function BuildController.rotate()
	rot = 1 - rot
end

function BuildController:init()
	local keys = {
		[Enum.KeyCode.One] = 1,
		[Enum.KeyCode.Two] = 2,
		[Enum.KeyCode.Three] = 3,
		[Enum.KeyCode.Four] = 4,
		[Enum.KeyCode.Five] = 5,
		[Enum.KeyCode.Six] = 6,
		[Enum.KeyCode.Seven] = 7,
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or Store.phase() ~= "build" then
			return
		end
		local i = keys[input.KeyCode]
		if i and Structures.list[i] then
			BuildController.pick(Structures.list[i].key)
		elseif input.KeyCode == Enum.KeyCode.Q or input.KeyCode == Enum.KeyCode.Escape then
			BuildController.pick(nil)
		end
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if
			processed
			or input.UserInputType ~= Enum.UserInputType.MouseWheel
			or Store.phase() ~= "build"
			or Layout.panel()
			or Layout.modalOpen()
		then
			return
		end
		local z = input.Position and input.Position.Z or 0
		if z ~= 0 then
			BuildController.cycle(z < 0 and 1 or -1) -- (wheel down: the next piece)
		end
	end)
	-- placing: a press builds the piece; held, the run goes on (placeGhost) until it's let go
	ContextActionService:BindAction("TW_Place", function(_, state)
		if state == Enum.UserInputState.Begin and picked and Store.phase() == "build" and not Layout.panel() then
			BuildController.place()
			BuildController.hold(true)
			return Enum.ContextActionResult.Sink
		elseif state ~= Enum.UserInputState.Begin then
			BuildController.hold(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	-- turning the piece: R, a right click (the wheel picks the piece, so the mouse's other button turns it), or the
	-- gamepad's Y; the touch TURN button too (Bus.Rotate)
	ContextActionService:BindAction("TW_Rotate", function(_, state)
		if state == Enum.UserInputState.Begin and picked and Store.phase() == "build" then
			BuildController.rotate()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonY)
	Bus.Place:Connect(BuildController.place)
	Bus.PlaceHold:Connect(BuildController.hold)
	Bus.Rotate:Connect(BuildController.rotate)
	-- what stands (its box): the preview sits on the tops of your team's pieces
	Net.listen("Structure", function(s)
		if type(s) ~= "table" then
			return
		end
		if s.kind == "built" and typeof(s.boxMin) == "Vector3" and typeof(s.boxMax) == "Vector3" then
			boxes[s.id] = { min = s.boxMin, max = s.boxMax, team = s.team, key = s.key }
			if pending and s.key == pending.key and (s.boxMin - pending.min).Magnitude < 0.01 then
				run, pending = pending, nil -- (ours, built: the run goes on from it)
			end
		elseif s.kind == "destroyed" then
			boxes[s.id] = nil
		end
	end)
	Store.Changed:Connect(function(partial)
		if partial.match and partial.match.phase ~= "build" then
			if picked then
				BuildController.pick(nil)
			end
			BuildController.hold(false)
		end
	end)
	RunService.RenderStepped:Connect(placeGhost)
end

return BuildController
