--[[
Duels (the lobby place only: Modes). Four pads on the plaza, 1v1 to 4v4 (Constants.DUEL_PADS). Step on a pad (or
tap its prompt) and you're in that size's queue ("1v1 · 1/2 ready" on your screen); your party comes with you onto
one side when it fits; step off (or tap CANCEL) to leave. When the queue fills two sides, a DUEL_COUNTDOWN counts
down and the duel starts.

Each duel plays in its own arena far out past the plaza (World/DuelArena: a different map each time, slot after slot
along Z, the slots reused when a duel is over), with two sides, red and blue (TeamService's looks). The rules: first
side to DUEL_ROUNDS round wins; a round ends when one side is all knocked out; DUEL_ROUND_WAIT later everyone is back
on their deck, with spawn protection, for the next; a DUEL_SECONDS cap (the side ahead on rounds wins; even is a
draw). Bow and blade only (no TNT, no building), no comeback shield, no new-player help. A knockout pays
DUEL_SHARDS.kill, the win DUEL_SHARDS.win (EconomyService, why "duel"); duelWins / duelLosses on the profile. Leaving
the server (or BACK TO LOBBY) mid-duel forfeits: a side left empty loses. The result card (VICTORY / DEFEAT, REMATCH /
BACK TO LOBBY) stays DUEL_RESULT_SECONDS, then the arena comes down and everyone is home by their pad (the lobby may
set DuelService.returnHome to put them where it likes). REMATCH puts you straight back in that pad's queue.

CombatService needs no match for any of this: here DuelService is its team provider (CombatService:SetTeams:
Team(player) is a duellist's side and nil for anyone on the plaza, so nobody on the plaza can hurt or be hurt and a
side can't hurt itself), each duel's arena is registered with ArenaService (its walls and cover stop arrows, its
decks are safe until you shoot), the CHARGE attribute stays on so the blade is always allowed, and the TNT is
refused.

Net "Duel" from the client: ("join", size) | ("cancel") | ("rematch") | ("leave"). To the client, Net "Duel":
  { kind = "queue", size, n, of, seconds? } | { kind = "queue", off = true }        the chip (seconds: counting down)
  { kind = "start", id, size, side, map, mapName, rounds, endsAt, sides = { red = { names }, blue = { names } } }
  { kind = "round", n, score } | { kind = "roundEnd", winner, score }                the banners
  { kind = "result", won, draw, winner, score, shards, map, rematch = { n, of } }
  { kind = "rematch", n, of } | { kind = "end" }
And the match's own events a duellist already knows: Kill (the feed, the kill cam, the killer's kill effect), Me,
Alert ("ROUND 3", "RED WINS THE ROUND"), Earned ("DUEL").

Attributes on a duellist: Duel (the duel's id), DuelSide and Team ("red" | "blue").

  DuelService:Join(player, size, via?) / :Leave(player)   the queue (size: a side's size, 1..4)
  DuelService:Queue(size) -> { players }                  DuelService:Of(player) -> the duel or nil
  DuelService:List() -> { duels }                          DuelService:Team(player) -> side (CombatService's view)
  DuelService:Forfeit(player)                             out of their duel, a loss
  DuelService:Rematch(player)                             after the result: back in the queue
  DuelService:SetParties(fn(player) -> { players } | nil)   who comes with them (PartyService, when it's here)
  DuelService.returnHome = fn(player, padIndex)           (the lobby: a body on the plaza after a duel)
  DuelService.Started(duel)  .Ended(duel, winner)  .Released(player)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local DuelArena = require(ReplicatedStorage.Shared.World.DuelArena)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Notify = require(script.Parent.Parent.Notify)

local DuelService = {
	Name = "DuelService",
	Modes = { "lobby" },
	Dependencies = { "PlayerDataService", "ArenaService", "CombatService", "EconomyService" },
	Started = Signal.new("DuelService.Started"), -- (duel)
	Ended = Signal.new("DuelService.Ended"), -- (duel, winner)
	Released = Signal.new("DuelService.Released"), -- (player) out of a duel, home on the plaza
	returnHome = nil, -- fn(player, padIndex): the lobby's own way of putting them back (else beside the pad)
}

local data, arenas, combat, economy, progress, teams, looks
local queues = {} -- [size] = { groups = { { by, members } }, countdownAt?, seated? }
local how = {} -- [player] = "pad" | "prompt" | "rematch" | "party": how they joined (a pad joiner leaves by stepping off)
local inDuel = {} -- [player] = duel
local duels = {} -- { duel }: { id, size, slot, arena, def, sides = { red, blue }, side = { [player] }, score, round,
-- phase = "round" | "wait" | "over", nextAt, endsAt, kills = { [player] = n }, rematch = { [player] = true } }
local slots = {} -- [slot] = duel
local pads = {} -- [i] = { size, pos, part }
local noBody = {} -- [player] = since when a duellist has been without a body (the watchdog)
local partiesFn -- fn(player) -> { players } | nil
local nextId = 0
local lastMap
local random = Random.new()

local function now()
	return workspace:GetServerTimeNow()
end

local function other(side)
	return side == "red" and "blue" or "red"
end

local function root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

local function queueOf(size)
	local q = queues[size]
	if not q then
		q = { groups = {} }
		queues[size] = q
	end
	return q
end

local function groupOf(player)
	for size, q in queues do
		for i, g in q.groups do
			if table.find(g.members, player) then
				return q, g, i, size
			end
		end
	end
	return nil
end

-- The duel's players, both sides
local function everyone(duel)
	local list = {}
	for _, side in Constants.TEAMS do
		for _, p in duel.sides[side] do
			table.insert(list, p)
		end
	end
	return list
end

-- (to everyone still in it: not someone already home after the result)
local function tell(duel, name, ...)
	for _, p in everyone(duel) do
		if inDuel[p] == duel then
			Net.fire(p, name, ...)
		end
	end
end

-- CombatService's view: a duellist's side, nil for anyone on the plaza
function DuelService:Team(player)
	local duel = inDuel[player]
	return duel and duel.side[player] or nil
end

function DuelService:Of(player)
	return inDuel[player]
end

function DuelService:List()
	return duels
end

function DuelService:SetParties(fn)
	partiesFn = fn
end

-- The queue ----------------------------------------------------------------------------------------------------
function DuelService:Queue(size)
	local out = {}
	for _, g in queueOf(size).groups do
		for _, p in g.members do
			table.insert(out, p)
		end
	end
	return out
end

-- Two full sides from the groups in order (each group on one side, where it fits; one that fits nowhere waits),
-- or nil, and how many are seated
local function seat(q, size)
	local sides = { red = {}, blue = {} }
	local seated = {}
	for _, g in q.groups do
		local n = #g.members
		-- (the emptier side first, then whichever has the room)
		local pick
		local redFits, blueFits = #sides.red + n <= size, #sides.blue + n <= size
		if redFits and (#sides.red <= #sides.blue or not blueFits) then
			pick = "red"
		elseif blueFits then
			pick = "blue"
		end
		if pick then
			for _, p in g.members do
				table.insert(sides[pick], p)
			end
			table.insert(seated, g)
		end
	end
	local n = #sides.red + #sides.blue
	return (n == size * 2) and sides or nil, n, seated
end

local function chip(q, size)
	local _, n = seat(q, size)
	local seconds = q.countdownAt and math.max(0, q.countdownAt - now()) or nil
	for _, g in q.groups do
		for _, p in g.members do
			Net.fire(p, "Duel", { kind = "queue", size = size, n = n, of = size * 2, seconds = seconds })
		end
	end
end

-- The queue changed: full sides start a countdown; a countdown with the sides no longer full stops
local function settle(size)
	local q = queueOf(size)
	local full = seat(q, size)
	if full and not q.countdownAt then
		q.countdownAt = now() + Constants.DUEL_COUNTDOWN
	elseif not full and q.countdownAt then
		q.countdownAt = nil
	end
	chip(q, size)
end

local function dropFromGroup(q, g, i, player)
	local at = table.find(g.members, player)
	if at then
		table.remove(g.members, at)
	end
	how[player] = nil
	if #g.members == 0 or g.by == player then
		-- (the one who stepped on leaves: their whole party leaves with them)
		for _, m in g.members do
			how[m] = nil
			Net.fire(m, "Duel", { kind = "queue", off = true })
		end
		table.remove(q.groups, i)
	end
	Net.fire(player, "Duel", { kind = "queue", off = true })
end

function DuelService:Leave(player)
	local q, g, i, size = groupOf(player)
	if not q then
		return false
	end
	dropFromGroup(q, g, i, player)
	settle(size)
	return true
end

-- Who comes with them: their party's members here and free (not in a duel), the stepper first, when the party fits
local function party(player, size)
	local list = partiesFn and partiesFn(player) or nil
	local members = { player }
	for _, m in list or {} do
		if m ~= player and m.Parent and not inDuel[m] then
			table.insert(members, m)
		end
	end
	if #members > size then
		return { player }
	end
	return members
end

function DuelService:Join(player, size, via)
	size = tonumber(size)
	if not size or not table.find(Constants.DUEL_SIZES, size) or inDuel[player] or not player.Parent then
		return false
	end
	local q, _, _, was = groupOf(player)
	if q and was == size then
		return true -- (already in it)
	end
	if q then
		self:Leave(player)
	end
	local members = party(player, size)
	for _, m in members do
		if m ~= player and groupOf(m) then
			self:Leave(m) -- (they come along)
		end
	end
	q = queueOf(size)
	table.insert(q.groups, { by = player, members = members })
	for _, m in members do
		how[m] = m == player and (via or "prompt") or "party" -- (a party member came along: they're not on the pad)
	end
	settle(size)
	return true
end

-- The pads: standing on one joins its queue, stepping off leaves it (polled, so a pad is a pad whatever the lobby
-- built it from); the prompt on each does the same with a tap
local function padUnder(pos)
	for _, pad in pads do
		local d = pos - pad.pos
		if math.abs(d.Y) < 8 and Vector3.new(d.X, 0, d.Z).Magnitude <= Constants.DUEL_PAD_RADIUS then
			return pad
		end
	end
	return nil
end

local function pollPads()
	for _, p in Players:GetPlayers() do
		if not inDuel[p] then
			local r = root(p)
			local pad = r and padUnder(r.Position) or nil
			local _, g, _, size = groupOf(p)
			if pad and (not g or size ~= pad.size) then
				DuelService:Join(p, pad.size, "pad") -- (stepped on; or walked from one pad to another)
			elseif not pad and g and how[p] == "pad" then
				DuelService:Leave(p) -- (stepped off)
			end
		end
	end
end

local function buildPads()
	local folder = Instance.new("Folder")
	folder.Name = "DuelPads"
	for i, size in Constants.DUEL_SIZES do
		local pos = Constants.DUEL_PADS[i]
		-- (an invisible post over the pad carries the prompt; the pad itself is the lobby's)
		local part = Instance.new("Part")
		part.Name = "DuelPad" .. size
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Transparency = 1
		part.CastShadow = false
		part.Size = Vector3.new(1, 1, 1)
		part.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
		part:SetAttribute("Size", size)
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Prompt"
		prompt.ActionText = "Duel"
		prompt.ObjectText = `⚔️ {size}v{size}`
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(player)
			local _, g, _, qsize = groupOf(player)
			if g and qsize == size then
				DuelService:Leave(player)
			else
				DuelService:Join(player, size, "prompt")
			end
		end)
		prompt.Parent = part
		part.Parent = folder
		pads[i] = { size = size, pos = pos, part = part }
	end
	folder.Parent = workspace
end

-- Bodies -------------------------------------------------------------------------------------------------------
-- A player's own avatar at the standard size (nobody is a bigger target), asked of Roblox once; the plain R15 body
-- when it can't be had
local avatars = {} -- [userId] = HumanoidDescription | false
local plainBody
local function bodyFor(player)
	local id = player.UserId
	if type(id) == "number" and id > 0 and avatars[id] == nil then
		local ok, d = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(id)
		end)
		if ok and d then
			pcall(function()
				d.HeightScale, d.WidthScale, d.DepthScale, d.HeadScale = 1, 1, 1, 1
				d.BodyTypeScale, d.ProportionScale = 0, 0
			end)
		end
		avatars[id] = ok and d or false
	end
	if avatars[id] then
		return avatars[id]
	end
	if plainBody == nil then
		local ok, d = pcall(function()
			local desc = Instance.new("HumanoidDescription")
			for _, k in { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" } do
				desc[k] = 0
			end
			desc.HeightScale, desc.WidthScale, desc.DepthScale, desc.HeadScale = 1, 1, 1, 1
			desc.BodyTypeScale, desc.ProportionScale = 0, 0
			return desc
		end)
		plainBody = ok and d or false
	end
	return plainBody or nil
end

local function load(player)
	local desc = bodyFor(player)
	local loaded = desc and pcall(function()
		player:LoadCharacterWithHumanoidDescription(desc)
	end)
	if not loaded and player.Parent then
		pcall(function()
			player:LoadCharacter()
		end)
	end
	return player.Parent and player.Character or nil
end

-- A fresh body on their deck, dressed in their side, facing the field, with spawn protection (CombatService)
local function spawn(player, duel, i)
	local side = duel.side[player]
	local c = load(player)
	if not c or inDuel[player] ~= duel then
		return
	end
	local cf = DuelArena.spawn(duel.arena, side, i or 1)
	cf = CFrame.lookAt(cf.Position, cf.Position + Vector3.new(Formulas.forward(side), 0, 0))
	local r = c:FindFirstChild("HumanoidRootPart")
	if r then
		r.CFrame = cf
	end
	player:SetAttribute("AcGrace", os.clock() + 2)
	local ok, err = pcall(looks.Dress, looks, c, side)
	if not ok then
		warn("[DuelService] dress failed: " .. tostring(err))
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum then
		pcall(function()
			hum.WalkSpeed = Constants.WALK_SPEED
			hum.BreakJointsOnDeath = false
			hum.Died:Connect(function()
				if player.Character == c and combat:Alive(player) then
					combat:Kill(player, nil, { kind = "reset" })
				end
			end)
		end)
	end
	ok, err = pcall(combat.Spawned, combat, player)
	if not ok then
		warn("[DuelService] spawned failed: " .. tostring(err))
	end
	noBody[player] = nil
end

-- The duel ----------------------------------------------------------------------------------------------------
local function freeSlot()
	local i = 1
	while slots[i] do
		i += 1
	end
	return i
end

local function pay(player, n, why)
	if economy and typeof(player) == "Instance" then
		pcall(economy.Add, economy, player, n, why)
	end
end

local function allDown(duel, side)
	for _, p in duel.sides[side] do
		if p.Parent and combat:Alive(p) then
			return false
		end
	end
	return true
end

local function startRound(duel)
	duel.round += 1
	duel.phase = "round"
	for _, side in Constants.TEAMS do
		for i, p in duel.sides[side] do
			task.spawn(function()
				local ok, err = pcall(spawn, p, duel, i)
				if not ok then
					warn("[DuelService] spawn failed: " .. tostring(err))
				end
			end)
		end
	end
	tell(duel, "Duel", { kind = "round", n = duel.round, score = table.clone(duel.score) })
	tell(duel, "Alert", `ROUND {duel.round}`, Color3.fromRGB(30, 30, 34), 1.5)
	tell(duel, "Sfx", "horn")
end

local function finish(duel, winner)
	if duel.phase == "over" then
		return
	end
	duel.phase = "over"
	duel.winner = winner
	duel.endAt = now() + Constants.DUEL_RESULT_SECONDS
	for _, p in everyone(duel) do
		local side = duel.side[p]
		local won = winner ~= "draw" and side == winner
		local profile = data:Get(p)
		if profile and profile.stats and winner ~= "draw" then
			-- (a draw moves nobody's record)
			local key = won and "duelWins" or "duelLosses"
			profile.stats[key] = (profile.stats[key] or 0) + 1
		end
		local shards = 0
		if won then
			shards = Constants.DUEL_SHARDS.win
			pay(p, shards, "duel")
		end
		if progress then
			pcall(progress.Push, progress, p)
		end
		Net.fire(p, "Duel", {
			kind = "result",
			won = won,
			draw = winner == "draw",
			winner = winner,
			score = table.clone(duel.score),
			shards = shards,
			kills = duel.kills[p] or 0,
			map = duel.def.key,
			rematch = { n = 0, of = duel.size * 2 },
		})
	end
	local name = Constants.DUEL_SIDE_NAME[winner]
	tell(
		duel,
		"Alert",
		name and `{name} WINS THE DUEL` or "A DRAW",
		Constants.TEAM_COLOR[winner] or Color3.fromRGB(30, 30, 34),
		2.5
	)
	tell(duel, "Sfx", "win")
	DuelService.Ended:Fire(duel, winner)
end

local function roundWon(duel, winner)
	if duel.phase ~= "round" then
		return
	end
	duel.score[winner] += 1
	duel.phase = "wait"
	duel.nextAt = now() + Constants.DUEL_ROUND_WAIT
	tell(duel, "Duel", { kind = "roundEnd", winner = winner, score = table.clone(duel.score) })
	if duel.score[winner] >= Constants.DUEL_ROUNDS then
		finish(duel, winner)
	else
		tell(duel, "Alert", `{Constants.DUEL_SIDE_NAME[winner]} WINS THE ROUND`, Constants.TEAM_COLOR[winner], 1.8)
	end
end

-- Back on the plaza: out of the duel and out of the fight (CombatService:Remove: a duel's arrow or blade can't touch
-- them; the lobby calls Spawned itself if its plaza has fights of its own), the lobby's body (or one beside the pad)
local function release(player, duel)
	if inDuel[player] ~= duel then
		return
	end
	inDuel[player] = nil
	noBody[player] = nil
	player:SetAttribute("Duel", nil)
	player:SetAttribute("DuelSide", nil)
	player:SetAttribute("Team", nil)
	if teams then
		pcall(teams.Clear, teams, player)
	end
	Net.fire(player, "Duel", { kind = "end" })
	combat:Remove(player) -- (out of the fight: nothing in a duel can reach them on the plaza)
	if not player.Parent then
		return
	end
	local pad = table.find(Constants.DUEL_SIZES, duel.size) or 1
	if DuelService.returnHome then
		local ok, err = pcall(DuelService.returnHome, player, pad)
		if not ok then
			warn("[DuelService] returnHome failed: " .. tostring(err))
		end
	else
		local c = load(player)
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r then
			-- (a step off the pad, facing the plaza: standing on it again would queue them again)
			local at = Constants.DUEL_PADS[pad] + Vector3.new(0, 3.5, 10)
			r.CFrame = CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
			player:SetAttribute("AcGrace", os.clock() + 2)
		end
	end
	pcall(combat.Push, combat, player)
	DuelService.Released:Fire(player)
end

local function teardown(duel)
	for _, p in everyone(duel) do
		release(p, duel)
	end
	arenas:RemoveArena("duel" .. duel.slot)
	DuelArena.destroy(duel.arena)
	slots[duel.slot] = nil
	local i = table.find(duels, duel)
	if i then
		table.remove(duels, i)
	end
	if #duels == 0 then
		combat:SetEnabled(false)
	end
end

-- Out of their duel before it's over: a loss for them; their side goes on without them, or loses when empty
local function drop(duel, player, why)
	local side = duel.side[player]
	local list = duel.sides[side]
	local at = table.find(list, player)
	if at then
		table.remove(list, at)
	end
	duel.side[player] = nil
	if duel.phase ~= "over" then
		local profile = data:Get(player)
		if profile and profile.stats then
			profile.stats.duelLosses = (profile.stats.duelLosses or 0) + 1
		end
		if why ~= "left" then
			Net.fire(player, "Duel", {
				kind = "result",
				won = false,
				draw = false,
				winner = other(side),
				score = table.clone(duel.score),
				shards = 0,
				kills = duel.kills[player] or 0,
				map = duel.def.key,
				forfeit = true,
			})
		end
	end
	release(player, duel)
	if duel.phase == "over" then
		return
	end
	if #list == 0 then
		finish(duel, other(side))
		for _, p in everyone(duel) do
			Notify.to(p, "The other side left. You win!", "win", { color = Constants.TEAM_COLOR[other(side)] })
		end
	elseif duel.phase == "round" and allDown(duel, side) then
		roundWon(duel, other(side))
	end
end

function DuelService:Forfeit(player)
	local duel = inDuel[player]
	if not duel then
		return false
	end
	drop(duel, player, "forfeit")
	return true
end

function DuelService:Rematch(player)
	local duel = inDuel[player]
	if not duel or duel.phase ~= "over" then
		return false
	end
	duel.rematch[player] = true
	local n = 0
	for _ in duel.rematch do
		n += 1
	end
	tell(duel, "Duel", { kind = "rematch", n = n, of = duel.size * 2 })
	release(player, duel)
	return self:Join(player, duel.size, "rematch")
end

local function start(size, sides, q, seated)
	for _, g in seated do
		local i = table.find(q.groups, g)
		if i then
			table.remove(q.groups, i)
		end
		for _, m in g.members do
			how[m] = nil
		end
	end
	q.countdownAt = nil
	chip(q, size)
	nextId += 1
	local slot = freeSlot()
	local def = Maps.next(lastMap, function(a, b)
		return random:NextInteger(a, b)
	end)
	lastMap = def.key
	local arena = DuelArena.build(def, workspace, slot)
	arenas:AddArena("duel" .. slot, arena)
	local duel = {
		id = nextId,
		size = size,
		slot = slot,
		arena = arena,
		def = def,
		sides = sides,
		side = {},
		score = { red = 0, blue = 0 },
		round = 0,
		phase = "wait",
		nextAt = now(),
		startedAt = now(),
		endsAt = now() + Constants.DUEL_SECONDS,
		kills = {},
		rematch = {},
	}
	slots[slot] = duel
	table.insert(duels, duel)
	local names = { red = {}, blue = {} }
	for _, side in Constants.TEAMS do
		for _, p in sides[side] do
			duel.side[p] = side
			inDuel[p] = duel
			table.insert(names[side], p.DisplayName)
			p:SetAttribute("Duel", duel.id)
			p:SetAttribute("DuelSide", side)
			p:SetAttribute("Team", side)
			if teams then
				pcall(teams.Set, teams, p, side) -- (where TeamService runs too, it agrees)
			end
			Net.fire(p, "Duel", { kind = "queue", off = true })
		end
	end
	for _, p in everyone(duel) do
		Net.fire(p, "Duel", {
			kind = "start",
			id = duel.id,
			size = size,
			side = duel.side[p],
			map = def.key,
			mapName = def.name,
			rounds = Constants.DUEL_ROUNDS,
			endsAt = duel.endsAt,
			sides = names,
		})
		Notify.to(p, `Duel: {def.name}. First to {Constants.DUEL_ROUNDS}!`, "start", { icon = "⚔️" })
	end
	combat:SetEnabled(true)
	startRound(duel)
	DuelService.Started:Fire(duel)
	return duel
end

-- A knockout in a duel: Shards for the knockout, the kill feed and the kill cam for the duel's players, and the round
-- to the other side when a whole side is down
local function onKilled(victim, killer, info)
	local duel = inDuel[victim]
	if not duel or duel.phase == "over" then
		return
	end
	local valid = killer ~= nil
		and killer ~= victim
		and killer.Parent ~= nil
		and inDuel[killer] == duel
		and duel.side[killer] ~= duel.side[victim]
	if valid then
		duel.kills[killer] = (duel.kills[killer] or 0) + 1
		pay(killer, Constants.DUEL_SHARDS.kill, "duel")
	end
	local vroot = root(victim)
	local kroot = killer and root(killer)
	local kp = killer and data:Get(killer)
	local killerPos = kroot and kroot.Position or nil
	tell(duel, "Kill", {
		killerPos = killerPos,
		dist = killerPos and vroot and math.floor((killerPos - vroot.Position).Magnitude + 0.5) or nil,
		cam = info.cam,
		effect = valid and kp and kp.equipped.effect or nil, -- (the killer's kill effect, drawn where you fell)
		pos = vroot and vroot.Position or nil,
		killer = killer and killer.UserId,
		killerName = killer and killer.DisplayName,
		killerTeam = killer and duel.side[killer],
		victim = victim.UserId,
		victimName = victim.DisplayName,
		victimTeam = duel.side[victim],
		weapon = info.weapon,
		head = info.head,
		push = 0,
		kind = info.kind,
		duel = duel.id,
	})
	if duel.phase == "round" and allDown(duel, duel.side[victim]) then
		roundWon(duel, other(duel.side[victim]))
	end
end

-- The clock --------------------------------------------------------------------------------------------------
local function tick()
	local t = now()
	pollPads()
	for size, q in queues do
		if q.countdownAt and t >= q.countdownAt then
			local sides, _, seated = seat(q, size)
			if sides then
				start(size, sides, q, seated)
			else
				q.countdownAt = nil
				chip(q, size)
			end
		end
	end
	for _, duel in table.clone(duels) do
		if duel.phase == "wait" and t >= duel.nextAt then
			startRound(duel)
		elseif duel.phase == "round" then
			if t >= duel.endsAt then
				-- the cap: the side ahead on rounds, or a draw
				local r, b = duel.score.red, duel.score.blue
				finish(duel, r > b and "red" or (b > r and "blue" or "draw"))
			else
				for _, p in everyone(duel) do
					local r = root(p)
					if r and combat:Alive(p) and r.Position.Y < duel.arena.origin.Y - 20 then
						combat:Kill(p, nil, { kind = "fall" }) -- (the kill plane)
					elseif not r and combat:Alive(p) then
						-- (the watchdog: alive with no body for a few seconds: a fresh one on the deck)
						noBody[p] = noBody[p] or t
						if t - noBody[p] >= Constants.STUCK_RESPAWN_SECONDS then
							noBody[p] = nil
							task.spawn(pcall, spawn, p, duel, table.find(duel.sides[duel.side[p]], p))
						end
					else
						noBody[p] = nil
					end
				end
			end
		elseif duel.phase == "over" and t >= duel.endAt then
			teardown(duel)
		end
	end
end

local function onRequest(player, action, arg)
	if action == "join" then
		DuelService:Join(player, arg, "prompt")
	elseif action == "cancel" then
		DuelService:Leave(player)
	elseif action == "rematch" then
		DuelService:Rematch(player)
	elseif action == "leave" then
		local duel = inDuel[player]
		if duel and duel.phase == "over" then
			release(player, duel)
		elseif duel then
			DuelService:Forfeit(player)
		else
			DuelService:Leave(player)
		end
	end
end

function DuelService:Init(registry)
	data = registry.PlayerDataService
	arenas = registry.ArenaService
	combat = registry.CombatService
	economy = registry.EconomyService
	progress = registry.ProgressService
	teams = registry.TeamService -- (when it runs here at all: the lobby has no match to pick teams for)
	-- (the looks: TeamService's Dress needs no match, so the module serves even where the service doesn't run)
	looks = teams or require(script.Parent.TeamService)
	if registry.PartyService then
		local parties = registry.PartyService
		partiesFn = function(player)
			local theirs = parties:Of(player)
			return theirs and theirs.members or nil
		end
	end
	-- the fight's rules in the lobby: sides are the duels', the blade is always out, no TNT, none of the match's helps
	combat:SetTeams(self)
	workspace:SetAttribute("Charge", true)
	local allowed = combat.allowed
	combat.allowed = function(key, player)
		return key ~= "tnt" and allowed(key, player)
	end
	combat.comebackShield = false
	combat.newPlayerHelp = false
	combat.firstKillHelp = false
	combat.Killed:Connect(onKilled)
	Net.on("Duel", onRequest)
	Players.PlayerRemoving:Connect(function(player)
		self:Leave(player)
		how[player] = nil
		noBody[player] = nil
	end)
	buildPads()
end

-- (before their save goes: a leaver forfeits, and the loss is written)
function DuelService:OnPlayerLeaving(player)
	local duel = inDuel[player]
	if duel then
		drop(duel, player, "left")
	end
end

function DuelService:Start()
	while true do
		task.wait(0.2)
		local ok, err = pcall(tick)
		if not ok then
			warn("[DuelService] tick failed: " .. tostring(err))
		end
	end
end

return DuelService
