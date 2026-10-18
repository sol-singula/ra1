--[[
Notifications for everyone (or one player): a banner slides down under the top bar (NotifyController), one at a
time, queued. For the moments that matter: a match starting, a team winning, someone becoming MVP or VIP, admin
news. Keep them short (a third grader reads them at a glance).

  Notify.all(text, kind, opts)        kind: "start" | "win" | "lose" | "status" | "admin" | "party" | "info" | "join"
  Notify.to(player, text, kind, opts) opts: { color = Color3, icon = "👑", seconds = 3, ally = bool ("join"),
                                              always = bool (shown in the AFK room too) }

"join" is small: a chip at the left, not the banner (someone new on your team, or a new enemy).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Notify = {}

local function pack(text, kind, opts)
	opts = opts or {}
	return {
		text = tostring(text),
		kind = kind or "info",
		color = opts.color,
		icon = opts.icon,
		seconds = opts.seconds,
		ally = opts.ally,
		always = opts.always, -- (shown even in the AFK room: the AFK messages themselves)
	}
end

function Notify.all(text, kind, opts)
	Net.fireAll("Announce", pack(text, kind, opts))
end

function Notify.to(player, text, kind, opts)
	Net.fire(player, "Announce", pack(text, kind, opts))
end

return Notify
