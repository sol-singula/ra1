--[[
The guide (master plan §9): one line, one arrow, one target, always. Chapter by chapter it walks a player through
the whole game; when the scripted steps run out it keeps going with generated goals (the next upgrade on offer).
GuideService checks each step against the profile; the client draws the card, an arrow over the target and a path
on the ground to it.

  Guide.STEPS    { { key, text, target, done = { kind, ... }, reward = { cash?, xp? } } } in order; each also gets
                 index, chapter, n (its number in the chapter) and button ("act" | "menu:<name>" | nil)
  Guide.CHAPTERS / Guide.CHAPTER_SIZE[chapter]
     target: "soil1" (the first soil tile) | "soil" (the nearest tile that needs something) | "stand" | "pad:<key>"
             (the buy-pad offering that upgrade) | "pen:<animal>" (that pen's pad) | "board" (the order board) |
             "door" (the shed's loading door) | "station:<track>" (a warehouse station's pad) | "flow:pack" |
             "flow:store" | "flow:ship" (the lines, the racks, the truck door)
     done:   { kind = "stat", stat, n }   profile.stats[stat] >= n
             { kind = "owned", key }      the upgrade is bought
             { kind = "level", n }        the farm level is at least n
             { kind = "planted", n }      at least n tiles are growing right now
             { kind = "animal", key, n }  that animal is at level n or more
]]
local Guide = {}

-- stylua: ignore start
Guide.STEPS = {
	-- Chapter 1: the Shack (plant, pick, sell, buy more soil)
	{ key = "plant1",    text = "Tap PLANT by the glowing soil",                 target = "soil1", done = { kind = "stat", stat = "planted", n = 1 },  reward = { xp = 2 } },
	{ key = "harvest1",  text = "It's ripe! Tap PICK",                           target = "soil1", done = { kind = "stat", stat = "harvested", n = 1 }, reward = { xp = 2 } },
	{ key = "plant3",    text = "Plant all 3 patches",                           target = "soil",  done = { kind = "planted", n = 3 },                  reward = { xp = 2 } },
	{ key = "tend1",     text = "Tap TEND: your crops grow 2x faster",           target = "soil",  done = { kind = "stat", stat = "tended", n = 1 },   reward = { xp = 2 } },
	{ key = "harvest6",  text = "Pick 6 strawberries",                           target = "soil",  done = { kind = "stat", stat = "harvested", n = 6 }, reward = { xp = 3 } },
	{ key = "sell1",     text = "Step on SELL by your stand: crops turn into Cash", target = "stand", done = { kind = "stat", stat = "sold", n = 1 },   reward = { cash = 5 } },
	{ key = "soil4",     text = "Step on the glowing pad: More Soil",             target = "pad:soil4", done = { kind = "owned", key = "soil4" },         reward = { xp = 3 } },
	{ key = "soil5",     text = "More soil = more Cash. Buy it!",                target = "pad:soil5", done = { kind = "owned", key = "soil5" },         reward = { xp = 3 } },
	{ key = "well",      text = "Buy the Water Well: crops grow faster",         target = "pad:well",  done = { kind = "owned", key = "well" },          reward = { xp = 5 } },
	{ key = "level2",    text = "Pick and sell to reach Level 2",                target = "soil",  done = { kind = "level", n = 2 },                    reward = { cash = 10 } },
	{ key = "carrot",    text = "Reach Level 4: carrots unlock. They pay more!", target = "soil",  done = { kind = "level", n = 4 },                    reward = { xp = 5 } },
	{ key = "soil6",     text = "Buy More Soil",                                 target = "pad:soil6", done = { kind = "owned", key = "soil6" },         reward = { xp = 3 } },
	{ key = "wheelbarrow", text = "Buy the Wheelbarrow: carry 3x as much",       target = "pad:wheelbarrow", done = { kind = "owned", key = "wheelbarrow" }, reward = { xp = 5 } },
	{ key = "fence",     text = "Make it yours: buy the White Fence",            target = "pad:fence", done = { kind = "owned", key = "fence" },         reward = { xp = 5 } },
	{ key = "soil9",     text = "Grow your field to 9 patches",                  target = "pad:soil9", done = { kind = "owned", key = "soil9" },         reward = { cash = 25 } },
	{ key = "sprinkler", text = "Buy Sprinklers: every crop grows faster",       target = "pad:sprinkler", done = { kind = "owned", key = "sprinkler" }, reward = { xp = 10 } },
	{ key = "awning",    text = "Buy the Stand Roof: every sale pays more",      target = "pad:awning", done = { kind = "owned", key = "awning" },       reward = { xp = 10 } },
	{ key = "soil12",    text = "Fill your field: 12 patches",                   target = "pad:soil12", done = { kind = "owned", key = "soil12" },       reward = { cash = 50 } },
	{ key = "scarecrow", text = "Buy the Scarecrow: more golden crops",          target = "pad:scarecrow", done = { kind = "owned", key = "scarecrow" }, reward = { xp = 10 } },
	{ key = "barn",      text = "Save up and BUILD THE BARN!",                   target = "pad:barnDeed", done = { kind = "owned", key = "barnDeed" },   reward = { cash = 100, xp = 25 } },
	-- Chapter 2: the Farm (the barn keeps crops, the tractor picks, the animals boost, the helper sells)
	{ key = "bigBarn",   text = "Build the Barn: it keeps 400 crops for you",     target = "pad:barn",   done = { kind = "owned", key = "barn" },       reward = { xp = 20 } },
	{ key = "field1",    text = "Buy the Bigger Field: more patches",            target = "pad:field1", done = { kind = "owned", key = "field1" },     reward = { xp = 20 } },
	{ key = "coop",      text = "Buy the Chicken Coop: chickens make crops grow faster", target = "pad:chickenCoop", done = { kind = "owned", key = "chickenCoop" }, reward = { xp = 25 } },
	{ key = "feed",      text = "Walk to the coop and tap FEED (it's free)",     target = "pen:chicken", done = { kind = "stat", stat = "fed", n = 1 },  reward = { xp = 10 } },
	{ key = "tendPen",   text = "Tap TEND at the coop: happy chickens boost 2x", target = "pen:chicken", done = { kind = "stat", stat = "tendedAnimals", n = 1 }, reward = { xp = 10 } },
	{ key = "tractor",   text = "Buy the Tractor: it picks and plants for you",  target = "pad:tractor", done = { kind = "owned", key = "tractor" },   reward = { xp = 30 } },
	{ key = "drive",     text = "Hop on your tractor: DRIVE it over ripe crops", target = "tractor",    done = { kind = "stat", stat = "driven", n = 1 }, reward = { cash = 200 } },
	{ key = "field2",    text = "Buy the Big Field",                             target = "pad:field2", done = { kind = "owned", key = "field2" },     reward = { xp = 20 } },
	{ key = "shopkeeper", text = "Buy the Shop Helper: sells your crops for you", target = "pad:shopkeeper", done = { kind = "owned", key = "shopkeeper" }, reward = { xp = 30 } },
	{ key = "chicken2",  text = "Upgrade your chickens at the coop: a bigger boost", target = "pen:chicken", done = { kind = "animal", key = "chicken", n = 2 }, reward = { xp = 25 } },
	{ key = "pigs",      text = "Buy the Pig Pen: vegetables sell for more",     target = "pad:pigPen", done = { kind = "owned", key = "pigPen" },     reward = { xp = 30 } },
	{ key = "tractor2",  text = "Buy the Bigger Tractor: picks 2 patches at once", target = "pad:tractor2", done = { kind = "owned", key = "tractor2" }, reward = { xp = 20 } },
	{ key = "bigBarn2",  text = "Buy the Big Barn: keeps 1500 crops",            target = "pad:bigBarn", done = { kind = "owned", key = "bigBarn" },   reward = { xp = 20 } },
	{ key = "field3",    text = "Buy the Huge Field",                            target = "pad:field3", done = { kind = "owned", key = "field3" },     reward = { cash = 500 } },
	{ key = "sheep",     text = "Buy the Sheep Pen: the tractor works faster",   target = "pad:sheepPen", done = { kind = "owned", key = "sheepPen" }, reward = { xp = 40 } },
	{ key = "tractor3",  text = "Buy the Big Tractor: picks 3 patches at once",  target = "pad:tractor3", done = { kind = "owned", key = "tractor3" }, reward = { xp = 30 } },
	{ key = "windmill",  text = "Buy the Windmill",                              target = "pad:windmill", done = { kind = "owned", key = "windmill" }, reward = { xp = 20 } },
	{ key = "cows",      text = "Buy the Cow Barn: fruit grows faster",          target = "pad:cowBarn", done = { kind = "owned", key = "cowBarn" },   reward = { xp = 50 } },
	{ key = "shed",      text = "Save up and BUILD THE SHED: deliveries pay 3x!", target = "pad:shedDeed", done = { kind = "owned", key = "shedDeed" }, reward = { cash = 1000, xp = 100 } },
	-- Chapter 3: the Packing Shed (orders fill themselves from the barn; each pays much more than the stand)
	{ key = "shedBuild", text = "Build the Shed: buyers order your crops and pay 3x", target = "pad:shed", done = { kind = "owned", key = "shed" }, reward = { xp = 40 } },
	{ key = "pack1",     text = "Orders fill themselves from your barn: just keep growing", target = "board", done = { kind = "stat", stat = "packed", n = 1 }, reward = { xp = 10 } },
	{ key = "ship1",     text = "The buyer picks it up: watch the Cash come in", target = "door",      done = { kind = "stat", stat = "shipments", n = 1 }, reward = { cash = 500 } },
	{ key = "van",       text = "Buy the Van: deliveries go faster",             target = "pad:van",   done = { kind = "owned", key = "van" },        reward = { xp = 40 } },
	{ key = "ship3",     text = "Deliver 3 orders",                              target = "board",     done = { kind = "stat", stat = "shipments", n = 3 }, reward = { cash = 1000 } },
	{ key = "orderBoard", text = "Buy the Big Order Board: 3 orders at once",    target = "pad:orderBoard", done = { kind = "owned", key = "orderBoard" }, reward = { xp = 40 } },
	{ key = "boxLine",   text = "Buy the Box Line: orders pack 3x faster",       target = "pad:boxLine", done = { kind = "owned", key = "boxLine" },   reward = { xp = 50 } },
	{ key = "tractor4",  text = "Buy the Huge Tractor: picks 4 patches at once", target = "pad:tractor4", done = { kind = "owned", key = "tractor4" }, reward = { xp = 50 } },
	{ key = "sorter",    text = "Buy the Sorter: orders pay more",               target = "pad:sorter", done = { kind = "owned", key = "sorter" },     reward = { xp = 50 } },
	{ key = "loadingDock", text = "Buy the Big Door: trucks load faster",        target = "pad:loadingDock", done = { kind = "owned", key = "loadingDock" }, reward = { xp = 50 } },
	{ key = "ship10",    text = "Deliver 10 orders",                             target = "board",     done = { kind = "stat", stat = "shipments", n = 10 }, reward = { cash = 3000 } },
	{ key = "wrapper",   text = "Buy the Wrapper: orders pay even more",         target = "pad:wrapper", done = { kind = "owned", key = "wrapper" },   reward = { xp = 60 } },
	{ key = "tractor5",  text = "Buy the Mega Tractor: picks 5 patches at once", target = "pad:tractor5", done = { kind = "owned", key = "tractor5" }, reward = { xp = 60 } },
	{ key = "van2",      text = "Buy a Second Van: two deliveries at once",      target = "pad:van2",  done = { kind = "owned", key = "van2" },      reward = { xp = 80 } },
	{ key = "secondTractor", text = "Buy a Second Tractor: two pick at once",    target = "pad:secondTractor", done = { kind = "owned", key = "secondTractor" }, reward = { xp = 80 } },
	{ key = "warehouse", text = "Save up and BUILD THE WAREHOUSE: trucks pay 6x!", target = "pad:warehouseDeed", done = { kind = "owned", key = "warehouseDeed" }, reward = { cash = 5000, xp = 200 } },
	-- Chapter 4: the Warehouse (crops become pallets, trucks sell them by the load)
	{ key = "warehouseBuild", text = "Build the Warehouse: your extra crops ship by the truckload", target = "pad:warehouse", done = { kind = "owned", key = "warehouse" }, reward = { xp = 100 } },
	{ key = "pallet1",   text = "The barn's extra crops go in the door: watch the first pallet get packed", target = "flow:pack", done = { kind = "stat", stat = "pallets", n = 1 }, reward = { xp = 20 } },
	{ key = "racked1",   text = "A forklift puts it on the shelves",             target = "flow:store", done = { kind = "stat", stat = "racked", n = 1 }, reward = { xp = 20 } },
	{ key = "shipped1",  text = "A truck takes pallets to market and pays when it's back", target = "flow:ship", done = { kind = "stat", stat = "palletsShipped", n = 1 }, reward = { cash = 20000 } },
	{ key = "pickCrop",  text = "You pick what to grow now: tap a crop along the bottom", target = "soil", done = { kind = "stat", stat = "picked", n = 1 }, reward = { xp = 60 } },
	{ key = "calendar1", text = "Tap DAILY (top right) and claim today's gift",  target = "menu:calendar", done = { kind = "stat", stat = "calendar", n = 1 }, reward = { xp = 50 } },
	{ key = "visit1",    text = "Tap STREET and VISIT a neighbour's farm",       target = "menu:street", done = { kind = "stat", stat = "visits", n = 1 }, reward = { xp = 50 } },
	{ key = "like1",     text = "LIKE a farm you like on the STREET board",      target = "menu:street", done = { kind = "stat", stat = "likesGiven", n = 1 }, reward = { cash = 20000 } },
	{ key = "hub",       text = "Save up and BUILD THE HUB: giant trucks!",      target = "pad:hubDeed", done = { kind = "owned", key = "hubDeed" }, reward = { cash = 250000, xp = 500 } },
	-- Chapter 5: the Distribution Hub
	{ key = "backDocks", text = "Build the Back Doors: trucks load at the back", target = "pad:backDocks", done = { kind = "owned", key = "backDocks" }, reward = { xp = 200 } },
	{ key = "frontHall", text = "Build the Front Hall over the old shed",        target = "pad:frontHall", done = { kind = "owned", key = "frontHall" }, reward = { xp = 200 } },
	{ key = "tower",     text = "Build the Tower: orders pay more",              target = "pad:controlTower", done = { kind = "owned", key = "controlTower" }, reward = { xp = 250 } },
	{ key = "solar",     text = "Put the Solar Roof up: the lines pack faster",  target = "pad:solarRoof", done = { kind = "owned", key = "solarRoof" }, reward = { xp = 250 } },
	{ key = "market",    text = "Build the Market Hall over the old stand",      target = "pad:marketHall", done = { kind = "owned", key = "marketHall" }, reward = { xp = 300 } },
	{ key = "semi1",     text = "Buy the Giant Truck at the SHIP pad",           target = "station:ship", done = { kind = "owned", key = "semi1" }, reward = { xp = 300 } },
	{ key = "semiTrip",  text = "Watch your giant truck back up and ship 24 pallets", target = "flow:ship", done = { kind = "stat", stat = "semis", n = 1 }, reward = { cash = 1000000 } },
	-- Chapter 6: Franchise
	{ key = "franchise1", text = "Tap FRANCHISE: sell the company for Stars and start bigger in a new region", target = "menu:franchise", done = { kind = "stat", stat = "franchises", n = 1 }, reward = { xp = 1000 } },
	{ key = "perk1",     text = "Spend your Stars on a perk in the FRANCHISE panel", target = "menu:franchise", done = { kind = "stat", stat = "perks", n = 1 }, reward = { xp = 200 } },
}
Guide.CHAPTERS = { "THE SHACK", "THE FARM", "THE PACKING SHED", "THE WAREHOUSE", "THE HUB", "FRANCHISE" }
-- stylua: ignore end

-- Chapters: each starts at its first step; a step knows its chapter and its number in it (STEP 3 of 20)
Guide.CHAPTER_FIRST = { plant1 = 1, bigBarn = 2, shedBuild = 3, warehouseBuild = 4, backDocks = 5, franchise1 = 6 }
Guide.CHAPTER_SIZE = {}

Guide.byKey = {}
local chapter, n = 1, 0
for i, s in Guide.STEPS do
	s.index = i
	Guide.byKey[s.key] = s
	if Guide.CHAPTER_FIRST[s.key] then
		chapter, n = Guide.CHAPTER_FIRST[s.key], 0
	end
	n += 1
	s.chapter, s.n = chapter, n
	Guide.CHAPTER_SIZE[chapter] = n
	-- the button the step needs (it pulses): the farm's PLANT/PICK/TEND button by the soil, a menu button
	if string.sub(s.target, 1, 4) == "soil" then
		s.button = "act"
	elseif string.sub(s.target, 1, 5) == "menu:" then
		s.button = s.target
	end
end

return Guide
