#!/usr/bin/env python3
"""Finish a piece of store art (the AI thumbnails made from the game's renders): crop it to 16:9, size it to
1920 x 1080, and add the lettering in the same font as the screenshots (thumbs_post.py): the game's title with a
caption under it, or only a caption.

  python3 tools/gameplay/title_art.py <in.png> <out.jpg> --font LuckiestGuy.ttf [--caption "SET SAIL"]
                                      [--bottom] [--left | --right] [--no-title]
  python3 tools/gameplay/title_art.py <in.png> <out.jpg> --font LuckiestGuy.ttf --caption-only
                                      --caption "WHAT'S DOWN THERE?" [--size 130] [--at X,Y] [--width W]
  python3 tools/gameplay/title_art.py <in.png> <out.jpg> --font LuckiestGuy.ttf --caption-only   (no lettering)

With the title: --bottom puts the lettering along the bottom edge (for art with a face or a big shape at the top);
--left and --right put a slightly smaller block in that top (or bottom) corner instead of the middle, beside a big
character. --no-title leaves the title off and keeps the small caption where the title's caption would be.

--caption-only prints just the caption, big (--size, default 120 px), white with a dark outline, for a question
on a thumbnail. Put it in empty sky or water, never over a face or the thing the picture is about: --at X,Y is the
middle of the block's top edge in the 1920 x 1080 frame (default 960,48); --left, --right and --bottom move the
default into that corner or edge. A caption longer than --width px (default 1500) wraps onto more lines; a "|" in
the caption breaks the line there. The block always stays 40 px inside the frame.
Needs Pillow and numpy.
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from thumbs_post import TITLE, outlined_text  # noqa: E402

OUTLINE = (34, 20, 30)
MARGIN = 40


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


def letter(img, font_path, caption, bottom, title, side=None):
    img = img.convert("RGBA")
    k = 0.7 if side else 1.0
    big = ImageFont.truetype(font_path, int(150 * k))
    small = ImageFont.truetype(font_path, int(72 * k))
    cx = {"left": 500, "right": 1420}.get(side, 960)
    # a long title (or caption) in a corner must still fit inside the frame (40 px margin)
    widest = TITLE if title else (caption or "")
    box = ImageDraw.Draw(img).textbbox((0, 0), widest, font=big if title else small, stroke_width=int(12 * k))
    half = (box[2] - box[0]) / 2
    cx = int(max(MARGIN + half, min(cx, 1920 - MARGIN - half)))
    if bottom:
        y = 1080 - 40 - int(((110 if caption else 0) + (150 if title else 0)) * k)
    else:
        y = 36
    if title:
        y = outlined_text(img, TITLE, big, cx, y, (255, 238, 110), (255, 140, 30), OUTLINE, int(12 * k)) + int(26 * k)
    if caption:
        outlined_text(img, caption, small, cx, y, (255, 255, 255), (232, 236, 255), OUTLINE, int(8 * k))
    return img.convert("RGB")


def wrap(draw, text, font, stroke, width):
    lines = []
    for chunk in text.split("|"):
        words, line = chunk.split(), ""
        for word in words:
            trial = (line + " " + word).strip()
            box = draw.textbbox((0, 0), trial, font=font, stroke_width=stroke)
            if line and box[2] - box[0] > width:
                lines.append(line)
                line = word
            else:
                line = trial
        if line:
            lines.append(line)
    return lines


def caption_only(img, font_path, caption, size, at, width, side, bottom):
    """Only the caption: big white capitals with a thick dark outline, one block of centred lines."""
    if not caption.strip():
        return img  # (no caption: just the 1920 x 1080 crop, for the clean version)
    img = img.convert("RGBA")
    font = ImageFont.truetype(font_path, size)
    stroke = max(6, size // 11)
    draw = ImageDraw.Draw(img)
    lines = wrap(draw, caption, font, stroke, width)
    boxes = [draw.textbbox((0, 0), line, font=font, stroke_width=stroke) for line in lines]
    gap = int(size * 0.12)
    heights = [b[3] - b[1] for b in boxes]
    total = sum(heights) + gap * (len(lines) - 1)
    half = max(b[2] - b[0] for b in boxes) / 2
    if at:
        cx, y = at
    else:
        cx = {"left": MARGIN + half, "right": 1920 - MARGIN - half}.get(side, 960)
        y = 1080 - MARGIN - total if bottom else 48
    cx = int(max(MARGIN + half, min(cx, 1920 - MARGIN - half)))
    y = int(max(MARGIN, min(y, 1080 - MARGIN - total)))
    for line, h in zip(lines, heights):
        outlined_text(img, line, font, cx, y, (255, 255, 255), (232, 236, 255), OUTLINE, stroke)
        y += h + gap
    return img.convert("RGB")


def main():
    src, out = sys.argv[1], sys.argv[2]
    args = sys.argv[3:]

    def opt(name, default=None):
        return args[args.index(name) + 1] if name in args else default

    font = opt("--font")
    caption = opt("--caption")
    img = fit(Image.open(src).convert("RGB"))
    side = "left" if "--left" in args else ("right" if "--right" in args else None)
    if "--caption-only" in args:
        at = tuple(int(v) for v in opt("--at").split(",")) if opt("--at") else None
        img = caption_only(img, font, caption or "", int(opt("--size", 120)), at, int(opt("--width", 1500)), side,
                           "--bottom" in args)
    else:
        img = letter(img, font, caption, "--bottom" in args, "--no-title" not in args, side)
    img.save(out, quality=90, optimize=True)
    # keep store uploads small
    q = 88
    while os.path.getsize(out) > 600_000 and q > 60:
        img.save(out, quality=q, optimize=True)
        q -= 4
    print("wrote", out, os.path.getsize(out) // 1024, "KB")


if __name__ == "__main__":
    main()
