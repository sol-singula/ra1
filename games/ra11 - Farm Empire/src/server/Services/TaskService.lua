--[[
Guidance (master plan §2, §16): one primary task on screen. First the onboarding tasks (Data/Tasks) until the
loop is understood; then the recommendation: the upgrade that fixes the current bottleneck (UpgradeService). Plus
the secondary goals (optional, each pays once) and the long-term milestone (the next building and its price).
Nothing has to be claimed: a task done shows its reward and the next one follows.

  TaskService:Primary(player)   { key, text, kind, target, cost, affordable, why }
  TaskService:Push(player)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)
local Tasks = require(ReplicatedStorage.Shared.Data.Tasks)
local Upgrades = require(ReplicatedStorage.Shared.Data.Upgrades)

local TaskService = {
	Name = "TaskService",
	Dependencies = { "PlayerDataService", "EconomyService", "CropService", "BusinessService", "UpgradeService" },
	Completed = Signal.new("TaskService.Completed"),
	TICK = 1,
}

local data, economy, crops, business, upgrades, analytics
local lastSent = {} -- [player] = the last primary key sent (so the push only goes on a change)

local WHY = {
	harvest = "ripe crops are waiting on the tiles",
	storage = "the stock area is full",
	service = "the line is longer than the counter can serve",
	demand = "the counter is idle: more customers would buy",
	production = "the shelves run empty: grow more",
	dispatch = "goods arrive faster than the docks send them",
	land = "the next step for a bigger business",
}

function TaskService:Primary(player)
	local p = data:Get(player)
	if not p then
		return nil
	end
	local t = p.task
	if not t.done then
		local step = Tasks.ONBOARDING[t.step]
		if step then
			local u = step.target and Upgrades[step.target]
			local cost = u and Upgrades.cost(step.target, p.owned[step.target] or 0) or nil
			return {
				key = step.key,
				text = step.text,
				kind = step.kind,
				target = step.target,
				cost = cost,
				affordable = cost == nil or p.cash >= cost,
				step = t.step,
				of = #Tasks.ONBOARDING,
			}
		end
		t.done = true
	end
	local key, bottleneck, affordable = upgrades:Recommend(player)
	if not key then
		return { key = "free", text = "Keep growing!", kind = "none" }
	end
	local u = Upgrades[key]
	local cost = Upgrades.cost(key, p.owned[key] or 0)
	local verb = affordable and "Buy" or "Save for"
	return {
		key = "buy:" .. key,
		text = `{verb} {u.name} ({Format.cash(cost)}): {WHY[bottleneck] or ""}`,
		kind = "upgrade",
		target = key,
		cost = cost,
		affordable = affordable,
		bottleneck = bottleneck,
	}
end

function TaskService:Goals(player)
	local p = data:Get(player)
	local out = {}
	if not p then
		return out
	end
	for _, g in Tasks.GOALS do
		local have = p.stats[g.stat] or 0
		table.insert(
			out,
			{
				key = g.key,
				text = g.text,
				n = g.n,
				have = math.min(have, g.n),
				done = p.task.goals[g.key] == true,
				reward = g.reward,
			}
		)
		if #out >= 3 and not out[#out].done then
			break
		end
	end
	-- (the first three not yet done, in order)
	local shown, i = {}, 1
	for _, g in Tasks.GOALS do
		if not p.task.goals[g.key] then
			local have = p.stats[g.stat] or 0
			table.insert(shown, { key = g.key, text = g.text, n = g.n, have = math.min(have, g.n), reward = g.reward })
			i += 1
			if i > 3 then
				break
			end
		end
	end
	return shown
end

function TaskService:Step(player)
	local p = data:Get(player)
	if not p then
		return
	end
	local t = p.task
	local changed = false
	-- onboarding
	if not t.done then
		local step = Tasks.ONBOARDING[t.step]
		if step then
			local s = crops:Summary(player)
			if step.done(p, s) then
				t.step += 1
				changed = true
				if analytics then
					pcall(analytics.event, player, "task", { key = step.key })
				end
				self.Completed:Fire(player, step.key)
				if not Tasks.ONBOARDING[t.step] then
					t.done = true
					Net.fire(
						player,
						"Toast",
						"You've got the loop! From now on, follow the recommended upgrade.",
						"good"
					)
				end
			end
		else
			t.done = true
		end
	end
	-- goals
	for _, g in Tasks.GOALS do
		if not t.goals[g.key] and (p.stats[g.stat] or 0) >= g.n then
			t.goals[g.key] = true
			economy:Add(player, g.reward, "goal")
			Net.fire(player, "Toast", `Goal done: {g.text} (+{Format.cash(g.reward)})`, "good")
			changed = true
		end
	end
	local primary = self:Primary(player)
	local sig = primary and (primary.key .. tostring(primary.affordable)) or ""
	if changed or sig ~= lastSent[player] then
		self:Push(player, primary)
	end
end

function TaskService:Push(player, primary)
	local p = data:Get(player)
	if not p then
		return
	end
	primary = primary or self:Primary(player)
	lastSent[player] = primary and (primary.key .. tostring(primary.affordable)) or ""
	Net.fire(player, "Task", {
		primary = primary,
		goals = self:Goals(player),
		milestone = Tasks.milestone(p),
		onboarding = not p.task.done,
	})
end

function TaskService:Init(registry)
	data = registry.PlayerDataService
	economy = registry.EconomyService
	crops = registry.CropService
	business = registry.BusinessService
	upgrades = registry.UpgradeService
	analytics = registry.AnalyticsService
	Net.on("Task", function(player, what, key)
		local p = data:Get(player)
		if not p then
			return
		end
		if what == "skip" and not p.task.done then
			p.task.done = true
			self:Push(player)
		elseif what == "seen" and type(key) == "string" then
			p.task.seen[key] = true
		end
	end)
	registry.UpgradeService.Applied:Connect(function(player)
		lastSent[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
	end)
	_ = business
end

function TaskService:OnPlayerReady(player)
	data:WhenClientReady(player, function()
		self:Push(player)
	end)
end

function TaskService:Start()
	while true do
		task.wait(self.TICK)
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(self.Step, self, player)
			if not ok then
				warn("[TaskService] tick failed: " .. tostring(err))
			end
		end
	end
end

return TaskService
