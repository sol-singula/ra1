#!/usr/bin/env python3
"""Compose the GDD gameplay preview images: AI-rendered scene plates + HTML UI overlays.

Each shot = a background plate (3D scene, no UI, generated from the art direction in §25) and an overlay built
from the UI components specified in §24 (HUD, order tickets, minigame widgets, menus, toasts). Overlays are
plain HTML/CSS rendered by headless Chromium, so all interface text is crisp and matches the GDD.

Usage:
    python3 gdd/tools/compose_previews.py --plates DIR --html OUTDIR      # writes one HTML file per shot
    node render.js OUTDIR gdd/previews                                     # screenshots each HTML to JPEG
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

FONT_DIR = None  # set from CLI

# ----------------------------------------------------------------------------------------------- styles
CSS = """
@font-face{font-family:'Luckiest';src:url('FONTDIR/luckiest-guy/files/luckiest-guy-latin-400-normal.woff2')}
@font-face{font-family:'Fredoka';font-weight:400;src:url('FONTDIR/fredoka/files/fredoka-latin-400-normal.woff2')}
@font-face{font-family:'Fredoka';font-weight:600;src:url('FONTDIR/fredoka/files/fredoka-latin-600-normal.woff2')}
@font-face{font-family:'Fredoka';font-weight:700;src:url('FONTDIR/fredoka/files/fredoka-latin-700-normal.woff2')}
:root{--ink:#1B1D2B;--muted:#5B6178;--paper:#FFF6E0;--paper2:#F2E6C9;--slate:#23263A;--mustard:#FFC531;
--ketchup:#FF4B3E;--teal:#2EC4B6;--mb:#FFD23F;--ms:#45E0E8;--rt:#C9B6FF;--good:#48D16B;--warn:#FFC531;
--alert:#FF8A1F;--danger:#FF4B3E;--info:#3A8DFF;--c:#9AA0A6;--u:#3DDC84;--r:#3A8DFF;--e:#A15CFF;--l:#FF9F1C;
--m:#FF3EA5;--s:#111}
*{box-sizing:border-box}
body{margin:0;width:1920px;height:1080px;overflow:hidden;font-family:'Fredoka','Noto Color Emoji',sans-serif;
color:var(--ink)}
/* plates are zoomed ~7% so generator corner marks fall outside the frame */
.bg{position:absolute;inset:0;background-position:center;background-size:cover;transform:scale(1.07)}
.bg.blur{filter:blur(7px) brightness(.62) saturate(1.1);transform:scale(1.1)}
.scrim{position:absolute;inset:0;background:rgba(11,14,26,.42)}
.abs{position:absolute}
.lucky{font-family:'Luckiest','Noto Color Emoji';letter-spacing:1px}
.so{color:#fff;-webkit-text-stroke:3px var(--ink);paint-order:stroke fill;text-shadow:0 4px 0 rgba(0,0,0,.35)}
.so2{color:#fff;-webkit-text-stroke:2px var(--ink);paint-order:stroke fill}
.dark{background:rgba(27,29,43,.86);border:3px solid #0d0f18;border-radius:18px;color:#fff;
box-shadow:0 5px 0 rgba(0,0,0,.35)}
.paper{background:var(--paper);border:4px solid var(--ink);border-radius:20px;box-shadow:0 7px 0 rgba(0,0,0,.35)}
.slate{background:rgba(35,38,58,.93);border:4px solid var(--ink);border-radius:20px;color:#fff;
box-shadow:0 7px 0 rgba(0,0,0,.4)}
.btn{display:inline-flex;align-items:center;justify-content:center;gap:10px;background:var(--mustard);
border:4px solid var(--ink);border-radius:16px;font-weight:700;font-size:26px;padding:10px 26px;
box-shadow:0 5px 0 var(--ink);color:var(--ink)}
.btn.teal{background:var(--teal);color:#fff}.btn.red{background:var(--ketchup);color:#fff}
.btn.ghost{background:#fff}
.key{display:inline-flex;align-items:center;justify-content:center;min-width:34px;height:34px;padding:0 8px;
border-radius:9px;background:#fff;color:var(--ink);border:3px solid var(--ink);font-weight:700;font-size:20px;
box-shadow:0 3px 0 var(--ink)}
.bar{height:20px;border-radius:12px;background:#0d0f18;border:3px solid #0d0f18;overflow:hidden}
.bar>i{display:block;height:100%;border-radius:8px}
.chip{display:inline-flex;align-items:center;gap:6px;padding:4px 12px;border-radius:999px;font-weight:600;
font-size:18px;border:3px solid var(--ink);background:#fff;color:var(--ink)}
.row{display:flex;align-items:center}.col{display:flex;flex-direction:column}
.cell{width:118px;height:118px;border-radius:16px;background:var(--paper);border:4px solid var(--c);position:relative;
display:flex;align-items:center;justify-content:center;font-size:58px;box-shadow:0 4px 0 rgba(0,0,0,.3)}
.badge{position:absolute;top:-10px;left:-10px;width:34px;height:34px;border-radius:50%;border:3px solid var(--ink);
display:flex;align-items:center;justify-content:center;font-size:16px;color:#fff;font-weight:700}
.tab{padding:10px 22px;border-radius:14px 14px 0 0;font-weight:700;font-size:22px;background:var(--paper2);
border:4px solid var(--ink);border-bottom:none;margin-right:8px}
.tab.on{background:var(--mustard)}
.toast{padding:14px 28px;border-radius:18px;border:4px solid var(--ink);background:var(--paper);font-weight:700;
font-size:28px;box-shadow:0 6px 0 rgba(0,0,0,.35);display:flex;align-items:center;gap:14px}
.float{font-family:'Luckiest','Noto Color Emoji';font-size:46px;color:var(--mb);-webkit-text-stroke:3px var(--ink);
paint-order:stroke fill;text-shadow:0 4px 0 rgba(0,0,0,.35)}
table.t{border-collapse:collapse;width:100%;font-size:22px}
table.t td,table.t th{padding:8px 12px;text-align:left;border-bottom:2px solid var(--paper2)}
table.t th{font-size:18px;color:var(--muted);text-transform:uppercase;letter-spacing:.5px}
"""

RAR = {"C": ("var(--c)", "●"), "U": ("var(--u)", "▲"), "R": ("var(--r)", "■"), "E": ("var(--e)", "⬟"),
       "L": ("var(--l)", "★"), "M": ("var(--m)", "⬢"), "S": ("var(--s)", "?")}


def esc(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def at(x, y, inner, w=None, extra=""):
    ws = f"width:{w}px;" if w else ""
    return f'<div class="abs" style="left:{x}px;top:{y}px;{ws}{extra}">{inner}</div>'


def ring(frac, size=46, color="var(--good)", stroke=7, label=""):
    r = (size - stroke) / 2
    c = 2 * 3.14159 * r
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 {size} {size}">'
            f'<circle cx="{size/2}" cy="{size/2}" r="{r}" fill="#fff" stroke="#0d0f18" stroke-width="{stroke+2}"/>'
            f'<circle cx="{size/2}" cy="{size/2}" r="{r}" fill="none" stroke="{color}" stroke-width="{stroke}" '
            f'stroke-dasharray="{c*frac:.1f} {c:.1f}" transform="rotate(-90 {size/2} {size/2})" stroke-linecap="round"/>'
            f'<text x="50%" y="56%" text-anchor="middle" font-family="Fredoka" font-weight="700" font-size="{size*0.3:.0f}" fill="#1B1D2B">{label}</text></svg>')


# ----------------------------------------------------------------------------------------------- HUD pieces
def hud_player(level=4, xp=0.62, hp=106, hpmax=106, face="🐺", name="Chef Grizzle"):
    return at(28, 24, f'''<div class="dark row" style="padding:12px 18px 12px 12px;gap:14px;width:440px">
  <div style="width:84px;height:84px;border-radius:50%;background:var(--paper);border:4px solid var(--ink);
   display:flex;align-items:center;justify-content:center;font-size:52px;position:relative">{face}
   <div class="lucky" style="position:absolute;bottom:-12px;right:-14px;background:var(--mustard);color:var(--ink);
    border:3px solid var(--ink);border-radius:12px;padding:2px 8px;font-size:24px">{level}</div></div>
  <div class="col" style="flex:1;gap:7px">
   <div style="font-weight:700;font-size:22px">{esc(name)} <span style="color:#aab;font-weight:600;font-size:17px">Lv {level}</span></div>
   <div class="row" style="gap:8px"><span style="font-size:18px">❤️</span><div class="bar" style="flex:1"><i style="width:{hp/hpmax*100:.0f}%;background:var(--danger)"></i></div><span style="font-size:17px;font-weight:600">{hp}/{hpmax}</span></div>
   <div class="row" style="gap:8px"><span style="font-size:18px">⭐</span><div class="bar" style="flex:1;height:14px"><i style="width:{xp*100:.0f}%;background:var(--teal)"></i></div><span style="font-size:15px;color:#cce">XP</span></div>
  </div></div>''')


def hud_wallet(mb="1,240", ms="35", rt=None):
    rt_html = f'<div class="dark row" style="padding:8px 16px;gap:8px;font-size:26px;font-weight:700">🧪 {rt}</div>' if rt else ""
    return at(1920 - 28 - 560, 24, f'''<div class="row" style="justify-content:flex-end;gap:12px">
  <div class="dark row" style="padding:8px 16px;gap:8px;font-size:26px;font-weight:700"><span style="font-size:30px">🪙</span>{mb}<span style="color:var(--mb);font-size:16px">MB</span></div>
  <div class="dark row" style="padding:8px 16px;gap:8px;font-size:26px;font-weight:700"><span style="font-size:28px">💎</span>{ms}<span style="color:var(--ms);font-size:16px">MS</span></div>
  {rt_html}
  <div class="dark" style="width:56px;height:56px;display:flex;align-items:center;justify-content:center;font-size:30px">☰</div>
 </div>''', w=560)


def hud_objective(title, line, prog=None, x=28, y=150):
    p = f'<div class="bar" style="height:14px;margin-top:8px"><i style="width:{prog*100:.0f}%;background:var(--mustard)"></i></div>' if prog is not None else ""
    return at(x, y, f'''<div class="dark" style="padding:12px 16px;width:440px">
  <div style="font-size:15px;color:var(--mustard);font-weight:700;letter-spacing:1px">📜 QUEST</div>
  <div style="font-weight:700;font-size:22px">{esc(title)}</div>
  <div style="font-size:18px;color:#dde;margin-top:2px">{esc(line)}</div>{p}</div>''')


def hud_orders(tickets, x=660, y=22):
    """tickets: list of (table, emoji_items, frac, color, label)"""
    out = []
    for t, items, frac, col, lab in tickets:
        out.append(f'''<div class="paper row" style="padding:6px 10px 6px 8px;gap:8px;border-radius:16px">
   {ring(frac, 48, col, 7, lab)}<div class="col" style="gap:0"><span style="font-size:13px;font-weight:700;color:var(--muted)">T{t}</span>
   <span style="font-size:30px;line-height:34px">{items}</span></div></div>''')
    return at(x, y, f'<div class="row" style="gap:10px">{"".join(out)}</div>')


def hud_abilities(slots=None, x=None, y=948):
    slots = slots or [("🦂", "1", 0), ("🦀", "2", 0.6), ("🐙", "3", 0), ("🔧", "4", 0)]
    base = [("👊", "LMB"), ("🛡️", "Q"), ("💨", "⇧"), ("🗯️", "V")]
    cells = []
    for em, k, cd in slots:
        cdh = f'<div style="position:absolute;inset:0;border-radius:14px;background:rgba(10,12,20,.62);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:26px;color:#fff">{cd*10:.0f}s</div>' if cd else ""
        cells.append(f'''<div style="position:relative;width:86px;height:86px;border-radius:18px;background:var(--paper);
   border:4px solid var(--ink);display:flex;align-items:center;justify-content:center;font-size:46px;box-shadow:0 5px 0 rgba(0,0,0,.4)">{em}{cdh}
   <span class="key" style="position:absolute;bottom:-14px;right:-10px;height:28px;min-width:28px;font-size:16px">{k}</span></div>''')
    bcells = "".join(f'''<div style="position:relative;width:64px;height:64px;border-radius:50%;background:rgba(27,29,43,.88);
   border:3px solid #0d0f18;display:flex;align-items:center;justify-content:center;font-size:30px">{em}
   <span class="key" style="position:absolute;bottom:-12px;right:-14px;height:24px;min-width:24px;font-size:13px">{k}</span></div>''' for em, k in base)
    w = 4 * 86 + 3 * 14 + 40 + 4 * 64 + 3 * 16
    x = x if x is not None else (1920 - w) // 2
    return at(x, y, f'<div class="row" style="gap:14px">{"".join(cells)}<div style="width:26px"></div><div class="row" style="gap:16px">{bcells}</div></div>')


def hud_restaurant(stars=3.4, clean=92, dmg=0, tier="Broken Burger Shack"):
    st = "★" * int(stars) + ("½" if stars - int(stars) >= .5 else "")
    return at(1920 - 28 - 700, 98, f'''<div class="row" style="justify-content:flex-end"><div class="dark row" style="padding:8px 16px;gap:16px;font-size:19px;font-weight:600">
  <span>🏠 {esc(tier)}</span><span style="color:var(--mustard)">{st} {stars:.1f}</span><span>🧹 {clean}%</span><span>🔧 {dmg}</span></div></div>''', w=700)


def prompt_btn(label, key="E", x=1540, y=860, emoji="👆"):
    return at(x, y, f'''<div class="row" style="gap:12px"><span class="key" style="width:54px;height:54px;font-size:26px">{key}</span>
  <div class="btn" style="font-size:30px;padding:12px 30px">{emoji} {esc(label)}</div></div>''')


def minimap(x=1650, y=110, label="Restaurant Row"):
    return at(x, y, f'''<div style="width:230px;height:230px;border-radius:50%;border:5px solid var(--ink);overflow:hidden;
  background:radial-gradient(circle at 50% 50%,#3d3f5c,#23263a);position:relative;box-shadow:0 6px 0 rgba(0,0,0,.35)">
  <div style="position:absolute;left:30px;top:100px;width:170px;height:26px;background:#5b5f86;border-radius:6px"></div>
  <div style="position:absolute;left:100px;top:20px;width:26px;height:190px;background:#5b5f86;border-radius:6px"></div>
  <div style="position:absolute;left:40px;top:40px;font-size:26px">🧬</div><div style="position:absolute;left:150px;top:44px;font-size:26px">🛠️</div>
  <div style="position:absolute;left:46px;top:150px;font-size:26px">📌</div><div style="position:absolute;left:150px;top:150px;font-size:26px">🍔</div>
  <div style="position:absolute;left:103px;top:103px;width:20px;height:20px;background:var(--mustard);border:3px solid var(--ink);transform:rotate(45deg)"></div>
 </div><div class="dark" style="text-align:center;margin-top:8px;padding:4px 10px;font-weight:700;font-size:18px">{esc(label)}</div>''')


def gameplay_hud(**kw):
    parts = [hud_player(**kw.get("player", {})), hud_wallet(**kw.get("wallet", {}))]
    if kw.get("orders"):
        parts.append(hud_orders(kw["orders"]))
    if kw.get("objective"):
        parts.append(hud_objective(*kw["objective"]))
    if kw.get("abilities", True):
        parts.append(hud_abilities(kw.get("ability_slots")))
    if kw.get("restaurant", True):
        parts.append(hud_restaurant(**kw.get("rest", {})))
    return "".join(parts)


# ----------------------------------------------------------------------------------------------- widgets
def ticket(title, items, mods=(), timer=None, x=1500, y=150, w=380, tag="ORDER"):
    li = "".join(f'<div class="row" style="gap:10px;font-size:24px;font-weight:600;padding:3px 0"><span style="font-size:30px">{e}</span>{esc(n)}<span style="margin-left:auto">{c}</span></div>' for e, n, c in items)
    md = "".join(f'<div class="chip" style="background:#FFE9A8;margin-top:6px;font-size:17px">✏️ {esc(m)}</div>' for m in mods)
    tm = f'<div class="row" style="gap:8px;margin-top:10px">{ring(timer[0], 40, timer[1], 6, "")}<span style="font-weight:700;font-size:20px">{timer[2]}</span></div>' if timer else ""
    return at(x, y, f'''<div class="paper" style="padding:14px 18px;transform:rotate(1.5deg)">
  <div class="lucky" style="font-size:26px;color:var(--ketchup)">{tag}</div><div style="font-weight:700;font-size:22px;margin-bottom:6px">{esc(title)}</div>
  {li}{md}{tm}</div>''', w=w)


def grill_bar(pos=0.62, x=560, y=820, w=800, label="Patty doneness"):
    # zones: raw / good / PERFECT / good / burned
    return at(x, y, f'''<div class="slate" style="padding:14px 20px 18px">
  <div class="row" style="justify-content:space-between;font-weight:700;font-size:20px;margin-bottom:8px"><span>🔥 {esc(label)}</span><span style="color:var(--good)">PERFECT window 2.4 s</span></div>
  <div style="position:relative;height:40px;border-radius:12px;overflow:hidden;border:3px solid #0d0f18;display:flex">
   <div style="flex:28;background:#c9a27e"></div><div style="flex:14;background:#ffc531"></div><div style="flex:18;background:#48d16b"></div>
   <div style="flex:22;background:#ffc531"></div><div style="flex:18;background:#5a3a2a"></div>
   <div style="position:absolute;left:{pos*100:.0f}%;top:-6px;width:8px;height:52px;background:#fff;border:3px solid var(--ink);border-radius:4px"></div></div>
  <div class="row" style="justify-content:space-between;font-size:16px;color:#cdd;margin-top:6px"><span>RAW</span><span>GOOD</span><span>✓ PERFECT</span><span>GOOD</span><span>✕ BURNED</span></div>
 </div>''', w=w)


def chop_ring(taps=3, total=4, x=1180, y=420):
    dots = "".join(f'<div style="width:26px;height:26px;border-radius:50%;border:3px solid var(--ink);background:{"var(--good)" if i < taps else "#fff"}"></div>' for i in range(total))
    return at(x, y, f'''<div class="col" style="align-items:center;gap:12px">
  <div style="position:relative;width:220px;height:220px">
   <div style="position:absolute;inset:0;border-radius:50%;border:16px solid rgba(255,255,255,.35)"></div>
   <div style="position:absolute;inset:0;border-radius:50%;border:16px solid transparent;border-top-color:var(--good);border-right-color:var(--warn);transform:rotate(20deg)"></div>
   <div style="position:absolute;inset:46px;border-radius:50%;border:8px solid #fff;box-shadow:0 0 0 4px var(--ink)"></div>
   <div class="lucky so" style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:44px">CHOP!</div></div>
  <div class="row" style="gap:10px">{dots}</div>
  <div class="dark" style="padding:6px 14px;font-weight:700;font-size:20px">Clean cut! ✓ 1.0</div></div>''')


def hold_bar(label, frac, x=660, y=800, w=600, color="var(--teal)", sub=""):
    return at(x, y, f'''<div class="slate" style="padding:14px 20px">
  <div class="row" style="justify-content:space-between;font-weight:700;font-size:22px;margin-bottom:8px"><span>{label}</span><span>{frac*100:.0f}%</span></div>
  <div class="bar" style="height:30px"><i style="width:{frac*100:.0f}%;background:{color}"></i></div>
  <div style="font-size:17px;color:#cdd;margin-top:6px">{sub}</div></div>''', w=w)


def gauge(label, frac, x, y, zones=("var(--info)", "var(--good)", "var(--danger)")):
    ang = -90 + frac * 180
    return at(x, y, f'''<div class="slate col" style="align-items:center;padding:16px 22px;width:280px">
  <div style="font-weight:700;font-size:20px;margin-bottom:6px">{label}</div>
  <svg width="220" height="120" viewBox="0 0 220 120"><path d="M20 110 A90 90 0 0 1 80 26" stroke="{zones[0]}" stroke-width="22" fill="none"/>
  <path d="M80 26 A90 90 0 0 1 150 28" stroke="{zones[1]}" stroke-width="22" fill="none"/><path d="M150 28 A90 90 0 0 1 200 110" stroke="{zones[2]}" stroke-width="22" fill="none"/>
  <line x1="110" y1="110" x2="110" y2="34" stroke="#fff" stroke-width="7" stroke-linecap="round" transform="rotate({ang} 110 110)"/>
  <circle cx="110" cy="110" r="11" fill="#fff" stroke="#1B1D2B" stroke-width="4"/></svg></div>''')


def toast(text, emoji="✨", x=None, y=118, w=None, color="var(--paper)"):
    style = f"background:{color};"
    xx = x if x is not None else 0
    wrap = f'<div style="display:flex;justify-content:center;width:1920px">' if x is None else "<div>"
    return at(xx, y, f'{wrap}<div class="toast" style="{style}"><span style="font-size:36px">{emoji}</span>{text}</div></div>')


def comic(text, x, y, size=110, rot=-6, color="#FF4B3E"):
    return at(x, y, f'<div class="lucky" style="font-size:{size}px;color:{color};-webkit-text-stroke:6px var(--ink);paint-order:stroke fill;transform:rotate({rot}deg);text-shadow:0 8px 0 rgba(0,0,0,.4)">{esc(text)}</div>')


def dialogue(name, line, face="🐢", x=360, y=760, w=1200, choices=()):
    ch = "".join(f'<div class="btn ghost" style="font-size:20px;padding:6px 16px">{esc(c)}</div>' for c in choices)
    return at(x, y, f'''<div class="paper row" style="padding:18px 22px;gap:20px;align-items:flex-start">
  <div style="width:110px;height:110px;flex:none;border-radius:20px;background:#bfefff;border:4px solid var(--ink);display:flex;align-items:center;justify-content:center;font-size:70px">{face}</div>
  <div class="col" style="gap:6px;flex:1"><div class="lucky" style="font-size:28px;color:var(--teal)">{esc(name)}</div>
  <div style="font-size:26px;font-weight:600;line-height:1.25">{esc(line)}</div>
  <div class="row" style="gap:12px;margin-top:6px">{ch}<span style="margin-left:auto;color:var(--muted);font-weight:700">▶ E</span></div></div></div>''', w=w)


def panel(title, body, x=150, y=70, w=1620, h=940, tabs=(), sub="", close=True, icon="✨"):
    tb = "".join(f'<div class="tab{" on" if i == 0 else ""}">{esc(t)}</div>' for i, t in enumerate(tabs))
    cl = '<div class="btn red" style="position:absolute;right:-14px;top:-14px;width:62px;height:62px;padding:0;font-size:30px">✕</div>' if close else ""
    return at(x, y, f'''<div class="col" style="height:{h}px">
  <div class="row" style="gap:16px;margin-bottom:10px"><div class="lucky so" style="font-size:58px">{icon} {esc(title)}</div>
   <div style="color:#fff;font-weight:600;font-size:22px;opacity:.9">{esc(sub)}</div></div>
  <div class="row">{tb}</div>
  <div class="paper" style="flex:1;position:relative;padding:24px;border-top-left-radius:{0 if tabs else 20}px">{cl}{body}</div></div>''', w=w)


def cell(em, rar="C", label="", lvl=None, sel=False, size=118, locked=False):
    col, shp = RAR[rar]
    lab = f'<div style="position:absolute;bottom:-28px;left:-6px;right:-6px;text-align:center;font-size:15px;font-weight:700;color:var(--ink)">{esc(label)}</div>' if label else ""
    lv = f'<div style="position:absolute;bottom:6px;right:8px;font-size:15px;font-weight:700;background:var(--ink);color:#fff;border-radius:8px;padding:0 6px">Lv{lvl}</div>' if lvl else ""
    lk = '<div style="position:absolute;inset:0;border-radius:12px;background:rgba(40,40,50,.55);display:flex;align-items:center;justify-content:center;font-size:40px">🔒</div>' if locked else ""
    sh = "box-shadow:0 0 0 6px var(--mustard),0 4px 0 rgba(0,0,0,.3);" if sel else ""
    return (f'<div class="cell" style="width:{size}px;height:{size}px;border-color:{col};{sh}font-size:{size*0.5:.0f}px">{em}'
            f'<div class="badge" style="background:{col}">{shp}</div>{lv}{lk}{lab}</div>')


def grid(cells, cols=6, gap=26):
    return f'<div style="display:grid;grid-template-columns:repeat({cols},max-content);gap:{gap+12}px {gap}px">{"".join(cells)}</div>'


def stat_rows(rows):
    return "".join(f'''<div class="row" style="gap:10px;margin:6px 0;font-size:21px;font-weight:600"><span style="width:180px">{esc(n)}</span>
  <div class="bar" style="flex:1;height:16px;background:#d9cdb0;border-color:#b9ad90"><i style="width:{v/150*100:.0f}%;background:{c}"></i></div>
  <span style="width:56px;text-align:right">{v}</span><span style="width:60px;color:{"#1e9e46" if d>0 else "#b23" if d<0 else "#999"};font-weight:700">{("▲" if d>0 else "▼" if d<0 else "")}{abs(d) if d else ""}</span></div>''' for n, v, c, d in rows)


def sat_popup(x, y, face="😍", label="DELIGHTED!", score=92, pay="+16", tip="+3"):
    return at(x, y, f'''<div class="col" style="align-items:center;gap:6px">
  <div class="paper row" style="padding:10px 18px;gap:12px"><span style="font-size:52px">{face}</span>
   <div class="col"><span class="lucky" style="font-size:30px;color:#1e9e46">{label}</span><span style="font-weight:700;font-size:20px">Satisfaction {score}</span></div></div>
  <div class="float">{pay} 🪙</div><div class="float" style="font-size:34px;color:#fff">TIP {tip}</div></div>''')


def anger_meter(level, x, y, name="Karenosaurus"):
    labels = ["Happy", "Annoyed", "Complaining", "Throwing food", "Smashing", "Fighting", "CHAOS"]
    segs = "".join(f'<div style="flex:1;height:26px;background:{["#48D16B","#9BDD5B","#FFC531","#FF8A1F","#FF5A2E","#FF2E2E","#B00020"][i] if i <= level else "#3a3d55"};border-right:3px solid #0d0f18"></div>' for i in range(7))
    return at(x, y, f'''<div class="slate" style="padding:10px 14px;width:420px">
  <div class="row" style="justify-content:space-between;font-weight:700;font-size:19px"><span>😤 {esc(name)}</span><span style="color:#ffb3a8">Lv {level}: {labels[level]}</span></div>
  <div class="row" style="margin-top:6px;border:3px solid #0d0f18;border-radius:10px;overflow:hidden">{segs}</div></div>''')


def huff_bar(x, y, name, frac, w=300, lvl=None):
    return at(x, y, f'''<div class="col" style="align-items:center;gap:4px;width:{w}px">
  <div class="so2" style="font-weight:700;font-size:22px">{esc(name)}{f" · Lv {lvl}" if lvl is not None else ""}</div>
  <div class="bar" style="width:100%;height:22px"><i style="width:{frac*100:.0f}%;background:var(--danger)"></i></div></div>''')


# ----------------------------------------------------------------------------------------------- shots
def S(n, title, caption, section, overlay, blur=False, plate=None):
    return {"n": n, "title": title, "caption": caption, "section": section, "overlay": overlay, "blur": blur,
            "plate": plate or f"{n:02d}"}


def shots():
    P = gameplay_hud
    L = []
    # 1 title
    L.append(S(1, "Title Screen", "Main menu over Restaurant Row at dusk.", "§24.20", lambda: (
        at(110, 90, '<div class="lucky" style="font-size:120px;line-height:.95;color:#fff;-webkit-text-stroke:8px var(--ink);paint-order:stroke fill;text-shadow:0 10px 0 rgba(0,0,0,.4)">MYSTERY<br><span style="color:#5BEA4B">MORPH</span><br><span style="color:#FF7A1A">RESTAURANT</span></div>')
        + at(120, 520, '<div class="dark" style="padding:8px 20px;font-weight:700;font-size:30px;letter-spacing:2px">SERVE. COOK. UPGRADE. SURVIVE.</div>')
        + at(120, 620, '<div class="col" style="gap:18px;width:420px"><div class="btn" style="font-size:38px;padding:16px">▶ PLAY</div><div class="btn ghost" style="font-size:28px">🧬 My Morph</div><div class="btn ghost" style="font-size:28px">👥 Visit a Friend</div><div class="btn ghost" style="font-size:28px">⚙️ Settings</div></div>')
        + at(1500, 1010, '<div class="dark" style="padding:6px 14px;font-size:18px">🪙 4,820 MB waiting from your staff!</div>'))))
    # 2 tutorial
    L.append(S(2, "Tutorial: Nana Gristle", "QST_TUT_001 — the cranky hologram great-aunt explains the shack.", "§32", lambda: (
        P(player={"level": 1, "xp": .05, "hp": 100, "hpmax": 100, "face": "🐱", "name": "New Chef"}, wallet={"mb": "0", "ms": "0"},
          objective=("Welcome to the Shack", "Walk inside and find the menu board (WASD)", 0.5), abilities=False,
          rest={"stars": 2.5, "clean": 41, "dmg": 3})
        + dialogue("NANA GRISTLE (hologram)", "So YOU'RE the one inheriting my shack. It has a broken table, a sticky floor and a grill older than your nose. Perfect. Let's cook something before the customers notice.", "🐢", choices=("Who are you?!", "Let's cook!"))
        + at(1150, 120, '<div class="col" style="align-items:center;gap:6px"><div style="font-size:60px">⬇️</div><div class="dark" style="padding:6px 14px;font-weight:700">Menu board</div></div>'))))
    # 3 first mutation
    L.append(S(3, "Your First Mutation", "QST_TUT_010 — pick one free starter part.", "§12, §32", lambda: (
        at(0, 40, '<div style="width:1920px;text-align:center" class="lucky so"><span style="font-size:78px">CHOOSE YOUR FIRST MUTATION!</span></div>')
        + at(280, 580, '<div class="row" style="gap:60px">' + "".join(
            f'''<div class="paper col" style="width:400px;padding:20px;align-items:center;gap:8px;border-color:{c};border-width:6px">
            <div style="font-size:90px">{e}</div><div class="lucky" style="font-size:30px">{n}</div>
            <div class="chip" style="background:{c};color:#fff">{shp} {r}</div><div style="font-size:19px;font-weight:600;text-align:center">{d}</div>
            <div class="btn" style="width:100%;margin-top:6px">{role}</div></div>''' for e, n, c, shp, r, d, role in [
                ("🐙", "Octopus Arm", "var(--u)", "▲", "Uncommon", "Carry +1 · Octo-Flurry (ABL_012)", "👨‍🍳 CHEF PICK"),
                ("🦀", "Crab Claw Arm", "var(--u)", "▲", "Uncommon", "Claw Grab & Toss (ABL_017)", "🥊 FIGHTER PICK"),
                ("🔧", "Wrench Claw Arm", "var(--r)", "■", "Rare", "Repair Burst (ABL_062)", "🛠️ REPAIR PICK")]) + '</div>'))))
    # 4 hire ollie
    L.append(S(4, "Hire Help: Ollie the Octopus Intern", "QST_TUT_012 — first employee and the offline-income preview.", "§16, §17, §32", lambda: (
        at(1180, 90, '''<div class="paper" style="padding:22px;width:640px"><div class="lucky" style="font-size:34px;color:var(--teal)">NEW HIRE: OLLIE 🐙</div>
        <div style="font-weight:600;font-size:21px;margin:6px 0 12px">Chef · Common · Wage 12 MB/h · "Eight Arms, One Brain Cell"</div>
        <table class="t"><tr><td>🍳 Cooking</td><td><b>30</b></td><td>🎯 Accuracy</td><td><b>28</b></td></tr><tr><td>🏃 Service</td><td><b>15</b></td><td>🧭 Reliability</td><td><b>40</b></td></tr></table>
        <div style="margin-top:14px;padding:14px;border-radius:14px;background:#E6FFF4;border:3px solid #1e9e46">
        <div style="font-weight:700;font-size:22px">💤 While you're away, Ollie keeps the shack open</div>
        <div style="font-size:20px;margin-top:4px">Up to <b>2 h</b> without a manager · ≈ <b>30 customers/h</b> (Ollie is the bottleneck)</div>
        <div class="float" style="font-size:40px;margin-top:6px">≈ 316 🪙 per 2 h</div></div>
        <div class="row" style="gap:14px;margin-top:16px"><div class="btn" style="flex:1">✍️ HIRE (FREE)</div><div class="btn ghost">Later</div></div></div>'''))))
    # 5 taking orders
    L.append(S(5, "Taking Orders", "Customers order with food-icon bubbles; patience rings track the wait.", "§8, §24.13", lambda: (
        P(player={"level": 3, "xp": .4, "face": "🐺"}, wallet={"mb": "486", "ms": "10"},
          orders=[(1, "🍔🥤", .82, "var(--good)", "61"), (2, "🍜", .55, "var(--warn)", "40"), (3, "🍣", .9, "var(--good)", "70"), (4, "🧋", .3, "var(--alert)", "21")],
          objective=("Your First Order", "Take Giraffe-Squid's order at the counter", 0.0))
        + prompt_btn("TAKE ORDER", "E", 1500, 860, "📝"))))
    # 6 grill
    L.append(S(6, "Cooking: The Grill", "Flip at the right time: the Perfect window is 2 s at Lv1, wider with Cooking Quality.", "§5.4", lambda: (
        P(player={"level": 3, "xp": .45, "face": "🦌"}, wallet={"mb": "502", "ms": "10"},
          orders=[(1, "🍔🥤", .64, "var(--good)", "48"), (3, "🍔", .8, "var(--good)", "62")], abilities=False)
        + grill_bar(0.52, 560, 800, 800)
        + ticket("Table 1 · Giraffe-Squid", [("🍔", "Cheeseburger", "×1"), ("🥤", "Fizzy Soda", "×1")], timer=(0.64, "var(--good)", "48 s left"), x=1480, y=160))))
    # 7 chop
    L.append(S(7, "Cooking: Chopping", "Tap in rhythm: green = clean cut, yellow = 0.8, miss = 0.6. Octopus Arms chop two boards.", "§5.4", lambda: (
        P(player={"level": 6, "xp": .2, "face": "🦝"}, wallet={"mb": "1,104", "ms": "22"},
          orders=[(2, "🥗", .7, "var(--good)", "55"), (5, "🍔", .5, "var(--warn)", "38")], abilities=False)
        + chop_ring(3, 4, 1260, 300) + prompt_btn("CHOP", "E", 1520, 900, "🔪"))))
    # 8 assembly
    L.append(S(8, "Cooking: Assembly", "Stack order matters: one swap = ×0.85 quality.", "§5.4, §6.3", lambda: (
        P(player={"level": 7, "xp": .55, "face": "🐸"}, wallet={"mb": "1,388", "ms": "24"},
          orders=[(4, "🍔", .58, "var(--warn)", "44")], abilities=False)
        + at(1480, 170, '<div class="paper" style="padding:16px 20px;width:380px"><div class="lucky" style="font-size:26px;color:var(--ketchup)">STACK ORDER</div>' + "".join(
            f'<div class="row" style="gap:10px;font-size:22px;font-weight:600;padding:4px 0">{"✅" if i < 5 else "⬜"} <span style="font-size:26px">{e}</span>{n}</div>' for i, (e, n) in enumerate(
                [("🍞", "Top bun"), ("🥒", "Pickles ×3"), ("🍅", "Tomato"), ("🥬", "Lettuce"), ("🧀", "Cheese"), ("🥩", "Patty (PERFECT)"), ("🍞", "Bottom bun")][::-1])) + '<div class="chip" style="margin-top:8px;background:#FFE9A8">✏️ "Exactly seventeen pickles"</div></div>')
        + prompt_btn("ADD LAYER", "E", 1520, 880, "🥒"))))
    return L


def shots_more():
    """Shots 9-52 are defined in the second module to keep this file readable."""
    try:
        from compose_previews_shots import more_shots  # noqa: WPS433
    except ImportError:
        return []
    return more_shots(globals())


def build_html(shot, plate_path):
    bgcls = "bg blur" if shot["blur"] else "bg"
    scrim = '<div class="scrim"></div>' if shot["blur"] else ""
    css = CSS.replace("FONTDIR", FONT_DIR)
    return (f'<!doctype html><html><head><meta charset="utf-8"><style>{css}</style></head><body>'
            f'<div class="{bgcls}" style="background-image:url(\'file://{plate_path}\')"></div>{scrim}{shot["overlay"]()}</body></html>')


def main():
    global FONT_DIR
    ap = argparse.ArgumentParser()
    ap.add_argument("--plates", required=True)
    ap.add_argument("--html", required=True)
    ap.add_argument("--fonts", required=True, help="node_modules/@fontsource directory")
    ap.add_argument("--only", help="comma-separated shot numbers")
    a = ap.parse_args()
    FONT_DIR = "file://" + str(Path(a.fonts).resolve())
    out = Path(a.html)
    out.mkdir(parents=True, exist_ok=True)
    all_shots = shots() + shots_more()
    only = {int(x) for x in a.only.split(",")} if a.only else None
    manifest = []
    for s in all_shots:
        if only and s["n"] not in only:
            continue
        plate = None
        for ext in (".jpg", ".png", ".webp"):
            p = Path(a.plates) / f'{s["plate"]}{ext}'
            if p.exists():
                plate = p.resolve()
                break
        if not plate:
            print(f"skip {s['n']:02d} (no plate)")
            continue
        (out / f'{s["n"]:02d}.html').write_text(build_html(s, plate), encoding="utf-8")
        manifest.append({k: s[k] for k in ("n", "title", "caption", "section")})
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"wrote {len(manifest)} html files")


if __name__ == "__main__":
    main()
