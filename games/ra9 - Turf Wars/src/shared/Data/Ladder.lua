--[[
The 100-win reward ladder (master plan §1, §8): every qualifying win unlocks the next step. All cosmetic.

  kind   "trail" (your arrows' trail) | "skin" (your bow's finish) | "effect" (what a kill of yours looks like)
         | "banner" (your banner's emblem) | "title" (under your name)
  big    every 10th step: a rarer one, announced to the server

Built from short lists so every step is something you can see and pick.
]]
local Ladder = {}

local TRAILS = {
	"White Line",
	"Dotted",
	"Long Streak",
	"Twin Lines",
	"Spiral",
	"Comet",
	"Glitch",
	"Shards",
	"Ribbon",
	"Neon",
}
local SKINS = {
	"Matte Black",
	"Chalk",
	"Glass",
	"Chrome",
	"Marble",
	"Gold Edge",
	"Carbon",
	"Frosted",
	"Obsidian",
	"Prism",
}
local EFFECTS = {
	"Shatter",
	"Poof",
	"Cubes",
	"Ring",
	"Fold",
	"Static",
	"Pixels",
	"Spark",
	"Slice",
	"Supernova",
}
local BANNERS = { "Chevron", "Star", "Arrow", "Crown", "Bolt", "Eye", "Wing", "Skull", "Sun", "Infinity" }
local TITLES = {
	"Recruit",
	"Archer",
	"Sharpshooter",
	"Builder",
	"Frontliner",
	"Veteran",
	"Pusher",
	"Commander",
	"Warlord",
	"Overdrive",
}
local KINDS = {
	{ "trail", TRAILS },
	{ "skin", SKINS },
	{ "effect", EFFECTS },
	{ "banner", BANNERS },
	{ "title", TITLES },
}

Ladder.steps = {}
for i = 1, 100 do
	local big = i % 10 == 0
	local kind, names
	if big then
		-- every 10th: a title (10, 20, ... 100: Recruit to Overdrive)
		kind, names = "title", TITLES
	else
		local k = KINDS[(i - 1) % 4 + 1] -- trail, skin, effect, banner in turn
		kind, names = k[1], k[2]
	end
	local index
	if big then
		index = i // 10
	else
		local n = 0
		for j = 1, i do
			if j % 10 ~= 0 and KINDS[(j - 1) % 4 + 1][1] == kind then
				n += 1
			end
		end
		index = (n - 1) % #names + 1
		local lap = (n - 1) // #names + 1
		if lap > 1 then
			-- (later laps of the same names are upgraded versions: "Comet II", "Comet III")
			names = table.clone(names)
			names[index] = names[index] .. " " .. string.rep("I", lap)
		end
	end
	table.insert(Ladder.steps, { win = i, kind = kind, key = `{kind}_{i}`, name = names[index], big = big })
end

function Ladder.at(wins)
	return Ladder.steps[wins]
end

-- What you have unlocked with this many qualifying wins.
function Ladder.unlocked(wins)
	local out = {}
	for i = 1, math.min(wins or 0, #Ladder.steps) do
		table.insert(out, Ladder.steps[i])
	end
	return out
end

return Ladder
