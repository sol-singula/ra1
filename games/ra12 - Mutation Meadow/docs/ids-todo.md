# Mutation Meadow: ids to create

Every Catalog `id` in `src/shared/Config/Catalog.lua` and every badge `id` in `src/shared/Config/Badges.lua` is still
`0 -- TODO: create on Mason's account`. Nothing is created or published from here. Create each item on Mason's
account in Creator Hub, then paste its id into the matching config key. A key with id 0 can't be prompted
(`not_created`), and a badge with id 0 is skipped with a warning.

That is **29 store items** (5 game passes, 2 developer products, 9 cosmetic products and 13 gift products) plus **10
badges**.

Names and prices below come straight from the config. Gift products cost the same as the item they gift, are
friends-only, and there is no gift for the Starter Bundle.

## Game passes (5)

| # | Config key | Name | Robux | Type |
|---|---|---|---|---|
| 1 | `extraRow` | Extra Plot Row | 199 | Game pass |
| 2 | `starterBundle` | Starter Bundle | 249 | Game pass |
| 3 | `vip` | VIP Gardener | 249 | Game pass |
| 4 | `gnome` | Auto-Harvest Gnome | 299 | Game pass |
| 5 | `doubleCash` | 2x Sell Cash | 349 | Game pass |

## Developer products (2)

| # | Config key | Name | Robux | Type |
|---|---|---|---|---|
| 6 | `instantGrow` | Instant Grow | 19 | Developer product |
| 7 | `growAll` | Grow All | 99 | Developer product |

## Cosmetic products (9)

| # | Config key | Name | Robux | Type |
|---|---|---|---|---|
| 8 | `tag_sprout` | Sprout Buddy | 49 | Developer product |
| 9 | `can_pumpkin` | Pumpkin Watering Can | 79 | Developer product |
| 10 | `trail_leaf` | Leaf Swirl | 79 | Developer product |
| 11 | `can_crystal` | Crystal Watering Can | 99 | Developer product |
| 12 | `tag_star` | Star Farmer | 99 | Developer product |
| 13 | `trail_firefly` | Firefly Trail | 129 | Developer product |
| 14 | `theme_candy` | Candy Land Plot | 149 | Developer product |
| 15 | `theme_cherry` | Cherry Blossom Plot | 149 | Developer product |
| 16 | `theme_starry` | Starry Night Plot | 199 | Developer product |

## Gift products (13)

| # | Config key | Name | Robux | Type |
|---|---|---|---|---|
| 17 | `gift_tag_sprout` | 🎁 Gift Sprout Buddy | 49 | Developer product |
| 18 | `gift_can_pumpkin` | 🎁 Gift Pumpkin Watering Can | 79 | Developer product |
| 19 | `gift_trail_leaf` | 🎁 Gift Leaf Swirl | 79 | Developer product |
| 20 | `gift_can_crystal` | 🎁 Gift Crystal Watering Can | 99 | Developer product |
| 21 | `gift_tag_star` | 🎁 Gift Star Farmer | 99 | Developer product |
| 22 | `gift_trail_firefly` | 🎁 Gift Firefly Trail | 129 | Developer product |
| 23 | `gift_theme_candy` | 🎁 Gift Candy Land Plot | 149 | Developer product |
| 24 | `gift_theme_cherry` | 🎁 Gift Cherry Blossom Plot | 149 | Developer product |
| 25 | `gift_extraRow` | 🎁 Gift Extra Plot Row | 199 | Developer product |
| 26 | `gift_theme_starry` | 🎁 Gift Starry Night Plot | 199 | Developer product |
| 27 | `gift_vip` | 🎁 Gift VIP Gardener | 249 | Developer product |
| 28 | `gift_gnome` | 🎁 Gift Auto-Harvest Gnome | 299 | Developer product |
| 29 | `gift_doubleCash` | 🎁 Gift 2x Sell Cash | 349 | Developer product |

## Badges (10)

| Config key | Name | Description |
|---|---|---|
| `first_golden` | Struck Gold! | Keep your first Golden crop, worth 20x. |
| `first_harvest` | First Harvest |  |
| `first_splash` | First Splash |  |
| `first_wetgolden` | 40x Legend | Keep a Wet + Golden crop, worth 40x. |
| `full_meadow` | Full Meadow | Upgrade your meadow plot to level 5. |
| `master_gardener` | Master Gardener |  |
| `moonstruck` | Moonstruck |  |
| `sunflower_friend` | Sunflower Friend | Help the Block Party sunflower bloom 10 times. |
| `week_of_sprouts` | 7-Day Gardener | Claim 7 days on the daily calendar. |
| `welcome` | Welcome to the Meadow |  |

## Also in Creator Hub

- Private servers: 99 R$ a month (`Config.Catalog.privateServerRobux`).
- The VIP pieces (`tag_vip`, `border_vip`, `trail_vip_sparkle`) and the subscriber can (`can_brass`) are brushed brass
  (`Cosmetics.BRASS`, RGB 168, 150, 112). Keep their icons and thumbnails brass too, never gold.
- No paid key or name may contain golden, rainbow or moon (`tests/Policy.spec.luau` checks this).
