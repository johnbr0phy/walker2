# Fable prompt: wire up the walker game mechanics

## Your role
Build the mechanics for a 2D physics-driven mech shooter in Godot 4, working in the local folder `/walker2` and pushing to `https://github.com/johnbr0phy/walker2`. Work in vertical slices: each milestone must run and be playable before the next. State assumptions; keep code clean and readable.

Critical: you are working in parallel with an art pipeline (Grok Imagine). So the two streams fit together, you must create the exact folder structure, asset manifest, and colored placeholder assets defined below, and load all art by these fixed paths. When real art lands in the same paths later, it must hot-swap in with zero code changes.

## The game in one line
A slow, physically-simulated bipedal mech with a fast, freely-aimed gun, fighting an omnidirectional swarm on terrain that deforms and collapses under fire. Control scheme inspired by Walker (DMA Design, Amiga 1993): the body is a lumbering liability, the aim is fast and free, and staying upright is half the fight.

## Locked technical decisions (do not re-open)
- Godot 4 latest stable, GDScript. 2D side-scrolling.
- Physics: Godot built-in 2D rigid bodies. Walker is a chain of bodies (torso, hip, two upper legs, two lower legs, two feet) with motorized hinge joints.
- Locomotion: stabilized biped. Controller auto-balances; player commands intent (move, aim, fire); sim resolves momentum, recoil, explosions, terrain. No manual per-leg control.
- Aim: direct cursor-to-turret mapping, instant, no physics on the gun. Recoil applies force to the torso, never to the aim.
- Terrain: custom deformable terrain on a material grid (dirt, rock, metal), meshed with marching squares, regenerated per-chunk on damage. Detached regions become rigid-body debris.
- FX are code-driven (projectiles, muzzle flash, impacts, explosions, debris particles). Do NOT expect art files for these; build them with Godot particles/shapes using the terrain textures where relevant.
- Single-player. Keep the sim structured so a deterministic pass could be added later, but do not build multiplayer.

## Design pillars
1. Dumb slow body, smart fast aim. Preserve the asymmetry.
2. Footing is a resource. Ground can be cratered, tunneled, or collapsed onto you.
3. Responsive with weight, not floaty realism. If realism fights fun, fun wins.

## Repo and folder setup (do this first)
1. In `/walker2`, initialize the project if empty: create a Godot 4 project (`project.godot`).
2. Create this exact structure:
```
/walker2
  project.godot
  ASSETS.md            (the manifest, see below, this is the source of truth)
  /assets
    /walker    torso.png hip.png leg_upper.png leg_lower.png foot.png gun.png
    /enemies   runner.png paratrooper.png parachute.png burrower.png
    /terrain   dirt.png rock.png metal.png
    /bg        sky.png parallax_far.png parallax_near.png
    /ui        crosshair.png
  /scenes
  /scripts
  /prompts   (copy this prompt here as prompts/fable.md)
```
3. Generate every asset above as a colored placeholder PNG at the exact canvas size in the manifest, with a 2px border and a text label of the filename, and a small dot marking the pivot. The game must run fully on placeholders.
4. Write `ASSETS.md` containing the manifest table below verbatim, so the art pipeline matches it.
5. Wire git: set remote to `https://github.com/johnbr0phy/walker2.git`, commit, push to `main`. If auth is not configured, stop and tell me the exact command to run. Commit at the end of each milestone with a clear message.

## Asset manifest (source of truth, put this in ASSETS.md)
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

Loader rule: load each asset by path; if a file is missing or fails, fall back to the placeholder so the game never crashes on art changes.

## Milestones (each runs and is playable before the next)
- M1 Walk and balance: biped stands, walks left/right on A/D with weight and momentum, recovers from a debug push key. Gate: reads as a heavy machine walking, not a puppet. If balance never feels right, stop and flag it.
- M2 Aim and fire: mouse crosshair (ui/crosshair.png), turret (gun.png) tracks instantly, rapid-fire projectiles (code FX), recoil pushes torso, firing down gives a boost. Gate: weighty firing, reliable stance recovery.
- M3 Deformable ground: terrain textured with dirt/rock/metal, projectiles and explosions crater it, foot IK adapts, chunks fall as debris. Gate: reshape ground and the mech responds physically at stable framerate. Cap and coalesce debris.
- M4 First enemy loop: runner, paratrooper (+parachute), burrower spawning from multiple directions, plus stomp melee. Gate: combat feels like triaging threats while managing a slow body.
- M5 The hook: one encounter that only works because of physics + deformation (for example a burrower collapses the ground and buries the mech, player boosts out with downward fire). Gate: the moment lands.

## Constraints and risks (address proactively)
- Balance is the hard part. Expect most of M1 to be controller tuning (PD gains on torso angle, center-of-mass over support foot). If active balance stalls, fall back to a stabilized upright spring and note the tradeoff.
- Keep aim instant and non-physical. The gun must not inherit body wobble.
- Terrain + physics perf: cap live debris, coalesce settled pieces, keep the material grid coarse enough.
- Expose tunable params (mass, motor torque, PD gains, walk speed, fire rate, recoil impulse) as editable variables at the top of the relevant scripts.

## This session
Deliver repo setup + folder structure + ASSETS.md + placeholders + M1 (walk and balance), committed and pushed. Include a short README with run instructions and the tunable parameters. When M1 runs and feels right, stop and summarize what to tune before we approve M2.
