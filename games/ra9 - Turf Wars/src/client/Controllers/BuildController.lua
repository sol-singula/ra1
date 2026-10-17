--[[
Building (master plan §2B, §7) on your side: pick a structure from the tray (a click, a tap, 1-7, or the mouse
wheel), and a see-through preview follows where you look on the floor, snapped to the 4-stud grid: white where it
can go, red where it can't (enemy turf, the spawn zones, out of reach, something already there); right up to the
line is fine. Click (or the PLACE button) to build; R or a right click (or TURN) turns it. The server checks
everything again and says why if not.

The floor is flat at y = 0 everywhere you can build, so "where you look" is the camera's ray meeting that plane:
no raycast needed, the same on every device. Nothing is placed while a menu is open (the click is the menu's).
]]
local ContextActionService = game:GetService("ContextActionService")
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

local picked -- structure key
local rot = 0
local ghost
local spot -- { cx, cz, ok, why }

function BuildController.picked()
	return picked
end

function BuildController.spot()
	return spot
end

function BuildController.pick(key)
	if key and not Structures.get(key) then
		return
	end
	picked = (picked ~= key) and key or nil
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
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

-- Where the camera's ray meets the floor (y = 0), or nil if you look up.
function BuildController.aimPoint()
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local o, d = cam.CFrame.Position, cam.CFrame.LookVector
	if d.Y > -0.05 then
		-- (looking level or up: a point straight ahead at reach)
		return o + Vector3.new(d.X, 0, d.Z).Unit * 16 - Vector3.new(0, o.Y, 0)
	end
	local t = -o.Y / d.Y
	local p = o + d * t
	local flat = Vector3.new(p.X - o.X, 0, p.Z - o.Z)
	if flat.Magnitude > Constants.BUILD_REACH - 4 then
		p = Vector3.new(o.X, 0, o.Z) + flat.Unit * (Constants.BUILD_REACH - 4)
	end
	return p
end

-- The local check (the server's is the one that counts): your turf, back from the line, in the field, in reach.
function BuildController.check(key, cx, cz, r)
	local def = Structures.get(key)
	local m = Store.get("match") or {}
	local team = Store.team()
	if not def or not team then
		return false, "No team"
	end
	if m.phase ~= "build" then
		return false, "Building is only in the build phase"
	end
	local w, d = Structures.footprint(def, r)
	local mn, mx = Formulas.footprintBox(cx, cz, w, d, 0, def.h)
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
	return true, nil, mn, mx
end

local function placeGhost()
	if not picked or Store.phase() ~= "build" then
		if ghost then
			ghost.Parent = nil
		end
		spot = nil
		return
	end
	local p = BuildController.aimPoint()
	if not p then
		return
	end
	local def = Structures.get(picked)
	local w, d = Structures.footprint(def, rot)
	local cx, cz = Formulas.cellOf(p.X - (w - 1) * Constants.CELL / 2, p.Z - (d - 1) * Constants.CELL / 2)
	local ok, why = BuildController.check(picked, cx, cz, rot)
	spot = { cx = cx, cz = cz, ok = ok, why = why }
	if not ghost then
		ghost = Instance.new("Part")
		ghost.Name = "BuildGhost"
		ghost.Anchored = true
		ghost.CanCollide = false
		ghost.CanQuery = false
		ghost.CastShadow = false
		ghost.Material = Enum.Material.SmoothPlastic
		ghost.Transparency = 0.5
	end
	local mn, mx = Formulas.footprintBox(cx, cz, w, d, 0, def.h)
	ghost.Size = mx - mn
	ghost.CFrame = CFrame.new((mn + mx) / 2)
	ghost.Color = ok and Color3.fromRGB(250, 250, 250) or Constants.TEAM_COLOR.red
	ghost.Transparency = ok and 0.45 or 0.6
	ghost.Parent = workspace
end

function BuildController.place()
	if not picked or not spot or Layout.panel() or Layout.modalOpen() then
		return false
	end
	if not spot.ok then
		Bus.Tap:Fire("build_refused")
		return false
	end
	Net.send("Build", picked, spot.cx, spot.cz, rot)
	Bus.Tap:Fire("build_" .. picked)
	return true
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
	ContextActionService:BindAction("TW_Place", function(_, state)
		if state == Enum.UserInputState.Begin and picked and Store.phase() == "build" and not Layout.panel() then
			BuildController.place()
			return Enum.ContextActionResult.Sink
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
	Bus.Rotate:Connect(BuildController.rotate)
	Store.Changed:Connect(function(partial)
		if partial.match and partial.match.phase ~= "build" and picked then
			BuildController.pick(nil)
		end
	end)
	RunService.RenderStepped:Connect(placeGhost)
end

return BuildController
