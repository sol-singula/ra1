#!/usr/bin/env python3
"""Create every game pass and developer product in src/shared/Data/Shop.lua on Roblox, then write their IDs
back into Shop.lua.

Uses Roblox Open Cloud (beta endpoints). Needs:
  ROBLOX_API_KEY      an Open Cloud API key with game-pass:read/write and developer-product:read/write for the
                      experience (Creator Dashboard -> Open Cloud -> API Keys)
  ROBLOX_UNIVERSE_ID  the experience's Universe ID (Creator Dashboard -> the experience's ... menu -> Copy Universe ID)

Safe to run again: items whose ID is already set in Shop.lua, or that already exist on Roblox with the same name,
are not created twice. Pass icons come from other/ra2/icon/passes/<KEY>.png when present.

  python3 tools/setup_shop.py --dry-run    # show what would happen
  python3 tools/setup_shop.py              # create and write the IDs
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
SHOP = os.path.join(GAME, "src", "shared", "Data", "Shop.lua")
ICONS = os.path.join(GAME, "..", "..", "other", "ra2", "icon", "passes")
API = "https://apis.roblox.com"

ITEM = re.compile(
    r'\{\s*key = "(?P<key>\w+)",\s*name = "(?P<name>[^"]+)",\s*text = "(?P<text>[^"]+)",\s*'
    r"price = (?P<price>\d+),\s*id = (?P<id>\d+),"
)


def read_items(source):
    """Passes and products from Shop.lua, in file order: (kind, key, name, text, price, id)."""
    split = source.index("Shop.Products")
    items = []
    for m in ITEM.finditer(source):
        kind = "pass" if m.start() < split else "product"
        items.append((kind, m["key"], m["name"], m["text"], int(m["price"]), int(m["id"])))
    return items


def multipart(fields, file_field=None, file_path=None):
    boundary = uuid.uuid4().hex
    out = bytearray()
    for k, v in fields.items():
        out += f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
    if file_path:
        with open(file_path, "rb") as f:
            data = f.read()
        name = os.path.basename(file_path)
        out += (
            f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; filename="{name}"\r\n'
            f"Content-Type: image/png\r\n\r\n"
        ).encode()
        out += data + b"\r\n"
    out += f"--{boundary}--\r\n".encode()
    return bytes(out), f"multipart/form-data; boundary={boundary}"


def call(method, path, key, body=None, content_type=None):
    req = urllib.request.Request(API + path, data=body, method=method)
    req.add_header("x-api-key", key)
    if content_type:
        req.add_header("Content-Type", content_type)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        raise SystemExit(f"{method} {path} failed: HTTP {e.code} {e.read().decode(errors='replace')[:500]}")


def existing(kind, universe, key):
    """Name -> id of what already exists on Roblox (both list endpoints are paged)."""
    path = (
        f"/game-passes/v1/universes/{universe}/game-passes/creator"
        if kind == "pass"
        else f"/developer-products/v2/universes/{universe}/developer-products/creator"
    )
    id_field = "gamePassId" if kind == "pass" else "productId"
    found, token = {}, None
    while True:
        page = call("GET", path + (f"?pageToken={token}" if token else ""), key)
        for v in page.values():
            if isinstance(v, list):
                for entry in v:
                    if isinstance(entry, dict) and "name" in entry and id_field in entry:
                        found[entry["name"]] = entry[id_field]
        token = page.get("nextPageToken")
        if not token:
            return found


def write_id(source, item_key, new_id):
    pattern = re.compile(r'(key = "' + item_key + r'",[^{}]*?id = )0,', re.S)
    updated, n = pattern.subn(rf"\g<1>{new_id},", source, count=1)
    if n != 1:
        raise SystemExit(f"could not write the ID for {item_key} into Shop.lua")
    return updated


def main():
    dry = "--dry-run" in sys.argv
    key = os.environ.get("ROBLOX_API_KEY")
    universe = os.environ.get("ROBLOX_UNIVERSE_ID")
    if not dry and (not key or not universe):
        raise SystemExit("Set ROBLOX_API_KEY and ROBLOX_UNIVERSE_ID first (see the top of this file).")
    source = open(SHOP, encoding="utf-8").read()
    items = read_items(source)
    print(f"{len(items)} items in Shop.lua")
    have = {} if dry else {"pass": existing("pass", universe, key), "product": existing("product", universe, key)}
    for kind, item_key, name, text, price, old_id in items:
        if old_id:
            print(f"  {item_key}: already set ({old_id})")
            continue
        if name in have.get(kind, {}):
            new_id = have[kind][name]
            print(f"  {item_key}: found on Roblox ({new_id})")
        else:
            icon = os.path.join(ICONS, item_key + ".png")
            icon = icon if kind == "pass" and os.path.exists(icon) else None
            if dry:
                print(f"  {item_key}: would create {kind} '{name}' for R$ {price}" + (" with icon" if icon else ""))
                continue
            fields = {
                "name": name,
                "description": text,
                "price": str(price),
                "isForSale": "true",
                "isRegionalPricingEnabled": "false",
            }
            body, ctype = multipart(fields, "imageFile", icon)
            path = (
                f"/game-passes/v1/universes/{universe}/game-passes"
                if kind == "pass"
                else f"/developer-products/v2/universes/{universe}/developer-products"
            )
            result = call("POST", path, key, body, ctype)
            new_id = result.get("gamePassId") if kind == "pass" else result.get("productId")
            if not new_id:
                raise SystemExit(f"{item_key}: no ID in the response: {result}")
            print(f"  {item_key}: created {kind} {new_id}")
            time.sleep(0.4)  # stay under the rate limits (3-5 writes per second)
        source = write_id(source, item_key, new_id)
        open(SHOP, "w", encoding="utf-8").write(source)  # save after each item, so a failure loses nothing
    print("done" if not dry else "dry run: nothing created")


if __name__ == "__main__":
    main()
