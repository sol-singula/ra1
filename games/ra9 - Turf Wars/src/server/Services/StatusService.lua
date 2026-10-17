--[[
What everyone sees on you (all cosmetic, none of it in the hit spheres CombatService uses):

  * a name tag over your head: your name, the title you wear (Data/Cosmetics), and VIP or ★ MVP; admins get a red
    ADMIN (the "Admin" attribute, AdminService), and an invisible admin (the "Invisible" attribute) no tag at all
  * the MVP crown: the last match's MVP wears it through the whole next match (white and black blocks over the head)
  * the VIP halo: a thin black ring, for VIPs (earned, never bought: Data/Achievements.VIP)

Built from the Player's attributes (ProgressService:Push sets LookTitle and VIP), on every new character.

  StatusService:Mvp()               the player wearing the crown
  StatusService:Refresh(player)
  StatusService:SetMvp(player)      the crown (the match's end; an admin can give it too)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)

local StatusService = {
	Name = "StatusService",
	Dependencies = { "PlayerDataService", "TeamService", "MatchService" },
}

local teams
local mvp -- the player wearing the crown

local INK = Color3.fromRGB(20, 20, 24)
local WHITE = Color3.fromRGB(250, 250, 250)

function StatusService:Mvp()
	return mvp
end

local function deco(parent, name, size, offset, color, shape)
	local head = parent:FindFirstChild("Head")
	if not head then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.CFrame = head.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = p
	weld.Parent = p
	p.Parent = parent
	return p
end

local function clear(character)
	for _, n in { "StatusTag", "MvpCrown", "VipHalo" } do
		local old = character:FindFirstChild(n)
		while old do
			old:Destroy()
			old = character:FindFirstChild(n)
		end
	end
end

function StatusService:Refresh(player)
	local c = player.Character
	if not c then
		return
	end
	clear(c)
	local head = c:FindFirstChild("Head")
	if not head or player:GetAttribute("Invisible") == true then
		return -- (an invisible admin wears nothing at all)
	end
	local isMvp = mvp == player
	local isVip = player:GetAttribute("VIP") == true
	local title = Cosmetics.get(player:GetAttribute("LookTitle"))
	local team = teams:Team(player)
	-- the tag
	local tag = Instance.new("BillboardGui")
	tag.Name = "StatusTag"
	tag.Size = UDim2.fromOffset(200, 54)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 90
	tag.AlwaysOnTop = false
	tag.Adornee = head
	local function line(text, y, h, color, font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, h)
		l.Position = UDim2.fromOffset(0, y)
		l.Text = text
		l.TextScaled = true
		l.Font = font or Enum.Font.GothamBold
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.4
		l.TextStrokeColor3 = WHITE
		l.Parent = tag
		return l
	end
	local isAdmin = player:GetAttribute("Admin") == true
	local parts = {}
	if isAdmin then
		table.insert(parts, "ADMIN")
	end
	if isMvp then
		table.insert(parts, "★ MVP")
	end
	if isVip then
		table.insert(parts, "VIP")
	end
	if #parts > 0 then
		line(table.concat(parts, "  ·  "), 0, 16, isAdmin and Constants.TEAM_COLOR.red or INK, Enum.Font.GothamBlack)
	end
	line(player.DisplayName, 16, 22, Constants.TEAM_COLOR[team or ""] or INK, Enum.Font.GothamBlack)
	if title and title.kind == "title" then
		line(string.upper(title.name), 38, 16, INK)
	end
	tag.Parent = c
	-- the crown: a ring of blocks, white and black
	if isMvp then
		for i = 0, 5 do
			local a = math.rad(i * 60)
			deco(
				c,
				"MvpCrown",
				Vector3.new(0.35, i % 2 == 0 and 0.7 or 0.45, 0.35),
				CFrame.new(math.cos(a) * 0.7, 1.05, math.sin(a) * 0.7),
				i % 2 == 0 and WHITE or INK
			)
		end
	end
	-- the halo
	if isVip then
		deco(
			c,
			"VipHalo",
			Vector3.new(0.12, 1.9, 1.9),
			CFrame.new(0, 1.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
			INK,
			Enum.PartType.Cylinder
		)
	end
end

function StatusService:SetMvp(player)
	local old = mvp
	mvp = player
	if old and old.Parent then
		self:Refresh(old)
	end
	if player and player.Parent then
		self:Refresh(player)
	end
end

local function watch(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			StatusService:Refresh(player)
		end)
	end)
	for _, attr in { "VIP", "LookTitle", "Admin", "Invisible" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			StatusService:Refresh(player)
		end)
	end
end

function StatusService:Init(registry)
	teams = registry.TeamService
	registry.MatchService.Ended:Connect(function(_, results)
		self:SetMvp(results and results.mvpPlayer or nil)
	end)
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		if mvp == p then
			mvp = nil
		end
	end)
end

return StatusService
