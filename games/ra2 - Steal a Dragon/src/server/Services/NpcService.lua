-- Raiders: when the server is quiet, goblin NPCs come out of the exit tunnel so there's always someone around.
-- They're clearly NPCs (goblins with a "RAIDER" tag, not in the player list). They stroll the road eyeing the
-- dragons, and every so often one sneaks into an open base (never a locked one, a player still in the tutorial,
-- or someone with fewer than 2 dragons), grabs a dragon and runs for the tunnel, slower than a player.
--   Bonk it: it drops the dragon (anyone can grab it, like a bonked player's) and the bonker gets the bounty.
--   Let it go: it vanishes into the tunnel and the dragon flies home, having earned nothing while it was away.
-- More players -> fewer raiders (Constants.NPC_FILL_TO); none at all in an empty server.
-- They move on the server, all parts anchored, 20 steps a second.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dragons = require(ReplicatedStorage.Shared.Data.Dragons)
local Format = require(ReplicatedStorage.Shared.Format)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local NpcService = {
	Name = "NpcService",
	Dependencies = { "PlayerDataService", "EconomyService", "BaseService", "DragonService", "CombatService" },
	Raided = Signal.new("NpcService.Raided"), -- (npc, owner, rec)
	Escaped = Signal.new("NpcService.Escaped"), -- (npc, owner, rec)
	active = not RunService:IsStudio() or Constants.NPC_IN_STUDIO, -- (tests switch this off and on)
	npcs = {},
}

local data, economy, baseService, dragons
local folder
local lastRaided = {} -- [player] = os.clock()
local nextNameIndex = 0
local STEP = 0.05
local TUNNEL_X = Constants.ROAD_END_X + 14
local LINES = {
	stroll = { "Ooh, shiny dragons...", "Hehehe.", "Nice castle you got there.", "Who left this door open?" },
	raid = { "Mine now! 😈", "Yoink!", "Hehehe, so shiny!" },
	flee = { "Can't catch me!", "Too slow!", "Bye bye!" },
	hit = { "OUCH! 😵", "Hey!!", "No fair!" },
	locked = { "Locked?! 😠", "Rats, locked." },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function pick(list)
	return list[math.random(1, #list)]
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Body parts as offsets from the feet: { name, size, offset, color, material?, swing? }
local function bodyPlan(skin)
	local cloth = rgb(110, 75, 50)
	return {
		{ "LegL", Vector3.new(0.7, 1.4, 0.7), CFrame.new(-0.45, 0.7, 0), rgb(70, 55, 45), nil, 1 },
		{ "LegR", Vector3.new(0.7, 1.4, 0.7), CFrame.new(0.45, 0.7, 0), rgb(70, 55, 45), nil, -1 },
		{ "Torso", Vector3.new(1.8, 1.6, 1.1), CFrame.new(0, 2.2, 0), cloth },
		{ "Belt", Vector3.new(1.85, 0.25, 1.15), CFrame.new(0, 1.6, 0), rgb(40, 30, 25) },
		{ "ArmL", Vector3.new(0.55, 1.5, 0.55), CFrame.new(-1.2, 2.1, 0), skin, nil, -1 },
		{ "ArmR", Vector3.new(0.55, 1.5, 0.55), CFrame.new(1.2, 2.1, 0), skin, nil, 1 },
		{ "Head", Vector3.new(1.5, 1.3, 1.3), CFrame.new(0, 3.7, 0), skin },
		{ "Nose", Vector3.new(0.35, 0.45, 0.5), CFrame.new(0, 3.6, -0.75), skin },
		{ "EarL", Vector3.new(1.1, 0.3, 0.5), CFrame.new(-1.15, 3.9, 0) * CFrame.Angles(0, 0, math.rad(25)), skin },
		{ "EarR", Vector3.new(1.1, 0.3, 0.5), CFrame.new(1.15, 3.9, 0) * CFrame.Angles(0, 0, math.rad(-25)), skin },
		{ "EyeL", Vector3.new(0.3, 0.3, 0.1), CFrame.new(-0.35, 3.85, -0.66), rgb(255, 230, 60), Enum.Material.Neon },
		{ "EyeR", Vector3.new(0.3, 0.3, 0.1), CFrame.new(0.35, 3.85, -0.66), rgb(255, 230, 60), Enum.Material.Neon },
		{ "Hood", Vector3.new(1.6, 0.5, 1.4), CFrame.new(0, 4.45, 0.05), rgb(60, 45, 70), Enum.Material.Fabric },
		{ "Sack", Vector3.new(1.3, 1.3, 0.8), CFrame.new(0, 2.4, 0.95), rgb(165, 130, 85), Enum.Material.Fabric },
	}
end

local function buildModel(name, skin)
	local model = Instance.new("Model")
	model.Name = "Raider_" .. name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root
	local parts = {}
	for _, p in bodyPlan(skin) do
		local part = Instance.new("Part")
		part.Name = p[1]
		part.Size = p[2]
		part.Color = p[4]
		part.Material = p[5] or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Parent = model
		table.insert(parts, { part = part, offset = p[3], swing = p[6] })
	end
	-- name tag: clearly an NPC
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.new(7, 0, 2.2, 0)
	gui.StudsOffset = Vector3.new(0, 3.6, 0)
	gui.MaxDistance = 120
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Parent = root
	for i, n in { "Line1", "Line2", "Say" } do
		local t = Instance.new("TextLabel")
		t.Name = n
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, i == 3 and 0.4 or 0.3, 0)
		t.Position = UDim2.new(0, 0, i == 3 and 0 or 0.4 + (i - 1) * 0.3, 0)
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.TextStrokeTransparency = 0
		t.TextColor3 = i == 3 and rgb(255, 255, 255) or rgb(170, 255, 140)
		t.Text = ""
		t.Parent = gui
	end
	gui.Line1.Text = "👺 " .. name
	gui.Line2.Text = "RAIDER"
	gui.Line2.TextColor3 = rgb(200, 200, 210)
	return model, parts
end

local function say(npc, text)
	local tag = npc.model.PrimaryPart:FindFirstChild("Tag")
	if tag then
		tag.Say.Text = "💬 " .. text
		npc.sayUntil = os.clock() + 3
	end
end

local function laneZ()
	return (math.random() < 0.5 and -1 or 1) * (2 + math.random() * 3)
end

-- What bonking this raider pays right now.
function NpcService:Bounty(npc)
	local c = npc.carrying
	if not c then
		return 0
	end
	return math.max(
		Constants.BOUNTY_MIN,
		math.floor(Formulas.dragonIncome(c.rec, os.time()) * Constants.BOUNTY_SECONDS)
	)
end

local function setThief(npc, on)
	local tag = npc.model.PrimaryPart:FindFirstChild("Tag")
	if tag then
		tag.Line2.Text = on and `😈 THIEF · 💰{Format.num(NpcService:Bounty(npc))}` or "RAIDER"
		tag.Line2.TextColor3 = on and rgb(255, 90, 90) or rgb(200, 200, 210)
	end
	local glow = npc.model:FindFirstChild("ThiefGlow")
	if on and not glow then
		glow = Instance.new("Highlight")
		glow.Name = "ThiefGlow"
		glow.FillTransparency = 1
		glow.OutlineColor = rgb(255, 70, 70)
		glow.Parent = npc.model
	elseif not on and glow then
		glow:Destroy()
	end
end

-- Draw a raider where it stands: walk cycle (legs and arms swing) and a little bob.
local function pose(npc)
	local cf = CFrame.lookAt(npc.pos, npc.pos + npc.facing)
	local moving = npc.moving
	local swing = moving and math.sin(npc.phase) * 0.7 or 0
	local bob = moving and math.abs(math.sin(npc.phase)) * 0.15 or 0
	if npc.state == "stunned" then
		cf = cf * CFrame.Angles(math.rad(-25), 0, 0)
	end
	npc.model.PrimaryPart.CFrame = cf * CFrame.new(0, 2.2 + bob, 0)
	for _, p in npc.parts do
		local o = p.offset
		if p.swing then
			-- swing around the top of the limb
			local hip = CFrame.new(o.X, o.Y + p.part.Size.Y / 2, o.Z)
			o = hip * CFrame.Angles(swing * p.swing, 0, 0) * CFrame.new(0, -p.part.Size.Y / 2, 0)
		end
		p.part.CFrame = cf * CFrame.new(0, bob, 0) * o
	end
	if npc.carrying and npc.carrying.model then
		npc.carrying.model:PivotTo(cf * CFrame.new(0, 5.2 + bob, 0.3))
	end
end

function NpcService:Spawn()
	nextNameIndex += 1
	local name = Constants.NPC_NAMES[(nextNameIndex - 1) % #Constants.NPC_NAMES + 1]
	local skin = Constants.NPC_COLORS[(nextNameIndex - 1) % #Constants.NPC_COLORS + 1]
	local model, parts = buildModel(name, skin)
	local npc = {
		name = name,
		model = model,
		parts = parts,
		pos = Vector3.new(TUNNEL_X, 0.5, laneZ()),
		facing = Vector3.new(-1, 0, 0),
		path = {},
		state = "stroll",
		phase = 0,
		moving = false,
		waitUntil = 0,
		stunUntil = 0,
		knock = Vector3.zero,
		nextRaidAt = os.clock() + math.random(Constants.NPC_RAID_EVERY[1], Constants.NPC_RAID_EVERY[2]) * 0.5,
		sayUntil = 0,
	}
	pose(npc)
	model.Parent = folder
	table.insert(self.npcs, npc)
	return npc
end

local function despawn(npc)
	local i = table.find(NpcService.npcs, npc)
	if i then
		table.remove(NpcService.npcs, i)
	end
	npc.model:Destroy()
end

-- Bases are walked through like a player would: in at the gate, down the middle aisle, then across to the
-- front of a nest (never through walls or stands). Points are in the base's own space (x across, z from the gate
-- at -34 to the back wall at +30).
local ENTRY_Z, GATE_Z = -26, -34
local function basePoint(base, x, z)
	local p = base.world.cf:PointToWorldSpace(Vector3.new(x, 0, z))
	return Vector3.new(p.X, 0.5, p.Z)
end

-- The way out of the base the raider is standing in (empty when it's not in one).
local function exitPath(npc)
	local base = baseService:BaseAt(npc.pos)
	if not base then
		return {}
	end
	local p = base.world.cf:PointToObjectSpace(npc.pos)
	local path = {}
	if math.abs(p.X) > 2 then
		table.insert(path, basePoint(base, 0, math.clamp(p.Z, ENTRY_Z, 17)))
	end
	table.insert(path, basePoint(base, 0, ENTRY_Z))
	table.insert(path, basePoint(base, 0, GATE_Z))
	return path
end

-- From the gate to the floor in front of a nest.
local function nestPath(base, slot)
	local f = base.world.cf:PointToObjectSpace(base.world.nests[slot].feet.Position)
	local aisleZ, front
	if math.abs(f.X) > 11 then
		aisleZ, front = f.Z, Vector3.new(math.sign(f.X) * 9.5, 0, f.Z) -- a side row
	else
		aisleZ, front = 15, Vector3.new(f.X, 0, 16.8) -- the trophy stand at the back
	end
	return {
		basePoint(base, 0, ENTRY_Z),
		basePoint(base, 0, aisleZ),
		basePoint(base, front.X, front.Z),
	}
end

-- Walk via the road: out of any base by its gate, off the lawn onto the road, along it, then to the target.
local function routeTo(npc, target)
	local lane = laneZ()
	local path = exitPath(npc)
	local from = path[#path] or npc.pos
	if math.abs(from.Z) > 10 then
		table.insert(path, Vector3.new(from.X, 0.5, from.Z * 0.5))
		table.insert(path, Vector3.new(from.X, 0.5, lane))
	end
	if math.abs(target.Z) > 10 then
		table.insert(path, Vector3.new(target.X, 0.5, lane))
		table.insert(path, Vector3.new(target.X, 0.5, target.Z * 0.5))
	end
	table.insert(path, target)
	npc.path = path
end

local function canRaid(player)
	local profile = data:Get(player)
	local base = baseService:Get(player)
	if not profile or not base or not profile.tutorialDone or baseService:IsLocked(base) then
		return false
	end
	if (lastRaided[player] or -999) > os.clock() - Constants.NPC_VICTIM_COOLDOWN then
		return false
	end
	for _, npc in NpcService.npcs do
		if npc.victim == player then
			return false
		end
	end
	local n = 0
	for _, rec in profile.dragons do
		if rec.slot then
			n += 1
		end
	end
	return n >= 2
end

-- Send a raider after a player's base (tests call this directly).
function NpcService:Raid(npc, victim)
	local profile = data:Get(victim)
	local base = baseService:Get(victim)
	if not profile or not base or npc.carrying then
		return false
	end
	local slotted = {}
	for _, rec in profile.dragons do
		if rec.slot then
			table.insert(slotted, rec)
		end
	end
	local rec = #slotted > 0 and slotted[math.random(1, #slotted)]
	if not rec then
		return false
	end
	lastRaided[victim] = os.clock()
	npc.victim, npc.targetRec, npc.state = victim, rec, "raid"
	npc.gate = base.world.gateCf.Position
	routeTo(npc, npc.gate)
	return true
end

local function flee(npc)
	npc.state = "flee"
	npc.victim = npc.carrying and npc.carrying.owner or nil
	routeTo(npc, Vector3.new(TUNNEL_X, 0.5, laneZ()))
	if npc.carrying then
		say(npc, pick(LINES.flee))
	end
end

local function stroll(npc)
	npc.state = "stroll"
	npc.victim, npc.targetRec = nil, nil
	local x = Constants.ROAD_START_X + 12 + math.random() * (Constants.ROAD_END_X - Constants.ROAD_START_X - 16)
	routeTo(npc, Vector3.new(x, 0.5, laneZ()))
end

-- The raider reached its nest: take the dragon (if it's still there and the base is still open).
function NpcService:_grab(npc)
	local owner, rec = npc.victim, npc.targetRec
	local base = owner and baseService:Get(owner)
	if not base or baseService:IsLocked(base) or not rec.slot then
		say(npc, pick(LINES.locked))
		stroll(npc)
		return
	end
	local model = dragons:LiftForNpc(owner, rec)
	if not model then
		stroll(npc)
		return
	end
	model.Parent = npc.model
	npc.carrying = { rec = rec, owner = owner, model = model }
	setThief(npc, true)
	local d = Dragons.byId[rec.id]
	Net.fire(
		owner,
		"Alert",
		`🚨 Raider {npc.name} is stealing your {d and d.name or "dragon"}! BONK it!`,
		rgb(255, 80, 80),
		npc.model
	)
	Net.fire(owner, "Sfx", "alarm")
	Net.fireAll("Popup", npc.pos + Vector3.new(0, 7, 0), "😈 STOP THE THIEF!", rgb(255, 90, 90))
	say(npc, pick(LINES.raid))
	self.Raided:Fire(npc, owner, rec)
	-- back out through the gate, then run for the tunnel along the road
	npc.state = "flee"
	routeTo(npc, Vector3.new(TUNNEL_X, 0.5, laneZ()))
end

-- Reached the tunnel: vanish (a carried dragon flies home).
function NpcService:_escape(npc)
	local c = npc.carrying
	if c then
		npc.carrying = nil
		c.model:Destroy()
		dragons:ReturnHome(c.rec, c.owner)
		if c.owner and c.owner.Parent then
			local d = Dragons.byId[c.rec.id]
			Net.fire(
				c.owner,
				"Toast",
				`😤 {npc.name} got away! Your {d and d.name or "dragon"} flew home, but earned nothing while it was gone.`,
				"bad"
			)
		end
		self.Escaped:Fire(npc, c.owner, c.rec)
	end
	despawn(npc)
end

-- Hit by a bonk (CombatService calls this through npcTargets).
function NpcService:_bonked(npc, attacker, seconds, push)
	npc.state = "stunned"
	npc.stunUntil = os.clock() + seconds
	npc.knock = flat(push) * 0.35
	say(npc, pick(LINES.hit))
	local c = npc.carrying
	if not c then
		return
	end
	local bounty = self:Bounty(npc)
	npc.carrying = nil
	c.model:Destroy()
	setThief(npc, false)
	dragons:DropAt(c.rec, c.owner, npc.pos)
	economy:Add(attacker, bounty)
	local profile = data:Get(attacker)
	if profile then
		profile.stats.bonks += 1
	end
	Net.fireAll(
		"Announce",
		`🔨 {attacker.DisplayName} stopped raider {npc.name}! +{Format.num(bounty)} bounty`,
		rgb(255, 205, 60)
	)
	if c.owner and c.owner.Parent and c.owner ~= attacker then
		Net.fire(c.owner, "Toast", `{attacker.DisplayName} bonked the raider! Grab your dragon! 🐉`, "good")
	end
end

function NpcService:_step(dt)
	local t = os.clock()
	for _, npc in table.clone(self.npcs) do
		npc.moving = false
		if npc.sayUntil > 0 and t > npc.sayUntil then
			npc.sayUntil = 0
			local tag = npc.model.PrimaryPart:FindFirstChild("Tag")
			if tag then
				tag.Say.Text = ""
			end
		end
		-- a base that locks while a raider is inside throws it out, like a player (unless it already has a dragon)
		local inBase = baseService:BaseAt(npc.pos)
		if inBase and not npc.carrying and baseService:IsLocked(inBase) and npc.state ~= "stunned" then
			npc.pos = basePoint(inBase, 0, GATE_Z - 3)
			say(npc, pick(LINES.locked))
			stroll(npc)
		end
		if npc.state == "stunned" then
			-- knocked back, but never through a base wall
			local pushed = npc.pos + npc.knock * dt
			if baseService:BaseAt(pushed) == inBase then
				npc.pos = pushed
			end
			npc.knock *= math.max(0, 1 - dt * 6)
			if t >= npc.stunUntil then
				-- shaken: head home (raiders who lost their dragon give up)
				flee(npc)
			end
		elseif npc.state == "grabbing" then
			if t >= npc.waitUntil then
				self:_grab(npc)
			end
		elseif t >= npc.waitUntil then
			local target = npc.path[1]
			if target then
				local delta = target - npc.pos
				local speed = npc.carrying and Constants.NPC_CARRY_SPEED or Constants.NPC_SPEED
				local stepLen = speed * dt
				if delta.Magnitude <= stepLen then
					npc.pos = target
					table.remove(npc.path, 1)
				else
					if flat(delta).Magnitude > 0.05 then
						npc.facing = flat(delta).Unit
					end
					npc.pos += delta.Unit * stepLen
					npc.moving = true
					npc.phase += dt * speed * 0.9
				end
			else
				-- arrived
				if npc.state == "raid" then
					-- at the gate: in if it's still open and the dragon still there
					local base = npc.victim and baseService:Get(npc.victim)
					local rec = npc.targetRec
					if not base or not rec or baseService:IsLocked(base) or not rec.slot then
						say(npc, pick(LINES.locked))
						stroll(npc)
					else
						npc.path = nestPath(base, rec.slot)
						npc.state = "toNest"
					end
				elseif npc.state == "toNest" then
					npc.state = "grabbing"
					npc.waitUntil = t + Constants.NPC_STEAL_SECONDS
				elseif npc.state == "flee" or npc.state == "leave" then
					self:_escape(npc)
				else
					-- strolling: look around a bit, chat now and then, maybe raid
					npc.waitUntil = t + 1 + math.random() * 3
					if math.random() < 0.25 then
						say(npc, pick(LINES.stroll))
					end
					if t >= npc.nextRaidAt then
						npc.nextRaidAt = t + math.random(Constants.NPC_RAID_EVERY[1], Constants.NPC_RAID_EVERY[2])
						local victims = {}
						for _, p in Players:GetPlayers() do
							if canRaid(p) then
								table.insert(victims, p)
							end
						end
						if #victims == 0 or not self:Raid(npc, pick(victims)) then
							stroll(npc)
						end
					else
						stroll(npc)
					end
				end
			end
		end
		if npc.model.Parent then
			pose(npc)
		end
	end
end

-- How many raiders the server wants right now.
function NpcService:Wanted()
	local n = #Players:GetPlayers()
	if not self.active or n == 0 then
		return 0
	end
	return math.clamp(Constants.NPC_FILL_TO - n, 0, Constants.NPC_MAX)
end

-- Keep the raider count right: spawn from the tunnel, or send extras home.
function NpcService:_balance()
	local wanted = self:Wanted()
	local staying = {}
	for _, npc in self.npcs do
		if npc.state ~= "leave" then
			table.insert(staying, npc)
		end
	end
	if #staying < wanted then
		self:Spawn()
	elseif #staying > wanted then
		for i = #staying, wanted + 1, -1 do
			local npc = staying[i]
			if not npc.carrying then
				npc.state = "leave"
				npc.victim, npc.targetRec = nil, nil
				routeTo(npc, Vector3.new(TUNNEL_X, 0.5, laneZ()))
			end
		end
	end
end

function NpcService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	baseService = registry.BaseService
	dragons = registry.DragonService
	folder = Instance.new("Folder")
	folder.Name = "Raiders"
	folder.Parent = workspace
	table.insert(registry.CombatService.npcTargets, function()
		local list = {}
		for _, npc in self.npcs do
			if npc.state ~= "stunned" then
				table.insert(list, {
					position = npc.pos + Vector3.new(0, 2.5, 0),
					carrying = npc.carrying ~= nil,
					model = npc.model,
					bonk = function(attacker, seconds, push)
						self:_bonked(npc, attacker, seconds, push)
					end,
				})
			end
		end
		return list
	end)
end

function NpcService:OnPlayerLeaving(player)
	lastRaided[player] = nil
	for _, npc in self.npcs do
		if npc.carrying and npc.carrying.owner == player then
			-- their dragon stays in their save, back in their base next time
			npc.carrying.model:Destroy()
			dragons:ReleaseNpc(npc.carrying.rec)
			npc.carrying = nil
			setThief(npc, false)
		end
		if npc.victim == player then
			npc.victim, npc.targetRec = nil, nil
			if npc.state ~= "leave" then
				flee(npc)
			end
		end
	end
end

function NpcService:Start()
	local acc, balanceAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		balanceAcc += dt
		if acc >= STEP then
			local step = math.min(acc, 0.25)
			acc = 0
			self:_step(step)
		end
		if balanceAcc >= 4 then
			balanceAcc = 0
			self:_balance()
		end
	end)
end

return NpcService
