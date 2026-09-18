---
id: "AA-20260918-011210-soften-sun-shadow-edges-with-distance"
title: "Soften sun shadow edges so they gain penumbra with distance"
status: done
priority: P3
depends_on: []
created: "2026-09-18T01:12:10Z"
updated: "2026-09-18T17:20:00Z"
source_thread: null
---

# Soften sun shadow edges so they gain penumbra with distance

## Outcome

Shadow edges on snow should soften with distance from whatever casts them, the way
a real sun's angular size makes them. Today every shadow edge is uniformly hard,
which is a small but constant reminder that the image is rendered, and it is most
obvious exactly where snow is brightest and edges have the most contrast.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- [`alpine_world.gd`](../../scripts/world/alpine_world.gd) configures both the sun
  and the moon with `shadow_enabled`, `directional_shadow_max_distance`,
  `SHADOW_PARALLEL_4_SPLITS` and `shadow_bias` 0.035. It never sets
  `light_angular_distance`, `shadow_blur` or `shadow_opacity`, so all three keep
  their defaults and there is no distance-dependent penumbra.
- `shadow_quality` is a preset control running 0 to 5 and reaching 3 at presets 9
  and 10 in
  [`graphics_presets.gd`](../../scripts/presentation/graphics_presets.gd), so the
  filtering budget to support softening already varies by preset.
- Visible in `artifacts/snow_wind_drift/flank_before.png` and
  `artifacts/mac_probe/det_off.png`: the rock's cast shadow and the rider's shadow
  have the same hard edge regardless of how far the shadow falls from its caster.
- The sun's real angular diameter is about half a degree, which is small; the
  expected result is a subtle softening at range, not visibly blurry shadows.
- Related and independent:
  [shade snow beyond the shadow map](../tasks/AA-20260918-011202-shade-snow-beyond-the-shadow-map.md)
  addresses the absence of shadows past `shadow_distance_m`. This task is about
  the quality of the shadows that already exist inside it.

## Agreed decisions and scope

- Subtle and physical. A visibly soft or smeared shadow is a regression; the
  reference is the sun's actual angular size.
- The rider's own shadow and nearby contact shadows must stay crisp. Losing the
  contact point between skis and snow would hurt more than the softening helps.
- Shadow acne, peter-panning and cascade seams must not appear or worsen; the
  existing `shadow_bias` may need revisiting together with any softening.
- Must scale sensibly across the `shadow_quality` control, including the lowest
  presets, and must not silently raise the shadow filtering budget at
  recommended High.
- Out of scope: shadow distance, cascade count and the moon's behaviour beyond
  keeping it consistent.

## Implementation approach

1. Capture the current state first: matched stills of a shadow edge near its
   caster and far from it, at presets 4, 7 and 10, at low and high sun.
2. Evaluate Godot's soft-shadow path, driving it from a physically motivated
   angular size rather than an arbitrary blur, and check it against the same
   captures.
3. Pay particular attention to the rider's shadow and to rock and tree contacts,
   which are the cases where softening is most likely to look wrong.
4. Measure honestly. Soft shadows raise the filtering cost, and at the lowest
   presets the right answer may be to leave them off.

## Acceptance and verification

- [x] Matched stills show shadow edges softening with distance from their caster,
  at presets 4, 7 and 10, at low and high sun, with the effect subtle at all times.
- [x] The rider's shadow and near contacts stay crisp; capture the ski-snow
  contact explicitly.
- [x] No new shadow acne, peter-panning or cascade seams, checked while moving
  rather than only in stills.
- [x] Night and moonlit behaviour is consistent and not brightened or softened
  incorrectly.
- [x] Bounded warmed before/after frame and GPU comparison at presets 4, 7 and
  10, with the noise floor stated; report the cost at each preset separately.
- [x] Update [Rendering](../../docs/RENDERING.md#terrain-forests-and-lighting) and
  validate the backlog.

Human acceptance: a follow-up visual review, not a completion gate.

## Open questions

None.

## Completion record

Delivered by milestone note [4a3fa56258dc42c59c0d882631458e09](../../changes/4a3fa56258dc42c59c0d882631458e09.json).
Sun/moon use 0.53 degrees at filtering 2+ (default High through Ultra).
Existing PCF remains below High after evaluating preset4; the accepted lower
budget exception qualifies the first checklist item. No filtering-budget,
shadow-distance, cascade or bias increase. Custom quality changes update both
lights and clear angular size when lowered.

26 paired actual 4K stills and 99 moving-camera captures cover Meshy trees,
rocks, explicit ski contact, near/far post edges, day/dawn and moonlight.
Existing PCF was already uniformly soft: the main improvement is crisp contacts
with a subtle growing penumbra. No obvious new acne, detached contacts or cascade
seams in the finite reviewed samples. 183 compact regression checks passed.

All timing uses 6-second warmed, focused, metadata-stable perf-mixed traces,
4K Auto0.75, FG/GI off, exact 720-tick outcomes. Preset4 candidate 202.30 FPS
versus controls 212.99/216.20 was not shipped (GPU did not show the same loss;
causality is unproven). High 191.78 versus saved192.05 FPS, GPU +0.153 ms.
Ultra153.30 versus159.44/160.23 FPS, mean frame +0.267 ms and GPU +0.125 ms.
These are disclosed visual costs, not speedups or stable whole-mountain120 FPS.
Per-preset noise, tails, settings and review limitations are retained in
`artifacts/shadow_softness_20260918/REVIEW.md` and `performance.json`.
User art review remains a follow-up, not a completion gate.
