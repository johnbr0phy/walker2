# walker2

![key art](_gen/keyart.jpg)

A slow, physically-simulated bipedal mech with a fast, freely-aimed gun, fighting an omnidirectional swarm on terrain that deforms and collapses under fire. Godot 4, GDScript, 2D. Control scheme inspired by Walker (DMA Design, 1993): the body is a lumbering liability, the aim is fast and free, and staying upright is half the fight.

**Status: M1 (walk and balance) complete.** The mech is a chain of seven rigid bodies (torso, hip, 2× upper leg, 2× lower leg, 2× foot) joined by pin joints with angular limits, kept upright and walking by a PD controller. No animation clips — every motion is physics.

## Run

Requires Godot 4.x (built and tested on 4.7.1). Open the project folder in Godot and press Play, or from the command line:

```sh
godot --path .          # or: /Applications/Godot.app/Contents/MacOS/Godot --path .
```

### Controls (M1)

| Key | Action |
|---|---|
| A / D (or ←/→) | walk left / right |
| Q / E | debug push (test balance recovery) |
| R | reset |

### Headless selftest

```sh
godot --headless -- selftest
```

Runs the M1 gate automatically: stand 2 s, walk right 4 s, take a debug push and recover, walk left 3 s. Prints PASS/FAIL per check and exits nonzero on failure.

## How the balance works (and its tradeoffs)

Per the design pillars, fun beats floaty realism. The controller layers, from most to least physical:

1. **Joint PD motors** — knees are torque motors between adjacent bodies (torque + equal/opposite reaction). Upper legs track world-frame gait targets (anchoring them to the hip body let reaction torques twist the gait's own reference frame — found the hard way).
2. **Upright stabilizer springs** — world-anchored PD torques hold the torso and hip near vertical. This is the "stabilized upright spring" fallback from the design brief: recoil, pushes, and terrain still shove the body around, but it always fights back to vertical.
3. **Ride-height suspension** — a vertical spring on the hip/torso, active only while a foot has ground contact, capped near the mech's weight so it can never hover or hop. Keeps stance legs from buckling under dynamic load.
4. **Ground drive** — a horizontal force toward target speed, gated by foot contact (with 0.2 s coyote time). The gait provides the stepping; the drive guarantees responsiveness.

Physics runs at 240 Hz (`project.godot`) — motorized ragdolls explode at 60 Hz with gains this stiff.

## Tunables

All exported at the top of `scripts/walker.gd` (masses, PD gains, gait, drive, suspension, push strength) and `scripts/main.gd` (ground, camera). Suggested tuning starting points for M1 review:

- `walk_speed`, `stride_hz`, `hip_swing_amp` — stride feel. Currently ~172 px/s.
- `gravity_scale_all`, `torso_kp/kd` — weight vs. stiffness of the body.
- `suspension_*` — stance firmness. Cap it near weight (`5.5e4`–`7e4`); higher makes it hop.
- `knee_lift` — swing-foot ground clearance. Too low and the feet scuff and the walk stalls.

## Assets

`ASSETS.md` is the manifest contract shared with the art pipeline. The game loads every asset by fixed path; anything missing falls back to a generated placeholder (`scripts/asset_loader.gd`), so dropping art in (or deleting it) never breaks the game. `tools/gen_placeholders.py` (Python + PIL) regenerates labeled placeholders for all manifest entries.

Notes for the art pipeline from first integration:

- Part art should fill its canvas to the stated pivot edges — internal padding reads as gaps at the joints (visible at knees/ankles with the current drop).
- `bg/parallax_*.png` tile horizontally with mirroring every 1920 px — art must be full-bleed edge-to-edge horizontally or the seam shows sky through the gap.

## Milestones

- [x] **M1 Walk and balance** — stands, walks A/D with weight and momentum, recovers from debug pushes. Verified by headless selftest.
- [ ] M2 Aim and fire — cursor turret, rapid-fire projectiles, recoil, downward-fire boost.
- [ ] M3 Deformable ground — material grid + marching squares, craters, debris.
- [ ] M4 First enemy loop — runner, paratrooper, burrower, stomp melee.
- [ ] M5 The hook — one encounter only physics + deformation makes possible.
