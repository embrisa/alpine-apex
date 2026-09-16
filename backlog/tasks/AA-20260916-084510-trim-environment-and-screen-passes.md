---
id: "AA-20260916-084510-trim-environment-and-screen-passes"
title: "Measure and trim always-on environment and screen-space passes"
status: ready
priority: P2
depends_on: []
created: "2026-09-16T08:45:10Z"
updated: "2026-09-16T08:45:10Z"
source_thread: null
---

# Measure and trim always-on environment and screen-space passes

## Outcome

Recover GPU time from post-processing and environment features that run every
frame at the recommended High preset, delivering the changes that are
invisible immediately and presenting any visible trade-off to the user with
matched stills before it ships.

## Current state and evidence

- Recorded native pass means in [the GPU task](AA-20260912-105302-reduce-dense-scene-gpu-cost.md):
  glow 0.557 ms, SSIL 0.475, SSAO 0.200, tonemap 0.331, fog 0.085; the
  rendering baseline lists glow 0.43 and SSIL 0.38 ms. The 90-120 FPS target
  needs 31.8-43.1 percent less total frame time.
- Source inspected at Dev 43 / `a9c2acb` (2026-09-16):
  - [`graphics_presets.gd:60-64`](../../scripts/presentation/graphics_presets.gd)
    enables SSAO for id above 1, SSIL and volumetric sun shafts for id 7 and
    above, glow for id above 1. [`alpine_atmosphere.gd:20-33`](../../scripts/presentation/alpine_atmosphere.gd)
    uses additive glow with five non-zero levels of seven and `hdr_scale 1.8`,
    and a 128x128x64 volumetric fog volume with temporal reprojection enabled
    in clear daylight (`shaft_weight = day * clear²`).
    [`alpine_world.gd:187-200`](../../scripts/world/alpine_world.gd) sets SSAO
    radius .65 and SSIL radius 2.0.
  - [`alpine_world.gd:176-180`](../../scripts/world/alpine_world.gd) keeps the
    weather sky in `PROCESS_MODE_REALTIME` although the sky shader cubemap
    branch depends only on slowly changing weather parameters.
  - [`speed_periphery.gdshader:3,27-35`](../../assets/speed_periphery.gdshader)
    is a full-output-resolution `hint_screen_texture` blur with five taps,
    visible whenever speed times strength exceeds .005
    (`main.gd:1023`), so a 4K back-buffer copy per frame at speed.
  - [`snow_tracks.gd:44-52`](../../scripts/presentation/snow_tracks.gd) puts
    up to 6,144 track instances in one MultiMesh whose AABB spans the whole
    trail (never culled); [`ski_track.gdshader`](../../assets/graphics/ski_track.gdshader)
    is `blend_mix, depth_draw_never, cull_disabled` and fades alpha to zero
    beyond 380 m without discarding, so far fragments still shade.
  - `alpine_atmosphere.gd:33` sets the global volumetric fog volume size and
    never restores it when shafts are off (harmless persistence).
  - SDFGI (`alpine_world.gd:202-208`, `sdfgi_min_cell_size 1.0`, four
    cascades) is off by default; when the user enables Terrain GI, cascade 0
    is about 128 m and re-voxelises continuously at 47 m/s.
- Presets and their visible output are a product contract in
  [Rendering](../../docs/RENDERING.md#graphics-and-display); the project
  contract states frame rate precedes graphics, but visible default changes
  still need the user's acceptance.

## Agreed decisions and scope

Own `scripts/presentation/graphics_presets.gd`, `alpine_atmosphere.gd`, the
environment setup in `scripts/world/alpine_world.gd`, `assets/speed_periphery.gdshader`,
the speed periphery setup in `scripts/main.gd`, and the track culling in
`snow_tracks.gd`/`ski_track.gdshader`. Two tiers of change:

- Invisible (deliver directly): sky `PROCESS_MODE_INCREMENTAL` when the
  cubemap does not change per frame, ski-track early `discard` beyond the
  existing 380 m fade and `cull_back` where cards face the camera, periphery
  blur at half resolution or via the existing compositor effect if output is
  indistinguishable, restoring the fog volume size when shafts are disabled,
  and SDFGI cell/cascade settings that only affect the opt-in Terrain GI path.
- Visible (measure, propose, wait for the user): glow level count, SSAO
  quality/half resolution, SSIL as Ultra-only, volumetric shaft volume size or
  default-off in clear weather. Prepare matched 4K stills and per-pass ms for
  each; do not commit a visible default change without the user's decision.

## Implementation approach

1. Use the GPU attribution route to read glow, SSAO, SSIL, fog, sky and
   periphery costs on the dense and open traces at High.
2. Deliver the invisible tier with matched stills proving no change.
3. For the visible tier, produce an options table (pass ms saved, stills at
   4K High, which presets change) and record it in the task for the user;
   implement only what the user selects, as a follow-up milestone.

## Acceptance and verification

- [ ] Invisible-tier changes show identical matched stills and a measured GPU
  reduction or neutral result; retain negatives.
- [ ] `tests/graphics_suite.gd`, `tests/pc_graphics_suite.gd`,
  `tests/graphics_override_suite.gd`, `tests/weather_suite.gd`,
  `tests/scene_motion_blur_suite.gd`, `tests/impact_warning_suite.gd`,
  `tests/render_efficiency_suite.gd` and `tests/runtime_suite.gd` pass.
- [ ] One warmed candidate per route versus the saved baselines with GPU ms
  and frame statistics; the visible-tier options table is complete with
  stills and numbers.
- [ ] Update [Rendering](../../docs/RENDERING.md) for delivered settings;
  commit/push with a development note and Dev ID.

Human acceptance: the visible tier is gated on the user's choice from the
options table; it is not part of worker completion.

## Open questions

None

## Completion record

Pending implementation. Record pass costs, delivered invisible changes,
stills, the visible-tier options table, tests and commit/push references.
