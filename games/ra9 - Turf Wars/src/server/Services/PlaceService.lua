--[[
Moving between the places of the universe (Data/Modes): the lobby sends people to a mode's place, a match sends
them back to the lobby. TeleportService:TeleportAsync, under pcall, tried again once on a failure, and a toast
when it still won't go (and on TeleportInitFailed). A party goes together: its leader's PLAY takes every member
(PartyService:Of; the party rides in the teleport data as PartyService:Move sends it, and forms again on
arrival); a member who isn't the leader is told to ask them. The teleport data also carries from = the mode they
left, so the place they land in can say "welcome from the lobby" (PlaceService.arrivedFrom(player)).

Nothing ever teleports while Modes.multiPlace() is false (the places aren't made yet): then PLAY only says the
mode isn't open yet, and the one place carries on as it always has.

  Client → server: Net "Play" (modeKey?: none means PopulationService:Best()), Net "ToLobby" ()

  PlaceService:ToMode(player, key)   -> ok, why ("closed" | "unknown" | "here" | "party" | "busy")
  PlaceService:ToLobby(player)       -> ok, why
  PlaceService:Trips()               every teleport asked for: { placeId, players, data } (tests)
  PlaceService.arrivedFrom(player)   the mode a player came from by teleport, or nil
  PlaceService.Moving (players, placeId, data)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Modes = require(ReplicatedStorage.Shared.Data.Modes)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local PlaceService = {
	Name = "PlaceService",
	Dependencies = { "PopulationService" },
	Moving = Signal.new("PlaceService.Moving"), -- (players, placeId, data)
	RETRIES = 1, -- tries again this many times after a failed TeleportAsync
	RETRY_SECONDS = 1.5,
	COOLDOWN = 5, -- seconds before the same player may ask again
}

local registry, population
local trips = {} -- every teleport asked for (tests)
local askedAt = {} -- [player] = os.clock() of their last trip

local function say(player, text, kind)
	Net.fire(player, "Toast", text, kind or "info")
end

local function isPlayer(p)
	return typeof(p) == "Instance" and p:IsA("Player") and p.Parent ~= nil
end

function PlaceService:Trips()
	return trips
end

-- The party to take along: the player's own, when they lead it (nil: just them). why: "party" when they're a
-- member who doesn't lead it.
local function companions(player)
	local parties = registry and registry.PartyService
	local party = parties and parties:Of(player)
	if not party then
		return { player }, nil
	end
	if party.leader ~= player then
		return nil, "party"
	end
	local members, ids = {}, {}
	for _, p in party.members do
		if isPlayer(p) then
			table.insert(members, p)
			table.insert(ids, p.UserId)
		end
	end
	return members, nil, { id = party.id, leader = player.UserId, members = ids, from = game.JobId }
end

-- The trip itself: TeleportAsync, again after RETRY_SECONDS when it errors, a toast when it still won't go
function PlaceService:Teleport(placeId, members, data)
	local trip = { placeId = placeId, players = members, data = data }
	table.insert(trips, trip)
	self.Moving:Fire(members, placeId, data)
	task.spawn(function()
		for attempt = 1, self.RETRIES + 1 do
			local going = {}
			for _, p in members do
				if isPlayer(p) then
					table.insert(going, p)
				end
			end
			if #going == 0 then
				return
			end
			local ok, err = pcall(function()
				local options = Instance.new("TeleportOptions")
				options:SetTeleportData(data)
				return TeleportService:TeleportAsync(placeId, going, options)
			end)
			if ok then
				trip.ok = true
				return
			end
			warn(`[PlaceService] teleport to {placeId} failed ({attempt}): {tostring(err)}`)
			trip.err = tostring(err)
			if attempt <= self.RETRIES then
				task.wait(self.RETRY_SECONDS)
			end
		end
		-- (Roblox never teleports from Studio: say how to test a mode there instead)
		local studio = RunService:IsStudio()
		if studio then
			warn(
				"[PlaceService] Studio can't teleport between places. To test a mode here: stop, set "
					.. "ReplicatedStorage > Mode to lobby / turf / ctf / brawl / tycoon, then press Play."
			)
		end
		for _, p in members do
			if isPlayer(p) then
				say(
					p,
					studio and "Could not go there: Studio can't teleport. Set ReplicatedStorage.Mode, then Play"
						or "Could not go there. Try again!",
					"bad"
				)
			end
		end
	end)
	return trip
end

local function go(self, player, placeId, modeKey, name)
	if not isPlayer(player) then
		return false, "gone"
	end
	local t = os.clock()
	if askedAt[player] and t - askedAt[player] < self.COOLDOWN then
		return false, "busy"
	end
	local members, why, party = companions(player)
	if not members then
		say(player, "Your party leader picks where you go.", "info")
		return false, why
	end
	askedAt[player] = t
	for _, p in members do
		askedAt[p] = t
		say(p, #members > 1 and `Off to {name}, together!` or `Off to {name}!`, "good")
	end
	local data = { from = Constants.MODE, to = modeKey, party = party }
	self:Teleport(placeId, members, data)
	return true
end

function PlaceService:ToMode(player, key)
	local mode = Modes.get(key)
	if not mode then
		return false, "unknown"
	end
	if not Modes.multiPlace() then
		say(player, `{mode.name} isn't open yet!`, "info")
		return false, "closed"
	end
	if key == Constants.MODE then
		return false, "here"
	end
	return go(self, player, mode.placeId, key, mode.name)
end

function PlaceService:ToLobby(player)
	if not Modes.multiPlace() then
		say(player, "The lobby isn't open yet!", "info")
		return false, "closed"
	end
	if Constants.MODE == "lobby" then
		return false, "here"
	end
	return go(self, player, Modes.LOBBY_PLACE, "lobby", "the lobby")
end

-- The mode a player arrived from (the teleport data's from), or nil (they came in from the site)
function PlaceService.arrivedFrom(player)
	local ok, jd = pcall(function()
		return player:GetJoinData()
	end)
	local trip = ok and type(jd) == "table" and jd.TeleportData
	local from = type(trip) == "table" and trip.from
	return type(from) == "string" and Constants.MODE_LOOK[from] and from or nil
end

function PlaceService:Init(reg)
	registry = reg
	population = reg.PopulationService
	Net.on("Play", function(player, key)
		if key ~= nil and type(key) ~= "string" then
			return
		end
		self:ToMode(player, key or population:Best())
	end)
	Net.on("ToLobby", function(player)
		self:ToLobby(player)
	end)
	pcall(function()
		TeleportService.TeleportInitFailed:Connect(function(player)
			if isPlayer(player) then
				askedAt[player] = nil
				say(player, "Could not go there. Try again!", "bad")
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		askedAt[player] = nil
	end)
end

return PlaceService
