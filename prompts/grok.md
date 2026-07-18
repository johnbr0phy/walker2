# Grok Imagine prompt: generate the walker game art

## Goal
Generate 2D side-view game art for a physics-driven mech shooter. The art must match a fixed manifest exactly (filenames, canvas sizes) so it drops into a Godot project without rework. Target folder: local `/walker2/assets`, repo `https://github.com/johnbr0phy/walker2`.

## Shared style anchor (use identically for every asset)
Grounded near-future military. A weathered, industrial bipedal war mech and its battlefield. Muted desaturated palette: gunmetal gray, olive drab, rust, dust. Orthographic side profile (flat side view, no dramatic perspective, no vanishing point). Soft even lighting, matte surfaces, light weathering and panel lines. Cohesive, serious tone, not cartoonish, not glossy sci-fi chrome.

Keep this identical across all generations. If Grok Imagine supports reference images or fixed seeds, generate one part first as the style reference and reuse it for every other asset to prevent style drift.

## Output rules (important for game use)
- Render each character/part/UI/parallax asset centered on a flat pure-magenta background (#FF00FF), orthographic side view, no ground shadow, no scene, no extra props. Magenta keys out cleanly to transparency afterward.
- Terrain textures are the exception: render them as full-frame, seamlessly tileable surfaces with no background and no border.
- One asset per image. Match the target canvas size (or larger at the same aspect ratio, then downscale).
- Consistent internal scale: the walker parts must fit together as one machine. The gun barrel is long and heavy; legs are thick and articulated; the torso is the bulky core.

## Post-processing you will do after generating (note for the human)
Grok Imagine outputs raster images without alpha, so after generating: key out the magenta to transparency, crop to the canvas size in the manifest, and save under the exact filename below. Terrain textures just crop to 256x256 and verify tiling.

## Assets to generate (filename : canvas : description)
Walker parts (must read as one cohesive machine):
- walker/torso.png : 160x200 : bulky armored mech core, side view, gun mount point at the upper front, cockpit/sensor cluster
- walker/hip.png : 120x90 : heavy pelvic joint block connecting torso to legs
- walker/leg_upper.png : 60x140 : armored thigh segment, hydraulic look, hinge at top
- walker/leg_lower.png : 50x140 : armored shin segment, hinge at top
- walker/foot.png : 90x50 : wide flat mechanical foot, treaded contact pad
- walker/gun.png : 220x70 : long heavy chaingun barrel, side view, rear mount on the left end

Enemies (same style, clearly smaller and simpler than the mech):
- enemies/runner.png : 120x120 : small fast ground drone or soldier charging, side view
- enemies/paratrooper.png : 90x120 : descending enemy trooper, arms up toward a chute, side view
- enemies/parachute.png : 200x140 : military parachute canopy, side view, lines at the bottom center
- enemies/burrower.png : 140x100 : low digging machine or drill unit that works the ground, side view

Terrain (seamless tileable, opaque, no background):
- terrain/dirt.png : 256x256 : packed dry battlefield dirt, seamless
- terrain/rock.png : 256x256 : gray fractured rock strata, seamless
- terrain/metal.png : 256x256 : riveted rusted industrial metal plating, seamless

Backgrounds (wide, atmospheric, muted):
- bg/sky.png : 1920x1080 : overcast war-torn sky, hazy, muted, full frame, opaque
- bg/parallax_far.png : 1920x1080 : distant ruined skyline silhouette on magenta, keys to transparent
- bg/parallax_near.png : 1920x1080 : nearer rubble and wreckage silhouette on magenta, keys to transparent

UI:
- ui/crosshair.png : 96x96 : clean military reticle, on magenta, keys to transparent

## Optional key art (not loaded by the game)
- One 16:9 hero shot of the mech mid-battle on cratered terrain, same style, for the repo README.

## Delivery
Save each file under its exact path in `/walker2/assets` and commit to the repo. Do not rename files; the game loads them by these exact names. If any asset comes out off-scale relative to the others, regenerate it against the walker parts, not on its own.
