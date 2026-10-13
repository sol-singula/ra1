-- Fighters are players (Roblox Instances) or robots (plain tables with robot = true). Never read `.robot` on a
-- player: real Roblox errors on a name that isn't a property, so always ask through here.
local Fighter = {}

function Fighter.isRobot(f)
	return typeof(f) == "table" and f.robot == true
end

return Fighter
