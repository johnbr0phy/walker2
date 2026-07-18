#!/usr/bin/env python3
"""Generate colored placeholder PNGs for walker2 per ASSETS.md manifest.

Each asset: exact canvas size, 2px border, filename label, small dot at pivot.
Terrain: opaque seamless-ish tile. Backgrounds: opaque sky / alpha silhouettes.
"""
import math
import random
from PIL import Image, ImageDraw, ImageFont

ROOT = "/Users/johnbrophy/walker2/assets"

# file, (w,h), alpha, pivot ("center","top-center","bottom-center","left-center","tile","fill"), fill color
MANIFEST = [
    ("walker/torso.png",        (160, 200), True,  "center",        (90, 105, 90)),
    ("walker/hip.png",          (120, 90),  True,  "top-center",    (80, 90, 80)),
    ("walker/leg_upper.png",    (60, 100),  True,  "top-center",    (100, 100, 110)),
    ("walker/leg_lower.png",    (50, 95),   True,  "top-center",    (110, 110, 120)),
    ("walker/foot.png",         (90, 50),   True,  "top-center",    (70, 70, 75)),
    ("walker/gun.png",          (220, 70),  True,  "left-center",   (60, 65, 70)),
    ("enemies/runner.png",      (120, 120), True,  "center",        (150, 80, 60)),
    ("enemies/paratrooper.png", (90, 120),  True,  "center",        (140, 100, 60)),
    ("enemies/parachute.png",   (200, 140), True,  "bottom-center", (170, 160, 130)),
    ("enemies/burrower.png",    (140, 100), True,  "center",        (130, 90, 90)),
    ("terrain/dirt.png",        (256, 256), False, "tile",          (120, 90, 60)),
    ("terrain/rock.png",        (256, 256), False, "tile",          (110, 110, 115)),
    ("terrain/metal.png",       (256, 256), False, "tile",          (95, 85, 80)),
    ("bg/sky.png",              (1920, 1080), False, "fill",        (150, 150, 160)),
    ("bg/parallax_far.png",     (1920, 1080), True,  "fill",        (100, 100, 115)),
    ("bg/parallax_near.png",    (1920, 1080), True,  "fill",        (70, 70, 85)),
    ("ui/crosshair.png",        (96, 96),   True,  "center",        (200, 60, 60)),
]

try:
    FONT = ImageFont.truetype("/System/Library/Fonts/Monaco.ttf", 12)
    FONT_SMALL = ImageFont.truetype("/System/Library/Fonts/Monaco.ttf", 9)
except Exception:
    FONT = ImageFont.load_default()
    FONT_SMALL = FONT


def pivot_xy(pivot, w, h):
    return {
        "center": (w // 2, h // 2),
        "top-center": (w // 2, 2),
        "bottom-center": (w // 2, h - 3),
        "left-center": (2, h // 2),
    }.get(pivot)


def draw_label(d, name, w, h, color=(255, 255, 255, 255)):
    label = name.split("/")[-1]
    font = FONT if w >= 110 else FONT_SMALL
    bbox = d.textbbox((0, 0), label, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x, y = max(3, (w - tw) // 2), max(3, (h - th) // 2)
    d.text((x, y), label, font=font, fill=color)


def make_tile(name, size, base):
    """Opaque, seamlessly tileable placeholder: base color + wrapped noise blobs."""
    w, h = size
    img = Image.new("RGB", size, base)
    d = ImageDraw.Draw(img)
    rng = random.Random(hash(name) & 0xFFFF)
    for _ in range(220):
        x, y = rng.randrange(w), rng.randrange(h)
        r = rng.randint(2, 9)
        dc = rng.randint(-18, 18)
        col = tuple(max(0, min(255, c + dc)) for c in base)
        # draw wrapped so the tile is seamless
        for ox in (-w, 0, w):
            for oy in (-h, 0, h):
                d.ellipse([x + ox - r, y + oy - r, x + ox + r, y + oy + r], fill=col)
    d = ImageDraw.Draw(img)
    draw_label(d, name, w, h, color=(255, 255, 255))
    img.save(f"{ROOT}/{name}")


def make_bg(name, size, base, alpha):
    w, h = size
    if not alpha:  # sky: vertical gradient, opaque
        img = Image.new("RGB", size, base)
        px = img.load()
        top = tuple(min(255, c + 40) for c in base)
        for y in range(h):
            t = y / h
            row = tuple(int(top[i] * (1 - t) + base[i] * t) for i in range(3))
            for x in range(w):
                px[x, y] = row
        d = ImageDraw.Draw(img)
    else:  # silhouette skyline strip on transparent
        img = Image.new("RGBA", size, (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        rng = random.Random(hash(name) & 0xFFFF)
        skyline = int(h * (0.55 if "far" in name else 0.7))
        x = 0
        col = base + (255,)
        while x < w:
            bw = rng.randint(60, 220)
            bh = rng.randint(40, int(h * 0.35))
            d.rectangle([x, skyline - bh, x + bw, h], fill=col)
            x += bw + rng.randint(10, 60)
    d.rectangle([0, 0, w - 1, h - 1], outline=(255, 255, 255, 255) if alpha else (255, 255, 255), width=2)
    draw_label(d, name, w, h)
    img.save(f"{ROOT}/{name}")


def make_part(name, size, base, pivot):
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=base + (255,), outline=(255, 255, 255, 255), width=2)
    if name == "ui/crosshair.png":  # readable reticle instead of a filled block
        d.rectangle([0, 0, w - 1, h - 1], fill=(0, 0, 0, 0))
        cx, cy = w // 2, h // 2
        d.ellipse([8, 8, w - 9, h - 9], outline=base + (255,), width=3)
        for a, b in [((cx, 0), (cx, 20)), ((cx, h - 21), (cx, h - 1)),
                     ((0, cy), (20, cy)), ((w - 21, cy), (w - 1, cy))]:
            d.line([a, b], fill=base + (255,), width=3)
    else:
        draw_label(d, name, w, h)
    p = pivot_xy(pivot, w, h)
    if p:
        d.ellipse([p[0] - 3, p[1] - 3, p[0] + 3, p[1] + 3], fill=(255, 255, 0, 255))
    img.save(f"{ROOT}/{name}")


for name, size, alpha, pivot, color in MANIFEST:
    if pivot == "tile":
        make_tile(name, size, color)
    elif pivot == "fill":
        make_bg(name, size, color, alpha)
    else:
        make_part(name, size, color, pivot)
    print("wrote", name, size)
print("done")
