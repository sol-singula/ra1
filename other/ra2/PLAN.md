# ra2 plan: Steal a Dragon

Status: built. See [README.md](README.md) for how to run and play it; this is the original plan.

## 1. What's trending (October 2026)

- **"Steal a ___" is the biggest genre on Roblox right now.**
  - **Steal an Egg** is the #1 game: about 1.2 to 1.6 million players online in early October.
  - **Steal a Brainrot** started the wave in 2025. It holds the record of 25 million+ players online at once, and its developer has sued close copies.
- **How the genre works:** grab a creature, run it home, and it earns money every second. Other players can steal it while your base door is open.
- **Other big games:** 99 Nights in the Forest, Grow a Garden-style idle games, and Adopt Me / Brookhaven. Pets, idle income and playing with friends keep winning.
- **What to avoid:**
  - Roblox now blocks games that reward watching a feed from Roblox Kids and Select. Steal an Egg's treadmill feed caused that rule.
  - Roblox asks for titles and thumbnails that don't look like another game's.
  - Steal a Brainrot's lawyers go after clones.

We use the genre (the verb), not anyone's look or name. "Steal an Egg" is taken, so we pick a different noun with
its own hook.

## 2. Title

Format: **Steal a [Noun]**

| Pick | Why |
|---|---|
| **Steal a Dragon** (recommended) | Dragons are loved by kids, easy to make in many colours, and can *grow*, which is our hook. Not a pet egg, so it doesn't look like Steal an Egg. |
| Steal a Dino | Same appeal and the same growing hook. Some low-quality "Steal a Dinosaur" games already exist. |
| Steal a Robot | No clear competitor found. Robots can "upgrade" instead of grow, but they're less cute and less collectible. |

Before locking it in, search the name on Roblox and check that no big game already uses it.

## 3. The game in one line

**"Steal baby dragons. They grow while you sleep. Big dragons make big money, and everyone wants them."**

- **Core fantasy:** to steal.
- **Implied challenge:** the best dragon is in someone else's base, and you have to steal it.

## 4. How it plays (3rd grade words)

1. **Grab** a dragon from the Dragon Road in the middle of the map.
2. **Run home.** Carrying a dragon makes you slow, and bigger dragons are slower.
3. **Put it in a nest.** It makes coins every second.
4. **Lock your door.** The lock lasts 60 seconds, then you have to lock it again.
5. **Sneak into other bases** and steal their dragons. If someone takes yours, chase them and bonk them to get it back.
6. **Buy more nests.** Get rarer dragons, then grow them big.

Every word on screen should be one a 3rd grader can read: Grab, Run, Home, Lock, Steal, Coins, Grow, Nest. Use
icons and arrows over text.

### Dragons

- **One model, many colours.** Rarities are set by colour and glow: Common, Rare, Epic, Legend, Secret.
- **Size stages:** Baby, then Kid, then Big, then Giant. Each stage doubles the coins. Dragons grow by real time,
  even when you're offline.
- **Specials** are a coloured sparkle on top, worth ×2 to ×5: Fire, Ice, Gold, Rainbow.

## 5. Why players stay

These map onto the signals Roblox's "Recommended for you" uses (Discovery FAQ).

| Roblox signal | Our feature |
|---|---|
| **Play-through rate** (they click) | A clear icon showing a kid running with a big glowing dragon and a "STEAL A DRAGON" title. The video shows the real game. |
| **First-play bounce** (they leave fast) | Holding a dragon within 10 seconds. First steal within 60 seconds, from a training base that guides you with an arrow (reuse the ra1 tutorial system). Coins pop up right away. |
| **Playtime** | Coins tick up, a rare dragon spawns every few minutes, and "LEGEND DRAGON IN 0:30" timers. You're always one steal from a big jump. |
| **Play days** (come back on day 2) | (1) **The overnight egg:** the end of session 1 gives a free egg that hatches tomorrow. (2) Dragons grow overnight. (3) An offline coin jar that fills in about 8 hours. (4) A daily gift streak where day 2 is a guaranteed Rare. (5) A new Dragon Road shop each day. |
| **Co-play days** (playing with friends) | Friends in the same server get +10 % coins each, up to +30 %. **Team bases:** up to 3 friends share one bigger base, so one guards while the others steal. "Friend Raid" bonus coins when friends steal together. |
| **Spend days / Robux spent** | Small daily deals plus the passes and products in section 6. |

### Getting friends to invite friends

- **Invite button** on the main screen ("Play with friends = more coins!").
- **Team bases** are only possible with friends, and a team base gets the biggest nests.
- **Friend bonus coins** whenever a friend is in your server. This lines up with Roblox's co-play signal.
- **Reward when an invited friend actually joins** (a free Rare egg). Check Roblox's current rules on invite rewards
  before shipping. The co-play bonus above is always allowed.

## 6. Making money (intentional, but within Roblox rules)

The paid items help you get ahead. They don't unlock a different game. Everything is a **fixed item, never a random
roll**. That keeps us out of Roblox's paid-random-item rules: odds disclosure, and bans for some ages and countries
(UK, Australia, Brazil).

**Game passes (buy once)**

| Pass | Price (Robux) |
|---|---|
| 2× Coins | 129 |
| VIP: +50 % coins, VIP door, +15 s lock, name tag | 449 |
| Fast Feet: +25 % speed carrying | 199 |
| Extra Nests (+4) | 249 |
| Auto Collect | 149 |
| Long Lock: 120 s instead of 60 s | 199 |

**Developer products (buy again and again)**

| Product | Price (Robux) |
|---|---|
| Lock Now (instant re-lock) | 19 |
| Grow Now (one stage) | 29–99 |
| Hatch Now (overnight egg) | 49 |
| Server Luck: 15 min of rarer spawns for *everyone* in the server, with the buyer's name shown | 99 |
| Buy this Legend from the Dragon Road right now | 149–399 |
| Coin packs | 49–999 |
| Troll gear: bonk bat skins, banana peel trap | 49–149 |
| Daily deal (cheap, changes daily) | 25 |

Server Luck counts as both spending and playing together, and it makes the buyer a hero to the server.

**Rules we keep:**
- No rewards for watching feeds or ads.
- No fake buttons.
- Prices are always shown before you buy.
- Offline bases can't be robbed, so kids don't log in to find everything gone.

## 7. Small enough to build

- **One map:** 8 bases in a ring around the Dragon Road. No vehicles, no pathfinding.
- **One dragon model** recoloured and scaled. Specials are particle effects.
- **Systems:** spawn road, carry and drop, nests and coins, lock door, steal and bonk, growth timers, offline coins,
  daily gift, team base, shop.
- **Reuse from ra1:** Rojo layout, service loader, Net with rate limits, PlayerData saving, the tutorial arrow, HUD
  theme, and the mock engine and tests.

## 8. Build order

1. **Base loop:** road spawns, grab, carry, nest, coins, lock, steal. Bots in tests.
2. **First-play flow:** training base, arrow guidance, first steal within 60 s.
3. **Growth plus the day-2 hooks:** overnight egg, offline coin jar, daily gift.
4. **Friends:** friend bonus, team bases, invite button.
5. **Shop:** passes, products, Server Luck.
6. **Polish:** icon, thumbnail, trailer, sounds, screenshots.

## Sources

- [Most played Roblox games, Oct 4 2026 (Endgame Tools)](https://endgametools.com/en/roblox/charts)
- [Trending Roblox games (RBLXSTAT)](https://rblxstat.com/lists/trending-roblox-games)
- [Steal An Egg on Rolimons](https://www.rolimons.com/game/107778070777162)
- [Roblox bans feed-reward games after Steal an Egg (eGamers)](https://egamers.io/roblox-bans-games-that-pay-kids-to-keep-scrolling-in-wake-of-steal-an-egg-uproar/)
- [Steal a Brainrot (Wikipedia)](https://en.wikipedia.org/wiki/Steal_a_Brainrot)
- [Steal a Brainrot battles imitators (Bloomberg)](https://www.bloomberg.com/news/articles/2026-03-24/roblox-s-hit-game-steal-a-brainrot-battles-its-many-imitators)
- [Roblox Discovery FAQ](https://create.roblox.com/docs/discovery-faq)
- [Recommended For You update (DevForum)](https://devforum.roblox.com/t/boost-your-discovery-with-the-improved-recommended-for-you-algorithm-and-analytics-for-creators/3587441)
- [Clarifying requirements for paid random items (DevForum)](https://devforum.roblox.com/t/clarifying-requirements-for-paid-random-items/4654622)
- [Steal a Brainrot game passes](https://buffget.com/news/steal-a-brainrot-gamepasses-guide-vip-and-2x-money-2026)
- [Games like Steal a Brainrot (Sportskeeda)](https://www.sportskeeda.com/roblox-news/5-roblox-games-like-steal-brainrot-july-2025)
