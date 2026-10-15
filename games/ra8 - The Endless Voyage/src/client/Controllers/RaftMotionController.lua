--[[
The raft rides the water (master plan §1: a raft you can feel floating). On this client every raft bobs and rolls
a little with the swell, a lot more in a storm, and pitches forward while it sails. The server's pieces never
move; this moves their parts locally every frame (BulkMoveTo) from base CFrames cached per raft and rebuilt as
pieces come and go, so nothing crosses the network and the characters standing on the deck ride along.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local OceanLayout = require(ReplicatedStorage.Shared.World.OceanLayout)
local Store = require(script.Parent.Parent.Store)

local RaftMotionController = { Name = "RaftMotionController", Order = 36 }

local player = Players.LocalPlayer
local rafts = {} -- [folder] = { parts, bases, known, center, phase, scanAt, applied }
local FAR = 260
local frame = 0

local function recordOf(folder)
	local rec = rafts[folder]
	if rec then
		return rec
	end
	local plot = tonumber(string.match(folder.Name, "Raft(%d+)")) or folder:GetAttribute("Plot")
	local layout = plot and OceanLayout.plot(plot)
	rec = {
		parts = {},
		bases = {},
		known = {},
		center = layout and layout.center + Vector3.new(0, Constants.DECK_Y, 0) or Vector3.zero,
		phase = (plot or 0) * 1.7,
		scanAt = 0,
		applied = CFrame.new(),
		plot = plot,
	}
	rafts[folder] = rec
	folder.ChildAdded:Connect(function()
		rec.scanAt = 0
	end)
	folder.ChildRemoved:Connect(function()
		rec.scanAt = 0
	end)
	return rec
end

-- Every part of the raft, with where the server put it (a part we moved already is unmoved by the last offset;
-- a new one is where the server built it).
local function scan(rec, folder)
	local parts, bases, known = {}, {}, {}
	local inverse = rec.applied:Inverse()
	for _, d in folder:GetDescendants() do
		if d:IsA("BasePart") then
			local base = rec.known[d]
			if base == nil then
				base = d.CFrame
			else
				base = inverse * d.CFrame
			end
			table.insert(parts, d)
			table.insert(bases, base)
			known[d] = true
		end
	end
	rec.parts, rec.bases, rec.known = parts, bases, known
	-- (the known set holds the parts we move; their base is recovered from the applied offset next time)
	for i, part in parts do
		rec.known[part] = true
		rec.bases[i] = bases[i]
	end
	rec.scanAt = os.clock() + 2
end

local function move(parts, cframes)
	if #parts == 0 then
		return
	end
	local ok = pcall(function()
		workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	if not ok then
		for i, part in parts do
			part.CFrame = cframes[i]
		end
	end
end

local function step()
	frame += 1
	local folder = workspace:FindFirstChild("Rafts")
	if not folder then
		return
	end
	local t = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame and cam.CFrame.Position or Vector3.zero
	local me = Store.get("me") or {}
	local myPlot = me.plot
	local storm = Store.storm()
	local voyage = Store.voyageState()
	for _, raft in folder:GetChildren() do
		local rec = recordOf(raft)
		if t >= rec.scanAt then
			scan(rec, raft)
		end
		local far = (rec.center - camPos).Magnitude > FAR
		if far and frame % 4 ~= 0 then
			continue
		end
		-- the swell: slow and small; a storm on this plot triples it; sailing adds a forward lean
		local mine = rec.plot == myPlot
		local amp = (mine and storm) and 0.5 or 0.16
		local roll = (mine and storm) and 2.2 or 0.7
		local pitchLean = (mine and (voyage == "sailing" or voyage == "home")) and -1.4 or 0
		local ph = rec.phase
		local bob = math.sin(t * 0.9 + ph) * amp + math.sin(t * 1.7 + ph * 2) * amp * 0.3
		local rollA = math.rad(math.sin(t * 0.7 + ph) * roll)
		local pitchA = math.rad(math.cos(t * 0.8 + ph) * roll * 0.6 + pitchLean)
		local c = rec.center
		local offset = CFrame.new(c) * CFrame.new(0, bob, 0) * CFrame.Angles(pitchA, 0, rollA) * CFrame.new(-c)
		rec.applied = offset
		local cframes = table.create(#rec.parts)
		for i, base in rec.bases do
			cframes[i] = offset * base
		end
		move(rec.parts, cframes)
	end
	for raft in rafts do
		if not raft.Parent then
			rafts[raft] = nil
		end
	end
end

function RaftMotionController:init()
	RunService.RenderStepped:Connect(step)
end

-- (tests)
RaftMotionController.step = step
RaftMotionController.rafts = rafts
_ = player

return RaftMotionController
