--[[
The 3-5 minute hook after the tutorial (Data/Hook): a chain of missions for new players, counted here from the real
events, each paying out at once (Shards), then a HOOK COMPLETE reward (Shards and a cosmetic, worn straight away).

Who: a player in their first Hook.MAX_SESSIONS sessions with fewer than Hook.MAX_MATCHES matches, who hasn't finished
it. It starts once the tutorial isn't running for them (at join, or the moment it ends: TutorialService calls
HookService:Begin). Progress is kept in profile.hook = { i, have, done }, so a rejoin carries on where it was.

Counting (only the current step counts):
  ko     CombatService.Killed, they were the killer (not themselves)
  build  BuildService.Built by them
  push   MatchService.Pushed with them as the killer
  tnt    CombatService.Shot with the TNT (a step whose TNT is locked for them is passed by)
  win    MatchService.Ended, their team won

  Net "Hook" (server -> client):
    { kind = "step", i, total, key, have, need, shards }   the current mission (on start and on every advance)
    { kind = "progress", key, have, need }
    { kind = "stepDone", key, i, total, shards }
    { kind = "complete", shards, cosmetic }
  Analytics: hook_start, hook_step (each one done), hook_done

  HookService:Eligible(profile) -> bool     HookService:State(player) -> profile.hook or nil
  HookService:Begin(player)                 HookService:Count(player, key, n?)   HookService:Running(player)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Hook = require(ReplicatedStorage.Shared.Data.Hook)
local Net = require(ReplicatedStorage.Shared.Net)
local Weapons = require(ReplicatedStorage.Shared.Data.Weapons)

local HookService = {
	Name = "HookService",
	Modes = { "turf", "ctf", "brawl" }, -- (a match's: never in the lobby)
	Dependencies = {
		"PlayerDataService",
		"EconomyService",
		"ProgressService",
		"MatchService",
		"CombatService",
		"BuildService",
		"TeamService",
		"TutorialService",
	},
}

local registry, data, economy, progress, teams, tutorial
local running = {} -- [player] = true while the chain runs for them this session

local function analytics(player, name, info)
	local a = registry and registry.AnalyticsService
	if a and type(a.event) == "function" then
		pcall(a.event, player, name, info or {})
	end
end

function HookService:Eligible(profile)
	if type(profile) ~= "table" then
		return false
	end
	if type(profile.hook) == "table" and profile.hook.done then
		return false
	end
	local sessions = type(profile.meta) == "table" and profile.meta.sessions or 1
	local matches = profile.stats and profile.stats.matches or 0
	return (sessions or 1) <= Hook.MAX_SESSIONS and matches < Hook.MAX_MATCHES
end

function HookService:State(player)
	local p = data:Get(player)
	return p and p.hook or nil
end

function HookService:Running(player)
	return running[player] == true
end

local function tell(player)
	local h = HookService:State(player)
	local s = h and Hook.step(h.i)
	if not s then
		return
	end
	Net.fire(player, "Hook", {
		kind = "step",
		i = h.i,
		total = #Hook.STEPS,
		key = s.key,
		have = h.have,
		need = s.need,
		shards = s.shards,
	})
end

-- (the TNT mission for someone with no TNT to throw right now: passed by, no reward)
local function passable(player, s)
	return s ~= nil and s.key == "tnt" and Weapons.locked("tnt", player)
end

local function finish(player)
	local p = data:Get(player)
	if not p then
		return
	end
	p.hook.done = true
	running[player] = nil
	economy:Add(player, Hook.FINAL.shards, "hook")
	local it = Hook.FINAL.cosmetic and Cosmetics.get(Hook.FINAL.cosmetic)
	if it then
		economy:Give(player, it.key)
		p.equipped[it.kind] = it.key
	end
	progress:Push(player)
	Net.fire(player, "Hook", { kind = "complete", shards = Hook.FINAL.shards, cosmetic = it and it.key or nil })
	analytics(player, "hook_done", {})
end

local function skipLocked(player, h)
	while passable(player, Hook.step(h.i)) do
		h.i += 1
	end
end

local function advance(player)
	local h = HookService:State(player)
	if not h then
		return
	end
	h.i += 1
	h.have = 0
	skipLocked(player, h)
	if Hook.step(h.i) then
		tell(player)
	else
		finish(player)
	end
end

function HookService:Begin(player)
	local p = data:Get(player)
	if not p or running[player] or not self:Eligible(p) then
		return false
	end
	if tutorial and tutorial:Active(player) then
		return false -- (the tutorial first: it calls this again when it ends)
	end
	if type(p.hook) ~= "table" then
		p.hook = { i = 1, have = 0, done = false }
		analytics(player, "hook_start", {})
	end
	skipLocked(player, p.hook)
	if not Hook.step(p.hook.i) then
		finish(player)
		return true
	end
	running[player] = true
	data:WhenClientReady(player, function()
		if running[player] then
			tell(player)
		end
	end)
	return true
end

-- n more of `key` for this player: counts only toward the current step
function HookService:Count(player, key, n)
	if not running[player] then
		return false
	end
	local h = self:State(player)
	local s = h and Hook.step(h.i)
	if not s or s.key ~= key then
		return false
	end
	h.have = math.min(s.need, h.have + (n or 1))
	if h.have >= s.need then
		economy:Add(player, s.shards, "hook")
		progress:Push(player)
		Net.fire(player, "Hook", { kind = "stepDone", key = s.key, i = h.i, total = #Hook.STEPS, shards = s.shards })
		analytics(player, "hook_step", { step = s.key, i = h.i })
		advance(player)
	else
		Net.fire(player, "Hook", { kind = "progress", key = s.key, have = h.have, need = s.need })
	end
	return true
end

function HookService:Init(reg)
	registry = reg
	data = reg.PlayerDataService
	economy = reg.EconomyService
	progress = reg.ProgressService
	teams = reg.TeamService
	tutorial = reg.TutorialService
	local match, combat, build = reg.MatchService, reg.CombatService, reg.BuildService
	combat.Killed:Connect(function(victim, killer)
		if killer and killer ~= victim and typeof(killer) == "Instance" then
			self:Count(killer, "ko")
		end
	end)
	combat.Shot:Connect(function(player, key)
		if key == "tnt" and typeof(player) == "Instance" then
			self:Count(player, "tnt")
		end
	end)
	build.Built:Connect(function(player)
		if typeof(player) == "Instance" then
			self:Count(player, "build")
		end
	end)
	match.Pushed:Connect(function(_, _, killer)
		if killer and typeof(killer) == "Instance" then
			self:Count(killer, "push")
		end
	end)
	match.Ended:Connect(function(winner)
		for player in running do
			if player.Parent and winner and teams:Team(player) == winner then
				self:Count(player, "win")
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		running[player] = nil
	end)
end

function HookService:OnPlayerReady(player)
	self:Begin(player)
end

return HookService
