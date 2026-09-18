---
id: "AA-20260918-011205-seat-scenery-with-affordable-contact-shading"
title: "Seat rocks, trees and equipment into the snow at recommended High"
status: ready
priority: P2
depends_on: []
created: "2026-09-18T01:12:05Z"
updated: "2026-09-18T01:12:05Z"
source_thread: null
---

# Seat rocks, trees and equipment into the snow at recommended High

## Outcome

Rocks, trees, gates and equipment should look seated in the snow rather than
pasted on top of it. At the recommended preset there is no ambient occlusion of
any kind, so every object meets the snow with a hard edge and no contact
darkening, which is a large part of why the mountain reads as flat white.

## Current state and evidence

Read-only inspection and bounded rendered macOS probes on 2026-09-18 at `main` `7c2d049`. Probe captures used `scripts/mac_frame_probe.sh` with the deterministic `--probe-hold`/`--probe-at-tick` options; the Standard fixture (seed 849205174) was rebaked because the local cache was `mountain_cache_v15` against current `mountain_cache_v17`. macOS frame times are not the performance target in [Rendering](../../docs/RENDERING.md#performance-policy); they indicate direction only.

- [`graphics_presets.gd`](../../scripts/presentation/graphics_presets.gd) sets
  `contact_shading` and `indirect_lighting` to `id>=8`, so presets 1 to 7,
  including recommended High, run with SSAO and SSIL off.
- [Rendering](../../docs/RENDERING.md#graphics-and-display) records why: either
  effect requires Godot Forward+'s normal and roughness depth prepass, so the
  cost includes that shared prerequisite as well as the named passes. That is a
  deliberate budget decision, not an oversight.
- [`alpine_world.gd`](../../scripts/world/alpine_world.gd) already tunes the SSAO
  path carefully for this purpose: radius 0.65, intensity 1.2, `ssao_light_affect`
  0.20 and `ssao_ao_channel_affect` 1.0, described as small contact-scale
  occlusion. The look is specified; only the cost is prohibitive.
- Material AO still applies and is combined by minimum, not multiplication, so a
  cheaper term added at the material level composes predictably with SSAO when a
  player enables it at presets 8 to 10.
- Visible in `artifacts/snow_wind_drift/flank_before.png`: the rock sits on the
  snow with a cast shadow but no contact darkening where it meets the surface.
- Hypothesis, not established: most of the benefit comes from the first few
  centimetres around a contact, which a cheaper localised term could supply
  without the normal and roughness prepass.

## Agreed decisions and scope

- The outcome is contact seating at recommended High without paying for the
  Forward+ normal and roughness prepass. If the only way to get it is that
  prepass, record that as the finding rather than quietly enabling it.
- Preserve the existing tuned SSAO and SSIL path for presets 8 to 10 and for
  players who enable it explicitly. Any cheaper term must combine with it without
  double darkening.
- Preserve material occlusion, direct shadows, snow relief and the readability
  hollows, all of which keep their current owners.
- Presentation only: no scenery placement, collision, seating or generation change.
- Out of scope: SDFGI, terrain GI, screen-space reflections and any change to the
  preset 8 to 10 defaults.

## Implementation approach

1. Establish the target by capturing preset 7 with SSAO force-enabled against
   preset 7 as shipped, at matched ticks. That pair defines both the appearance
   to reach and the cost to beat, and it is cheap to produce.
2. Evaluate cheaper candidates against that target. Godot's directional-light
   contact shadows, a per-instance grounding gradient authored into the scenery
   materials, and a snow-side proximity darkening driven by the data the world
   already has are all plausible; choose on measured cost and appearance, and
   reject visually before timing.
3. Whatever is chosen must compose by minimum with material AO and with SSAO when
   enabled, matching the existing combination rule.
4. Check the cases that matter most at speed: rocks meeting snow, tree trunks and
   root flare, gates and flags, the rider's skis and poles, and the boundary of
   the local powder patch.

## Acceptance and verification

- [ ] Matched stills at preset 7 show rocks, trees, gates and equipment seated in
  the snow, compared against both today's preset 7 and the SSAO-enabled target.
- [ ] No double darkening at presets 8 to 10 with SSAO and SSIL enabled; capture
  the combination explicitly.
- [ ] Readability hollows, material AO, direct shadows and snow relief are
  visually unchanged.
- [ ] Bounded warmed before/after frame and GPU comparison at preset 7, reported
  against the SSAO-enabled cost so the saving is explicit.
- [ ] Run the graphics override and PC graphics suites if quality propagation
  changes, and update
  [Rendering](../../docs/RENDERING.md#graphics-and-display).

Human acceptance: whether the seating looks right at skiing speed is a completion
gate for the user.

## Open questions

None.

## Completion record

Pending implementation.
