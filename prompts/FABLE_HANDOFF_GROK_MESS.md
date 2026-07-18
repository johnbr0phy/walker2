# Fable handoff: fix the Nashwan walker art/aim/walk mess

**From:** John (human) + Grok Build session  
**For:** Fable (Godot 4 mechanics / integration agent)  
**Repo / folder:** `/Users/johnbrophy/walker2`  
**Date:** 2026-07-18  

---

## Your job

You are Fable. Grok ran a long art + HTML prototype session for **bot chassis “Nashwan Heavy”** (design pick #2 of 2/4/10). The result is a pile of assets, several failed approaches, one partially usable direction, and a bloated HTML demo.

Please:

1. **Inventory** what’s on disk (see archive + live paths below).
2. **Write a clear technical postmortem** of what Grok did wrong (architecture, not vibes).
3. **Propose a smart, production-viable system** for:
   - walk cycle
   - turnaround L↔R
   - free aim (including behind the legs)
   - consistency with a single side-view camera
   - hot-swappable chassis later (nashwan / psygnosis / megablast)
4. **Implement the smallest vertical slice** in Godot that proves the architecture (not another 50MB HTML frankenstein).
5. **Define a strict art contract** so the next Imagine/Grok pass cannot freestyle camera angles or 3/4 views.

Be blunt. Prefer correct structure over pretty one-off gens.

---

## Product intent (do not reopen)

- 2D side-view physics walker shooter (Walker Amiga 1993 inspiration).
- **A/D (or left/right):** move + **which way the legs face**.
- **Mouse:** free aim, independent of leg facing — including **rear / over-shoulder**.
- Aim is **not** a free-spinning detached gun sprite.
- Aim should feel like the **upper assembly (torso + cannons)** tracks the cursor.
- Walk should feel like the **first good Imagine walk video**, not a glitchy 8-frame puppet.
- Three chassis skins later (Nashwan, Psygnosis, Megablast); same skeleton / pivots.

Godot project already exists (M1 walk/balance work may be present). Art pipeline was supposed to drop into fixed paths (`ASSETS.md`). Grok largely ignored that and built parallel HTML prototypes instead.

---

## Where everything is saved

### Live (working tree)

```
/Users/johnbrophy/walker2/
  assets/designs/aim_demo/aim_demo.html     # current HTML demo (~50MB, embedded PNGs)
  assets/designs/animation/                 # frame packs
  assets/designs/                           # concepts, previews, walk_cycles videos
  ASSETS.md
  prompts/
  scripts/  scenes/  project.godot          # real game
```

### Archive (frozen snapshot)

```
/Users/johnbrophy/walker2/archive/
  README.md
  demos/                    # HTML demo copies
  animation/                # full frame packs
  designs/ + designs_full/
  source_videos/
  prompts/
```

Open archive README: `archive/README.md`.

---

## What Grok tried (chronological mess)

### Phase A — Concept art
- Generated 10 chassis designs; user liked **2 Nashwan, 4 Psygnosis, 10 Megablast**.
- Walk-cycle videos for each; user noted **inconsistent camera angles** between bots.
- In-game composites, chassis-swap architecture discussion (skin packs under `assets/chassis/<id>/`).

### Phase B — Free-aim confusion
- Original Walker: mouse aims freely; head/gun assembly **tips/swivels**; body walks separately.
- User clarified: guns mount with upper body / arms; **not** a 360° spinning detached turret.
- Grok repeatedly:
  - spun a gun sprite 360° around a fake neck
  - stacked a second “cockpit” as a turret (looked like a duplicate)
  - **cross-faded walk + aim frames** → **ghost double-image** (user hated this)
  - used **wrong angle labels** so aiming up-left showed a down-looking pose

### Phase C — Walk
- First useful walk: Imagine video → eventually **113 frames** in `animation/walk/`.
- Earlier demos stuck on **39 frames** until rewired.
- Turnaround: **73 frames** each way in `animation/turn/`.
- Walk loop/turnaround in HTML is *okay*; not production-validated in Godot.

### Phase D — Aim disasters
1. **Pitch-only sweep** (`aim_sweep/`, 48) — incomplete (no real rear).
2. **360 orbit video** (`aim_360/`, 64) — auto angle detection **failed**; labels lied.
3. **8 “compass” keys** (`aim_compass/`) — many became **3/4 side profiles**, different camera from walk → **broke animation continuity**. User correctly flipped out.
4. **Walk-matched aim** (`aim_walkmatch/`, 8) — last attempt: edit walk frame, tip torso only, keep flat side camera. **Best of a bad lot**, still coarse, rear poses imperfect, **does not composite with walking legs**.

### Current HTML demo behavior
File: `assets/designs/aim_demo/aim_demo.html` (also archived).

| State | Shows |
|---|---|
| Idle | One of 8 walk-matched aim frames by local mouse angle |
| Walk A/D | 113 walk frames only |
| Reverse | 73-frame turn |
| Never | Layered legs+aim (so **cannot walk and aim at the same time**) |

Demo embeds base64 images → huge single HTML file. Fine as a scrapbook, **not** a game architecture.

---

## Root causes (for Fable to internalize)

1. **No enforced art contract** — Imagine freestyled camera (side vs 3/4 vs front).
2. **Full-body aim frames treated as the whole character** — fights walk cycle instead of layering.
3. **Angle metadata invented from silhouette heuristics** — wrong labels → wrong pose.
4. **State-machine blunders** — blending two full-body sprites = ghosting.
5. **HTML prototype substituted for Godot architecture** — no pivot hierarchy, no chassis packs, no asset loader integration.
6. **Scope thrash** — redesign aim 5 ways without locking a skeleton + camera + layer list first.

---

## What actually works (keep)

- **Walk pack:** `assets/designs/animation/walk/` (113) + `walk_source.mp4`
- **Turn packs:** `assets/designs/animation/turn/right_to_left|left_to_right/` (73 each)
- **Walk-matched aim (reference only):** `assets/designs/animation/aim_walkmatch/` (8) + `CONTACT_aim_walkmatch.png`
- **Concept picks:** designs 2 / 4 / 10 under `assets/designs/`
- **Godot project skeleton** + `ASSETS.md` + `Assets.tex()` placeholder loader
- **Chassis swap idea:** same part filenames/pivots under `assets/chassis/<id>/`

## What to discard or quarantine

- `aim_compass/` as gameplay frames (3/4 break)
- `aim_360/` angle JSON as truth (unreliable)
- Any demo logic that `globalAlpha` stacks walk+aim full bodies
- Detached 360° gun-on-neck spin approach

---

## Smart architecture Fable should consider (recommended default)

### Camera / art law (non-negotiable)

- **One camera forever:** orthographic **flat side view**, facing **right** in source art.
- **No 3/4, no yawed body, no camera pitch.**
- Left-facing = **horizontal flip of the whole assembled bot** (or flip of each layer), not a new photoshoot.

### Layer hierarchy (this is the missing piece)

```
Root (physics / world x)
├── legs_container          # facing flip applies here or at root
│     walk cycle frames OR modular leg parts
│     (hip, upper, lower, foot) driven by gait / physics
└── waist_aim (Node2D)      # rotation = aim pitch ONLY in side plane
      └── torso + cockpit   # single piece or modular torso
            └── gun_hardpoint
                  └── gun / lasers / weapon tiers
```

**Side-view aim is mostly one DOF:** pitch in the plane of the screen (up / forward / down / rear as torso twists in-plane).  
“Aim anywhere on screen” = map mouse vector → **local pitch (and optional rear flag)**, not a free 3D orbit that changes camera.

### How walk + aim coexist

| Approach | Pros | Cons |
|---|---|---|
| **A. Layered (recommended)** | Walk legs + aim torso simultaneously | Need clean torso/leg split art |
| **B. Full-body aim matrix** | Easy blit | Need walk×aim grid (huge); Grok already failed at consistency |
| **C. State exclusive** | Simple (current HTML) | Cannot walk and aim — unacceptable for Walker feel |

**Choose A.** Generate/cut:

1. `legs_walk_###.png` — lower body only, or full walk with torso masked  
2. `torso_aim_###.png` — upper body only, same scale, waist pivot at bottom-center  
3. Optional discrete rear torso frames if continuous pitch looks wrong past ±90°

### Turnaround

- Keep Grok’s turn strip as **reference motion**, but re-export under the same camera/layer rules, **or**  
- Implement turn as: short squash / plant / flip facing / resume walk (code), if art turn is too inconsistent.

### Chassis swap

```
assets/chassis/nashwan/{torso,head,hip,leg_*,foot,gun}.png
assets/chassis/psygnosis/...
assets/chassis/megablast/...
```

Same canvas sizes + pivots as `ASSETS.md` (extend with `head` / waist if needed).  
Weapon upgrades live under `assets/weapons/`, parented to gun hardpoint — **not baked into chassis**.

### Super Nashwan (later)

Timed full weapon set + VFX overlay; does not require a fourth chassis.

---

## Suggested Fable milestone plan

### M0 — Truth table (half day)
- Document final layer list, pivots, canvas sizes, facing rules.
- Update `ASSETS.md` / write `CHASSIS_ART_CONTRACT.md`.
- Mark which archive packs are reference vs disposable.

### M1 — Godot player visual (no new art if possible)
- Load `animation/walk` as `AnimatedSprite2D` or atlas.
- A/D move + facing flip + turn clip or flip transition.
- Mouse sets `waist_aim.rotation` with clamp; temporary **rectangle / existing torso** until split art exists.
- **Prove:** walk and aim at the same time without ghosting.

### M2 — Art integration
- Split or re-request Imagine assets under the contract (or crop walk-matched aims into torso-only).
- Snap discrete aim frames only if continuous rotate looks bad; otherwise rotate one torso piece.

### M3 — Chassis swap + weapons
- `apply_chassis(id)` texture swap.
- Gun tiers as children of hardpoint.

Do **not** rebuild the 50MB HTML demo as the product.

---

## Prompt for the next Imagine/Grok art pass (include in contract)

Use language like:

> Orthographic flat side view only, identical camera to walk reference. Legs pose locked / or transparent. Only torso+cannons change. Pure magenta background. No 3/4 view. No whole-body turn. Rear aim = guns point left while feet still face right, still flat side profile.

Never: “hero shot”, “three-quarter”, “dynamic angle”, free camera.

---

## Questions for Fable to decide (state assumptions if you pick)

1. Continuous torso pitch vs discrete aim frame set for ±180° rear?
2. Physics biped (current M1 rigid chain) vs animated legs + simpler collision while aiming?
3. Keep Grok turn filmstrip or replace with flip transition?
4. Priority: ship Nashwan only first, or multi-chassis from day one?

---

## Success criteria

- [ ] Player can walk L/R with a non-flickering walk cycle  
- [ ] Player can reverse with a readable turn (art or code)  
- [ ] Player can aim while walking; **no ghost double-sprite**  
- [ ] Aim up / forward / down / rear is correct relative to **leg facing**  
- [ ] All frames share one side-view camera  
- [ ] Architecture supports chassis swap without rewriting aim  
- [ ] Art contract is short enough that a dumb generator can follow it  

---

## Tone note

Grok produced useful **raw materials** (walk harvest, turn harvest, some walk-matched aims) and a lot of **confusing prototypes**. The failure mode was **not locking hierarchy + camera + layers before generating**.  

Fable: lock structure first, then tell Grok exactly which PNGs to produce. Don’t let the image model design the game architecture again.
