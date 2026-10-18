--[[
Naming your farm. Net "Name" (text) sets the farm's name (filtered through Roblox's TextService, 3 to 24 letters);
it goes on the sign by the road, the street board and the profile (profile.farmName). Without one the farm is
"<DISPLAYNAME>'S FARM".

  NameService:Of(player) -> the farm's name
  NameService:Set(player, text) -> ok, why ("short" | "long" | "filtered")
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Net = require(ReplicatedStorage.Shared.Net)

local NameService = {
	Name = "NameService",
	Dependencies = { "PlayerDataService", "PlotService" },
	MIN = 3,
	MAX = 24,
}

local data, plots

function NameService:Of(player)
	local p = data:Get(player)
	local name = p and p.farmName
	if type(name) == "string" and #name >= self.MIN then
		return name
	end
	return `{player.DisplayName}'s Farm`
end

local function filtered(player, text)
	local ok, result = pcall(function()
		local r = TextService:FilterStringAsync(text, player.UserId)
		return r:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" then
		return result
	end
	return text -- (Studio, or the mock: nothing to filter with)
end

function NameService:Set(player, text)
	local p = data:Get(player)
	if not p or type(text) ~= "string" then
		return false, "short"
	end
	text = string.gsub(text, "^%s+", "")
	text = string.gsub(text, "%s+$", "")
	text = string.gsub(text, "%s+", " ")
	if #text < self.MIN then
		return false, "short"
	elseif #text > self.MAX then
		return false, "long"
	end
	local clean = filtered(player, text)
	if string.find(clean, "#") then
		return false, "filtered"
	end
	p.farmName = clean
	p.stats.named = (p.stats.named or 0) + 1
	plots:Resign(player)
	data:Push(player, { farmName = clean })
	Net.fire(player, "Toast", `Your farm is now {clean}!`, "good")
	return true
end

function NameService:Init(registry)
	data = registry.PlayerDataService
	plots = registry.PlotService
	plots.farmName = function(player)
		return self:Of(player)
	end
	Net.on("Name", function(player, text)
		local ok, why = self:Set(player, text)
		if not ok then
			Net.fire(player, "Toast", ({
				short = "A name needs 3 letters or more",
				long = "That name is too long (24 letters)",
				filtered = "That name isn't allowed",
			})[why] or "Try another name", "bad")
		end
	end)
end

return NameService
