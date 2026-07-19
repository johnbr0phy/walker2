# Grok art pass 3: per-part Nashwan sprites (STRICT CONTRACT, v2 geometry)

> **v2 (2026-07-18): all canvas sizes and skeleton coordinates changed.** The
> first skeleton was too leggy; the game now matches the real proportions of
> the bot in `aim_360_source.mp4` / `walk_source.mp4` — huge upper assembly,
> short chunky legs, tread feet. Pass-2 art is live but squash-stretched;
> this pass re-cuts it at the correct aspect. Numbers below are current.

**For:** Grok (art/orchestration session, working in `/Users/johnbrophy/walker2`)
**From:** John + Fable
**Goal:** 6 PNG files that skin the existing physics walker. Nothing else.

The game is already running. It loads these files by fixed path and hot-swaps them
with **zero code changes**. Your entire deliverable is 6 correct PNGs (plus a QA
contact sheet). Do NOT build HTML demos, do NOT produce new frame packs, do NOT
touch `scripts/`, `scenes/`, or `project.godot`, do NOT invent new file names or
canvas sizes. Write only under `assets/` and `_gen/`.

## Why per-part (decided — do not reopen)

The walker is 7 rigid bodies (torso, hip, 2× upper leg, 2× lower leg, 2× foot)
joined by hinge joints and driven by physics. Whole-body animation frames cannot
skin it — the engine poses each part every tick. Your 113-frame walk pack stays as
**motion/style reference only**. Aim (M2) will tip the entire torso assembly at the
waist joint, Amiga-Walker style — so there is **no separate head file**; the cockpit
is painted into the torso.

## Camera law (non-negotiable)

- Orthographic **flat side view**, bot facing **RIGHT**.
- No 3/4 view, no yaw, no perspective, no "dynamic angle", no "hero shot".
- Neutral top-down lighting only. Parts rotate at runtime — strong directional
  side-lighting or baked ground shadows will look wrong the moment a leg swings.
- One leg texture is reused for BOTH legs (near and far). Do not bake
  depth shading that implies "this is the back leg".
- Left-facing is done in-engine by flipping. Never draw a left-facing variant.

## The skeleton (these numbers are law)

Local origin = the **waist joint** (torso↔hip pin). +y is down. All units px.
Canvas size == joint spacing: adjacent canvases butt edge-to-edge exactly.

| Part | Canvas (w×h) | Pivot | Spans (local y) | Hinges |
|---|---|---|---|---|
| torso | 240×200 | center | −200 → 0 | waist at bottom-center edge (0,0) |
| hip | 140×80 | top-center | 0 → 80 | waist at top edge; leg pivots at y=50, x=±30 |
| leg_upper | 90×75 | top-center | 50 → 125 | hip hinge at top edge, knee at bottom edge |
| leg_lower | 80×75 | top-center | 125 → 200 | knee at top edge, ankle at bottom edge |
| foot | 130×55 | top-center | 200 → 255 | ankle at top edge; bottom edge = ground contact |
| gun | 220×70 | left-center | (M2 hardpoint) | mounts on torso upper-front, barrels point right |

Assembled bot: **455 px tall** (torso top −200 to foot sole 255), ~240 wide.
Torso is ~44% of total height — the reference bot is all upper body. Paint every
part at this scale — consistent detail density across all 6 files.

### Composite table (for your QA agent)

Paste each canvas at this top-left offset (origin = waist), draw order back→front:

```
far  leg_upper  (-75,  50)
far  leg_lower  (-70, 125)
far  foot       (-95, 200)
hip             (-70,   0)
torso           (-120, -200)
near leg_upper  (-15,  50)
near leg_lower  (-10, 125)
near foot       (-35, 200)
gun (optional)  (  0, -185)   # provisional M2 hardpoint; not required in composite
```

A correct set of parts composited at these offsets must read as ONE standing
Nashwan Heavy with no gaps and no doubled shapes.

## The 6 files

Deliver to `assets/walker/` (hot-swaps into the live game) AND copy to
`assets/chassis/nashwan/` (chassis-pack home for later skins).

| File | Content |
|---|---|
| `torso.png` 240×200 | Full upper assembly exactly as in `aim_360_source.mp4`: armored hull, missile pods on top, glowing cockpit, sensor mast. NO legs, NO separate head, NO baked barrels (gun is its own file). Must still read correctly rotated ±50° at the waist. |
| `hip.png` 140×80 | Wide pelvis block / leg gimbal housing. Mechanical mass connecting waist to both leg pivots. |
| `leg_upper.png` 90×75 | Thigh: SHORT and CHUNKY armored block (wider than it is long reads right — see reference). Hinge hardware (pivot boss, semicircular cap) at BOTH ends. |
| `leg_lower.png` 80×75 | Shin: same language, slightly lighter build. Hinge hardware at both ends. |
| `foot.png` 130×55 | Long tread foot like the reference — tank-track links along the sole, road wheels. Ankle hardware at top edge. |
| `gun.png` 220×70 | Twin gatling barrels + receiver ONLY (as in the reference), horizontal, pointing right, mount hardware at the LEFT edge (left-center pivot). Weapon tiers will swap this file later. |

### Full-bleed rule (this is what broke last time)

Canvas edges ARE the joints. Opaque art must **touch every joint edge** listed in
the skeleton table (legs: top AND bottom edge; hip: top; torso: bottom; foot: top
and bottom; gun: left). Transparent padding at a joint edge renders as a visible
gap between body parts in-game. Paint a rounded pivot boss / clevis at each hinge
so the joint still reads as connected when the child rotates up to ±55–75°.

### Alpha rule (this also broke last time)

True transparent background (RGBA). If a generation step can't do alpha, use solid
pure magenta `#FF00FF` over the FULL background and key it out yourself before
delivery — your last pass shipped `aim_up_-90.png` with the magenta still baked in,
and several frames with magenta edge halos. Deliveries with any pixel where
r>240, g<60, b>240 are rejected.

## Style reference (THE look — John picked it)

- **Canonical bot:** the one in `assets/designs/animation/aim_360_source.mp4`
  and `assets/designs/animation/walk_source.mp4` (same bot; extract stills).
  Huge armored torso with missile pods and glowing cockpit, twin gatling
  cannons, short deeply-bent chunky legs, tread feet. Match its armor
  language, olive-drab green, warm yellow accents, worn-metal edges.
- Secondary: `assets/designs/02_nashwan_heavy.png`, `assets/designs/animation/walk/` frames.
- Proportion law: torso ≈ 44% of total height, legs short and wide. Repaint at
  target canvas scale, don't upscale crops.

## Run this as a swarm

1. **Plate agent (1):** produce ONE master assembly plate — the reference bot
   standing, facing right, flat side view, exactly 455px tall, limbs positioned
   so joint centers sit at the skeleton coordinates above (legs vertical, feet
   flat — straighten the reference's bent knees for the cut; the game bends
   them live). Transparent background. This plate is the single source of
   style truth.
2. **Cutter agents (6, parallel — one per file):** each cuts its part from the
   master plate into the exact canvas, extends/paints art to reach every required
   joint edge, adds hinge hardware at cut lines, cleans halos, exports RGBA.
   Cutting from one plate is mandatory — six independent generations WILL drift
   in style/scale (that's what happened with the aim packs).
3. **QA agent (1):** runs the acceptance script below after every cutter pass,
   recomposites, saves `_gen/parts_qa/composite.png` + a contact sheet, kicks
   failures back to the responsible cutter. Loop until all green.
4. **Deliver:** copy the 6 green files to both target folders. Stop. Report.

## Acceptance script (QA agent runs this verbatim)

```python
#!/usr/bin/env python3
# python3 qa_parts.py  — run from repo root
from PIL import Image
import os, sys

SPECS = {
    "torso.png":     (240, 200, ["bottom"]),
    "hip.png":       (140,  80, ["top"]),
    "leg_upper.png": ( 90,  75, ["top", "bottom"]),
    "leg_lower.png": ( 80,  75, ["top", "bottom"]),
    "foot.png":      (130,  55, ["top", "bottom"]),
    "gun.png":       (220,  70, ["left"]),
}
OFFSETS = [("leg_upper.png",-75,250),("leg_lower.png",-70,325),("foot.png",-95,400),
           ("hip.png",-70,200),("torso.png",-120,0),
           ("leg_upper.png",-15,250),("leg_lower.png",-10,325),("foot.png",-35,400)]
SRC = "assets/walker"
fails = []

def touches(im, edge):
    w, h = im.size; a = im.getchannel("A"); px = a.load()
    if edge in ("top", "bottom"):
        y = 0 if edge == "top" else h - 1
        band = range(w // 3, 2 * w // 3)          # middle third, at the pivot
        return any(px[x, yy] > 32 for yy in (y, max(0,min(h-1,y+(1 if edge=="top" else -1)))) for x in band)
    x = 0 if edge == "left" else w - 1
    return any(px[x, y] > 32 for y in range(h // 3, 2 * h // 3))

for name, (w, h, edges) in SPECS.items():
    p = os.path.join(SRC, name)
    if not os.path.exists(p): fails.append(f"{name}: MISSING"); continue
    im = Image.open(p)
    if im.size != (w, h): fails.append(f"{name}: size {im.size} != {(w,h)}"); continue
    im = im.convert("RGBA")
    if im.getpixel((1, 1))[3] != 0 and "top" not in edges and "left" not in edges:
        fails.append(f"{name}: corner not transparent")
    if any(r > 240 and g < 60 and b > 240 for r, g, b, a in im.getdata() if a > 0):
        fails.append(f"{name}: magenta pixels (bad keying)")
    for e in edges:
        if not touches(im, e): fails.append(f"{name}: opaque art does not reach {e} joint edge")

comp = Image.new("RGBA", (340, 480), (40, 40, 48, 255))
for name, x, y in OFFSETS:
    p = os.path.join(SRC, name)
    if os.path.exists(p):
        part = Image.open(p).convert("RGBA")
        comp.alpha_composite(part, (x + 170, y))
os.makedirs("_gen/parts_qa", exist_ok=True)
comp.save("_gen/parts_qa/composite.png")

print("\n".join(fails) if fails else "ALL GREEN")
print("composite: _gen/parts_qa/composite.png  <- eyeball this: one connected bot, no gaps")
sys.exit(1 if fails else 0)
```

Green script + a composite that eyeballs as one connected standing mech = done.

## Forbidden

- 3/4 or front views, camera drift between parts
- separate head file, barrels baked into the torso, legs baked into anything
- resizing canvases "because the art wanted more room"
- repurposing walk-pack frames as part textures without repainting to scale
- HTML demos, frame packs, "bonus" variants, writes outside `assets/` and `_gen/`
