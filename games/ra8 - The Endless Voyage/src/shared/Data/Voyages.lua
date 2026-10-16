--[[
Where the ocean goes (master plan §9, §10): the destinations, what each is for, and what can happen on the way.
The raft never leaves its plot: when a voyage arrives, the destination is built beside it (IslandBuilder), and it
goes back under the water when you sail home.

  kind       island | wreck | deep
  template   the IslandBuilder template
  distance   1-7: seconds at sea = distance x VOYAGE_SECONDS_PER_DISTANCE / the raft's speed
  danger     1-5: the raft tier that may sail there (Constants.DANGER_BY_TIER), what can attack on the way
  known      true: on every map from the start
  found      how its chart turns up: "crate" (supply crates in waters of this danger), "bottle", "nest" (the
             crow's nest), "logbook" / "idol" (reading an artifact), "research" (a milestone)
  resources  what's there to gather; finds: what its containers hold beyond the usual; creatures: who lives there
  puzzle     an environmental puzzle with a reward: "lanterns" (light three), "totems" (turn three to face the sea)
]]
local Voyages = {}

Voyages.list = {
	{
		key = "palm_key",
		name = "Palm Key",
		icon = "🏝️",
		kind = "island",
		template = "tropical",
		distance = 1,
		danger = 1,
		known = true,
		resources = { "wood", "palm", "coconut", "fiber", "berries", "stone" },
		creatures = { "reef_crab" },
		finds = { "chart" },
		landmark = "an old campfire with a note",
		desc = "Wood, palms, coconuts. A good first trip.",
	},
	{
		key = "gull_rock",
		name = "Gull Rock",
		icon = "⛰️",
		kind = "island",
		template = "rocky",
		distance = 2,
		danger = 1,
		found = "crate",
		resources = { "stone", "ore", "scrap", "metal" },
		creatures = { "gull", "reef_crab" },
		finds = { "relic" },
		landmark = "a rusted beacon",
		desc = "Stone and ore. Mind the gulls.",
	},
	{
		key = "drift_wreck",
		name = "The Drifter",
		icon = "🚢",
		kind = "wreck",
		template = "surface_wreck",
		distance = 2,
		danger = 1,
		found = "guide",
		resources = { "scrap", "metal", "rope", "cloth" },
		creatures = {},
		finds = { "relic", "chart", "old_compass" },
		landmark = "a ship on its side, half under",
		desc = "A wreck on the surface. Pry it open.",
	},
	{
		key = "mist_hollow",
		name = "Mist Hollow",
		icon = "🌫️",
		kind = "island",
		template = "foggy",
		distance = 3,
		danger = 2,
		found = "crate",
		resources = { "scrap", "metal", "rope", "fiber", "wood" },
		creatures = { "mire_lurker" },
		finds = { "ship_bell", "logbook", "blueprint" },
		puzzle = "lanterns",
		landmark = "huts nobody left in a hurry",
		desc = "Fog, old huts, something in the reeds.",
	},
	{
		key = "ember_isle",
		name = "Ember Isle",
		icon = "🌋",
		kind = "island",
		template = "volcanic",
		distance = 4,
		danger = 3,
		found = "crate",
		resources = { "heat_crystal", "ore", "stone" },
		creatures = { "lava_beetle" },
		finds = { "relic", "blueprint" },
		landmark = "a cave that breathes warm air",
		desc = "Heat crystals. Hot ground. Beetles.",
	},
	{
		key = "frost_shelf",
		name = "Frost Shelf",
		icon = "🧊",
		kind = "island",
		template = "frozen",
		distance = 5,
		danger = 3,
		found = "bottle",
		resources = { "frost_crystal", "ore", "stone" },
		creatures = { "frost_wolf" },
		finds = { "old_compass", "blueprint" },
		landmark = "a ship frozen into the ice",
		desc = "Frost crystals. Wolves hunt in threes.",
	},
	{
		key = "marrow_wreck",
		name = "The Marrow",
		icon = "⚓",
		kind = "wreck",
		template = "deep_wreck",
		distance = 4,
		danger = 3,
		found = "logbook",
		resources = { "metal", "gear", "old_tech", "scrap" },
		creatures = { "mire_lurker" },
		finds = { "logbook", "tooth", "blueprint" },
		landmark = "a hidden room behind the galley",
		desc = "A big ship, mostly sunk. A room nobody found.",
	},
	{
		key = "overgrown_ruin",
		name = "The Overgrown Ruin",
		icon = "🏛️",
		kind = "island",
		template = "ruin",
		distance = 6,
		danger = 4,
		found = "nest",
		resources = { "old_tech", "gear", "stone", "wood" },
		creatures = { "mire_lurker", "ruin_guardian" },
		finds = { "idol", "blueprint" },
		puzzle = "totems",
		landmark = "three totems that face the wrong way",
		desc = "Old tech under the vines. Something guards it.",
	},
	{
		key = "the_trench",
		name = "The Trench",
		icon = "🌊",
		kind = "deep",
		template = "trench",
		distance = 7,
		danger = 5,
		found = "idol",
		resources = {},
		creatures = { "leviathan" },
		finds = { "leviathan_scale", "tooth" },
		landmark = "the water goes black",
		desc = "Where the enormous thing lives.",
	},
}

Voyages.byKey = {}
for _, d in Voyages.list do
	Voyages.byKey[d.key] = d
end

-- What can happen while sailing (§10: travel is an activity). Weighted by the waters' danger.
Voyages.EVENTS = {
	{
		key = "debris_lane",
		name = "A debris lane",
		icon = "🌊",
		minDanger = 1,
		weight = 3,
		seconds = 22,
		desc = "Wood and scrap drifting past: reel it in while it lasts.",
	},
	{
		key = "supply_drop",
		name = "A supply crate",
		icon = "📦",
		minDanger = 1,
		weight = 2,
		seconds = 30,
		desc = "A crate in the water. Cast for it before it's gone.",
	},
	{
		key = "bottle",
		name = "A bottle",
		icon = "🍾",
		minDanger = 1,
		weight = 1,
		seconds = 30,
		desc = "Something floats by with a note in it.",
	},
	{
		key = "calm",
		name = "Dolphins",
		icon = "🐬",
		minDanger = 1,
		weight = 2,
		seconds = 14,
		desc = "A pod rides the bow wave.",
	},
	{
		key = "storm",
		name = "A storm",
		icon = "⛈️",
		minDanger = 1,
		weight = 2,
		dangerWeight = 1,
		seconds = 26,
		desc = "Waves over the deck. Railings and an anchor hold it together; a hammer fixes what breaks.",
	},
	{
		key = "shadow",
		name = "Something enormous",
		icon = "🐋",
		minDanger = 2,
		weight = 1,
		seconds = 12,
		desc = "A shadow longer than the raft passes under it.",
	},
	{
		key = "shark",
		name = "Sharks",
		icon = "🦈",
		minDanger = 2,
		weight = 3,
		seconds = 40,
		desc = "They bite the edges. Spikes, spears and harpoons.",
	},
	{
		key = "serpent",
		name = "A sea serpent",
		icon = "🐍",
		minDanger = 3,
		weight = 2,
		seconds = 45,
		desc = "Bigger than a shark. Harpoons.",
	},
	{
		key = "whirlpool",
		name = "A whirlpool",
		icon = "🌀",
		minDanger = 4,
		weight = 1,
		seconds = 16,
		desc = "The raft spins; loose tiles crack. An anchor holds.",
	},
}

function Voyages.get(key)
	return Voyages.byKey[key]
end

return Voyages
