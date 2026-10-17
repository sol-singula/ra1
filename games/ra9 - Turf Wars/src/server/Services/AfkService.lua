--[[
The AFK limbo: nobody can stall a match by standing still. A player who doesn't move, shoot, swing or build for
AFK_SECONDS while a match is on is taken out of it (no team, not counted, never hit: Admins.spectating says so for
the "Limbo" attribute) and moved to a small white room floating high above the arena, with a banner: "You're AFK.
Walk around to jump back in!". The moment they walk AFK_RETURN_STUDS in there, they're back: a team the normal way
(MatchService:Join), a spawn, "Welcome back!". Bots fill in for them meanwhile (BotService counts people the same way).

  AfkService:Away(player)      -> bool
  AfkService:Send(player)      off to limbo now (tests, an admin)
  AfkService:Return(player)    back into the match now
  AfkService.ROOM              the limbo room's floor centre (a CFrame)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Notify = require(script.Parent.Parent.Notify)
local Admins = require(script.Parent.Parent.Admins)

local AfkService = {
	Name = "AfkService",
	Dependencies = { "MatchService", "TeamService", "CombatService", "BuildService" },
}

AfkService.ROOM = CFrame.new(0, 600, 0)

local match, teams, combat, build
local watch = {} -- [player] = { pos, at, limboAt }

local function now()
	return workspace:GetServerTimeNow()
end

local function root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function active(player)
	local w = watch[player]
	if w then
		w.at = now()
	end
end

-- The room: a floor, low walls, a soft light and the banner over it
local function buildRoom()
	local folder = Instance.new("Folder")
	folder.Name = "Limbo"
	local function block(size, offset, color, transparency)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = AfkService.ROOM * CFrame.new(offset)
		p.Color = color or Constants.WHITE
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = transparency or 0
		p.Parent = folder
		return p
	end
	local floor = block(Vector3.new(60, 1, 60), Vector3.new(0, -0.5, 0))
	floor.Name = "LimboFloor"
	for _, side in { -1, 1 } do
		block(Vector3.new(60, 6, 1), Vector3.new(0, 3, side * 30), Constants.LIGHT)
		block(Vector3.new(1, 6, 60), Vector3.new(side * 30, 3, 0), Constants.LIGHT)
	end
	-- a glowing ring on the floor: walk off it to go back
	local ring = block(Vector3.new(10, 0.1, 10), Vector3.new(0, 0.06, 0), Color3.fromRGB(120, 120, 130), 0.4)
	ring.Material = Enum.Material.Neon
	ring.CanCollide = false
	local sign = block(Vector3.new(30, 8, 0.5), Vector3.new(0, 10, -29), Constants.WHITE)
	sign.Name = "LimboSign"
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "YOU'RE AFK\nWALK AROUND TO JUMP BACK IN!"
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(30, 30, 34)
	label.Parent = gui
	folder.Parent = workspace
end

function AfkService:Away(player)
	return player:GetAttribute("Limbo") == true
end

function AfkService:Send(player)
	if self:Away(player) or not player.Parent then
		return false
	end
	player:SetAttribute("Limbo", true)
	teams:Clear(player)
	match:Leave(player)
	local r = root(player)
	if r then
		local spot = AfkService.ROOM * CFrame.new(0, 3, 0)
		local ok = pcall(function()
			player.Character:PivotTo(spot)
		end)
		if not ok or (r.Position - spot.Position).Magnitude > 5 then
			r.CFrame = spot
		end
		player:SetAttribute("AcGrace", os.clock() + 3) -- (the anti-cheat lets the jump up go; it reads os.clock)
	end
	local w = watch[player] or {}
	watch[player] = w
	w.limboAt = r and flat(AfkService.ROOM.Position) or nil
	w.at = now()
	Notify.to(player, "You're AFK. Walk around to jump back in!", "info", { icon = "💤", seconds = 5 })
	return true
end

function AfkService:Return(player)
	if not self:Away(player) then
		return false
	end
	player:SetAttribute("Limbo", nil)
	local w = watch[player]
	if w then
		w.limboAt, w.at, w.pos = nil, now(), nil
	end
	match:Join(player) -- (a team the normal way, and a spawn)
	Notify.to(player, "Welcome back!", "start", { icon = "⚔️", seconds = 2.5 })
	return true
end

function AfkService:_check()
	local phase = match:Phase()
	local on = Constants.AFK_SECONDS > 0 and (phase == "build" or phase == "fight")
	for _, player in Players:GetPlayers() do
		local w = watch[player]
		if not w then
			w = { at = now() }
			watch[player] = w
		end
		local r = root(player)
		if self:Away(player) then
			-- in limbo: walking around brings them back
			local from = w.limboAt or (r and flat(r.Position))
			w.limboAt = from
			if r and from and (flat(r.Position) - from).Magnitude >= Constants.AFK_RETURN_STUDS then
				self:Return(player)
			end
		elseif r then
			local p = flat(r.Position)
			if not w.pos or (p - w.pos).Magnitude > 2 then
				w.pos, w.at = p, now()
			end
			-- (a spectating admin is never sent; nor anyone while no match is on)
			if on and not Admins.spectating(player) and now() - w.at >= Constants.AFK_SECONDS then
				self:Send(player)
			end
		else
			w.at = math.max(w.at, now() - Constants.AFK_SECONDS / 2) -- (dead or loading isn't idling)
		end
	end
end

function AfkService:Init(registry)
	match = registry.MatchService
	teams = registry.TeamService
	combat = registry.CombatService
	build = registry.BuildService
end

function AfkService:Start()
	buildRoom()
	combat.Shot:Connect(active)
	build.Built:Connect(active)
	Players.PlayerRemoving:Connect(function(player)
		watch[player] = nil
	end)
	while true do
		task.wait(1)
		pcall(self._check, self)
	end
end

return AfkService
