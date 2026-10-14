#!/usr/bin/env python3
"""Finish a piece of store art (the AI thumbnails made from the game's renders): crop it to 16:9, size it to
1920 x 1080, and add the game's title and a caption in the same lettering as the screenshots (thumbs_post.py).

  python3 tools/gameplay/title_art.py <in.png> <out.jpg> --font LuckiestGuy.ttf [--caption "HOLD THE GATE!"]
                                      [--bottom] [--no-title]
--bottom puts the lettering along the bottom edge (for art with a face or a big shape at the top).
Needs Pillow and numpy.
"""
import os
import sys

from PIL import Image, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from thumbs_post import TITLE, outlined_text  # noqa: E402


def fit(img):
    w, h = img.size
    want = 16 / 9
    if w / h > want:
        nw = int(h * want)
        img = img.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / want)
        img = img.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    return img.resize((1920, 1080), Image.LANCZOS)


def letter(img, font_path, caption, bottom, title):
    img = img.convert("RGBA")
    big = ImageFont.truetype(font_path, 150)
    small = ImageFont.truetype(font_path, 72)
    outline = (34, 20, 30)
    if bottom:
        y = 1080 - 40 - (110 if caption else 0) - 150
    else:
        y = 40
    if title:
        y = outlined_text(img, TITLE, big, 960, y, (255, 238, 110), (255, 140, 30), outline, 12) + 26
    if caption:
        outlined_text(img, caption, small, 960, y, (255, 255, 255), (232, 236, 255), outline, 8)
    return img.convert("RGB")


def main():
    src, out = sys.argv[1], sys.argv[2]
    args = sys.argv[3:]
    font = args[args.index("--font") + 1]
    caption = args[args.index("--caption") + 1] if "--caption" in args else None
    img = fit(Image.open(src).convert("RGB"))
    img = letter(img, font, caption, "--bottom" in args, "--no-title" not in args)
    img.save(out, quality=90, optimize=True)
    # keep store uploads small
    q = 88
    while os.path.getsize(out) > 600_000 and q > 60:
        img.save(out, quality=q, optimize=True)
        q -= 4
    print("wrote", out, os.path.getsize(out) // 1024, "KB")


if __name__ == "__main__":
    main()
