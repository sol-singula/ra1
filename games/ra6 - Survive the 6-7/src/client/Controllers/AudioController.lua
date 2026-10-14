--[[
Sound (master plan §11: audio that tells you what's happening). The server sends "Sfx" (name, position?) for
chopping, mining, crafting, building, swings and hits, arrows, crates, eating, the horn at dusk, a teammate going
down, Kermy's roar and the wolves' howl; with a position it plays there in 3D, so a howl in the trees tells you
where the pack is. Callouts and pings get a chime.

Music follows the run: light and curious by day, tense at night, big for Mega Kermy, calm on the results. It fades
between tracks, ducks during dusk's horn and goes quiet while you wait for the next run. The Music setting turns it
off.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local AudioController = { Name = "AudioController", Order = 5 }

local music = { key = nil, sound = nil, index = 0 }
local MAX_AT_ONCE = 24
local playing = 0

local function newSound(id, volume, parent)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = parent or SoundService
	return s
end

function AudioController.play(name, position)
	local id = Constants.SOUNDS[name]
	if not id or playing >= MAX_AT_ONCE then
		return nil
	end
	local volume = Constants.SOUND_VOLUME[name] or 0.6
	local sound, holder
	if typeof(position) == "Vector3" then
		holder = Instance.new("Part")
		holder.Name = "Sfx_" .. name
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(position)
		holder.Parent = workspace
		sound = newSound(id, volume, holder)
		sound.RollOffMinDistance = 12
		sound.RollOffMaxDistance = 180
	else
		sound = newSound(id, volume)
		sound.Name = "Sfx_" .. name
		holder = sound
	end
	sound.PlaybackSpeed = (Constants.SOUND_SPEED[name] or 1) * (0.94 + math.random() * 0.12)
	playing += 1
	task.delay(6, function()
		playing -= 1
		holder:Destroy()
	end)
	sound:Play()
	return sound
end

-- Which music, and how loud, right now.
function AudioController.wanted()
	local phase = Store.phase()
	local settings = Store.get("settings")
	local on = not (settings and settings.music == false)
	local function vol(key, mult)
		return on and (Constants.MUSIC_VOLUME[key] or 0.18) * (mult or 1) or 0
	end
	if not Store.inRun() and phase ~= "results" then
		return "day", vol("day", 0.4)
	end
	if phase == "day" or phase == "dawn" or phase == "idle" then
		return "day", vol("day")
	elseif phase == "dusk" then
		return "night", vol("night", 0.5)
	elseif phase == "night" then
		return "night", vol("night")
	elseif phase == "boss" then
		return "boss", vol("boss")
	elseif phase == "results" then
		return "results", vol("results")
	end
	return "day", vol("day")
end

local function startTrack(key)
	local list = Constants.MUSIC[key] or Constants.MUSIC.day
	local old = music.sound
	if old then
		Theme.tween(old, 1.2, { Volume = 0 })
		task.delay(1.3, function()
			old:Destroy()
		end)
	end
	music.key = key
	music.index = math.random(1, #list)
	local sound = newSound(list[music.index], 0)
	sound.Name = "Music"
	sound.Looped = #list == 1
	sound.Ended:Connect(function()
		if music.sound == sound then
			music.index = music.index % #list + 1
			sound.SoundId = list[music.index]
			sound:Play()
		end
	end)
	music.sound = sound
	sound:Play()
end

function AudioController:init()
	Net.listen("Sfx", function(name, position)
		AudioController.play(name, position)
	end)
	Net.listen("Callout", function()
		AudioController.play("notify")
	end)
	Net.listen("Ping", function(ping)
		AudioController.play("ping", type(ping) == "table" and ping.position or nil)
	end)
	local acc, lastVolume = 1, nil
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local key, volume = AudioController.wanted()
		if key ~= music.key then
			startTrack(key)
			lastVolume = nil
		end
		if volume ~= lastVolume and music.sound then
			lastVolume = volume
			Theme.tween(music.sound, 1.5, { Volume = volume })
		end
	end)
end

-- (tests)
AudioController.music = music

return AudioController
