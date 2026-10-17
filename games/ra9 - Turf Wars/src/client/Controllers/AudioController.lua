--[[
Sound (master plan §5: every hit has a distinct sound). No new uploads: the raw clips are the studio's shared set and
a few of Roblox's own client sounds (Constants.SOUNDS), and every cue here is built from them: layered (a kill is a
punch, a shatter and a rising chime at once), pitched and timed per layer, a little random each time so nothing
repeats exactly, and shaped with sound effects (reverb, EQ, distortion, chorus, a compressor, an octave down).

  the bow      a creak as you start drawing, creaking tighter as the charge builds and a soft ping at full; the
               release a twang and a whoosh (harder the fuller the draw); an arrow passing close by whooshes past
               where it is; a thunk where one lands; a tick on a hit
  kills        yours: a heavy punch under a glass shatter and a chime that rises (a headshot adds its own crack and a
               higher note); a streak of them adds a stinger that climbs a note per kill; someone else's falls
               shatter where they stood (3D)
  the blade    a whoosh on every swing (everyone's, where they are), a meaty cut under your knockout, an empty
               swish when yours cuts nothing, a steel clang on a parry or when two blades clash
  the TNT      a fuse hissing while you wind up, a throw, and the blast: a deep boom with a sub under it, a crack, a
               hiss of debris and a long hall tail, quieter and duller far away
  building     a clunk as you place a piece, a crunch where one comes down (3D)
  phases       a bright call at the build, the horn at FIGHT!, a riser and a doubled horn at the CHARGE, a tick each
               of the last 10 s (higher in the last 3), a victory or defeat stinger
  the menus    a soft click on every button, fainter still on hover
  ambience     a low wind under everything (Music)

The mix: SoundGroups Master > SFX (World: the arena; Stinger: your kills, streaks, phase calls), Music, UI
(Constants.SOUND_GROUPS). World and Music dip for a moment under a kill, and under the kill cam they're muffled and
roomy (AudioController.duck, .muffle). Sounds in the arena are 3D: each plays from an Attachment where it happened,
so you hear where. Each layer has a few voices it reuses (nothing is made per shot after the first few).

  AudioController.play(cue, speed?, volume?)          2D (yours); speed scales every layer's pitch
  AudioController.playAt(cue, pos, speed?, volume?)   3D, from pos
  AudioController.loop(cue, on, volume?)              a looping cue (the fuse, the wind) on or off
  AudioController.streak(n)                           the streak stinger for n kills in a row
  AudioController.duck(depth, seconds)                World and Music down by depth (0..1), back up after
  AudioController.muffle(on)                          the kill cam's dull, roomy arena
  AudioController.count(cue?)                         (tests) how many times a cue (or any) has played
  AudioController.groups()                            (tests) the SoundGroups by name
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Net = require(ReplicatedStorage.Shared.Net)
local Bus = require(script.Parent.Parent.UI.Bus)
local Store = require(script.Parent.Parent.Store)

local AudioController = { Name = "AudioController", Order = 60 }

local player = Players.LocalPlayer
local rng = Random.new()
local VOICES_2D, VOICES_3D = 3, 5 -- voices per layer
local FLAT = { button = true, click = true } -- (clips too short to bother varying)

-- Effect presets: each is a list of { class, props }, put on a layer's voices once
local FX = {
	punch = {
		{ "DistortionSoundEffect", { Level = 0.22 } },
		{ "EqualizerSoundEffect", { LowGain = 6, MidGain = 0, HighGain = -4 } },
		{ "CompressorSoundEffect", { Threshold = -18, Ratio = 4, Attack = 0.005, Release = 0.12, MakeupGain = 3 } },
	},
	sub = {
		{ "PitchShiftSoundEffect", { Octave = 0.5 } },
		{ "EqualizerSoundEffect", { LowGain = 8, MidGain = -4, HighGain = -18 } },
	},
	crunch = {
		{ "DistortionSoundEffect", { Level = 0.45 } },
		{ "EqualizerSoundEffect", { LowGain = 3, MidGain = 2, HighGain = -6 } },
	},
	air = { { "EqualizerSoundEffect", { LowGain = -18, MidGain = -3, HighGain = 3 } } },
	dull = { { "EqualizerSoundEffect", { LowGain = 3, MidGain = -6, HighGain = -24 } } },
	chorus = { { "ChorusSoundEffect", { Depth = 0.35, Mix = 0.5, Rate = 1.8 } } },
	room = {
		{ "ReverbSoundEffect", { DecayTime = 0.8, Density = 0.9, Diffusion = 0.8, DryLevel = 0, WetLevel = -12 } },
	},
	hall = { { "ReverbSoundEffect", { DecayTime = 2.4, Density = 1, Diffusion = 1, DryLevel = 0, WetLevel = -5 } } },
}

-- The cues. Each layer: { c = clip, v = volume, p = pitch, r = pitch randomness (±), d = delay s, fx = { presets } }.
-- group: "World" (3D or 2D, ducked), "Stinger" (yours, never ducked), "UI", "Music". loop: a looping cue.
local CUES = {
	-- the bow
	draw = { group = "World", layers = { { c = "draw", v = 0.32, p = 0.75, r = 0.04, fx = { "room" } } } },
	creak = { group = "World", layers = { { c = "draw", v = 0.22, p = 1, r = 0.03, fx = { "dull" } } } },
	full = {
		group = "World",
		layers = { { c = "ping", v = 0.1, p = 1.7, fx = { "room" } }, { c = "draw", v = 0.2, p = 1.35, d = 0.02 } },
	},
	release = {
		group = "World",
		layers = {
			{ c = "twang", v = 0.7, p = 1, r = 0.05 },
			{ c = "shoot", v = 0.45, p = 1.25, r = 0.06, fx = { "air" } },
			{ c = "click", v = 0.14, p = 0.6 },
		},
	},
	flyby = {
		group = "World",
		layers = {
			{ c = "shoot", v = 0.85, p = 1.7, r = 0.1, fx = { "air" } },
			{ c = "shoot", v = 0.3, p = 2.3, d = 0.04 },
		},
	},
	impact = {
		group = "World",
		layers = {
			{ c = "thud", v = 0.9, p = 1.35, r = 0.08 },
			{ c = "boom", v = 0.22, p = 2.2, r = 0.1 },
			{ c = "click", v = 0.22, p = 0.8 },
		},
	},
	hit = { group = "Stinger", layers = { { c = "hit", v = 0.6, p = 1.4 }, { c = "ping", v = 0.18, p = 2.2 } } },
	-- kills
	kill = {
		group = "Stinger",
		layers = {
			{ c = "thud", v = 1, p = 0.55, r = 0.03, fx = { "punch" } },
			{ c = "rocket", v = 0.32, p = 0.5, fx = { "sub" } },
			{ c = "glass", v = 0.5, p = 1.15, r = 0.05, d = 0.02 },
			{ c = "ping", v = 0.42, p = 1, d = 0.05, fx = { "room" } },
			{ c = "kill", v = 0.5, p = 1.25, d = 0.08, fx = { "room" } },
			{ c = "ping", v = 0.3, p = 1.5, d = 0.16, fx = { "room" } },
		},
	},
	headshot = {
		group = "Stinger",
		layers = {
			{ c = "thud", v = 1, p = 0.6, r = 0.03, fx = { "punch" } },
			{ c = "headshot", v = 0.75, p = 1 },
			{ c = "rocket", v = 0.3, p = 0.5, fx = { "sub" } },
			{ c = "glass", v = 0.55, p = 1.3, r = 0.05, d = 0.02 },
			{ c = "ping", v = 0.42, p = 1.26, d = 0.05, fx = { "room" } },
			{ c = "kill", v = 0.5, p = 1.5, d = 0.09, fx = { "room" } },
			{ c = "ping", v = 0.32, p = 2, d = 0.2, fx = { "room" } },
		},
	},
	shatter = {
		group = "World",
		layers = {
			{ c = "glass", v = 0.7, p = 1, r = 0.08 },
			{ c = "thud", v = 0.6, p = 0.7, r = 0.05, fx = { "punch" } },
			{ c = "ping", v = 0.14, p = 1.2, d = 0.04, fx = { "room" } },
		},
	},
	hurt = {
		group = "Stinger",
		layers = { { c = "thud", v = 0.8, p = 0.7, r = 0.05, fx = { "punch" } }, { c = "hit", v = 0.5, p = 0.6 } },
	},
	-- the blade
	swing = {
		group = "World",
		layers = {
			{ c = "slash", v = 0.55, p = 1, r = 0.08 },
			{ c = "shoot", v = 0.4, p = 0.55, r = 0.05, fx = { "air" } },
		},
	},
	-- (your slash reached no one: a hollow swish, lower and duller than the swing)
	whiff = {
		group = "World",
		layers = { { c = "shoot", v = 0.3, p = 0.42, r = 0.05, fx = { "air" } }, { c = "lunge", v = 0.18, p = 0.7 } },
	},
	-- (your slash knocked someone out: the blade biting, under the kill)
	cut = {
		group = "Stinger",
		layers = {
			{ c = "slash", v = 0.7, p = 0.72, r = 0.05, fx = { "punch" } },
			{ c = "thud", v = 0.7, p = 0.85, fx = { "punch" } },
		},
	},
	parry = {
		group = "Stinger",
		layers = {
			{ c = "unsheath", v = 0.7, p = 1.35, r = 0.05, fx = { "room" } },
			{ c = "ping", v = 0.4, p = 0.8, fx = { "hall" } },
			{ c = "hit", v = 0.4, p = 2 },
		},
	},
	-- the TNT
	fuse = { group = "World", loop = true, layers = { { c = "wind", v = 0.22, p = 2.4, fx = { "air" } } } },
	throw = {
		group = "World",
		layers = { { c = "shoot", v = 0.6, p = 0.5, r = 0.05 }, { c = "lunge", v = 0.4, p = 0.9 } },
	},
	boom = {
		group = "World",
		layers = {
			{ c = "boom", v = 1, p = 0.42, r = 0.04, fx = { "sub", "hall" } },
			{ c = "rocket", v = 0.6, p = 0.55, r = 0.05, fx = { "crunch" } },
			{ c = "thud", v = 1, p = 0.38, fx = { "punch" } },
			{ c = "glass", v = 0.3, p = 0.5, d = 0.05 },
			{ c = "wind", v = 0.3, p = 1.6, d = 0.1, fx = { "air" } },
		},
	},
	-- building
	place = {
		group = "World",
		layers = {
			{ c = "thud", v = 0.7, p = 1, r = 0.05 },
			{ c = "button", v = 0.35, p = 0.7 },
			{ c = "land", v = 0.4, p = 1.2, r = 0.05 },
		},
	},
	built = { group = "Stinger", layers = { { c = "built", v = 0.4, p = 1 } } },
	refused = {
		group = "UI",
		layers = { { c = "button", v = 0.35, p = 0.55 }, { c = "click", v = 0.2, p = 0.5, d = 0.06 } },
	},
	crumble = {
		group = "World",
		layers = {
			{ c = "crumble", v = 0.7, p = 0.9, r = 0.06, fx = { "crunch" } },
			{ c = "thud", v = 0.7, p = 0.7, r = 0.05 },
			{ c = "glass", v = 0.35, p = 0.65, d = 0.04 },
		},
	},
	-- phases
	build = {
		group = "Stinger",
		layers = {
			{ c = "built", v = 0.6, p = 0.8, fx = { "room" } },
			{ c = "ping", v = 0.3, p = 1, d = 0.1, fx = { "room" } },
			{ c = "ping", v = 0.3, p = 1.33, d = 0.2, fx = { "room" } },
		},
	},
	horn = {
		group = "Stinger",
		layers = {
			{ c = "horn", v = 0.7, p = 1, fx = { "room" } },
			{ c = "rocket", v = 0.35, p = 0.45, fx = { "sub" } },
			{ c = "thud", v = 0.8, p = 0.5, fx = { "punch" } },
		},
	},
	charge = {
		group = "Stinger",
		layers = {
			{ c = "shoot", v = 0.4, p = 0.5 },
			{ c = "shoot", v = 0.45, p = 0.7, d = 0.22 },
			{ c = "shoot", v = 0.5, p = 0.95, d = 0.44 },
			{ c = "horn", v = 0.7, p = 0.8, d = 0.62, fx = { "chorus", "hall" } },
			{ c = "horn", v = 0.35, p = 1.2, d = 0.67 },
			{ c = "thud", v = 0.9, p = 0.45, d = 0.62, fx = { "punch" } },
		},
	},
	count = { group = "Stinger", layers = { { c = "click", v = 0.5, p = 1 }, { c = "button", v = 0.15, p = 1.6 } } },
	countHigh = { group = "Stinger", layers = { { c = "ping", v = 0.4, p = 1.5 }, { c = "click", v = 0.45, p = 1.2 } } },
	victory = {
		group = "Stinger",
		layers = {
			{ c = "win", v = 0.8, p = 1, fx = { "room" } },
			{ c = "ping", v = 0.3, p = 1, fx = { "room" } },
			{ c = "ping", v = 0.3, p = 1.26, d = 0.1, fx = { "room" } },
			{ c = "ping", v = 0.3, p = 1.5, d = 0.2, fx = { "room" } },
			{ c = "ping", v = 0.35, p = 2, d = 0.3, fx = { "hall" } },
		},
	},
	defeat = {
		group = "Stinger",
		layers = {
			{ c = "horn", v = 0.5, p = 0.6, fx = { "dull" } },
			{ c = "kill", v = 0.35, p = 0.6, d = 0.2, fx = { "dull", "hall" } },
		},
	},
	-- the menus
	click = { group = "UI", layers = { { c = "button", v = 0.3, p = 1.15, r = 0.04 } } },
	hover = { group = "UI", layers = { { c = "click", v = 0.07, p = 1.7 } } },
	-- ambience (loops)
	wind = {
		group = "Music",
		loop = true,
		layers = {
			{ c = "wind", v = 0.12, p = 0.42, fx = { "dull" } },
			{ c = "wind", v = 0.1, p = 0.27, fx = { "dull" } },
		},
	},
}
AudioController.CUES = CUES

-- The streak stinger: a note up the scale for each kill in a row (from 2), a horn on top from 5
local SCALE = { 1, 1.26, 1.5, 2, 2.52 }
for n = 2, 5 do
	local layers = { { c = "kill", v = 0.35, p = 0.9 + n * 0.08, d = 0, fx = { "room" } } }
	for i = 1, n do
		table.insert(layers, { c = "ping", v = 0.3, p = SCALE[i], d = (i - 1) * 0.075, fx = { "room" } })
	end
	if n >= 5 then
		table.insert(layers, { c = "horn", v = 0.35, p = 1.4, d = 0.3, fx = { "chorus", "hall" } })
	end
	CUES["streak" .. n] = { group = "Stinger", layers = layers }
end

local groups = {} -- [name] = SoundGroup
local duckUntil, duckDepth = 0, 0
local muffled = false
local voices = {} -- [key] = { list = { { sound, att? } }, i }
local loops = {} -- [cue] = { sounds }
local played = {} -- [cue] = times (tests)
local folder -- (the 3D voices' attachments live on the Terrain)

local function mixGroups()
	if groups.Master then
		return
	end
	local function group(name, parent)
		local g = SoundService:FindFirstChild("TW_" .. name) or Instance.new("SoundGroup")
		g.Name = "TW_" .. name
		g.Volume = Constants.SOUND_GROUPS[name] or 1
		g.Parent = parent
		groups[name] = g
		return g
	end
	local master = group("Master", SoundService)
	local sfx = group("SFX", master)
	group("World", sfx)
	group("Stinger", sfx)
	group("Music", master)
	group("UI", master)
	-- the kill cam's muffle: off until it's wanted
	pcall(function()
		local eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "Muffle"
		eq.LowGain, eq.MidGain, eq.HighGain = 0, 0, 0
		eq.Enabled = false
		eq.Parent = groups.World
		local verb = Instance.new("ReverbSoundEffect")
		verb.Name = "Room"
		verb.DecayTime, verb.WetLevel, verb.DryLevel = 1.8, -6, 0
		verb.Enabled = false
		verb.Parent = groups.World
	end)
end

local function addFx(sound, presets)
	for i, name in presets or {} do
		for _, e in FX[name] or {} do
			local inst = Instance.new(e[1])
			for k, v in e[2] do
				inst[k] = v
			end
			inst.Priority = i
			inst.Parent = sound
		end
	end
end

local function voice(cueName, index, layer, group, spatial)
	local key = cueName .. "#" .. index .. (spatial and "@" or "")
	local pool = voices[key]
	if not pool then
		pool = { list = {}, i = 0 }
		voices[key] = pool
	end
	pool.i = pool.i % (spatial and VOICES_3D or VOICES_2D) + 1
	local v = pool.list[pool.i]
	if v and v.sound.Parent then
		return v
	end
	local s = Instance.new("Sound")
	s.Name = cueName
	s.SoundId = Constants.SOUNDS[layer.c] or ""
	s.SoundGroup = groups[group] or groups.SFX
	addFx(s, layer.fx)
	local att
	if spatial then
		if not folder or not folder.Parent then
			folder = workspace:FindFirstChildOfClass("Terrain") or workspace
		end
		att = Instance.new("Attachment")
		att.Name = "Sfx_" .. cueName
		att.Parent = folder
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 10
		s.RollOffMaxDistance = 320
		s.Parent = att
	else
		s.Parent = SoundService
	end
	v = { sound = s, att = att }
	pool.list[pool.i] = v
	return v
end

local function start(cueName, pos, speed, volume)
	local cue = CUES[cueName]
	if not cue then
		-- (a clip with no recipe: played as it is)
		if not Constants.SOUNDS[cueName] then
			return nil
		end
		cue = { group = "World", layers = { { c = cueName, v = Constants.SOUND_VOLUME[cueName] or 0.6, p = 1 } } }
		CUES[cueName] = cue
	end
	mixGroups()
	played[cueName] = (played[cueName] or 0) + 1
	local spatial = typeof(pos) == "Vector3"
	local first
	for i, layer in cue.layers do
		local v = voice(cueName, i, layer, cue.group, spatial)
		local s = v.sound
		local r = (layer.r or (FLAT[layer.c] and 0 or 0.02))
		s.PlaybackSpeed = (layer.p or 1) * (speed or 1) * (1 + rng:NextNumber(-r, r))
		s.Volume = (layer.v or 0.6) * (volume or 1)
		if v.att then
			v.att.Position = pos -- (on the Terrain: its frame is the world's)
		end
		first = first or s
		local function go()
			pcall(function()
				s.TimePosition = 0
				s:Play()
			end)
		end
		if (layer.d or 0) > 0 then
			task.delay(layer.d, go)
		else
			go()
		end
	end
	return first
end

function AudioController.play(cue, speed, volume)
	return start(cue, nil, speed, volume)
end

function AudioController.playAt(cue, pos, speed, volume)
	if typeof(pos) ~= "Vector3" then
		return start(cue, nil, speed, volume)
	end
	return start(cue, pos, speed, volume)
end

function AudioController.loop(cueName, on, volume)
	local cue = CUES[cueName]
	if not cue then
		return nil
	end
	mixGroups()
	local l = loops[cueName]
	if on then
		if not l then
			l = {}
			for i, layer in cue.layers do
				local s = Instance.new("Sound")
				s.Name = cueName .. "Loop" .. i
				s.SoundId = Constants.SOUNDS[layer.c] or ""
				s.Looped = true
				s.PlaybackSpeed = layer.p or 1
				s.SoundGroup = groups[cue.group] or groups.SFX
				addFx(s, layer.fx)
				s.Parent = SoundService
				table.insert(l, { sound = s, v = layer.v or 0.5 })
			end
			loops[cueName] = l
		end
		for _, it in l do
			it.sound.Volume = it.v * (volume or 1)
			if not it.sound.IsPlaying then
				played[cueName] = (played[cueName] or 0) + 1
				pcall(function()
					it.sound:Play()
				end)
			end
		end
	elseif l then
		for _, it in l do
			pcall(function()
				it.sound:Stop()
			end)
		end
	end
	return l
end

function AudioController.streak(n)
	if n < 2 then
		return nil
	end
	return AudioController.play("streak" .. math.min(n, 5))
end

function AudioController.duck(depth, seconds)
	duckDepth = math.max(duckUntil > os.clock() and duckDepth or 0, depth)
	duckUntil = math.max(duckUntil, os.clock() + seconds)
end

function AudioController.muffle(on)
	mixGroups()
	muffled = on == true
	local world = groups.World
	pcall(function()
		local eq, verb = world:FindFirstChild("Muffle"), world:FindFirstChild("Room")
		eq.LowGain, eq.MidGain, eq.HighGain = 2, -6, muffled and -22 or 0
		eq.Enabled = muffled
		verb.Enabled = muffled
	end)
end

function AudioController.muffled()
	return muffled
end

function AudioController.count(cue)
	if cue then
		return played[cue] or 0
	end
	local n = 0
	for _, c in played do
		n += c
	end
	return n
end

function AudioController.groups()
	mixGroups()
	return groups
end

-- the dip: World and Music come down for a kill, then ease back up
local function stepMix()
	local k = 0
	local t = os.clock()
	if t < duckUntil then
		k = duckDepth
	elseif t < duckUntil + 0.5 then
		k = duckDepth * (1 - (t - duckUntil) / 0.5)
	end
	for _, name in { "World", "Music" } do
		local g = groups[name]
		if g then
			g.Volume = (Constants.SOUND_GROUPS[name] or 1) * (1 - k)
		end
	end
end

-- Every button, as it appears: a click when pressed, fainter on hover
local hooked = setmetatable({}, { __mode = "k" })
local function hookButton(b)
	if hooked[b] or not b:IsA("GuiButton") then
		return
	end
	hooked[b] = true
	pcall(function()
		b.Activated:Connect(function()
			AudioController.play("click")
		end)
	end)
	pcall(function()
		b.MouseEnter:Connect(function()
			AudioController.play("hover")
		end)
	end)
end

function AudioController:init()
	mixGroups()
	AudioController.loop("wind", true)
	-- the bow's creak, tighter as the charge builds (the TNT: its fuse hisses instead)
	local stage = nil
	Bus.Charge:Connect(function(c)
		local weapon = (Store.get("me") or {}).weapon
		if c == nil then
			if stage ~= nil then
				AudioController.loop("fuse", false)
			end
			stage = nil
			return
		end
		if stage == nil then
			stage = 0
			if weapon == "tnt" then
				AudioController.loop("fuse", true)
			else
				AudioController.play("draw")
			end
		end
		local s = c >= 0.999 and 3 or (c >= 0.66 and 2 or (c >= 0.33 and 1 or 0))
		if s > stage then
			stage = s
			if weapon == "tnt" then
				AudioController.loop("fuse", true, 1 + s * 0.3)
			elseif s == 3 then
				AudioController.play("full")
			else
				AudioController.play("creak", 0.9 + s * 0.15)
			end
		end
	end)
	Bus.Fired:Connect(function(key, charge)
		if key == "blade" then
			AudioController.play("swing")
		elseif key == "tnt" then
			AudioController.play("throw", 0.9 + (charge or 0) * 0.2)
		else
			AudioController.play("release", 0.92 + (charge or 0) * 0.16, 0.6 + (charge or 0) * 0.4)
		end
	end)
	-- your kills (every bow hit is one), your streak
	local streak = 0
	Net.listen("Hit", function(h)
		if type(h) ~= "table" then
			return
		end
		if h.clash then
			return -- (two blades met: everyone hears that clang where it happened, Sfx)
		elseif h.parry then
			AudioController.play("parry")
		elseif h.kill then
			AudioController.play(h.head and "headshot" or "kill", h.melee and 0.9 or 1)
			if h.melee then
				AudioController.play("cut")
			end
			AudioController.duck(0.55, 0.35)
		else
			AudioController.play("hit", h.head and 1.2 or 1)
		end
	end)
	Net.listen("Kill", function(k)
		if type(k) ~= "table" then
			return
		end
		if k.killer == player.UserId and k.victim ~= player.UserId then
			streak += 1
			if streak >= 2 then
				local n = streak
				task.delay(0.32, function()
					AudioController.streak(n)
				end)
			end
		elseif k.victim == player.UserId then
			streak = 0
		elseif typeof(k.pos) == "Vector3" then
			AudioController.playAt("shatter", k.pos) -- (someone else's fall, where it happened)
		end
	end)
	Net.listen("Hurt", function(h)
		if type(h) == "table" and (h.amount or 0) > 0 then
			AudioController.play("hurt", 0.9)
			AudioController.duck(0.4, 0.25)
		end
	end)
	Net.listen("Swing", function(s)
		if type(s) == "table" and s.whiff and s.by == player.UserId then
			AudioController.play("whiff")
		elseif type(s) == "table" and s.by ~= player.UserId and typeof(s.pos) == "Vector3" then
			AudioController.playAt("swing", s.pos + Vector3.new(0, 1.5, 0), 0.95)
		end
	end)
	Net.listen("Sfx", function(name, pos)
		AudioController.playAt(name, pos)
	end)
	Net.listen("Results", function(r)
		if type(r) ~= "table" or not r.you then
			return
		end
		if r.you.won then
			AudioController.play("victory")
		elseif r.winner then
			AudioController.play("defeat")
		end
	end)
	Net.listen("Structure", function(s)
		if s.kind == "built" and s.team == player:GetAttribute("Team") then
			AudioController.play("built", 1.1)
		end
	end)
	Bus.Tap:Connect(function(name)
		if name == "build_refused" then
			AudioController.play("refused")
		elseif type(name) == "string" and string.sub(name, 1, 6) == "build_" then
			AudioController.play("place")
		end
	end)
	-- the phases: the build call, the CHARGE, the last seconds ticking (FIGHT! is the server's horn: Sfx)
	local lastPhase, lastLeft
	Store.Changed:Connect(function(partial)
		local m = partial.match
		if m and m.phase ~= lastPhase then
			if m.phase == "build" and lastPhase ~= nil then
				AudioController.play("build")
				streak = 0
			end
			lastPhase = m.phase
		end
	end)
	workspace:GetAttributeChangedSignal("Charge"):Connect(function()
		if workspace:GetAttribute("Charge") == true then
			AudioController.play("charge")
		end
	end)
	RunService.RenderStepped:Connect(function()
		stepMix()
		local m = Store.get("match") or {}
		local window = m.phase == "fight" and 10 or (m.phase == "build" and 5 or 0)
		local left = m.ends and math.ceil(m.ends - workspace:GetServerTimeNow()) or nil
		if left and left ~= lastLeft and left >= 1 and left <= window then
			AudioController.play(left <= 3 and "countHigh" or "count", left % 2 == 0 and 1 or 0.92)
		end
		lastLeft = left
	end)
	-- the menus
	local gui = player:WaitForChild("PlayerGui")
	for _, d in gui:GetDescendants() do
		hookButton(d)
	end
	gui.DescendantAdded:Connect(hookButton)
end

return AudioController
