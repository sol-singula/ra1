--[[
Sound (master plan §15). The server sends "Sfx" (name, position?) for mining, hammering, a piece finished or
crumbling, swings, hits, arrows, spit, roars, magic, the horn and a shrine falling, coins and level-ups; with a
position it plays there in 3D, so you hear the fight at the gate from the courtyard. Callouts and alerts get a
chime.

Music follows the match: happy and bouncy while the castle goes up, dark fast drums in the fight, the last stand
played faster, a calm track in the hangout. It fades between tracks and goes quiet under the plague's warning.
The Music setting (⚙️ MORE) turns it off.
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
local MAX_AT_ONCE = 24 -- a big fight sends a lot; past this, new sounds wait their turn
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
	local sound
	local holder
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
		sound.RollOffMaxDistance = 160
	else
		sound = newSound(id, volume)
		sound.Name = "Sfx_" .. name
		holder = sound
	end
	-- a little variety so a wall of hammers doesn't sound like one machine
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
	local volume = (settings and settings.music == false) and 0 or Constants.MUSIC_VOLUME
	if phase == "build" then
		return "build", volume
	elseif phase == "plague" then
		return "build", volume * 0.3 -- the warning carries
	elseif phase == "fight" then
		return "fight", volume
	elseif phase == "laststand" then
		return "laststand", volume * 1.15
	elseif phase == "ended" then
		return "build", volume * 0.6
	end
	return "hangout", volume * 0.8
end

local function startTrack(key)
	local list = Constants.MUSIC[key] or Constants.MUSIC.build
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
	sound.PlaybackSpeed = key == "laststand" and Constants.LASTSTAND_MUSIC_SPEED or 1
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
