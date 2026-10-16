#!/usr/bin/env python3
"""A contact sheet (the _all.jpg next to the screenshots and the thumbnails): pictures in a grid, and optionally a
row of square icons under them, on a dark background.

  python3 tools/gameplay/contact_sheet.py <out.jpg> [--cols 4] [--width 480] <pictures...> [--icons <icons...>]
Every picture is cut to 16:9 and sized to --width; the icons are sized to the same height as a picture row and
centred on their own row. Needs Pillow.
"""
import sys

from PIL import Image

BG = (22, 24, 32)
GAP = 0


def cut(img, w, h):
    iw, ih = img.size
    if iw / ih > w / h:
        nw = int(ih * w / h)
        img = img.crop(((iw - nw) // 2, 0, (iw - nw) // 2 + nw, ih))
    else:
        nh = int(iw * h / w)
        img = img.crop((0, (ih - nh) // 2, iw, (ih - nh) // 2 + nh))
    return img.resize((w, h), Image.LANCZOS)


def main():
    args = sys.argv[1:]
    out = args.pop(0)

    def opt(name, default):
        if name in args:
            i = args.index(name)
            v = args[i + 1]
            del args[i:i + 2]
            return v
        return default

    cols = int(opt("--cols", 4))
    width = int(opt("--width", 480))
    icons = []
    if "--icons" in args:
        i = args.index("--icons")
        icons, args = args[i + 1:], args[:i]
    pics = args
    height = width * 9 // 16
    rows = (len(pics) + cols - 1) // cols
    icon_size = height
    pad = 20 if icons else 0
    sheet_w = cols * width + (cols - 1) * GAP
    sheet_h = rows * height + (rows - 1) * GAP + ((icon_size + 2 * pad) if icons else 0)
    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    for k, path in enumerate(pics):
        r, c = divmod(k, cols)
        sheet.paste(cut(Image.open(path).convert("RGB"), width, height), (c * (width + GAP), r * (height + GAP)))
    if icons:
        y = rows * height + (rows - 1) * GAP + pad
        total = len(icons) * icon_size + (len(icons) - 1) * pad
        x = (sheet_w - total) // 2
        for path in icons:
            sheet.paste(cut(Image.open(path).convert("RGB"), icon_size, icon_size).resize((icon_size, icon_size)), (x, y))
            x += icon_size + pad
    sheet.save(out, quality=86, optimize=True)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()
