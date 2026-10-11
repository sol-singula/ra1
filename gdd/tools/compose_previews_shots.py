"""Overlay definitions for preview shots 9-52 (helpers are injected from compose_previews.py)."""
from __future__ import annotations


def more_shots(g):  # noqa: C901 - one flat list of shot definitions is the clearest form here
    S, P, at, esc = g["S"], g["gameplay_hud"], g["at"], g["esc"]
    ticket, hold_bar, gauge, toast, comic = g["ticket"], g["hold_bar"], g["gauge"], g["toast"], g["comic"]
    panel, cell, grid, stat_rows, sat_popup = g["panel"], g["cell"], g["grid"], g["stat_rows"], g["sat_popup"]
    anger_meter, huff_bar, prompt_btn, minimap, ring = g["anger_meter"], g["huff_bar"], g["prompt_btn"], g["minimap"], g["ring"]
    hud_wallet, hud_player, hud_abilities, dialogue = g["hud_wallet"], g["hud_player"], g["hud_abilities"], g["dialogue"]
    hud_objective = g["hud_objective"]
    L = []

    def mid(player, wallet, **kw):
        return P(player=player, wallet=wallet, **kw)

    # ---------------------------------------------------------------- cooking stations
    L.append(S(9, "Cooking: The Fryer", "Basket timers and an overheat gauge; Lv5 'Ridiculous' fryers auto-salt.", "§5.3", lambda: (
        mid({"level": 8, "xp": .3, "face": "🐔"}, {"mb": "1,960", "ms": "28"},
            orders=[(2, "🍟🍔", .7, "var(--good)", "52"), (6, "🧅", .45, "var(--warn)", "34")], abilities=False)
        + gauge("🛢️ Oil temperature", 0.5, 60, 700)
        + hold_bar("🍟 Basket: French Fries", 0.86, 380, 800, 620, "var(--good)", "PERFECT in 0.8 s · lift now for a golden crunch")
        + prompt_btn("LIFT BASKET", "E", 1500, 880, "🧺"))))
    L.append(S(10, "Cooking: The Pizza Oven", "Dial LOW / MED / HIGH per recipe; spin at halfway for an even bake.", "§5.3, §6.4", lambda: (
        mid({"level": 16, "xp": .5, "face": "🐐"}, {"mb": "6,410", "ms": "64"},
            orders=[(3, "🍕", .74, "var(--good)", "66"), (7, "🍕🥤", .5, "var(--warn)", "45")], abilities=False)
        + at(60, 640, '''<div class="slate col" style="padding:16px 20px;width:330px;align-items:center">
          <div style="font-weight:700;font-size:20px">🔥 Oven dial</div><div class="row" style="gap:10px;margin:10px 0">
          <div class="chip">LOW</div><div class="chip" style="background:var(--mustard)">● MED</div><div class="chip">HIGH</div></div>
          <div style="font-size:18px;color:#cdd">Eyeball Pizza needs MED</div></div>''')
        + toast("Spin the pizza now for an even bake! <span class='key'>E</span>", "🔄", y=150)
        + ticket("Table 3 · Pirate Crab", [("🍕", "Eyeball Pizza", "×1")], mods=["Extra eyeballs (they're gummy!)"], timer=(.74, "var(--good)", "66 s left"), x=1480, y=170))))
    L.append(S(11, "Cooking: The Soup Pot", "One pot = four servings. Pots boil over (no fire) if left too long.", "§5.3", lambda: (
        mid({"level": 27, "xp": .2, "face": "🐘"}, {"mb": "21,880", "ms": "140"},
            orders=[(1, "🥣", .8, "var(--good)", "70"), (4, "🥣🥣", .6, "var(--warn)", "52"), (9, "🥣", .9, "var(--good)", "80")], abilities=False)
        + hold_bar("🥄 Simmer: Swamp Stew (4 servings)", 0.64, 60, 820, 600, "var(--good)", "Stir every 5 s · boil-over in 9 s if ignored")
        + ticket("3 tables want Swamp Stew", [("🥣", "Swamp Stew", "×4")], mods=["Extra lily pads", "No eyeballs (Table 9)"], x=1480, y=170))))
    L.append(S(12, "Cooking: The Blender", "Hold the lid! Past 100 % the smoothie turns MUSHY.", "§5.4", lambda: (
        mid({"level": 11, "xp": .6, "face": "🐵"}, {"mb": "3,740", "ms": "44"},
            orders=[(5, "🥤", .55, "var(--warn)", "40")], abilities=False)
        + hold_bar("🌀 Blending: Rainbow Slushie", 0.78, 640, 820, 640, "linear-gradient(90deg,#ff4b3e,#ffc531,#48d16b,#3a8dff,#a15cff)", "Release at 85–100 % · MUSHY above 100 %")
        + comic("WHIRRR!", 1430, 290, 90, 8, "#45E0E8"))))
    L.append(S(13, "Ridiculous Modification: 'Make my drink angry'", "MOD_076 — joke request with a real mechanic: Agitate ×5 at the drink dispenser.", "§6.18", lambda: (
        mid({"level": 13, "xp": .35, "face": "🐹"}, {"mb": "4,910", "ms": "51"},
            orders=[(8, "🥤", .62, "var(--warn)", "47")], abilities=False)
        + ticket("Table 8 · Spicy Salamander", [("🥤", "Angry Coffee", "×1")], mods=["\"Make my drink angry.\""], timer=(.62, "var(--warn)", "47 s left"), x=1480, y=170)
        + at(620, 830, '''<div class="slate" style="padding:14px 22px;width:680px"><div class="row" style="justify-content:space-between;font-weight:700;font-size:22px">
          <span>😠 AGITATE (shake it!)</span><span>4 / 5</span></div><div class="row" style="gap:12px;margin-top:10px">''' + "".join(
              f'<div style="flex:1;height:26px;border-radius:10px;border:3px solid #0d0f18;background:{"var(--danger)" if i < 4 else "#3a3d55"}"></div>' for i in range(5)) + '''</div>
          <div style="font-size:17px;color:#cdd;margin-top:8px">Pay bonus +15 % · joke mod: never adds anger if missed</div></div>''')
        + comic("GRRR!", 1180, 330, 100, 10, "#FF4B3E"))))
    L.append(S(14, "Cooking: Ice Cream Machine", "Swirl height scores the tower; too tall and it topples.", "§5.3", lambda: (
        mid({"level": 9, "xp": .7, "face": "🐧"}, {"mb": "2,630", "ms": "33"},
            orders=[(2, "🍨", .7, "var(--good)", "58")], abilities=False)
        + at(80, 380, '''<div class="slate col" style="padding:16px;width:150px;align-items:center;gap:8px"><div style="font-weight:700">🍦 Height</div>
          <div style="position:relative;width:46px;height:340px;border-radius:14px;background:#3a3d55;border:3px solid #0d0f18;overflow:hidden">
          <div style="position:absolute;bottom:0;left:0;right:0;height:78%;background:linear-gradient(0deg,#ffd1dc,#fff5e6)"></div>
          <div style="position:absolute;left:0;right:0;top:12%;height:16%;background:rgba(72,209,107,.55);border-top:3px dashed #fff;border-bottom:3px dashed #fff"></div></div>
          <div style="font-weight:700;color:var(--good)">TOWER ✓</div></div>''')
        + toast("Tower Bonus +10 % — don't let it lean!", "🍨", y=150))))
    L.append(S(15, "Serving & Satisfaction", "Satisfaction = accuracy, quality, cooking, wait, cleanliness and atmosphere (§10).", "§10", lambda: (
        mid({"level": 4, "xp": .8, "face": "🐻"}, {"mb": "742", "ms": "15"},
            orders=[(2, "🍜", .5, "var(--warn)", "38")], objective=("Happy Customer, Happy Wallet", "Serve a meal with satisfaction ≥ 70", 1.0))
        + sat_popup(1240, 250, "😍", "DELIGHTED!", 92, "+16", "+3"))))
    L.append(S(16, "Kitchen Hazard: Grill Fire!", "ON_FIRE 4 s after burning; extinguish, or Trunk Spray / Freeze Touch puts it out.", "§5.7", lambda: (
        mid({"level": 10, "xp": .1, "face": "🐹"}, {"mb": "3,120", "ms": "40"},
            orders=[(1, "🍔", .4, "var(--alert)", "30"), (3, "🍔🍟", .3, "var(--danger)", "22")], abilities=False,
            rest={"stars": 3.1, "clean": 71, "dmg": 1})
        + at(0, 190, '<div style="width:1920px;display:flex;justify-content:center"><div class="toast" style="background:var(--ketchup);color:#fff;font-size:34px"><span style="font-size:42px">🔥</span>GRILL ON FIRE! Grab the extinguisher <span class="key">F</span></div></div>')
        + hold_bar("🧯 Extinguishing…", 0.64, 640, 840, 640, "#ffffff", "Fire never spreads to customers · grill drops to Cracked if it burns 8 s"))))
    L.append(S(17, "Co-op Kitchen", "Friends cook in your restaurant; guests earn their own XP and MB paid by the game.", "§21", lambda: (
        mid({"level": 22, "xp": .4, "face": "🦈", "name": "You (Owner)"}, {"mb": "14,200", "ms": "96"},
            orders=[(1, "🍝", .6, "var(--warn)", "48"), (2, "🍕🍕", .8, "var(--good)", "70"), (5, "🍔", .7, "var(--good)", "62"), (6, "🍝🥤", .35, "var(--alert)", "28")], abilities=False)
        + at(28, 300, '''<div class="dark" style="padding:12px 16px;width:300px"><div style="font-weight:700;font-size:18px;color:var(--mustard)">👥 CO-OP · 3/4</div>
          <div style="font-size:19px;margin-top:6px">🦈 You · Owner</div><div style="font-size:19px">🐱 PixelPaws · Co-Chef</div><div style="font-size:19px">🤖 BoltNugget · Guest</div>
          <div class="chip" style="margin-top:8px;font-size:15px">Busy Kitchen bonus +10 % XP</div></div>''')
        + at(500, 330, '<div class="dark" style="padding:6px 14px;font-weight:700">🦈 You</div>') + at(900, 280, '<div class="dark" style="padding:6px 14px;font-weight:700">🐱 PixelPaws</div>')
        + at(1380, 300, '<div class="dark" style="padding:6px 14px;font-weight:700">🤖 BoltNugget</div>')
        + at(1150, 760, '<div class="toast" style="font-size:24px"><span style="font-size:30px">📍</span>PixelPaws pinged: "Plates needed!"</div>'))))
    L.append(S(18, "Late Game: Mutagen Infuser", "Mutation Cuisine: diners grow a random cosmetic part for 60 s (+10 'Whoa!').", "§5.3, §6.16", lambda: (
        mid({"level": 44, "xp": .55, "face": "🐲"}, {"mb": "182,400", "ms": "620", "rt": "38"},
            orders=[(4, "🧆", .7, "var(--good)", "90"), (11, "🧆🥤", .6, "var(--warn)", "74")], abilities=False,
            rest={"tier": "Monster Food Court", "stars": 4.4, "clean": 95, "dmg": 0})
        + gauge("🧪 Mutagen pressure", 0.47, 1560, 640, ("#3a8dff", "#48d16b", "#ff3ea5"))
        + hold_bar("🧬 INFUSE: Mutagen Meatballs", 0.55, 520, 840, 720, "#5BEA4B", "Keep the needle in the green · overload = ON_FIRE (infusers can burn!)")
        + toast("Mutagen Meatballs: customers mutate for 60 seconds!", "🧬", y=170))))
    L.append(S(19, "Late Game: Anti-Gravity Wok", "Alien Cuisine: keep the ingredients airborne with FLOAT taps.", "§5.3, §6.15", lambda: (
        mid({"level": 36, "xp": .3, "face": "👽"}, {"mb": "96,300", "ms": "410", "rt": "21"},
            orders=[(2, "🍜", .75, "var(--good)", "80")], abilities=False, rest={"tier": "Monster Food Court", "stars": 4.1, "clean": 93, "dmg": 0})
        + at(60, 720, '''<div class="slate" style="padding:14px 20px;width:520px"><div style="font-weight:700;font-size:22px">🛸 FLOAT: Zero-Gravity Noodles</div>
          <div class="row" style="gap:8px;margin-top:10px">''' + "".join(f'<div style="flex:1;height:30px;border-radius:50%;border:3px solid #0d0f18;background:{"#45E0E8" if i < 8 else "#3a3d55"}"></div>' for i in range(10)) + '''</div>
          <div style="font-size:17px;color:#cdd;margin-top:8px">8 / 10 ingredients airborne · tap when one dips below the ring</div></div>'''))))
    # ---------------------------------------------------------------- customers
    L.append(S(20, "Dining Room at Tier 5", "Mutant Family Restaurant: 12 seats, table service, employees run the floor.", "§8, §15", lambda: (
        mid({"level": 28, "xp": .65, "face": "🐺"}, {"mb": "24,560", "ms": "180"},
            orders=[(1, "🍔🍟", .8, "var(--good)", "72"), (2, "🍝", .66, "var(--good)", "60"), (4, "🍣🍣", .5, "var(--warn)", "44"), (6, "🥗", .9, "var(--good)", "81"), (9, "🍕", .3, "var(--alert)", "26")],
            rest={"tier": "Mutant Family Restaurant", "stars": 4.2, "clean": 94, "dmg": 0})
        + at(28, 300, '''<div class="dark" style="padding:12px 16px;width:330px"><div style="font-weight:700;color:var(--mustard)">👷 STAFF ON SHIFT</div>
          <div style="font-size:18px;margin-top:4px">🐙 Octavia · Chef · cooking</div><div style="font-size:18px">🐆 Chet · Waiter · delivering</div>
          <div style="font-size:18px">🤖 Barb · Cashier · idle</div><div style="font-size:18px">🦏 Rocco · Security · patrolling</div></div>'''))))
    L.append(S(21, "Ridiculous Modification: 'Exactly seventeen pickles'", "MOD_052 — a COUNT mod checked by the server on the Dish object.", "§6.18", lambda: (
        mid({"level": 14, "xp": .4, "face": "🐸"}, {"mb": "5,520", "ms": "58"},
            orders=[(3, "🍔", .45, "var(--warn)", "33")], abilities=False)
        + ticket("Table 3 · Picky Platypus", [("🍔", "Pickle Mountain Burger", "×1")], mods=["\"I want exactly seventeen pickles.\""], timer=(.45, "var(--warn)", "33 s left"), x=1480, y=170)
        + at(700, 860, '''<div class="slate row" style="padding:14px 22px;gap:18px;font-size:30px;font-weight:700">🥒 Pickles <span class="btn ghost" style="padding:0 16px">−</span>
          <span class="lucky" style="font-size:44px;color:var(--good)">17 / 17 ✓</span><span class="btn ghost" style="padding:0 16px">+</span></div>'''))))
    L.append(S(22, "The Food Critic", "Madame Fourchette scores five categories; a great review raises the star rating.", "§9 PER_004, §19", lambda: (
        mid({"level": 31, "xp": .2, "face": "🐱"}, {"mb": "38,900", "ms": "260"}, abilities=False,
            rest={"tier": "Mutant Family Restaurant", "stars": 4.5, "clean": 98, "dmg": 0})
        + at(1380, 300, '''<div class="paper" style="padding:18px 22px;width:480px;transform:rotate(-1.5deg)"><div class="lucky" style="font-size:30px;color:var(--e)">🧐 CRITIC SCORECARD</div>
          <div style="font-weight:600;font-size:19px;margin-bottom:8px">Madame Fourchette · Lobster-ish Roll</div>''' + "".join(
              f'<div class="row" style="justify-content:space-between;font-size:22px;font-weight:600;padding:3px 0"><span>{n}</span><span style="color:var(--l)">{"★"*v}{"☆"*(5-v)}</span></div>' for n, v in
              [("Taste", 5), ("Temperature", 4), ("Presentation", 5), ("Speed", 4), ("Atmosphere", 5)]) + '''
          <div class="chip" style="margin-top:10px;background:#E6FFF4">✨ Review published: +0.2 ★</div></div>'''))))
    L.append(S(23, "The Influencer", "Vlogzilla's posts swing reputation ±0.1 ★ and bring follower customers.", "§9 PER_009", lambda: (
        mid({"level": 19, "xp": .5, "face": "🐶"}, {"mb": "9,870", "ms": "82"}, abilities=False,
            rest={"tier": "Morph City Grill", "stars": 3.9, "clean": 90, "dmg": 0})
        + toast("Vlogzilla posted your Rainbow Burger!  <b style='color:#1e9e46'>+0.1 ★</b> · 3 followers on the way", "📱", y=170)
        + at(1500, 300, '<div class="dark" style="padding:8px 16px;font-weight:700;font-size:22px">🔴 LIVE · 12.4k 👀</div>'))))
    L.append(S(24, "Party Pack Order", "PER_016: one party, three tiny orders, one very sticky table.", "§9", lambda: (
        mid({"level": 12, "xp": .3, "face": "🐱"}, {"mb": "4,180", "ms": "47"},
            orders=[(5, "🍔🍟🥤", .7, "var(--good)", "88")], abilities=False)
        + at(1440, 170, '''<div class="paper" style="padding:16px 18px;width:430px"><div class="lucky" style="font-size:26px;color:var(--ketchup)">🎉 PARTY ORDER · T5</div>''' + "".join(
            f'<div class="row" style="gap:10px;font-size:21px;font-weight:600;padding:4px 0;border-bottom:2px dashed #e8dcbf"><span style="font-size:28px">{f}</span>{n}<span style="margin-left:auto">{o}</span></div>' for f, n, o in
            [("🐝", "Mini Bee", "🍔 🥤"), ("🐸", "Mini Frog", "🍟 🍟 🍟"), ("🦖", "Mini Dino", "🎂 🥤")]) + '''<div class="chip" style="margin-top:10px;background:#FFE9A8">Party patience is shared · serve all 3 for a group tip</div></div>'''))))
    L.append(S(25, "The Mime Mantis", "PER_019 orders in pictograms only; Super Sniff (ABL_064) reveals hidden mods.", "§9", lambda: (
        mid({"level": 17, "xp": .45, "face": "🐶"}, {"mb": "7,390", "ms": "70"}, abilities=False)
        + at(1450, 180, '''<div class="paper col" style="padding:16px 20px;width:410px;align-items:center"><div class="lucky" style="font-size:26px;color:var(--teal)">🤐 PICTOGRAM ORDER</div>
          <div style="font-size:64px;margin:8px 0">🍔 ➕ 🧂🧂</div><div style="font-size:64px">🚫 🧅 ❓</div>
          <div style="font-size:18px;font-weight:600;margin-top:8px;text-align:center">"…" (mimes salt-shaking furiously)</div>
          <div class="chip" style="margin-top:10px;background:#E6F2FF">👃 Super Sniff reveals: <b>extra salt, no onion</b></div></div>'''))))
    # ---------------------------------------------------------------- chaos & combat
    L.append(S(26, "WRONG ORDER?! — A Tantrum Begins", "Anger climbs 0→6; each escalation past level 2 is a personality roll (§10).", "§10", lambda: (
        mid({"level": 2, "xp": .5, "face": "🐺"}, {"mb": "212", "ms": "5"},
            objective=("Uh-Oh, Karenosaurus", "Block the flying food! Hold Q", 0.3))
        + anger_meter(3, 1440, 170, "Karenosaurus") + comic("WRONG ORDER?!", 500, 150, 96, 4))))
    L.append(S(27, "Restaurant-Wide Chaos (Level 6)", "Three angry customers ignite chaos: 45 s max, then a 3-minute cooldown.", "§10", lambda: (
        mid({"level": 24, "xp": .2, "face": "🐻"}, {"mb": "17,330", "ms": "120"},
            rest={"tier": "Mutant Family Restaurant", "stars": 3.8, "clean": 52, "dmg": 5})
        + at(0, 170, '''<div style="width:1920px;display:flex;justify-content:center"><div class="slate col" style="padding:12px 26px;width:760px;align-items:center;border-color:#B00020">
          <div class="lucky" style="font-size:44px;color:#FF4B3E">⚠️ RESTAURANT-WIDE CHAOS!</div><div class="bar" style="width:100%;height:24px;margin-top:6px"><i style="width:64%;background:linear-gradient(90deg,#ff8a1f,#b00020)"></i></div>
          <div class="row" style="justify-content:space-between;width:100%;font-weight:700;font-size:20px;margin-top:6px"><span>⏱️ 29 s left</span><span>Calm the 3 ringleaders 👑 1/3</span><span>🪑 5 broken</span></div></div></div>'''))))
    L.append(S(28, "Combat: Mutation Abilities", "Scorpion Tail Swipe (ABL_009) stuns; damage = base × STR × 100/(100+DEF).", "§11, §36.6", lambda: (
        hud_player(level=21, xp=.7, hp=118, hpmax=148, face="🐻", name="Chef Grizzle") + hud_wallet("13,060", "88")
        + hud_abilities([("🦂", "1", 0), ("🦀", "2", .3), ("🦈", "3", 0), ("🛡️", "4", .8)])
        + huff_bar(1180, 180, "Shark-Spider", 0.42, 340, 5)
        + at(1250, 250, '<div class="chip" style="background:#FFE9A8">💫 STUNNED 1.2 s</div>')
        + at(1000, 430, '<div class="float" style="font-size:64px;color:#fff">BONK! 31</div>'))))
    L.append(S(29, "Emergent Chaos: The Chain Reaction", "A thrown burger misses you, hits a bystander, and starts a whole new fight.", "§11.6", lambda: (
        mid({"level": 15, "xp": .3, "face": "🐺"}, {"mb": "6,020", "ms": "60"})
        + at(520, 260, '<svg width="900" height="400"><path d="M20 360 Q 450 -120 880 300" stroke="#fff" stroke-width="8" fill="none" stroke-dasharray="18 16"/></svg>')
        + at(760, 640, '<div class="row" style="gap:12px"><span class="key" style="width:60px;height:60px;font-size:28px">⇧</span><div class="lucky so" style="font-size:54px">DODGE!</div></div>')
        + at(1380, 400, '<div class="float" style="font-size:40px;color:#FF8A1F">+25 ANGER 😡</div>'))))
    L.append(S(30, "Security Guard at Work", "EMP_066 Rocco the Rhino intercepts angry customers (40 % Apology Payment).", "§16, §36.8", lambda: (
        mid({"level": 33, "xp": .6, "face": "🐺"}, {"mb": "52,100", "ms": "300"},
            rest={"tier": "Monster Food Court", "stars": 4.3, "clean": 91, "dmg": 1})
        + toast("Rocco stopped a tantrum with one very stern eyebrow.  <b>+40 % Apology Payment</b>", "🦏", y=170))))
    L.append(S(31, "Seeing Stars (Knocked Out)", "KO never costs mutations, items or currency: respawn in the kitchen with 60 % HP.", "§11.10", lambda: (
        at(0, 300, '<div style="width:1920px;text-align:center"><div class="lucky" style="font-size:150px;color:#FFC531;-webkit-text-stroke:8px var(--ink);paint-order:stroke fill;text-shadow:0 10px 0 rgba(0,0,0,.4)">⭐ SEEING STARS! ⭐</div></div>')
        + at(0, 520, '<div style="width:1920px;display:flex;justify-content:center"><div class="slate" style="padding:14px 30px;font-size:30px;font-weight:700">Back on your feet in <span style="color:var(--mustard)">3</span>… · Woozy −15 % speed for 10 s</div></div>')
        + at(0, 610, '<div style="width:1920px;display:flex;justify-content:center"><div class="chip" style="font-size:22px">✅ Nothing lost — no mutations, no items, no Morph Bucks</div></div>')), blur=True))
    L.append(S(32, "Repair Minigame", "Damage states Pristine → Destroyed; Destroyed items rebuild for ≤ 25 % of price.", "§15.9", lambda: (
        mid({"level": 3, "xp": .9, "face": "🐺"}, {"mb": "318", "ms": "8"},
            objective=("Fix It Up", "Repair the table the Karenosaurus flipped", 0.6), rest={"stars": 2.7, "clean": 60, "dmg": 1})
        + hold_bar("🔨 Repairing: Wobbly Diner Table", 0.6, 640, 820, 640, "var(--teal)", "Cracked → Pristine · cost 18 MB · Wrench Claw Repair Burst makes it instant"))))
    # ---------------------------------------------------------------- morph & progression
    def morph_ui():
        cats = "".join(f'<div class="{"btn" if i == 5 else "btn ghost"}" style="width:220px;justify-content:flex-start;font-size:22px">{c}</div>' for i, c in enumerate(
            ["🙂 Head", "👂 Ears", "👀 Eyes", "💪 Arms", "🦵 Legs", "🦂 Tails", "✨ Extras"]))
        inv = [("🦂", "R", "Scorpion Tail", 3, True), ("🦊", "U", "Fox Tail", 2, False), ("🐉", "E", "Dragon Tail", 1, False), ("🐟", "C", "Fish Tail", 1, False),
               ("☄️", "E", "Comet Tail", 1, False), ("🦚", "R", "Peacock Tail", 1, False), ("🐒", "U", "Monkey Tail", 2, False), ("🦨", "R", "Skunk Tail", 1, False),
               ("🦦", "U", "Beaver Tail", 1, False), ("🐍", "U", "Rattlesnake", 1, False), ("🦊", "L", "Nine Fox Tails", 0, False), ("⚡", "E", "Lightning Tail", 0, False)]
        cells = [cell(e, r, n, l if l else None, s, 104, l == 0) for e, r, n, l, s in inv]
        return (at(70, 60, '<div class="lucky so" style="font-size:60px">🧬 CUSTOMIZE YOUR MORPH</div>')
                + at(70, 170, f'<div class="col" style="gap:14px">{cats}</div>')
                + at(1270, 160, f'<div class="paper" style="padding:22px 22px 40px;width:600px">{grid(cells, 4, 24)}</div>')
                + at(1270, 820, '''<div class="paper" style="padding:14px 20px;width:600px"><div style="font-weight:700;font-size:22px">■ Scorpion Tail · Rare · Lv 3</div>
                  <div style="font-size:18px">STR +7 · REPAIR +2 · EFFICIENCY +2 · Active: Scorpion Tail Swipe (stun)</div>
                  <div class="row" style="gap:10px;margin-top:8px"><div class="btn" style="font-size:20px;padding:6px 16px">EQUIP</div><div class="btn teal" style="font-size:20px;padding:6px 16px">⬆ Upgrade 2,025 MB + 24 MS</div></div></div>''')
                + at(330, 900, '''<div class="row" style="gap:12px"><div class="btn" style="font-size:20px">👨‍🍳 Chef</div><div class="btn ghost" style="font-size:20px">🥊 Fighter</div>
                  <div class="btn ghost" style="font-size:20px">🛠️ Repair</div><div class="btn ghost" style="font-size:20px">🔒 Slot 4</div></div>''')
                + at(390, 830, '<div class="dark" style="padding:6px 16px;font-weight:700;font-size:22px">"Sir Pinchy McStingface" ✏️ · Scorpion Bear</div>'))
    L.append(S(33, "Customize Your Morph", "22 anatomy slots, rarity by color and shape, three free loadouts (Chef, Fighter, Repair).", "§13", morph_ui))
    L.append(S(34, "Level Up & Get Stronger", "2 stat points per level; the mockup's four headline stats with a 'More Stats' view.", "§14", lambda: (
        at(0, 40, '<div style="width:1920px;text-align:center"><span class="lucky" style="font-size:120px;color:#FFC531;-webkit-text-stroke:8px var(--ink);paint-order:stroke fill;text-shadow:0 10px 0 rgba(0,0,0,.4)">LEVEL UP!</span></div>')
        + at(120, 250, '''<div class="slate" style="padding:24px 28px;width:640px"><div class="lucky" style="font-size:46px;color:#5BEA4B">LEVEL 12</div>
          <div class="bar" style="height:22px;margin:8px 0 18px"><i style="width:8%;background:var(--good)"></i></div>''' + "".join(
              f'''<div class="row" style="gap:16px;padding:10px 0;border-bottom:2px solid #3a3d55"><span style="font-size:40px">{e}</span><div class="col" style="flex:1">
              <span style="font-weight:700;font-size:28px">{n}</span><span style="color:#aab;font-size:18px">{d}</span></div><span style="font-weight:700;font-size:26px">{v}</span>
              <div class="btn" style="width:56px;height:56px;padding:0;font-size:34px;background:var(--good)">+</div></div>''' for e, n, d, v in
              [("👨‍🍳", "Cooking", "Faster & better food", 14), ("❤️", "Strength", "Hit harder in fights", 9), ("🔧", "Repair", "Fix broken stuff faster", 6), ("🍀", "Luck", "Happier customers, rarer finds", 5)]) + '''
          <div class="row" style="justify-content:space-between;margin-top:14px;font-weight:700;font-size:22px"><span style="color:var(--mustard)">2 points to spend</span><span>More Stats ▾</span></div></div>'''))))
    L.append(S(35, "Mutation Mart", "Commons and Uncommons always stocked; Rares rotate. Prices from §36.3.", "§18 BLD_01, §36.3", lambda: (
        hud_wallet("12,480", "86")
        + at(1000, 120, '<div class="lucky so" style="font-size:54px">🧬 MUTATION MART</div>')
        + at(1000, 200, '<div class="paper" style="padding:24px 24px 46px;width:860px">' + grid([cell(e, r, f"{n} · {p}") for e, r, n, p in [
            ("🐻", "C", "Bear Head", "330"), ("🐰", "C", "Bunny Ears", "200"), ("🐻", "C", "Bear Arm", "400"), ("🦈", "U", "Shark Head", "1,640"),
            ("🐙", "U", "Octopus Arm", "2,000"), ("🦒", "U", "Giraffe Neck", "1,040"), ("🦋", "U", "Moth Wings", "1,640"), ("🦔", "U", "Porcupine", "2,000"),
            ("📺", "R", "TV Head", "8,200"), ("🦏", "R", "Rhino Horn", "7,000"), ("🐆", "R", "Cheetah Leg", "7,000"), ("🦂", "R", "Scorpion Tail", "10,000")]], 4, 30)
            + '<div class="row" style="gap:12px;margin-top:26px"><div class="chip">🔄 Rotation refreshes in 5 h 12 m</div><div class="chip">Rares also cost 20 💎</div><div class="chip">No Robux, ever</div></div></div>'))))
    L.append(S(36, "Mutation Laboratory: Fusion", "Mythic fusion: 3 Legendaries from one route + 600 MS + 40 RT, deterministic output.", "§12.5, §18 BLD_11", lambda: (
        hud_wallet("612,300", "1,240", "64")
        + at(120, 150, '<div class="lucky so" style="font-size:54px">🧪 MUTATION LAB · FUSION</div>')
        + at(120, 240, '''<div class="paper" style="padding:26px;width:820px"><div style="font-weight:700;font-size:22px;margin-bottom:14px">Mythological route → choose your Mythic</div>
          <div class="row" style="gap:26px">''' + cell("🔥", "L", "Phoenix Head", 9) + cell("🔮", "L", "Crystal Eyes", 9) + cell("😈", "L", "Demon Horns", 9) + '''
          <div class="lucky" style="font-size:70px">➜</div>''' + cell("🪽", "M", "Phoenix Wings", None, True) + '''</div>
          <div class="row" style="gap:12px;margin-top:40px"><div class="chip">💎 600 MS ✓</div><div class="chip">🧪 40 RT ✓</div><div class="chip">Output is chosen, never random</div></div>
          <div class="btn" style="margin-top:16px;width:100%;font-size:30px">⚗️ FUSE</div></div>'''))))
    L.append(S(37, "Body Mods: Colors & Palettes", "Per-part tint palettes; cosmetic only, earnable or purchased.", "§13, §23", lambda: (
        at(1180, 140, '''<div class="paper" style="padding:22px;width:680px"><div class="lucky" style="font-size:34px;color:var(--m)">💅 BODY MODS</div>
          <div style="font-weight:600;font-size:20px;margin:6px 0 14px">Slot: Arms · Crab Claw</div><div style="display:grid;grid-template-columns:repeat(6,1fr);gap:14px">''' + "".join(
              f'<div style="height:74px;border-radius:16px;border:4px solid {"var(--mustard)" if i == 3 else "var(--ink)"};background:{c}"></div>' for i, c in enumerate(
                  ["#ff7aa2", "#ffb347", "#ffe066", "#7be495", "#4ecdc4", "#5c7cfa", "#9d4edd", "#ff4b3e", "#c0c0c0", "#222", "linear-gradient(90deg,#ff0080,#7928ca,#2afadf)", "linear-gradient(90deg,#ffd700,#ff8c00)"])) + '''</div>
          <div class="row" style="gap:12px;margin-top:16px"><div class="chip">🌈 Neon palette 6,000 MB</div><div class="chip">✨ Prestige palette 20,000 MB (L30)</div></div>
          <div class="btn" style="margin-top:14px;width:100%">APPLY</div></div>'''))))
    L.append(S(38, "Synergy Unlocked", "SYN_001 Eight-Arm Kitchen Nightmare: octopus arms + chef parts cook several items faster.", "§12.10, §36.4", lambda: (
        mid({"level": 20, "xp": .9, "face": "🦝"}, {"mb": "11,240", "ms": "95"},
            orders=[(1, "🍔", .7, "var(--good)", "60"), (2, "🍳", .6, "var(--warn)", "52"), (3, "🥞", .8, "var(--good)", "66")], abilities=False)
        + at(0, 200, '''<div style="width:1920px;display:flex;justify-content:center"><div class="paper col" style="padding:18px 30px;align-items:center;border-color:var(--e);border-width:6px">
          <div class="lucky" style="font-size:44px;color:var(--e)">✨ SYNERGY UNLOCKED! ✨</div><div style="font-weight:700;font-size:28px">🐙 Eight-Arm Kitchen Nightmare</div>
          <div style="font-size:21px;font-weight:600">While 2+ items cook at once, all cook faster · tend two adjacent stations</div></div></div>'''))))
    # ---------------------------------------------------------------- restaurant management
    L.append(S(39, "Restaurant Supplies", "Stock appliances (Lv1 prices from §36.13) and upgrade paths Lv2–Lv5.", "§15, §36.13", lambda: (
        hud_wallet("8,940", "72")
        + at(80, 120, '<div class="lucky so" style="font-size:54px">🛠️ RESTAURANT SUPPLIES</div>')
        + at(80, 210, '<div class="paper" style="padding:20px;width:900px"><table class="t"><tr><th>Appliance</th><th>Station</th><th>Tier</th><th>Price</th><th></th></tr>' + "".join(
            f'<tr><td><span style="font-size:30px">{e}</span> {n}</td><td>{st}</td><td>T{t}</td><td><b>{p} MB</b></td><td><span class="btn" style="font-size:18px;padding:4px 14px">{b}</span></td></tr>' for e, n, st, t, p, b in [
                ("🔥", "Sizzle Grill", "Grill", 1, "400", "Owned"), ("🍟", "Bubble Fryer", "Fryer", 1, "450", "Owned"), ("🍕", "Brick Pizza Oven", "Pizza Oven", 1, "1,200", "BUY"),
                ("🍲", "Bubbling Soup Pot", "Soup Pot", 1, "1,000", "BUY"), ("🌀", "Whirly Blender", "Blender", 1, "1,300", "BUY"), ("🍦", "Swirl-O-Matic", "Ice Cream", 1, "1,100", "BUY"),
                ("🧊", "Frosty Box Freezer", "Freezer", 2, "2,000", "BUY"), ("🛸", "Anti-Gravity Wok", "Anti-Grav", 5, "10,000", "🔒 T5")]) + '</table>'
            + '<div class="chip" style="margin-top:12px">Appliance slots used 6 / 8 (TIER_02)</div></div>'))))

    def build_grid():
        lines = "".join(f'<line x1="{x}" y1="0" x2="{x}" y2="1080" stroke="rgba(255,255,255,.18)" stroke-width="2"/>' for x in range(0, 1920, 64))
        lines += "".join(f'<line x1="0" y1="{y}" x2="1920" y2="{y}" stroke="rgba(255,255,255,.18)" stroke-width="2"/>' for y in range(0, 1080, 64))
        return f'<div class="abs" style="left:0;top:0"><svg width="1920" height="1080">{lines}</svg></div>'
    L.append(S(40, "Build Mode", "2-stud grid, 90° rotation; every layout must keep the door connected to every seat.", "§15.5", lambda: (
        build_grid() + hud_wallet("26,400", "190")
        + at(28, 24, '<div class="dark" style="padding:10px 18px;font-weight:700;font-size:26px">🏗️ BUILD MODE · service paused</div>')
        + at(860, 470, '<div style="width:192px;height:128px;border:5px dashed #48D16B;background:rgba(72,209,107,.25);border-radius:12px"></div>')
        + at(830, 610, '<div class="chip" style="background:#E6FFF4">✓ Path OK · +4 Atmosphere</div>')
        + at(0, 900, '<div style="width:1920px;display:flex;justify-content:center"><div class="paper row" style="padding:14px;gap:14px">' + "".join(
            f'<div class="col" style="align-items:center;width:120px"><div class="cell" style="width:90px;height:90px;font-size:44px">{e}</div><span style="font-size:15px;font-weight:700;margin-top:6px">{n}</span></div>' for e, n in
            [("🪑", "Booth"), ("🍽️", "Table"), ("🪴", "Plant"), ("💡", "Neon Lamp"), ("🐠", "Aquarium"), ("🗿", "Statue"), ("🎵", "Jukebox"), ("🪞", "Morph Mirror")]) + '</div></div>')
        + at(1500, 120, '<div class="dark" style="padding:12px 16px;width:360px;font-size:20px;font-weight:600">🌟 Atmosphere 68 / 85<br>🔄 R rotate · ⌫ store · Ctrl+Z undo</div>'))))
    L.append(S(41, "Restaurant Upgrade: Tier 3 → Tier 4", "Morph City Grill: 5,000 MB + City Hall permit; the Mutant Builders take 10 seconds.", "§15.2, §36.12", lambda: (
        at(560, 140, '''<div class="paper" style="padding:26px;width:800px"><div class="lucky" style="font-size:40px;color:var(--teal)">🏗️ UPGRADE RESTAURANT</div>
          <div style="font-weight:700;font-size:26px;margin:6px 0 14px">Neighborhood Freak Café ➜ <span style="color:var(--ketchup)">Morph City Grill</span></div>
          <table class="t"><tr><th></th><th>Now</th><th>After</th></tr><tr><td>🪑 Seats</td><td>8</td><td><b>10</b></td></tr><tr><td>🍳 Appliance slots</td><td>10</td><td><b>12</b></td></tr>
          <tr><td>📋 Menu slots</td><td>6</td><td><b>8</b></td></tr><tr><td>👷 Employees</td><td>4</td><td><b>6</b></td></tr><tr><td>👥 Base demand</td><td>80/h</td><td><b>95/h</b></td></tr></table>
          <div class="row" style="gap:12px;margin-top:14px"><div class="chip">🪙 5,000 MB ✓</div><div class="chip">⭐ Level 18 ✓</div><div class="chip">📜 City Hall permit ✓</div></div>
          <div class="btn" style="margin-top:16px;width:100%;font-size:32px">🔨 UPGRADE!</div></div>''')), blur=True))
    L.append(S(42, "Recruitment Office", "Candidates refresh every 4 h; rarity sets stats, wage and potential.", "§16.4, §36.8", lambda: (
        hud_wallet("19,700", "140")
        + at(80, 110, '<div class="lucky so" style="font-size:54px">📋 RECRUITMENT OFFICE</div>')
        + at(80, 190, '<div class="dark" style="padding:8px 16px;font-weight:700">🔄 New candidates in 2 h 41 m · Staff 5 / 6</div>')
        # compact cards along the bottom so the candidates' faces in the plate stay visible
        + at(96, 800, '<div class="row" style="gap:24px;align-items:stretch">' + "".join(
            f'''<div class="paper col" style="width:560px;padding:14px 18px;gap:4px;border-color:{c};border-width:6px">
            <div class="row" style="gap:12px"><span style="font-size:46px">{e}</span><div class="col" style="gap:4px"><div style="font-weight:700;font-size:24px">{n}</div>
            <div><span class="chip" style="background:{c};color:#fff">{r}</span> <span class="chip">{role}</span></div></div></div>
            <div style="font-size:19px;font-weight:600;margin-top:4px">{stats}</div><div style="font-size:18px;color:var(--muted)">{trait}</div>
            <div class="row" style="gap:14px;font-weight:700;font-size:20px;margin-top:6px"><span>Hire {hire}</span><span>Wage {wage}/h</span>
            <div class="btn" style="margin-left:auto;font-size:22px;padding:6px 20px">✍️ HIRE</div></div></div>''' for e, n, c, r, role, stats, trait, hire, wage in [
                ("🐆", "Chet Speedwell", "var(--r)", "■ Rare", "Waiter", "Service 68 · Accuracy 55 · Reliability 60", "Speedster: serves tables at roughly the speed of sound", "12,000", "165"),
                ("🦏", "Rocco", "var(--r)", "■ Rare", "Security", "Combat 70 · Reliability 64 · Service 30", "One very stern eyebrow: intercepts tantrums", "12,500", "170"),
                ("🦥", "Sloane", "var(--c)", "● Common", "Dishwasher", "Service 18 · Reliability 38", "Unhurried: slow, thorough, very cheap", "200", "10")]) + '</div>'))))
    L.append(S(43, "Employee Roster", "Roles, efficiency, morale and energy; assign stations and review performance.", "§16.5", lambda: (
        at(140, 90, '<div class="lucky so" style="font-size:54px">👷 MY STAFF · 6 / 8</div>')
        + at(140, 180, '<div class="paper" style="padding:20px;width:1640px"><table class="t"><tr><th>Employee</th><th>Role</th><th>Rarity</th><th>Efficiency</th><th>Morale</th><th>Energy</th><th>Wage</th><th>Station</th></tr>' + "".join(
            f'<tr><td><span style="font-size:30px">{e}</span> <b>{n}</b></td><td>{r}</td><td>{ra}</td><td>{ef}%</td><td>{"😊" if mo > 70 else "😐"} {mo}</td><td>⚡ {en}%</td><td>{w}/h</td><td>{s}</td></tr>' for e, n, r, ra, ef, mo, en, w, s in [
                ("🐙", "Octavia", "Chef", "▲ Uncommon", 61, 84, 92, 50, "Grill + Fryer"), ("🐆", "Chet Speedwell", "Waiter", "■ Rare", 74, 79, 88, 165, "Floor A"),
                ("🤖", "Beep-Boop Barb", "Cashier", "▲ Uncommon", 58, 90, 100, 53, "Register"), ("🦏", "Rocco", "Security", "■ Rare", 69, 72, 81, 170, "Door"),
                ("🦥", "Sloane", "Dishwasher", "● Common", 24, 95, 70, 10, "Sink"), ("🐙", "Ollie", "Chef", "● Common", 33, 88, 90, 12, "Prep Counter")]) + '</table>'
            + '<div class="row" style="gap:12px;margin-top:14px"><div class="btn">🎓 Train</div><div class="btn ghost">💸 Raise</div><div class="btn ghost">⭐ Promote</div><div class="btn ghost">🔀 Assign</div>'
            + '<div class="chip" style="margin-left:auto">Offline cap 8 h (Rare Manager) · Wages 460 MB/h</div></div></div>')), blur=True))
    L.append(S(44, "Welcome Back! (Offline Earnings)", "§17 Example C: TIER_05, Rare manager, 8 h with the long-absence taper.", "§17.10", lambda: (
        at(380, 50, '''<div class="paper" style="padding:26px 34px;width:1160px"><div class="lucky" style="font-size:56px;color:var(--ketchup);text-align:center">WELCOME BACK, YOU WEIRDO!</div>
          <div style="text-align:center;font-weight:600;font-size:22px">Your restaurant operated for <b>8 h 0 min</b> (capped by your Rare manager) · Full shift 2 h ▸ late shift 6 h at half pace</div>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px 50px;margin:18px 0;font-size:25px;font-weight:600">
          <div class="row" style="justify-content:space-between"><span>👥 Customers served</span><b>543</b></div><div class="row" style="justify-content:space-between"><span>💰 Revenue</span><b>19,539 MB</b></div>
          <div class="row" style="justify-content:space-between"><span>💸 Tips</span><b>1,315 MB</b></div><div class="row" style="justify-content:space-between"><span>🥬 Ingredients</span><b style="color:#c0392b">−6,636 MB</b></div>
          <div class="row" style="justify-content:space-between"><span>👷 Employee wages</span><b style="color:#c0392b">−3,180 MB</b></div><div class="row" style="justify-content:space-between"><span>🔧 Repairs</span><b>0 MB</b></div>
          <div class="row" style="justify-content:space-between"><span>⚡ Incidents</span><b style="color:#c0392b">−83 MB</b></div><div class="row" style="justify-content:space-between"><span>🧩 Discoveries</span><b>+6 💎</b></div></div>
          <div class="lucky" style="font-size:46px;text-align:center;color:#1e9e46">TOTAL PROFIT: 10,955 MB ✨</div>
          <div style="font-size:20px;font-style:italic;margin-top:10px">"Octavia cooked 391 dishes — 78 of them simultaneously, with arms to spare."<br>"Sloane washed 456 plates, very thoroughly. The other 304 are 'soaking'."</div>
          <div class="row" style="gap:12px;margin-top:16px"><div class="tab on" style="border-radius:14px;border-bottom:4px solid var(--ink)">Employee Report</div><div class="tab" style="border-radius:14px;border-bottom:4px solid var(--ink)">Damage •24</div><div class="tab" style="border-radius:14px;border-bottom:4px solid var(--ink)">Incidents 3</div></div>
          <div class="row" style="gap:16px;margin-top:16px"><div class="btn" style="flex:1;font-size:32px">🪙 COLLECT 10,955 MB</div><div class="btn teal">Upgrade tips ▸</div><div class="btn ghost">Continue ▸</div></div></div>''')), blur=True))

    def hub():
        bars = [(4.1, 2.2), (5.2, 2.6), (4.8, 2.9), (6.0, 2.7), (5.6, 3.3), (6.8, 3.0), (7.2, 3.4)]
        svg = '<svg width="760" height="320">' + "".join(
            f'<rect x="{30+i*104}" y="{300-a*38}" width="40" height="{a*38}" fill="#3A8DFF" stroke="#1B1D2B" stroke-width="3"/><rect x="{74+i*104}" y="{300-b*38}" width="40" height="{b*38}" fill="#45E0E8" stroke="#1B1D2B" stroke-width="3"/>'
            f'<text x="{60+i*104}" y="318" font-family="Fredoka" font-weight="700" font-size="16" text-anchor="middle">{d}</text>' for i, ((a, b), d) in enumerate(zip(bars, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]))) + '</svg>'
        body = (f'<div class="row" style="gap:30px;align-items:flex-start"><div><div style="font-weight:700;font-size:22px">Net income this week (k MB)</div>{svg}'
                '<div class="row" style="gap:16px;font-weight:600"><span><i style="display:inline-block;width:16px;height:16px;background:#3A8DFF;border:2px solid #1B1D2B;margin-right:6px"></i>Active play</span><span><i style="display:inline-block;width:16px;height:16px;background:#45E0E8;border:2px solid #1B1D2B;margin-right:6px"></i>Offline (staff)</span></div></div>'
                '<div class="col" style="gap:12px;flex:1"><div class="paper" style="padding:14px;border-width:3px"><div style="color:var(--muted);font-weight:700">TODAY</div><div class="lucky" style="font-size:40px">+10,640 MB</div></div>'
                '<div class="paper" style="padding:14px;border-width:3px"><div style="color:var(--muted);font-weight:700">BEST DISH</div><div style="font-weight:700;font-size:24px">🍝 Spaghetti Tornado · 74 % margin</div></div>'
                '<div class="paper" style="padding:14px;border-width:3px"><div style="color:var(--muted);font-weight:700">OFFLINE SHARE (7 days)</div><div style="font-weight:700;font-size:24px">46 % ✓ under 60 % guardrail</div></div>'
                '<div class="paper" style="padding:14px;border-width:3px"><div style="color:var(--muted);font-weight:700">BOTTLENECK</div><div style="font-weight:700;font-size:24px">Kitchen 61 % of the time → hire a Prep Cook</div></div></div></div>')
        return panel("RESTAURANT HUB", body, 180, 190, 1560, 640, ("💰 Finances", "📋 Menu", "👷 Staff", "🔧 Repairs", "⬆️ Upgrades"), "Mutant Family Restaurant · ★ 4.2", icon="🏠")
    L.append(S(45, "Restaurant Hub: Finances", "Daily active vs offline income, best dishes, and bottleneck hints.", "§24.14", hub, blur=True))
    # ---------------------------------------------------------------- city
    L.append(S(46, "Morph City: Downtown", "Walk, sprint (city-only ×1.35), Morph Metro or Pigeon Taxi between 10 districts.", "§18", lambda: (
        hud_player(level=18, xp=.3, hp=134, hpmax=134, face="🐺") + hud_wallet("7,780", "66")
        + minimap(1650, 110, "Downtown Morph City")
        + at(0, 200, '<div style="width:1920px;text-align:center"><span class="lucky so" style="font-size:70px">DOWNTOWN MORPH CITY</span><br><span class="dark" style="padding:4px 16px;font-weight:700;font-size:22px">District discovered! Metro station unlocked 🚇</span></div>')
        + hud_objective("A Permit to Grill", "Visit City Hall (BLD_09) to stamp your Tier 4 permit", 0.5, 28, 150))))

    def city_map():
        d = [("Restaurant Row", 330, 520, "🍔"), ("Mutation Market", 560, 330, "🧬"), ("Downtown", 860, 470, "🏙️"), ("Industrial", 1160, 300, "🏭"),
             ("Monster Mall", 1120, 640, "🛍️"), ("Research", 760, 200, "🔬"), ("Entertainment", 1400, 520, "🎪"), ("Residential", 330, 760, "🏡"),
             ("Sewers", 900, 820, "🐀"), ("Arena District", 1500, 760, "🏟️")]
        links = [(0, 1), (0, 2), (0, 7), (1, 2), (1, 5), (2, 3), (2, 4), (2, 6), (2, 9), (3, 8), (4, 6), (5, 8), (6, 9), (7, 8)]
        svg = '<svg width="1700" height="960">' + "".join(
            f'<line x1="{d[a][1]}" y1="{d[a][2]}" x2="{d[b][1]}" y2="{d[b][2]}" stroke="#2EC4B6" stroke-width="10" stroke-dasharray="{"14 12" if 8 in (a, b) else "0"}"/>' for a, b in links) + "".join(
            f'<circle cx="{x}" cy="{y}" r="62" fill="#FFF6E0" stroke="#1B1D2B" stroke-width="6"/><text x="{x}" y="{y+20}" font-size="56" text-anchor="middle" font-family="Noto Color Emoji">{e}</text>'
            f'<text x="{x}" y="{y+96}" font-size="26" text-anchor="middle" font-family="Fredoka" font-weight="700" fill="#fff" stroke="#1B1D2B" stroke-width="6" paint-order="stroke">{n}</text>' for n, x, y, e in d) + '</svg>'
        return (at(110, 60, '<div class="lucky so" style="font-size:58px">🗺️ MORPH CITY MAP</div>') + at(110, 100, svg)
                + at(1520, 160, '<div class="paper" style="padding:16px;width:330px;font-size:20px;font-weight:600"><div class="lucky" style="font-size:24px">LEGEND</div>🚇 Metro (free)<br>🐦 Pigeon Taxi (25 MB × tier)<br>🚪 Return Door (free)<br>⚡ Live event: Rat King!<br>👥 2 friends online<br>🍔 Your restaurant</div>'))
    L.append(S(47, "City Map & Fast Travel", "Ten districts; the Sewers link via hidden manholes (dashed).", "§18.2, §24.17", city_map, blur=True))
    L.append(S(48, "Pigeon Taxi", "Fly to any discovered district; the fare is charged on arrival.", "§18.4", lambda: (
        at(0, 860, '''<div style="width:1920px;display:flex;justify-content:center"><div class="slate" style="padding:16px 26px;width:820px">
          <div class="row" style="justify-content:space-between;font-weight:700;font-size:24px"><span>🐦 Pigeon Taxi → Mutation Research District</span><span>125 MB</span></div>
          <div class="bar" style="height:24px;margin-top:10px"><i style="width:62%;background:var(--mustard)"></i></div>
          <div style="font-size:18px;color:#cdd;margin-top:6px">Arriving in 4 s · streaming the district ahead of you</div></div></div>'''))))
    L.append(S(49, "City Event: Giant Rat King Attack", "EVT_007 every 4 h: the whole server defends the avenue together.", "§36.11", lambda: (
        hud_player(level=26, xp=.5, hp=150, hpmax=150, face="🐻") + hud_wallet("21,900", "150") + hud_abilities()
        + at(0, 150, '''<div style="width:1920px;display:flex;justify-content:center"><div class="slate col" style="padding:14px 28px;width:900px;align-items:center">
          <div class="lucky" style="font-size:46px;color:#FFC531">🐀👑 GIANT RAT KING ATTACK!</div>
          <div class="bar" style="width:100%;height:26px;margin-top:8px"><i style="width:57%;background:var(--danger)"></i></div>
          <div class="row" style="justify-content:space-between;width:100%;font-weight:700;font-size:20px;margin-top:6px"><span>King Ratbeard 57 %</span><span>⏱️ 6:12</span><span>👥 23 heroes · 3 servers</span></div></div></div>''')
        + at(1500, 330, '<div class="dark" style="padding:12px 16px;width:360px;font-size:19px;font-weight:600">🏆 Rewards<br>Participation: 💎 + capsule<br>Success: Rat King\'s Crown Display<br>Top 10: 🧪 research tokens</div>'))))
    L.append(S(50, "Mystery Market (Sewers)", "Weekly Legendary, daily Epics and Rares; odds-free, priced items only.", "§18, §36.10 BLD_13", lambda: (
        hud_wallet("204,800", "910", "41")
        + at(1020, 120, '<div class="lucky so" style="font-size:52px">🕯️ MYSTERY MARKET</div>')
        + at(1020, 200, '''<div class="paper" style="padding:22px;width:840px"><div style="font-weight:700;font-size:22px;margin-bottom:16px">"Psst. Shiny things. Fair prices. Mostly." — The Hooded Hagfish</div>
          <div class="row" style="gap:30px">''' + cell("🦑", "L", "Kraken Arm") + cell("🐉", "E", "Dragon Head") + cell("🌋", "E", "Lava Fist") + cell("☄️", "E", "Comet Tail") + '''</div>
          <table class="t" style="margin-top:40px"><tr><td>★ Kraken Tentacle Arm</td><td><b>325,000 MB + 250 💎 + 10 🧪</b></td><td>Weekly · 4 d left</td></tr>
          <tr><td>⬟ Dragon Head</td><td><b>60,000 MB + 80 💎</b></td><td>Daily · 7 h left</td></tr><tr><td>⬟ Lava Fist Arm</td><td><b>52,000 MB + 80 💎</b></td><td>Daily · 7 h left</td></tr></table></div>'''))))

    def journal():
        rows = [("📖", "Story · Ch. 4", "A Permit to Grill", "Visit City Hall and impress Mayor Moosington", 0.5), ("☀️", "Daily", "Pickle Purist", "Serve 10 dishes with a COUNT modification", 0.7),
                ("☀️", "Daily", "Calm Waters", "Talk down 3 angry customers without fighting", 0.33), ("☀️", "Daily", "Sizzle Shift", "Cook 25 grilled items at PERFECT", 0.2),
                ("📅", "Weekly", "Critic's Choice", "Earn a 5-star review from Madame Fourchette", 0.0), ("🛠️", "Repair", "Good As New", "Repair 15 objects in one day", 0.6)]
        body = "".join(f'''<div class="row" style="gap:16px;padding:12px 6px;border-bottom:3px dashed var(--paper2)"><span style="font-size:40px">{e}</span>
          <div class="col" style="flex:1"><span style="color:var(--muted);font-weight:700;font-size:16px">{t}</span><span style="font-weight:700;font-size:25px">{n}</span><span style="font-size:19px">{d}</span>
          <div class="bar" style="height:14px;margin-top:6px;background:#e8dcbf;border-color:#c9bc9c"><i style="width:{p*100:.0f}%;background:var(--mustard)"></i></div></div>
          <div class="btn ghost" style="font-size:18px;padding:6px 14px">📍 Track</div></div>''' for e, t, n, d, p in rows)
        body += '<div class="row" style="gap:12px;margin-top:14px"><div class="chip">🔄 1 free daily reroll</div><div class="chip">Dailies reset 00:00 UTC</div><div class="chip">Arena quests always offer a non-PvP option</div></div>'
        return panel("QUEST JOURNAL", body, 420, 70, 1080, 940, ("All", "Story", "Daily", "Weekly", "Challenges"), "Pinboard Pete's Job Board", icon="📌")
    L.append(S(51, "Job Board & Quest Journal", "157 quests: story chapters, dailies, weeklies and challenge lines.", "§20", journal, blur=True))
    L.append(S(52, "Morph Arena (Opt-in PvP)", "Normalized stats, PvP damage ×0.7; never required for restaurant progression.", "§21.12", lambda: (
        at(0, 30, '''<div style="width:1920px;display:flex;justify-content:center"><div class="row" style="gap:20px;align-items:center">
          <div class="slate" style="padding:10px 16px;width:500px"><div class="row" style="justify-content:space-between;font-weight:700;font-size:22px"><span>🐻 Chef Grizzle</span><span>1,284 MMR</span></div><div class="bar" style="height:22px;margin-top:6px"><i style="width:72%;background:var(--good)"></i></div></div>
          <div class="lucky so" style="font-size:54px">1:24</div>
          <div class="slate" style="padding:10px 16px;width:500px"><div class="row" style="justify-content:space-between;font-weight:700;font-size:22px"><span>🦈 FinnTastic</span><span>1,301 MMR</span></div><div class="bar" style="height:22px;margin-top:6px"><i style="width:48%;background:var(--danger)"></i></div></div></div></div>''')
        + at(0, 140, '<div style="width:1920px;text-align:center"><span class="dark" style="padding:6px 16px;font-weight:700;font-size:20px">Food Fight Duel · Round 2 of 3 · stats normalized ⚖️</span></div>')
        + hud_abilities([("🦂", "1", 0), ("🐻", "2", .5), ("🦘", "3", 0), ("🦔", "4", 0)]))))
    return L
