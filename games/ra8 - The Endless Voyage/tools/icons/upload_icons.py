#!/usr/bin/env python3
"""Upload the item icons (other/ra8/items/<key>.png) to Roblox with the Open Cloud Assets API and write their asset
ids into src/shared/Data/IconIds.lua, so the game's UI shows the 2D art instead of the 3D model pictures.

  ROBLOX_API_KEY=... python3 tools/icons/upload_icons.py <iconDir> --user <userId>
  ROBLOX_API_KEY=... python3 tools/icons/upload_icons.py <iconDir> --group <groupId>
  options: --out src/shared/Data/IconIds.lua   --only wood,rope   --dry-run

The key comes from https://create.roblox.com/dashboard/credentials with the "Assets" API system (Read and Write)
and your IP allowed. The icons are moderated after upload; they show in the game once approved (usually minutes).
Re-running only uploads icons that have no id yet (edit IconIds.lua to force one). Needs the requests package.
"""
import json
import os
import re
import sys
import time

try:
    import requests
except ImportError:  # pragma: no cover
    sys.exit("pip install requests")

API = "https://apis.roblox.com/assets/v1"


def read_ids(path):
    ids = {}
    if os.path.exists(path):
        for key, value in re.findall(r"(\w+)\s*=\s*(\d+)", open(path).read()):
            ids[key] = int(value)
    return ids


def write_ids(path, ids):
    lines = ["-- Uploaded 2D icons by item key (Roblox image asset ids), written by tools/icons/upload_icons.py.",
             "-- Items missing here show their 3D model (client/UI/Icons + World/ItemModels)."]
    lines.append("return {")
    for key in sorted(ids):
        lines.append(f"\t{key} = {ids[key]},")
    lines.append("}")
    open(path, "w").write("\n".join(lines) + "\n")


def upload(session, api_key, creator, path, name):
    request = {
        "assetType": "Image",
        "displayName": name,
        "description": "Build the Biggest Raft item icon",
        "creationContext": {"creator": creator},
    }
    with open(path, "rb") as f:
        r = session.post(
            f"{API}/assets",
            headers={"x-api-key": api_key},
            files={"request": (None, json.dumps(request), "application/json"), "fileContent": (os.path.basename(path), f, "image/png")},
            timeout=60,
        )
    r.raise_for_status()
    op = r.json()
    for _ in range(30):
        if op.get("done"):
            break
        time.sleep(2)
        r = session.get(f"{API}/{op['path']}", headers={"x-api-key": api_key}, timeout=30)
        r.raise_for_status()
        op = r.json()
    if not op.get("done"):
        raise RuntimeError(f"timed out waiting for {name}")
    if "error" in op:
        raise RuntimeError(op["error"])
    return int(op["response"]["assetId"])


def main():
    args = sys.argv[1:]
    src = args[0]
    out = args[args.index("--out") + 1] if "--out" in args else "src/shared/Data/IconIds.lua"
    only = set(args[args.index("--only") + 1].split(",")) if "--only" in args else None
    dry = "--dry-run" in args
    if "--user" in args:
        creator = {"userId": args[args.index("--user") + 1]}
    elif "--group" in args:
        creator = {"groupId": args[args.index("--group") + 1]}
    else:
        sys.exit("say whose assets these are: --user <userId> or --group <groupId>")
    api_key = os.environ.get("ROBLOX_API_KEY")
    if not api_key and not dry:
        sys.exit("set ROBLOX_API_KEY (an Open Cloud key with the Assets API, read and write)")
    ids = read_ids(out)
    session = requests.Session()
    for f in sorted(os.listdir(src)):
        if not f.endswith(".png"):
            continue
        key = f[:-4]
        if (only and key not in only) or key in ids:
            continue
        if dry:
            print("would upload", key)
            continue
        try:
            ids[key] = upload(session, api_key, creator, os.path.join(src, f), f"ev_icon_{key}")
            print(key, "->", ids[key])
            write_ids(out, ids)
        except Exception as e:  # keep going: the next run picks up the rest
            print("failed", key, e)
    write_ids(out, ids)
    print(len(ids), "icons in", out)


if __name__ == "__main__":
    main()
