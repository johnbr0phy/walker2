# walker2 asset manifest (source of truth)

All character/part/UI/parallax assets are PNG with alpha (transparent background). Terrain textures are opaque and seamlessly tileable. Pivot is where the physics joint or mount attaches.

| File | Canvas px | Alpha | Pivot | Notes |
|---|---|---|---|---|
| walker/torso.png | 160x200 | yes | center | gun mounts upper-front |
| walker/hip.png | 120x90 | yes | top-center | connects torso to legs |
| walker/leg_upper.png | 60x140 | yes | top-center | thigh, hinge at top |
| walker/leg_lower.png | 50x140 | yes | top-center | shin, hinge at top |
| walker/foot.png | 90x50 | yes | top-center | contact surface |
| walker/gun.png | 220x70 | yes | left-center | long barrel, mount at rear/left |
| enemies/runner.png | 120x120 | yes | center | charges along ground |
| enemies/paratrooper.png | 90x120 | yes | center | descends from above |
| enemies/parachute.png | 200x140 | yes | bottom-center | attaches above paratrooper |
| enemies/burrower.png | 140x100 | yes | center | damages terrain near feet |
| terrain/dirt.png | 256x256 | no | tile | seamless |
| terrain/rock.png | 256x256 | no | tile | seamless |
| terrain/metal.png | 256x256 | no | tile | seamless |
| bg/sky.png | 1920x1080 | no | fill | backmost layer |
| bg/parallax_far.png | 1920x1080 | yes | fill | distant silhouette layer |
| bg/parallax_near.png | 1920x1080 | yes | fill | mid silhouette layer |
| ui/crosshair.png | 96x96 | yes | center | follows cursor |

## Rules for the art pipeline

- Save each file under its exact path in `/assets`. Do not rename; the game loads by these exact paths.
- Match the canvas size exactly (generate larger at the same aspect ratio, then downscale).
- Character/part/UI/parallax assets: transparent background, orthographic side view, subject centered on the canvas with the pivot landing where the table says.
- Terrain textures: opaque, seamlessly tileable, full frame, no border.
- Replacing a placeholder PNG with real art at the same path hot-swaps into the game with zero code changes (Godot reimports automatically).

## Loader rule (game side)

The game loads each asset by path; if a file is missing or fails to load, it falls back to a generated placeholder so the game never crashes on art changes.
