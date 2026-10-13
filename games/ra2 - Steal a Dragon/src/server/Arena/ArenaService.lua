-- The Bonk Arena: everyone bonks everyone with the weapon they own in the main game (Bonk Bat .. Inferno Blade).
-- One bonk knocks you out: you fly back, then respawn on a pad around the edge after ARENA_RESPAWN_SECONDS, with a
-- short shield so nobody bonks you the moment you land. No wings, no dragons. KOs show in the player list and on
-- the TOP BONKERS board (this server), and are added to your profile (stats.arenaKOs). A portal goes back to the
-- main game. In a reserved arena server (no arena place yet) the player count is kept in the ARENA_MAP map so
-- lobby portals fill it up.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local ToolService = require(script.Parent.Parent.Services.ToolService)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)

local ArenaService = {}

local data
local kos = {} -- [player] = KOs this visit
local streaks = {} -- [player] = KOs in a row without being bonked
local lastSwing = {}
local downUntil = {} -- [player] = knocked out until (os.clock)
local safeUntil = {} -- [player] = spawn shield until
local leaving = {}

local function weaponOf(player)
	local profile = data:Get(player)
	return Constants.WEAPONS[math.clamp(profile and profile.weaponLevel or 1, 1, #Constants.WEAPONS)],
		profile and profile.weaponLevel or 1
end

local function rootOf(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function hasMega(player)
	local profile = data:Get(player)
	return profile ~= nil and profile.passes ~= nil and profile.passes.MEGABONK == true
end

-- A fresh character: a random spawn pad, the weapon in hand, and a short shield.
function ArenaService.spawned(player, character)
	local spawns = WorldBuilder.layout.arena.spawns
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if hrp then
		hrp.CFrame = spawns[math.random(1, #spawns)]
	end
	downUntil[player] = nil
	safeUntil[player] = os.clock() + Constants.ARENA_SPAWN_SAFE
	local shield = Instance.new("ForceField")
	shield.Name = "SpawnShield"
	shield.Parent = character
	task.delay(Constants.ARENA_SPAWN_SAFE, function()
		shield:Destroy()
	end)
	local _, level = weaponOf(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local tool = ToolService.makeWeapon(level, hasMega(player))
	tool.Activated:Connect(function()
		ArenaService.bonk(player)
	end)
	tool.Parent = backpack or character
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(hum.EquipTool, hum, tool)
	end
end

-- The best target: in front of you and in reach, not knocked out, not shielded.
function ArenaService.target(attacker, pos, range, look)
	local best, bestScore
	for _, other in Players:GetPlayers() do
		local hrp = rootOf(other)
		if
			other ~= attacker
			and hrp
			and (downUntil[other] or 0) < os.clock()
			and (safeUntil[other] or 0) < os.clock()
		then
			local d = hrp.Position - pos
			local dist = d.Magnitude
			local flat = Vector3.new(d.X, 0, d.Z)
			local front = (look and flat.Magnitude > 0.1) and flat.Unit:Dot(look) or 1
			if dist <= range and (front > -0.15 or dist <= Constants.BONK_BEHIND_OK) then
				local score = dist - front * 2.5
				if not best or score < bestScore then
					best, bestScore = other, score
				end
			end
		end
	end
	return best
end

function ArenaService.bonk(attacker)
	local now = os.clock()
	if (lastSwing[attacker] or -99) > now - Constants.ARENA_BONK_COOLDOWN or (downUntil[attacker] or 0) > now then
		return false
	end
	local hrp = rootOf(attacker)
	if not hrp then
		return false
	end
	lastSwing[attacker] = now
	for _, other in Players:GetPlayers() do
		if other ~= attacker then
			Net.fire(other, "Swing", attacker)
			Net.fire(other, "Sfx", "swing", hrp.Position)
		end
	end
	local weapon = weaponOf(attacker)
	local look = hrp.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	look = look.Magnitude > 0.1 and look.Unit or nil
	-- a little more reach than in the main game: it's all about fighting here
	local victim = ArenaService.target(attacker, hrp.Position, weapon.range + 1.5, look)
	if not victim then
		return false
	end
	ArenaService.knockOut(victim, attacker, weapon)
	return true
end

function ArenaService.knockOut(victim, attacker, weapon)
	downUntil[victim] = os.clock() + Constants.ARENA_RESPAWN_SECONDS + 1
	streaks[victim] = 0
	local vh = rootOf(victim)
	local ah = rootOf(attacker)
	if vh and ah then
		local push = vh.Position - ah.Position
		push = Vector3.new(push.X, 0, push.Z)
		push = push.Magnitude > 0.1 and push.Unit or Vector3.new(0, 0, 1)
		vh.AssemblyLinearVelocity = push * (weapon.knock * 1.3) + Vector3.new(0, 45, 0)
		local hum = victim.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.PlatformStand = true -- flop like a ragdoll while flying back
		end
	end
	Net.fireAll(
		"Popup",
		(vh and vh.Position or Vector3.zero) + Vector3.new(0, 5, 0),
		"BONK!",
		Color3.fromRGB(255, 220, 60)
	)
	Net.fireAll("Sfx", "bonk", vh and vh.Position)
	Net.fire(victim, "ArenaKO", { by = attacker.DisplayName, respawn = Constants.ARENA_RESPAWN_SECONDS })
	-- the score
	kos[attacker] = (kos[attacker] or 0) + 1
	streaks[attacker] = (streaks[attacker] or 0) + 1
	local stats = attacker:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("KOs") then
		stats.KOs.Value = kos[attacker]
	end
	local profile = data:Get(attacker)
	if profile then
		profile.stats.arenaKOs = (profile.stats.arenaKOs or 0) + 1
	end
	if Constants.STREAK_ANNOUNCE[streaks[attacker]] then
		Net.fireAll(
			"Announce",
			`🔥 {attacker.DisplayName} is on a {streaks[attacker]}-BONK STREAK!`,
			Color3.fromRGB(255, 120, 40)
		)
	end
	task.delay(Constants.ARENA_RESPAWN_SECONDS, function()
		if victim.Parent and not leaving[victim] then
			pcall(victim.LoadCharacter, victim)
		end
	end)
end

function ArenaService.join(player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local ko = Instance.new("IntValue")
	ko.Name = "KOs"
	ko.Value = 0
	ko.Parent = stats
	stats.Parent = player
	kos[player] = 0
	player.CharacterAdded:Connect(function(character)
		ArenaService.spawned(player, character)
	end)
	if player.Character then
		ArenaService.spawned(player, player.Character)
	end
	local w = weaponOf(player)
	Net.fire(player, "Toast", `⚔️ BONK ARENA! You fight with your {w.name}. Bonked = respawn.`, "good")
end

function ArenaService.leave(player)
	leaving[player] = true
	kos[player], streaks[player], lastSwing[player] = nil, nil, nil
	downUntil[player], safeUntil[player] = nil, nil
	task.defer(function()
		leaving[player] = nil
	end)
end

-- the TOP BONKERS board: this server's KOs
function ArenaService.redraw()
	local rows = {}
	for p, n in kos do
		if p.Parent then
			table.insert(rows, { name = p.DisplayName, value = n })
		end
	end
	table.sort(rows, function(a, b)
		return a.value > b.value
	end)
	local board = WorldBuilder.layout.arena.board
	board.sub.Text = "KOs in this arena"
	for i, row in board.rows do
		local r = rows[i]
		row.name.Text = r and r.name or ""
		row.value.Text = r and Format.commas(r.value) or ""
	end
end

local function reservedId()
	local ok, id = pcall(function()
		return game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 and game.PrivateServerId or nil
	end)
	return ok and id or nil
end

function ArenaService.init(registry)
	data = registry.PlayerDataService
	Net.on("Bonk", function(player)
		ArenaService.bonk(player)
	end)
	-- the portal back to the main game
	local back = WorldBuilder.layout.arena.backPortal
	local sent = {}
	pcall(function()
		back.Touched:Connect(function(hit)
			local player = hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
			if player and not sent[player] then
				sent[player] = true
				Net.fire(player, "Toast", "🏰 Back to the game...", "good")
				local ok = pcall(TeleportService.TeleportAsync, TeleportService, Constants.MAIN_PLACE_ID, { player })
				if not ok then
					sent[player] = nil
				end
			end
		end)
	end)
	task.spawn(function()
		local map
		pcall(function()
			map = MemoryStoreService:GetSortedMap(Constants.ARENA_MAP)
		end)
		while true do
			pcall(ArenaService.redraw)
			-- a reserved arena server keeps its player count in the map (lobby portals fill it up)
			local id = reservedId()
			if map and id then
				pcall(function()
					map:UpdateAsync(id, function(old)
						if not old then
							return nil
						end
						old.players = #Players:GetPlayers()
						return old
					end, 3600)
				end)
			end
			task.wait(RunService:IsStudio() and 2 or 5)
		end
	end)
end

function ArenaService.close()
	local id = reservedId()
	if id then
		pcall(function()
			MemoryStoreService:GetSortedMap(Constants.ARENA_MAP):RemoveAsync(id)
		end)
	end
end

-- (tests)
ArenaService.kos = kos
return ArenaService
