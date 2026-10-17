--[[
The first few minutes after the tutorial (HookService on the server, HookController on the client): a short chain of
missions, each with an instant reward, shown as big animated cards with a guide in the world, then a HOOK COMPLETE
card with a cosmetic that points to the shop. For new players only (their first sessions; see HookService).

  key      what counts (HookService)        marker   the world guide (HookController)
  ko       your knockouts                   enemy    a bouncing arrow over the nearest enemy
  build    walls you build                  build    the build tray glows (the build phase only)
  push     knockouts that move the line     line     an arrow on the frontline pointing at their side
  tnt      TNT throws (only for those who own it: passed by otherwise) enemy
  win      a match your team wins           line
]]
local Hook = {}

Hook.STEPS = {
	{
		key = "ko",
		title = "GET 2 KNOCKOUTS",
		desc = "Shoot an enemy across the line. One hit is a knockout!",
		need = 2,
		shards = 25,
		marker = "enemy",
		icon = "🎯",
	},
	{
		key = "build",
		title = "BUILD A WALL",
		desc = "In the build phase: pick a wall and place it on your side.",
		need = 1,
		shards = 25,
		marker = "build",
		icon = "🧱",
		phase = "build",
	},
	{
		key = "push",
		title = "PUSH THE LINE 3 TIMES",
		desc = "Every knockout in the fight moves the line toward their base.",
		need = 3,
		shards = 40,
		marker = "line",
		icon = "➡️",
	},
	{
		key = "tnt",
		title = "THROW THE TNT",
		desc = "Press 2 for your TNT and lob it at their walls!",
		need = 1,
		shards = 40,
		marker = "enemy",
		icon = "🧨",
	},
	{
		key = "win",
		title = "WIN A MATCH",
		desc = "Push the line all the way into their base.",
		need = 1,
		shards = 75,
		marker = "line",
		icon = "🏆",
	},
}

-- The end of the chain: Shards and a cosmetic of their own, worn at once
Hook.FINAL = { shards = 100, cosmetic = "shop_rainbowtrail" }

-- Who gets it: their first sessions, and not someone with many matches already
Hook.MAX_SESSIONS = 3
Hook.MAX_MATCHES = 15

function Hook.step(i)
	return Hook.STEPS[i]
end

return Hook
