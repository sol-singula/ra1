#!/usr/bin/env python3
"""Finish a store thumbnail (AI art made from the game's renders): crop to 16:9, size to 1920 x 1080, and letter
the title and a short line in the game's own plain style: heavy black-italic type, TURF in red and WARS in blue,
the line on a black bar under it. No outlines: the art is white, like the game, so plain dark type
reads cleanly. The block sits at the top middle (the art leaves that sky empty), or wherever --at puts it.

  python3 tools/gameplay/title_art.py <in.png> <out.jpg> --line "PUSH THEIR TURF BACK" [--at X,Y] [--size 120]
  python3 tools/gameplay/title_art.py <in.png> <out.jpg> --icon        (a 512 x 512 icon, no lettering)

Needs Pillow. The font is Inter Black Italic (the system's /usr/share/fonts/opentype/inter); --font overrides it.
"""
import argparse

from PIL import Image, ImageDraw, ImageFont

RED = (235, 40, 45)
BLUE = (35, 110, 245)
INK = (20, 20, 24)
FONT = "/usr/share/fonts/opentype/inter/Inter-BlackItalic.otf"


def fit(img, want):
    w, h = img.size
    if w / h > want:
        nw = int(h * want)
        img = img.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / want)
        img = img.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--line", default="")
    ap.add_argument("--at", default="960,40")
    ap.add_argument("--size", type=int, default=140)
    ap.add_argument("--font", default=FONT)
    ap.add_argument("--icon", action="store_true")
    a = ap.parse_args()
    img = Image.open(a.src).convert("RGB")
    if a.icon:
        fit(img, 1).resize((512, 512), Image.LANCZOS).save(a.dst, optimize=True)
        return
    img = fit(img, 16 / 9).resize((1920, 1080), Image.LANCZOS)
    d = ImageDraw.Draw(img)
    big = ImageFont.truetype(a.font, a.size)
    small = ImageFont.truetype(a.font, int(a.size * 0.42))
    x0, y0 = (int(v) for v in a.at.split(","))
    # the name: TURF (red) WARS (blue); then the caption
    words = [("TURF ", RED), ("WARS", BLUE)]
    widths = [d.textlength(t, font=big) for t, _ in words]
    x = x0 - sum(widths) / 2
    for (t, c), wdt in zip(words, widths):
        d.text((x, y0), t, font=big, fill=c)
        x += wdt
    y = y0 + int(a.size * 1.12)
    if a.line:
        # the caption on a short black bar, white letters (it reads on any part of the art)
        tw = d.textlength(a.line, font=small)
        pad = int(a.size * 0.16)
        bh = int(a.size * 0.42) + pad * 2
        d.rectangle((x0 - tw / 2 - pad * 1.6, y, x0 + tw / 2 + pad * 1.6, y + bh), fill=INK)
        d.text((x0 - tw / 2, y + pad - int(a.size * 0.04)), a.line, font=small, fill=(255, 255, 255))
    img.save(a.dst, quality=90, optimize=True)


if __name__ == "__main__":
    main()
