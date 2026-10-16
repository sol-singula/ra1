# ra9 · the build plan and what was built

## Round 1 (October 2026): the playable core

Phases A to E of the master plan (§9), tested on the mock engine.

**A. Scaffold.** `games/ra9 - Turf Wars Overdrive/` from the studio's engine (the service loader, the typed remotes
with per-player rate limits, the session-locked saves, the mock engine and the Luau test runner), the master plan.

**B. The match** (`MatchService`, `TeamService`, `ProgressService`)
* Players join straight into the running match. Teams keep friends together (a party may put its team up to two
  ahead) and balance solo players round them; between matches teams are rebalanced.
* Phases: build 60 s → fight 120 s → build... until a team has no turf; then the results (7 s) and the next map
  in the same server (3 s). A watchdog restarts a match running 45 minutes (logged, never "won").
* The frontline is the server's number. A valid kill (opposing teams, the fight, a real attacker) moves it
  `Formulas.pushCells(players)` cells toward the victim's base: 1 cell in a full server, up to 3 in a small one.
  Falls, resets and friendly fire never move it. A team loses when the line reaches its spawn zone.
* Turf Wars' rule: step onto enemy turf and you're put back on your side.
* Respawn 3 s after going down, 2.5 s of spawn protection.
* Results: everyone's kills, deaths, assists and structures, best first, an MVP (kills ×10, assists ×4, built ×1).
* A qualifying win (on the winning team, in the match 2+ minutes, active) unlocks the next step of the 100-win
  ladder (`Data/Ladder`: arrow trails, bow finishes, kill effects, banners, and a title every 10th win, Recruit to
  Overdrive), streak badges at 3, 5 and 10. All cosmetic.

**C. The maps** (`World/ArenaBuilder`, `World/Maps/*`): one reusable arena (the turf strips, walls with an
invisible shell to a ceiling, a kill plane, spawn zones with ten pads a side) and four layouts in the SUPERHOT
style, mirrored for fairness: Castle Clash (a courtyard: colonnades, gate arches, battlements, a fountain),
Frostbite (a glacier: a high terrace, leaning ice walls, shards, a ridge with three gaps), Jungle Rush (stepped
temples, broken walls, a pillar grove with geometric leaf canopies, a ruined gate), Dust Devil (a canyon of mesas,
two railed bridges, tall angled slabs, an open floor). Each has its own off-white tint and light.

**D. Combat and building** (`CombatService`, `BuildService`)
* Three free bows (`Data/Weapons`): the Standard Bow (a full draw kills), the Rapid Crossbow (34 a bolt, six to a
  magazine, a reload), the Heavy Bow (slow, huge knockback, wrecks structures). None strictly better.
* The server times every draw itself, flies every arrow in 1/30 s steps along the same curve the clients draw,
  against head and body spheres and every solid box (map and structures), and decides hits (heads ×1.35),
  knockback (capped), kills and assists (6 s window). No friendly fire, no damage outside the fight.
* Seven structures on the 4-stud grid (`Data/Structures`), only on your own turf, a cell back from the line, out of
  the spawn zones, within reach; 100 points a player each build phase, a team cap; no wall may close the last
  openings of any row across the field; arrows chip them, the heavy bow breaks them; your own refunded in the build
  phase.

**E. The client**: locked first person (a steady view, a draw zoom, light shakes, sensitivity), the bow in your
hands (string pull, the nocked arrow, the kick), predicted arrows with SUPERHOT tracers in team colours, the build
tray and a snapping preview (white where it can go, red with the reason where it can't), the HUD (phase and clock,
the frontline bar, the objective, the charge, hit markers, the kill feed, health, the bows, build points, results,
unlock cards), sprint, slide, the front flip on every 4th jump, knockback, touch controls (FIRE, RUN, SLIDE, PLACE,
TURN).

**Tests**: 84 unit checks (rules, data, every map built and checked for fairness, closure and open lanes), 66 server
checks (a whole match: teams, building rules, arrows, kills, the line, the turf rule, structures breaking, the
crossbow's magazine, victory, rewards, the next map), 38 client checks (the same through the real client).

## Round 2: the win

* **30 seconds from the win to the next game.** The results card (12 s, compact, under the top bar), then a big
  NEXT GAME IN countdown in the winners' colour; the top pill counts down the whole time.
* **Fireworks** in the winners' colour all over the arena for 14 s: rockets that burst into neon shards (the team's
  colour, a lighter shade, white), drawn on each client from the match's Winner (fewer on phones).
* **Asking the winners** (`FeedbackService`, `FeedbackController`), 6 s after the win so it lands after the
  fireworks start: "Are you liking the game?" YES / NO at most once a day; after a YES, their next win asks for a
  👍 like (once). Roblox doesn't let a game press its like button, so the card asks and its button opens Roblox's own
  favourite prompt. The buttons free the mouse from first person; Y / N answer too.

![](screenshots/victory.png)

## Round 3: a thank-you, and nothing on top of anything

* **The Thank-You Trail** (`Data/Extras`): answering "Are you liking the game?" (YES *or* NO: it's the answer that's
  thanked, not liking it, so it stays within Roblox's rules on rewards) gives a trail once, worn straight away: a
  thin white line running beside your arrows' team-coloured tracer, seen by everyone. A THANK YOU card shows it.
  The like / favourite card gives nothing. Kept in the profile (`extras`), equippable again later.
* **Popups have slots** (checked on the smallest canvas, 1240 x 560):
  * unlocks and thank-yous stack down the right under the kill feed, two at a time, the rest waiting their turn
    (they used to sit in the middle, on the results card);
  * the results card shows 5 rows (yours in the last if you're further down) and ends above the question card;
  * no "RED WINS" alert on top of the results card (the card says it);
  * the toast moves up above the build tray's hint in the build phase, and between the results and the question
    card while one is up;
  * the kill feed is 300 wide (it touched the top bar), the objective and alerts narrower;
  * on phones RUN/TURN and SLIDE moved clear of the bows panel and of each other.
* **Words shrink to fit their boxes** inside every card (`Theme.text { fit = n }`), whatever the player's text-size
  setting, and each card's title, words and buttons have their own bands.
* **Tested**: ClientSmoke works out every piece's rectangle and checks that nothing overlaps in the build phase, the
  fight, a win with everything at once (a 12-player table, the question, three unlocks, a toast) and the countdown,
  that nothing sticks out of its card, and that the card words shrink to fit (put back the old feed, buttons and
  table and it fails on each). 84 unit, 83 server, 63 client checks.

## Round 4: invite a friend, both get something

* **INVITE A FRIEND** at the top left (or **I**; on phones a tap): Roblox's invite prompt, with LaunchData
  `i:<your UserId>` ("Come fight with me! We both get the Buddy Trail."). Clickable with the mouse between games.
* **When the friend joins from it** (`InviteService`; a share link counts too, through `ReferredByPlayerId`), the
  friend gets the **Buddy Trail** (two white lines, one each side of the tracer) with an "A FRIEND INVITED YOU!" card,
  and so do you, with "FRIEND JOINED! · Pal came from your invite".
* **Fair:** you must be Roblox friends and not the same account; the friend is credited once ever; you're credited
  once per friend (each new friend still gets you the card and counts in `profile.invite.count`); the trail itself
  is given once.
* **In another server?** The invite usually lands them in yours, but if not, your credit waits in the
  `TWO_InviteCredits_v1` DataStore and you get it the next time you join.
* Tests: 84 unit, 94 server (joining, the cards, rejoining, a stranger, yourself, the inviter elsewhere), 69 client
  (the button, the I key, the trail's lines, the button in the overlap check).

## Next (phase F)

* The Discord log and analytics (the studio's shared pipeline), the dashboard entry.
* Bots for small servers (so one or two players still get a fight), lag compensation for hits.
* The rest of the cosmetics applied in play (the ladder's trails, bow finishes, kill effects, banners, titles) and a
  locker to pick them.
* The icon and store thumbnails from these renders, the place, publishing.
