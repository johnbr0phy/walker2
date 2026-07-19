#!/usr/bin/env python3
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
        band = range(w // 3, 2 * w // 3)
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
print("composite: _gen/parts_qa/composite.png")
sys.exit(1 if fails else 0)
