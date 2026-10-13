-- Sound. The server sends "Sfx" (name, position?) for pickups, banking, building, giving, upgrades, the whistle,
-- the doors, the warnings and the horn, the brakes and the flare; with a position it plays there in 3D. Every
-- announcement gets a chime. Music: quiet ambient tracks while the train is on the line, faded down at the stops
-- (so the warnings carry) and at the station.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Store = require(script.Parent.Parent.Store)
local Theme = require(script.Parent.Parent.UI.Theme)

local AudioController = { Name = "AudioController", Order = 5 }

local music -- { sound, index }

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
	local volume = Constants.SOUND_VOLUME[name] or 0.6
	local sound
	if typeof(position) == "Vector3" then
		local anchor = Instance.new("Part")
		anchor.Name = "Sfx_" .. name
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.CFrame = CFrame.new(position)
		anchor.Parent = workspace
		sound = newSound(id, volume, anchor)
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = 100
		task.delay(8, function()
			anchor:Destroy()
		end)
	else
		sound = newSound(id, volume)
		sound.Name = "Sfx_" .. name
		task.delay(8, function()
			sound:Destroy()
		end)
	end
	sound:Play()
	return sound
end

-- How loud the music should be in this phase.
local function musicVolume()
	local phase = Store.phase()
	if phase == "traveling" or phase == "ended" then
		return Constants.MUSIC_VOLUME
	elseif phase == "arriving" or phase == "departing" then
		return Constants.MUSIC_VOLUME * 0.6
	end
	return Constants.MUSIC_VOLUME * 0.35
end

local function startMusic()
	local list = Constants.MUSIC
	local index = math.random(1, #list)
	local sound = newSound(list[index], 0)
	sound.Name = "Music"
	music = { sound = sound, index = index }
	sound.Ended:Connect(function()
		music.index = music.index % #list + 1
		sound.SoundId = list[music.index]
		sound:Play()
	end)
	sound:Play()
end

function AudioController:init()
	Net.listen("Sfx", function(name, position)
		AudioController.play(name, position)
	end)
	Net.listen("Announce", function(_, kind)
		if kind ~= "final" then
			AudioController.play("chime")
		end
	end)
	startMusic()
	local acc, last = 0, nil
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local v = musicVolume()
		if v ~= last and music then
			last = v
			Theme.tween(music.sound, 1.5, { Volume = v })
		end
	end)
end

return AudioController
