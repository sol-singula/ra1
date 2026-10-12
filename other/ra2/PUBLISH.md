# Steal a Dragon: publish checklist

Do these in order. Paths are relative to `games/ra2 - Steal a Dragon/`.

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
| `AUTO` | Auto Collect | 149 | Coins go right to you. |
| `LONGLOCK` | Long Lock | 199 | Your door locks for 2 minutes. |
| `MEGABONK` | Mega Bonk | 149 | Bonked thieves are stuck longer. |

### Developer products (can be bought again and again)

Creator Dashboard → Steal a Dragon → **Monetization → Developer Products → Create a Developer Product**. Enter
the name, description and price and save. An icon is optional. Copy the **Product ID**.

| Key in Shop.lua | Name | Price (Robux) | Where players buy it |
|---|---|---|---|
| `LUCK` | Server Luck | 99 | Shop |
| `LOCKNOW` | Lock Now | 19 | Shop |
| `COINS_S` | Coin Bag | 49 | Shop |
| `COINS_L` | Coin Chest | 299 | Shop |
| `DEAL` | Daily Deal | 25 | Shop |
| `GROW` | Grow Now | 39 | Tapping **Grow Now** on one of your dragons |
| `HATCH` | Hatch Now | 49 | Tapping the egg |
| `BUYNOW` | Buy Now | 199 | **Buy with Robux** on Epic and rarer road dragons |
| `OFFLINE2X` | Double It | 25 | The welcome-back screen |

Names, prices and descriptions above match `src/shared/Data/Shop.lua`. If you change a price on the dashboard,
change it in that file too, because the shop shows the price from the file.

### Paste the IDs

Open `src/shared/Data/Shop.lua` and replace each `id = 0` with the item's ID, for example `id = 1234567890`.

You can also send me the 16 IDs and I'll paste them in, re-test and push.

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
   - **Icon:** 512 × 512.
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
