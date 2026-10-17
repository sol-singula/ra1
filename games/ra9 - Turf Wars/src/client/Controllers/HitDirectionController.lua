--[[
Where it came from: an enemy arrow that just missed you (the server's Net "Threat", CombatService:_nearMiss) or that
hit you (Net "Hurt", the knockout too) puts a red marker on a ring round the middle of the screen, pointing toward
the shooter, for Constants.HIT_MARKER_SECONDS (fading out). It follows the camera as you turn, so turning toward it
brings it to the top. A hit's marker is bigger and solid; a near miss's lighter. One marker per shooter (a second
arrow from them only refreshes it), a few at most.

The ring sits clear of the screen's edges: on a phone a little further in (the thumbs' buttons hold the bottom
corners), and its own screen is drawn above the HUD so no button ever covers a marker.

  HitDirectionController.show(from, kind?, by?)   a marker toward the world position `from` ("hit" | "near")
  HitDirectionController.markers()                 the markers on screen now (tests)
  HitDirectionController.angleTo(from)             degrees round from straight ahead (0) clockwise, for `from`
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Device = require(script.Parent.Parent.UI.Device)

local HitDirectionController = { Name = "HitDirectionController", Order = 58 }

local player = Players.LocalPlayer
local RED = Color3.fromRGB(235, 40, 45)
local MAX_MARKERS = 4
-- the ring's half-width and half-height (shares of the screen): a mouse's near the edges, a thumb's further in
local RING = { touch = { 0.3, 0.33 }, other = { 0.42, 0.4 } }

local gui
local active = {} -- { { label, from, by, kind, born } }

local function screen()
	if gui and gui.Parent then
		return gui
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "HitDirection"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 8 -- (above the HUD and its touch buttons)
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function HitDirectionController.angleTo(from)
	local cam = workspace.CurrentCamera
	if not cam or typeof(from) ~= "Vector3" then
		return 0
	end
	local cf = cam.CFrame
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-look.Z, 0, look.X)
	local rel = from - cf.Position
	return math.deg(math.atan2(rel:Dot(right), rel:Dot(look)))
end

local function place(m)
	local a = math.rad(HitDirectionController.angleTo(m.from))
	local ring = Device.isTouch() and RING.touch or RING.other
	m.label.Position = UDim2.fromScale(0.5 + math.sin(a) * ring[1], 0.5 - math.cos(a) * ring[2])
	m.label.Rotation = math.deg(a)
end

local function newLabel()
	local l = Instance.new("TextLabel")
	l.Name = "Marker"
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.BackgroundTransparency = 1
	l.Text = "▲"
	l.Font = Enum.Font.GothamBlack
	l.TextScaled = true
	l.TextColor3 = RED
	l.TextStrokeColor3 = Color3.fromRGB(30, 30, 34)
	return l
end

function HitDirectionController.show(from, kind, by)
	if typeof(from) ~= "Vector3" then
		return nil
	end
	kind = kind == "hit" and "hit" or "near"
	local m
	for _, e in active do
		if by ~= nil and e.by == by then
			m = e -- (the same shooter again: the one marker, refreshed)
			break
		end
	end
	if not m then
		if #active >= MAX_MARKERS then
			local oldest = table.remove(active, 1)
			oldest.label:Destroy()
		end
		m = { label = newLabel(), by = by }
		m.label.Parent = screen()
		table.insert(active, m)
	end
	-- (a hit outranks a near miss from the same shooter)
	m.kind = (m.kind == "hit" and m.born and os.clock() - m.born < Constants.HIT_MARKER_SECONDS) and "hit" or kind
	m.from, m.born = from, os.clock()
	local size = (m.kind == "hit" and 54 or 40) * (Device.isPhone() and 1.25 or 1)
	m.label.Size = UDim2.fromOffset(size, size * 0.8)
	m.label.TextStrokeTransparency = m.kind == "hit" and 0.2 or 0.5
	m.label:SetAttribute("Kind", m.kind)
	place(m)
	return m.label
end

function HitDirectionController.markers()
	local out = {}
	for _, m in active do
		table.insert(out, m.label)
	end
	return out
end

-- each frame: follow the camera, fade, and go once their time is up
local function step()
	local t = os.clock()
	for i = #active, 1, -1 do
		local m = active[i]
		local age = t - m.born
		if age >= Constants.HIT_MARKER_SECONDS or not m.label.Parent then
			m.label:Destroy()
			table.remove(active, i)
		else
			place(m)
			local k = age / Constants.HIT_MARKER_SECONDS
			local base = m.kind == "hit" and 0.05 or 0.3
			m.label.TextTransparency = base + (1 - base) * k * k
		end
	end
end

function HitDirectionController:init()
	Net.listen("Threat", function(t)
		if type(t) == "table" then
			HitDirectionController.show(t.from, "near", t.by)
		end
	end)
	Net.listen("Hurt", function(h)
		-- (a hit, the knockout too; a blast's throw-back points at the blast)
		if type(h) == "table" then
			HitDirectionController.show(h.from, (h.amount or 0) > 0 and "hit" or "near", h.by)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(step)
		if not ok then
			warn("[HitDirectionController] " .. tostring(err))
		end
	end)
end

return HitDirectionController
