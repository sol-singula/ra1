#!/usr/bin/env python3
"""Downloads the free (CC0) PBR texture sets the render tools use to stand in for Roblox's built-in materials,
from ambientCG, and turns each into three 512 px maps in <outDir>:

  <Material>_color.jpg   the detail, as a neutral grey (Roblox tints a material's texture by the part's Color, or
                         by Terrain:SetMaterialColor, so the colour comes from the game and only the detail from here)
  <Material>_normal.jpg  the normal map (OpenGL convention, as three.js expects)
  <Material>_rough.jpg   the roughness map

  python3 tools/gameplay/fetch_textures.py <outDir> [--keep-zips <dir>]

Only the dev renderer uses these; the game itself uses Roblox's own materials. Needs Pillow and numpy.
"""
import io
import os
import sys
import time
import urllib.request
import zipfile

import numpy as np
from PIL import Image

# Roblox material -> ambientCG asset id (picked to look like Roblox's 2022+ material set)
SETS = {
    "Grass": "Grass004",
    "LeafyGrass": "Grass008",
    "Ground": "Ground037",
    "Mud": "Ground068",
    "Sand": "Ground054",
    "Rock": "Rock030",
    "Slate": "Rock022",
    "Basalt": "Rock058",
    "Sandstone": "Rock061",
    "Limestone": "Rock051",
    "Granite": "Rock060",
    "Snow": "Snow006",
    "Glacier": "Ice002",
    "Cobblestone": "PavingStones070",
    "Pebble": "Gravel023",
    "Pavement": "PavingStones128",
    "Brick": "Bricks085",
    "WoodPlanks": "WoodFloor041",
    "Wood": "Wood051",
    "Fabric": "Fabric030",
    "Metal": "Metal032",
    "CorrodedMetal": "Metal049A",
    "Leather": "Leather026",
    "ClayRoofTiles": "RoofingTiles014A",
    "RoofShingles": "RoofingTiles006",
    "Plaster": "Plaster001",
    "Concrete": "Concrete034",
    "Marble": "Marble012",
    "CrackedLava": "Lava004",
    "Carpet": "Carpet016",
}
SIZE = 512


def neutral(img):
    # keep the light and dark detail, drop the hue: mean brightness ~0.86 so a part's colour shows true
    a = np.asarray(img.convert("RGB")).astype(np.float32) / 255.0
    lum = a @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    lum = lum / max(1e-3, float(lum.mean())) * 0.86
    lum = 0.86 + (lum - 0.86) * 0.85  # a touch softer than the photo
    out = np.clip(lum, 0, 1)
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "L").convert("RGB")


def main():
    out = sys.argv[1]
    keep = sys.argv[sys.argv.index("--keep-zips") + 1] if "--keep-zips" in sys.argv else None
    os.makedirs(out, exist_ok=True)
    for material, asset in SETS.items():
        if all(os.path.exists(os.path.join(out, f"{material}_{k}.jpg")) for k in ("color", "normal", "rough")):
            continue
        url = f"https://ambientcg.com/get?file={asset}_1K-JPG.zip"
        data = None
        if keep and os.path.exists(os.path.join(keep, f"{asset}.zip")):
            data = open(os.path.join(keep, f"{asset}.zip"), "rb").read()
        if data is None:
            req = urllib.request.Request(url, headers={"User-Agent": "ra7-render-tools"})
            for attempt in range(5):
                try:
                    data = urllib.request.urlopen(req, timeout=120).read()
                    break
                except OSError as e:  # the connection dropped: wait and try again
                    print("retry", material, asset, e)
                    time.sleep(2 ** (attempt + 1))
            if data is None:
                print("skip", material, asset, "(download failed)")
                continue
            if keep:
                os.makedirs(keep, exist_ok=True)
                open(os.path.join(keep, f"{asset}.zip"), "wb").write(data)
        z = zipfile.ZipFile(io.BytesIO(data))
        names = z.namelist()

        def pick(suffix):
            for n in names:
                if n.endswith(suffix):
                    return Image.open(io.BytesIO(z.read(n)))
            return None

        color = pick("_Color.jpg")
        normal = pick("_NormalGL.jpg")
        rough = pick("_Roughness.jpg")
        if color is None:
            print("skip", material, asset, "(no colour map)")
            continue
        neutral(color).resize((SIZE, SIZE), Image.LANCZOS).save(os.path.join(out, f"{material}_color.jpg"), quality=90)
        if normal is not None:
            normal.convert("RGB").resize((SIZE, SIZE), Image.LANCZOS).save(
                os.path.join(out, f"{material}_normal.jpg"), quality=92
            )
        if rough is not None:
            rough.convert("L").resize((SIZE, SIZE), Image.LANCZOS).convert("RGB").save(
                os.path.join(out, f"{material}_rough.jpg"), quality=90
            )
        print("ok", material, asset)


if __name__ == "__main__":
    main()
