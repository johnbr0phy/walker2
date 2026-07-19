#!/usr/bin/env python3
"""Build the layered player visuals from the Grok walk harvest.

Input:  assets/designs/animation/walk/walk_###.png  (378x420 RGBA, full bot)
Output: assets/player/legs/legs_###.png   (torso masked off, torso-stabilized)
        assets/player/torso.png           (torso+cannons plate, feathered hem)
        assets/player/frames.json         (frame count, waist, per-frame bob)

Architecture (from the Grok-session postmortem, option A):
the walk frames ARE the look; we split them at the waist. Legs play as an
animation; the torso plate sits on top pivoting at the waist for free aim.
Frames are shifted so the torso is pinned at a fixed x (the source video pans),
and the residual vertical torso motion is exported as a bob table so the
overlay torso moves in lockstep with the legs.
"""
from PIL import Image, ImageFilter
import numpy as np, glob, os, json

SRC = "assets/designs/animation/walk"
OUT = "assets/player"
W, H = 378, 420
TORSO_ROWS = (0, 190)     # rows that are unambiguously torso in every frame
CUT_Y = 205               # waist line
FEATHER = 10              # alpha ramp below/above the cut
LOOP_END = 109            # frame 109 ~= frame 0 (measured), so loop 0..108

frames = sorted(glob.glob(f"{SRC}/walk_*.png"))[:LOOP_END]
assert len(frames) == LOOP_END, f"expected {LOOP_END} frames, got {len(frames)}"

os.makedirs(f"{OUT}/legs", exist_ok=True)

def defringe(arr):
    # Kill leftover chroma-key halo: magenta-ish pixels go transparent.
    r, g, b = arr[:, :, 0].astype(int), arr[:, :, 1].astype(int), arr[:, :, 2].astype(int)
    a = arr[:, :, 3].astype(int)
    pinkish = (r > 110) & (b > 100) & (g < r * 3 // 4) & (g < b)
    arr[:, :, 3][pinkish] = 0
    # Soft halo ring: semi-transparent pixels tinted toward magenta — fade
    # them AND pull the tint back to neutral so no purple line survives.
    ring = (a < 255) & (r > g) & (b > g)
    arr[:, :, 3][ring] = (arr[:, :, 3][ring] * 0.35).astype(np.uint8)
    tinted = (r > g + 12) & (b > g + 12)
    arr[:, :, 0][tinted] = arr[:, :, 1][tinted]
    arr[:, :, 2][tinted] = arr[:, :, 1][tinted]
    return arr


def torso_box(alpha):
    band = alpha[TORSO_ROWS[0]:TORSO_ROWS[1]]
    cols = np.where(band.any(axis=0))[0]
    rows = np.where(band.any(axis=1))[0]
    return (cols[0] + cols[-1]) / 2.0, rows[0]

# Reference anchor: frame 0 torso center/top.
a0 = np.asarray(Image.open(frames[0]).convert("RGBA"))[:, :, 3] > 32
cx0, top0 = torso_box(a0)

bob = []
for i, f in enumerate(frames):
    im = Image.open(f).convert("RGBA")
    alpha = np.asarray(im)[:, :, 3] > 32
    cx, top = torso_box(alpha)
    dx = int(round(cx0 - cx))
    shifted = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shifted.paste(im, (dx, 0))
    bob.append(int(top - top0))

    # Legs strip: fade the torso out across the cut line.
    arr = defringe(np.array(shifted))
    ramp = np.zeros(H, dtype=np.float32)
    ramp[CUT_Y:] = 1.0
    for k in range(FEATHER):
        ramp[CUT_Y - FEATHER + k] = k / FEATHER
    arr[:, :, 3] = (arr[:, :, 3] * ramp[:, None]).astype(np.uint8)
    Image.fromarray(arr).save(f"{OUT}/legs/legs_{i:03d}.png")

# Torso plate from stabilized frame 0: everything above the cut, feathered hem.
im0 = Image.open(frames[0]).convert("RGBA")
arr = defringe(np.array(im0))
ramp = np.ones(H, dtype=np.float32)
ramp[CUT_Y + FEATHER:] = 0.0
for k in range(FEATHER):
    ramp[CUT_Y + k] = 1.0 - k / FEATHER
arr[:, :, 3] = (arr[:, :, 3] * ramp[:, None]).astype(np.uint8)
torso = Image.fromarray(arr).crop((0, 0, W, CUT_Y + FEATHER))
torso.save(f"{OUT}/torso.png")

meta = {
    "frame_count": LOOP_END,
    "canvas": [W, H],
    "waist": [int(round(cx0)), CUT_Y],   # waist pivot in frame coords
    "torso_size": [W, CUT_Y + FEATHER],
    "bob": bob,                          # per-frame torso dy vs frame 0
    "source_fps": 24,
}
with open(f"{OUT}/frames.json", "w") as fh:
    json.dump(meta, fh)
print(f"wrote {LOOP_END} legs frames, torso {torso.size}, waist {meta['waist']}, "
      f"bob range {min(bob)}..{max(bob)}")
