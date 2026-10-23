--[[
Profile migrations: Migrations[v] takes a profile at version v to version v + 1. DataService runs them in order
until the profile reaches Config.Save.schemaVersion, then reconciles it against DataService.TEMPLATE (which fills
any key a step didn't add).
]]
return {
	-- v0: profiles from before versioning. Nothing moves; the template fills every missing key.
	[0] = function(p)
		return p
	end,
}
