# Steal a Dragon: UI guidelines

What Roblox's own docs, the Roblox DevForum and game-UI articles recommend, and how this game follows it. The
code is in `games/ra2 - Steal a Dragon/src/client/` (mostly `UI/Theme.lua`, `Controllers/HudController.lua` and
`Controllers/PanelController.lua`).

## Recommendations and what we did

| Recommendation | Where it comes from | In the game |
|---|---|---|
| Keep status info small, in the top corners. Put actions at the bottom, where thumbs rest. Use the centre only for short alerts. | creation.dev; game HUD guides | Coins, income, egg and goal sit at the top. BONK and LOCK are bottom right, left of the jump button. Alerts appear in the middle for about 3 seconds, then go away. |
| Touch targets at least 44 × 44 pt. Make them bigger when unsure. | creation.dev | The smallest buttons are about 48 pt on a phone. Menu buttons are 70 design px (about 49 pt) and BONK is 112 (about 78 pt). |
| Respect safe areas (notches, rounded corners, Roblox's own buttons). | Roblox adaptive design; creation.dev | Every screen uses `ScreenInsets = CoreUISafeInsets`. |
| Adapt to every input: show prompts and labels for the input the player is using. | Roblox adaptive design (input fluidity) | Key hints on BONK and LOCK change as the player switches input: **Q / L** for keyboard, **R2 / Y** for gamepad, hidden on touch. L and gamepad Y lock the door. Gamepad X is left free because Roblox uses it for prompts. |
| Make UI navigable with a gamepad. | Roblox adaptive design; GuiService docs | Every button is `Selectable`. Opening a panel with a gamepad selects its first button, and **B** closes it. |
| One menu at a time. Tabs for big menus. The close button always in the same spot. Close with back or Escape. | creation.dev; DevForum | One panel at a time, Boosts and Passes tabs, and a round ✕ always on the top-right corner. Gamepad B or Backspace closes it, and so does tapping outside the panel. |
| Respond to the player's Reduced Motion setting. | Roblox accessibility docs | Every tween snaps with Reduced Motion on. The coin counter jumps instead of counting, the RUN HOME banner stops pulsing and the camera doesn't shake. |
| Respond to the player's Background Transparency setting (multiply `BackgroundTransparency` by `PreferredTransparency`). | Roblox accessibility docs | See-through HUD backgrounds (goal bar, egg and waiting pills, toasts) follow the setting, live. |
| Respond to the player's Text Size setting. | Roblox accessibility docs | Fixed-size text grows with `PreferredTextSize` (Large ×1.15, Larger ×1.3, Largest ×1.5). Scaled text already fills its box. |
| Readable text: no thin or decorative fonts, enough contrast, no text over busy backgrounds without a backing. | Roblox adaptive design; creation.dev | Two chunky fonts (Luckiest Guy for headings, Fredoka for body text). White text has a thick black outline, and longer text always sits on a solid card or pill. Small text was raised to about 16 design px or more. |
| Don't rely on colour alone. | Roblox accessibility docs | Toasts have an icon (✅ ⛔ 💬) as well as a coloured edge. LOCK shows 🔓 or 🔒 and a countdown as well as orange or green. |
| Responsive buttons: about 0.1 s feedback, slight scale on hover and press. | creation.dev; DevForum; game-feel guides | Buttons grow to 1.05× under the mouse, squish to 0.92× while held and bounce back (Back easing). |
| Menu transitions of about 0.2–0.4 s, with Quad or Back easing. | creation.dev; game UI guides | The backdrop fades in over 0.2 s and the panel pops in over 0.25 s with a little overshoot. |
| Animate number changes (count up over about 0.5 s) instead of jumping. | creation.dev | The coin counter eases to the new total and the coin pill gives a little punch when coins go up. |
| Show a loading state on buttons, and stop double taps. | creation.dev (common mistakes) | Purchase buttons show "..." and ignore taps for 1.5 s while Roblox's prompt opens. |
| Screen shake: small, dampened, never sustained. | Game-feel guides | Getting bonked shakes the camera for at most 0.5 s, fading out. |
| Contextual UI: hide controls when they don't apply. | Roblox adaptive design (responsive layout); creation.dev (≤ 5 persistent elements) | The LOCK button only shows inside your own base, the only place it works. Banners (luck, legend, carry), the egg and the waiting pill only show when they have something to say. |
| Consistent style: one palette and two fonts, rounded corners, `UIStroke` and `UIGradient`. | DevForum | Everything comes from one `Theme.lua`: the same outlines, gloss and corner radius everywhere. |
| Test on many screens. | DevForum; Roblox adaptive design | Every screen is laid out on a 1000 × 560 canvas and scaled to fit. The client test runs on a phone-sized screen (844 × 390) and checks the rescale on 1920 × 1080. Test in Studio's Device Emulator too. |

## Not done (yet)

- **Sounds on taps and purchases:** popular games use them, but they need sound assets from the Creator Store. Add
  them once you've picked sounds (one `Sound` in `SoundService`, played from `Theme.button`).
- **Portrait layout:** the game locks phones to landscape, which most action games on Roblox do.

## Sources

- [Roblox Creator Hub: Adaptive design guidelines](https://create.roblox.com/docs/production/publishing/adaptive-design)
- [Roblox Creator Hub: Accessibility](https://create.roblox.com/docs/production/publishing/accessibility)
- [Roblox GuiService reference (gamepad selection)](https://create.roblox.com/docs/reference/engine/classes/GuiService)
- [DevForum: New gamepad UI selection APIs](https://devforum.roblox.com/t/new-gamepad-ui-selection-apis/1791278)
- [DevForum: UI Designing Tips](https://devforum.roblox.com/t/ui-designing-tips/2423307)
- [DevForum: UI Design Guide](https://devforum.roblox.com/t/ui-design-guide/2975811)
- [DevForum: Any tips for GUI design?](https://devforum.roblox.com/t/any-tips-for-gui-design/901162)
- [creation.dev: Roblox UI design best practices](https://www.creation.dev/blog/roblox-ui-design-best-practices)
- [Outlook Respawn: UI and UX in games — menus, HUDs and feedback](https://respawn.outlookindia.com/gaming/gaming-guides/ui-and-ux-in-games-building-menus-huds-and-feedback-systems)
- [Wayline: Game feel course](https://www.wayline.io/learn/game-feel)
