# Mutation Meadow: Creator Hub ids

All 29 store items in `src/shared/Config/Catalog.lua` and 5 of the 10 badges in `src/shared/Config/Badges.lua`
have their Creator Hub ids (below). The other 5 badges are still `0` (TODO: create on Mason's account, then paste
the id into the matching key). Nothing is created or published from here. A key with id 0 can't be prompted
(`not_created`), and a badge with id 0 is skipped with a warning.

That is **29 store items** (5 game passes, 2 developer products, 9 cosmetic products and 13 gift products) plus **10
badges**.

Names and prices below come straight from the config. Gift products cost the same as the item they gift, are
friends-only, and there is no gift for the Starter Bundle.

## Game passes (5)

| # | Config key | Name | Robux | Type | Id |
|---|---|---|---|---|---|
| 1 | `extraRow` | Extra Plot Row | 199 | Game pass | 2052953294 |
| 2 | `starterBundle` | Starter Bundle | 249 | Game pass | 2052647253 |
| 3 | `vip` | VIP Gardener | 249 | Game pass | 2053169320 |
| 4 | `gnome` | Auto-Harvest Gnome | 299 | Game pass | 2052035337 |
| 5 | `doubleCash` | 2x Sell Cash | 349 | Game pass | 2053025309 |

## Developer products (2)

| # | Config key | Name | Robux | Type | Id |
|---|---|---|---|---|---|
| 6 | `instantGrow` | Instant Grow | 19 | Developer product | 3721780958 |
| 7 | `growAll` | Grow All | 99 | Developer product | 3721780982 |

## Cosmetic products (9)

| # | Config key | Name | Robux | Type | Id |
|---|---|---|---|---|---|
| 8 | `tag_sprout` | Sprout Buddy | 49 | Developer product | 3721780987 |
| 9 | `can_pumpkin` | Pumpkin Watering Can | 79 | Developer product | 3721780992 |
| 10 | `trail_leaf` | Leaf Swirl | 79 | Developer product | 3721781001 |
| 11 | `can_crystal` | Crystal Watering Can | 99 | Developer product | 3721781023 |
| 12 | `tag_star` | Star Farmer | 99 | Developer product | 3721781032 |
| 13 | `trail_firefly` | Firefly Trail | 129 | Developer product | 3721781036 |
| 14 | `theme_candy` | Candy Land Plot | 149 | Developer product | 3721781043 |
| 15 | `theme_cherry` | Cherry Blossom Plot | 149 | Developer product | 3721781049 |
| 16 | `theme_starry` | Starry Night Plot | 199 | Developer product | 3721781052 |

## Gift products (13)

| # | Config key | Name | Robux | Type | Id |
|---|---|---|---|---|---|
| 17 | `gift_tag_sprout` | 🎁 Gift Sprout Buddy | 49 | Developer product | 3721781069 |
| 18 | `gift_can_pumpkin` | 🎁 Gift Pumpkin Watering Can | 79 | Developer product | 3721781074 |
| 19 | `gift_trail_leaf` | 🎁 Gift Leaf Swirl | 79 | Developer product | 3721781076 |
| 20 | `gift_can_crystal` | 🎁 Gift Crystal Watering Can | 99 | Developer product | 3721781079 |
| 21 | `gift_tag_star` | 🎁 Gift Star Farmer | 99 | Developer product | 3721781084 |
| 22 | `gift_trail_firefly` | 🎁 Gift Firefly Trail | 129 | Developer product | 3721781088 |
| 23 | `gift_theme_candy` | 🎁 Gift Candy Land Plot | 149 | Developer product | 3721781093 |
| 24 | `gift_theme_cherry` | 🎁 Gift Cherry Blossom Plot | 149 | Developer product | 3721781118 |
| 25 | `gift_extraRow` | 🎁 Gift Extra Plot Row | 199 | Developer product | 3721781120 |
| 26 | `gift_theme_starry` | 🎁 Gift Starry Night Plot | 199 | Developer product | 3721781130 |
| 27 | `gift_vip` | 🎁 Gift VIP Gardener | 249 | Developer product | 3721781136 |
| 28 | `gift_gnome` | 🎁 Gift Auto-Harvest Gnome | 299 | Developer product | 3721781138 |
| 29 | `gift_doubleCash` | 🎁 Gift 2x Sell Cash | 349 | Developer product | 3721781145 |

## Badges (10)

| Config key | Name | Description | Id |
|---|---|---|---|
| `first_golden` | Struck Gold! | Keep your first Golden crop, worth 20x. | 3926931535334792 |
| `first_harvest` | First Harvest |  | 1687679896087609 |
| `first_splash` | First Splash |  | 2349293162665604 |
| `first_wetgolden` | 40x Legend | Keep a Wet + Golden crop, worth 40x. | 1521292345391916 |
| `full_meadow` | Full Meadow | Upgrade your meadow plot to level 5. | 0 (to create) |
| `master_gardener` | Master Gardener |  | 0 (to create) |
| `moonstruck` | Moonstruck |  | 0 (to create) |
| `sunflower_friend` | Sunflower Friend | Help the Block Party sunflower bloom 10 times. | 0 (to create) |
| `week_of_sprouts` | 7-Day Gardener | Claim 7 days on the daily calendar. | 0 (to create) |
| `welcome` | Welcome to the Meadow |  | 2620034105736556 |

## Also in Creator Hub

- Private servers: 99 R$ a month (`Config.Catalog.privateServerRobux`).
- The VIP pieces (`tag_vip`, `border_vip`, `trail_vip_sparkle`) and the subscriber can (`can_brass`) are brushed brass
  (`Cosmetics.BRASS`, RGB 168, 150, 112). Keep their icons and thumbnails brass too, never gold.
- No paid key or name may contain golden, rainbow or moon (`tests/Policy.spec.luau` checks this).
