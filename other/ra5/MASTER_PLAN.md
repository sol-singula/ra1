# THE LAST TRAIN — Master Game Plan and Production Blueprint

Document status: Living design document · Platform: Roblox · Genre: Cooperative scavenging, train-building, home
customization, expedition progression · Target server size: Up to 20 players per expedition

Design principle: A mysterious, cinematic journey where players improve a personal train cabin while cooperating to
keep a shared train moving farther down an unknown line.

> This is the team's master plan, kept as written. Our build plan, what's built and the decisions we made while
> building are in [PLAN.md](PLAN.md).

## 1. Executive Summary

The Last Train is a cooperative Roblox experience about living aboard a train that travels through an enclosed,
mysterious world. The train stops at abandoned locations. Players leave the safety of the train, scavenge materials
under a departure timer, and return before the train leaves. Materials can improve a player's persistent personal
cabin or be contributed to shared train systems that let the whole crew travel farther.

The emotional hook is a contrast between *my little home* and *our impossible journey*. Every player has a
private-feeling space that gradually changes from a bare compartment into a personalized, useful, impressive train
car. At the same time, the common train becomes a shared project. Players see the effects of their work in the
train's appearance, available facilities, distance records, and newly reached regions.

The game should feel atmospheric, surprising, social, and rewarding—not like a spreadsheet, a generic simulator, or a
monetization funnel. It should support solo-minded players, friend groups, and large crews without making any one
player responsible for everyone else's fun.

### Product promise

- **Explore:** Each stop offers a compact, readable scavenging space with a few meaningful discoveries.
- **Race the clock:** Players choose how far to venture before the train departs.
- **Build a home:** Personal cabin progression persists between expeditions.
- **Build together:** Shared train upgrades improve the crew's ability to travel farther.
- **Make history:** The crew's distance and expedition story become part of a station Hall of Records.
- **Play with friends:** Players can find and join friends' active trains when space allows.
- **Look great on phones:** The art direction and systems are designed for mobile performance from day one.

### What the first version must prove

1. Players understand the scavenging timer without needing a wall of instructions.
2. Players feel a meaningful reward after their first stop.
3. A personal cabin upgrade feels exciting and visibly changes the space.
4. A shared train upgrade creates a clear "we did that" moment.
5. Players want to take one more stop to reach a distance milestone or gather one more material.
6. Joining a friend is reliable and understandable.
7. The game remains readable and responsive on ordinary phones.

Everything else is secondary until these are true.

## 2. Pillars and Non-Goals

**Pillar A — The cabin is yours.** Every player has a persistent personal cabin. It is a safe, expressive place to
return to, show friends, and gradually improve. An expedition ending never deletes cabin progress.

**Pillar B — The train is ours.** The shared train has needs and upgrade goals. Players can contribute to common
systems, but the game should never shame players who focus on their own cabin or are new to the game.

**Pillar C — Stops are short stories.** A stop is not a giant empty map. It is a compact environment with a strong
landmark, resource clusters, a few decisions, and a reason to return to the train before departure.

**Pillar D — Distance creates momentum.** The main expedition record is how far the crew travels. Distance unlocks
milestones, region transitions, recipes, visual changes, and a place in the Hall of Records.

**Pillar E — Mystery beats clutter.** The world should suggest a larger story without requiring a long lore dump.
Announcements, signs, distant silhouettes, abandoned equipment, and unusual landmarks make the journey feel strange
and memorable.

**Pillar F — Fairness is part of the fun.** A player should not need to pay to join friends, avoid arbitrary
punishment, or access the core loop. Purchases should offer optional expression or convenience—not fix problems
deliberately created to sell a solution.

### Non-goals for the first playable release

- A full open world with a continuously simulated train journey.
- Physically simulating a 20-car chain with complex joints.
- Large-scale PvP, trading markets, or player theft.
- A huge skill tree.
- Multiple complicated enemy factions.
- A large paid shop before the free game is fun.
- Dozens of regions before one region is polished.
- Full free-placement building with unrestricted physics.
- Elaborate vehicle rescue systems.

## 3. The Player Experience

### The emotional arc

1. **Arrival:** The player enters a warm, enclosed station and notices a huge train and a record hall.
2. **Belonging:** The player is assigned a basic cabin and learns that it is theirs to improve.
3. **First risk:** The train stops at an abandoned site. The doors open, an announcement explains the departure
   window, and the player steps outside.
4. **Discovery:** The player finds materials, a blueprint, or a visually interesting landmark.
5. **Urgency:** The warning lights and announcement signal that departure is approaching.
6. **Return:** The player races back through the train doors and feels relief when they make it.
7. **Reward:** Materials turn into a visible cabin improvement or a contribution to a train milestone.
8. **Commitment:** The crew reaches a distance milestone, unlocks something new, or sees its record appear in the
   station.
9. **Long-term attachment:** The player's cabin becomes recognizable and the journey becomes part of their personal
   history.

### First 10–15 minutes

By the end of a good first session, a new player should have:

- Entered a personal cabin and changed at least one thing in it.
- Taken part in one scavenging stop.
- Learned the departure warnings and return route.
- Collected at least two different resource types.
- Crafted or purchased one early cabin improvement.
- Seen one shared train objective and understood how to contribute.
- Seen a distance or region milestone.
- Been shown how to invite or join a friend.

Do not front-load every system. Introduce one new concept at a time, in the place where the player needs it.

## 4. Core Gameplay Loop

### Expedition loop

1. The train travels for a short, controlled segment.
2. A destination announcement previews the stop.
3. The train slows, lighting changes, and the doors open.
4. A clear timer begins.
5. Players explore a compact site and gather materials.
6. Optional discoveries create a risk/reward choice: one more resource node, a blueprint, or a safe return.
7. Departure warnings begin.
8. Players return to the train. Doors close and the train departs.
9. Resources are banked according to the inventory rules.
10. The crew advances distance, upgrades systems, and unlocks new possibilities.
11. The loop repeats until the expedition ends.

### Initial timing targets

These are playtest starting points, not permanent balance commitments.

| Phase | Initial target | Purpose |
|---|---|---|
| Travel and preview | 30–60 seconds | Anticipation, announcements, movement illusion |
| Scavenging window | 2–3 minutes | Meaningful exploration without excessive downtime |
| Early warning | 60 seconds remaining | Let players make a deliberate return decision |
| Final warning | 20 seconds remaining | Create urgency without being unfair |
| Door close/departure | 5–10 seconds | Readable final chance and cinematic transition |
| Stranded-player recovery | 2–4 minutes | A compact, tense recovery story |

Measure whether players routinely return too early, arrive too late, or feel the timer is arbitrary. Adjust the site
size and resource placement before simply increasing the timer.

### The central choice

At a stop, the player repeatedly chooses between:

- Returning now with a safe haul.
- Venturing farther for a valuable resource.
- Searching a landmark for a rare blueprint.
- Helping another player return or locate a route.
- Gathering resources that improve their own cabin.
- Gathering or donating materials for shared train needs.

The best stops make these choices legible and situational rather than forcing one correct answer.

## 5. Train Movement and Presentation

### The train does not need full physical simulation

Use a controlled presentation system rather than simulating every car as a complex physics object. The train can be
built from anchored modular geometry and controlled transitions. The player's experience of travel comes from sound,
lighting, animation, camera cues, doors, announcements, and interior details.

### Enclosed travel design

- The station and train interiors are the main visual spaces.
- Windows should be controlled views, frosted panels, dark glass, shutters, or short scripted glimpses—not continuous
  terrain scrolling past.
- During travel, use low-frequency rumble, subtle camera or screen shake, changing light color, carriage sway
  animation, and announcements.
- Do not use excessive camera movement that can cause discomfort.
- Arrival should have a clear sequence: brakes, mechanical sound, lights, announcement, stop name, doors opening.
- The goal is for the player to think, "Oh, we're here," without needing a huge exterior simulation.

### Moving between cars

Players can physically walk through connected cars. The train should feel like a continuous community space, but
long trains need a convenience option:

- Add a car directory or quick-travel interaction for distant cars.
- Keep physical walking available for social visits and exploration.
- Do not force players to traverse a long corridor every time they want to return to their cabin.
- Use clear signage, lighting, floor markings, and car numbers.

### Car and train architecture

- Build car modules from reusable pieces: floor, walls, ceiling, doors, trim, lights, windows, signage, and
  interaction anchors.
- Avoid unrestricted moving parts and high-cost constraints.
- Keep collision meshes simpler than visible meshes.
- Use a small number of shared materials and texture atlases where practical.
- Use distance-based detail reduction for cars not currently near the player.

## 6. Personal Cabin Progression

### Core rules

- Every player has one persistent personal cabin in the initial version.
- Cabin progression survives expedition failure, server shutdown, leaving the game, and joining another expedition.
- The cabin starts intentionally bare, but not ugly or unusable.
- Every upgrade should create a visible change and unlock a practical or expressive benefit.
- The player should always know the next recommended step and what materials it requires.
- The game should support a long progression runway, but the first 15–20 steps must be fun before building 100–200
  steps.

### Recommended progression stages

1. **Bare Compartment** — a bedroll, weak light, basic storage, and a small amount of personal space.
2. **Livable Cabin** — a proper bed or bench, improved light, and first decorative surface.
3. **Personalized Home** — wall accents, a rug or floor finish, color choices, and a display shelf.
4. **Functional Workshop** — workbench, basic crafting interface, and visible tool storage.
5. **Comfortable Quarters** — seating, warmth, better lighting, and a stronger sense of home.
6. **Specialist Room** — a chosen theme such as mechanic, explorer, botanist, collector, or engineer.
7. **Advanced Interior** — better storage, rare materials, improved finish quality, and more layout options.
8. **Signature Car** — recognizable visual identity and rare cosmetic choices.
9. **Masterwork Car** — high-end materials, unique lighting, and prestigious displays.
10. **Legacy Car** — long-term prestige, historical items, and a way to display expedition accomplishments.

### Example early upgrade chain

This is an illustrative chain; material quantities must be tuned by playtesting.

| Step | Upgrade | Example requirement | Player-facing result |
|---|---|---|---|
| 1 | Repair bunk | 4 scrap, 2 cloth | A proper bed replaces the bedroll |
| 2 | Fit a wall lamp | 3 scrap, 1 electronics | A warm light source turns on |
| 3 | Build a storage crate | 5 wood | More personal storage capacity |
| 4 | Make a bench | 6 wood, 2 cloth | A place to sit and decorate |
| 5 | Add a work surface | 4 wood, 3 scrap | New craft recipes become available |
| 6 | Build a basic workbench | 8 scrap, 2 mechanical parts | A visible workshop station appears |
| 7 | Install wall insulation | 5 cloth, 3 scrap | Cabin sound and visual warmth improve |
| 8 | Add a display shelf | 6 wood, 1 mechanical part | A place for collectibles and discoveries |
| 9 | Improve overhead lighting | 4 electronics, 2 scrap | Better ambient light and a new fixture |
| 10 | Choose an interior finish | 8 wood or equivalent material set | Player chooses from several looks |
| 11 | Add a map board | 4 wood, 3 cloth, 1 blueprint | Displays visited regions and records |
| 12 | Build a tool rack | 5 scrap, 2 mechanical parts | Workshop looks more complete |
| 13 | Add a personal locker | 8 scrap, 2 electronics | Storage and visual progression |
| 14 | Add a comfort item | Material set varies | Small expression reward |
| 15 | Install a specialist station | Rare blueprint plus materials | Opens a chosen specialist path |

Do not make every upgrade require the same generic pile of scrap. Distinct requirements make locations and
discoveries matter.

### Cabin interaction design

Every buildable item should show:

- Item name and short purpose.
- Current stage and next stage.
- Materials required and materials owned.
- A visible preview or ghost of the result where feasible.
- Whether the item is a functional upgrade, cosmetic, storage item, or collectible display.
- A clear "Build" or "Not enough materials" state.

Avoid making players hunt through multiple menus to understand the next step.

### Layout placement

For the first version, prefer snap points and curated slots over unrestricted free placement. This improves mobile
controls, reduces clipping, supports save/load, and makes cabin layouts easier to optimize. Later, allow limited grid
placement or rotation once the basic cabin loop is proven.

### Cabin persistence data

Store the cabin stage, built items, item variants, layout/slot choices, unlocked recipes, personal storage,
achievements, cosmetics, and tutorial progress. Use a schema version so future updates can migrate old profiles
safely.

## 7. Shared Train Progression

The shared train is a second progression track, separate from personal cabins. It should visibly change and create
benefits for everyone aboard.

### Candidate shared systems

1. Engine and fuel efficiency — more distance per unit of fuel.
2. Fuel capacity — larger reserve before the next major refill.
3. Salvage storage — more room for shared materials.
4. Shared workshop — unlocks repairs and useful crafting.
5. Emergency repairs — improves resilience after an environmental incident.
6. Navigation and destination intelligence — previews stop types and resource possibilities.
7. Communications and recovery — improves stranded-player recovery and crew coordination.
8. Additional utility car — introduces a specialized shared room.
9. Long-haul systems — enables access to more distant regions.
10. Legacy finish — high-level visual upgrades that make a record-setting train memorable.

Do not implement all ten systems in the first release. Start with fuel/engine efficiency and one shared workshop or
storage milestone.

### Shared upgrade requirements

A shared upgrade may require a combination of:

- Materials deposited into a shared inventory.
- A blueprint found at a stop.
- A distance milestone.
- A brief repair or activation task.
- A simple crew confirmation for large irreversible choices.

Avoid a vote for every small decision. If voting is used for a major specialization, provide a timeout and a
deterministic fallback so the whole game cannot stall because players are idle.

### Avoiding contribution resentment

- Do not display a humiliating public ranking of who donated least.
- New players should have useful ways to help even without rare materials.
- Use some personal-only resources, some train-only resources, and a small set of flexible resources.
- The shared train should not require a fixed percentage of players to donate.
- If a shared upgrade is complete, all current crew members should understand what changed.
- Let non-donors contribute through repairs, scouting, blueprints, carrying, navigation, or recovery tasks.
- Never let one malicious player consume or destroy the entire shared bank without strong safeguards.

### Shared storage safeguards

The server owns shared inventory. Players cannot submit arbitrary amounts from the client. Deposits are validated
against server-held player inventory and transaction IDs. Critical shared resources should not be withdrawable by
ordinary players unless the design has a clear, safe reason.

## 8. Resources, Crafting, and Economy

### Start with four core resources

A manageable initial set:

- **Wood:** cabin furniture, simple structures, crates, work surfaces.
- **Scrap metal:** repairs, fixtures, tools, train upgrades.
- **Mechanical parts:** workbench, engine systems, complex upgrades.
- **Cloth and insulation:** bedding, cabin comfort, insulation, soft furnishings.

Introduce electronics, fuel, blueprints, and rare components after the core loop is stable. Fuel may be a shared
train resource rather than something every player carries.

### Resource categories

| Category | Main use | Recommended handling |
|---|---|---|
| Common personal materials | Early cabin builds | Easy to understand, frequent |
| Shared train materials | Train systems | Deposit into shared storage |
| Flexible salvage | Either cabin or train | Supports the personal-vs-team choice |
| Blueprints | Unlock recipes or milestones | Rare, memorable discoveries |
| Expedition supplies | Temporary field use | Bank or consume according to clear rules |
| Collectibles | Cabin display, records, cosmetics | Never required for basic survival |

### Make the choice fair

Players should have reasons to choose personal progress or shared progress. The choice is interesting only if both
are valid. If donating is always mathematically superior, the cabin becomes a trap. If personal upgrades are always
superior, the shared train is ignored.

Balance through:

- Distinct materials that naturally serve different purposes.
- Flexible resources for situational decisions.
- Shared milestones that benefit everyone.
- Personal upgrades that are rewarding but not mandatory for expedition success.
- Clear previews of what a contribution will unlock.
- No hidden penalties for players who keep flexible materials.

### Resource node design

Each resource node should have a readable silhouette and interaction. Use a short hold, a small progress bar, or a
limited number of interactions. Avoid long repetitive animations for common materials. Rare nodes can require a
tool, a short puzzle, or a choice, but the controls must work well on touchscreens.

### Crafting philosophy

Crafting should create visible changes and unlock new options. It should not exist just to move numbers between
menus. Whenever possible, the player should see the object appear in the cabin or shared train immediately after
building it.

## 9. Stops, Regions, and Environmental Design

### Build one region first

The first release should contain one polished region with three to five stop variants. Each stop needs a distinctive
silhouette, route layout, resource placement, and one memorable landmark. Reuse modular building kits intelligently
instead of building a huge number of one-off assets.

### First region: Overgrown Line

A suggested opening region featuring a disused forest rail corridor and abandoned service sites.

Possible stop variants:

1. **Ranger Station:** a small station building, storage sheds, scattered tools, and a map room.
2. **Timber Yard:** stacks of lumber, broken machinery, and open lanes that reward efficient routing.
3. **Signal Tower:** vertical landmark, a small side route, and a blueprint or communications objective.
4. **Maintenance Depot:** rail equipment, scrap piles, workbenches, and a clear return path.
5. **Overgrown Platform:** an eerie platform swallowed by plants, with a few rare finds and strong atmosphere.

### Future region candidates

- **Iron Basin:** mining structures, industrial conveyors, ore storage, and heavy mechanical salvage.
- **Whiteout:** snowbound stations, low visibility, insulated supplies, and cold-weather presentation.
- **Deadworks:** an abandoned power station or automated factory with electronics and unusual machinery.
- **Unknown Line:** a later high-mystery region with stranger geometry, rare blueprints, and altered train behavior.

These are future options, not a launch checklist.

### Stop layout principles

- Make the train visible or make the return route obvious.
- Keep a strong central landmark so players can orient themselves.
- Use lighting, signs, and shape language to differentiate resource zones.
- Place common resources on safe, obvious routes.
- Place rare resources farther away or behind a small challenge.
- Offer at least two viable routes back to the train when the space allows.
- Avoid confusing maze layouts during the initial timer experience.
- Design resource clusters so several players can scavenge at once without crowding.
- Avoid hiding required materials behind tiny, low-contrast interactions.

### Hazards and monsters

Prototype without monsters first. Timer pressure, route choice, resource scarcity, and the possibility of being left
behind may already create enough tension. If playtests feel too calm, add one readable environmental hazard at a
time, such as a failing light grid, a steam vent, a locked service door, or a temporary route obstruction.

Do not add hordes simply because other survival games have them. Enemies should improve the game's distinctive loop,
not distract from it.

## 10. Being Left Behind and Recovery

Being left behind should be tense and memorable, but not feel like a random deletion of progress.

### Rules

- The train does not physically turn around from a later region to collect a stranded player.
- The stranded player gets a short recovery experience that fits the current environment.
- Permanent cabin progression is never lost.
- Unbanked field loot may be lost, but this must be communicated before the risk becomes relevant.
- Recovery should create a route back into play rather than a long punishment screen.

### Recovery concept

A stranded player reaches a nearby signal station, emergency shelter, or maintenance point. They must complete a
small objective—restore power, find a signal part, align a signal, or activate a beacon. A later authorized pickup or
communications link brings them back into an eligible train state. The pickup is represented through a controlled
transition rather than a train reversing across the map.

### Important edge cases

- Player disconnects while stranded.
- Player reconnects after the original server closes.
- The expedition ends before recovery completes.
- The player chooses to join a different friend.
- The recovery destination is already occupied or unavailable.
- A player repeatedly exploits recovery to bypass normal travel.

Design recovery state as explicit server-owned data, not as a collection of local visual flags.

### Paid convenience boundary

A paid recovery convenience may eventually be acceptable only if the free recovery is reasonable, reliable, and not
intentionally frustrating. Never sell the only way to protect permanent cabin progress. Do not introduce paid
recovery until the free recovery system has been tested and is fun.

## 11. Friends, Servers, and Late Joining

Friend joining is a core feature, not a polish item.

### Target behavior

- Players can see online friends and whether a friend is in an active expedition.
- When a player chooses a friend, the game checks whether the friend's train/server has capacity.
- If space is available, the player is teleported or routed to that exact expedition.
- If full, the UI clearly says **Train Full** and offers explicit alternatives.
- Never silently send the player to a random train when they asked to join a friend.

### Full-train UI

Offer:

- **Wait for a Spot** — join a queue or retry when capacity changes.
- **Join Another Friend** — return to the friend list.
- **Start a New Expedition** — begin a separate train.

Do not promise a queue position unless it is actually being maintained. Explain when a queue is unavailable or when
the friend has left the expedition.

### Late join experience

A late joiner should arrive in a safe entry compartment and receive a compact summary:

- Current region and stop phase.
- Distance traveled and next milestone.
- Train condition and current shared objective.
- How much time remains before departure.
- What the crew is currently trying to build.

Give a small starter toolset or role-appropriate entry kit so the player can help immediately. Do not grant access to
the entire shared bank or critical train controls by default.

### Disconnects and rejoining

- Save personal progress independently of the active expedition.
- Store enough expedition identity to determine whether rejoining is valid.
- Rejoining should be allowed only if the expedition is active, the player is eligible, and capacity exists.
- Handle teleport failures with a useful message and a safe fallback.
- A player who leaves should not leave the expedition in a permanently invalid state.
- Avoid awarding a full expedition record to someone who joined for a few seconds unless the record rules explicitly
  account for participation.

### Capacity

The target is up to 20 players per train. The actual maximum must be validated on lower-end mobile devices and real
servers. A lower stable player count is preferable to a nominal 20-player experience that performs poorly.

## 12. Distance, Records, and the Hall of Records

### Distance is an expedition stat

Distance represents how far the crew has progressed along the mysterious line. It does not need to correspond to
real-world geography. It increases during travel segments and unlocks region transitions, blueprints, recipes, visual
milestones, and records.

### Record rules

- The server calculates distance and determines whether an expedition is eligible for a record.
- The client cannot submit its own distance, crew roster, or contribution score.
- Each expedition has a unique ID.
- Final records include the final distance, time, region milestones, crew roster, contribution summary, train
  configuration/appearance, and a timestamp.
- Record submissions are idempotent so a server retry cannot create duplicate records.
- If the server crashes, only safely committed milestones and distance should be eligible for the final record. Do
  not invent progress that the server cannot verify.

### Team record vs. individual recognition

The top distance record belongs to the expedition crew, not one individual. Individual recognition can highlight
helpful roles such as:

- Fuel contributed.
- Repairs completed.
- Blueprints discovered.
- Players recovered.
- Resources carried back.
- Exploration or navigation tasks completed.

Do not reward sabotage or let players gain recognition by deliberately withholding critical supplies until the train
is in danger.

### Hall of Records presentation

The Hall of Records should be a signature space in the station lobby.

- Display the top record-setting train with its distinctive appearance.
- Show crew avatars or representations beside the train.
- Show the distance, expedition date, and a few meaningful milestones.
- Let players inspect a record for a concise expedition summary.
- Use static or lightly animated historical avatar representations if players are offline.
- Prioritize detail for the top few displays; simplify distant displays.
- Make the Hall feel alive without rendering every historical player at full fidelity.

### Historical avatar strategy

Do not rely on live character rigs for every historic participant. Store stable user identifiers and approved
presentation data, then render lightweight representations or thumbnails where supported. Provide a fallback if an
avatar cannot be loaded. The record must remain useful even if one or more avatars are unavailable.

### Record eligibility

Define eligibility before launch. For example, players may need to have participated for a minimum amount of time or
through a minimum number of stops to appear as full crew members. Show the rule clearly so it does not feel
arbitrary. Late joiners can still receive participation credit without automatically qualifying for every crew
award.

## 13. Monetization: Earn Without Being Pushy

### Guiding principle

A purchase should be an optional answer to a real desire—not a solution to a frustration deliberately manufactured
by the game.

Do not add monetization until the free core loop produces repeat sessions and players are making meaningful progress
without paying.

### Potential ethical offers

**Cosmetic expression**

- Cabin theme bundles.
- Interior trim, wall finishes, lamps, and lighting colors.
- Decorative furniture variants.
- Unique but non-powerful train exterior accents.
- Personal emblems, signs, or nameplates.
- Cabin layout presets or saved designs if these offer real convenience.

**Optional convenience**

- Additional saved cabin layouts.
- More cosmetic preset slots.
- Convenience around organizing non-critical personal storage, if the free capacity remains reasonable.
- Optional craft queue or construction convenience, only if the free process is not intentionally tedious.

**Seasonal or collection content**

- A themed cosmetic set tied to a region or event.
- Collectible display pieces that do not provide gameplay power.
- Visual cabin collections with a clear preview before purchase.

### Monetization to avoid

- Forced purchase popups during a scavenging timer.
- Repeated prompts after a player declines.
- Fake countdowns or misleading scarcity.
- Paid access to friends or to the only viable expedition route.
- Paid survival, mandatory fuel, or essential train functionality.
- Deliberately painful recovery followed by a paid skip.
- Randomized paid rewards that obscure the odds or create pressure.
- A shop so prominent that it competes with the core objective.

### Purchase presentation

- Let players preview exactly what they receive.
- Show the price clearly before confirmation.
- Keep the shop discoverable but not intrusive.
- Never interrupt the departure timer with a sales prompt.
- Do not repeatedly prompt after a decline.
- Make free progression and paid expression visually distinct.

### Monetization experiments

Only test one or two offer types at a time. Compare conversion and revenue with retention, session length,
complaints, and free-player progression. A purchase that increases short-term revenue while harming return rate may
be a bad trade.

### Key measures

- Purchase conversion rate.
- Revenue per daily active user and per paying user.
- D1 and D7 retention for buyers vs. non-buyers.
- Progression rate for non-paying players.
- Shop open/close rates.
- Purchase refunds or negative feedback where available.
- Whether users can explain the value of the offer without feeling pressured.

## 14. Visual Direction and Art Quality

### Style target

Aim for stylized cinematic realism: rich lighting and material contrast, readable silhouettes, carefully composed
spaces, and atmospheric environmental storytelling without photorealistic asset cost.

The game should look memorable in a thumbnail and hold up when a player stands close to a cabin object.

### Highest-priority visual spaces

1. Station lobby and Hall of Records.
2. The first train corridor and arrival/departure sequence.
3. Personal cabin at its bare and upgraded stages.
4. The first region's signature landmark.
5. Resource nodes and collectible blueprints.

### Visual readability rules

- Resource types need distinct silhouettes and colors.
- Interactive objects need a clear state and readable prompt.
- Departure warnings must remain visible in different lighting conditions.
- Important routes should be readable without relying only on color.
- Avoid tiny text and delicate UI elements on mobile.
- Do not let atmospheric darkness hide the only route back to the train.

### Efficient art production

- Build modular environment kits.
- Reuse a controlled material palette.
- Use texture atlases where practical.
- Keep collision geometry simple.
- Use LOD or distance-based detail reduction.
- Limit transparent particle effects.
- Avoid too many dynamic shadow-casting lights.
- Use baked-looking or carefully controlled lighting where possible.
- Avoid large numbers of unanchored objects and complex physical interactions.
- Reuse props with variation in placement, damage, color, and lighting.

### Hall of Records performance

The Hall may show multiple historic crews, but not every display should have a fully detailed train and 20 fully
animated characters. Use a hierarchy:

- **Top record:** highest detail and limited animation.
- **Other prominent records:** simplified train and a smaller set of avatar representations.
- **Distant records:** static signage, silhouettes, or compact panels.

This preserves the emotional effect without creating an excessive rendering burden.

## 15. Mobile-First UX and Performance

Mobile is a first-order constraint, not a later optimization pass.

### UI requirements

- Large touch targets.
- Minimal text entry.
- Clear interaction prompts.
- A simple, persistent departure timer.
- Inventory and material counts visible without opening many panels.
- One-tap return/navigation affordances where appropriate.
- Controls that do not overlap the thumb zones.
- Readable contrast and scalable text.
- No essential information conveyed by color alone.

### Performance rules

- Test on low- and mid-range phones from the first prototype.
- Keep physics simple and predictable.
- Limit simultaneous dynamic lights and shadow casters.
- Use streaming and spatial loading intentionally.
- Avoid loading every car and every historical display at full detail.
- Keep remote events small and validate them server-side.
- Avoid per-frame server loops for systems that can update on a timer or state change.
- Use simple collision meshes and anchored set dressing.
- Profile before and after each major visual upgrade.

### Graphics tiers

Offer automatic or user-selectable low, medium, and high visual settings if needed. Graphics tiers may simplify
particles, shadows, and distant detail, but must not remove gameplay information or make resources harder to find.

### Performance acceptance targets

Choose specific measurable targets during prototyping. At minimum, monitor client frame rate, memory use, network
traffic, server heartbeat stability, load time, and input responsiveness under a full or near-full crew. Test a full
server with a mix of phones and desktop clients, not only a solo desktop session.

## 16. Technical Architecture

### Server-authoritative systems

The server must own:

- Expedition ID and current phase.
- Distance and milestone progression.
- Stop selection and stop timers.
- Resource node availability and collection results.
- Player inventory and resource transfers.
- Shared train inventory and upgrades.
- Fuel consumption and train condition.
- Player eligibility, crew roster, and capacity.
- Stranded-player and recovery state.
- Record eligibility and final record submission.
- Any purchase grants and paid entitlements.

Clients can request actions and display state, but they cannot authoritatively declare that an item was collected,
an upgrade was completed, or a record was achieved.

### Persistent player profile

Suggested data areas: profile schema version; personal cabin stage; built items and their variants; layout/slot
assignments; personal storage inventory; unlocked recipes and blueprints; achievements and collections; cosmetic
entitlements and equipped cosmetics; tutorial progress and accessibility settings; last known expedition metadata if
needed for rejoin handling.

### Live expedition state

Suggested data areas: unique expedition ID; server/job identifier; train name, configuration, and appearance; crew
roster and join/leave times; current distance and milestone; current region and stop variant; current phase and
authoritative timestamps; shared inventory, fuel, and upgrade state; resource node states; current objective;
recovery state for stranded players; record eligibility metadata.

### Historical record

Suggested fields: expedition ID; final verified distance; start and end timestamps; region and milestone sequence;
crew members and participation windows; contribution summary; train configuration/appearance snapshot or versioned
reference; record eligibility version; data schema version.

### Data integrity and reliability

- Use server-side validation for every inventory change.
- Use transaction IDs or equivalent idempotency for important grants and deposits.
- Handle data-store throttling and transient failures with bounded retries and safe fallbacks.
- Do not repeatedly overwrite profile data from stale client state.
- Separate personal persistence from live expedition state.
- Save at sensible milestones and on player departure, while recognizing shutdown can interrupt saves.
- Use schema migrations for future updates.
- Test duplicate events, teleport failures, server shutdown, and reconnects.
- Avoid trusting client timestamps for record eligibility.

### Suggested service boundaries

Keep responsibilities modular even if the project begins in one place:

- **ProfileService** — load/save personal profiles and migrations.
- **ExpeditionService** — phase, distance, stop flow, and end state.
- **TrainService** — fuel, condition, shared upgrades, and train presentation state.
- **ResourceService** — nodes, pickups, inventory validation, and deposits.
- **CabinService** — buildable items, layouts, and cabin progression.
- **JoinService** — friend joining, capacity, queues, and teleport handling.
- **RecoveryService** — stranded state and recovery objectives.
- **RecordService** — eligibility, finalization, and Hall of Records data.
- **MonetizationService** — purchase validation and entitlement grants.
- **UIStateService** or shared state modules — stable state contracts for client displays.

These names are architectural suggestions, not a requirement to create an oversized framework before the prototype
works.

## 17. Exploit Prevention and Abuse Cases

At minimum, test against:

- Client claims it collected a resource without reaching a node.
- Client sends an arbitrary resource amount.
- Client repeats a pickup or purchase grant.
- Client requests an upgrade without required materials.
- Client submits fake distance or record data.
- Client joins a full server by bypassing the intended flow.
- Client tries to deposit the same inventory twice.
- Client tries to withdraw shared critical resources.
- Client spams friend-join, recovery, or interaction requests.
- Client changes local timer values to avoid departure.
- Client tries to duplicate items through disconnect/reconnect timing.

Use rate limits, server-side distance checks, server-owned state, validated transactions, and explicit state
transitions. Security work should focus on high-value state changes first: inventory, purchases, upgrades,
expedition distance, and records.

## 18. Social Systems and Cooperation

### Encourage natural cooperation

- Shared objectives should be visible and understandable.
- Players can help carry resources or show newcomers a route.
- Some discoveries should benefit the whole train.
- Cabin visits and car-to-car movement create natural social spaces.
- Crew milestones should celebrate the group.
- Individual achievements should reward useful actions without turning the game into a toxic leaderboard.

### Avoid social pressure traps

- Do not shame players who do not donate.
- Do not make a player's personal cabin progress depend on strangers behaving generously.
- Do not make one person solely responsible for fuel or repairs.
- Do not make idle players block every shared decision.
- Provide useful tasks for players who arrive late or have limited time.

### Optional roles later

Potential roles such as scavenger, mechanic, navigator, courier, or signal operator may be introduced after the base
loop is stable. In the MVP, avoid hard classes that prevent players from switching tasks or helping friends.

## 19. Onboarding and Tutorial Design

### Teach in context

- In the cabin, teach the build interaction and show the next upgrade.
- At the first stop, teach one resource pickup.
- When the timer starts, teach the return rule.
- At the train, teach depositing or crafting.
- At the shared upgrade, teach the personal-vs-team choice.
- In the station, teach friend joining and the Hall of Records.

### Tutorial rules

- Keep each instruction short.
- Prefer arrows, highlights, and contextual prompts over paragraphs.
- Let experienced players dismiss repeated instruction.
- Remember tutorial progress across sessions.
- Provide late joiners with a short contextual tutorial rather than replaying the full new-player sequence.
- Do not place the player in a state where they can fail the expedition while reading instructions.

### First-session success measures

Track how many players:

- Finish the first cabin interaction.
- Leave the train at the first stop.
- Collect at least one resource.
- Return before departure.
- Complete one personal upgrade.
- Participate in one shared milestone.
- Reach a second stop.
- Join or invite a friend.

Find the biggest drop-off and fix it before adding more content.

## 20. MVP Scope

### Must build

1. One enclosed station lobby.
2. A visible Hall of Records prototype.
3. One modular train with connected cars.
4. One persistent personal cabin per player.
5. One polished region.
6. Three stop variants, with a fourth only if needed for variety.
7. Four core resource types.
8. A 2–3 minute scavenging timer with clear warnings.
9. Controlled train travel and arrival/departure presentation.
10. One early personal cabin progression chain with roughly 10–15 upgrades.
11. One shared train upgrade chain with at least two meaningful stages.
12. Server-owned distance and expedition phase.
13. Basic friend join and full-server messaging.
14. Safe late join behavior.
15. Simple record creation and Hall of Records display.
16. Mobile-first UI and performance testing.
17. Basic recovery for players left behind, even if the first version is deliberately simple.
18. Basic telemetry for retention and core-loop completion.

### Explicitly postpone

- Monsters and combat.
- Multiple large regions.
- Complex rescue vehicles.
- Player trading or an economy market.
- PvP and sabotage.
- Complex skill trees and classes.
- Unrestricted free-placement building.
- Dozens of cabin furniture sets.
- Large paid shop expansion.
- Many different currencies.
- Full physical train simulation.
- Elaborate branching narrative and cinematic cutscenes.

### Definition of MVP success

The MVP is successful if players repeatedly choose to take another stop, feel proud of a visible cabin change,
understand the shared train goal, and can reliably join friends. It is not successful merely because the map is
large or the game has many assets.

## 21. Production Roadmap

### Phase 0 — Paper design and technical spike

Goal: Remove major uncertainty before building content.

Tasks: define the authoritative expedition state machine; define player profile and record schemas; test
teleporting into a specific friend server and handling full capacity; prototype the controlled travel illusion; test
basic cabin persistence; establish a mobile performance baseline.

Exit criteria: a player can enter a test server, join a defined state, and retain a simple saved value; the train can
simulate travel and stop transitions without full physical simulation; the architecture has a clear source of truth
for distance, inventory, and timers.

### Phase 1 — Core loop graybox

Goal: Prove the loop with placeholder art.

Tasks: build one graybox station, train car, and stop; add a resource node and inventory; add the departure timer and
return rule; add travel and arrival states; add a basic personal cabin build action; add one shared upgrade.

Exit criteria: a new player can complete a full loop without developer instruction; the loop feels understandable and
creates a reason to take another stop.

### Phase 2 — Persistent progression and multiplayer

Goal: Make progression survive sessions and work with a crew.

Tasks: add profile saving and migrations; add multiple players collecting resources; add shared inventory and upgrade
validation; add friend join and full-train UI; add late join summary; add reconnect and shutdown behavior.

Exit criteria: no routine duplication or loss of persistent cabin progress in test scenarios; friend joining is clear
and reliable.

### Phase 3 — First polished region

Goal: Turn the graybox into a visually memorable vertical slice.

Tasks: build modular Overgrown Line assets; create three distinct stop layouts; add resource silhouettes and landmark
storytelling; polish train sounds, announcements, lights, doors, and transitions; build the first cabin visual upgrade
sequence; add the first Hall of Records presentation.

Exit criteria: the first 10–15 minutes feel cohesive, atmospheric, and rewarding.

### Phase 4 — Closed playtest and balance

Goal: Find retention and usability failures.

Tasks: run solo, small-party, and near-full-server sessions; test on phones and lower-end hardware; observe first-time
players without explaining the game; tune resource yields, recipes, timer, and stop layouts; test leaving,
reconnecting, late joining, and being stranded; collect qualitative feedback and core metrics.

Exit criteria: the most common early confusion is fixed; players can reliably complete the first upgrade and
understand the next goal.

### Phase 5 — Limited release

Goal: Validate return behavior before scaling content or monetization.

Tasks: release a stable version to a limited audience; track first-session completion, D1/D7 retention, session
duration, and friend joins; fix crashes, save failures, and matchmaking friction; test only minimal cosmetic
monetization after the free loop is working.

Exit criteria: retention and repeat-session behavior show a credible upward trend after iteration; no critical
reliability or fairness problems remain.

### Phase 6 — Expand carefully

Goal: Add depth without undermining performance or clarity.

Possible additions: more stop variants; additional cabin specialist paths; a second region; more shared train
milestones; environmental hazards; more cosmetics and collection displays; better historical records and expedition
summaries.

Only expand the content type that player behavior indicates is most valuable.

## 22. Analytics and Decision Metrics

Visits are not the main success metric. The important question is whether players understand the game, return, and
build a habit around their own cabin and the crew's journey.

### Funnel metrics

- Tutorial started and completed.
- First cabin interaction completed.
- First stop entered.
- First resource collected.
- First successful return.
- First cabin upgrade completed.
- First shared upgrade contributed to or completed.
- Second stop reached.
- Session ended and reason if available.

### Retention and engagement

- Average session duration.
- Median session duration.
- Stops per session.
- Distance per active player-minute.
- D1 retention.
- D7 retention.
- Repeat expeditions per user.
- Cabin upgrades per session and per week.
- Percentage of players who visit another player's cabin.
- Friend-join attempts and success rate.
- Full-train queue abandonment.
- Stranded-player rate and recovery completion.

### Economy and fairness

- Resources gathered per stop.
- Resources banked vs. lost.
- Personal vs. shared spending of flexible materials.
- Distribution of shared contributions.
- Time to first cabin upgrade.
- Time to first shared upgrade.
- Percentage of players who feel stuck at a resource bottleneck.
- Progression speed for non-paying players.

### Monetization

- Shop visits.
- Offer impressions and declines.
- Conversion rate.
- Revenue per daily active user.
- Buyer vs. non-buyer retention.
- Whether purchases correlate with frustration or failure.

### Decision rules

- If players leave before the first stop, improve onboarding and the first arrival—not the shop.
- If players scavenge but do not return, clarify the timer and route or tune stop layout.
- If players return but do not upgrade, improve reward visibility, recipe clarity, or resource balance.
- If players upgrade once but do not take another stop, the next goal may be unclear or the loop may lack novelty.
- If shared contributions are near zero, do not simply shame or force donation; improve shared benefits and make the
  contribution decision clearer.
- If the game performs poorly with 20 players, reduce active simulation or lower the tested capacity rather than
  accepting a bad mobile experience.

## 23. Risks and Mitigations

| Risk | Why it matters | Mitigation |
|---|---|---|
| The loop feels calm or empty | Players may not feel tension | Improve stop variety and meaningful choices; add one environmental hazard only if needed |
| Personal upgrades are too slow | Players do not feel rewarded | Tune first 3–5 upgrades for quick, visible wins |
| Shared upgrades are ignored | Cooperative progression feels fake | Improve shared benefits, clarity, and distinct train-only materials |
| Players resent donating | Social systems feel coercive | Avoid shaming, percentage requirements, and forced contributions |
| Timer feels unfair | Players lose trust | Clear warnings, visible routes, readable maps, and balanced stop layouts |
| Players get left behind too often | Frustration can cause exits | Improve warnings, return routes, and a short recovery experience |
| Late joiners disrupt the crew | Social play becomes chaotic | Safe entry compartment, concise summary, controlled permissions |
| Friend join fails | The social promise breaks | Explicit capacity states, retry handling, no silent random routing |
| Server shutdown loses progress | Players lose trust | Separate persistent cabin data, save at milestones, test shutdown recovery |
| 20-player performance suffers | Mobile players leave | Profile early, reduce physics, simplify distant cars and displays |
| Hall of Records is too expensive | Signature feature harms performance | Use tiers of detail and static historical representations |
| Monetization feels pushy | Retention and reputation suffer | Delay monetization, preview items, no forced prompts, protect free progression |
| Too much content is built too early | Development time is wasted | Prove one region and the first 15–20 cabin steps before scaling |
| Record cheating | Competitive integrity breaks | Server-owned distance and idempotent record finalization |

## 24. Launch Readiness Checklist

### Core gameplay

- [ ] A first-time player can understand the cabin and first objective.
- [ ] The first stop has a clear landmark and return route.
- [ ] Departure warnings are audible and visible.
- [ ] The player can tell which resources they have collected.
- [ ] The first cabin upgrade creates a visible change.
- [ ] The shared train upgrade visibly changes the train or its capabilities.
- [ ] Players understand whether materials are personal, shared, or flexible.
- [ ] A player can finish or abandon a session without corrupting persistent progression.

### Multiplayer

- [ ] Players can join a friend when capacity allows.
- [ ] Full trains show clear alternatives.
- [ ] Late joiners receive useful context.
- [ ] Disconnect and rejoin states are tested.
- [ ] A departing player does not break the expedition state.
- [ ] Shared inventory is validated server-side.

### Records

- [ ] Distance is server-calculated.
- [ ] Duplicate record submissions are prevented.
- [ ] Historic records show the right crew and distance.
- [ ] Avatar/display failures have fallbacks.
- [ ] Record eligibility is understandable.

### Persistence and safety

- [ ] Personal cabin progress survives rejoining.
- [ ] Data schema migration is tested.
- [ ] Save failure has a safe fallback and useful logging.
- [ ] Purchase grants are validated and idempotent.
- [ ] Critical interactions have rate limits.

### Performance and UX

- [ ] Low- and mid-range mobile devices are tested.
- [ ] UI targets are comfortable for touch.
- [ ] Important information is readable at different graphics settings.
- [ ] Full-server performance has been profiled.
- [ ] No essential route or resource depends only on color.
- [ ] Visual effects do not obscure the timer or interaction prompts.

### Monetization

- [ ] The free core loop is enjoyable without purchases.
- [ ] Offers have clear previews and prices.
- [ ] No prompt interrupts a scavenging timer or departure sequence.
- [ ] Declining an offer does not trigger repeated prompts.
- [ ] Paid content does not gate joining friends or basic train functionality.

## 25. Decisions to Lock Before Expanding

These questions should be answered through a small prototype and playtests, not by trying to design every future
possibility in advance.

1. **Cabin ownership:** Start with one persistent cabin per player. Only add multiple owned cars if the first cabin
   loop creates a strong long-term habit.
2. **Building placement:** Start with curated snap points and limited variants. Add free placement only after mobile
   UX and persistence are stable.
3. **Resource set:** Start with four common resources and one blueprint type. Add fuel as a shared resource if it
   makes the crew's goal clearer.
4. **Fuel balance:** Decide whether fuel is consumed by time, distance, region, or a combination. Make the rule visible
   and predictable.
5. **Expedition length:** Tune around repeatable short stops, not an arbitrary huge runtime. Test whether players
   want one more stop or feel trapped in a long session.
6. **Late join credit:** Define minimum participation for full crew-record credit while allowing late joiners to
   contribute meaningfully.
7. **Shared upgrade authority:** Small upgrades can be automatic when funded; large irreversible specializations may
   need a simple crew confirmation with a timeout.
8. **Stranded recovery:** Start with one simple recovery mission and validate that it feels tense rather than
   punitive.
9. **Monsters or hazards:** Begin with no monsters. Add hazards only if measured playtests show a need for more
   tension.
10. **Server capacity:** Target 20, but ship at the highest player count that remains stable on real mobile devices.
11. **Hall of Records fidelity:** Use a high-detail hero display and progressively simpler distant displays.
12. **Paid convenience:** Do not sell recovery or crafting shortcuts until the free versions are proven fair and
    enjoyable.

## 26. Recommended Immediate Build Order

If development begins now, follow this order and resist expanding sideways.

1. **Write the state machine.** Define Lobby, Traveling, Arriving, Scavenging, DepartureWarning, Departing, Recovery,
   and Ended states, including valid transitions and timeouts.
2. **Build a graybox train and stop.** Use placeholder shapes and focus on route clarity.
3. **Implement the authoritative timer and distance.** The server decides phase changes and distance gains.
4. **Add one resource node.** Validate the interaction, inventory update, and UI.
5. **Add one cabin upgrade.** Require materials and make the result visible.
6. **Add a second player.** Confirm that shared world state and individual inventories behave correctly.
7. **Add a shared train upgrade.** Show a before-and-after change that players can recognize.
8. **Add profile persistence.** Test leaving, rejoining, duplicate events, and failed saves.
9. **Add friend joining and capacity handling.** Test successful join, full server, friend leaving, and teleport
   failure.
10. **Add the first three stop variants.** Reuse modular assets while making their layouts and landmarks distinct.
11. **Add the Hall of Records.** Start with a single verified record and a lightweight display.
12. **Profile mobile performance.** Do this before adding a lot of decorative content.
13. **Run first-time-player tests.** Watch without explaining. Fix confusion before adding features.
14. **Measure repeat behavior.** Use data to decide whether the next investment should be more stop variety, more
    cabin progression, better social play, or stronger shared milestones.
15. **Only then consider monetization.** Begin with one optional cosmetic offer and monitor the effect on retention
    and sentiment.

## 27. The Standard for Every New Feature

The long-term fantasy is not simply "collect items on a train." It is:

> I have a little home that keeps becoming more mine. I travel with a crew through places I have never seen. The
> train we improve together gets farther than the last one. My friends can visit, my discoveries have a place in
> history, and every stop gives me a reason to risk one more trip outside.

Build toward that feeling in small, testable increments. One excellent stop, one satisfying cabin upgrade, one shared
train milestone, and one reliable friend-join flow are worth more than a huge map full of unfinished systems.
