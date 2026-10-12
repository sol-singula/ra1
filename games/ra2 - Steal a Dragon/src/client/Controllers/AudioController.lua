-- Sound: background music and sound effects.
--   Music: a playlist of whimsical fantasy tracks, one after another; inside the secret disco it fades over to
--   dance music and back when you leave.
--   Effects: the server sends "Sfx" (name, position?) for coins, buying, levelling up, locking, stealing, the
--   alarm when someone steals from you, bonks, swings and egg hatches; with a position the sound plays there in
--   3D, so you hear what happens near you. The client plays the rest itself (announcements, wing jumps).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(script.Parent.Parent.UI.Theme)

local player = Players.LocalPlayer

local AudioController = { Name = "AudioController", Order = 5 }

local DISCO_CENTRE = Vector3.new(165, 6, 20) -- the secret disco room (Disco.lua)
local DISCO_RADIUS = 20

local music -- { sound, list, index, volume }
local current = "world"

local function newSound(id, volume, parent)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.Parent = parent or SoundService
	return s
end

-- Play a sound effect by name, at a world position (3D) or for you alone (2D).
function AudioController.play(name, position)
	local id = Constants.SOUNDS[name]
	if not id then
		return nil
	end
	local volume = Constants.SOUND_VOLUME[name] or 0.6
	local sound
	if typeof(position) == "Vector3" and workspace:FindFirstChildOfClass("Terrain") then
		local at = Instance.new("Attachment")
		at.Name = "Sfx_" .. name
		at.WorldPosition = position
		at.Parent = workspace:FindFirstChildOfClass("Terrain")
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
	return kind == "disco" and Constants.DISCO_MUSIC or Constants.MUSIC
end

-- Switch the music between the world playlist and the disco's, with a quick fade.
local function switchTo(kind)
	if current == kind and music then
		return
	end
	current = kind
	local old = music
	local list = playlist(kind)
	local volume = kind == "disco" and Constants.DISCO_MUSIC_VOLUME or Constants.MUSIC_VOLUME
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
AudioController.switchTo = switchTo

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
	switchTo("world")
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local inDisco = hrp and (hrp.Position - DISCO_CENTRE).Magnitude < DISCO_RADIUS
		switchTo(inDisco and "disco" or "world")
	end)
end

return AudioController
