#!/usr/bin/env python3
"""Cut the AI icon sheets (4 x 4 grids on a transparent background, one item a cell, made with Higgsfield / GPT
Image 2.5 from the game's own item renders) into one PNG per item.

  python3 tools/icons/slice_sheets.py <sheetDir> <outDir> --size 320
<sheetDir> holds sheet_<n>.png and sheet_<n>.txt: the grid ("4 4" = columns rows) on the first line, then the item
keys in the sheet, row by row ("-" for an empty cell). Each cell is cropped to what is drawn in it (its alpha),
scaled to fit the output square with a little margin, and written as <outDir>/<key>.png. Needs Pillow and numpy.
"""
import os
import sys

import numpy as np
from PIL import Image


def cells(img, cols, rows):
    w, h = img.size
    cw, ch = w / cols, h / rows
    for row in range(rows):
        for col in range(cols):
            yield img.crop((int(col * cw), int(row * ch), int((col + 1) * cw), int((row + 1) * ch)))


def crop_alpha(cell, pad=6):
    a = np.asarray(cell.convert("RGBA"))[..., 3]
    ys, xs = np.where(a > 24)
    if len(xs) == 0:
        return None
    x0, x1, y0, y1 = max(0, xs.min() - pad), min(a.shape[1], xs.max() + pad + 1), max(0, ys.min() - pad), min(a.shape[0], ys.max() + pad + 1)
    return cell.crop((x0, y0, x1, y1))


def fit(piece, size, margin=0.08):
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * (1 - margin * 2))
    w, h = piece.size
    k = min(inner / w, inner / h)
    piece = piece.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)
    out.paste(piece, ((size - piece.width) // 2, (size - piece.height) // 2), piece)
    return out


def main():
    src, out = sys.argv[1], sys.argv[2]
    size = int(sys.argv[sys.argv.index("--size") + 1]) if "--size" in sys.argv else 320
    os.makedirs(out, exist_ok=True)
    done = 0
    for f in sorted(os.listdir(src)):
        if not (f.startswith("sheet_") and f.endswith(".png")):
            continue
        words = open(os.path.join(src, f[:-4] + ".txt")).read().split()
        cols, rows, keys = int(words[0]), int(words[1]), words[2:]
        img = Image.open(os.path.join(src, f)).convert("RGBA")
        for key, cell in zip(keys, cells(img, cols, rows)):
            if key == "-":
                continue
            piece = crop_alpha(cell)
            if piece is None:
                print("empty cell for", key, "in", f)
                continue
            fit(piece, size).save(os.path.join(out, key + ".png"))
            done += 1
    print("wrote", done, "icons to", out)


if __name__ == "__main__":
    main()
