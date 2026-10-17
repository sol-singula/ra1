--[[
The lobby place (Constants.MODE = "lobby"; Modes = { "lobby" }: this runs only there): everyone lands here first.
No teams and no match: the server builds the plaza (World/LobbyBuilder), puts everyone on the spawn spot looking
down the walkway at PLAY, and runs what the lobby does:

  PLAY         Net "Play" (modeKey?) from the PLAY button, a mode card, the beacon or a portal: the framework's
               PlaceService teleports (it takes the event itself); without one, "Coming soon" (a toast)
  the parkour  the checkpoints up the west wall (LobbyBuilder.PARKOUR): standing on the start starts your clock,
               each checkpoint is kept (a fall back to the floor puts you back to the start), the tower's top
               finishes: PARKOUR_SHARDS once a day, the Parkour title the first time (ProgressService:GrantExtra),
               your best time kept (profile.lobby)
  VERIFY       Net "Verify" from the stand's card ("Like Turf Wars? Tap VERIFY to tell us"): an honour-system
               thank-you, once per account: VERIFY_SHARDS and the Supporter banner. Roblox doesn't tell a game
               whether it's liked, so nothing here checks or asks for a like: the tap is the whole thing.
  the counts   Net "Population" { turf, ctf, brawl } for the cards and the portals, on join and whenever they
               change (the framework sets them: LobbyService:SetPopulation)
  Net "Lobby"  { kind = "state", verified, parkourBest, parkourPaid } on join;
               { kind = "parkour", step, of, seconds?, done?, paid?, best?, fell? } as you climb;
               { kind = "verified", shards } when the thank-you's paid

  LobbyService:Spawn(player)          a body on the spawn spot (again after a fall or a knockout)
  LobbyService:SetPopulation(t)       the counts (Net "Population" to everyone)
  LobbyService:Population()
  LobbyService:World()                LobbyBuilder.build's table
  LobbyService:Run(player)            { step, startedAt } their climb so far (tests)
  LobbyService.Played (player, key?)  Net "Play" came in (tests; the framework teleports)
  LobbyService.Logged (player, name, data)   an analytics event (AnalyticsService.event too, when it's here)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local LobbyBuilder = require(ReplicatedStorage.Shared.World.LobbyBuilder)
local Modes = require(ReplicatedStorage.Shared.Data.Modes)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local LobbyService = {
	Name = "LobbyService",
	Modes = { "lobby" },
	Dependencies = { "PlayerDataService", "EconomyService", "ProgressService", "ShopService", "LeaderboardService" },
	Played = Signal.new("LobbyService.Played"), -- (player, modeKey?)
	Logged = Signal.new("LobbyService.Logged"), -- (player, name, data)
}

LobbyService.TICK = 0.2 -- seconds between looks at where everyone stands (the checkpoints, the kill plane)
LobbyService.REACH = 5 -- studs from a checkpoint's middle (on the ground) that count as standing on it
LobbyService.RESPAWN = 2 -- seconds after a knockout or a fall

local data, economy, progress, place, analytics
local world
local population = { turf = 0, ctf = 0, brawl = 0 }
local runs = {} -- [player] = { step = n (checkpoints passed; 0: not started), startedAt = os.clock() }
local spawning = {} -- [player] = true while a body is loading

local function today()
	return math.floor(os.time() / 86400)
end

local function log(player, name, payload)
	if analytics then
		pcall(analytics.event, player, name, payload)
	end
	LobbyService.Logged:Fire(player, name, payload)
end

local function lobbyOf(profile)
	profile.lobby = profile.lobby or { verified = false, parkourDay = 0, parkourBest = 0 }
	return profile.lobby
end

local function root(player)
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart")
end

-- A body on the spawn spot, facing PLAY ----------------------------------------------------------------------
function LobbyService:Spawn(player)
	if not player.Parent or spawning[player] then
		return
	end
	spawning[player] = true
	local ok = pcall(function()
		player:LoadCharacter()
	end)
	spawning[player] = nil
	if not ok or not player.Parent then
		return
	end
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	if r then
		r.CFrame = LobbyBuilder.SPOTS.spawn
	end
	player:SetAttribute("AcGrace", os.clock() + 2)
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			task.delay(self.RESPAWN, function()
				if player.Parent and player.Character == c then
					self:Spawn(player)
				end
			end)
		end)
	end
	runs[player] = { step = 0 }
end

-- The parkour ---------------------------------------------------------------------------------------------------
-- (step: checkpoints passed since the start, 0 at the start itself; of: how many there are to the top)
local function tell(player, run, extra)
	local msg = { kind = "parkour", step = math.max(0, run.step - 1), of = #LobbyBuilder.PARKOUR.checkpoints - 1 }
	if run.startedAt then
		msg.seconds = math.floor((os.clock() - run.startedAt) * 10) / 10
	end
	for k, v in extra or {} do
		msg[k] = v
	end
	Net.fire(player, "Lobby", msg)
end

function LobbyService:_finish(player, run)
	local seconds = math.floor((os.clock() - (run.startedAt or os.clock())) * 10) / 10
	local p = data:Get(player)
	local paid, first = false, false
	if p then
		local l = lobbyOf(p)
		if l.parkourDay ~= today() then
			l.parkourDay = today()
			economy:Add(player, Constants.PARKOUR_SHARDS, "parkour")
			paid = true
		end
		if l.parkourBest == 0 or seconds < l.parkourBest then
			l.parkourBest = seconds
		end
		first = progress:GrantExtra(player, "extra_parkour", {
			title = "PARKOUR CHAMPION!",
			line = "The Parkour title is yours: under your name",
		})
		run.best = l.parkourBest
	end
	log(player, "parkour", { seconds = seconds, paid = paid, first = first })
	tell(player, run, { done = true, paid = paid, first = first, seconds = seconds, best = run.best })
	local words = paid and `PARKOUR DONE in {seconds}s: +{Constants.PARKOUR_SHARDS} Shards!`
		or `PARKOUR DONE in {seconds}s (today's Shards are paid: again tomorrow)`
	Net.fire(player, "Toast", words, "good")
	run.step = 0
	run.startedAt = nil
end

function LobbyService:_tick()
	local cps = LobbyBuilder.PARKOUR.checkpoints
	for _, player in Players:GetPlayers() do
		local r = root(player)
		if not r then
			continue
		end
		local pos = r.Position
		if pos.Y < -20 then
			self:Spawn(player) -- (off the edge of the world)
			continue
		end
		local run = runs[player]
		if not run then
			run = { step = 0 }
			runs[player] = run
		end
		local nextCp = cps[run.step + 1]
		if nextCp and LobbyBuilder.near(pos, nextCp, self.REACH, 6) then
			if run.step == 0 then
				run.startedAt = os.clock()
				run.step = 1
				tell(player, run, { go = true })
			else
				run.step += 1
				if run.step >= #cps then
					self:_finish(player, run)
				else
					tell(player, run)
				end
			end
		elseif run.step >= 1 and pos.Y < 4 and not LobbyBuilder.near(pos, cps[1], 9) then
			-- (back on the floor, off the start: the climb's over; it starts again from the start)
			run.step = 0
			run.startedAt = nil
			tell(player, run, { fell = true })
		end
	end
end

function LobbyService:Run(player)
	return runs[player]
end

-- The counts ---------------------------------------------------------------------------------------------------
function LobbyService:SetPopulation(t)
	for _, key in Modes.LIST do
		population[key] = math.max(0, math.floor(tonumber(t and t[key]) or 0))
	end
	Net.fireAll("Population", table.clone(population))
end

function LobbyService:Population()
	return table.clone(population)
end

function LobbyService:World()
	return world
end

-- What a Roblox template leaves in the place (the grey Baseplate, the default SpawnLocation): the plaza is the world
local function clearTemplate()
	for _, d in workspace:GetChildren() do
		if (d:IsA("BasePart") and (d.Name == "Baseplate" or d:IsA("SpawnLocation"))) or d.Name == "Baseplate" then
			d:Destroy()
		end
	end
	pcall(function()
		workspace.Terrain:Clear()
	end)
end

-- Hooks ----------------------------------------------------------------------------------------------------------
function LobbyService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	progress = registry.ProgressService
	place = registry.PlaceService -- (the framework's: teleports on Net "Play"; nil until it lands)
	analytics = registry.AnalyticsService -- (nil in the lobby until the framework brings it along)
	clearTemplate()
	LobbyBuilder.light()
	world = LobbyBuilder.build(workspace)
	workspace:SetAttribute("Lobby", true)

	Net.on("Play", function(player, key)
		if key ~= nil and (type(key) ~= "string" or not Modes[key] or not table.find(Modes.LIST, key)) then
			key = nil
		end
		self.Played:Fire(player, key)
		log(player, "play", { mode = key or "any" })
		if place then
			return -- (PlaceService heard it too: the teleport is its)
		end
		Net.fire(player, "Toast", "Coming soon: matches start from the lobby", "info")
	end)

	Net.on("Verify", function(player)
		local p = data:Get(player)
		if not p then
			return
		end
		local l = lobbyOf(p)
		if l.verified then
			Net.fire(player, "Toast", "Already verified: thank you, Supporter!", "info")
			return
		end
		l.verified = true
		local total = economy:Add(player, Constants.VERIFY_SHARDS, "verify")
		progress:GrantExtra(player, "extra_supporter", {
			title = "THANK YOU! 👍",
			line = `+{Constants.VERIFY_SHARDS} Shards and the Supporter banner, equipped`,
		})
		log(player, "verify", { shards = Constants.VERIFY_SHARDS, total = total })
		Net.fire(player, "Lobby", { kind = "verified", shards = Constants.VERIFY_SHARDS })
		Net.fire(player, "Toast", `Thank you! +{Constants.VERIFY_SHARDS} Shards and the Supporter banner`, "good")
	end)

	Net.on("ToLobby", function()
		-- (already here; the framework's PlaceService answers this from a match place)
	end)

	Players.PlayerRemoving:Connect(function(player)
		runs[player] = nil
		spawning[player] = nil
	end)
end

function LobbyService:OnPlayerReady(player, profile)
	self:Spawn(player)
	data:WhenClientReady(player, function()
		local l = lobbyOf(profile)
		Net.fire(player, "Population", table.clone(population))
		Net.fire(player, "Lobby", {
			kind = "state",
			verified = l.verified == true,
			parkourBest = l.parkourBest or 0,
			parkourPaid = l.parkourDay == today(),
			of = #LobbyBuilder.PARKOUR.checkpoints - 1,
		})
	end)
end

function LobbyService:Start()
	while true do
		task.wait(self.TICK)
		local ok, err = pcall(self._tick, self)
		if not ok then
			warn("[LobbyService] tick failed: " .. tostring(err))
		end
	end
end

return LobbyService
