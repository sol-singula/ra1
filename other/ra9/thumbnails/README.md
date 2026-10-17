# Turf Wars: store thumbnails

![The 6 thumbnails](_all.jpg)

For **the game's own page** (Home and the game's page). Each is **1920 × 1080 (16:9), JPG, under 0.4 MB**. The
text-free pictures for ads are in [`../ads/`](../ads/README.md); the icon is in [`../icon/`](../icon/README.md).

**The idea: say what the game is, in the game's look.** Plain white, SUPERHOT-style geometry, and only the two
team colours. Each carries the name (TURF in red, WARS in blue, heavy italic like the HUD) and
one short line on a black bar. The name sits in the empty sky at the top; Roblox's player count runs along the
bottom, so nothing important goes there.

They were made with AI image generation (Higgsfield, GPT Image 2.5, high, 2k) with **real renders of the game**
as references (`../screenshots/`: Castle Clash, the first-person view, the victory), then lettered with
`games/ra9 - Turf Wars/tools/gameplay/title_art.py`. The players in the game wear their own avatars dressed
in their team's colour; the pictures show them as plain red and blue figures.

| # | File | Line | Picture | In the game |
|---|---|---|---|---|
| 1 | `01_push_their_turf_back.jpg` | PUSH THEIR TURF BACK | Red and blue armies on their coloured turf, arrows crossing the line | The frontline, the turf, every kill pushing it |
| 2 | `02_build_then_fight.jpg` | BUILD, THEN FIGHT | Three blue players building a wall, a tower, a ramp and a banner | The build phase's 7 pieces |
| 3 | `03_pick_your_bow.jpg` | PICK YOUR BOW | Three archers: a longbow, a crossbow, a heavy bow | The Standard Bow, Rapid Crossbow and Heavy Bow |
| 4 | `04_flip_slide_shoot.jpg` | FLIP. SLIDE. SHOOT. | A red archer front-flipping over a wall and shooting; a blue one sliding under an arch | The 4th-jump flip, the slide |
| 5 | `05_red_vs_blue.jpg` | RED VS BLUE | The arena from above, split red and blue | Castle Clash's courtyard |
| 6 | `06_win_and_unlock.jpg` | WIN TO UNLOCK REWARDS | Red fireworks over the red team on a wall, the blue banner falling | The win: fireworks in the winners' colour, a reward per win |
