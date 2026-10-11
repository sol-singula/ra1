# Gameplay screenshots

Frames from a real session of the game in `game/`. The actual server and client scripts ran on the mock engine
(`tests/mock/Engine.luau`), and a bot played through the real prompts, remotes and UI buttons. Everything in each
frame was produced by the game code: the restaurant, the stations, customers and their bubbles, prompts, the HUD,
panels, and every number in them. Three things are stand-ins:

- **The renderer:** three.js in headless Chromium (`tools/gameplay/`), so lighting and materials only approximate
  Roblox Studio.
- **The avatar:** a blocky placeholder, because Roblox would load your own.
- **The Roblox top-bar icons.**

Regenerate with:

```bash
tools/luaurun/target/release/luaurun tools/gameplay/session.luau <jsonDir>
node tools/gameplay/render.js <jsonDir> <pngDir> --modules <node_modules with puppeteer, three@0.149.0, @fontsource/fredoka, @fontsource/luckiest-guy>
```

### 1. First join: pick a free mutation

![First join: pick a free mutation](01_first_join_mutation_pick.jpg)

Octopus Arm, Crab Claw Arm or Wrench Claw Arm. The bot picks the Octopus Arm.

### 2. The Pantry

![The Pantry](02_pantry.jpg)

The panel lists every ingredient on the current menu. The purple Octopus Arm is on, and the carry bar shows 2 hands.

### 3. Two patties on the Grill

![Two patties on the Grill](03_grill.jpg)

Live doneness bars over each patty: UNDERCOOKED, then PERFECT, then BURNED.

### 4. Chopping lettuce

![Chopping lettuce](04_chopping.jpg)

Tap when the marker is in the green. Each pip shows how clean that cut was.

### 5. Building a Basic Burger

![Building a Basic Burger](05_assembly.jpg)

Patty, lettuce, bun, ketchup and pickle stacked on board 1. The prompt names the dish once the stack matches.

### 6. The first customer

![The first customer](06_customer_at_counter.jpg)

A Sleepy Sloth-Rocket at the counter: "Ready to order!" and the Take order prompt.

### 7. Serving with a special request

![Serving with a special request](07_serving.jpg)

The ticket and the bubble both show "Hold the pickles." Cheeseburger in hand, Serve prompt up.

### 8. Paid

![Paid](08_served.jpg)

+17 MB and a Delighted customer. Money, XP and reputation all come from the server's satisfaction formula.

### 9. Pouring a Fizzy Soda

![Pouring a Fizzy Soda](09_pouring_a_drink.jpg)

Stop the fill inside the green band for a Perfect drink.

### 10. Lunch rush

![Lunch rush](10_dining_room.jpg)

Three orders taken at once. The ticket rail fills up and every table has an order bubble.

### 11. Grill fire

![Grill fire](11_grill_fire.jpg)

A forgotten patty burned and caught fire. Hold the prompt to put it out.

### 12. Food fight

![Food fight](12_food_fight.jpg)

An Impatient Goblin hits anger level 3 and throws food. The plate is mid-air over the kitchen.

### 13. Fighting back

![Fighting back](13_fight.jpg)

Swipe Combo on a Sleepy Sloth-Rocket at anger level 5 ("BIF!" on the third hit). Its table is already cracked.

### 14. Dizzy

![Dizzy](14_dizzy.jpg)

Huff Points gone. The customer pays a 40 % apology and leaves.

### 15. Level 3 stats

![Level 3 stats](15_stats_panel.jpg)

The four headline stats with 4 points to spend. "More stats" opens all nine.

### 16. Repairing a destroyed table

![Repairing a destroyed table](16_broken_table_repair.jpg)

Smashed by an angry customer. Press R to rebuild it for 20 MB.

### 17. Menu editor

![Menu editor](17_menu.jpg)

Four menu slots at TIER_01. Recipes unlock by level.

### 18. Upgrade

![Upgrade](18_upgrade_panel.jpg)

Level 6 and 1,118 MB earned by the bot: ready to become the Tiny Mutation Diner.

### 19. The Tiny Mutation Diner

![The Tiny Mutation Diner](19_tiny_mutation_diner.jpg)

Six seats, five menu slots, and new customer types such as the Bodybuilder Pigeon on the ticket rail.

### 20. Restaurant Row

![Restaurant Row](20_restaurant_row.jpg)

Three players' restaurants on the street: ChefGrizzle's diner, then BoltNugget's and PixelPaws' shacks.
