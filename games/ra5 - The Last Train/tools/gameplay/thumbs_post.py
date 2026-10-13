#!/usr/bin/env python3
"""The "shader" pass for store thumbnails and screenshots rendered by tools/gameplay/thumbs.luau + render.js.

For each <name>.png (with <name>_depth.png and <name>.json next to it) writes <out>/<name>.jpg (with the title)
and <out>/<name>_notext.jpg, 1920x1080:
  colour grade (contrast curve, saturation, warm highlights / cool shadows), bloom on bright areas,
  depth-of-field blur away from the camera's focus point, a warm sun glow, a vignette, then the title.

  python3 tools/gameplay/thumbs_post.py <renderDir> <outDir> --font oswald-latin-700-normal.woff
Needs Pillow and numpy.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

# per-shot caption under the title (None = title only)
CAPTIONS = {
    "01_station_boarding": "ALL ABOARD!",
    "02_hall_of_records": "HOW FAR CAN YOUR CREW GO?",
    "03_my_cabin": "BUILD YOUR CABIN",
    "04_ranger_station": "SCAVENGE BEFORE THE TRAIN LEAVES",
    "05_final_call": "DON'T MISS THE TRAIN!",
    "06_signal_tower": "FIND THE BLUEPRINTS",
    "07_on_the_line": None,
    "09_overgrown_platform": "EVERY STOP IS DIFFERENT",
    "10_left_behind": "DON'T GET LEFT BEHIND",
}
TITLE = "THE LAST TRAIN"


def arr(img):
    return np.asarray(img).astype(np.float32) / 255.0


def img_of(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8))


def blur(a, radius):
    # blur at quarter size (fast, and a big radius anyway), then back up
    h, w = a.shape[:2]
    small = img_of(a).resize((w // 4, h // 4), Image.BILINEAR).filter(ImageFilter.GaussianBlur(radius / 4))
    return arr(small.resize((w, h), Image.BILINEAR))


def grade(a):
    lum = (a @ np.array([0.2126, 0.7152, 0.0722], np.float32))[..., None]
    a = lum + (a - lum) * 1.22  # saturation
    a = np.clip(a, 0, 1)
    a = a * a * (3 - 2 * a) * 0.35 + a * 0.65  # gentle S-curve
    lum = (a @ np.array([0.2126, 0.7152, 0.0722], np.float32))[..., None]
    warm = np.array([1.05, 1.0, 0.9], np.float32)
    cool = np.array([0.92, 0.98, 1.08], np.float32)
    return np.clip(a * (cool + (warm - cool) * lum), 0, 1)


def focus_depth(snap):
    cam = snap["camera"]
    d = math.dist(cam["pos"], snap.get("focus", cam["target"]))
    return math.sqrt(min(1.0, d / 700.0))


def post(color, depth, snap):
    a = arr(color.convert("RGB"))
    h, w = a.shape[:2]
    dep = arr(depth.convert("L").resize((w, h)))
    # depth of field: blend toward a blurred copy the further a pixel is from the focus depth
    df = focus_depth(snap)
    soft = blur(a, 14)
    amount = np.clip((np.abs(dep - df) - 0.035) * 9.0, 0, 1)[..., None]
    amount[dep[..., None] > 0.995] = 0.6  # sky
    a = a * (1 - amount) + soft * amount
    a = grade(a)
    # bloom: blurred bright parts added back
    lum = a @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    bright = a * np.clip((lum - 0.72) / 0.28, 0, 1)[..., None]
    a = 1 - (1 - a) * (1 - blur(bright, 40) * 0.55)
    # sun glow from the top right, screen-blended
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.hypot((xx - w * 0.95) / w, (yy + h * 0.15) / h)
    glow = np.clip(1 - r / 0.85, 0, 1) ** 2 * 0.32
    a = 1 - (1 - a) * (1 - glow[..., None] * np.array([1.0, 0.85, 0.55], np.float32))
    # vignette
    v = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2))
    a = a * (1 - np.clip(v - 0.55, 0, 1) ** 1.6 * 0.42)[..., None]
    out = img_of(a).resize((1920, 1080), Image.LANCZOS)
    return out.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))


def outlined_text(img, text, font, cx, y, fill_top, fill_bottom, outline, stroke):
    draw = ImageDraw.Draw(img)
    box = draw.textbbox((0, 0), text, font=font, stroke_width=stroke)
    tw, th = box[2] - box[0], box[3] - box[1]
    x = int(cx - tw / 2 - box[0])
    # drop shadow
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text((x + 8, y + 12), text, font=font, fill=(0, 0, 0, 150), stroke_width=stroke,
                                stroke_fill=(0, 0, 0, 150))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(8)))
    ImageDraw.Draw(img).text((x, y), text, font=font, fill=outline, stroke_width=stroke, stroke_fill=outline)
    # vertical gradient fill through a text mask
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).text((x, y), text, font=font, fill=255)
    grad = Image.new("RGBA", img.size)
    top, bottom = y + box[1], y + box[3]
    g = ImageDraw.Draw(grad)
    for row in range(max(0, top), min(img.size[1], bottom + 1)):
        t = (row - top) / max(1, bottom - top)
        g.line([(0, row), (img.size[0], row)], fill=tuple(int(fill_top[i] + (fill_bottom[i] - fill_top[i]) * t) for i in range(3)) + (255,))
    img.paste(grad, (0, 0), mask)
    return y + th


def title(img, font_path, caption):
    img = img.convert("RGBA")
    # brass-gold condensed capitals, like the train's signs
    big = ImageFont.truetype(font_path, 150)
    bottom = outlined_text(img, TITLE, big, 960, 34, (255, 226, 150), (214, 150, 60), (24, 18, 14), 10)
    if caption:
        small = ImageFont.truetype(font_path, 70)
        outlined_text(img, caption, small, 960, bottom + 30, (255, 248, 232), (236, 222, 196), (24, 18, 14), 7)
    return img.convert("RGB")


def main():
    src, out = sys.argv[1], sys.argv[2]
    font = sys.argv[sys.argv.index("--font") + 1] if "--font" in sys.argv else None
    os.makedirs(out, exist_ok=True)
    names = json.load(open(os.path.join(src, "index.json"))) if os.path.exists(os.path.join(src, "index.json")) else None
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png") or f.endswith("_depth.png") or f.startswith("_"):
            continue
        name = f[:-4]
        snap_path = os.path.join(src, name + ".json")
        snap = json.load(open(snap_path)) if os.path.exists(snap_path) else None
        depth_path = os.path.join(src, name + "_depth.png")
        if not snap or not os.path.exists(depth_path):
            continue
        img = post(Image.open(os.path.join(src, f)), Image.open(depth_path), snap)
        img.save(os.path.join(out, name + "_notext.jpg"), quality=93)
        if font:
            title(img, font, CAPTIONS.get(name)).save(os.path.join(out, name + ".jpg"), quality=93)
        print("post", name)


if __name__ == "__main__":
    main()
