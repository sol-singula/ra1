--[[
ACT (master plan §4: one button that does what you hold). The client sends Act(aim, targetId) and the server does
what the selected item does: a rod casts (at a piece of debris: it reels it in; at open water: it fishes), an axe
chops the island's trees, a pickaxe mines, a crowbar
pries a wreck's salvage, a hammer repairs the raft, a spear stabs, a harpoon flies, food is eaten, a chart read,
a crate opened. Everyone nearby sees the action ("Act").
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Signal)

local ActionService = {
	Name = "ActionService",
	Dependencies = { "PlayerDataService", "InventoryService", "PlayerService", "OceanService", "RaftService" },
	Acted = Signal.new("ActionService.Acted"), -- (player, item, mode, ok)
}

local inventory, players, ocean, rafts, registry
local lastAct = {} -- [player] = os.clock()
local lastHint = {}

-- What ACT does with an item: the mode, and the service call.
function ActionService.modeOf(item)
	if not item then
		return nil
	end
	local kind = Items.toolKind(item)
	if kind == "rod" then
		return "cast"
	elseif kind == "axe" then
		return "chop"
	elseif kind == "pick" then
		return "mine"
	elseif kind == "pry" then
		return "pry"
	elseif kind == "hammer" then
		return "repair"
	elseif item.weapon then
		return item.weapon.thrown and "throw" or "swing"
	elseif item.food then
		return "eat"
	elseif item.kind == "chart" or item.kind == "blueprint" or item.key == "supply_crate" then
		return "use"
	end
	return nil
end

function ActionService:Act(player, aim, targetId)
	if not players:IsAlive(player) then
		return false
	end
	local t = os.clock()
	if t - (lastAct[player] or 0) < 0.2 then
		return false
	end
	lastAct[player] = t
	local id, item = inventory:Selected(player)
	-- empty hands: ACT grabs your rod (the rod is the whole game, it should never be a puzzle to get it back)
	if not item and inventory:CountKind(player, "rod") > 0 then
		inventory:HoldKind(player, "rod")
		id, item = inventory:Selected(player)
		Net.fire(player, "Toast", "🎣 Rod in hand! Tap ACT again to cast.", "good")
		return true
	end
	local mode = ActionService.modeOf(item)
	if typeof(aim) ~= "Vector3" then
		aim = nil
	end
	if type(targetId) ~= "number" and type(targetId) ~= "string" then
		targetId = nil
	end
	local ok = false
	if mode == "cast" then
		ok = ocean:Cast(player, item, aim, targetId)
	elseif mode == "chop" or mode == "mine" or mode == "pry" then
		ok = registry.IslandService:Gather(player, item, targetId, aim)
	elseif mode == "repair" then
		ok = rafts:Repair(player, type(targetId) == "number" and targetId or nil)
	elseif mode == "swing" then
		ok = registry.CombatService:Swing(player, item, aim, targetId)
	elseif mode == "throw" then
		ok = registry.CombatService:Throw(player, item, aim, targetId)
	elseif mode == "eat" or mode == "use" then
		ok = inventory:Use(player, id)
	else
		if t - (lastHint[player] or 0) > 3 then
			lastHint[player] = t
			Net.fire(player, "Toast", "Hold a tool to use it: tap a hotbar slot (or 1-6).", "info")
		end
	end
	if mode and mode ~= "eat" and mode ~= "use" then
		local root = players:Root(player)
		local plot = players:Here(player)
		for _, other in players:PlayersOnPlot(plot or 0) do
			if other ~= player then
				Net.fire(
					other,
					"Act",
					{ by = player.UserId, item = item.key, mode = mode, aim = aim, pos = root and root.Position or nil }
				)
			end
		end
	end
	self.Acted:Fire(player, item, mode, ok)
	return ok
end

function ActionService:Init(reg)
	registry = reg
	inventory = reg.InventoryService
	players = reg.PlayerService
	ocean = reg.OceanService
	rafts = reg.RaftService
	Net.on("Act", function(player, aim, targetId)
		self:Act(player, aim, targetId)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastAct[player] = nil
		lastHint[player] = nil
	end)
end

return ActionService
