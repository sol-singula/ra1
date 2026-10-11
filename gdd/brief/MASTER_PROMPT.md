# MASTER PROMPT: MYSTERY MORPH RESTAURANT

> Source brief supplied by the project owner. Preserved here verbatim in structure so every
> contributor works from the same requirements. The visual reference is the "Mystery Morph
> Restaurant" graphics sheet (panels: title art, "Wrong Order?!", "Weird Food, Weirder People",
> Taking Orders, Cooking Food, When They're Not Happy, Fights Can Happen, Customize Your Morph
> (slots: Head, Ears, Eyes, Arms, Legs, Tails, Extras), Level Up & Get Stronger (Cooking, Strength,
> Repair, Luck with "+" buttons, "Level 12"), Upgrade Your Restaurant (Basic → Expand → Go Wild),
> Explore the City (Morph City sign, Mutation Mart, Restaurant Supplies, Job Board, Arena, Body Mods),
> Example Customers (Giraffe-Squid, TV-Moth, Shark-Spider, Pigeon-Muscle, Axolotl-Cow, Bear-Scorpion,
> Snake-Rabbit, Deer-Plant, Frog-Robot, Cat-Fish)).

## Comprehensive Roblox Game Design & Development Specification

You are a multidisciplinary AAA game development team consisting of a creative director, Roblox technical architect, gameplay systems designer, economy designer, character artist, environment artist, UI/UX designer, AI behavior engineer, multiplayer systems engineer, progression designer, and live-operations strategist.

Your assignment is to design an extraordinarily comprehensive Roblox game called **MYSTERY MORPH RESTAURANT**.

- Genre: Restaurant Simulation / Cooking Chaos / Creature Collection / Character Customization / Action Combat / Tycoon / Social Multiplayer / Idle Economy
- Platform: Roblox
- Primary audience: Roblox players, approximately ages 8–16, with accessible mechanics and enough depth to retain older players.
- Visual direction: Colorful, ridiculous, exaggerated, chaotic, highly expressive, blocky 3D Roblox aesthetics.
- Core fantasy: Run a restaurant in a city populated entirely by absurd, randomly assembled mutant creatures. Cook for demanding customers, survive their tantrums, defend your restaurant, collect bizarre mutations, grow your business, hire employees, and build an increasingly powerful and ridiculous creature.

The game must be funny, visually distinctive, immediately understandable, and mechanically rewarding.

The central design principle is: **EVERYTHING SHOULD BE JUST A LITTLE BIT RIDICULOUS.** However, beneath the ridiculous presentation, the gameplay systems must be coherent, balanced, scalable, and genuinely fun.

Create a complete development-ready Markdown document named `MYSTERY_MORPH_RESTAURANT_GDD.md`.

Do not simply describe the game. Specify how to build it. Every major system must include its gameplay mechanics, rules, variables, UI, progression, player interactions, dependencies, Roblox implementation approach, edge cases, and acceptance criteria. When exact values are not established, propose sensible starting values and clearly label them as balancing assumptions. Do not leave entire systems described with vague phrases such as "implement customer AI" or "create a mutation system." Explain exactly how those systems should work.

---

## PART 1: THE GAME'S IDENTITY

### 1.1 Game Overview
The player is a newly arrived mutant in Morph City, a bizarre urban environment where every citizen is an unnatural combination of animals, objects, monsters, insects, and miscellaneous body parts. The player inherits a rundown restaurant. Their objective is to turn it into the most successful restaurant in the city.

Unfortunately, Morph City residents are extremely demanding. Customers might order a cheeseburger without cheese, insist their soup be served frozen, or become furious because their pizza is too circular.

When customers become unhappy, they can: complain dramatically; throw food; knock over furniture; break kitchen equipment; attack other customers; transform into more aggressive forms; fight the player; cause chain reactions involving other customers; damage the restaurant; leave without paying; create a restaurant-wide disaster.

The player must balance cooking, service, restaurant maintenance, fighting, upgrading, and earning money. Customers who are satisfied pay generously. Customers who are unhappy create expensive problems. Players can collect and equip mutations that make them better cooks, stronger fighters, faster repairers, and more efficient restaurant operators. Eventually, players can hire mutant employees who operate their restaurants while they are offline. Players return to collect their accumulated earnings, discover employee incidents, upgrade their businesses, and continue progressing.

### 1.2 Core Gameplay Pillars
Define these seven pillars in detail:
1. **Cook**: Prepare increasingly ridiculous meals through engaging interactive cooking mechanics.
2. **Serve**: Manage unpredictable customers with different personalities, preferences, and patience levels.
3. **Survive**: Defend yourself and your restaurant when customers become hostile.
4. **Morph**: Collect, combine, and upgrade mutations with useful gameplay abilities.
5. **Build**: Expand, decorate, repair, and automate your restaurant.
6. **Explore**: Visit Morph City to discover shops, quests, secrets, characters, and activities.
7. **Earn**: Build an increasingly profitable restaurant that continues generating income through hired staff while offline.

Explain how these systems reinforce one another. For example: Cooking generates money. Money purchases mutations. Mutations improve cooking and combat. Improved performance increases restaurant profitability. Profits fund restaurant upgrades and employee hiring. Employees generate offline income. Offline earnings allow players to acquire more mutations and unlock additional gameplay. The progression must feel interconnected rather than like several unrelated minigames.

## PART 2: THE COMPLETE GAMEPLAY LOOP
Design gameplay across five timescales.

### 2.1 Immediate Loop: 15–60 Seconds
A customer arrives. The player receives an order. The player gathers ingredients. The player cooks the meal. The player assembles the dish. The player serves the customer. The customer reacts. The player receives money, experience, and possibly additional rewards. A customer may instead become angry and initiate a confrontation. Specify every interaction, timer, animation, success condition, and failure condition.

### 2.2 Short Session: 5–15 Minutes
Players should be able to: complete numerous orders; experience several customer personalities; encounter at least one memorable chaotic event; earn money; upgrade something; acquire or progress toward a mutation; repair damage; improve restaurant performance. Design a satisfying short-session progression.

### 2.3 Medium Session: 15–45 Minutes
Players can: explore Morph City; purchase ingredients; discover new recipes; complete quests; fight unusual enemies; unlock new restaurant equipment; recruit employees; upgrade mutations; visit other players; participate in city events.

### 2.4 Long-Term Progression
Define progression across: first hour; first day; first week; first month; first three months. Include milestone unlocks, content pacing, restaurant expansion, morph collection, and increasingly difficult customers.

### 2.5 Offline Progression
The restaurant continues operating through hired employees while the player is offline. This is a critical feature. It must not be treated as a minor bonus. Design it as a complete gameplay system.

## PART 3: COOKING SYSTEM
Use games such as Overcooked, Overcooked 2, PlateUp!, Cooking Simulator, and Roblox restaurant simulators as mechanical references. Do not copy their protected assets, branding, or proprietary content. Analyze the general mechanics that make these games enjoyable and adapt them to Mystery Morph Restaurant.

### 3.1 Kitchen Interaction Mechanics
Specify interactive stations for: ingredient storage; refrigerators; freezers; cutting boards; preparation counters; grills; fryers; ovens; pizza ovens; stovetops; soup pots; steamers; blenders; mixers; drink dispensers; ice cream machines; food assembly counters; plating stations; serving windows; dishwashing stations; trash disposal; ingredient delivery stations.

Each station must include: purpose; interaction method; processing duration; required ingredients; possible upgrades; failure conditions; visual effects; audio feedback; multiplayer interactions; mutation bonuses; Roblox implementation requirements.

### 3.2 Food Preparation Actions
Implement mechanics for:
- **Chopping**: Players repeatedly interact to chop ingredients. Timing and accuracy affect preparation quality.
- **Grilling**: Food must be removed within an appropriate cooking window. Undercooked and burned food reduce satisfaction.
- **Frying**: Ingredients are placed into fryers with cooking timers and overheating risks.
- **Baking**: Ovens process recipes with different temperature and time requirements.
- **Mixing**: Players combine ingredients in the correct sequence.
- **Blending**: Players operate blenders and can create bizarre combinations.
- **Assembling**: Ingredients must be stacked or combined in the correct order.
- **Plating**: Finished food is transferred to a serving plate.
- **Serving**: Players deliver food to the correct customer.
- **Cleaning**: Players remove trash, spilled ingredients, broken dishes, and kitchen hazards.

Specify keyboard, mouse, controller, and mobile controls. Design mechanics that remain practical on mobile devices.

## PART 4: COMPLETE FOOD AND RECIPE DATABASE
Create a minimum of 150 fully specified recipes across at least 15 categories. Every recipe must have: unique recipe ID; display name; description; food category; unlock level; required ingredients; preparation stations; preparation steps; base preparation time; ideal cooking time; difficulty; base selling price; ingredient cost; profit margin; customer satisfaction modifiers; potential customer complaints; visual appearance; animation requirements; special effects; mutation interactions.

Include at least the following categories:
- 4.1 Burgers — 15 recipes (examples: Basic Burger, Cheeseburger, Double Cheeseburger, Triple Stack Burger, Bacon Monster Burger, Pickle Mountain Burger, Volcano Burger, Frozen Burger, Rainbow Burger, Mystery Meat Burger, Tentacle Burger, Exploding Burger, Upside-Down Burger, Invisible Burger, The Unreasonably Large Burger)
- 4.2 Pizza — 15 recipes (ordinary pizzas alongside Eyeball Pizza, Tentacle Supreme, Lava Pizza, Screaming Cheese Pizza, Pizza With No Crust, Pizza With Only Crust, Backwards Pizza, Pizza Inside Another Pizza)
- 4.3 Tacos and Mexican-Inspired Food — 10
- 4.4 Sandwiches — 10
- 4.5 Soups — 10
- 4.6 Pasta — 10
- 4.7 Breakfast — 10
- 4.8 Desserts — 15
- 4.9 Drinks and Smoothies — 15
- 4.10 Seafood — 10
- 4.11 Salads — 5
- 4.12 Fried Foods — 5
- 4.13 Alien Cuisine — 10
- 4.14 Mutation Cuisine — 5
- 4.15 Legendary Dishes — 5

The database must contain at least 150 distinct recipes, not merely a list of names. Create a complete ingredient database supporting all recipes. Ingredients must include purchase costs, storage rules, visual assets, preparation states, and compatible recipes.

### 4.16 Ridiculous Customer Modifications
Customers can request unusual modifications. Examples: "Make my burger upside down." "I want my soup frozen." "Give me a pizza with absolutely no pizza." "Cook my steak until it screams." "I want exactly seventeen pickles." "Make my drink angry." "I want a cheeseburger, but I'm allergic to circles." Create at least 75 possible order modifications. Each must be mechanically achievable through the cooking system or clearly designated as a joke request with an alternative satisfaction mechanic. Do not generate impossible orders that players cannot reasonably complete.

## PART 5: CUSTOMER AI AND BEHAVIOR
Create a comprehensive customer AI system. Customers are autonomous mutant NPCs with unique appearances, personalities, preferences, and behaviors.

### 5.1 Customer State Machine
States: 1 Spawn; 2 Approach restaurant; 3 Enter restaurant; 4 Request seating; 5 Navigate to table; 6 Sit; 7 Review menu; 8 Place order; 9 Wait; 10 Receive food; 11 Inspect food; 12 Evaluate satisfaction; 13 Eat; 14 Pay; 15 Tip; 16 Leave.
Additional conditional states: Confused; Impatient; Complaining; Angry; Enraged; Throwing food; Breaking furniture; Fighting; Fleeing; Apologizing; Calming down; Being escorted out; Returning as a repeat customer.
Specify state transitions and interruption handling.

### 5.2 Customer Personalities
Create at least 30 personality archetypes. Examples: The Karenosaurus (complains about almost everything); The Hungry Hippo-Spider (orders enormous quantities); The Polite Demon (courteous until provoked); The Food Critic (evaluates every aspect); The Impatient Goblin (very short patience); The Sleepy Sloth-Rocket (takes forever to order); The Chaos Gremlin (occasionally causes trouble even when satisfied); The Rich Mutant (pays exceptionally well, expects perfection); The Influencer (can increase popularity or damage reputation); The Bodybuilder Pigeon (extremely strong and easily offended).
For every personality define: patience; preferred foods; disliked foods; satisfaction thresholds; anger probability; combat behavior; spending range; tip behavior; unique animations; dialogue examples; special interactions.

### 5.3 Satisfaction System
Satisfaction score based on: order accuracy; food quality; cooking accuracy; waiting time; restaurant cleanliness; restaurant atmosphere; customer personality; mutation bonuses; special events. Define exact formulas and weights.

### 5.4 Anger and Tantrum System
Escalating anger levels: 0 Happy; 1 Annoyed; 2 Complaining; 3 Throwing food; 4 Destroying furniture; 5 Fighting the player; 6 Restaurant-wide chaos. Specify triggers, probabilities, escalation timing, and recovery mechanics. Not every unhappy customer should automatically attack. Customer reactions must be varied and entertaining.

## PART 6: COMBAT SYSTEM
Combat must be exaggerated, cartoonish, and suitable for Roblox's younger audience. Avoid realistic gore.

### 6.1 Core Combat
Basic attacks; heavy attacks; blocking; dodging; knockback; stuns; special abilities; mutation attacks; environmental interactions; temporary status effects.

### 6.2 Environmental Combat
Players and customers can interact with: chairs; tables; food trays; plates; trash cans; kitchen utensils; broken furniture; restaurant decorations. Example chain: a customer throws a hamburger; the player ducks; the hamburger hits another customer; that customer becomes angry; a fight begins; someone crashes into a table; the table breaks; the player must repair it afterward. Specify physics limits and performance safeguards.

### 6.3 Mutation-Based Combat
Examples: Scorpion Tail (tail swipe, temporary stun); Bear Arms (increased melee strength); Kangaroo Legs (powerful jumping kick); Octopus Arms (multiple-target attacks); Rhino Horn (charging attack); Electric Eel Skin (electrical stun); Porcupine Spines (defensive damage); Frog Tongue (pull enemies closer); Crab Claws (grab and throw objects); Dragon Head (short-range fire breath). Create at least 50 combat abilities. Each must specify cooldowns, damage, range, animations, effects, balancing, and counters.

### 6.4 Defeat and Recovery
Players should not permanently lose valuable mutations when defeated. Define: knockout animations; respawn mechanics; temporary penalties; restaurant damage; recovery costs; protective upgrades; employee intervention. Combat must be exciting without making ordinary restaurant management frustrating.

## PART 7: THE MORPH SYSTEM
This is the game's defining feature. Every character is a bizarre hybrid assembled from unrelated biological and artificial components. A creature might have: bear head; rat nose; giraffe neck; human torso; crab arm; robot arm; chicken legs; scorpion tail; butterfly wings; television face. The system must support procedural character generation.

### 7.1 Morph Anatomy Slots
Head; Face; Nose; Mouth; Eyes; Ears; Horns; Neck; Torso; Left arm; Right arm; Hands; Left leg; Right leg; Feet; Tail; Wings; Back attachments; Skin; Fur; Scales; Special effects. Explain compatibility constraints and how these components attach to Roblox character rigs.

### 7.2 Mutation Categories
Mammals; Birds; Reptiles; Amphibians; Fish; Insects; Arachnids; Marine creatures; Dinosaurs; Mythological creatures; Robots; Household objects; Food-based mutations; Plants; Alien mutations; Elemental mutations.

### 7.3 Mutation Database
Minimum of 250 individual mutation parts. Every mutation must specify: ID; name; body slot; category; rarity; unlock requirement; acquisition method; visual description; model requirements; animation requirements; cooking bonus; combat bonus; repair bonus; movement bonus; passive ability; active ability (if applicable); upgrade levels; balance limitations.

### 7.4 Mutation Rarities
Common; Uncommon; Rare; Epic; Legendary; Mythic; Secret. Define acquisition rates and progression requirements. Avoid predatory monetization.

### 7.5 Morph Combinations
Examples: Bear Head + Scorpion Tail = Scorpion Bear; Shark Head + Spider Legs = Shark Spider; Giraffe Neck + Squid Tentacles = Giraffe Squid; Television Head + Moth Wings = TV Moth; Frog Head + Robot Body = Frog Robot; Cat Head + Fish Body = Cat Fish; Axolotl Head + Cow Body = Axolotl Cow; Pigeon Head + Muscular Arms = Muscle Pigeon. Create at least 100 example morph combinations. The system must not depend on manually creating every possible combination. Specify a modular system capable of generating thousands of combinations from reusable parts.

### 7.6 Mutation Synergies
Examples: Octopus Arms + Chef Mutation (faster simultaneous cooking interactions); Bear Arms + Rhino Horn (increased knockback); Spider Legs + Repair Claws (faster movement between damaged objects); Dragon Head + Fireproof Skin (improved cooking near hot equipment). Create at least 75 mutation synergies. Define stacking rules and balance caps.

## PART 8: MORPH CUSTOMIZATION INTERFACE
Complete character customization screen (reference the mockup's "Customize Your Morph" panel) including: rotatable 3D character preview; body part categories; mutation inventory; equipped mutations; rarity indicators; mutation statistics; ability descriptions; equip controls; unequip controls; saved loadouts; morph naming; cosmetic color selection; mutation upgrade controls. Players should be able to save at least three loadouts: Chef Loadout (cooking), Fighter Loadout (combat), Repair Loadout (maintenance). Define switching restrictions and cooldowns.

## PART 9: PLAYER PROGRESSION
Level system with at least 100 levels. XP from: cooking; serving; customer satisfaction; combat; repairs; exploration; quests; restaurant upgrades; special events.

### 9.1 Player Statistics
Cooking Speed; Cooking Quality; Strength; Defense; Repair Speed; Movement Speed; Luck; Customer Charm; Restaurant Efficiency. Define formulas and stat caps.

### 9.2 Skill Trees
Three primary skill trees: **Chef Tree** (faster preparation, reduced burning, improved food quality, multitasking); **Combat Tree** (strength, defense, mobility, mutation effectiveness); **Repair Tree** (faster repairs, lower material costs, stronger furniture, improved disaster recovery). Add optional specialization systems for customer service and employee management. Specify at least 20 unlockable upgrades per primary tree.

## PART 10: RESTAURANT BUILDING AND UPGRADES
Players begin with a small, rundown restaurant and expand into increasingly elaborate businesses.

### 10.1 Restaurant Tiers
At least 10 tiers, e.g.: 1 Broken Burger Shack; 2 Tiny Mutation Diner; 3 Neighborhood Freak Café; 4 Morph City Grill; 5 Mutant Family Restaurant; 6 Monster Food Court; 7 Mutation Megadiner; 8 Luxury Freak Restaurant; 9 Morph City Food Palace; 10 Legendary Mutation Restaurant. Each tier: upgrade cost; unlock requirements; floor area; table capacity; kitchen capacity; customer throughput; available equipment; decoration options; employee capacity; offline earning potential.

### 10.2 Furniture and Decorations
At least 100 purchasable objects: tables; chairs; booths; counters; lighting; flooring; wall finishes; windows; doors; kitchen appliances; signs; plants; aquariums; sculptures; interactive decorations.

### 10.3 Damage and Repair
Every destructible object: durability; damage states; repair requirements; repair cost; repair duration; destruction animation; restoration animation. Players can repair manually or assign employees. Mutations may improve repair performance. Destruction should be visually entertaining without permanently erasing expensive player progress.

## PART 11: EMPLOYEE HIRING AND OFFLINE RESTAURANT OPERATIONS
**THIS IS A MAJOR GAMEPLAY SYSTEM AND MUST BE FULLY DESIGNED.** Players hire mutant NPC employees who work while the player is online and, more importantly, operate the restaurant while the player is offline. The player should return to a meaningful amount of earned currency. This system creates a reason to return every day.

### 11.1 Employee Roles
Chef; Prep Cook; Waiter; Cashier; Dishwasher; Cleaner; Repair Technician; Security Guard; Restaurant Manager; Delivery Worker; Ingredient Stocker; Assistant Manager. Each role must have distinct responsibilities.

### 11.2 Employee Mutations
Employees are ridiculous mutants whose mutations influence performance. Examples: Octopus Chef (multiple arms, several dishes); Cheetah Waiter (fast between tables); Rhino Security Guard (stops angry customers); Spider Repair Technician (climbs and repairs quickly); Robot Cashier (efficient transactions); Sloth Dishwasher (extremely slow but inexpensive); Dragon Chef (excellent at grilling, occasionally burns food). Create at least 75 employee archetypes.

### 11.3 Employee Statistics
Cooking Skill; Service Speed; Accuracy; Repair Skill; Combat Strength; Reliability; Energy; Morale; Salary; Efficiency; Special Abilities.

### 11.4 Hiring System
Recruitment office in Morph City. Each employee has: hiring cost; wage rate; skill levels; mutation combination; rarity; special abilities; personality; training potential. Create a recruitment interface and hiring workflow.

### 11.5 Employee Management
Assign roles; change workstations; train employees; upgrade equipment; increase salaries; promote employees; replace employees; hire managers; review performance.

### 11.6 Offline Restaurant Simulation
The game must not require an actual Roblox server to keep the restaurant running continuously. Implement a server-authoritative, timestamp-based offline earnings simulation. When the player returns: 1 retrieve last saved logout/simulation timestamp; 2 determine elapsed offline time; 3 apply the offline earnings cap; 4 calculate employee productivity; 5 estimate customer throughput; 6 calculate revenue; 7 deduct ingredient costs; 8 deduct employee wages; 9 apply equipment and mutation bonuses; 10 calculate incidents and operational losses; 11 determine net profit; 12 save the resulting state; 13 present an offline earnings report. Do not trust client-provided timestamps or earnings. Use server-controlled time and persisted player data.

### 11.7 Offline Earnings Formula
Incorporate: restaurant capacity; customer demand; employee efficiency; available kitchen stations; menu profitability; ingredient supply; employee wages; restaurant reputation; security effectiveness; repair effectiveness; offline duration; upgrade bonuses. Provide worked numerical examples for restaurants at different progression levels.

### 11.8 Offline Time Limits
Initial proposal: Without Manager 2 h; Basic Manager 4 h; Experienced Manager 8 h; Elite Manager 12 h; Legendary Manager 24 h. These are balancing assumptions. Explain how to tune them using retention and economy data.

### 11.9 Offline Incidents
Angry customers; broken furniture; kitchen equipment failure; employee mistakes; ingredient shortages; unexpected rushes; surprise inspections; celebrity customers; employee hero moments; rare mutation discoveries. Incidents affect earnings but must not create unfair catastrophic losses. Create at least 50 offline incident types.

### 11.10 Welcome Back Screen
Animated return screen, e.g.:
> WELCOME BACK, YOU WEIRDO! Your restaurant operated for 7 hours and 23 minutes. Customers Served: 183. Revenue: $18,450. Employee Wages: $2,300. Ingredients: $4,100. Repairs: $350. TOTAL PROFIT: $11,700. Special Events: "Your Octopus Chef prepared 43 burgers simultaneously." "Your Rhino Guard stopped three angry customers." "Your Sloth Dishwasher washed exactly four plates."

Include: Collect Earnings button; Employee Report button; Restaurant Damage button; Upgrade Suggestions; Mutation Rewards; Continue Playing button. Define the underlying UI states and server validation.

### 11.11 Offline Mutation Progression
Offline earnings can be spent on mutations, and employees may occasionally discover mutation materials. Define how this works without making active gameplay irrelevant. Offline progress must complement active gameplay, not replace it.

## PART 12: MORPH CITY
A complete explorable city: bright neon signs; colorful storefronts; strange citizens; unusual vehicles; animated billboards; absurd advertisements; cartoonish architecture; hidden alleyways; interactive environments.

### 12.1 City Layout
Named districts, at minimum: 1 Restaurant Row; 2 Mutation Market; 3 Downtown Morph City; 4 Industrial District; 5 Monster Mall; 6 Mutation Research District; 7 Entertainment District; 8 Residential District; 9 Underground Mutation Sewers; 10 Arena District. Specify how districts connect and how players travel between them.

### 12.2 Required Buildings
Mutation Mart (purchase mutation parts); Body Mods (customize appearance); Restaurant Supplies (equipment and ingredients); Recruitment Office (hire employees); Training Gym (combat abilities); Cooking Academy (recipes and cooking skills); Repair Workshop (maintenance abilities); Morph Arena (fight other mutants); City Hall (licenses and expansion permits); Job Board (quests); Mutation Laboratory (combine and upgrade mutations); Monster Mall (cosmetics and decorations); Mystery Market (rotating rare items); Food Critic Headquarters (restaurant rating challenges); Delivery Depot (delivery missions); Morph Museum (creature lore and collection achievements). For every building: location; exterior appearance; interior layout; NPCs; interactions; available services; currency costs; unlock requirements; quests; UI screens; Roblox implementation considerations.

### 12.3 City NPCs
At least 100 named NPCs, each with: name; morph combination; personality; location; role; dialogue; quest possibilities; interaction behavior.

### 12.4 City Events
At least 30 events, e.g.: Giant Food Festival; Mutation Parade; Citywide Restaurant Rush; Angry Customer Invasion; Legendary Chef Tournament; Mutation Meteor Shower; Giant Rat King Attack; Food Critic Convention; Blackout Night; Restaurant Repair Emergency. Events should encourage players to leave their restaurants and explore.

## PART 13: QUESTS AND MISSIONS
Tutorial quests; story quests; daily quests; weekly quests; cooking challenges; combat challenges; repair challenges; exploration challenges; employee management challenges; restaurant expansion challenges. At least 100 fully specified quests, each with: ID; name; description; NPC; location; objectives; prerequisites; completion conditions; rewards; failure conditions (if applicable). Include a lighthearted, humorous story campaign about becoming Morph City's greatest restaurant owner.

## PART 14: MULTIPLAYER
### 14.1 Cooperative Restaurants
Players can visit friends and help run their restaurants: shared cooking; shared serving; shared cleaning; shared combat; permission settings; guest rewards; owner rewards. Prevent guests from stealing valuable items or permanently damaging restaurant progress.
### 14.2 Shared City
Public gathering areas; social activities; city events; cooperative quests; player emotes; morph showcases.
### 14.3 Arena Combat
Optional PvP: matchmaking; combat rules; rewards; ability balancing; anti-cheat; opt-in requirements. Restaurant customers remain NPCs. PvP should never be forced upon players who only want restaurant gameplay.

## PART 15: ECONOMY DESIGN
### 15.1 Currencies
Morph Bucks (primary earnable); Mutation Shards (quests, events, special activities); Research Tokens (advanced mutation upgrades). Keep the economy understandable; no unnecessary currencies.
### 15.2 Revenue Sources
Customer payments; tips; quests; restaurant milestones; events; deliveries; offline earnings; achievements.
### 15.3 Money Sinks
Ingredients; equipment; furniture; repairs; employee wages; hiring; restaurant expansion; mutation upgrades; cosmetics.
### 15.4 Economic Balance
Formulas for: recipe profitability; restaurant operating margins; employee return on investment; upgrade payback periods; mutation acquisition pacing; offline earnings; customer spending; restaurant expansion costs. Provide sample economy simulations for early-, mid-, and late-game players. Prevent runaway inflation and trivial progression.

## PART 16: MONETIZATION
Ethical, Roblox-compatible monetization: cosmetic morph skins; restaurant themes; decorative furniture packs; character emotes; additional cosmetic loadout slots; optional VIP visual effects; nonessential customization options. Avoid pay-to-win combat advantages. Do not make offline earnings dependent on Robux purchases. Do not require purchases to complete the game. Any random-reward systems must comply with Roblox policies, including applicable disclosure and eligibility requirements. Explain which features should remain exclusively earnable through gameplay.

## PART 17: USER INTERFACE
### 17.1 Main HUD
Player level; XP bar; health; Morph Bucks; Mutation Shards; current objective; active order queue; customer patience indicators; equipped abilities; restaurant condition; quick-access menu.
### 17.2 Restaurant Interface
Orders; cooking stations; customer status; employee management; inventory; repairs; upgrades; financial reports.
### 17.3 Morph Interface
Character preview; mutation slots; mutation inventory; stats; abilities; upgrade controls; saved loadouts.
### 17.4 City Map
Districts; shops; quests; events; fast-travel locations; friends; player restaurant.
### 17.5 Employee Interface
Employee roster; roles; stats; wages; training; assignments; offline efficiency; performance reports.
### 17.6 Additional Interfaces
Main menu; tutorial; cooking minigames; restaurant upgrades; building placement; repair minigames; combat abilities; quest journal; achievements; inventory; mutation research; marketplace; settings; offline earnings report.

Provide wireframe descriptions and UI component hierarchies. All interfaces must work on desktop, tablet, mobile, and controller.

## PART 18: ART DIRECTION
Use the supplied graphics sheet as the primary visual reference. The game should resemble a polished, colorful Roblox experience.
### 18.1 Visual Style
Blocky character proportions; exaggerated silhouettes; oversized facial features; bright colors; strong readability; expressive animations; cartoon destruction; ridiculous creature combinations; neon city lighting; stylized restaurant interiors. Avoid making the game look realistic or frightening.
### 18.2 Character Art
Modular character construction; mutation parts visually compatible even when combinations are absurd. Guidelines for: scale; attachment points; materials; color palettes; animation rigs; facial expressions; equipment compatibility.
### 18.3 Restaurant Art
Visual assets for all restaurant tiers: exterior designs; interior layouts; kitchen equipment; furniture; destruction states; repair effects; upgrade animations.
### 18.4 City Art
District-specific architecture, signage, lighting, props, and ambient animations.
### 18.5 Animation Library
At least 150 animations: walking; running; jumping; cooking; chopping; grilling; serving; eating; complaining; tantrums; fighting; dodging; repairing; celebrating; mutation abilities; employee work cycles.
### 18.6 Sound Design
Comprehensive sound asset list: kitchen sounds; customer dialogue sounds; creature noises; combat effects; destruction sounds; repair sounds; currency rewards; level-ups; mutation unlocks; city ambience; restaurant music.

## PART 19: ROBLOX TECHNICAL ARCHITECTURE
Detailed Roblox Studio implementation plan using Luau; modular, maintainable, scalable.
### 19.1 Project Structure
Hierarchy for ReplicatedStorage, ServerScriptService, ServerStorage, StarterPlayer, StarterGui, Workspace, SoundService, Lighting. Define modules and responsibilities.
### 19.2 Core Services
PlayerDataService; RestaurantService; OrderService; RecipeService; CookingService; CustomerAIService; CombatService; MutationService; MorphAssemblyService; EmployeeService; OfflineEarningsService; EconomyService; InventoryService; QuestService; CityEventService; MultiplayerService; BuildingService; RepairService; ProgressionService; UIController. For every service: responsibilities; public interfaces; data dependencies; events; RemoteEvents and RemoteFunctions; validation; error handling; performance considerations.
### 19.3 Data Persistence
DataStoreService schemas for: player progression; currency; mutation inventory; equipped mutations; restaurant upgrades; furniture; employees; employee assignments; recipe unlocks; quests; offline earnings; achievements. Include: schema versioning; data migration; session locking; autosaving; retry handling; idempotent transactions; duplicate reward prevention; recovery from interrupted saves.
### 19.4 Server Authority
Server validates: currency changes; item purchases; mutation ownership; combat damage; cooking results; quest rewards; offline earnings; employee hiring; restaurant upgrades. Never trust client-submitted reward values.
### 19.5 Performance
Optimize for Roblox mobile devices: NPC population; pathfinding; physics; destruction effects; character morph complexity; animation performance; network replication; asset streaming; memory usage. Use object pooling where appropriate. Implement limits on simultaneous active NPCs and physics objects.

## PART 20: ANALYTICS AND PLAYER RETENTION
Analytics events for: new player onboarding; tutorial completion; first order; first successful meal; first customer tantrum; first combat encounter; first mutation; first restaurant upgrade; first employee hire; first offline earnings collection; city exploration; quest completion; session duration; return visits. Track: CCU; peak CCU; DAU; D1/D7/D30 retention; average session length; tutorial completion; restaurant progression; mutation collection; offline earnings engagement; revenue per active user. Define an analytics event schema and explain how the data should influence balancing.

## PART 21: TUTORIAL AND FIRST-TIME USER EXPERIENCE
Design the first 15 minutes in extraordinary detail. The player should quickly understand: 1 how to move; 2 take orders; 3 prepare food; 4 serve customers; 5 how satisfaction works; 6 what happens when customers become angry; 7 how to defend themselves; 8 how to repair damage; 9 how to earn money; 10 how to purchase mutations; 11 how to upgrade their restaurant; 12 how employees work. The first customer tantrum should be memorable and funny. The first mutation should feel exciting. The first employee hire should demonstrate the future possibility of offline income. Specify tutorial dialogue, prompts, timing, animations, rewards, and skip/recovery behavior.

## PART 22: CONTENT EXPANSION
Future expansion possibilities, e.g.: additional districts; new restaurant themes; seasonal mutation events; new food categories; new employee professions; legendary customers; restaurant competitions; cooperative cooking tournaments; mutation discovery events; new combat arenas; additional restaurant properties. Create a 12-month content roadmap.

## PART 23: COMPLETE CONTENT DATABASES
Implementation-oriented tables for: 1 all recipes; 2 all ingredients; 3 all mutation parts; 4 all mutation synergies; 5 all customer personalities; 6 all employee archetypes; 7 all NPCs; 8 all quests; 9 all city buildings; 10 all city events; 11 all restaurant upgrades; 12 all furniture; 13 all abilities; 14 all animations; 15 all sounds; 16 all achievements; 17 all progression milestones. Use consistent unique identifiers. Cross-reference dependencies. Do not invent references to assets or systems that are not defined elsewhere in the document.

## PART 24: DEVELOPMENT ROADMAP
Phase 1 Core Prototype (one restaurant; basic cooking; customer orders; customer satisfaction; basic tantrums; simple combat; initial mutations; currency and XP). Phase 2 Vertical Slice (polished cooking; restaurant upgrades; employee hiring; offline earnings; mutation customization; first city district; complete tutorial). Phase 3 Alpha (expanded recipes; more mutations; additional personalities; restaurant expansion; quests; multiple districts; multiplayer). Phase 4 Beta (full employee management; expanded offline simulation; city events; advanced combat; additional tiers; analytics; performance optimization). Phase 5 Launch (polished, balanced, tested, enough content for repeat play). Phase 6 Live Operations (expand content based on behavior and retention). For each phase: features; dependencies; estimated complexity; required assets; technical tasks; testing requirements; completion criteria. Identify the minimum viable playable game. Distinguish launch-critical systems from future expansion content.

## PART 25: TESTING AND QUALITY ASSURANCE
Test plans for: cooking; customer behavior; customer satisfaction; combat; mutations; morph assembly; restaurant building; furniture destruction; repairs; employee hiring; offline earnings; data persistence; multiplayer; mobile performance; economy exploits; quest progression; UI behavior. Include edge cases, e.g.: disconnect while cooking; customer attacks while the player is in a menu; restaurant damaged while an employee is repairing it; changing mutations during combat; returning after 30 days offline; DataStore request failure; two players interacting with the same cooking station; no money to pay employees; no ingredients; customer cannot reach assigned table; offline earnings received twice because of a reconnect. Specify expected behavior and test cases.

## PART 26: ADDITIONAL DESIGN REQUIREMENTS (apply to every system)
- 26.1 Humor: constantly produce entertaining, unexpected moments; humor emerges from character design, animation, customer behavior, dialogue, food, and environmental interactions; do not rely exclusively on scripted jokes; design systems that create funny situations naturally.
- 26.2 Readability: players always understand what to do; important UI remains readable during chaos.
- 26.3 Accessibility: mobile controls; controller controls; keyboard and mouse; reduced visual effects; adjustable audio; color-independent status indicators; clear tutorials.
- 26.4 Fairness: failure should be funny, not devastating; recover without excessive grinding.
- 26.5 Progression: every session provides meaningful progress toward something.
- 26.6 Replayability: personalities, mutation combinations, random incidents, and city events create varied experiences.
- 26.7 Social Appeal: morph combinations interesting enough that players want to show friends.
- 26.8 Offline Engagement: compelling reason to return, collect earnings, manage employees, purchase upgrades.

## PART 27: REQUIRED DOCUMENT OUTPUT STRUCTURE
1 Executive Summary; 2 Game Vision; 3 Design Pillars; 4 Core Gameplay Loops; 5 Cooking Mechanics; 6 Recipe Database; 7 Ingredient Database; 8 Customer AI; 9 Customer Personalities; 10 Satisfaction and Tantrum Systems; 11 Combat System; 12 Mutation System; 13 Morph Customization; 14 Player Progression; 15 Restaurant Building; 16 Employee Management; 17 Offline Restaurant Simulation; 18 Morph City; 19 City NPCs; 20 Quests; 21 Multiplayer; 22 Economy; 23 Monetization; 24 UI/UX; 25 Art Direction; 26 Animation and Audio; 27 Roblox Architecture; 28 Data Persistence; 29 Security and Anti-Exploit; 30 Performance Optimization; 31 Analytics; 32 Tutorial; 33 Content Expansion; 34 Development Roadmap; 35 Testing and QA; 36 Content Database Appendices; 37 Implementation Checklists; 38 Open Design Decisions; 39 Balancing Assumptions; 40 Definition of Done.

Use clear Markdown headings, tables, diagrams, and code examples. Include Mermaid diagrams for: core gameplay loop; customer state machine; cooking workflow; combat state machine; employee management; offline earnings calculation; player progression; Roblox service architecture; data persistence flow.

## PART 28: CRITICAL EXECUTION INSTRUCTIONS
Do not produce a shallow overview. The document should let a Roblox team implement without repeatedly requesting basic design decisions.
1. Be exhaustive. 2. Be specific (numerical values, formulas, state transitions, interaction rules, implementation details). 3. Be consistent. 4. Be technically realistic (actual Roblox capabilities and limitations). 5. Be entertaining (preserve the ridiculous tone). 6. Be development-oriented. 7. Be scalable. 8. Avoid unnecessary complexity. 9. Define dependencies. 10. Separate assumptions from requirements (label tunable values). 11. Include acceptance criteria (measurable). 12. Do not silently omit content (multi-pass if needed). 13. Maintain a completion manifest. 14. Validate database relationships. 15. Make the offline economy robust (deterministic, server-authoritative, capped, protected against duplicate claims). 16. Prioritize fun — never let complexity overwhelm the premise: take orders, cook food, make money, collect morphs, survive ridiculous customers.

## CREATIVE DIRECTOR NOTES (from the project owner)
- **The morph system is the center of the economy and retention, not the restaurant itself.** The restaurant is how players earn money; mutations are what they want to spend it on. A restaurant has a finite number of meaningful upgrades, whereas modular creature customization supports thousands of combinations. Core progression loop: **Cook → Earn → Morph → Become More Powerful → Run a Better Restaurant → Earn More → Discover Rarer Morphs.** When the player logs off, employees keep that progression moving.
- **Emergent chaos.** A dissatisfied customer shouldn't just play an angry animation. They should be able to start a chain reaction that transforms an ordinary cooking session into a ridiculous restaurant brawl. That is what makes Mystery Morph Restaurant stand out from conventional Roblox restaurant tycoons.
