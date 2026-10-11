### 19.10 Edge Cases

| # | Situation | Ruling |
|---|---|---|
| N1 | A quest needs an NPC in a district with no players loaded | The proxy spawns when the player enters the district (QUEST/AMBIENT spawn rule), and quest markers on the map always show the anchor position. |
| N2 | Story NPC "visits" the player's restaurant (Grimewell in `QST_STY_003`, Zorp in `QST_STY_014`, Baron in Ch. 9) | `NPCService` spawns a temporary proxy inside the owner's instanced interior. Co-op guests see it, but only the owner's quest advances. Guests get a "witness" bark. The proxy despawns when the beat ends or after 10 min. |
| N3 | Two players with different quest states talk to the same NPC | Dialogue is per player. The NPC faces the latest speaker, and neither conversation blocks the other. |
| N4 | Player disconnects mid-dialogue | No effect is applied until the server has processed the choice. `TurnIn` is a single atomic `QuestService` transaction (§20.7), so a half-finished conversation can never pay out. |
| N5 | NPC is moved by an event override (§19.5) while holding a quest marker | The marker and waypoint follow the NPC. Turn-in works at the override location, and the NPC returns to its anchor when the event ends. |
| N6 | King Ratbeard during `EVT_007` | Not talkable while in boss state (prompt label "Busy being dramatic"). Hearts and gifts are suspended until the event ends. |
| N7 | Baron Von Bistro before and after `QST_STY_029` | The dialogue tree switches pools on the flag `baron_friend`. Hearts unlock only after the flag is set, and earlier Heart points are not retroactive (the Baron "was being difficult"). |
| N8 | Player stands on an NPC's waypoint | The NPC waits 3 s, says a polite bark, then poofs to the next node (§19.7). It never pushes players. |
| N9 | Gift exploit attempts (spamming remotes, gifting un-cooked dishes) | The server checks `recentDishes` (served ≥ GOOD in the last 24 h) and `lastGiftDay[npc] < today`. Failing requests are dropped and rate-limit strikes are logged (§29). |
| N10 | Missing localization key | The EN source string is shown, and an `mmr_loc_missing` analytics event fires with the key. The UI never shows a raw key. |
| N11 | Player is In Combat or targeted by a level-5 customer near an NPC | The prompt is hidden. If dialogue was already open, it auto-closes and the player gets the canon 1.5 s invulnerability (E2). |
| N12 | Low-end mobile device | The client visual cap drops from 25 to 12 named NPCs (nearest first; quest-marker NPCs are prioritized). Barks still show as bubbles above impostors. |
| N13 | Player is in a different chapter from a friend in the same server | NPC positions and lines that depend on the chapter are client-local overlays. The shared server proxy stays at the NPC's neutral anchor, so each player sees their own story state. |

### 19.11 Dependencies

- **§18 / §36.10 / §36.11:** building interiors, anchors, waypoint graphs and event schedules (`EVT_` overrides).
- **§20:** quest IDs, states and markers. Dialogue effects call `QuestService` (`OfferQuest`, `TurnIn`, `TalkObjective`).
- **§12 / §36.3 / §13:** mutation parts used in NPC morphs; `MorphAssemblyService` builds the visuals.
- **§25 / §26 / §36.14 / §36.15:** signature meshes, idle animations, blip voices and bark SFX (A16 assigns IDs).
- **§24:** dialogue box, heart row, quest markers and the "Friends of Morph City" journal tab.
- **§27 / §28 / §29:** service hosting, the `profile.npc` schema, and remote rate limits.
- **§31:** analytics events `mmr_npc_talk {npcId, nodeId}`, `mmr_npc_gift {npcId, recipeId, fav}`, `mmr_npc_heart_up {npcId, hearts}`,
  `mmr_npc_bark_seen {npcId}` (sampled at 5 %).

### 19.12 Acceptance Criteria

- **AC-19-01:** The rendered database contains ≥ 110 named NPCs (currently 115). Every canon `NPC_001`–`NPC_030` keeps its canon name, morph, role and location, and each NPC appears in exactly one district table.
- **AC-19-02:** Every NPC row lists ≥ 1 quest possibility, and every listed `QST_` ID resolves to a row in §20 (enforced by `render_npcs_quests.py --check`).
- **AC-19-03:** Pressing Talk within 10 studs opens the correct opening node in ≤ 200 ms server round-trip at p95. A request from > 12 studs is rejected server-side.
- **AC-19-04:** Only one interaction prompt is visible at a time, and it belongs to the nearest NPC within a 60° view cone. Prompts are hidden 100 % of the time while the player is In Combat.
- **AC-19-05:** Opening-line priority follows §19.3: with a ReadyToTurnIn quest the turn-in line is shown first in 100 % of tests, and random lines never repeat any of the last 3 shown.
- **AC-19-06:** A client-forged `NPC.Choose` for a branch whose conditions fail produces no effect and no reward, and is logged.
- **AC-19-07:** SERVICE NPCs are present and interactable at all four day phases, and every service screen opens from its NPC.
- **AC-19-08:** Hearts: the first daily chat grants exactly +5 once per UTC day per NPC. Gifting twice to the same NPC on one UTC day grants points once. The 5♥ reward (title + 1 Morph Capsule) is granted exactly once per NPC, even across reconnects.
- **AC-19-09:** With 8 players spread over 3 districts, the server holds ≤ 115 named-NPC proxies and ≤ 20 moving proxies per district, and server NPC movement costs ≤ 1.5 ms per frame (MicroProfiler p95).
- **AC-19-10:** A mid-tier phone client renders ≤ 25 named-NPC visuals (≤ 12 in low-end mode). Visuals beyond 60 studs use impostors, and those beyond 150 studs are destroyed.
- **AC-19-11:** Every visible NPC string resolves through a `LocalizationTable` key of the form `npc.<NPC_ID>.<node>.<nn>`. The pseudo-localization build (+30 % length) shows no clipped dialogue lines.
- **AC-19-12:** Quest markers use shape plus color (!, ?, ↻, ★, …) and remain distinguishable in the three color-blind simulation modes.
- **AC-19-13:** No NPC dialogue line contains real brands, real people, copyrighted characters, violence beyond cartoon slapstick, or mean-spirited humor (content review checklist signed off before Beta).
- **AC-19-14:** NPCs blocked by a player for more than 3 s poof to their next waypoint, and no NPC ever physically pushes or traps a player.
