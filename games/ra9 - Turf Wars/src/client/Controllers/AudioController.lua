--[[
Sound (master plan §5: every hit has a distinct sound): your shot, the hit tick, the kill, being hit, the horn at
the start of a fight, a structure going up, the win. Short, dry sounds; no music under the fight.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)

local AudioController = { Name = "AudioController", Order = 60 }

local player = Players.LocalPlayer
local cache = {}

function AudioController.play(name, speed)
	local id = Constants.SOUNDS[name]
	if not id then
		return nil
	end
	local s = cache[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.Volume = Constants.SOUND_VOLUME[name] or 0.6
		s.Parent = SoundService
		cache[name] = s
	end
	s.PlaybackSpeed = speed or 1
	pcall(function()
		SoundService:PlayLocalSound(s)
	end)
	return s
end

function AudioController:init()
	Bus.Fired:Connect(function(key, charge)
		-- (the blade: the same whoosh, pitched low, so a slash sounds heavier than a bowstring)
		AudioController.play("shoot", key == "blade" and 0.55 or 0.9 + (charge or 0) * 0.3)
	end)
	Net.listen("Hit", function(h)
		AudioController.play(h.kill and "kill" or "hit", h.melee and 0.75 or (h.head and 1.3 or 1))
	end)
	Net.listen("Hurt", function()
		AudioController.play("hurt", 0.8)
	end)
	Net.listen("Sfx", function(name)
		AudioController.play(name)
	end)
	Net.listen("Results", function(r)
		if r.you and r.you.won then
			AudioController.play("win")
		end
	end)
	Net.listen("Structure", function(s)
		if s.kind == "built" and s.team == player:GetAttribute("Team") then
			AudioController.play("built", 1.1)
		end
	end)
end

return AudioController
