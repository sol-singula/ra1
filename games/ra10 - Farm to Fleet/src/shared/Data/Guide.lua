--[[
The guide (master plan §9): one line, one arrow, one target, always. Chapter by chapter it walks a player through
the whole game; when the scripted steps run out it keeps going with generated goals (the next upgrade on offer).
GuideService checks each step against the profile; the client draws the card, an arrow over the target and a path
on the ground to it.

  Guide.STEPS    { { key, text, target, done = { kind, ... }, reward = { cash?, xp? } } } in order
     target: "soil1" (the first soil tile) | "soil" (the nearest tile that needs something) | "stand" | "pad:<key>"
             (the buy-pad offering that upgrade) | "pen:<animal>" (that pen's pad) | "pack" (the shed's PACK ORDERS
             pad) | "board" (the order board) | "door" (the shed's loading door) | "station" (the bottleneck's station
             pad) | "station:<track>" | "flow:pack" | "flow:store" | "flow:ship" (the lines, the racks, the truck door)
     done:   { kind = "stat", stat, n }   profile.stats[stat] >= n
             { kind = "owned", key }      the upgrade is bought
             { kind = "level", n }        the farm level is at least n
             { kind = "planted", n }      at least n tiles are growing right now
             { kind = "animal", key, n }  that animal is at level n or more
]]
local Guide = {}

-- stylua: ignore start
Guide.STEPS = {
	-- Chapter 1: the Shack
	{ key = "plant1",    text = "Walk to the soil and tap PLANT",               target = "soil1", done = { kind = "stat", stat = "planted", n = 1 },  reward = { xp = 2 } },
	{ key = "harvest1",  text = "It's ripe! Tap HARVEST",                        target = "soil1", done = { kind = "stat", stat = "harvested", n = 1 }, reward = { xp = 2 } },
	{ key = "plant3",    text = "Plant all 3 patches",                           target = "soil",  done = { kind = "planted", n = 3 },                  reward = { xp = 2 } },
	{ key = "harvest6",  text = "Harvest 6 strawberries",                        target = "soil",  done = { kind = "stat", stat = "harvested", n = 6 }, reward = { xp = 3 } },
	{ key = "sell1",     text = "Take them to your farm stand to sell",          target = "stand", done = { kind = "stat", stat = "sold", n = 1 },      reward = { cash = 5 } },
	{ key = "soil4",     text = "Stand on the pad to buy More Soil",             target = "pad:soil4", done = { kind = "owned", key = "soil4" },         reward = { xp = 3 } },
	{ key = "soil5",     text = "More soil, more strawberries!",                 target = "pad:soil5", done = { kind = "owned", key = "soil5" },         reward = { xp = 3 } },
	{ key = "well",      text = "Buy the Water Well",                            target = "pad:well",  done = { kind = "owned", key = "well" },          reward = { xp = 5 } },
	{ key = "water1",    text = "Plant, then tap WATER: it grows twice as fast", target = "soil",  done = { kind = "stat", stat = "watered", n = 1 },   reward = { xp = 3 } },
	{ key = "level2",    text = "Keep harvesting to reach Farm Level 2",         target = "soil",  done = { kind = "level", n = 2 },                    reward = { cash = 10 } },
	{ key = "carrot",    text = "Carrots unlocked! Plant a carrot",              target = "soil",  done = { kind = "stat", stat = "carrots", n = 1 },  reward = { xp = 5 } },
	{ key = "soil6",     text = "Buy More Soil",                                 target = "pad:soil6", done = { kind = "owned", key = "soil6" },         reward = { xp = 3 } },
	{ key = "wheelbarrow", text = "Buy the Wheelbarrow: carry 3x as much",      target = "pad:wheelbarrow", done = { kind = "owned", key = "wheelbarrow" }, reward = { xp = 5 } },
	{ key = "fence",     text = "Make it yours: buy the Picket Fence",           target = "pad:fence", done = { kind = "owned", key = "fence" },         reward = { xp = 5 } },
	{ key = "soil9",     text = "Grow your field to 9 patches",                  target = "pad:soil9", done = { kind = "owned", key = "soil9" },         reward = { cash = 25 } },
	{ key = "sprinkler", text = "Buy Sprinklers: everything starts watered",     target = "pad:sprinkler", done = { kind = "owned", key = "sprinkler" }, reward = { xp = 10 } },
	{ key = "awning",    text = "Buy the Stand Awning: +25% on every sale",      target = "pad:awning", done = { kind = "owned", key = "awning" },       reward = { xp = 10 } },
	{ key = "soil12",    text = "Fill your field: 12 patches",                   target = "pad:soil12", done = { kind = "owned", key = "soil12" },       reward = { cash = 50 } },
	{ key = "scarecrow", text = "Buy the Scarecrow: golden crops show up more",  target = "pad:scarecrow", done = { kind = "owned", key = "scarecrow" }, reward = { xp = 10 } },
	{ key = "barn",      text = "Save up and BUILD THE BARN!",                   target = "pad:barnDeed", done = { kind = "owned", key = "barnDeed" },   reward = { cash = 100, xp = 25 } },
	-- Chapter 2: the Farm
	{ key = "bigBarn",   text = "Build The Big Barn: carry 150 crops",           target = "pad:barn",   done = { kind = "owned", key = "barn" },       reward = { xp = 20 } },
	{ key = "field1",    text = "Buy the Corn Field: 9 more patches",            target = "pad:field1", done = { kind = "owned", key = "field1" },     reward = { xp = 20 } },
	{ key = "corn",      text = "Plant corn in your new field",                  target = "soil",       done = { kind = "stat", stat = "corns", n = 1 }, reward = { xp = 10 } },
	{ key = "coop",      text = "Buy the Chicken Coop: chickens make crops grow faster", target = "pad:chickenCoop", done = { kind = "owned", key = "chickenCoop" }, reward = { xp = 25 } },
	{ key = "feed",      text = "Bring 5 crops to the coop's pad to feed them",  target = "pen:chicken", done = { kind = "stat", stat = "fed", n = 1 },  reward = { xp = 10 } },
	{ key = "eggs",      text = "Collect eggs at the coop's pad",                target = "pen:chicken", done = { kind = "stat", stat = "eggs", n = 1 }, reward = { xp = 10 } },
	{ key = "sellEggs",  text = "Sell your eggs at the farm stand",              target = "stand",      done = { kind = "stat", stat = "soldProducts", n = 1 }, reward = { cash = 100 } },
	{ key = "tractor",   text = "Buy the Tractor: it harvests and plants for you", target = "pad:tractor", done = { kind = "owned", key = "tractor" },   reward = { xp = 30 } },
	{ key = "field2",    text = "Buy the Big Field",                             target = "pad:field2", done = { kind = "owned", key = "field2" },     reward = { xp = 20 } },
	{ key = "conveyor",  text = "Buy the Conveyor Belt: it sells for you",       target = "pad:conveyor", done = { kind = "owned", key = "conveyor" }, reward = { xp = 30 } },
	{ key = "chicken2",  text = "Upgrade your chickens at the coop's pad",       target = "pen:chicken", done = { kind = "animal", key = "chicken", n = 2 }, reward = { xp = 25 } },
	{ key = "pigs",      text = "Buy the Pig Pen: vegetables sell for more",     target = "pad:pigPen", done = { kind = "owned", key = "pigPen" },     reward = { xp = 30 } },
	{ key = "silo",      text = "Buy the Grain Silo: carry 300",                 target = "pad:silo",   done = { kind = "owned", key = "silo" },       reward = { xp = 20 } },
	{ key = "field3",    text = "Buy the Huge Field",                            target = "pad:field3", done = { kind = "owned", key = "field3" },     reward = { cash = 500 } },
	{ key = "sheep",     text = "Buy the Sheep Pasture: machines work faster",   target = "pad:sheepPen", done = { kind = "owned", key = "sheepPen" }, reward = { xp = 40 } },
	{ key = "windmill",  text = "Buy the Windmill",                              target = "pad:windmill", done = { kind = "owned", key = "windmill" }, reward = { xp = 20 } },
	{ key = "cows",      text = "Buy the Cow Pasture: fruit grows faster",       target = "pad:cowBarn", done = { kind = "owned", key = "cowBarn" },   reward = { xp = 50 } },
	{ key = "shed",      text = "Save up and BUILD THE PACKING SHED!",           target = "pad:shedDeed", done = { kind = "owned", key = "shedDeed" }, reward = { cash = 1000, xp = 100 } },
	-- Chapter 3: the Packing Shed
	{ key = "shedBuild", text = "Build The Packing Shed: customers will order your crops", target = "pad:shed", done = { kind = "owned", key = "shed" }, reward = { xp = 40 } },
	{ key = "pack1",     text = "Grow what the order board asks for, then stand on PACK ORDERS", target = "pack", done = { kind = "stat", stat = "packed", n = 1 }, reward = { xp = 10 } },
	{ key = "packFull",  text = "Pack a whole order: every crop on its list",    target = "pack",       done = { kind = "stat", stat = "ordersPacked", n = 1 }, reward = { xp = 20 } },
	{ key = "ship1",     text = "The buyer's pickup is coming for it: watch it go!", target = "door",  done = { kind = "stat", stat = "shipments", n = 1 }, reward = { cash = 500 } },
	{ key = "yard",      text = "Buy the Paved Yard",                            target = "pad:yard",   done = { kind = "owned", key = "yard" },       reward = { xp = 20 } },
	{ key = "van",       text = "Buy the Delivery Van: orders ship twice as fast", target = "pad:van",  done = { kind = "owned", key = "van" },        reward = { xp = 40 } },
	{ key = "ship3",     text = "Fill and ship 3 orders",                        target = "pack",       done = { kind = "stat", stat = "shipments", n = 3 }, reward = { cash = 1000 } },
	{ key = "orderBoard", text = "Buy the Big Order Board: 3 orders at once",    target = "pad:orderBoard", done = { kind = "owned", key = "orderBoard" }, reward = { xp = 40 } },
	{ key = "contract1", text = "Finish a daily contract (the list under your orders)", target = "board", done = { kind = "stat", stat = "contracts", n = 1 }, reward = { xp = 30 } },
	{ key = "boxLine",   text = "Buy the Box Line: it packs orders for you",     target = "pad:boxLine", done = { kind = "owned", key = "boxLine" },   reward = { xp = 50 } },
	{ key = "sorter",    text = "Buy the Sorting Machine: orders pay +15%",      target = "pad:sorter", done = { kind = "owned", key = "sorter" },     reward = { xp = 50 } },
	{ key = "loadingDock", text = "Buy the Loading Dock: trips are quicker",     target = "pad:loadingDock", done = { kind = "owned", key = "loadingDock" }, reward = { xp = 50 } },
	{ key = "ship10",    text = "Ship 10 orders",                                target = "pack",       done = { kind = "stat", stat = "shipments", n = 10 }, reward = { cash = 3000 } },
	{ key = "wrapper",   text = "Buy the Pallet Wrapper: orders pay +15% more",  target = "pad:wrapper", done = { kind = "owned", key = "wrapper" },   reward = { xp = 60 } },
	{ key = "van2",      text = "Buy a Second Van: two orders on the road at once", target = "pad:van2", done = { kind = "owned", key = "van2" },      reward = { xp = 80 } },
	{ key = "warehouse", text = "Save up and BUILD THE WAREHOUSE!",              target = "pad:warehouseDeed", done = { kind = "owned", key = "warehouseDeed" }, reward = { cash = 5000, xp = 200 } },
	-- Chapter 4: the Warehouse (then the guide follows the bottleneck: master plan §13.2)
	{ key = "warehouseBuild", text = "Build The Warehouse: your crops become pallets that ship by the truckload", target = "pad:warehouse", done = { kind = "owned", key = "warehouse" }, reward = { xp = 100 } },
	{ key = "pallet1",   text = "The conveyor feeds the warehouse now: watch the lines pack your first pallet", target = "flow:pack", done = { kind = "stat", stat = "pallets", n = 1 }, reward = { xp = 20 } },
	{ key = "racked1",   text = "A forklift puts it on the racks",               target = "flow:store", done = { kind = "stat", stat = "racked", n = 1 }, reward = { xp = 20 } },
	{ key = "shipped1",  text = "A box truck takes pallets to market: wait for it to come back and pay", target = "flow:ship", done = { kind = "stat", stat = "palletsShipped", n = 1 }, reward = { cash = 20000 } },
	{ key = "fix1",      text = "The red bar is your BOTTLENECK: fix it at its red pad", target = "station", done = { kind = "stat", stat = "fixes", n = 1 }, reward = { xp = 60 } },
	{ key = "fix3",      text = "Fix 3 bottlenecks: each fix moves the jam somewhere new", target = "station", done = { kind = "stat", stat = "fixes", n = 3 }, reward = { cash = 100000 } },
}
-- stylua: ignore end

Guide.byKey = {}
for i, s in Guide.STEPS do
	s.index = i
	Guide.byKey[s.key] = s
end

return Guide
