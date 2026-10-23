--[[
Server weather after a Block Party bloom, and the Welcome Shower (§2 WeatherService).

Event (startEvent, at bloom): Rain (Config.Weather.pick.rain) or Golden Hour for durationSec, broadcast as
Weather { kind, scope = "server", startsAt, endsAt }. Rain grows every plot rainGrowthMult faster; Golden Hour only
warms the lighting. Every crop on the plot of a player in the server rolls once, at a random whole second of the
event (Rain: Wet, Golden Hour: Golden, at Config.Mutations chances). A crop planted or regrown during the event rolls
at a random second of what is left; a crop harvested before its roll never rolls; a player who leaves takes their
rolls with them.

Welcome Shower (startShower, called by FirstSessionService in M8): rain on one player's plot only for
welcomeShower.durationSec (Weather { scope = "ownPlot" } to that player; rainGrowthMult there). Each crop has a
Mutations.wet.chance.welcomeShower Wet roll. At guaranteeWetAtSec the eligible crop (not Wet yet) with the highest
sell gets a guaranteed Wet and doesn't roll again; with nothing eligible it retries every second until the shower
ends. With still nothing, firstSession.wetGuaranteed stays false and the next crop they plant gets its Wet
guaranteeWetAtSec after planting.

  WeatherService.pick(rng) -> "rain" | "goldenHour"
  WeatherService.startEvent(kind?) / stopEvent() / current()
  WeatherService.startShower(player) / showerOf(player)
  WeatherService.tick(now)          runs due rolls and endings (the 1s loop calls it)
  WeatherService.Started(event) / Ended(event)
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Signal)

local DataService = require(script.Parent.DataService)
local DevCommands = require(script.Parent.Parent.Net.DevCommands)
local FarmService = require(script.Parent.FarmService)
local MutationService = require(script.Parent.MutationService)
local NetService = require(script.Parent.NetService)

local WeatherService = {
	Started = Signal.new(),
	Ended = Signal.new(),
}

WeatherService.rng = Random.new()

local event -- { kind, startsAt, endsAt }
local rolls = {} -- [key] = { player, tile, plantedAt, at, mut, chance, source = "event" | "shower" }
local showers = {} -- [player] = { startsAt, endsAt, nextTry, done }
local laterWet = {} -- [player] = true: the shower found nothing; the next planted crop gets the Wet
local delayedWet = {} -- [player] = { tile, plantedAt, at }
local savedLighting

local GOLDEN_LIGHT = {
	ClockTime = 17.6,
	Brightness = 2.6,
	Ambient = Color3.fromRGB(150, 110, 60),
	OutdoorAmbient = Color3.fromRGB(190, 140, 80),
	ColorShift_Top = Color3.fromRGB(255, 190, 110),
}

local MUT_FOR = { rain = "wet", goldenHour = "golden" }

function WeatherService.pick(rng)
	return if rng:NextNumber() < Config.Weather.pick.rain then "rain" else "goldenHour"
end

function WeatherService.current()
	return event
end

function WeatherService.showerOf(player)
	return showers[player]
end

local function eventChance(kind)
	local mut = MUT_FOR[kind]
	return mut, Config.Mutations[mut].chance[kind]
end

local function schedule(player, tileId, tile, from, to, mut, chance, source)
	local key = `{player.UserId}:{tileId}:{tile.plantedAt}:{source}`
	if rolls[key] then
		return
	end
	local span = math.max(1, math.floor(to - from))
	rolls[key] = {
		player = player,
		tile = tileId,
		plantedAt = tile.plantedAt,
		at = from + WeatherService.rng:NextInteger(0, span - 1),
		mut = mut,
		chance = chance,
		source = source,
	}
end

local function dropRolls(match)
	for key, r in rolls do
		if match(r) then
			rolls[key] = nil
		end
	end
end

local function broadcast(player)
	local data = if event
		then { kind = event.kind, scope = "server", startsAt = event.startsAt, endsAt = event.endsAt }
		else { kind = nil, scope = "server" }
	if player then
		NetService.fire(player, "Weather", data)
	else
		NetService.fireAll("Weather", data)
	end
end

local function setLighting(golden)
	if golden then
		savedLighting = savedLighting or {}
		for k, v in GOLDEN_LIGHT do
			savedLighting[k] = savedLighting[k] or Lighting[k]
			Lighting[k] = v
		end
	elseif savedLighting then
		for k, v in savedLighting do
			Lighting[k] = v
		end
		savedLighting = nil
	end
end

function WeatherService.stopEvent()
	if not event then
		return
	end
	local ended = event
	event = nil
	setLighting(false)
	dropRolls(function(r)
		return r.source == "event"
	end)
	broadcast()
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile then
			for id in profile.tiles do
				FarmService.render(player, id)
			end
		end
	end
	WeatherService.Ended:Fire(ended)
end

function WeatherService.startEvent(kind)
	WeatherService.stopEvent()
	local now = Clock.now()
	kind = kind or WeatherService.pick(WeatherService.rng)
	event = { kind = kind, startsAt = now, endsAt = now + Config.Weather.durationSec }
	setLighting(kind == "goldenHour")
	local mut, chance = eventChance(kind)
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile then
			for id, tile in profile.tiles do
				schedule(player, id, tile, now, event.endsAt, mut, chance, "event")
				FarmService.render(player, id)
			end
		end
	end
	broadcast()
	WeatherService.Started:Fire(event)
	return event
end

function WeatherService.startShower(player)
	local profile = DataService.get(player)
	if not profile then
		return false
	end
	local cfg = Config.Weather.welcomeShower
	local now = Clock.now()
	local s = { startsAt = now, endsAt = now + cfg.durationSec, nextTry = now + cfg.guaranteeWetAtSec, done = false }
	showers[player] = s
	for id, tile in profile.tiles do
		schedule(player, id, tile, now, s.endsAt, "wet", Config.Mutations.wet.chance.welcomeShower, "shower")
		FarmService.render(player, id)
	end
	NetService.fire(player, "Weather", { kind = "rain", scope = "ownPlot", startsAt = now, endsAt = s.endsAt })
	return true
end

-- the crop that gets the shower's guaranteed Wet: not Wet yet, highest sell (lowest tile id on a tie)
local function bestForWet(profile)
	local bestId, bestSell
	for id, tile in profile.tiles do
		if not tile.muts.wet then
			local sell = Config.Seeds[tile.seed].sell
			if not bestId or sell > bestSell or (sell == bestSell and id < bestId) then
				bestId, bestSell = id, sell
			end
		end
	end
	return bestId
end

local function guarantee(player, profile, id)
	MutationService.apply(player, id, "wet")
	profile.firstSession.wetGuaranteed = true
	NetService.change(player, { "firstSession" }, profile.firstSession)
	local tile = profile.tiles[id]
	rolls[`{player.UserId}:{id}:{tile.plantedAt}:shower`] = nil
end

local function endShower(player, s)
	showers[player] = nil
	local profile = DataService.get(player)
	if profile and not s.done then
		profile.firstSession.wetGuaranteed = false
		laterWet[player] = true
	end
	dropRolls(function(r)
		return r.player == player and r.source == "shower"
	end)
	NetService.fire(player, "Weather", { kind = nil, scope = "ownPlot" })
	if profile then
		for id in profile.tiles do
			FarmService.render(player, id)
		end
	end
end

function WeatherService.tick(now)
	for key, r in rolls do
		if r.at <= now then
			rolls[key] = nil
			local profile = r.player.Parent == Players and DataService.get(r.player)
			local tile = profile and profile.tiles[r.tile]
			local live = (r.source == "event" and event ~= nil) or (r.source == "shower" and showers[r.player] ~= nil)
			if tile and tile.plantedAt == r.plantedAt and live then
				MutationService.roll(r.player, r.tile, r.mut, r.chance, WeatherService.rng)
			end
		end
	end
	for player, s in showers do
		local profile = DataService.get(player)
		if not s.done and profile and now >= s.nextTry then
			local id = bestForWet(profile)
			if id then
				s.done = true
				guarantee(player, profile, id)
			else
				s.nextTry = now + 1
			end
		end
		if now >= s.endsAt then
			endShower(player, s)
		end
	end
	for player, d in delayedWet do
		if now >= d.at then
			delayedWet[player] = nil
			local profile = DataService.get(player)
			local tile = profile and profile.tiles[d.tile]
			if tile and tile.plantedAt == d.plantedAt then
				guarantee(player, profile, d.tile)
			else
				laterWet[player] = true -- harvested first: the next crop gets it
			end
		end
	end
	if event and now >= event.endsAt then
		WeatherService.stopEvent()
	end
end

local function onPlanted(player, id, tile)
	local now = Clock.now()
	if event then
		local mut, chance = eventChance(event.kind)
		schedule(player, id, tile, now, event.endsAt, mut, chance, "event")
	end
	local s = showers[player]
	if s then
		schedule(player, id, tile, now, s.endsAt, "wet", Config.Mutations.wet.chance.welcomeShower, "shower")
	end
	if laterWet[player] and not s then
		laterWet[player] = nil
		delayedWet[player] =
			{ tile = id, plantedAt = tile.plantedAt, at = now + Config.Weather.welcomeShower.guaranteeWetAtSec }
	end
end

local function forget(player)
	dropRolls(function(r)
		return r.player == player
	end)
	showers[player], laterWet[player], delayedWet[player] = nil, nil, nil
end

function WeatherService:Init()
	FarmService.weather = function(player)
		return { rain = event ~= nil and event.kind == "rain", shower = showers[player] ~= nil }
	end
	NetService.snapshotPart("weather", function(player)
		local s = showers[player]
		return {
			event = event and { kind = event.kind, startsAt = event.startsAt, endsAt = event.endsAt },
			shower = s and { startsAt = s.startsAt, endsAt = s.endsAt },
		}
	end)
	DevCommands.register("weather", function(_, args)
		local which = args[1]
		if which == "rain" then
			WeatherService.startEvent("rain")
		elseif which == "golden" then
			WeatherService.startEvent("goldenHour")
		elseif which == "off" then
			WeatherService.stopEvent()
		else
			return false, "usage: weather rain|golden|off"
		end
		return true
	end)
end

function WeatherService:Start()
	FarmService.Planted:Connect(onPlanted)
	Players.PlayerRemoving:Connect(forget)
	while true do
		task.wait(1)
		WeatherService.tick(Clock.now())
	end
end

function WeatherService:OnPlayerLoaded(player)
	broadcast(player)
end

return WeatherService
