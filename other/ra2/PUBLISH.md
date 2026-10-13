# Steal a Dragon: publish checklist

Do these in order. Paths are relative to `games/ra2 - Steal a Dragon/`.

## This experience

- **Universe ID:** 10770473232
- **Place ID:** 118904155814967
- **Shop items:** all 23 created and on sale; hotbar icons and sound effects are uploaded too (IDs in `Constants.lua`); their IDs are in `src/shared/Data/Shop.lua`.
- **Publish a new build** (needs `ROBLOX_API_KEY` with universe-places write access), from the game folder:

  ```bash
  rojo build default.project.json -o StealADragon.rbxl
  curl -X POST -H "x-api-key: $ROBLOX_API_KEY" -H "Content-Type: application/octet-stream" \
    --data-binary @StealADragon.rbxl \
    "https://apis.roblox.com/universes/v1/10770473232/places/118904155814967/versions?versionType=Published"
  ```

## 1. Publish a private first version

Passes and products belong to a published experience, so publish once before creating them.

1. In Studio, open `StealADragon.rbxl`. Or open a Baseplate, run `rojo serve` and click **Rojo → Connect**.
2. **File → Publish to Roblox As… → Create new experience.** Name: **Steal a Dragon**.
3. **Game Settings:**
   - **Places:** set **Max Players** to **8**. There are 8 bases, and a 9th player would have none.
   - **Security:** turn on **Enable Studio Access to API Services**. Only Studio needs this; the live game saves
     either way.
   - **Permissions:** leave **Private** for now.
   - **Avatar:** R15.
4. Check **Lighting → Technology** is **Future**. The place file sets it, but if you synced into an older
   Baseplate, set it by hand.
5. Press **Play** once and check the Output window shows no red errors.

## 2. Set up the paid items

While an item's ID is `0`, Studio gives it free for testing and the live game shows "Coming soon". Each item
needs a real ID before it can earn.

### The quick way: let the script make them all

`tools/setup_shop.py` creates every pass and product below through Roblox's Open Cloud API, uploads the pass icons
from `other/ra2/icon/passes/`, and writes each new ID into `Shop.lua`. It needs two environment variables:

- `ROBLOX_UNIVERSE_ID`: on the Creator Dashboard, open the experience's **⋯** menu → **Copy Universe ID**.
- `ROBLOX_API_KEY`: on the Creator Dashboard, go to **Open Cloud → API Keys → Create API Key**. Add **game-pass**
  and **developer-product** (read and write) for this experience, and give it a short expiry. Never paste a key into
  a chat; store it as an environment variable or secret.

Run `python3 tools/setup_shop.py --dry-run` first, then `python3 tools/setup_shop.py`. Running it again won't create
duplicates. Or create them by hand as below.

### Game passes (bought once, kept forever)

Creator Dashboard → **Creations** → Steal a Dragon → **Monetization → Passes → Create a Pass**. Upload a square
image, enter the name and description, then **Create Pass**. Open the pass, go to **Sales**, turn on **Item
for Sale**, set the price and save. Copy its ID from the **⋯** menu (**Copy Asset ID**).

| Key in Shop.lua | Name | Price (Robux) | Description |
|---|---|---|---|
| `DOUBLE` | 2x Coins | 129 | All your dragons make 2x coins! |
| `VIP` | VIP | 449 | +50% coins, longer lock, gold name. |
| `FAST` | Fast Feet | 199 | Run 25% faster with a dragon. |
| `NESTS` | Extra Nests | 249 | +4 nests for more dragons. |
| `AUTO` | Auto Collect | 149 | Coins go right to you. (Also sold by the blue plate next to the coin pad.) |
| `LONGLOCK` | Long Lock | 199 | Your door locks for 2 minutes. |
| `MEGABONK` | Mega Bonk | 149 | Swap the bat for a big hammer: bonked thieves are stuck longer. |
| `WINGS` | Dragon Wings | 299 | Wings in your hotbar: jump high and glide over the map! |

### Developer products (can be bought again and again)

Creator Dashboard → Steal a Dragon → **Monetization → Developer Products → Create a Developer Product**. Enter
the name, description and price and save. An icon is optional. Copy the **Product ID**.

| Key in Shop.lua | Name | Price (Robux) | Where players buy it |
|---|---|---|---|
| `LUCK` | Server Luck | 99 | Shop |
| `LOCKNOW` | Lock Now | 19 | Shop |
| `LOCK30` | 30-Minute Lock | 49 | Shop, the **30 MIN** plate next to the lock pad, and the card after you get robbed |
| `STARTER` | Starter Pack | 49 | One-time card after 8 minutes of play: an Epic dragon, 5 potions, coins |
| `LEVELALL` | +5 Levels for ALL | 99 | Shop, and the **LEVEL ALL** plate when you have no coins |
| `POTIONS` | 5 Speed Potions | 29 | Shop, and using the Speed Potion with none left |
| `COINS_S` | Coin Bag | 49 | Shop |
| `COINS_L` | Coin Chest | 299 | Shop |
| `DEAL` | Daily Deal | 25 | Shop |
| `GROW` | +10 Levels | 39 | Tapping **+10 Levels** on one of your dragons |
| `HATCH` | Hatch Now | 49 | Tapping the egg |
| `BUYNOW` | Buy Now | 199 | **Buy with Robux** on Epic and rarer road dragons |
| `OFFLINE2X` | Double It | 25 | The welcome-back screen |
| `SKIN_LAVA` | Lava Skin | 99 | Shop → Skins |
| `SKIN_ROYAL` | Royal Gold Skin | 149 | Shop → Skins |
| `SKIN_NEON` | Neon Skin | 199 | Shop → Skins |

Names, prices and descriptions above match `src/shared/Data/Shop.lua`. If you change a price on the dashboard,
change it in that file too, because the shop shows the price from the file.

### Paste the IDs

Open `src/shared/Data/Shop.lua` and replace each `id = 0` with the item's ID, for example `id = 1234567890`.

You can also send me the IDs and I'll paste them in, re-test and push.

### Getting paid

- Robux from sales land in the experience owner's account. If the experience is in a group, they land in the
  group's funds.
- Sales stay "pending" for a few days before you can spend them.
- Turning Robux into real money is **DevEx**, which has its own eligibility rules. Check them on the Creator
  Dashboard.

## 3. Publish the real version

1. Pull the latest code (`git pull`). If you edited `Shop.lua` yourself, rebuild the place with
   `rojo build default.project.json -o StealADragon.rbxl`, or keep `rojo serve` connected.
2. **File → Publish to Roblox** to update the same experience.
3. Test a purchase in Studio. Studio purchase prompts are test purchases and don't charge you.
4. On the Creator Dashboard, fill in:
   - **Basic info:** description and genre (Adventure or Simulation).
   - **Icon:** `other/ra2/icon/icon_red_dragon.png` (512 × 512; an alternate is in the same folder).
   - **Thumbnails:** from `other/ra2/thumbnails/`.
   - **Devices:** Phone, Tablet, Computer and Console.
5. Fill in the **Maturity & Compliance** questionnaire. A game can't be made public without it.
6. **Permissions → Public.**

## 4. After launch

- **Invite rewards** (`INVITE_REWARDS` in `Constants.lua`) are on. Roblox's own invite docs describe using invite
  data to incentivize invites, so this is allowed. Re-check if Roblox changes its rules.
- Watch the Creator Dashboard's **Analytics** (day-1 retention, session length, paying users) for the first week
  before you change prices.
- For ads, read `other/ra2/thumbnails/README.md` first.
