# Mutation Meadow: reading the analytics

Everything goes through `src/server/Services/TelemetryService.lua`, the only module that calls AnalyticsService.
Other services log to `Telemetry.log(player, name, data)`, and TelemetryService turns each entry into Roblox
Analytics events (Creator Hub > your experience > Analytics).

## The ad split: three custom fields on every event

Every funnel, economy and custom event carries the same three fields, so any chart can be broken down by them.

| Field | Values | Meaning |
|---|---|---|
| `CustomField01` | `ad` / `organic` | How the player first arrived. Set once, on the first join, from the ad's LaunchData `{"src":"ad","c":"<campaign>"}`, and never changed |
| `CustomField02` | campaign or `none` | The ad campaign (letters, digits, `_` and `-`, at most 32 characters) |
| `CustomField03` | `payer` / `nonpayer` | Payer means a recorded Robux receipt or any game pass owned |

For the $200 ad test, put this in each ad's launch data: `{"src":"ad","c":"spring_test"}` (use your own campaign
name). Anything malformed, longer than 200 characters, or with a campaign containing spaces or other symbols
counts as `organic`.

Analytics allows only 3 custom fields, and all three hold the split. Other details are carried like this:

- **Low-cardinality details** are added to the event name: `weather_start:rain`, `mutation_found:wetgolden`,
  `shop_open:prompt`, `purchase:vip`.
- **One number** goes in the event's value: coins for `item_sold`, Robux for `purchase`, the day for
  `daily_claim`, seconds for `session_end`.
- **Everything else** goes to the server log, as lines starting with `[Telemetry]`.

## The three numbers for the ad test

Break each one down by `CustomField01` to compare `ad` with `organic`.

**D1 retention** (by UTC day). `d1_return` fires once, when a player joins on the UTC day after their first join.
- D1 = unique users with `d1_return` on day N+1 ÷ new users on day N.
- New users on day N are the unique users with funnel step 1 (`join`) that day. The onboarding funnel only counts
  the first session, so step 1 is exactly the new players.
- Roblox's own Retention chart gives the overall number. Use the custom-event version above when you need the
  ad / organic split.

**Average session length.** `session_end` fires when a player leaves, with the session's seconds as its value.
- Average session = the mean `session_end` value per user.
- The target is 15 minutes (900).

**Payer conversion.** `first_purchase` fires once per player, on the first Robux purchase (`purchase:<key>`, with
the Robux as its value).
- Payer conversion = unique users with `first_purchase` ÷ DAU.
- For DAU per split, use the unique users with `session_end` that day.

## Targets (Target metrics)

| Metric | Ad-test bar | Stretch / target |
|---|---|---|
| D1 retention | 15% | 22% stretch |
| D7 retention | | 7% |
| Payer conversion | | 2.5% |
| Average session | | 15 min |

The ad test passes when `ad` D1 reaches 15%. 22% is the stretch.

**Starter Bundle review line: 39%** (from the Monetization revenue check). Sum the Robux values of
`purchase:starterBundle` over all `purchase:*` Robux. When the bundle's share crosses 39%, review its price and
contents.

## The onboarding funnel (first session only, once per step)

| Step | Name | When |
|---|---|---|
| 1 | join | the first join |
| 2 | plant | the first crop planted |
| 3 | harvest | the first harvest |
| 4 | sell | the first coins from selling |
| 5 | shop_open | Patch's shop opened |
| 6 | plot_level_2 | plot level 2 |
| 7 | welcome_shower | the Welcome Shower at 4:00 |
| 8 | first_item_kept | the first mutated crop kept |
| 9 | first_pedestal | the first item on a pedestal |
| 10 | ten_minutes | ten minutes played |

## Economy (currency "Coins", with the ending balance)

| Kind | Reasons (the item SKU) | Transaction type |
|---|---|---|
| Sources | `sell_normal`, `sell_item`, `collection`, `daily`, `quest`, `playtime`, `help`, `blockparty`, `weekly` | Gameplay (Onboarding for the starter quests' rewards) |
| Sinks | `seed`, `can`, `sprinkler` | Shop |
| Sinks | `upgrade` (plot levels) | Gameplay |

## Custom events

- **§10:** `mutation_found`, `item_kept`, `item_sold`, `item_displayed`, `item_gifted`, `gift_declined`,
  `collection_claim`, `milestone_claim`, `backpack_full`, `basket_full`, `blockparty_water`, `blockparty_bloom`,
  `blockparty_reward`, `weather_start`, `daily_claim`, `quest_complete`, `playtime_claim`, `weekly_gift_claim`,
  `shop_open`, `lounge_enter`, `purchase`, `patch_line_shown`, `patch_line_dismissed`.
- **Engine additions:** `session_end`, `d1_return`, `first_purchase`, and `net_drop:<reason>` (dropped requests
  per reason, logged on leave).
