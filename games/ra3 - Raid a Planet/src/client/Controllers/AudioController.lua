-- Sound: space adventure music (a raid switches to battle music), and sound effects the server sends ("Sfx":
-- name, position?) for blasts, pops, coins, the forge, bosses and so on; with a position the sound plays there
-- in 3D.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local AudioController = { Name = "AudioController", Order = 5 }

local music
local current = "world"
local lastPlayed = {} -- [name] = os.clock(): the same effect never plays more than 8 times a second

local function newSound(id, volume, parent)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = parent or SoundService
	return s
end

function AudioController.play(name, position)
	local id = Constants.SOUNDS[name]
	if not id then
		return nil
	end
	local t = os.clock()
	if (lastPlayed[name] or 0) > t - 0.12 then
		return nil
	end
	lastPlayed[name] = t
	local volume = Constants.SOUND_VOLUME[name] or 0.6
	local sound
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if typeof(position) == "Vector3" and terrain then
		local at = Instance.new("Attachment")
		at.Name = "Sfx_" .. name
		at.WorldPosition = position
		at.Parent = terrain
		sound = newSound(id, volume, at)
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = 90
		sound.Ended:Connect(function()
			at:Destroy()
		end)
		task.delay(8, function()
			if at.Parent then
				at:Destroy()
			end
		end)
	else
		sound = newSound(id, volume)
		sound.Name = "Sfx_" .. name
		sound.Ended:Connect(function()
			sound:Destroy()
		end)
		task.delay(8, function()
			if sound.Parent then
				sound:Destroy()
			end
		end)
	end
	sound:Play()
	return sound
end

local function playlist(kind)
	return kind == "raid" and Constants.RAID_MUSIC or Constants.MUSIC
end

function AudioController.switchTo(kind)
	if current == kind and music then
		return
	end
	current = kind
	local old = music
	local list = playlist(kind)
	local volume = kind == "raid" and Constants.RAID_MUSIC_VOLUME or Constants.MUSIC_VOLUME
	local start = math.random(1, #list)
	local sound = newSound(list[start], 0)
	sound.Name = "Music"
	music = { sound = sound, list = list, index = start, volume = volume }
	sound.Ended:Connect(function()
		if music and music.sound == sound then
			music.index = music.index % #music.list + 1
			sound.SoundId = music.list[music.index]
			sound:Play()
		end
	end)
	sound:Play()
	Theme.tween(sound, 1.2, { Volume = volume })
	if old then
		Theme.tween(old.sound, 1, { Volume = 0 })
		task.delay(1.1, function()
			old.sound:Destroy()
		end)
	end
end

function AudioController.musicKind()
	return current
end

function AudioController:init()
	Net.listen("Sfx", function(name, position)
		AudioController.play(name, position)
	end)
	Net.listen("Announce", function()
		AudioController.play("notify")
	end)
	Net.listen("Event", function(e)
		if e and e.kind == "raidStart" then
			AudioController.switchTo("raid")
		elseif e and e.kind == "raidEnd" then
			AudioController.switchTo("world")
		end
	end)
	AudioController.switchTo("world")
end

return AudioController
