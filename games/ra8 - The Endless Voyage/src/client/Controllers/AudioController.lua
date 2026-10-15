--[[
Sound (master plan §1: a beautiful ocean you can hear). The server sends "Sfx" (name, position?) for the hook,
the splash, chopping, mining, crafting, building, hits and bites, crates, eating, the horn when you set sail, the
discovery chime, roars and thunder; with a position it plays there in 3D. Callouts get a chime.

Music follows the voyage: calm by day on the raft, brighter while sailing, an island theme ashore, heavy in a storm,
big for the Leviathan, quiet at night. It fades between tracks. The Music setting turns it off.
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
local bossUntil = 0

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
	local settings = Store.get("settings")
	local on = not (settings and settings.music == false)
	local function vol(key, mult)
		return on and (Constants.MUSIC_VOLUME[key] or 0.18) * (mult or 1) or 0
	end
	if os.clock() < bossUntil then
		return "boss", vol("boss")
	end
	if Store.storm() then
		return "storm", vol("storm")
	end
	local state = Store.voyageState()
	if state == "sailing" or state == "home" then
		return "sailing", vol("sailing")
	elseif state == "island" then
		return "island", vol("island")
	end
	if Store.isNight() then
		return "night", vol("night")
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
	-- the Leviathan's music while it's up
	Net.listen("Creature", function(e)
		if type(e) == "table" and e.boss then
			if e.kind == "die" then
				bossUntil = 0
			else
				bossUntil = os.clock() + 20
			end
		end
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
