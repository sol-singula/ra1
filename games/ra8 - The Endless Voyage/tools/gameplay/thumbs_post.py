#!/usr/bin/env python3
"""The "shader" pass for store thumbnails and screenshots rendered by tools/gameplay/thumbs.luau + render.js.

For each <name>.png (with <name>_depth.png and <name>.json next to it) writes <out>/<name>.jpg (with the title)
and <out>/<name>_notext.jpg, 1920x1080:
  colour grade (contrast curve, saturation, warm highlights / cool shadows), bloom on bright areas,
  depth-of-field blur away from the camera's focus point, a warm sun glow, a vignette, then the title.

  python3 tools/gameplay/thumbs_post.py <renderDir> <outDir> --font LuckiestGuy.ttf
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
    "01_first_cast": "CAST FOR WHAT DRIFTS BY",
    "02_build_your_raft": "BUILD YOUR RAFT",
    "03_set_sail": "SET SAIL",
    "04_palm_key": "EXPLORE ISLANDS",
    "05_the_wreck": "SALVAGE THE WRECKS",
    "06_storm": "SURVIVE THE STORM",
    "07_the_leviathan": "FACE THE LEVIATHAN",
    "08_legendary_vessel": "THE LEGENDARY VESSEL",
    "09_the_cast": "WHAT'S OUT THERE?",
    "10_the_ocean": "AN ENDLESS OCEAN",
    "11_message_in_a_bottle": "WHO SENT THIS?",
    "12_mist_hollow": "WHERE DID THEY GO?",
    "13_frost_shelf": "WHO WAS ON IT?",
    "14_the_totems": "WHAT ARE THEY WATCHING?",
    "15_the_shadow": "WHAT'S DOWN THERE?",
    "16_who_built_that": "WHO BUILT THAT?",
}
TITLE = "THE ENDLESS VOYAGE"


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


def levels(a):
    # stretch the tones so pale, hazy daytime shots get their contrast back (the 1st and 99th percentiles of
    # brightness go to near black and near white)
    lum = a @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    lo, hi = np.percentile(lum, 1), np.percentile(lum, 99)
    lo, hi = min(lo, 0.12), max(hi, 0.85)
    return np.clip((a - lo) / max(1e-3, hi - lo) * 0.97 + 0.015, 0, 1)


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
    soft = blur(a, 10)
    amount = np.clip((np.abs(dep - df) - 0.07) * 3.5, 0, 0.7)[..., None]
    amount[dep[..., None] > 0.995] = 0.35  # sky
    a = a * (1 - amount) + soft * amount
    a = levels(a)
    a = grade(a)
    # bloom: blurred bright parts added back
    lum = a @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    bright = a * np.clip((lum - 0.8) / 0.2, 0, 1)[..., None]
    strength = 0.4 if lum.mean() < 0.55 else 0.15  # bright daytime frames would go milky
    a = 1 - (1 - a) * (1 - blur(bright, 40) * strength)
    # a glow from the top right, screen-blended: the warm sun by day, a cool moon at night
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    r = np.hypot((xx - w * 0.95) / w, (yy + h * 0.15) / h)
    night = lum.mean() < 0.3
    glow = np.clip(1 - r / 0.85, 0, 1) ** 2 * (0.12 if night else 0.2)
    tint = np.array([0.6, 0.75, 1.0] if night else [1.0, 0.85, 0.55], np.float32)
    a = 1 - (1 - a) * (1 - glow[..., None] * tint)
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
    # chunky cartoon capitals (Luckiest Guy), sunny yellow to orange with a thick dark outline, like the HUD
    big = ImageFont.truetype(font_path, 150)
    bottom = outlined_text(img, TITLE, big, 960, 40, (255, 238, 110), (255, 140, 30), (34, 20, 30), 12)
    if caption:
        small = ImageFont.truetype(font_path, 72)
        outlined_text(img, caption, small, 960, bottom + 26, (255, 255, 255), (232, 236, 255), (34, 20, 30), 8)
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
