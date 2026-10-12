#!/usr/bin/env python3
"""Writes src/shared/Data/FancyDragons.lua: 200 custom dragons in 40 themes of 5.

Each theme has a look (palettes, body and wing materials, wing and horn styles, extra parts, effects) and five
names. Rarer dragons in a theme get more on top: glowing eyes (Epic), an aura and big wings (Legend), and
spinning orbs or a halo (Secret). DragonBuilder turns these fields into parts and effects.

  python3 tools/gen_dragons.py        (from the game folder)
"""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "src", "shared", "Data", "FancyDragons.lua")

# rarity patterns for the five dragons of a theme
TIERS = {
    1: ["Rare", "Rare", "Rare", "Epic", "Epic"],
    2: ["Rare", "Rare", "Epic", "Epic", "Legend"],
    3: ["Rare", "Epic", "Epic", "Legend", "Legend"],
    4: ["Epic", "Legend", "Secret", "Secret", "Secret"],
}
# coins per second range for each rarity (the regular dragons: Rare 8-18, Epic 40-70, Legend 250-500,
# Secret 2000-3000), and price = cps x this
CPS = {"Rare": (16, 30), "Epic": (80, 160), "Legend": (600, 1200), "Secret": (4000, 9000)}
PRICE_PER_CPS = {"Rare": 50, "Epic": 80, "Legend": 130, "Secret": 200}

# key, tier, names, palettes [(body, belly, wing, accent)], body material, wing material, wings, horns,
# extras, effects, options (eyes = glow colour for Epic+, top = extra for Legend+, rainbow, alpha, accentMat)
THEMES = [
    # tier 1: cute and nature
    ("candy", 1, ["Gumdrop", "Taffy", "Lollipop", "Bonbon", "Sugarstorm"],
     [("ff8fc8", "fff0f8", "8fe8d0", "fff27a"), ("a7f0ff", "ffffff", "ff9ad5", "ff5fa8"),
      ("ffd36e", "fff6d6", "ff7aa8", "7fd6ff"), ("c79bff", "f5ecff", "7ff0c0", "ff8fc8"),
      ("ff6b9e", "ffe0ec", "ffe066", "8ff7ff")],
     "SmoothPlastic", "SmoothPlastic", "butterfly", "normal", ["spots"], ["stars"], {"eyes": "ff5fa8"}),
    ("bloom", 1, ["Petal", "Blossom", "Tulip", "Orchid", "Bloomqueen"],
     [("ffb3d1", "fff0f5", "8fd17a", "ffe14d"), ("ffd6e8", "ffffff", "ff7eb6", "ffd24d"),
      ("ff6f8f", "ffe4ea", "6fc46a", "fff07a"), ("d79bff", "f7ebff", "79c96b", "ffffff"),
      ("ff9fd8", "fff2fa", "ffcf5a", "ff4f9a")],
     "SmoothPlastic", "Fabric", "butterfly", "none", ["mane", "leaves"], ["petals"], {"eyes": "ff7eb6"}),
    ("mushroom", 1, ["Toadstool", "Sporeling", "Truffle", "Morel", "Glowcap"],
     [("e8433c", "fff4e6", "f5efe0", "ffffff"), ("b07a4f", "f3e3cc", "8c5b36", "ffe9b8"),
      ("6e4a3a", "d9c2a7", "a58467", "f0d9b5"), ("c9a26b", "fff1d6", "8f6b3f", "ffd27f"),
      ("3d4a9e", "c6f7ff", "2b336e", "6dfff0")],
     "SmoothPlastic", "SmoothPlastic", "normal", "none", ["spots"], ["glow"], {"eyes": "6dfff0", "accentMat": "Neon"}),
    ("bee", 1, ["Buzz", "Honeycomb", "Nectar", "Pollen", "Hivemind"],
     [("ffcc1f", "fff2b0", "e8f6ff", "2a2a33"), ("ffb31a", "ffe9a8", "f0faff", "33302a"),
      ("ffd84d", "fff7cc", "dff3ff", "1f1f26"), ("ffc233", "fff0bf", "ffffff", "3a2f1f"),
      ("ffaa00", "fff0a0", "e0fbff", "141418")],
     "SmoothPlastic", "Glass", "butterfly", "none", ["stripes", "antenna"], ["sparkles"], {"eyes": "ffcc1f", "alphaWing": 0.35}),
    ("rock", 1, ["Boulder", "Gravel", "Flint", "Quartzback", "Rockslide"],
     [("8a8580", "b8b2aa", "5e5a55", "d9d2c5"), ("6f6a66", "a39d96", "4f4b47", "ffb347"),
      ("9c9387", "c9c0b3", "6b645b", "ffffff"), ("7d7a86", "c5c2cf", "55525e", "e8d9ff"),
      ("5c5853", "8f8a84", "3d3a36", "ff8a3d")],
     "Slate", "Slate", "bat", "big", ["spikes_big"], ["smoke"], {"eyes": "ffb347"}),
    ("seafoam", 1, ["Fizz", "Seafoam", "Splash", "Ripple", "Tidepool"],
     [("7fe0e6", "e6ffff", "4fb8d9", "ffffff"), ("5fd1c9", "dcfffb", "3aa1b8", "b8f4ff"),
      ("9fe8ff", "f0fdff", "6bc3f0", "ffffff"), ("4fc3d9", "d6f8ff", "2f8fb8", "aef0ff"),
      ("3ab0e0", "c8f2ff", "1e7fb3", "e0fbff")],
     "Glass", "Glass", "normal", "normal", ["fins"], ["bubbles"], {"eyes": "aef0ff"}),
    ("fruit", 1, ["Kiwi", "Mango", "Berrybite", "Dragonfruit", "Melonquake"],
     [("7fbf3f", "d8f0a0", "5c3d1f", "2b1d10"), ("ffb02e", "ffe3a0", "ff7a2e", "6fbf3f"),
      ("6a3fb8", "d8c2ff", "3f2b80", "8fe06a"), ("ff4f9a", "ffffff", "8fd14f", "1f1f1f"),
      ("4fbf5f", "ff6b6b", "2f8f3f", "1f1f1f")],
     "SmoothPlastic", "SmoothPlastic", "normal", "normal", ["spots", "leaves"], ["sparkles"], {"eyes": "8fe06a"}),
    ("cloud", 1, ["Puffcloud", "Nimbus", "Drizzle", "Cumulus", "Daydream"],
     [("f5f8ff", "ffffff", "dce6ff", "9fd0ff"), ("e8eefc", "ffffff", "c9d6f5", "b8a8ff"),
      ("cfd8e8", "f0f4fa", "a9b5c9", "7fb8ff"), ("ffffff", "fff6e8", "e6eeff", "ffd6a8"),
      ("eae4ff", "ffffff", "cfc4ff", "ffb8e0")],
     "Fabric", "Fabric", "feather", "none", ["mane"], ["smoke"], {"eyes": "9fd0ff"}),
    # tier 2
    ("inferno", 2, ["Cinder", "Scorch", "Magmaw", "Pyroclast", "Infernox"],
     [("3a1f1a", "ff8a1f", "c22a12", "ff6a00"), ("2b1a17", "ffb03a", "e0401a", "ffd000"),
      ("4a201a", "ff6a1f", "a3200f", "ff3c00"), ("1f1414", "ffc04d", "ff5a1f", "ff8a00"),
      ("170f0f", "ffe066", "ff2a00", "ffb000")],
     "CrackedLava", "Neon", "bat", "big", ["tailflame", "spikes_big"], ["embers", "fire"], {"eyes": "ffd000", "top": "backflame"}),
    ("glacier", 2, ["Sleet", "Icicle", "Permafrost", "Glacius", "Frostfang"],
     [("bfe9ff", "ffffff", "7fd0ff", "e0faff"), ("a8dcff", "f2fbff", "5fb8f0", "ffffff"),
      ("d6f3ff", "ffffff", "9fdcff", "b8f0ff"), ("8fcaf5", "e8f8ff", "4f9fe0", "e8fdff"),
      ("e6f8ff", "ffffff", "8fd8ff", "7ff0ff")],
     "Ice", "Glass", "crystal", "big", ["icicles"], ["snow"], {"eyes": "7ff0ff", "top": "crown"}),
    ("thunder", 2, ["Static", "Volt", "Thunderclap", "Stormcaller", "Voltwing"],
     [("3a3f8f", "c9d0ff", "1f2466", "ffe14d"), ("2b2f66", "aab4ff", "171a4d", "8ff7ff"),
      ("4a4fa8", "d8dcff", "2a2e80", "fff27a"), ("23264f", "9fa8ff", "121433", "ffe14d"),
      ("1a1c3a", "8f9aff", "0d0e24", "aef6ff")],
     "SmoothPlastic", "SmoothPlastic", "bat", "normal", ["stripes"], ["lightning"], {"eyes": "fff27a", "accentMat": "Neon", "top": "orbs"}),
    ("jungle", 2, ["Vine", "Canopy", "Mossback", "Thornjaw", "Junglord"],
     [("3f8f3a", "b8e08f", "2a6b2a", "ff5f5f"), ("4fa34a", "cdeca0", "2f7a2f", "ffd23f"),
      ("2f6f3a", "a8d08a", "1f4f2a", "ff8f3f"), ("5c8f2a", "d0e8a0", "3f6b1f", "c94fff"),
      ("1f5f2f", "9fd08f", "0f3f1f", "ffe14d")],
     "Grass", "Grass", "normal", "antlers", ["leaves", "mane"], ["petals"], {"eyes": "ffe14d", "top": "crown"}),
    ("desert", 2, ["Dune", "Mirage", "Scarab", "Sandstorm", "Pharaoh"],
     [("e0c08a", "fff0cf", "c9a066", "3fa8d9"), ("d9b37a", "fbe8c2", "b88f55", "2f8fbf"),
      ("c9a36b", "f3dfb5", "a8804a", "1f9f8f"), ("e8c890", "fff5dc", "cfa86f", "ffcf3f"),
      ("f0d090", "fff8e0", "d4af37", "1f5fbf")],
     "Sand", "Sand", "normal", "normal", ["mask"], ["smoke"], {"eyes": "3fe0ff", "top": "crown"}),
    ("abyss", 2, ["Brine", "Kelp", "Riptide", "Abyssal", "Leviathan"],
     [("1f4f6f", "8fd0e0", "143a54", "4fffe0"), ("2a5f4f", "a0e0c8", "1a4a3a", "7fff9f"),
      ("1a3f66", "80c0e8", "0f2a4a", "5fd0ff"), ("10304f", "6fb0d8", "0a1f3a", "3fffd0"),
      ("0a1f3a", "5fa0d0", "06142a", "6ff0ff")],
     "SmoothPlastic", "Glass", "normal", "none", ["fins"], ["bubbles"], {"eyes": "4fffe0", "accentMat": "Neon", "top": "orbs"}),
    ("pirate", 2, ["Doubloon", "Cutlass", "Jolly", "Plunder", "Captain Goldtooth"],
     [("6b4a2f", "e8d0a8", "2a2a33", "ffd23f"), ("8f2a2a", "f0d8b8", "1f1f26", "ffcc33"),
      ("2f4a6b", "e0d0b0", "1a1a22", "ffd23f"), ("4a3a2a", "d8c098", "2a1f1a", "ffe066"),
      ("1f1f26", "f0e0c0", "8f1f1f", "ffd700")],
     "WoodPlanks", "Fabric", "bat", "normal", ["beard"], ["coins"], {"eyes": "ffd23f", "top": "crown"}),
    ("knight", 2, ["Squire", "Shieldscale", "Lancer", "Paladin", "Lionheart"],
     [("8f96a3", "dfe3ea", "2f4f9f", "ffd23f"), ("a3a8b3", "eef0f4", "9f2f2f", "ffcf3f"),
      ("7a808c", "d0d4dc", "2f7f4f", "ffe066"), ("b8bcc6", "f4f6f9", "5f2f9f", "ffd700"),
      ("c8ccd4", "ffffff", "c9a227", "ffd700")],
     "Metal", "Fabric", "normal", "big", ["armor"], ["sparkles"], {"eyes": "8fd0ff", "top": "crown"}),
    ("robot", 2, ["Gizmo", "Circuit", "Byte", "Mecha", "Overclock"],
     [("9aa3b0", "d8dde5", "4f5866", "3fd0ff"), ("6f7a8a", "c0c8d4", "3a4250", "7fff6f"),
      ("b0b8c4", "e8ecf2", "5f6876", "ff4f8f"), ("4f5866", "a8b0bc", "2a3038", "ffcf3f"),
      ("3a4250", "9098a6", "1f242c", "3fffe0")],
     "DiamondPlate", "Metal", "crystal", "none", ["stripes", "antenna"], ["sparkles"], {"eyes": "3fd0ff", "accentMat": "Neon", "top": "orbs"}),
    ("ghost", 2, ["Wisp", "Boo", "Phantom", "Specter", "Banshee"],
     [("e8f0ff", "ffffff", "c8d8ff", "8ff7ff"), ("d8e8ff", "ffffff", "b0c8f0", "b88fff"),
      ("f0f0ff", "ffffff", "d0d0f0", "7fffcf"), ("c8d8f0", "eef4ff", "a0b4d8", "ff8fd0"),
      ("b8c8e8", "e8f0ff", "8fa0c8", "8fd0ff")],
     "ForceField", "ForceField", "bat", "none", ["mask"], ["smoke"], {"eyes": "8ff7ff", "alpha": 0.35, "top": "halo"}),
    ("pumpkin", 2, ["Gourd", "Jack", "Hexer", "Cauldron", "Pumpking"],
     [("ff8a1f", "ffd08a", "3f8f2a", "fff04d"), ("e06a12", "ffc070", "2f6f1f", "7fff4f"),
      ("ff9f3f", "ffe0a8", "4a2a6b", "b84fff"), ("c9550f", "f0b060", "1f1f26", "7fff4f"),
      ("ff7a00", "ffcf70", "2a1a3a", "fff04d")],
     "SmoothPlastic", "SmoothPlastic", "bat", "normal", ["leaves"], ["embers"], {"eyes": "fff04d", "top": "crown"}),
    ("jingle", 2, ["Jingle", "Snowglobe", "Tinsel", "Peppermint", "Yulewyrm"],
     [("e8f4ff", "ffffff", "cf2f2f", "2f9f4f"), ("cf2f2f", "ffffff", "2f8f4f", "ffd23f"),
      ("2f8f4f", "f0fff0", "cf2f2f", "ffffff"), ("ffffff", "ffe8e8", "e03030", "e03030"),
      ("2a6b4a", "ffffff", "ffd23f", "ff3f3f")],
     "SmoothPlastic", "Fabric", "feather", "antlers", ["stripes"], ["snow"], {"eyes": "ffd23f", "top": "crown"}),
    ("music", 2, ["Melody", "Bassline", "Drumroll", "Rockstar", "Encore"],
     [("2a2a3a", "ff4fd0", "1a1a26", "4ff0ff"), ("3a1f5f", "ffcf3f", "26143f", "ff4f8f"),
      ("1f3a5f", "4fffb0", "14263f", "ffe14d"), ("1a1a1a", "ff3f3f", "0f0f0f", "ffd23f"),
      ("26143f", "4ff0ff", "1a0d2a", "ff4fd0")],
     "SmoothPlastic", "SmoothPlastic", "bat", "normal", ["stripes"], ["stars"], {"eyes": "4ff0ff", "accentMat": "Neon", "top": "orbs", "pulse": True}),
    ("speed", 2, ["Turbo", "Nitro", "Racer", "Slipstream", "Hyperdash"],
     [("e02a2a", "ffffff", "1f1f26", "ffd23f"), ("1f6fe0", "ffffff", "14141a", "4ff0ff"),
      ("ffcf1f", "1f1f1f", "1f1f26", "ff4f1f"), ("2fbf4f", "ffffff", "14141a", "e0ff3f"),
      ("8f2fe0", "ffffff", "14141a", "ff4fd0")],
     "SmoothPlastic", "Metal", "normal", "none", ["stripes", "fins"], ["trail"], {"eyes": "4ff0ff", "accentMat": "Neon", "top": "backflame"}),
    # tier 3
    ("gem", 3, ["Amethyst", "Sapphire", "Emerald", "Ruby Rex", "Diamondheart"],
     [("9f5fe0", "e8d0ff", "7a3fc0", "e0b8ff"), ("2f5fe0", "c8d8ff", "1f3fb0", "8fd0ff"),
      ("1fbf6f", "c0ffe0", "0f8f4f", "8fffc8"), ("e0203f", "ffc8d0", "b01030", "ff8fa0"),
      ("e8fbff", "ffffff", "bfeeff", "ffffff")],
     "Glass", "Glass", "crystal", "unicorn", ["gem"], ["sparkles", "glow"], {"eyes": "ffffff", "accentMat": "Neon", "top": "crown"}),
    ("solar", 3, ["Sunny", "Solstice", "Corona", "Helios", "Sunforge"],
     [("ffcf3f", "fff4c0", "ff8f1f", "fff27a"), ("ffb81f", "ffeaa0", "ff6a1f", "ffe14d"),
      ("ffdf5f", "fffad8", "ffa01f", "ffffff"), ("ffa500", "ffe8a0", "ff4f00", "fff27a"),
      ("ffe14d", "ffffff", "ff8f00", "fffbe0")],
     "Foil", "Neon", "feather", "big", ["mane"], ["fire", "glow"], {"eyes": "ffffff", "accentMat": "Neon", "top": "halo"}),
    ("lunar", 3, ["Crescent", "Moonbeam", "Eclipse", "Nocturne", "Lunaris"],
     [("2a3a6b", "c8d0f0", "1a2450", "e8f0ff"), ("1f2a50", "b0bce0", "141c3a", "ffffff"),
      ("14141f", "8f8fb0", "0a0a14", "ffd23f"), ("26304f", "a8b4d8", "161c33", "c8e0ff"),
      ("0f1430", "9fb0e8", "080a1f", "e8f4ff")],
     "SmoothPlastic", "Glass", "bat", "big", ["gem"], ["stars"], {"eyes": "e8f0ff", "accentMat": "Neon", "top": "halo"}),
    ("ninja", 3, ["Kunai", "Shadowstep", "Ronin", "Shogun", "Katana Storm"],
     [("26262f", "5f5f6b", "14141a", "e02a2a"), ("1f2a3a", "4f5a6b", "0f141f", "4fd0ff"),
      ("2f1f2f", "5f4f5f", "1a0f1a", "ff4fd0"), ("1a1a1f", "4a4a55", "0a0a0f", "ffd23f"),
      ("0f0f14", "3a3a44", "050508", "ff2a2a")],
     "SmoothPlastic", "Fabric", "bat", "none", ["mask", "armor"], ["smoke"], {"eyes": "ff4f4f", "top": "backflame"}),
    ("viking", 3, ["Runestone", "Frostaxe", "Berserker", "Valkyrie", "Thunderjarl"],
     [("8f6b4a", "e0c8a8", "5f6b7a", "ffd23f"), ("6b7a8f", "d0d8e0", "4a3a2a", "8fd0ff"),
      ("a3502f", "f0c8a0", "4a3a2a", "ffcf3f"), ("c8d0dc", "ffffff", "8f6b4a", "ffd700"),
      ("4a5566", "c0c8d4", "2a2f38", "fff27a")],
     "SmoothPlastic", "Fabric", "feather", "big", ["beard", "armor"], ["lightning"], {"eyes": "8fd0ff", "top": "crown"}),
    ("steam", 3, ["Cog", "Brass", "Piston", "Clockwork", "Chronodrake"],
     [("b8863b", "f0d8a0", "6b4a2a", "ffcf3f"), ("a0703a", "e8c890", "5a3a1f", "e0a03f"),
      ("8f5f2f", "d8b080", "4a2f1a", "ffd23f"), ("c89650", "f8e0b0", "7a5530", "8fd0ff"),
      ("d4a050", "fff0c8", "8a6030", "ffe066")],
     "Foil", "Metal", "bat", "antlers", ["armor", "antenna"], ["smoke"], {"eyes": "ffcf3f", "top": "ring"}),
    ("toxic", 3, ["Sludge", "Venom", "Acidic", "Toxitail", "Plaguewing"],
     [("4fbf2f", "d0ff8f", "2f7f1f", "b0ff3f"), ("7a2fbf", "d0a0ff", "4f1f7f", "8fff3f"),
      ("2f8f2f", "b0f08f", "1f5f1f", "dfff3f"), ("5f3f1f", "c0e08f", "3a2a14", "8fff3f"),
      ("1f1f14", "8fff3f", "0f0f0a", "c8ff3f")],
     "SmoothPlastic", "Neon", "bat", "big", ["spots"], ["bubbles"], {"eyes": "b0ff3f", "accentMat": "Neon", "top": "backflame"}),
    ("royal", 3, ["Prince", "Duchess", "Monarch", "Empress", "High King"],
     [("6b2fbf", "f0d8ff", "c9a227", "ffd700"), ("2f3fbf", "d8e0ff", "c9a227", "ffd700"),
      ("bf2f5f", "ffd8e8", "c9a227", "ffd700"), ("8f1f8f", "ffd0ff", "ffd700", "ffffff"),
      ("4a1f8f", "e8d0ff", "ffd700", "ffffff")],
     "SmoothPlastic", "Foil", "feather", "normal", ["crown", "mane"], ["sparkles"], {"eyes": "ffd700", "top": "halo"}),
    ("dino", 3, ["Raptor", "Fossil", "Trike", "Spinosaur", "Tyrant King"],
     [("6f8f3a", "d8e0a0", "4a6b2a", "ff8f3f"), ("d8ccb0", "f8f0e0", "a89c80", "ffffff"),
      ("3f7f8f", "b0e0e0", "2a5f6b", "ffcf3f"), ("8f4f2f", "e8c0a0", "5f2f1f", "ff6a3f"),
      ("5f6b2a", "d0d8a0", "3a4a1a", "ffd23f")],
     "Pebble", "SmoothPlastic", "bat", "big", ["fins", "tusks"], ["smoke"], {"eyes": "ffcf3f", "top": "crown"}),
    ("aurora", 3, ["Glimmer", "Borealis", "Prism", "Aurora", "Spectrum"],
     [("4fe0c0", "e0fff8", "8f6fff", "ff8fd0"), ("6f8fff", "e0e8ff", "4fffb0", "fff27a"),
      ("ff8fd0", "fff0f8", "4fd0ff", "8fff8f"), ("4f6fff", "d8e0ff", "ff6fd0", "6fffd0"),
      ("ffffff", "f0f8ff", "a0f0ff", "ff8fff")],
     "Glass", "Neon", "crystal", "normal", ["stripes"], ["sparkles", "stars"], {"eyes": "ffffff", "accentMat": "Neon", "top": "halo", "rainbow": "Legend"}),
    # tier 4: cosmic and mythic
    ("cosmic", 4, ["Nebula", "Supernova", "Quasar", "Pulsar", "Cosmo Prime"],
     [("2a1f5f", "8f6fff", "14103a", "ff8fff"), ("3a1f4f", "ff6fd0", "1f0f2a", "fff27a"),
      ("0f1f4f", "4fd0ff", "080f2a", "ffffff"), ("1f0f3a", "b04fff", "0f0820", "4ff0ff"),
      ("0a0a24", "6f8fff", "05051a", "ffd23f")],
     "Neon", "Neon", "crystal", "unicorn", ["ring"], ["stars", "glow"], {"eyes": "ffffff", "accentMat": "Neon", "top": "orbs", "pulse": True}),
    ("void", 4, ["Umbra", "Voidmaw", "Oblivion", "Eventide", "Nullwing"],
     [("14101f", "4f2f8f", "0a0814", "b04fff"), ("0f0f14", "3a2a6b", "050508", "ff4fd0"),
      ("1a0f26", "5f2fa0", "0a0514", "8f4fff"), ("0a0a0f", "2a1f4f", "000000", "4fd0ff"),
      ("000000", "1f1f3a", "000000", "ff2a6a")],
     "ForceField", "ForceField", "bat", "big", ["spikes_big"], ["void", "smoke"], {"eyes": "b04fff", "accentMat": "Neon", "top": "orbs", "alpha": 0.15}),
    ("phoenix", 4, ["Ashwing", "Firebird", "Rebirth", "Phoenix Prime", "Eternal Flame"],
     [("ff6a1f", "ffe066", "ff2a00", "ffd000"), ("ff4f1f", "fff0a0", "e01a00", "ffffff"),
      ("ff8f1f", "ffe8a0", "ff4f00", "ff2a00"), ("ffcf3f", "ffffff", "ff6a00", "ff2a00"),
      ("ffffff", "fff6c0", "ffb000", "ff6a00")],
     "Neon", "Neon", "feather", "none", ["tailflame", "mane"], ["fire", "embers"], {"eyes": "ffffff", "accentMat": "Neon", "top": "halo"}),
    ("seraph", 4, ["Seraph", "Archon", "Haloheart", "Celestia", "Divinus"],
     [("ffffff", "fff8e0", "f0f4ff", "ffd700"), ("f8f0ff", "ffffff", "e8e0ff", "ffe066"),
      ("fffbe8", "ffffff", "fff0c0", "ffd700"), ("e8f4ff", "ffffff", "d0e8ff", "fff27a"),
      ("ffffff", "ffffff", "ffffff", "ffd700")],
     "Marble", "SmoothPlastic", "feather", "unicorn", ["mane", "gem"], ["sparkles", "glow"], {"eyes": "8fd0ff", "accentMat": "Neon", "top": "halo"}),
    ("molten", 4, ["Brimstone", "Doomfang", "Molten Tyrant", "Ragnarok", "Cataclysm"],
     [("1a0f0a", "ff6a00", "3a0a00", "ff3c00"), ("140a0a", "ffb000", "2a0505", "ffd000"),
      ("0f0505", "ff4f00", "4a0a00", "ff8a00"), ("0a0505", "ff2a00", "1a0000", "ffe066"),
      ("050000", "ff8a00", "2a0000", "ff2a00")],
     "CrackedLava", "CrackedLava", "bat", "big", ["spikes_big", "armor"], ["fire", "embers"], {"eyes": "ffd000", "accentMat": "Neon", "top": "backflame"}),
    ("chrono", 4, ["Tick", "Hourglass", "Paradox", "Timewarp", "Infinity"],
     [("c9a227", "fff0c0", "4a3a8f", "8ff7ff"), ("3a2f6b", "c8c0ff", "c9a227", "ffd700"),
      ("1f3a5f", "a0d0ff", "c9a227", "ffffff"), ("4f1f6b", "e0b8ff", "ffd700", "8ff7ff"),
      ("14143a", "8f8fff", "ffd700", "ffffff")],
     "Foil", "Glass", "crystal", "normal", ["gem", "antenna"], ["stars"], {"eyes": "8ff7ff", "accentMat": "Neon", "top": "ring", "pulse": True}),
    ("glitch", 4, ["Pixel", "Glitch", "Hologram", "Neon Byte", "Error 404"],
     [("1fffb0", "0f3a2a", "ff1fd0", "1fffff"), ("ff1fd0", "3a0f2f", "1fffff", "fff21f"),
      ("1fd0ff", "0f2a3a", "ff1f6a", "1fff6a"), ("b01fff", "2a0f3a", "1fffb0", "ffffff"),
      ("ffffff", "1a1a1a", "ff1f1f", "1fff1f")],
     "Neon", "ForceField", "crystal", "none", ["stripes", "antenna"], ["sparkles"], {"eyes": "ffffff", "accentMat": "Neon", "top": "orbs", "rainbow": "Secret", "alpha": 0.1}),
    ("unicorn", 4, ["Stardust", "Unicorn", "Rainbow Rush", "Prismatic Queen", "Wishmaker"],
     [("fff0fb", "ffffff", "ffb8e8", "8fd0ff"), ("ffffff", "fff8ff", "c8b0ff", "ff8fd0"),
      ("ffd0f0", "ffffff", "8ff0ff", "fff27a"), ("f0e0ff", "ffffff", "ffb0e0", "8fffd0"),
      ("ffffff", "ffffff", "ffd0f8", "ffd700")],
     "SmoothPlastic", "Glass", "butterfly", "unicorn", ["mane"], ["stars", "sparkles"], {"eyes": "ff8fd0", "accentMat": "Neon", "top": "halo", "rainbow": "Secret"}),
]

EXISTING = {"Puff", "Ember", "Pebble", "Bubbles", "Frosty", "Sparky", "Leafy", "Coral", "Blaze", "Storm", "Jelly",
            "King Goldie", "Shadow", "Crystal", "Rainbow Rex", "Galaxy"}


def lua_color(h):
    return f"rgb({int(h[0:2], 16)}, {int(h[2:4], 16)}, {int(h[4:6], 16)})"


def lua_list(xs):
    return "{ " + ", ".join(f'"{x}"' for x in xs) + " }" if xs else "{}"


def main():
    assert len(THEMES) == 40, len(THEMES)
    seen_ids, seen_names = set(), set(EXISTING)
    rows = []
    counters = {}
    for t_index, (key, tier, names, palettes, mat, wing_mat, wings, horns, extras, fx, opt) in enumerate(THEMES):
        assert len(names) == 5 and len(palettes) == 5, key
        for i, (name, rarity) in enumerate(zip(names, TIERS[tier])):
            assert name not in seen_names, name
            seen_names.add(name)
            did = re.sub(r"[^A-Z0-9]", "", name.upper())
            assert did not in seen_ids, did
            seen_ids.add(did)
            n = counters.get(rarity, 0)
            counters[rarity] = n + 1
            lo, hi = CPS[rarity]
            # spread cps over the rarity's range, a little higher for later dragons in a theme
            frac = ((t_index * 37 + i * 11) % 100) / 100 * 0.7 + i * 0.075
            cps = round(lo + (hi - lo) * min(frac, 1))
            price = cps * PRICE_PER_CPS[rarity]
            body, belly, wing, accent = palettes[i]
            rank = ["Rare", "Epic", "Legend", "Secret"].index(rarity)
            my_extras = list(extras[: 1 if rank == 0 and i % 2 == 0 else len(extras)])
            my_fx = list(fx[: 1 if rank == 0 else len(fx)])
            my_wings, my_horns = wings, horns
            if rank >= 2:
                if opt.get("top") and opt["top"] not in my_extras:
                    my_extras.append(opt["top"])
                my_fx.append("aura")
                if wings in ("normal", "bat", "feather"):
                    my_wings = "big" if wings == "normal" else wings
            if rank >= 3:
                for extra in ("orbs", "halo"):
                    if extra not in my_extras:
                        my_extras.append(extra)
                        break
                if opt.get("pulse") is None and "pulse" not in my_fx:
                    my_fx.append("pulse")
            if opt.get("pulse") and rank >= 1:
                my_fx.append("pulse")
            # every custom dragon shows at least one clear particle effect, not only smoke or a glow
            visible = {"embers", "snow", "bubbles", "stars", "petals", "lightning", "void", "coins", "aura", "fire", "sparkles"}
            if not visible.intersection(my_fx):
                my_fx.append("sparkles")
            rainbow = opt.get("rainbow")
            if rainbow and rank >= ["Rare", "Epic", "Legend", "Secret"].index(rainbow):
                my_fx.append("rainbow")
            if rank >= 1 and "trail" not in my_fx and i % 2 == 1:
                my_fx.append("trail")
            fields = [
                f'id = "{did}"',
                f'name = "{name}"',
                f'rarity = "{rarity}"',
                f"cps = {cps}",
                f"price = {price}",
                "weight = 10",
                f'theme = "{key}"',
                f"body = {lua_color(body)}",
                f"belly = {lua_color(belly)}",
                f"wing = {lua_color(wing)}",
                f"accent = {lua_color(accent)}",
                f'mat = "{mat}"',
                f'wingMat = "{wing_mat}"',
                f'wings = "{my_wings}"',
                f'horns = "{my_horns}"',
                f"extras = {lua_list(my_extras)}",
                f"fx = {lua_list(list(dict.fromkeys(my_fx)))}",
            ]
            if rank >= 1 and opt.get("eyes"):
                fields.append(f"eyes = {lua_color(opt['eyes'])}")
            if opt.get("accentMat"):
                fields.append(f'accentMat = "{opt["accentMat"]}"')
            if opt.get("alpha"):
                fields.append(f"alpha = {opt['alpha']}")
            if opt.get("alphaWing"):
                fields.append(f"alphaWing = {opt['alphaWing']}")
            rows.append("\t{ " + ", ".join(fields) + " },")
    out = [
        "-- GENERATED by tools/gen_dragons.py: edit the themes there and run it again, not this file.",
        "-- 200 custom dragons in 40 themes. Data/Dragons.lua adds them to the list (fancy = true); DragonBuilder",
        "-- builds their look from these fields; the road always tries to have one walking (RoadService).",
        "-- stylua: ignore start",
        "local function rgb(r, g, b)",
        "\treturn Color3.fromRGB(r, g, b)",
        "end",
        "",
        "return {",
        *rows,
        "}",
        "-- stylua: ignore end",
        "",
    ]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print(f"{len(rows)} dragons -> {OUT}", counters)


if __name__ == "__main__":
    main()
